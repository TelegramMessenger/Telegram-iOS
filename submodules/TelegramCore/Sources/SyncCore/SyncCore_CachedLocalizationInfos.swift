import Postbox

public final class CachedLocalizationInfos: Codable {
    public let list: [LocalizationInfo]
    
    public init(list: [LocalizationInfo]) {
        self.list = list
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.list = try container.decode([LocalizationInfo].self, forKey: "t")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.list, forKey: "l")
    }
}
