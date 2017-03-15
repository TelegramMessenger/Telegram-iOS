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
        acc = UInt32(bitPattern: Int32(bitPattern: acc &* UInt32(20261)) &+ info.hash)
    }
    
    return Int32(bitPattern: acc % 0x7FFFFFFF)
}

func manageStickerPacks(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    let currentHash = postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 1)
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
                            for apiSet in sets {
                                stickerPackInfos.append(StickerPackCollectionInfo(apiSet: apiSet))
                            }
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
                                    case let .stickerSet(_, packs, documents):
                                        var indexKeysByFile: [MediaId: [MemoryBuffer]] = [:]
                                        //stickerPack#12b299d4 emoticon:string documents:Vector<long> = StickerPack;
                                        for pack in packs {
                                            switch pack {
                                                case let .stickerPack(text, fileIds):
                                                    let key = ValueBoxKey(text).toMemoryBuffer()
                                                    for fileId in fileIds {
                                                        let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                                        if indexKeysByFile[mediaId] == nil {
                                                            indexKeysByFile[mediaId] = [key]
                                                        } else {
                                                            indexKeysByFile[mediaId]!.append(key)
                                                        }
                                                    }
                                                    break
                                            }
                                        }
                                        
                                        for apiDocument in documents {
                                            if let file = telegramMediaFileFromApiDocument(apiDocument), let id = file.id {
                                                let fileIndexKeys: [MemoryBuffer]
                                                if let indexKeys = indexKeysByFile[id] {
                                                    fileIndexKeys = indexKeys
                                                } else {
                                                    fileIndexKeys = []
                                                }
                                                items.append(StickerPackItem(index: ItemCollectionItemIndex(index: Int32(items.count), id: id.id), file: file, indexKeys: fileIndexKeys))
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
