import Foundation
import Postbox

extension StoreMessage {
    /// `message` to store again with `attributes` and `tags` in place of its own and every other field as stored:
    /// no custom stable id, the forward info as `StoreMessageForwardInfo(_:)` builds it, the author's id. For the
    /// replay's `transaction.updateMessage` closures that change only attributes and tags.
    convenience init(updating message: Message, attributes: [MessageAttribute], tags: MessageTags) {
        self.init(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: attributes, media: message.media)
    }
}
