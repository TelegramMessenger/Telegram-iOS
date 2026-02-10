import Foundation
import Postbox

public class ParticipantRankMessageAttribute: MessageAttribute {
    public let rank: String
    
    public var associatedMessageIds: [MessageId] = []
    
    public init(rank: String) {
        self.rank = rank
    }
    
    required public init(decoder: PostboxDecoder) {
        self.rank = decoder.decodeStringForKey("r", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.rank, forKey: "r")
    }
}
