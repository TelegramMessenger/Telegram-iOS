import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class ViewCountMessageAttribute: MessageAttribute {
    let count: Int
    
    public var associatedMessageIds: [MessageId] = []
    
    init(count: Int) {
        self.count = count
    }
    
    required public init(decoder: Decoder) {
        self.count = Int(decoder.decodeInt32ForKey("c"))
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(Int32(self.count), forKey: "c")
    }
}
