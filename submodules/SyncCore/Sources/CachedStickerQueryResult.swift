import Postbox

public final class CachedStickerQueryResult: PostboxCoding {
    public let items: [TelegramMediaFile]
    public let hash: Int32
    
    public init(items: [TelegramMediaFile], hash: Int32) {
        self.items = items
        self.hash = hash
    }
    
    public init(decoder: PostboxDecoder) {
        self.items = decoder.decodeObjectArrayForKey("it").map { $0 as! TelegramMediaFile }
        self.hash = decoder.decodeInt32ForKey("h", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.items, forKey: "it")
        encoder.encodeInt32(self.hash, forKey: "h")
    }
    
    public static func cacheKey(_ query: String) -> ValueBoxKey {
        let key = ValueBoxKey(query)
        return key
    }
}
