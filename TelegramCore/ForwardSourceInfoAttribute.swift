import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class ForwardSourceInfoAttribute: MessageAttribute {
    public let messageId: MessageId
    
    init(messageId: MessageId) {
        self.messageId = messageId
    }
    
    required public init(decoder: Decoder) {
        self.messageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("p")), namespace: decoder.decodeInt32ForKey("n"), id: decoder.decodeInt32ForKey("i"))
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.messageId.peerId.toInt64(), forKey: "p")
        encoder.encodeInt32(self.messageId.namespace, forKey: "n")
        encoder.encodeInt32(self.messageId.id, forKey: "i")
    }
}
