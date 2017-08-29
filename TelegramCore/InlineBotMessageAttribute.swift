import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class InlineBotMessageAttribute: MessageAttribute {
    public let peerId: PeerId
    
    public var associatedPeerIds: [PeerId] {
        return [self.peerId]
    }
    
    init(peerId: PeerId) {
        self.peerId = peerId
    }
    
    required public init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("i", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "i")
    }
}
