import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

func emojiKeywordColletionIdForCode(_ code: String) -> ItemCollectionId {
    return ItemCollectionId(namespace: Namespaces.ItemCollection.EmojiKeywords, id: Int64(murMurHashString32(code)))
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

private let refreshTimeout: Int32 = 60 * 60

private enum SearchEmojiKeywordsIntermediateResult {
    case updating(timestamp: Int32?)
    case completed([EmojiKeywordItem])
}

public func searchEmojiKeywords(postbox: Postbox, inputLanguageCode: String, query: String, completeMatch: Bool) -> Signal<[EmojiKeywordItem], NoError> {
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return .single([])
    }
    let collectionId = emojiKeywordColletionIdForCode(inputLanguageCode)
    
    let search: (Transaction) -> [EmojiKeywordItem] = { transaction in
        let items: [EmojiKeywordItem]
        let queryTokens = stringIndexTokens(query, transliteration: .none)
        let query: ItemCollectionSearchQuery = completeMatch ? .exact(queryTokens.first!) : .matching(queryTokens)
        items = transaction.searchItemCollection(namespace: Namespaces.ItemCollection.EmojiKeywords, query: query).filter { item -> Bool in
            if let item = item as? EmojiKeywordItem, item.collectionId == collectionId.id {
                return true
            } else {
                return false
            }
        } as! [EmojiKeywordItem]
        
        return items.sorted(by: { lhs, rhs -> Bool in
            if lhs.keyword.count == rhs.keyword.count {
                return lhs.keyword < rhs.keyword
            } else {
                return lhs.keyword.count < rhs.keyword.count
            }
        })
    }
    
    return postbox.transaction { transaction -> Signal<SearchEmojiKeywordsIntermediateResult, NoError> in
        let currentTime = Int32(CFAbsoluteTimeGetCurrent())
        let info = transaction.getItemCollectionInfo(collectionId: collectionId)
        if let info = info as? EmojiKeywordCollectionInfo {
            if info.timestamp + refreshTimeout < currentTime {
                addSynchronizeEmojiKeywordsOperation(transaction: transaction, inputLanguageCode: inputLanguageCode, languageCode: info.languageCode, fromVersion: info.version)
                return .single(.updating(timestamp: info.timestamp))
            } else {
                return .single(.completed(search(transaction)))
            }
        } else {
            addSynchronizeEmojiKeywordsOperation(transaction: transaction, inputLanguageCode: inputLanguageCode, languageCode: nil, fromVersion: nil)
            return .single(.updating(timestamp: nil))
        }
    }
    |> switchToLatest
    |> mapToSignal { intermediateResult -> Signal<[EmojiKeywordItem], NoError> in
        switch intermediateResult {
            case let .updating(timestamp):
                return postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.EmojiKeywords], aroundIndex: nil, count: 10)
                |> filter { view -> Bool in
                    for info in view.collectionInfos {
                        if let info = info.1 as? EmojiKeywordCollectionInfo, info.id == collectionId {
                            if let timestamp = timestamp {
                                return timestamp < info.timestamp
                            } else {
                                return true
                            }
                        }
                    }
                    return false
                }
                |> take(1)
                |> mapToSignal { view -> Signal<[EmojiKeywordItem], NoError> in
                    for info in view.collectionInfos {
                        if let info = info.1 as? EmojiKeywordCollectionInfo, info.id == collectionId {
                            return postbox.transaction { transaction -> [EmojiKeywordItem] in
                                return search(transaction)
                            }
                        }
                    }
                    return .complete()
                }
            case let .completed(items):
                return .single(items)
        }
    }
}
