import Postbox

public final class CachedStickerPack: Codable {
    public let info: StickerPackCollectionInfo?
    public let items: [StickerPackItem]
    public let hash: Int32
    
    public init(info: StickerPackCollectionInfo?, items: [StickerPackItem], hash: Int32) {
        self.info = info
        self.items = items
        self.hash = hash
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let infoData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: "in") {
            self.info = StickerPackCollectionInfo(decoder: PostboxDecoder(buffer: MemoryBuffer(data: infoData.data)))
        } else {
            self.info = nil
        }

        self.items = (try container.decode([AdaptedPostboxDecoder.RawObjectData].self, forKey: "it")).map { itemData in
            return StickerPackItem(decoder: PostboxDecoder(buffer: MemoryBuffer(data: itemData.data)))
        }

        self.hash = try container.decode(Int32.self, forKey: "h")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        if let info = self.info {
            try container.encode(PostboxEncoder().encodeObjectToRawData(info), forKey: "in")
        } else {
            try container.encodeNil(forKey: "in")
        }

        try container.encode(self.items.map { item in
            return PostboxEncoder().encodeObjectToRawData(item)
        }, forKey: "it")

        try container.encode(self.hash, forKey: "h")
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
