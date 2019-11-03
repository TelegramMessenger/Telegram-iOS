import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

import SyncCore

private func hashForIds(_ ids: [Int64]) -> Int32 {
    var acc: UInt32 = 0
    
    for id in ids {
        let low = UInt32(UInt64(bitPattern: id) & (0xffffffff as UInt64))
        let high = UInt32((UInt64(bitPattern: id) >> 32) & (0xffffffff as UInt64))
        
        acc = (acc &* 20261) &+ high
        acc = (acc &* 20261) &+ low
    }
    return Int32(bitPattern: acc & UInt32(0x7FFFFFFF))
}

private func managedRecentMedia(postbox: Postbox, network: Network, collectionId: Int32, reverseHashOrder: Bool, forceFetch: Bool, fetch: @escaping (Int32) -> Signal<[OrderedItemListEntry]?, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var itemIds = transaction.getOrderedListItemIds(collectionId: collectionId).map {
            RecentMediaItemId($0).mediaId.id
        }
        if reverseHashOrder {
            itemIds.reverse()
        }
        return fetch(forceFetch ? 0 : hashForIds(itemIds))
            |> mapToSignal { items in
                if let items = items {
                    return postbox.transaction { transaction -> Void in
                        transaction.replaceOrderedItemListItems(collectionId: collectionId, items: items)
                    }
                } else {
                    return .complete()
                }
            }
    } |> switchToLatest
}

func managedRecentStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudRecentStickers, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getRecentStickers(flags: 0, hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
            switch result {
                case .recentStickersNotModified:
                    return .single(nil)
                case let .recentStickers(_, _, stickers, _):
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

func managedRecentGifs(postbox: Postbox, network: Network, forceFetch: Bool = false) -> Signal<Void, NoError> {
    return managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudRecentGifs, reverseHashOrder: false, forceFetch: forceFetch, fetch: { hash in
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

func managedSavedStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudSavedStickers, reverseHashOrder: true, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getFavedStickers(hash: hash))
            |> retryRequest
            |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
                switch result {
                    case .favedStickersNotModified:
                        return .single(nil)
                    case let .favedStickers(_, packs, stickers):
                        var fileStringRepresentations: [MediaId: [String]] = [:]
                        for pack in packs {
                            switch pack {
                                case let .stickerPack(text, fileIds):
                                    for fileId in fileIds {
                                        let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                        if fileStringRepresentations[mediaId] == nil {
                                            fileStringRepresentations[mediaId] = [text]
                                        } else {
                                            fileStringRepresentations[mediaId]!.append(text)
                                        }
                                    }
                            }
                        }
                        
                        var items: [OrderedItemListEntry] = []
                        for sticker in stickers {
                            if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                                var stringRepresentations: [String] = []
                                if let representations = fileStringRepresentations[id] {
                                    stringRepresentations = representations
                                }
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: SavedStickerItem(file: file, stringRepresentations: stringRepresentations)))
                            }
                        }
                        return .single(items)
                }
        }
    })
}
