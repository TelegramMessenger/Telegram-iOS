import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public final class FoundStickerItem: Equatable {
    public let file: TelegramMediaFile
    public let stringRepresentations: [String]
    
    public init(file: TelegramMediaFile, stringRepresentations: [String]) {
        self.file = file
        self.stringRepresentations = stringRepresentations
    }
    
    public static func ==(lhs: FoundStickerItem, rhs: FoundStickerItem) -> Bool {
        if !lhs.file.isEqual(rhs.file) {
            return false
        }
        if lhs.stringRepresentations != rhs.stringRepresentations {
            return false
        }
        return true
    }
}

extension MutableCollection {
    mutating func shuffle() {
        let c = count
        guard c > 1 else { return }
        for (firstUnshuffled, unshuffledCount) in zip(indices, stride(from: c, to: 1, by: -1)) {
            let d: IndexDistance = numericCast(arc4random_uniform(numericCast(unshuffledCount)))
            let i = index(firstUnshuffled, offsetBy: d)
            swapAt(firstUnshuffled, i)
        }
    }
}

extension Sequence {
    func shuffled() -> [Element] {
        var result = Array(self)
        result.shuffle()
        return result
    }
}


public func searchStickers(account: Account, query: String) -> Signal<[FoundStickerItem], NoError> {
    return account.viewTracker.featuredStickerPacks() |> mapToSignal { featured in
        return account.postbox.modify { modifier -> [FoundStickerItem] in
            var result: [FoundStickerItem] = []
            var idsSet = Set<MediaId>()
            
            for item in modifier.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentStickers) {
                if let stickerItem = item.contents as? RecentMediaItem {
                    if let file = stickerItem.media as? TelegramMediaFile, file.stickerString == query {
                        idsSet.insert(file.fileId)
                        result.append(FoundStickerItem(file: file, stringRepresentations: [query]))
                        if result.count == 5 {
                            break
                        }
                    }
                }
            }
            
            for item in modifier.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudSavedStickers) {
                if let stickerItem = item.contents as? SavedStickerItem {
                    for string in stickerItem.stringRepresentations {
                        if string == query, !idsSet.contains(stickerItem.file.fileId) {
                            idsSet.insert(stickerItem.file.fileId)
                            result.append(FoundStickerItem(file: stickerItem.file, stringRepresentations: stickerItem.stringRepresentations))
                        }
                    }
                }
            }
            
            for featured in featured.shuffled() {
                for item in featured.topItems {
                    if item.file.stickerString == query, !idsSet.contains(item.file.fileId) {
                        idsSet.insert(item.file.fileId)
                        result.append(FoundStickerItem(file: item.file, stringRepresentations: [query]))
                    }
                }
            }
            
            for item in modifier.searchItemCollection(namespace: Namespaces.ItemCollection.CloudStickerPacks, key: ValueBoxKey(query).toMemoryBuffer()) {
                if let item = item as? StickerPackItem {
                    if !idsSet.contains(item.file.fileId) {
                        idsSet.insert(item.file.fileId)
                        var stringRepresentations: [String] = []
                        for key in item.indexKeys {
                            key.withDataNoCopy { data in
                                if let string = String(data: data, encoding: .utf8) {
                                    stringRepresentations.append(string)
                                }
                            }
                        }
                        result.append(FoundStickerItem(file: item.file, stringRepresentations: stringRepresentations))
                    }
                }
            }
            return result
        }
    }
}

public struct FoundStickerSets {
    public let infos:[(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?, Bool)]
    public let entries: [ItemCollectionViewEntry]
    public init(infos:[(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?, Bool)] = [], entries: [ItemCollectionViewEntry] = []) {
        self.infos = infos
        self.entries = entries
    }
    
    public func withUpdatedInfosAndEntries(infos:[(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?, Bool)], entries: [ItemCollectionViewEntry]) -> FoundStickerSets {
        let infoResult = self.infos + infos
        let entriesResult = self.entries + entries
        return FoundStickerSets(infos: infoResult, entries: entriesResult)
    }
    
    public func merge(with other: FoundStickerSets) -> FoundStickerSets {
        return FoundStickerSets(infos: self.infos + other.infos, entries: self.entries + other.entries)
    }
}


public func searchStickerSetsRemotly(network: Network, query: String) -> Signal<FoundStickerSets, NoError> {
    return network.request(Api.functions.messages.searchStickerSets(flags: 0, q: query, hash: 0))
        |> mapError {_ in}
        |> mapToSignal { value in
            var index: Int32 = 1000
            switch value {
            case let .foundStickerSets(_, sets: sets):
                var result = FoundStickerSets()
                for set in sets {
                    let parsed = parsePreviewStickerSet(set)
                    let values = parsed.1.map({ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex(collectionIndex: index, collectionId: parsed.0.id, itemIndex: $0.index), item: $0)})
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

public func searchStickerSets(postbox: Postbox, query: String) -> Signal<FoundStickerSets, NoError> {
    return postbox.modify { modifier -> Signal<FoundStickerSets, NoError> in
        let infos = modifier.getItemCollectionsInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks)
        
        var collections: [(ItemCollectionId, ItemCollectionInfo)] = []
        var topItems:[ItemCollectionId: ItemCollectionItem] = [:]
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
            let items = modifier.getItemCollectionItems(collectionId: info.0)
            let values = items.map({ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex(collectionIndex: index, collectionId: info.0, itemIndex: $0.index), item: $0)})
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


public func searchGifs(account: Account, query: String) -> Signal<ChatContextResultCollection?, Void> {
    return resolvePeerByName(account: account, name: "gif")
        |> filter {$0 != nil}
        |> map {$0!}
        |> mapToSignal { peerId -> Signal<Peer, NoError> in
            return account.postbox.loadedPeerWithId(peerId)
        }
        |> mapToSignal { peer -> Signal<ChatContextResultCollection?, NoError> in
            return requestChatContextResults(account: account, botId: peer.id, peerId: account.peerId, query: query, offset: "")
    }
}
extension TelegramMediaFile {
    var stickerString:String? {
        for attr in attributes {
            if case let .Sticker(displayText, _, _) = attr {
                return displayText
            }
        }
        return nil
    }
}
