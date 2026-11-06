import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences

enum AllMentionDemoForumChronology {
    /// Cloud message ids and timestamps must agree across the whole channel,
    /// including different topics. Repair only the bundled seed, before opening
    /// any history views; recipient calls and user-created queue entries stay intact.
    static func repair(transaction: Transaction, peerId: PeerId, maxSeedId: Int32) {
        guard peerId == AllMentionDemoConfiguration.forumPeerId else { return }
        let messages = transaction.getMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, from: .lowerBound(peerId: peerId), includeFrom: true, to: .upperBound(peerId: peerId, namespace: Namespaces.Message.Cloud), limit: Int(Int32.max)).filter { $0.id.id <= maxSeedId }.sorted { $0.id.id < $1.id.id }
        var previousTimestamp: Int32 = 0
        for message in messages {
            let timestamp = max(previousTimestamp, message.timestamp)
            previousTimestamp = timestamp
            if timestamp != message.timestamp {
                transaction.updateMessage(message.id, update: { original in
                    return .update(StoreMessage(id: original.id, customStableId: nil, globallyUniqueId: original.globallyUniqueId, groupingKey: original.groupingKey, threadId: original.threadId, timestamp: timestamp, flags: StoreMessageFlags(original.flags), tags: original.tags, globalTags: original.globalTags, localTags: original.localTags, forwardInfo: original.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: original.author?.id, text: original.text, attributes: original.attributes, media: original.media))
                })
            }
        }
    }

}
