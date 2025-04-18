import Foundation
import Postbox


public class EditedMessageAttribute: MessageAttribute {
    public let date: Int32
    public let isHidden: Bool
    
    public init(date: Int32, isHidden: Bool) {
        self.date = date
        self.isHidden = isHidden
    }
    
    required public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
        self.isHidden = decoder.decodeInt32ForKey("h", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
        encoder.encodeInt32(self.isHidden ? 1 : 0, forKey: "h")
    }
}
