import Foundation
import Postbox
        
public class LocalMediaPlaybackInfoAttribute: MessageAttribute {
    public let data: Data
    
    public init(data: Data) {
        self.data = data
    }
    
    required public init(decoder: PostboxDecoder) {
        self.data = decoder.decodeDataForKey("d") ?? Data()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeData(self.data, forKey: "d")
    }
}
