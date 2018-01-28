import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

extension StickerPackReference {
    init(_ stickerPackInfo: StickerPackCollectionInfo) {
        self = .id(id: stickerPackInfo.id.id, accessHash: stickerPackInfo.accessHash)
    }
    
    var apiInputStickerSet: Api.InputStickerSet {
        switch self {
            case let .id(id, accessHash):
                return .inputStickerSetID(id: id, accessHash: accessHash)
            case let .name(name):
                return .inputStickerSetShortName(shortName: name)
        }
    }
}

public enum LoadedStickerPack {
    case fetching
    case none
    case result(info: StickerPackCollectionInfo, items: [ItemCollectionItem], installed: Bool)
}

func remoteStickerPack(network: Network, reference: StickerPackReference) -> Signal<(StickerPackCollectionInfo, [ItemCollectionItem])?, NoError> {
    return network.request(Api.functions.messages.getStickerSet(stickerset: reference.apiInputStickerSet))
        |> map { Optional($0) }
        |> `catch` { _ -> Signal<Api.messages.StickerSet?, NoError> in
            return .single(nil)
        }
        |> map { result -> (StickerPackCollectionInfo, [ItemCollectionItem])? in
            guard let result = result else {
                return nil
            }
            
            let info: StickerPackCollectionInfo
            var items: [ItemCollectionItem] = []
            switch result {
            case let .stickerSet(set, packs, documents):
                let namespace: ItemCollectionId.Namespace
                switch set {
                    /*%layer76*/
                case let .stickerSet(flags, _, _, _, _, _, _):
                    if (flags & (1 << 3)) != 0 {
                        namespace = Namespaces.ItemCollection.CloudMaskPacks
                    } else {
                        namespace = Namespaces.ItemCollection.CloudStickerPacks
                    }
                }
                info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)
                var indexKeysByFile: [MediaId: [MemoryBuffer]] = [:]
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
            }
            
            return (info, items)
        }
}

public func loadedStickerPack(postbox: Postbox, network: Network, reference: StickerPackReference) -> Signal<LoadedStickerPack, NoError> {
    return cachedStickerPack(postbox: postbox, network: network, reference: reference)
        |> map { result -> LoadedStickerPack in
            if let result = result {
                return .result(info: result.0, items: result.1, installed: result.2)
            } else {
                return .fetching
            }
        }
}

private func loadedStickerPack1(account: Account, reference: StickerPackReference) -> Signal<LoadedStickerPack, NoError> {
    return account.postbox.modify { modifier -> Signal<LoadedStickerPack, NoError> in
        switch reference {
            case let .id(id, _):
                if let info = modifier.getItemCollectionInfo(collectionId: ItemCollectionId(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: id)) as? StickerPackCollectionInfo {
                    let items = modifier.getItemCollectionItems(collectionId: info.id)
                    return account.postbox.combinedView(keys: [PostboxViewKey.itemCollectionInfo(id: info.id)])
                        |> map { view in
                            if let view = view.views[PostboxViewKey.itemCollectionInfo(id: info.id)] as? ItemCollectionInfoView, let info = view.info as? StickerPackCollectionInfo {
                                return .result(info: info, items: items, installed: true)
                            } else {
                                return .result(info: info, items: items, installed: false)
                            }
                        }
                } else if let info = modifier.getItemCollectionInfo(collectionId: ItemCollectionId(namespace: Namespaces.ItemCollection.CloudMaskPacks, id: id)) as? StickerPackCollectionInfo {
                    let items = modifier.getItemCollectionItems(collectionId: info.id)
                    return account.postbox.combinedView(keys: [PostboxViewKey.itemCollectionInfo(id: info.id)])
                        |> map { view in
                            if let view = view.views[PostboxViewKey.itemCollectionInfo(id: info.id)] as? ItemCollectionInfoView, let info = view.info as? StickerPackCollectionInfo {
                                return .result(info: info, items: items, installed: true)
                            } else {
                                return .result(info: info, items: items, installed: false)
                            }
                        }
                }
            default:
                break
        }
        
        let signal = remoteStickerPack(network: account.network, reference: reference) |> mapToSignal { result -> Signal<LoadedStickerPack, NoError> in
            if let result = result {
                return account.postbox.combinedView(keys: [PostboxViewKey.itemCollectionInfo(id: result.0.id)])
                    |> map { view in
                        if let view = view.views[PostboxViewKey.itemCollectionInfo(id: result.0.id)] as? ItemCollectionInfoView, let info = view.info as? StickerPackCollectionInfo {
                            return .result(info: info, items: result.1, installed: true)
                        } else {
                            return .result(info: result.0, items: result.1, installed: false)
                        }
                    }
            } else {
                return .single(.none)
            }
        }
        
        return .single(.fetching) |> then(signal)
    } |> switchToLatest
}
