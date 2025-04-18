import Postbox

public final class CachedThemesConfiguration: Codable {
    public let hash: Int64
    
    public init(hash: Int64) {
        self.hash = hash
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.hash = try container.decode(Int64.self, forKey: "hash6")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.hash, forKey: "hash6")
    }
}
