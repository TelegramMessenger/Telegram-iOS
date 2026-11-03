import Foundation
import Postbox
internal import TelegramApi

/// Stores one page of feed posts: peers first, then each message — a stored copy is refreshed the way an edit
/// update refreshes it (`mergedServerMessageUpdate`, so a translation or unlocked paid media survives), a new one
/// is added out of history (`.Random`, as `_internal_getMessagesLoadIfNecessary` does). Returns the stored
/// messages' ids, dates and album keys in input order.
func storeFeedMessages(transaction: Transaction, accountPeerId: PeerId, messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) -> [FeedPageMessage] {
    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)

    var result: [FeedPageMessage] = []
    var addedMessages: [StoreMessage] = []
    for apiMessage in messages {
        var peerIsForum = false
        if let peerId = apiMessage.peerId, let peer = parsedPeers.get(peerId) ?? transaction.getPeer(peerId), peer.isForumOrMonoForum {
            peerIsForum = true
        }
        guard let storeMessage = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: peerIsForum), case let .Id(id) = storeMessage.id else {
            continue
        }
        if transaction.getMessage(id) != nil {
            transaction.updateMessage(id, update: { previousMessage in
                return .update(mergedServerMessageUpdate(previous: previousMessage, updated: storeMessage))
            })
        } else {
            addedMessages.append(storeMessage)
        }
        result.append(FeedPageMessage(id: id, timestamp: storeMessage.timestamp, groupingKey: storeMessage.groupingKey))
    }
    if !addedMessages.isEmpty {
        let _ = transaction.addMessages(addedMessages, location: .Random)
    }
    return result
}
