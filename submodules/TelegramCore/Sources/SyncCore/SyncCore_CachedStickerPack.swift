import Foundation
import Postbox
import FlatBuffers
import FlatSerialization

public final class CachedStickerPack: Codable {
    public let info: StickerPackCollectionInfo.Accessor?
    public let items: [StickerPackItem]
    public let hash: Int32
    
    public init(info: StickerPackCollectionInfo?, items: [StickerPackItem], hash: Int32) {
        self.info = info.flatMap(StickerPackCollectionInfo.Accessor.init)
        self.items = items
        self.hash = hash
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let serializedInfoData = try container.decodeIfPresent(Data.self, forKey: "ind") {
            var byteBuffer = ByteBuffer(data: serializedInfoData)
            self.info = StickerPackCollectionInfo.Accessor(FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_StickerPackCollectionInfo, serializedInfoData)
        } else if let infoData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: "in") {
            let info = StickerPackCollectionInfo(decoder: PostboxDecoder(buffer: MemoryBuffer(data: infoData.data)))
            self.info = StickerPackCollectionInfo.Accessor(info)
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
            if let infoData = info._wrappedData {
                try container.encode(infoData, forKey: "ind")
            } else if let info = info._wrappedObject {
                var builder = FlatBufferBuilder(initialSize: 1024)
                let value = info.encodeToFlatBuffers(builder: &builder)
                builder.finish(offset: value)
                let serializedInstantPage = builder.data
                try container.encode(serializedInstantPage, forKey: "ind")
            } else {
                preconditionFailure()
            }
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
