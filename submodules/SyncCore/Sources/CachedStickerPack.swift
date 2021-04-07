import Postbox

public final class CachedStickerPack: PostboxCoding {
    public let info: StickerPackCollectionInfo?
    public let items: [StickerPackItem]
    public let hash: Int32
    
    public init(info: StickerPackCollectionInfo?, items: [StickerPackItem], hash: Int32) {
        self.info = info
        self.items = items
        self.hash = hash
    }
    
    public init(decoder: PostboxDecoder) {
        self.info = decoder.decodeObjectForKey("in", decoder: { StickerPackCollectionInfo(decoder: $0) }) as? StickerPackCollectionInfo
        self.items = decoder.decodeObjectArrayForKey("it").map { $0 as! StickerPackItem }
        self.hash = decoder.decodeInt32ForKey("h", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let info = self.info {
            encoder.encodeObject(info, forKey: "in")
        } else {
            encoder.encodeNil(forKey: "in")
        }
        encoder.encodeObjectArray(self.items, forKey: "it")
        encoder.encodeInt32(self.hash, forKey: "h")
    }
    
    public static func cacheKey(_ id: ItemCollectionId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: id.namespace)
        key.setInt64(4, value: id.id)
        return key
    }
    
    public static func cacheKey(shortName: String) -> ValueBoxKey {
        return ValueBoxKey(shortName)
    }
}
