import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif
import TelegramCorePrivateModule

private func hashForInfos(_ infos: [StickerPackCollectionInfo]) -> Int32 {
    var acc: UInt32 = 0
    
    for info in infos {
        acc = (acc &* 20261) &+ unsafeBitCast(info.hash, to: UInt32.self)
    }
    
    return unsafeBitCast(acc % UInt32(0x7FFFFFFF), to: Int32.self)
}

func manageStickerPacks(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    let currentHash = postbox.itemCollectionsView(namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 1)
        |> take(1)
        |> map { view -> Int32 in
            return hashForInfos(view.collectionInfos.map({ $0.1 as! StickerPackCollectionInfo }))
        }
    
    let remoteStickerPacks = currentHash
        |> mapToSignal { hash -> Signal<Void, NoError> in
            if hash != 0 {
                return .never()
            }
            
            return network.request(Api.functions.messages.getAllStickers(hash: hash))
                |> retryRequest
                |> mapToSignal { result -> Signal<Void, NoError> in
                    var stickerPackInfos: [StickerPackCollectionInfo] = []
                    switch result {
                        case let .allStickers(_, sets):
                            for apiPack in sets {
                                switch apiPack {
                                    case let .stickerSet(_, id, accessHash, title, shortName, _, nHash):
                                        stickerPackInfos.append(StickerPackCollectionInfo(id: ItemCollectionId(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: id), accessHash: accessHash, title: title, shortName: shortName, hash: nHash))
                                }
                            }
                            break
                        case .allStickersNotModified:
                            break
                    }
                    
                    var stickerPackItemSignals: [Signal<(ItemCollectionId, [ItemCollectionItem]), NoError>] = []
                    for info in stickerPackInfos {
                        let signal = network.request(Api.functions.messages.getStickerSet(stickerset: Api.InputStickerSet.inputStickerSetID(id: info.id.id, accessHash: info.accessHash)))
                            |> retryRequest
                            |> map { result -> (ItemCollectionId, [ItemCollectionItem]) in
                                var items: [ItemCollectionItem] = []
                                switch result {
                                    case let .stickerSet(_, _, documents):
                                        for apiDocument in documents {
                                            if let file = telegramMediaFileFromApiDocument(apiDocument), let id = file.id {
                                                items.append(StickerPackItem(index: ItemCollectionItemIndex(index: Int32(items.count), id: id.id), file: file))
                                            }
                                        }
                                        break
                                }
                                return (info.id, items)
                            }
                        stickerPackItemSignals.append(signal)
                    }
                    
                    return combineLatest(stickerPackItemSignals)
                        |> mapToSignal { results -> Signal<Void, NoError> in
                            var itemsByCollectionId: [ItemCollectionId: [ItemCollectionItem]] = [:]
                            for (collectionId, items) in results {
                                itemsByCollectionId[collectionId] = items
                            }
                            
                            var itemCollections: [(ItemCollectionId, ItemCollectionInfo, [ItemCollectionItem])] = []
                            
                            for info in stickerPackInfos {
                                if let items = itemsByCollectionId[info.id] {
                                    itemCollections.append((info.id, info, items))
                                }
                            }
                            
                            return postbox.modify { modifier -> Void in
                                modifier.replaceItemCollections(namespace: Namespaces.ItemCollection.CloudStickerPacks, itemCollections: itemCollections)
                            }
                        }
                }
        }
    
    return remoteStickerPacks
}
