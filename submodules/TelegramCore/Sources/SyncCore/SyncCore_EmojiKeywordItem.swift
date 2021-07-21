import Postbox

public final class EmojiKeywordItem: ItemCollectionItem, Equatable {
    public let index: ItemCollectionItemIndex
    public let collectionId: ItemCollectionId.Id
    public let keyword: String
    public let emoticons: [String]
    public let indexKeys: [MemoryBuffer]

    public init(index: ItemCollectionItemIndex, collectionId: ItemCollectionId.Id, keyword: String, emoticons: [String], indexKeys: [MemoryBuffer]) {
        self.index = index
        self.collectionId = collectionId
        self.keyword = keyword
        self.emoticons = emoticons
        self.indexKeys = indexKeys
    }

    public init(decoder: PostboxDecoder) {
        self.index = ItemCollectionItemIndex(index: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0))
        self.collectionId = decoder.decodeInt64ForKey("c", orElse: 0)
        self.keyword = decoder.decodeStringForKey("k", orElse: "")
        self.emoticons = decoder.decodeStringArrayForKey("e")
        self.indexKeys = decoder.decodeBytesArrayForKey("s")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.index.index, forKey: "i.n")
        encoder.encodeInt64(self.index.id, forKey: "i.i")
        encoder.encodeInt64(self.collectionId, forKey: "c")
        encoder.encodeString(self.keyword, forKey: "k")
        encoder.encodeStringArray(self.emoticons, forKey: "e")
        encoder.encodeBytesArray(self.indexKeys, forKey: "s")
    }

    public static func ==(lhs: EmojiKeywordItem, rhs: EmojiKeywordItem) -> Bool {
        return lhs.index == rhs.index && lhs.collectionId == rhs.collectionId && lhs.keyword == rhs.keyword && lhs.emoticons == rhs.emoticons && lhs.indexKeys == rhs.indexKeys
    }
}
