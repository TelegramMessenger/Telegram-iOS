import Postbox

public final class SuggestedLocalizationEntry: Codable {
    public let languageCode: String
    public let isSeen: Bool
    
    public init(languageCode: String, isSeen: Bool) {
        self.languageCode = languageCode
        self.isSeen = isSeen
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.languageCode = try container.decode(String.self, forKey: "lc")
        self.isSeen = (try container.decode(Int32.self, forKey: "s")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.languageCode, forKey: "lc")
        try container.encode((self.isSeen ? 1 : 0) as Int32, forKey: "s")
    }
    
    public static func ==(lhs: SuggestedLocalizationEntry, rhs: SuggestedLocalizationEntry) -> Bool {
        return lhs.languageCode == rhs.languageCode && lhs.isSeen == rhs.isSeen
    }
}
