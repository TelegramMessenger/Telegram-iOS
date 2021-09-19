import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit


private func hashForIdsReverse(_ ids: [Int64]) -> Int64 {
    var acc: UInt64 = 0
    
    for id in ids {
        combineInt64Hash(&acc, with: UInt64(bitPattern: id))
    }
    return Int64(bitPattern: acc)
}

func manageStickerPacks(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return (postbox.transaction { transaction -> Void in
        addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .stickers, content: .sync, noDelay: false)
        addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .masks, content: .sync, noDelay: false)
        addSynchronizeSavedGifsOperation(transaction: transaction, operation: .sync)
        addSynchronizeSavedStickersOperation(transaction: transaction, operation: .sync)
        addSynchronizeRecentlyUsedMediaOperation(transaction: transaction, category: .stickers, operation: .sync)
    } |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func updatedFeaturedStickerPacks(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        let initialPacks = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
        var initialPackMap: [Int64: FeaturedStickerPackItem] = [:]
        for entry in initialPacks {
            let item = entry.contents.get(FeaturedStickerPackItem.self)!
            initialPackMap[FeaturedStickerPackItemId(entry.id).packId] = item
        }
        
        let initialPackIds = initialPacks.map {
            return FeaturedStickerPackItemId($0.id).packId
        }
        let initialHash: Int64 = hashForIdsReverse(initialPackIds)
        return network.request(Api.functions.messages.getFeaturedStickers(hash: initialHash))
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                switch result {
                case .featuredStickersNotModified:
                    break
                case let .featuredStickers(_, _, sets, unread):
                    let unreadIds = Set(unread)
                    var updatedPacks: [FeaturedStickerPackItem] = []
                    for set in sets {
                        var (info, items) = parsePreviewStickerSet(set)
                        if let previousPack = initialPackMap[info.id.id] {
                            if previousPack.info.hash == info.hash {
                                items = previousPack.topItems
                            }
                        }
                        updatedPacks.append(FeaturedStickerPackItem(info: info, topItems: items, unread: unreadIds.contains(info.id.id)))
                    }
                    transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, items: updatedPacks.compactMap { item -> OrderedItemListEntry? in
                        if let entry = CodableEntry(item) {
                            return OrderedItemListEntry(id: FeaturedStickerPackItemId(item.info.id.id).rawValue, contents: entry)
                        } else {
                            return nil
                        }
                    })
                }
            }
        }
    } |> switchToLatest
}

public func requestOldFeaturedStickerPacks(network: Network, postbox: Postbox, offset: Int, limit: Int) -> Signal<[FeaturedStickerPackItem], NoError> {
    return network.request(Api.functions.messages.getOldFeaturedStickers(offset: Int32(offset), limit: Int32(limit), hash: 0))
    |> retryRequest
    |> map { result -> [FeaturedStickerPackItem] in
        switch result {
        case .featuredStickersNotModified:
            return []
        case let .featuredStickers(_, _, sets, unread):
            let unreadIds = Set(unread)
            var updatedPacks: [FeaturedStickerPackItem] = []
            for set in sets {
                let (info, items) = parsePreviewStickerSet(set)
                updatedPacks.append(FeaturedStickerPackItem(info: info, topItems: items, unread: unreadIds.contains(info.id.id)))
            }
            return updatedPacks
        }
    }
}

public func preloadedFeaturedStickerSet(network: Network, postbox: Postbox, id: ItemCollectionId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let pack = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, itemId: FeaturedStickerPackItemId(id.id).rawValue)?.contents.get(FeaturedStickerPackItem.self) {
            if pack.topItems.count < 5 && pack.topItems.count < pack.info.count {
                return _internal_requestStickerSet(postbox: postbox, network: network, reference: .id(id: pack.info.id.id, accessHash: pack.info.accessHash))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<RequestStickerSetResult?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    if let result = result {
                        return postbox.transaction { transaction -> Void in
                            if let pack = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, itemId: FeaturedStickerPackItemId(id.id).rawValue)?.contents.get(FeaturedStickerPackItem.self) {
                                var items = result.items.map({ $0 as? StickerPackItem }).compactMap({ $0 })
                                if items.count > 5 {
                                    items.removeSubrange(5 ..< items.count)
                                }
                                if let entry = CodableEntry(FeaturedStickerPackItem(info: pack.info, topItems: items, unread: pack.unread)) {
                                    transaction.updateOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, itemId: FeaturedStickerPackItemId(id.id).rawValue, item: entry)
                                }
                            }
                        }
                    } else {
                        return .complete()
                    }
                }
            }
        }
        return .complete()
    } |> switchToLatest
}

func parsePreviewStickerSet(_ set: Api.StickerSetCovered, namespace: ItemCollectionId.Namespace = Namespaces.ItemCollection.CloudStickerPacks) -> (StickerPackCollectionInfo, [StickerPackItem]) {
    switch set {
        case let .stickerSetCovered(set, cover):
            let info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)
            var items: [StickerPackItem] = []
            if let file = telegramMediaFileFromApiDocument(cover), let id = file.id {
                items.append(StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: id.id), file: file, indexKeys: []))
            }
            return (info, items)
        case let .stickerSetMultiCovered(set, covers):
            let info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)
            var items: [StickerPackItem] = []
            for cover in covers {
                if let file = telegramMediaFileFromApiDocument(cover), let id = file.id {
                    items.append(StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: id.id), file: file, indexKeys: []))
                }
            }
            return (info, items)
    }
}
