import Foundation
import Postbox

public final class HiddenAccountAttribute: AccountRecordAttribute {
    public let accessChallengeData: PostboxAccessChallengeData
    
    public init(accessChallengeData: PostboxAccessChallengeData) {
        self.accessChallengeData = accessChallengeData
    }
    
    public init(decoder: PostboxDecoder) {
        self.accessChallengeData = decoder.decodeObjectForKey("d", decoder: { PostboxAccessChallengeData(decoder: $0) }) as! PostboxAccessChallengeData
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(accessChallengeData, forKey: "d")
    }
    
    public func isEqual(to: AccountRecordAttribute) -> Bool {
        return to is HiddenAccountAttribute
    }
}
