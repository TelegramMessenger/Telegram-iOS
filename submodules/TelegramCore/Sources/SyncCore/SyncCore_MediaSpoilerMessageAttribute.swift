import Foundation
import Postbox

public class MediaSpoilerMessageAttribute: MessageAttribute {
    public var associatedMessageIds: [MessageId] = []
    
    public init() {
        
    }
    
    required public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
}
