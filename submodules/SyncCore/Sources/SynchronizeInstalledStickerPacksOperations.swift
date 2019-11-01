import Foundation
import Postbox

public enum SynchronizeInstalledStickerPacksOperationNamespace: Int32 {
    case stickers = 0
    case masks = 1
}

public final class SynchronizeInstalledStickerPacksOperation: PostboxCoding {
    public let previousPacks: [ItemCollectionId]
    public let archivedPacks: [ItemCollectionId]
    
    public init(previousPacks: [ItemCollectionId], archivedPacks: [ItemCollectionId]) {
        self.previousPacks = previousPacks
        self.archivedPacks = archivedPacks
    }
    
    public init(decoder: PostboxDecoder) {
        self.previousPacks = ItemCollectionId.decodeArrayFromBuffer(decoder.decodeBytesForKey("p")!)
        self.archivedPacks = decoder.decodeBytesForKey("ap").flatMap(ItemCollectionId.decodeArrayFromBuffer) ?? []
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        ItemCollectionId.encodeArrayToBuffer(self.previousPacks, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "p")
        buffer.reset()
        ItemCollectionId.encodeArrayToBuffer(self.archivedPacks, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "ap")
    }
}

public final class SynchronizeMarkFeaturedStickerPacksAsSeenOperation: PostboxCoding {
    public let ids: [ItemCollectionId]
    
    public init(ids: [ItemCollectionId]) {
        self.ids = ids
    }
    
    public init(decoder: PostboxDecoder) {
        self.ids = ItemCollectionId.decodeArrayFromBuffer(decoder.decodeBytesForKey("p")!)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        ItemCollectionId.encodeArrayToBuffer(self.ids, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "p")
    }
}
