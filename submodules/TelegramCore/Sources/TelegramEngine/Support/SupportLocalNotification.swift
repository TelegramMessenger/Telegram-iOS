import Foundation
import Postbox
import SwiftSignalKit

func supportLocalNotificationMessages(texts: [String], timestamp: Int32, peerId: PeerId) -> [StoreMessage] {
    return texts.map { text in
        return StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, customStableId: nil, globallyUniqueId: Int64.random(in: Int64.min ... Int64.max), groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: text, attributes: [], media: [])
    }
}

func _internal_addSupportLocalNotification(account: Account, texts: [String]) -> Signal<Never, NoError> {
    guard account.isSupportUser, !texts.isEmpty else {
        return .complete()
    }
    let timestamp = account.network.getApproximateRemoteTimestamp()
    return account.postbox.transaction { transaction -> Void in
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))
        if transaction.getPeer(peerId) == nil {
            let peer = TelegramUser(id: peerId, accessHash: nil, firstName: "Telegram Notifications", lastName: nil, username: nil, phone: nil, photo: [], botInfo: BotUserInfo(flags: [], inlinePlaceholder: nil), restrictionInfo: nil, flags: [.isVerified], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
            updatePeersCustom(transaction: transaction, peers: [peer], update: { _, updated in
                return updated
            })
        }
        if case .notIncluded = transaction.getPeerChatListInclusion(peerId) {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
        }
        let ids = transaction.addMessages(supportLocalNotificationMessages(texts: texts, timestamp: timestamp, peerId: peerId), location: .UpperHistoryBlock)
        if let maxId = ids.values.max(by: { $0.id < $1.id }) {
            transaction.applyIncomingReadMaxId(maxId)
        }
    }
    |> ignoreValues
}
