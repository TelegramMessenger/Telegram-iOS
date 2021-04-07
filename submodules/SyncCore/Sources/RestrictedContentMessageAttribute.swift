import Foundation
import Postbox

public class RestrictedContentMessageAttribute: MessageAttribute {
    public let rules: [RestrictionRule]
    
    public init(rules: [RestrictionRule]) {
        self.rules = rules
    }
    
    required public init(decoder: PostboxDecoder) {
        self.rules = decoder.decodeObjectArrayWithDecoderForKey("rs")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.rules, forKey: "rs")
    }
}
