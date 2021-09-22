import Postbox

public final class CachedStickerQueryResult: PostboxCoding {
    public let items: [TelegramMediaFile]
    public let hash: Int64
    public let timestamp: Int32
    
    public init(items: [TelegramMediaFile], hash: Int64, timestamp: Int32) {
        self.items = items
        self.hash = hash
        self.timestamp = timestamp
    }
    
    public init(decoder: PostboxDecoder) {
        self.items = decoder.decodeObjectArrayForKey("it").map { $0 as! TelegramMediaFile }
        self.hash = decoder.decodeInt64ForKey("h6", orElse: 0)
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.items, forKey: "it")
        encoder.encodeInt64(self.hash, forKey: "h6")
        encoder.encodeInt32(self.timestamp, forKey: "t")
    }
    
    public static func cacheKey(_ query: String) -> ValueBoxKey {
        let key = ValueBoxKey(query)
        return key
    }
}
