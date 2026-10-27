import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

/// What the server said about stored Cloud messages a regular-chat history fill did not get back, which it
/// suspects are gone.
struct StoredMessageConfirmation {
    /// Fresh copies of the candidates the server still has, each a real message of its own chat.
    var existing: [StoreMessage]
    /// The peers and users the answers carried, each chat merged with its stored copy when its answer was read
    /// (`AccumulatedPeers(transaction:chats:users:)`); `updatePeers` them before storing `existing`.
    var peers: AccumulatedPeers
    /// The candidates the server did not return as a real message of their own chat (`messageEmpty`, or
    /// left out of the answer: a left-out message is considered deleted, owner 2026-10-25).
    var missing: Set<MessageId>
}

extension StoredMessageConfirmation {
    /// How many ids `storedCloudMessagesAboveTopMessages` reads from one chat's id index at a time; a full page
    /// continues from its last id. 1000 in the app; tests lower it to reach the continuation.
    static var ghostTailPageLimit: Int = 1000
}

/// At most this many ids go into one `messages.getMessages`.
private let storedMessageConfirmationBatchLimit = 200

private func storedMessageConfirmationBatches(_ ids: [MessageId]) -> [[MessageId]] {
    var batches: [[MessageId]] = []
    var start = 0
    while start < ids.count {
        let end = min(start + storedMessageConfirmationBatchLimit, ids.count)
        batches.append(Array(ids[start ..< end]))
        start = end
    }
    return batches
}

/// A request of `confirmStoredMessages` that has failed this many times is logged once (State log), so one
/// that never succeeds can be told from a slow one. It is still retried.
private let storedMessageConfirmationFailureLogThreshold = 10

/// `request` with its failures counted across the retries that resubscribe it: the first failure past
/// `storedMessageConfirmationFailureLogThreshold` is logged with `method` and the error. The error itself is
/// passed on unchanged, so the retry policy after it decides as before.
private func countingStoredMessageConfirmationFailures<T>(_ request: Signal<T, MTRpcError>, method: String, idCount: Int) -> Signal<T, MTRpcError> {
    let failureCount = Atomic<Int>(value: 0)
    return request
    |> `catch` { error -> Signal<T, MTRpcError> in
        let count = failureCount.modify { $0 + 1 }
        if count == storedMessageConfirmationFailureLogThreshold + 1 {
            Logger.shared.log("State", "confirmStoredMessages: \(method) for \(idCount) ids has failed \(count) times, last with \(error.errorCode) \(error.errorDescription ?? ""); still retrying")
        }
        return .fail(error)
    }
}

/// One answer of `confirmStoredMessages`, for the ids its request carried. An id the server answered as a
/// real message of another chat is neither existing nor missing: it is logged and left untouched.
///
/// Read inside `transaction`, as a history fill reads its own answer: each chat is merged with its stored copy
/// (`mergeGroupOrChannel`), so a min copy (the source of a forward, say) updates only what it carries. Parsed on its
/// own, a min channel has no admin rights, banned rights or restriction info, and writing it would clear the stored
/// channel's.
private func parseStoredMessageConfirmation(transaction: Transaction, _ result: Api.messages.Messages, requested: [MessageId], accountPeerId: PeerId, knownForumPeerIds: Set<PeerId>) -> StoredMessageConfirmation {
    let apiMessages: [Api.Message]
    let apiChats: [Api.Chat]
    let apiUsers: [Api.User]
    switch result {
    case let .messages(messagesData):
        apiMessages = messagesData.messages
        apiChats = messagesData.chats
        apiUsers = messagesData.users
    case let .messagesSlice(messagesSliceData):
        apiMessages = messagesSliceData.messages
        apiChats = messagesSliceData.chats
        apiUsers = messagesSliceData.users
    case let .channelMessages(channelMessagesData):
        // Only `channels.getMessages` answers so, and it is not sent here; read as any other answer.
        apiMessages = channelMessagesData.messages
        apiChats = channelMessagesData.chats
        apiUsers = channelMessagesData.users
    case .messagesNotModified:
        // Only a hashed request can get this, and these requests carry no hash. It confirms nothing, so it
        // deletes nothing.
        Logger.shared.log("State", "confirmStoredMessages: messages.messagesNotModified for \(requested.count) ids, confirming none of them")
        return StoredMessageConfirmation(existing: [], peers: AccumulatedPeers(), missing: Set())
    }

    let peers = AccumulatedPeers(transaction: transaction, chats: apiChats, users: apiUsers)
    let requestedIds = Set(requested)
    var requestedByNumber: [MessageId.Id: [MessageId]] = [:]
    for id in requested {
        requestedByNumber[id.id, default: []].append(id)
    }

    var existing: [StoreMessage] = []
    var existingIds = Set<MessageId>()
    var answeredInAnotherChat = Set<MessageId>()
    for apiMessage in apiMessages {
        var peerIsForum = false
        if let peerId = apiMessage.peerId {
            if let peer = peers.get(peerId) {
                peerIsForum = peer.isForumOrMonoForum
            } else {
                peerIsForum = knownForumPeerIds.contains(peerId)
            }
        }
        // `messageEmpty` does not parse: its id stays out of `existing`, so it is missing.
        guard let storeMessage = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: peerIsForum), case let .Id(id) = storeMessage.id else {
            continue
        }
        if let sameNumber = requestedByNumber[id.id] {
            let otherChats = sameNumber.filter { $0 != id }
            if !otherChats.isEmpty {
                Logger.shared.log("State", "confirmStoredMessages: \(otherChats) answered as \(id), leaving them untouched")
                answeredInAnotherChat.formUnion(otherChats)
            }
        }
        if requestedIds.contains(id) && !existingIds.contains(id) {
            existingIds.insert(id)
            existing.append(storeMessage)
        }
    }

    let missing = requestedIds.subtracting(existingIds).subtracting(answeredInAnotherChat)
    return StoredMessageConfirmation(existing: existing, peers: peers, missing: missing)
}

/// Asks the server which of `ids`, stored Cloud messages of private chats and basic groups, it still has.
///
/// The requests go through `source`, the source the history fill filled through, so a preload fill
/// (`.download`) confirms through its download session.
///
/// The ids go to `messages.getMessages`: they are account-global in private chats and basic groups, so one
/// request mixes chats. Ids are sorted ascending, at most 200 go into a request, and the requests run one after
/// another. Each answer is read in a transaction of its own (`parseStoredMessageConfirmation`). Whether a peer is a
/// forum (a bot's), which decides how its messages parse, is read from the answer, else from `knownPeers` (the peers
/// of the answer the caller just got), else from Postbox.
///
/// Every request retries every error until it succeeds (0.2 s more per attempt, at most 5 s), a definite answer
/// included (owner, 2026-10-24: "Keep the hole"), so an error, FLOOD_WAIT included, never makes a message look
/// missing and nothing ever gives up; a request that has failed more than 10 times is logged once, with its last
/// error, and retried on. Ids of another namespace or of another kind of peer, a channel's included, are skipped
/// and logged: a history fill reconciles only private chats and basic groups (`historyFillReconciles`).
func confirmStoredMessages(accountPeerId: PeerId, postbox: Postbox, source: FetchMessageHistoryHoleSource, ids: [MessageId], knownPeers: AccumulatedPeers = AccumulatedPeers()) -> Signal<StoredMessageConfirmation, NoError> {
    var regularIds: [MessageId] = []
    for id in Set(ids).sorted() {
        if id.namespace != Namespaces.Message.Cloud {
            Logger.shared.log("State", "confirmStoredMessages: skipping \(id), not a Cloud message")
        } else if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
            regularIds.append(id)
        } else {
            Logger.shared.log("State", "confirmStoredMessages: skipping \(id), not in a private chat or basic group")
        }
    }

    let emptyConfirmation = StoredMessageConfirmation(existing: [], peers: AccumulatedPeers(), missing: Set())
    if regularIds.isEmpty {
        return .single(emptyConfirmation)
    }

    let batches = storedMessageConfirmationBatches(regularIds)
    let peerIds = Set(regularIds.map { $0.peerId })

    return postbox.transaction { transaction -> Set<PeerId> in
        var forumPeerIds = Set<PeerId>()
        for peerId in peerIds {
            if let peer = knownPeers.get(peerId) ?? transaction.getPeer(peerId), peer.isForumOrMonoForum {
                forumPeerIds.insert(peerId)
            }
        }
        return forumPeerIds
    }
    |> mapToSignal { forumPeerIds -> Signal<StoredMessageConfirmation, NoError> in
        // One request at a time: each starts when the one before it has answered.
        var signal: Signal<StoredMessageConfirmation, NoError> = .single(emptyConfirmation)
        for batch in batches {
            let answer = countingStoredMessageConfirmationFailures(source.request(Api.functions.messages.getMessages(id: batch.map { Api.InputMessage.inputMessageID(.init(id: $0.id)) })), method: "messages.getMessages", idCount: batch.count)
            |> retryRequest
            signal = signal
            |> mapToSignal { confirmation -> Signal<StoredMessageConfirmation, NoError> in
                return answer
                |> mapToSignal { result -> Signal<StoredMessageConfirmation, NoError> in
                    return postbox.transaction { transaction -> StoredMessageConfirmation in
                        let parsed = parseStoredMessageConfirmation(transaction: transaction, result, requested: batch, accountPeerId: accountPeerId, knownForumPeerIds: forumPeerIds)
                        var updated = confirmation
                        updated.existing.append(contentsOf: parsed.existing)
                        updated.peers = updated.peers.union(with: parsed.peers)
                        updated.missing.formUnion(parsed.missing)
                        return updated
                    }
                }
            }
        }
        return signal
    }
}

/// Deletes `ids`, stored Cloud messages, inside a write transaction exactly as a received deletion deletes them: a
/// private-chat or basic-group message as `updateDeleteMessages` (`.DeleteMessagesWithGlobalIds`, whose case calls
/// `applyDeleteMessagesWithGlobalIds` in StateReplay+Messages.swift, cached media included), a channel message as
/// `updateDeleteChannelMessages` (`.DeleteMessages`, whose case calls `applyDeleteMessages` there,
/// `_internal_deleteMessages`). It fires the replay's deletion events too (owner decision D1): the ids reach
/// `messagesRemovedContext` (inside this transaction) and `deletedMessages` (once it has committed) of the account's
/// state manager, found by `mediaBox` (`StoredMessageConfirmationDeletionReporters`). With no manager registered for
/// `mediaBox`, only the storage changes. The account reset deletes its ghost tail with it, and
/// `applyStoredMessageConfirmation` what a history fill's confirmation found missing.
///
/// Returns the ids it deleted: the private-chat and basic-group ones, then the channel ones, each in the order given.
@discardableResult
func deleteStoredMessagesAsReceivedDeletion(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId]) -> [MessageId] {
    var regularIds: [MessageId] = []
    var channelIds: [MessageId] = []
    for id in ids {
        if id.peerId.namespace == Namespaces.Peer.CloudChannel {
            channelIds.append(id)
        } else {
            regularIds.append(id)
        }
    }

    if !regularIds.isEmpty {
        var resourceIds: [MediaResourceId] = []
        transaction.deleteMessages(regularIds, forEachMedia: { media in
            addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
        })
        if !resourceIds.isEmpty {
            let _ = mediaBox.removeCachedResources(Array(Set(resourceIds)), force: true).start()
        }
    }
    if !channelIds.isEmpty {
        _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: channelIds)
    }

    let deletedIds = regularIds + channelIds
    // The received-deletion events (owner decision D1): reported inside this transaction, as the replay reports
    // its deletions inside its own; the deletedMessages pipe fires once it has committed.
    StoredMessageConfirmationDeletionReporters.shared.report(deletedIds, mediaBox: mediaBox, transaction: transaction)
    return deletedIds
}

/// Applies `confirmation` inside a write transaction. A candidate is touched only while it is still stored
/// with the `stableVersion` recorded in `versions` when it was read, so a write made while the
/// confirmation was in flight (an edit, a deletion, a fresh store) wins.
///
/// - A missing candidate is deleted exactly as a received deletion deletes it, deletion events included
///   (`deleteStoredMessagesAsReceivedDeletion`).
/// - An existing candidate is stored again from its fresh copy, after `updatePeers` with the answers'
///   peers. That fixes edits and recomputes its tags.
///
/// Returns the ids it deleted.
@discardableResult
func applyStoredMessageConfirmation(transaction: Transaction, accountPeerId: PeerId, mediaBox: MediaBox, confirmation: StoredMessageConfirmation, versions: [MessageId: UInt32]) -> [MessageId] {
    func isUnchanged(_ id: MessageId) -> Bool {
        guard let version = versions[id], let message = transaction.getMessage(id) else {
            return false
        }
        return message.stableVersion == version
    }

    let missingIds = confirmation.missing.sorted().filter(isUnchanged)
    var refreshed: [StoreMessage] = []
    for message in confirmation.existing {
        if case let .Id(id) = message.id, isUnchanged(id) {
            refreshed.append(message)
        }
    }

    let deletedIds = deleteStoredMessagesAsReceivedDeletion(transaction: transaction, mediaBox: mediaBox, ids: missingIds)
    if !refreshed.isEmpty {
        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: confirmation.peers)
        let _ = transaction.addMessages(refreshed, location: .Random)
    }

    if !deletedIds.isEmpty || !refreshed.isEmpty {
        Logger.shared.log("State", "applyStoredMessageConfirmation: deleted \(deletedIds), refreshed \(refreshed.count)")
    }
    return deletedIds
}

/// The ghost tail of the account reset's chat-list page (spec section 3 point 3, as amended 2026-10-24): for each
/// chat the page carries, the stored Cloud messages whose ids are above the chat's top message. The reset deletes
/// them all (`deleteStoredMessagesAsReceivedDeletion`); the chat-list hole fill does not read them.
///
/// A chat's top is the higher of its dialog's `top_message` (`topMessageIds`) and the highest Cloud id the
/// page stores for it (`storeMessages`). A dialog of the page with neither (`top_message == 0`: its history was
/// cleared elsewhere and the chat kept; also a collapsed community item, under whose id nothing is stored, so its
/// read is empty) has top 0, so every stored Cloud message of the chat is above it. The dialogs of the page are `chatPeerIds` and the keys of `peerGroupIds`, which also lists the archived
/// dialogs a `.general` page fetches from the folders it references (they are not in `chatPeerIds`; their
/// `top_message` is in `topMessageIds`, so one whose top message the page does not carry is not taken for top 0).
/// Private chats, basic groups and channels only. Read by id (`messageIdsInRange`), not by
/// timestamp: an imported message has a new id and an old date. Read inside the reset's transaction, after it
/// stored the page. Usually there are none.
func storedCloudMessagesAboveTopMessages(transaction: Transaction, fetchedChats: FetchedChatList) -> [MessageId] {
    var topIds: [PeerId: MessageId.Id] = [:]
    for (peerId, messageId) in fetchedChats.topMessageIds where messageId.namespace == Namespaces.Message.Cloud {
        topIds[peerId] = max(topIds[peerId] ?? messageId.id, messageId.id)
    }
    for message in fetchedChats.storeMessages {
        if case let .Id(id) = message.id, id.namespace == Namespaces.Message.Cloud {
            topIds[id.peerId] = max(topIds[id.peerId] ?? id.id, id.id)
        }
    }
    // A fetched dialog with no top: everything stored is above it. The archived dialogs of a `.general` page are
    // only in `peerGroupIds`.
    for peerId in fetchedChats.chatPeerIds + Array(fetchedChats.peerGroupIds.keys) where topIds[peerId] == nil {
        topIds[peerId] = 0
    }

    // `messageIdsInRange` returns ascending ids, lowest first, at most `limit`; a full page continues
    // from its last id.
    let pageLimit = StoredMessageConfirmation.ghostTailPageLimit
    var ids: [MessageId] = []
    for peerId in topIds.keys.sorted() {
        guard let topId = topIds[peerId] else {
            continue
        }
        if peerId.namespace != Namespaces.Peer.CloudUser && peerId.namespace != Namespaces.Peer.CloudGroup && peerId.namespace != Namespaces.Peer.CloudChannel {
            continue
        }
        var lowerBound = topId
        while lowerBound < Int32.max {
            let page = transaction.messageIdsInRange(peerId: peerId, namespace: Namespaces.Message.Cloud, range: (lowerBound + 1) ... Int32.max, limit: pageLimit)
            ids.append(contentsOf: page)
            guard page.count >= pageLimit, let last = page.last, last.id > lowerBound else {
                break
            }
            lowerBound = last.id
        }
    }
    return ids
}
