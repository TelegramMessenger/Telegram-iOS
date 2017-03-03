import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif


public enum RequestStickerSetError {
    case generic
    case invalid
}

fileprivate extension Api.StickerSet {
    var info:StickerPackCollectionInfo {
        switch self {
        case let .stickerSet(data):
            
            var flags:StickerPackCollectionInfoFlags = StickerPackCollectionInfoFlags()
            if (data.flags & (1 << 2)) != 0 {
                flags.insert(.official)
            }
            if (data.flags & (1 << 3)) != 0 {
                flags.insert(.masks)
            }
            
            return StickerPackCollectionInfo(id: ItemCollectionId(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: data.id), flags: flags, accessHash: data.accessHash, title: data.title, shortName: data.shortName, hash: data.hash)
        }
    }
}

public enum RequestStickerSetResult {
    case local(info: ItemCollectionInfo, items: [ItemCollectionItem])
    case remote(info: ItemCollectionInfo, items: [ItemCollectionItem], installed: Bool)
}

public func requestStickerSet(account:Account, reference: StickerPackReference) -> Signal<RequestStickerSetResult, RequestStickerSetError> {
    
    let collectionId:ItemCollectionId?
    let input:Api.InputStickerSet
    
    switch reference {
    case let .name(name):
        collectionId = nil
        input = .inputStickerSetShortName(shortName: name)
    case let .id(id, accessHash):
        collectionId = ItemCollectionId(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: id)
        input = .inputStickerSetID(id: id, accessHash: accessHash)
    }
    
    let localSignal:(ItemCollectionId) -> Signal<(ItemCollectionInfo, [ItemCollectionItem])?, Void> = { collectionId in
        return account.postbox.modify { modifier -> (ItemCollectionInfo, [ItemCollectionItem])? in
            return modifier.getItemCollectionInfoItems(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: collectionId)
        }
    }
    
    let remoteSignal = account.network.request(Api.functions.messages.getStickerSet(stickerset: input))
        |> mapError { _ -> RequestStickerSetError in
            return .invalid
        }
        |> map { result -> RequestStickerSetResult in
            var items: [ItemCollectionItem] = []
            let info:ItemCollectionInfo
            let installed:Bool
            switch result {
            case let .stickerSet(set, packs, documents):

                info = set.info
                
                switch set {
                case let .stickerSet(data):
                    installed = (data.flags & (1 << 0) != 0)
                }
                
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
            return .remote(info: info, items: items, installed: installed)
    }
    
    
    if let collectionId = collectionId {
        return localSignal(collectionId) |> mapError {_ in return .generic} |> mapToSignal { result -> Signal<RequestStickerSetResult, RequestStickerSetError> in
            if let result = result {
                return .single(.local(info: result.0, items: result.1))
            } else {
                return remoteSignal
            }
        }
    } else {
        return remoteSignal
    }
    
    
}

public enum InstallStickerSetError {
    case generic
}

public enum InstallStickerSetResult {
    case successful
    case archived([CoveredStickerSet])
}

public final class CoveredStickerSet : Equatable {
    let items:[StickerPackItem]
    let info:StickerPackCollectionInfo
    public init(info:StickerPackCollectionInfo, items:[StickerPackItem]) {
        self.items = items
        self.info = info
    }
    
    public static func ==(lhs:CoveredStickerSet, rhs:CoveredStickerSet) -> Bool {
        return lhs.items == rhs.items && lhs.info == rhs.info
    }
}

public func installStickerSetInteractively(account:Account, info: StickerPackCollectionInfo, items: [ItemCollectionItem]) -> Signal<InstallStickerSetResult, InstallStickerSetError> {
    
    return account.network.request(Api.functions.messages.installStickerSet(stickerset: .inputStickerSetID(id: info.id.id, accessHash: info.accessHash), archived: .boolFalse)) |> mapError { _ -> InstallStickerSetError in
        return .generic
        } |> mapToSignal { result -> Signal<InstallStickerSetResult, InstallStickerSetError> in
            let addResult:InstallStickerSetResult
            switch result {
            case .stickerSetInstallResultSuccess:
                addResult = .successful
            case let .stickerSetInstallResultArchive(sets: archived):
                var coveredSets:[CoveredStickerSet] = []
                for archived in archived {
                    let apiDocuments:[Api.Document]
                    let apiSet:Api.StickerSet
                    switch archived {
                    case let .stickerSetCovered(set: set, cover: cover):
                        apiSet = set
                        apiDocuments = [cover]
                    case let .stickerSetMultiCovered(set: set, covers: covers):
                        apiSet = set
                        apiDocuments = covers
                    }
                    
                    let info:StickerPackCollectionInfo = apiSet.info
                    
                    var items:[StickerPackItem] = []
                    for apiDocument in apiDocuments {
                        if let file = telegramMediaFileFromApiDocument(apiDocument), let id = file.id {
                            items.append(StickerPackItem(index: ItemCollectionItemIndex(index: Int32(items.count), id: id.id), file: file, indexKeys: []))
                        }
                    }
                    coveredSets.append(CoveredStickerSet(info: info, items: items))
                }
                addResult = .archived(coveredSets)
            }
            
            
            return account.postbox.modify { modifier -> Void in
                var collections = modifier.getCollectionsItems(namespace: info.id.namespace)
                
                var removableIndexes:[Int] = []
                for i in 0 ..< collections.count {
                    if collections[i].0 == info.id {
                        removableIndexes.append(i)
                    }
                    if case let .archived(sets) = addResult {
                        for set in sets {
                            if collections[i].0 == set.info.id {
                                removableIndexes.append(i)
                            }
                        }
                    }
                }
                
                for index in removableIndexes.reversed() {
                    collections.remove(at: index)
                }
                
                collections.insert((info.id, info, items), at: 0)
                
                modifier.replaceItemCollections(namespace: info.id.namespace, itemCollections: collections)
                } |> map { _ in return addResult} |> mapError {_ in return .generic}
    }
}


public func uninstallStickerSetInteractively(account:Account, info:StickerPackCollectionInfo) -> Signal<Void, Void> {
    return account.network.request(Api.functions.messages.uninstallStickerSet(stickerset: .inputStickerSetID(id: info.id.id, accessHash: info.accessHash)))
        |> mapError {_ in
            
        }
        |> mapToSignal { result-> Signal<Void, Void> in
            switch result {
            case .boolTrue:
                return account.postbox.modify { modifier -> Void in
                    var collections = modifier.getCollectionsItems(namespace: info.id.namespace)
                    
                    for i in 0 ..< collections.count {
                        if collections[i].0 == info.id {
                            collections.remove(at: i)
                            break
                        }
                    }
                    
                    modifier.replaceItemCollections(namespace: info.id.namespace, itemCollections: collections)
                }
            case .boolFalse:
                return .complete()
            }
    }
}


