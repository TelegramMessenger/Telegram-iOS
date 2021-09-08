import Foundation
import Postbox

public class ChannelMessageStateVersionAttribute: MessageAttribute {
    public let pts: Int32
    
    public init(pts: Int32) {
        self.pts = pts
    }
    
    required public init(decoder: PostboxDecoder) {
        self.pts = decoder.decodeInt32ForKey("p", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.pts, forKey: "p")
    }
}
