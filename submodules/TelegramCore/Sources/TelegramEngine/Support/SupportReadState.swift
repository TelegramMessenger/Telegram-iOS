import Foundation
import Postbox
import SwiftSignalKit

private let deletedUserSweepStartDelay: Double = 30.0
private let deletedUserSweepBatchCount = 50
private let deletedUserSweepBatchPause: Double = 0.05

public func supportOpensChatAtEnd(isSupportUser: Bool, hasTag: Bool, peerId: PeerId?, accountPeerId: PeerId) -> Bool {
    guard isSupportUser, !hasTag, let peerId else {
        return false
    }
    return peerId != accountPeerId
}

enum SupportSendReadTarget: Equatable {
    case chat
    case thread(Int64)
}

struct SupportSendReadInfo {
    var isDeferred: Bool
    var threadId: Int64?
    var replyThreadId: Int64?
}

public func supportSendIsDeferred(attributes: [EngineMessage.Attribute]) -> Bool {
    return attributes.contains(where: { $0 is OutgoingScheduleInfoMessageAttribute || $0 is OutgoingQuickReplyMessageAttribute })
}

func supportSendReadTargets(peerHasThreads: Bool, sends: [SupportSendReadInfo]) -> [SupportSendReadTarget] {
    var result: [SupportSendReadTarget] = []
    for send in sends where !send.isDeferred {
        let target: SupportSendReadTarget
        if peerHasThreads, let threadId = send.threadId ?? send.replyThreadId {
            target = .thread(threadId)
        } else {
            target = .chat
        }
        if !result.contains(target) {
            result.append(target)
        }
    }
    return result
}

func supportSendReadInfo(transaction: Transaction, message: EnqueueMessage) -> SupportSendReadInfo {
    let threadId: Int64?
    var replyThreadId: Int64?
    switch message {
    case let .message(_, _, _, _, threadIdValue, replyToMessageId, _, _, _, _):
        threadId = threadIdValue
        if let replyToMessageId {
            replyThreadId = transaction.getMessage(replyToMessageId.messageId)?.threadId
        }
    case let .forward(_, threadIdValue, _, _, _):
        threadId = threadIdValue
    }
    return SupportSendReadInfo(isDeferred: supportSendIsDeferred(attributes: message.attributes), threadId: threadId, replyThreadId: replyThreadId)
}

func supportApplyReadOnSend(transaction: Transaction, network: Network, stateManager: AccountStateManager, peerId: PeerId, sends: [SupportSendReadInfo]) {
    let peerHasThreads = transaction.getPeer(peerId)?.isForumOrMonoForum ?? false
    for target in supportSendReadTargets(peerHasThreads: peerHasThreads, sends: sends) {
        switch target {
        case .chat:
            let namespace = peerId.namespace == Namespaces.Peer.SecretChat ? Namespaces.Message.SecretIncoming : Namespaces.Message.Cloud
            if let index = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: namespace) {
                _internal_applyMaxReadIndexInteractively(transaction: transaction, stateManager: stateManager, index: index)
            }
        case let .thread(threadId):
            _internal_toggleForumThreadUnreadMarkInteractively(transaction: transaction, network: network, peerId: peerId, threadId: threadId, setToValue: false)
        }
    }
}

// TDesktop's History::clearUnreadOnClientSide: a deleted user's chat keeps no unread state on a support account.
func supportClearsUnread(isSupportAccount: Bool, peer: Peer?) -> Bool {
    return isSupportAccount && (peer?.isDeleted ?? false)
}

func supportClearsUnread(transaction: Transaction, accountPeerId: PeerId, peerId: PeerId) -> Bool {
    guard peerId.namespace == Namespaces.Peer.CloudUser, transaction.getPeer(peerId)?.isDeleted ?? false else {
        return false
    }
    return isSupportAccount(transaction: transaction, accountPeerId: accountPeerId)
}

// `maxKnownId` keeps an incoming message from being counted, as in `nonMemberChannelReadState`.
func supportClearedReadState(current: PeerReadState?, topMessageId: Int32?) -> PeerReadState {
    var maxIncomingReadId = topMessageId ?? 0
    var maxOutgoingReadId: Int32 = 0
    if case let .idBased(currentMaxIncomingReadId, currentMaxOutgoingReadId, _, _, _) = current {
        maxIncomingReadId = max(maxIncomingReadId, currentMaxIncomingReadId)
        maxOutgoingReadId = currentMaxOutgoingReadId
    }
    return .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: Int32.max - 1, count: 0, markedUnread: false)
}

func readStateOperationTargetsDeletedUser(_ operation: AccountStateMutationOperation, getPeer: (PeerId) -> Peer?) -> Bool {
    guard let peerId = readStateOperationPeerId(operation), peerId.namespace == Namespaces.Peer.CloudUser else {
        return false
    }
    return getPeer(peerId)?.isDeleted ?? false
}

func supportReadStatesToStore(transaction: Transaction, accountPeerId: PeerId, readStates: [PeerId: [MessageId.Namespace: PeerReadState]]) -> [PeerId: [MessageId.Namespace: PeerReadState]] {
    var result = readStates
    for (peerId, states) in readStates where supportClearsUnread(transaction: transaction, accountPeerId: accountPeerId, peerId: peerId) {
        let topMessageId = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud)?.id.id
        result[peerId] = [Namespaces.Message.Cloud: supportClearedReadState(current: states[Namespaces.Message.Cloud], topMessageId: topMessageId)]
    }
    return result
}

private func supportDeletedUserSweepBatch(transaction: Transaction, groupId: PeerGroupId, accountPeerId: PeerId, position: (index: ChatListIndex, isChat: Bool)?) -> (next: (index: ChatListIndex, isChat: Bool)?, clearedCount: Int) {
    let entries = transaction.chatListStoredEntries(groupId: groupId, earlierThan: position, count: deletedUserSweepBatchCount)
    var next: (index: ChatListIndex, isChat: Bool)?
    var clearedCount = 0
    for entry in entries {
        switch entry {
        case let .hole(hole):
            next = (ChatListIndex(pinningIndex: nil, messageIndex: hole.index), false)
        case let .chat(index):
            next = (index, true)
            let peerId = index.messageIndex.id.peerId
            guard supportClearsUnread(transaction: transaction, accountPeerId: accountPeerId, peerId: peerId), let current = transaction.getPeerReadStates(peerId)?.first(where: { $0.0 == Namespaces.Message.Cloud })?.1 else {
                continue
            }
            let cleared = supportClearedReadState(current: current, topMessageId: transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud)?.id.id)
            if cleared != current {
                transaction.resetIncomingReadStates([peerId: [Namespaces.Message.Cloud: cleared]])
                clearedCount += 1
            }
        }
    }
    return (next, clearedCount)
}

struct SupportChatListSweepCursor {
    var groupIndex: Int
    var position: (index: ChatListIndex, isChat: Bool)?
    var count: Int
}

// Runs batches one after another until a batch returns nil. Each batch starts from the timer, never from the previous
// batch's completion: chaining them with `then` nested one subscription per batch, and finishing a sweep over
// thousands of chats overflowed the thread's stack.
func supportSequentialBatches<State>(initial: State, pause: Double, queue: Queue, batch: @escaping (State) -> Signal<State?, NoError>) -> Signal<Never, NoError> {
    return Signal { subscriber in
        let disposable = MetaDisposable()
        let isDisposed = Atomic<Bool>(value: false)
        func run(_ state: State) {
            if isDisposed.with({ $0 }) {
                return
            }
            disposable.set(batch(state).start(next: { next in
                if let next {
                    queue.after(pause, {
                        run(next)
                    })
                } else {
                    subscriber.putCompletion()
                }
            }))
        }
        run(initial)
        return ActionDisposable {
            let _ = isDisposed.swap(true)
            disposable.dispose()
        }
    }
}

func managedSupportDeletedUserSweep(postbox: Postbox, accountPeerId: PeerId) -> Signal<Never, NoError> {
    let groupIds: [PeerGroupId] = [.root, Namespaces.PeerGroup.archive]

    let sweep = supportSequentialBatches(initial: SupportChatListSweepCursor(groupIndex: 0, position: nil, count: 0), pause: deletedUserSweepBatchPause, queue: Queue.concurrentDefaultQueue(), batch: { cursor in
        return postbox.transaction { transaction -> SupportChatListSweepCursor? in
            if cursor.groupIndex >= groupIds.count {
                Logger.shared.log("SupportReadState", "cleared \(cursor.count) deleted users' read states")
                return nil
            }
            let result = supportDeletedUserSweepBatch(transaction: transaction, groupId: groupIds[cursor.groupIndex], accountPeerId: accountPeerId, position: cursor.position)
            if let next = result.next {
                return SupportChatListSweepCursor(groupIndex: cursor.groupIndex, position: next, count: cursor.count + result.clearedCount)
            }
            return SupportChatListSweepCursor(groupIndex: cursor.groupIndex + 1, position: nil, count: cursor.count + result.clearedCount)
        }
    })

    return Signal<Never, NoError>.complete()
    |> delay(deletedUserSweepStartDelay, queue: Queue.concurrentDefaultQueue())
    |> then(sweep)
}
