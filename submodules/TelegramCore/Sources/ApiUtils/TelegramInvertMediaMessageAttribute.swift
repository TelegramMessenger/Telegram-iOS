
import Foundation
import Postbox
import TelegramApi

public class InvertMediaMessageAttribute: MessageAttribute, Equatable {
    public let associatedPeerIds: [PeerId] = []
    public let associatedMediaIds: [MediaId] = []
    
    
    public init() {
    }
    
    required public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public static func ==(lhs: InvertMediaMessageAttribute, rhs: InvertMediaMessageAttribute) -> Bool {
        return true
    }
}
