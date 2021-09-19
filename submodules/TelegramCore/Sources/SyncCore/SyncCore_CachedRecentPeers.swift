import Postbox

public final class CachedRecentPeers: Codable {
    public let enabled: Bool
    public let ids: [PeerId]
    
    public init(enabled: Bool, ids: [PeerId]) {
        self.enabled = enabled
        self.ids = ids
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.enabled = try container.decode(Int32.self, forKey: "enabled") != 0
        self.ids = (try container.decode([Int64].self, forKey: "ids")).map(PeerId.init)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.enabled ? 1 : 0) as Int32, forKey: "enabled")
        try container.encode(self.ids.map({ $0.toInt64() }), forKey: "ids")
    }
    
    public static func cacheKey() -> ValueBoxKey {
        let key = ValueBoxKey(length: 0)
        return key
    }
}
