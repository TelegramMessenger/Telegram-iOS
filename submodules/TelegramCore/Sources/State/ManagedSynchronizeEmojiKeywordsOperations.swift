import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit


private final class ManagedSynchronizeEmojiKeywordsOperationHelper {
    var operationDisposables: [Int32: Disposable] = [:]
    
    func update(_ entries: [PeerMergedOperationLogEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validMergedIndices = Set<Int32>()
        for entry in entries {
            if !hasRunningOperationForPeerId.contains(entry.peerId) {
                hasRunningOperationForPeerId.insert(entry.peerId)
                validMergedIndices.insert(entry.mergedIndex)
                
                if self.operationDisposables[entry.mergedIndex] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.mergedIndex] = disposable
                }
            }
        }
        
        var removeMergedIndices: [Int32] = []
        for (mergedIndex, disposable) in self.operationDisposables {
            if !validMergedIndices.contains(mergedIndex) {
                removeMergedIndices.append(mergedIndex)
                disposeOperations.append(disposable)
            }
        }
        
        for mergedIndex in removeMergedIndices {
            self.operationDisposables.removeValue(forKey: mergedIndex)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SynchronizeEmojiKeywords, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeEmojiKeywordsOperation {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
    } |> switchToLatest
}

func managedSynchronizeEmojiKeywordsOperations(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let tag = OperationLogTags.SynchronizeEmojiKeywords
    return Signal { _ in
        let helper = Atomic<ManagedSynchronizeEmojiKeywordsOperationHelper>(value: ManagedSynchronizeEmojiKeywordsOperationHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizeEmojiKeywordsOperation {
                            let collectionId = emojiKeywordColletionIdForCode(operation.inputLanguageCode)
                            return synchronizeEmojiKeywords(postbox: postbox, transaction: transaction, network: network, operation: operation, collectionId: collectionId)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(postbox.transaction { transaction -> Void in
                    let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
                })
                
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

private func keywordCollectionItemId(_ keyword: String, inputLanguageCode: String) -> Int64 {
    let namespace = HashFunctions.murMurHash32(inputLanguageCode)
    let id = HashFunctions.murMurHash32(keyword)
    return (Int64(namespace) << 32) | Int64(bitPattern: UInt64(UInt32(bitPattern: id)))
}

private func synchronizeEmojiKeywords(postbox: Postbox, transaction: Transaction, network: Network, operation: SynchronizeEmojiKeywordsOperation, collectionId: ItemCollectionId) -> Signal<Void, NoError> {
    if let languageCode = operation.languageCode, let fromVersion = operation.fromVersion {
        return network.request(Api.functions.messages.getEmojiKeywordsDifference(langCode: languageCode, fromVersion: fromVersion))
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            switch result {
                case let .emojiKeywordsDifference(langCode, _, version, keywords):
                    if langCode == languageCode {
                        var itemsToAppend: [String: EmojiKeywordItem] = [:]
                        var itemsToSubtract: [String: EmojiKeywordItem] = [:]
                        for apiEmojiKeyword in keywords {
                            switch apiEmojiKeyword {
                                case let .emojiKeyword(keyword, emoticons):
                                    let keyword = keyword.replacingOccurrences(of: " ", with: "")
                                    let indexKeys = stringIndexTokens(keyword, transliteration: .none).map { $0.toMemoryBuffer() }
                                    let item = EmojiKeywordItem(index: ItemCollectionItemIndex(index: 0, id: 0), collectionId: collectionId.id, keyword: keyword, emoticons: emoticons, indexKeys: indexKeys)
                                    itemsToAppend[keyword] = item
                                case let .emojiKeywordDeleted(keyword, emoticons):
                                    let item = EmojiKeywordItem(index: ItemCollectionItemIndex(index: 0, id: 0), collectionId: collectionId.id, keyword: keyword, emoticons: emoticons, indexKeys: [])
                                    itemsToSubtract[keyword] = item
                            }
                        }
                        let info = EmojiKeywordCollectionInfo(languageCode: langCode, inputLanguageCode: operation.inputLanguageCode, version: version, timestamp: Int32(CFAbsoluteTimeGetCurrent()))
                        return postbox.transaction { transaction -> Void in
                            var updatedInfos = transaction.getItemCollectionsInfos(namespace: info.id.namespace).map { $0.1 as! EmojiKeywordCollectionInfo }
                            if let index = updatedInfos.firstIndex(where: { $0.id == info.id }) {
                                updatedInfos.remove(at: index)
                            }
                            updatedInfos.append(info)
                            
                            if fromVersion != version {
                                let currentItems = transaction.getItemCollectionItems(collectionId: collectionId)
                                var updatedItems: [EmojiKeywordItem] = []
                                
                                var index: Int32 = 0
                                for case let item as EmojiKeywordItem in currentItems {
                                    var updatedEmoticons = item.emoticons
                                    var existingEmoticons = Set(item.emoticons)
                                    if let appendedItem = itemsToAppend[item.keyword] {
                                        for emoticon in appendedItem.emoticons {
                                            if !existingEmoticons.contains(emoticon) {
                                                existingEmoticons.insert(emoticon)
                                                updatedEmoticons.append(emoticon)
                                            }
                                        }
                                        itemsToAppend.removeValue(forKey: item.keyword)
                                    }
                                    if let subtractedItem = itemsToSubtract[item.keyword] {
                                        let substractedEmoticons = Set(subtractedItem.emoticons)
                                        updatedEmoticons = updatedEmoticons.filter { !substractedEmoticons.contains($0) }
                                    }
                                    if !updatedEmoticons.isEmpty {
                                        updatedItems.append(EmojiKeywordItem(index: ItemCollectionItemIndex(index: index, id: keywordCollectionItemId(item.keyword, inputLanguageCode: operation.inputLanguageCode)), collectionId: item.collectionId, keyword: item.keyword, emoticons: updatedEmoticons, indexKeys: item.indexKeys))
                                        index += 1
                                    }
                                }
                                
                                for (_, item) in itemsToAppend where !item.emoticons.isEmpty {
                                    updatedItems.append(EmojiKeywordItem(index: ItemCollectionItemIndex(index: index, id: keywordCollectionItemId(item.keyword, inputLanguageCode: operation.inputLanguageCode)), collectionId: collectionId.id, keyword: item.keyword, emoticons: item.emoticons, indexKeys: item.indexKeys))
                                    index += 1
                                }
                                
                                transaction.replaceItemCollectionItems(collectionId: info.id, items: updatedItems)
                            }
                            transaction.replaceItemCollectionInfos(namespace: info.id.namespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
                        }
                    } else {
                        return postbox.transaction { transaction in
                            addSynchronizeEmojiKeywordsOperation(transaction: transaction, inputLanguageCode: operation.inputLanguageCode, languageCode: nil, fromVersion: nil)
                        }
                    }
            }
        }
    } else {
        return network.request(Api.functions.messages.getEmojiKeywords(langCode: operation.inputLanguageCode))
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            switch result {
                case let .emojiKeywordsDifference(langCode, _, version, keywords):
                    var items: [EmojiKeywordItem] = []
                    var index: Int32 = 0
                    for apiEmojiKeyword in keywords {
                        if case let .emojiKeyword(keyword, emoticons) = apiEmojiKeyword, !emoticons.isEmpty {
                            let keyword = keyword.replacingOccurrences(of: " ", with: "")
                            let indexKeys = stringIndexTokens(keyword, transliteration: .none).map { $0.toMemoryBuffer() }
                            let item = EmojiKeywordItem(index: ItemCollectionItemIndex(index: index, id: keywordCollectionItemId(keyword, inputLanguageCode: operation.inputLanguageCode)), collectionId: collectionId.id, keyword: keyword, emoticons: emoticons, indexKeys: indexKeys)
                            items.append(item)
                        }
                        index += 1
                    }
                    let info = EmojiKeywordCollectionInfo(languageCode: langCode, inputLanguageCode: operation.inputLanguageCode, version: version, timestamp: Int32(CFAbsoluteTimeGetCurrent()))
                    return postbox.transaction { transaction -> Void in
                        var updatedInfos = transaction.getItemCollectionsInfos(namespace: info.id.namespace).map { $0.1 as! EmojiKeywordCollectionInfo }
                        if let index = updatedInfos.firstIndex(where: { $0.id == info.id }) {
                            updatedInfos.remove(at: index)
                        }
                        updatedInfos.append(info)
                        
                        transaction.replaceItemCollectionInfos(namespace: info.id.namespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
                        transaction.replaceItemCollectionItems(collectionId: info.id, items: items)
                    }
            }
        }
    }
}
