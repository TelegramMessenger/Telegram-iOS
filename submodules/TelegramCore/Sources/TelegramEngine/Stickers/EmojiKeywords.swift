import Foundation
import Postbox
import SwiftSignalKit


private let refreshTimeout: Int32 = 60 * 60

private enum SearchEmojiKeywordsIntermediateResult {
    case updating(timestamp: Int32?)
    case completed([EmojiKeywordItem])
}

func _internal_searchEmojiKeywords(postbox: Postbox, inputLanguageCode: String, query: String, completeMatch: Bool) -> Signal<[EmojiKeywordItem], NoError> {
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return .single([])
    }
    let collectionId = emojiKeywordColletionIdForCode(inputLanguageCode)
    
    let search: (Transaction) -> [EmojiKeywordItem] = { transaction in
        let queryTokens = stringIndexTokens(query, transliteration: .none)
        if let firstQueryToken = queryTokens.first {
            let query: ItemCollectionSearchQuery = completeMatch ? .exact(firstQueryToken) : .matching(queryTokens)
            let items = transaction.searchItemCollection(namespace: Namespaces.ItemCollection.EmojiKeywords, query: query).filter { item -> Bool in
                if let item = item as? EmojiKeywordItem, item.collectionId == collectionId.id {
                    return true
                } else {
                    return false
                }
            } as? [EmojiKeywordItem]
            
            if let items = items {
                return items.sorted(by: { lhs, rhs -> Bool in
                    if lhs.keyword.count == rhs.keyword.count {
                        return lhs.keyword < rhs.keyword
                    } else {
                        return lhs.keyword.count < rhs.keyword.count
                    }
                })
            }
        }
        return []
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
