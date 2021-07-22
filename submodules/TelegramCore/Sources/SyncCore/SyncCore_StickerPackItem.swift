import Postbox

public final class StickerPackItem: ItemCollectionItem, Equatable {
    public let index: ItemCollectionItemIndex
    public let file: TelegramMediaFile
    public let indexKeys: [MemoryBuffer]
    
    public init(index: ItemCollectionItemIndex, file: TelegramMediaFile, indexKeys: [MemoryBuffer]) {
        self.index = index
        self.file = file
        self.indexKeys = indexKeys
    }
    
    public init(decoder: PostboxDecoder) {
        self.index = ItemCollectionItemIndex(index: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0))
        self.file = decoder.decodeObjectForKey("f") as! TelegramMediaFile
        self.indexKeys = decoder.decodeBytesArrayForKey("s")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.index.index, forKey: "i.n")
        encoder.encodeInt64(self.index.id, forKey: "i.i")
        encoder.encodeObject(self.file, forKey: "f")
        encoder.encodeBytesArray(self.indexKeys, forKey: "s")
    }
    
    public static func ==(lhs: StickerPackItem, rhs: StickerPackItem) -> Bool {
        return lhs.index == rhs.index && lhs.file == rhs.file && lhs.indexKeys == rhs.indexKeys
    }
    
    public func getStringRepresentationsOfIndexKeys() -> [String] {
        var stringRepresentations: [String] = []
        for key in self.indexKeys {
            key.withDataNoCopy { data in
                if let string = String(data: data, encoding: .utf8) {
                    stringRepresentations.append(string)
                }
            }
        }
        return stringRepresentations
    }
}
