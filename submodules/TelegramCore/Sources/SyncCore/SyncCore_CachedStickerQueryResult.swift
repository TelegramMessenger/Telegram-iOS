import Postbox

public final class CachedStickerQueryResult: PostboxCoding {
    public let items: [TelegramMediaFile]
    public let hash: Int32
    public let timestamp: Int32
    
    public init(items: [TelegramMediaFile], hash: Int32, timestamp: Int32) {
        self.items = items
        self.hash = hash
        self.timestamp = timestamp
    }
    
    public init(decoder: PostboxDecoder) {
        self.items = decoder.decodeObjectArrayForKey("it").map { $0 as! TelegramMediaFile }
        self.hash = decoder.decodeInt32ForKey("h", orElse: 0)
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.items, forKey: "it")
        encoder.encodeInt32(self.hash, forKey: "h")
        encoder.encodeInt32(self.timestamp, forKey: "t")
    }
    
    public static func cacheKey(_ query: String) -> ValueBoxKey {
        let key = ValueBoxKey(query)
        return key
    }
}
