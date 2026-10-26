#if DEBUG
import Foundation
import Postbox
import SwiftSignalKit

/// Debug-only: forgets the stored comments of each post's discussion group, so the next open of
/// its comments is a cold load. The group's messages go, and its history and thread holes are
/// re-added whole; the post and its `ReplyThreadMessageAttribute` stay (the open reads them), unless
/// `dropPosts` also removes the post (leaving a hole in its place, so the channel fetches it again). Driven by the `-resetCommentsCache` launch argument.
func _internal_debugResetDiscussionCaches(account: Account, posts: [(username: String, postId: Int32)], dropPosts: Bool) -> Signal<Never, NoError> {
    let resets = posts.map { username, postId -> Signal<Never, NoError> in
        return _internal_resolvePeerByName(account: account, name: username, referrer: nil)
        |> mapToSignal { result -> Signal<PeerId?, NoError> in
            if case let .result(peerId) = result {
                return .single(peerId)
            } else {
                return .complete()
            }
        }
        |> take(1)
        |> mapToSignal { channelId -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction -> Void in
                guard let channelId else {
                    Logger.shared.log("ReplyThreadOpen", "reset skipped \(username): not resolved")
                    return
                }
                let postMessageId = MessageId(peerId: channelId, namespace: Namespaces.Message.Cloud, id: postId)

                var groupId: PeerId?
                if let cachedData = transaction.getPeerCachedData(peerId: channelId) as? CachedChannelData, case let .known(linkedId) = cachedData.linkedDiscussionPeerId {
                    groupId = linkedId
                }
                if groupId == nil, let message = transaction.getMessage(postMessageId) {
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyThreadMessageAttribute {
                            groupId = attribute.commentsPeerId
                        }
                    }
                }
                guard let groupId else {
                    Logger.shared.log("ReplyThreadOpen", "reset skipped \(username)/\(postId): no discussion group")
                    return
                }

                var threadIds = Set<Int64>()
                transaction.scanMessageAttributes(peerId: groupId, namespace: Namespaces.Message.Cloud, limit: 100_000, { id, attributes in
                    for attribute in attributes {
                        if let attribute = attribute as? SourceReferenceMessageAttribute, attribute.messageId == postMessageId {
                            threadIds.insert(Int64(id.id))
                        } else if let attribute = attribute as? ReplyMessageAttribute, let threadMessageId = attribute.threadMessageId {
                            threadIds.insert(Int64(threadMessageId.id))
                        }
                    }
                    return true
                })

                transaction.clearHistory(groupId, threadId: nil, minTimestamp: nil, maxTimestamp: nil, namespaces: .all, forEachMedia: nil)
                // The server still has every message cleared here: the record of recent deletions would keep the
                // next fills from storing them again (RecentlyDeletedMessages.swift).
                transaction.forgetRecentlyDeletedMessages(peerId: groupId)
                transaction.addHole(peerId: groupId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                for threadId in threadIds {
                    transaction.addHole(peerId: groupId, threadId: threadId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                }
                if dropPosts {
                    // A hole where the post was, or the channel's history reads it as never having existed.
                    transaction.deleteMessages([postMessageId], forEachMedia: nil)
                    transaction.forgetRecentlyDeletedMessages(peerId: channelId)
                    transaction.addHole(peerId: channelId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: postId ... postId)
                }

                Logger.shared.log("ReplyThreadOpen", "reset \(username)/\(postId) group=\(groupId.id._internalGetInt64Value()) threads=\(threadIds.sorted()) droppedPost=\(dropPosts)")
            }
            |> ignoreValues
        }
    }
    var signal: Signal<Never, NoError> = .complete()
    for reset in resets {
        signal = signal |> then(reset)
    }
    return signal
}

/// Debug-only: forgets a forum's stored messages, so every topic opens cold. The history hole and every topic's
/// thread hole are re-added whole, and the topic list is marked unloaded, so it is fetched again (its entries do not
/// survive their topics' messages). Driven by the `-resetForumCache` launch argument.
func _internal_debugResetForumHistory(account: Account, usernames: [String]) -> Signal<Never, NoError> {
    let resets = usernames.map { username -> Signal<Never, NoError> in
        return _internal_resolvePeerByName(account: account, name: username, referrer: nil)
        |> mapToSignal { result -> Signal<PeerId?, NoError> in
            if case let .result(peerId) = result {
                return .single(peerId)
            } else {
                return .complete()
            }
        }
        |> take(1)
        |> mapToSignal { peerId -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction -> Void in
                guard let peerId else {
                    Logger.shared.log("ReplyThreadOpen", "forum reset skipped \(username): not resolved")
                    return
                }
                var threadIds = Set<Int64>()
                for item in transaction.getMessageHistoryThreadIndex(peerId: peerId, limit: 10_000) {
                    threadIds.insert(item.threadId)
                }
                transaction.scanMessageAttributes(peerId: peerId, namespace: Namespaces.Message.Cloud, limit: 100_000, { _, attributes in
                    for attribute in attributes {
                        if let attribute = attribute as? ReplyMessageAttribute, let threadMessageId = attribute.threadMessageId {
                            threadIds.insert(Int64(threadMessageId.id))
                        }
                    }
                    return true
                })
                
                transaction.clearHistory(peerId, threadId: nil, minTimestamp: nil, maxTimestamp: nil, namespaces: .all, forEachMedia: nil)
                // As above: the server still has these messages.
                transaction.forgetRecentlyDeletedMessages(peerId: peerId)
                transaction.addHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                for threadId in threadIds {
                    transaction.addHole(peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                }
                // A topic's list entry, and the topic info stored in it, lives only while the topic has a stored
                // message (MessageThreadIndexTable.replay), so clearing the history emptied the topic list. Marking
                // the whole list unloaded makes it fetch the topics again, as a channel state reset does.
                transaction.setPeerThreadCombinedState(peerId: peerId, state: nil)
                
                Logger.shared.log("ReplyThreadOpen", "forum reset \(username) peer=\(peerId.id._internalGetInt64Value()) threads=\(threadIds.count)")
            }
            |> ignoreValues
        }
    }
    var signal: Signal<Never, NoError> = .complete()
    for reset in resets {
        signal = signal |> then(reset)
    }
    return signal
}
#endif
