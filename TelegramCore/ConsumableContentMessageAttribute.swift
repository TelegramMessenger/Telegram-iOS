import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class ConsumableContentMessageAttribute: MessageAttribute {
    public let consumed: Bool
    
    public init(consumed: Bool) {
        self.consumed = consumed
    }
    
    required public init(decoder: Decoder) {
        self.consumed = decoder.decodeInt32ForKey("c", orElse: 0) != 0
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.consumed ? 1 : 0, forKey: "c")
    }
}
