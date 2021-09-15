import Foundation
import Postbox

public final class HiddenAccountAttribute: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case accessChallengeData = "d"
    }

    public let accessChallengeData: PostboxAccessChallengeData
    
    public init(accessChallengeData: PostboxAccessChallengeData) {
        self.accessChallengeData = accessChallengeData
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.accessChallengeData = try container.decode(PostboxAccessChallengeData.self, forKey: .accessChallengeData)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(accessChallengeData, forKey: .accessChallengeData)
    }
    
    public static func ==(lhs: HiddenAccountAttribute, rhs: HiddenAccountAttribute) -> Bool {
        return lhs.accessChallengeData == rhs.accessChallengeData
    }
}
