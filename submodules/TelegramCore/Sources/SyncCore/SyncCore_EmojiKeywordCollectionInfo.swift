import Postbox

public func emojiKeywordColletionIdForCode(_ code: String) -> ItemCollectionId {
    return ItemCollectionId(namespace: Namespaces.ItemCollection.EmojiKeywords, id: Int64(HashFunctions.murMurHash32(code)))
}

public final class EmojiKeywordCollectionInfo: ItemCollectionInfo, Equatable {
    public let id: ItemCollectionId
    public let languageCode: String
    public let inputLanguageCode: String
    public let version: Int32
    public let timestamp: Int32

    public init(languageCode: String, inputLanguageCode: String, version: Int32, timestamp: Int32) {
        self.id = emojiKeywordColletionIdForCode(inputLanguageCode)
        self.languageCode = languageCode
        self.inputLanguageCode = inputLanguageCode
        self.version = version
        self.timestamp = timestamp
    }

    public init(decoder: PostboxDecoder) {
        self.id = ItemCollectionId(namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0))
        self.languageCode = decoder.decodeStringForKey("lc", orElse: "")
        self.inputLanguageCode = decoder.decodeStringForKey("ilc", orElse: "")
        self.version = decoder.decodeInt32ForKey("v", orElse: 0)
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.id.namespace, forKey: "i.n")
        encoder.encodeInt64(self.id.id, forKey: "i.i")
        encoder.encodeString(self.languageCode, forKey: "lc")
        encoder.encodeString(self.inputLanguageCode, forKey: "ilc")
        encoder.encodeInt32(self.version, forKey: "v")
        encoder.encodeInt32(self.timestamp, forKey: "t")
    }

    public static func ==(lhs: EmojiKeywordCollectionInfo, rhs: EmojiKeywordCollectionInfo) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.languageCode != rhs.languageCode {
            return false
        }
        if lhs.inputLanguageCode != rhs.inputLanguageCode {
            return false
        }
        if lhs.version != rhs.version {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        return true
    }
}
