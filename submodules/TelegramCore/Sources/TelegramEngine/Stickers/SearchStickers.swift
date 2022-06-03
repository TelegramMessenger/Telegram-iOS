import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

private struct SearchStickersConfiguration {
    static var defaultValue: SearchStickersConfiguration {
        return SearchStickersConfiguration(cacheTimeout: 86400)
    }
    
    public let cacheTimeout: Int32
    
    fileprivate init(cacheTimeout: Int32) {
        self.cacheTimeout = cacheTimeout
    }
    
    static func with(appConfiguration: AppConfiguration) -> SearchStickersConfiguration {
        if let data = appConfiguration.data, let value = data["stickers_emoji_cache_time"] as? Double {
            return SearchStickersConfiguration(cacheTimeout: Int32(value))
        } else {
            return .defaultValue
        }
    }
}

public final class FoundStickerItem: Equatable {
    public let file: TelegramMediaFile
    public let stringRepresentations: [String]
    
    public init(file: TelegramMediaFile, stringRepresentations: [String]) {
        self.file = file
        self.stringRepresentations = stringRepresentations
    }
    
    public static func ==(lhs: FoundStickerItem, rhs: FoundStickerItem) -> Bool {
        if !lhs.file.isEqual(to: rhs.file) {
            return false
        }
        if lhs.stringRepresentations != rhs.stringRepresentations {
            return false
        }
        return true
    }
}

public struct SearchStickersScope: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let installed = SearchStickersScope(rawValue: 1 << 0)
    public static let remote = SearchStickersScope(rawValue: 1 << 1)
}

func _internal_randomGreetingSticker(account: Account) -> Signal<FoundStickerItem?, NoError> {
    let key: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudGreetingStickers)
    return account.postbox.combinedView(keys: [key])
    |> map { views -> [OrderedItemListEntry]? in
        if let view = views.views[key] as? OrderedItemListView, !view.items.isEmpty {
            return view.items
        } else {
            return nil
        }
    }
    |> filter { items in
        return items != nil
    }
    |> take(1)
    |> map { items -> FoundStickerItem? in
        if let randomItem = items?.randomElement(), let item = randomItem.contents.get(RecentMediaItem.self) {
            let file = item.media
            return FoundStickerItem(file: file, stringRepresentations: [])
        }
        return nil
    }
}

func _internal_searchStickers(account: Account, query: String, scope: SearchStickersScope = [.installed, .remote]) -> Signal<[FoundStickerItem], NoError> {
    if scope.isEmpty {
        return .single([])
    }
    var query = query
    if query == "\u{2764}" {
        query = "\u{2764}\u{FE0F}"
    }
    return account.postbox.transaction { transaction -> ([FoundStickerItem], CachedStickerQueryResult?, Bool) in
        let isPremium = transaction.getPeer(account.peerId)?.isPremium ?? false
        
        var result: [FoundStickerItem] = []
        if scope.contains(.installed) {
            for entry in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudSavedStickers) {
                if let item = entry.contents.get(SavedStickerItem.self) {
                    for representation in item.stringRepresentations {
                        if representation.hasPrefix(query) {
                            result.append(FoundStickerItem(file: item.file, stringRepresentations: item.stringRepresentations))
                            break
                        }
                    }
                }
            }
            
            let currentItems = Set<MediaId>(result.map { $0.file.fileId })
            var recentItems: [TelegramMediaFile] = []
            var recentAnimatedItems: [TelegramMediaFile] = []
            var recentItemsIds = Set<MediaId>()
            var matchingRecentItemsIds = Set<MediaId>()
            
            for entry in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentStickers) {
                if let item = entry.contents.get(RecentMediaItem.self) {
                    let file = item.media
                    if file.isPremiumSticker && !isPremium {
                        continue
                    }

                    if !currentItems.contains(file.fileId) {
                        for case let .Sticker(displayText, _, _) in file.attributes {
                            if displayText.hasPrefix(query) {
                                matchingRecentItemsIds.insert(file.fileId)
                            }
                            recentItemsIds.insert(file.fileId)
                            if file.isAnimatedSticker || file.isVideoSticker {
                                recentAnimatedItems.append(file)
                            } else {
                                recentItems.append(file)
                            }
                            break
                        }
                    }
                }
            }
            
            var searchQuery: ItemCollectionSearchQuery = .exact(ValueBoxKey(query))
            if query == "\u{2764}" {
                searchQuery = .any([ValueBoxKey("\u{2764}"), ValueBoxKey("\u{2764}\u{FE0F}")])
            }
            
            var installedItems: [FoundStickerItem] = []
            var installedAnimatedItems: [FoundStickerItem] = []
            for item in transaction.searchItemCollection(namespace: Namespaces.ItemCollection.CloudStickerPacks, query: searchQuery) {
                if let item = item as? StickerPackItem {
                    if item.file.isPremiumSticker && !isPremium {
                        continue
                    }
                    
                    if !currentItems.contains(item.file.fileId) {
                        var stringRepresentations: [String] = []
                        for key in item.indexKeys {
                            key.withDataNoCopy { data in
                                if let string = String(data: data, encoding: .utf8) {
                                    stringRepresentations.append(string)
                                }
                            }
                        }
                        if !recentItemsIds.contains(item.file.fileId) {
                            if item.file.isAnimatedSticker || item.file.isVideoSticker {
                                installedAnimatedItems.append(FoundStickerItem(file: item.file, stringRepresentations: stringRepresentations))
                            } else {
                                installedItems.append(FoundStickerItem(file: item.file, stringRepresentations: stringRepresentations))
                            }
                        } else {
                            matchingRecentItemsIds.insert(item.file.fileId)
                        }
                    }
                }
            }
            
            for file in recentAnimatedItems {
                if file.isPremiumSticker && !isPremium {
                    continue
                }
                if matchingRecentItemsIds.contains(file.fileId) {
                    result.append(FoundStickerItem(file: file, stringRepresentations: [query]))
                }
            }
            
            for file in recentItems {
                if file.isPremiumSticker && !isPremium {
                    continue
                }
                if matchingRecentItemsIds.contains(file.fileId) {
                    result.append(FoundStickerItem(file: file, stringRepresentations: [query]))
                }
            }
            
            result.append(contentsOf: installedAnimatedItems)
            result.append(contentsOf: installedItems)
        }
        
        var cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerQueryResults, key: CachedStickerQueryResult.cacheKey(query)))?.get(CachedStickerQueryResult.self)
        
        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        let appConfiguration: AppConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
        let searchStickersConfiguration = SearchStickersConfiguration.with(appConfiguration: appConfiguration)
        
        if let currentCached = cached, currentTime > currentCached.timestamp + searchStickersConfiguration.cacheTimeout {
            cached = nil
        }
        
        return (result, cached, isPremium)
    } |> mapToSignal { localItems, cached, isPremium -> Signal<[FoundStickerItem], NoError> in
        var tempResult: [FoundStickerItem] = localItems
        if !scope.contains(.remote) {
            return .single(tempResult)
        }
        let currentItemIds = Set<MediaId>(localItems.map { $0.file.fileId })
        
        if let cached = cached {
            var cachedItems: [FoundStickerItem] = []
            var cachedAnimatedItems: [FoundStickerItem] = []
            
            for file in cached.items {
                if file.isPremiumSticker && !isPremium {
                    continue
                }
                if !currentItemIds.contains(file.fileId) {
                    if file.isAnimatedSticker || file.isVideoSticker {
                        cachedAnimatedItems.append(FoundStickerItem(file: file, stringRepresentations: []))
                    } else {
                        cachedItems.append(FoundStickerItem(file: file, stringRepresentations: []))
                    }
                }
            }
            
            tempResult.append(contentsOf: cachedAnimatedItems)
            tempResult.append(contentsOf: cachedItems)
        }
        
        let remote = account.network.request(Api.functions.messages.getStickers(emoticon: query, hash: cached?.hash ?? 0))
        |> `catch` { _ -> Signal<Api.messages.Stickers, NoError> in
            return .single(.stickersNotModified)
        }
        |> mapToSignal { result -> Signal<[FoundStickerItem], NoError> in
            return account.postbox.transaction { transaction -> [FoundStickerItem] in
                switch result {
                    case let .stickers(hash, stickers):
                        var items: [FoundStickerItem] = []
                        var animatedItems: [FoundStickerItem] = []
                        
                        var result: [FoundStickerItem] = localItems
                        let currentItemIds = Set<MediaId>(result.map { $0.file.fileId })
                        
                        var files: [TelegramMediaFile] = []
                        for sticker in stickers {
                            if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                                if file.isPremiumSticker && !isPremium {
                                    continue
                                }
                                files.append(file)
                                if !currentItemIds.contains(id) {
                                    if file.isAnimatedSticker || file.isVideoSticker {
                                        animatedItems.append(FoundStickerItem(file: file, stringRepresentations: []))
                                    } else {
                                        items.append(FoundStickerItem(file: file, stringRepresentations: []))
                                    }
                                }
                            }
                        }
                        
                        result.append(contentsOf: animatedItems)
                        result.append(contentsOf: items)
                        
                        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        if let entry = CodableEntry(CachedStickerQueryResult(items: files, hash: hash, timestamp: currentTime)) {
                            transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerQueryResults, key: CachedStickerQueryResult.cacheKey(query)), entry: entry)
                        }
                    
                        return result
                    case .stickersNotModified:
                        break
                }
                return tempResult
            }
        }
        return .single(tempResult)
        |> then(remote)
    }
}

public struct FoundStickerSets {
    public var infos: [(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?, Bool)]
    public let entries: [ItemCollectionViewEntry]
    public init(infos: [(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?, Bool)] = [], entries: [ItemCollectionViewEntry] = []) {
        self.infos = infos
        self.entries = entries
    }
    
    public func withUpdatedInfosAndEntries(infos: [(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?, Bool)], entries: [ItemCollectionViewEntry]) -> FoundStickerSets {
        let infoResult = self.infos + infos
        let entriesResult = self.entries + entries
        return FoundStickerSets(infos: infoResult, entries: entriesResult)
    }
    
    public func merge(with other: FoundStickerSets) -> FoundStickerSets {
        return FoundStickerSets(infos: self.infos + other.infos, entries: self.entries + other.entries)
    }
}

func _internal_searchStickerSetsRemotely(network: Network, query: String) -> Signal<FoundStickerSets, NoError> {
    return network.request(Api.functions.messages.searchStickerSets(flags: 0, q: query, hash: 0))
        |> mapError {_ in}
        |> mapToSignal { value in
            var index: Int32 = 1000
            switch value {
            case let .foundStickerSets(_, sets: sets):
                var result = FoundStickerSets()
                for set in sets {
                    let parsed = parsePreviewStickerSet(set)
                    let values = parsed.1.map({ ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex(collectionIndex: index, collectionId: parsed.0.id, itemIndex: $0.index), item: $0) })
                    result = result.withUpdatedInfosAndEntries(infos: [(parsed.0.id, parsed.0, parsed.1.first, false)], entries: values)
                    index += 1
                }
                return .single(result)
            default:
                break
            }
            
            return .complete()
        }
        |> `catch` { _ -> Signal<FoundStickerSets, NoError> in
            return .single(FoundStickerSets())
    }
}

func _internal_searchStickerSets(postbox: Postbox, query: String) -> Signal<FoundStickerSets, NoError> {
    return postbox.transaction { transaction -> Signal<FoundStickerSets, NoError> in
        let infos = transaction.getItemCollectionsInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks)
        
        var collections: [(ItemCollectionId, ItemCollectionInfo)] = []
        var topItems: [ItemCollectionId: ItemCollectionItem] = [:]
        var entries: [ItemCollectionViewEntry] = []
        for info in infos {
            if let info = info.1 as? StickerPackCollectionInfo {
                let split = info.title.split(separator: " ")
                if !split.filter({$0.lowercased().hasPrefix(query.lowercased())}).isEmpty || info.shortName.lowercased().hasPrefix(query.lowercased()) {
                    collections.append((info.id, info))
                }
            }
        }
        var index: Int32 = 0
        
        for info in collections {
            let items = transaction.getItemCollectionItems(collectionId: info.0)
            let values = items.map({ ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex(collectionIndex: index, collectionId: info.0, itemIndex: $0.index), item: $0) })
            entries.append(contentsOf: values)
            if let first = items.first {
                topItems[info.0] = first
            }
            index += 1
        }
        
        let result = FoundStickerSets(infos: collections.map { ($0.0, $0.1, topItems[$0.0], true) }, entries: entries)
        
        return .single(result)
    } |> switchToLatest
}

func _internal_searchGifs(account: Account, query: String, nextOffset: String = "") -> Signal<ChatContextResultCollection?, NoError> {
   return account.postbox.transaction { transaction -> String in
        let configuration = currentSearchBotsConfiguration(transaction: transaction)
        return configuration.gifBotUsername ?? "gif"
    } |> mapToSignal {
         return _internal_resolvePeerByName(account: account, name: $0)
    } |> filter { $0 != nil }
    |> map { $0! }
    |> mapToSignal { peerId -> Signal<Peer, NoError> in
        return account.postbox.loadedPeerWithId(peerId)
    }
    |> mapToSignal { peer -> Signal<ChatContextResultCollection?, NoError> in
        return _internal_requestChatContextResults(account: account, botId: peer.id, peerId: account.peerId, query: query, offset: nextOffset)
        |> map { results -> ChatContextResultCollection? in
            return results?.results
        }
        |> `catch` { error -> Signal<ChatContextResultCollection?, NoError> in
            return .single(nil)
        }
    }
}

extension TelegramMediaFile {
    var stickerString: String? {
        for attr in attributes {
            if case let .Sticker(displayText, _, _) = attr {
                return displayText
            }
        }
        return nil
    }
}
