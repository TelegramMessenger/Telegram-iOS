import Postbox

public final class CachedRecentPeers: PostboxCoding {
    public let enabled: Bool
    public let ids: [PeerId]
    
    public init(enabled: Bool, ids: [PeerId]) {
        self.enabled = enabled
        self.ids = ids
    }
    
    public init(decoder: PostboxDecoder) {
        self.enabled = decoder.decodeInt32ForKey("enabled", orElse: 0) != 0
        self.ids = decoder.decodeInt64ArrayForKey("ids").map(PeerId.init)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.enabled ? 1 : 0, forKey: "enabled")
        encoder.encodeInt64Array(self.ids.map({ $0.toInt64() }), forKey: "ids")
    }
    
    public static func cacheKey() -> ValueBoxKey {
        let key = ValueBoxKey(length: 0)
        return key
    }
}
