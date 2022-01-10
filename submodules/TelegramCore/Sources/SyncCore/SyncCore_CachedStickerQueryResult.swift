import Postbox

public final class CachedStickerQueryResult: Codable {
    public let items: [TelegramMediaFile]
    public let hash: Int64
    public let timestamp: Int32
    
    public init(items: [TelegramMediaFile], hash: Int64, timestamp: Int32) {
        self.items = items
        self.hash = hash
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.items = (try container.decode([AdaptedPostboxDecoder.RawObjectData].self, forKey: "it")).map { itemData in
            return TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: itemData.data)))
        }

        self.hash = try container.decode(Int64.self, forKey: "h6")
        self.timestamp = try container.decode(Int32.self, forKey: "t")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.items.map { item in
            return PostboxEncoder().encodeObjectToRawData(item)
        }, forKey: "it")
        try container.encode(self.hash, forKey: "h6")
        try container.encode(self.timestamp, forKey: "t")
    }
    
    public static func cacheKey(_ query: String) -> ValueBoxKey {
        let key = ValueBoxKey(query)
        return key
    }
}
