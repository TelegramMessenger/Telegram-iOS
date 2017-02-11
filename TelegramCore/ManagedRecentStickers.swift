import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

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

private func managedRecentMedia(postbox: Postbox, network: Network, collectionId: Int32, fetch: @escaping (Int32) -> Signal<[OrderedItemListEntry]?, NoError>) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Signal<Void, NoError> in
        let itemIds = modifier.getOrderedListItemIds(collectionId: collectionId).map {
            RecentMediaItemId($0).mediaId.id
        }
        return fetch(hashForIdsReverse(itemIds))
            |> mapToSignal { items in
                if let items = items {
                    return postbox.modify { modifier -> Void in
                        modifier.replaceOrderedItemListItems(collectionId: collectionId, items: items)
                    }
                } else {
                    return .complete()
                }
            }
    } |> switchToLatest
}

func managedRecentStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudRecentStickers, fetch: { hash in
        return network.request(Api.functions.messages.getRecentStickers(flags: 0, hash: hash))
            |> retryRequest
            |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
                switch result {
                    case .recentStickersNotModified:
                        return .single(nil)
                    case let .recentStickers(_, stickers):
                        var items: [OrderedItemListEntry] = []
                        for sticker in stickers {
                            if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: RecentMediaItem(file)))
                            }
                        }
                        return .single(items)
                }
            }
    })
}

func managedRecentGifs(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudRecentGifs, fetch: { hash in
        return network.request(Api.functions.messages.getSavedGifs(hash: hash))
            |> retryRequest
            |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
                switch result {
                    case .savedGifsNotModified:
                        return .single(nil)
                    case let .savedGifs(_, gifs):
                        var items: [OrderedItemListEntry] = []
                        for gif in gifs {
                            if let file = telegramMediaFileFromApiDocument(gif), let id = file.id {
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: RecentMediaItem(file)))
                            }
                        }
                        return .single(items)
                }
        }
    })
}
