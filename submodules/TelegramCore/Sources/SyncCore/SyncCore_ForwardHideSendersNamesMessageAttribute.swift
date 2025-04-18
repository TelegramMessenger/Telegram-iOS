import Foundation
import Postbox
        
public class ForwardOptionsMessageAttribute: MessageAttribute {
    public let hideNames: Bool
    public let hideCaptions: Bool
    
    public init(hideNames: Bool, hideCaptions: Bool) {
        self.hideNames = hideNames
        self.hideCaptions = hideCaptions
    }
    
    required public init(decoder: PostboxDecoder) {
        self.hideNames = decoder.decodeBoolForKey("hideNames", orElse: false)
        self.hideCaptions = decoder.decodeBoolForKey("hideCaptions", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBool(self.hideNames, forKey: "hideNames")
        encoder.encodeBool(self.hideCaptions, forKey: "hideCaptions")
    }
}
