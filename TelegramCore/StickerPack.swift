import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class StickerPackCollectionInfo: ItemCollectionInfo, Equatable {
    public let id: ItemCollectionId
    public let accessHash: Int64
    public let title: String
    public let shortName: String
    public let hash: Int32
    
    public init(id: ItemCollectionId, accessHash: Int64, title: String, shortName: String, hash: Int32) {
        self.id = id
        self.accessHash = accessHash
        self.title = title
        self.shortName = shortName
        self.hash = hash
    }
    
    public init(decoder: Decoder) {
        self.id = ItemCollectionId(namespace: decoder.decodeInt32ForKey("i.n"), id: decoder.decodeInt64ForKey("i.i"))
        self.accessHash = decoder.decodeInt64ForKey("a")
        self.title = decoder.decodeStringForKey("t")
        self.shortName = decoder.decodeStringForKey("s")
        self.hash = decoder.decodeInt32ForKey("h")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.id.namespace, forKey: "i.n")
        encoder.encodeInt64(self.id.id, forKey: "i.i")
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.shortName, forKey: "s")
        encoder.encodeInt32(self.hash, forKey: "h")
    }
    
    public static func ==(lhs: StickerPackCollectionInfo, rhs: StickerPackCollectionInfo) -> Bool {
        return lhs.id == rhs.id && lhs.title == rhs.title && lhs.shortName == rhs.shortName && lhs.hash == rhs.hash
    }
}

public final class StickerPackItem: ItemCollectionItem, Equatable {
    public let index: ItemCollectionItemIndex
    public let file: TelegramMediaFile
    public var indexKeys: [MemoryBuffer]
    
    public init(index: ItemCollectionItemIndex, file: TelegramMediaFile, indexKeys: [MemoryBuffer]) {
        self.index = index
        self.file = file
        self.indexKeys = indexKeys
    }
    
    public init(decoder: Decoder) {
        self.index = ItemCollectionItemIndex(index: decoder.decodeInt32ForKey("i.n"), id: decoder.decodeInt64ForKey("i.i"))
        self.file = decoder.decodeObjectForKey("f") as! TelegramMediaFile
        self.indexKeys = decoder.decodeBytesArrayForKey("s")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.index.index, forKey: "i.n")
        encoder.encodeInt64(self.index.id, forKey: "i.i")
        encoder.encodeObject(self.file, forKey: "f")
        encoder.encodeBytesArray(self.indexKeys, forKey: "s")
    }
    
    public static func ==(lhs: StickerPackItem, rhs: StickerPackItem) -> Bool {
        return lhs.index == rhs.index && lhs.file == rhs.file && lhs.indexKeys == rhs.indexKeys
    }
}
