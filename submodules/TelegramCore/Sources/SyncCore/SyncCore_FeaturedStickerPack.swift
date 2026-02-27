import Foundation
import Postbox
import FlatBuffers
import FlatSerialization

public struct FeaturedStickerPackItemId {
    public let rawValue: MemoryBuffer
    public let packId: Int64
    
    public init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
        assert(rawValue.length == 8)
        var idValue: Int64 = 0
        memcpy(&idValue, rawValue.memory, 8)
        self.packId = idValue
    }
    
    public init(_ packId: Int64) {
        self.packId = packId
        var idValue: Int64 = packId
        self.rawValue = MemoryBuffer(memory: malloc(8)!, capacity: 8, length: 8, freeWhenDone: true)
        memcpy(self.rawValue.memory, &idValue, 8)
    }
}

public final class FeaturedStickerPackItem: Codable {
    public let info: StickerPackCollectionInfo.Accessor
    public let topItems: [StickerPackItem]
    public let unread: Bool
    
    public init(info: StickerPackCollectionInfo.Accessor, topItems: [StickerPackItem], unread: Bool) {
        self.info = info
        self.topItems = topItems
        self.unread = unread
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let serializedInfoData = try container.decodeIfPresent(Data.self, forKey: "infd") {
            var byteBuffer = ByteBuffer(data: serializedInfoData)
            self.info = StickerPackCollectionInfo.Accessor(FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_StickerPackCollectionInfo, serializedInfoData)
        } else {
            let infoData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: "i")
            self.info = StickerPackCollectionInfo.Accessor(StickerPackCollectionInfo(decoder: PostboxDecoder(buffer: MemoryBuffer(data: infoData.data))))
        }

        self.topItems = (try container.decode([AdaptedPostboxDecoder.RawObjectData].self, forKey: "t")).map { itemData in
            return StickerPackItem(decoder: PostboxDecoder(buffer: MemoryBuffer(data: itemData.data)))
        }

        self.unread = try container.decode(Int32.self, forKey: "u") != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        if let infoData = self.info._wrappedData {
            try container.encode(infoData, forKey: "infd")
        } else if let info = self.info._wrappedObject {
            var builder = FlatBufferBuilder(initialSize: 1024)
            let value = info.encodeToFlatBuffers(builder: &builder)
            builder.finish(offset: value)
            let serializedInstantPage = builder.data
            try container.encode(serializedInstantPage, forKey: "infd")
        } else {
            preconditionFailure()
        }
        try container.encode(self.topItems.map { item in
            return PostboxEncoder().encodeObjectToRawData(item)
        }, forKey: "t")

        try container.encode((self.unread ? 1 : 0) as Int32, forKey: "u")
    }
}
