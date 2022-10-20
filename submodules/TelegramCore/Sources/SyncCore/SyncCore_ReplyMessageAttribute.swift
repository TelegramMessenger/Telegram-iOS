import Foundation
import Postbox

public class ReplyMessageAttribute: MessageAttribute {
    public let messageId: MessageId
    public let threadMessageId: MessageId?
    
    public var associatedMessageIds: [MessageId] {
        return [self.messageId]
    }
    
    public init(messageId: MessageId, threadMessageId: MessageId?) {
        self.messageId = messageId
        self.threadMessageId = threadMessageId
    }
    
    required public init(decoder: PostboxDecoder) {
        let namespaceAndId: Int64 = decoder.decodeInt64ForKey("i", orElse: 0)
        self.messageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("p", orElse: 0)), namespace: Int32(namespaceAndId & 0xffffffff), id: Int32((namespaceAndId >> 32) & 0xffffffff))
        
        if let threadNamespaceAndId = decoder.decodeOptionalInt64ForKey("ti"), let threadPeerId = decoder.decodeOptionalInt64ForKey("tp") {
            self.threadMessageId = MessageId(peerId: PeerId(threadPeerId), namespace: Int32(threadNamespaceAndId & 0xffffffff), id: Int32((threadNamespaceAndId >> 32) & 0xffffffff))
        } else {
            self.threadMessageId = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let namespaceAndId = Int64(self.messageId.namespace) | (Int64(self.messageId.id) << 32)
        encoder.encodeInt64(namespaceAndId, forKey: "i")
        encoder.encodeInt64(self.messageId.peerId.toInt64(), forKey: "p")
        if let threadMessageId = self.threadMessageId {
            let threadNamespaceAndId = Int64(threadMessageId.namespace) | (Int64(threadMessageId.id) << 32)
            encoder.encodeInt64(threadNamespaceAndId, forKey: "ti")
            encoder.encodeInt64(threadMessageId.peerId.toInt64(), forKey: "tp")
        }
    }
}

public extension Message {
    var effectiveReplyThreadMessageId: MessageId? {
        if let threadId = self.threadId {
            return makeThreadIdMessageId(peerId: self.id.peerId, threadId: threadId)
        }
        return nil
    }
}
