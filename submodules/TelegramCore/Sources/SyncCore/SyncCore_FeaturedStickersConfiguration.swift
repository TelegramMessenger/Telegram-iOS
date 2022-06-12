import Postbox

public final class FeaturedStickersConfiguration: Codable {
    public let isPremium: Bool
    
    public init(isPremium: Bool) {
        self.isPremium = isPremium
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.isPremium = try container.decode(Bool.self, forKey: "isPremium")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.isPremium, forKey: "isPremium")
    }
}

