import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif
import TelegramCorePrivateModule

private func hashForIdsReverse(_ ids: [Int64]) -> Int32 {
    var acc: UInt32 = 0
    
    for id in ids {
        let low = UInt32(UInt64(bitPattern: id) & (0xffffffff as UInt64))
        let high = UInt32((UInt64(bitPattern: id) >> 32) & (0xffffffff as UInt64))
        
        acc = (acc &* 20261) &+ high
        acc = (acc &* 20261) &+ low
    }
    return Int32(bitPattern: acc % UInt32(0x7FFFFFFF))
}

func manageStickerPacks(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return (postbox.modify { modifier -> Void in
        addSynchronizeInstalledStickerPacksOperation(modifier: modifier, namespace: .stickers)
        addSynchronizeInstalledStickerPacksOperation(modifier: modifier, namespace: .masks)
        addSynchronizeSavedGifsOperation(modifier: modifier, operation: .sync)
        addSynchronizeSavedStickersOperation(modifier: modifier, operation: .sync)
    } |> then(.complete() |> delay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func updatedFeaturedStickerPacks(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Signal<Void, NoError> in
        let initialPacks = modifier.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
        var initialPackMap: [Int64: FeaturedStickerPackItem] = [:]
        for entry in initialPacks {
            let item = entry.contents as! FeaturedStickerPackItem
            initialPackMap[FeaturedStickerPackItemId(entry.id).packId] = item
        }
        
        let initialPackIds = initialPacks.map {
            return FeaturedStickerPackItemId($0.id).packId
        }
        let initialHash: Int32 = hashForIdsReverse(initialPackIds)
        return network.request(Api.functions.messages.getFeaturedStickers(hash: initialHash))
            |> retryRequest
            |> mapToSignal { result -> Signal<Void, NoError> in
                return postbox.modify { modifier -> Void in
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
                            modifier.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, items: updatedPacks.map { OrderedItemListEntry(id: FeaturedStickerPackItemId($0.info.id.id).rawValue, contents: $0) })
                    }
                }
            }
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
