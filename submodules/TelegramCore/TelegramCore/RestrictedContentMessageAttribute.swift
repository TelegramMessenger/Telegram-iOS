import Foundation
#if os(macOS)
import PostboxMac
#else
import Postbox
#endif

public class RestrictedContentMessageAttribute: MessageAttribute {
    public let platformSelector: String
    public let category: String
    public let text: String
    
    public init(platformSelector: String, category: String, text: String) {
        self.platformSelector = platformSelector
        self.category = category
        self.text = text
    }
    
    required public init(decoder: PostboxDecoder) {
        self.platformSelector = decoder.decodeStringForKey("ps", orElse: "")
        self.category = decoder.decodeStringForKey("c", orElse: "")
        self.text = decoder.decodeStringForKey("t", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.platformSelector, forKey: "ps")
        encoder.encodeString(self.category, forKey: "c")
        encoder.encodeString(self.text, forKey: "t")
    }
}
