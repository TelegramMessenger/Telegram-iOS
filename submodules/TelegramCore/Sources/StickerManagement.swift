import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

import SyncCore

private func hashForIdsReverse(_ ids: [Int64]) -> Int32 {
    var acc: UInt32 = 0
    
    for id in ids {
        let low = UInt32(UInt64(bitPattern: id) & (0xffffffff as UInt64))
        let high = UInt32((UInt64(bitPattern: id) >> 32) & (0xffffffff as UInt64))
        
        acc = (acc &* 20261) &+ high
        acc = (acc &* 20261) &+ low
    }
    return Int32(bitPattern: acc & UInt32(0x7FFFFFFF))
}

func manageStickerPacks(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return (postbox.transaction { transaction -> Void in
        addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .stickers, content: .sync)
        addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .masks, content: .sync)
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
            let item = entry.contents as! FeaturedStickerPackItem
            initialPackMap[FeaturedStickerPackItemId(entry.id).packId] = item
        }
        
        let initialPackIds = initialPacks.map {
            return FeaturedStickerPackItemId($0.id).packId
        }
        let initialHash: Int32 = hashForIdsReverse(initialPackIds)
        return network.request(Api.functions.messages.getFeaturedStickers(hash: 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                switch result {
                    case .featuredStickersNotModified:
                        break
                    case let .featuredStickers(_, sets, unread):
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
                        transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, items: updatedPacks.map { OrderedItemListEntry(id: FeaturedStickerPackItemId($0.info.id.id).rawValue, contents: $0) })
                }
            }
        }
    } |> switchToLatest
}

public func preloadedFeaturedStickerSet(network: Network, postbox: Postbox, id: ItemCollectionId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let pack = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, itemId: FeaturedStickerPackItemId(id.id).rawValue)?.contents as? FeaturedStickerPackItem {
            if pack.topItems.count < 5 && pack.topItems.count < pack.info.count {
                return requestStickerSet(postbox: postbox, network: network, reference: .id(id: pack.info.id.id, accessHash: pack.info.accessHash))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<RequestStickerSetResult?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    if let result = result {
                        return postbox.transaction { transaction -> Void in
                            if let pack = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, itemId: FeaturedStickerPackItemId(id.id).rawValue)?.contents as? FeaturedStickerPackItem {
                                var items = result.items.map({ $0 as? StickerPackItem }).flatMap({ $0 })
                                if items.count > 5 {
                                    items.removeSubrange(5 ..< items.count)
                                }
                                transaction.updateOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, itemId: FeaturedStickerPackItemId(id.id).rawValue, item: FeaturedStickerPackItem(info: pack.info, topItems: items, unread: pack.unread))
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

func parsePreviewStickerSet(_ set: Api.StickerSetCovered) -> (StickerPackCollectionInfo, [StickerPackItem]) {
    switch set {
        case let .stickerSetCovered(set, cover):
            let info = StickerPackCollectionInfo(apiSet: set, namespace: Namespaces.ItemCollection.CloudStickerPacks)
            var items: [StickerPackItem] = []
            if let file = telegramMediaFileFromApiDocument(cover), let id = file.id {
                items.append(StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: id.id), file: file, indexKeys: []))
            }
            return (info, items)
        case let .stickerSetMultiCovered(set, covers):
            let info = StickerPackCollectionInfo(apiSet: set, namespace: Namespaces.ItemCollection.CloudStickerPacks)
            var items: [StickerPackItem] = []
            for cover in covers {
                if let file = telegramMediaFileFromApiDocument(cover), let id = file.id {
                    items.append(StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: id.id), file: file, indexKeys: []))
                }
            }
            return (info, items)
    }
}
