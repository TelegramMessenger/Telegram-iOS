import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


public enum RequestStickerSetError {
    case generic
    case invalid
}

public enum RequestStickerSetResult {
    case local(info: ItemCollectionInfo, items: [ItemCollectionItem])
    case remote(info: ItemCollectionInfo, items: [ItemCollectionItem], installed: Bool)
    
    public var items: [ItemCollectionItem] {
        switch self {
            case let .local(_, items):
                return items
            case let .remote(_, items, _):
                return items
        }
    }
}

func _internal_requestStickerSet(postbox: Postbox, network: Network, reference: StickerPackReference) -> Signal<RequestStickerSetResult, RequestStickerSetError> {
    let collectionId: ItemCollectionId?
    let input: Api.InputStickerSet
    
    switch reference {
        case let .name(name):
            collectionId = nil
            input = .inputStickerSetShortName(shortName: name)
        case let .id(id, accessHash):
            collectionId = ItemCollectionId(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: id)
            input = .inputStickerSetID(id: id, accessHash: accessHash)
        case .animatedEmoji:
            collectionId = nil
            input = .inputStickerSetAnimatedEmoji
        case let .dice(emoji):
            collectionId = nil
            input = .inputStickerSetDice(emoticon: emoji)
        case .animatedEmojiAnimations:
            collectionId = nil
            input = .inputStickerSetAnimatedEmojiAnimations
    }
    
    let localSignal: (ItemCollectionId) -> Signal<(ItemCollectionInfo, [ItemCollectionItem])?, NoError> = { collectionId in
        return postbox.transaction { transaction -> (ItemCollectionInfo, [ItemCollectionItem])? in
            return transaction.getItemCollectionInfoItems(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: collectionId)
        }
    }
    
    let remoteSignal = network.request(Api.functions.messages.getStickerSet(stickerset: input, hash: 0))
    |> mapError { _ -> RequestStickerSetError in
        return .invalid
    }
    |> mapToSignal { result -> Signal<RequestStickerSetResult, RequestStickerSetError> in
        var items: [ItemCollectionItem] = []
        let info: ItemCollectionInfo
        let installed: Bool
        switch result {
            case .stickerSetNotModified:
                return .complete()
            case let .stickerSet(set, packs, documents):
                info = StickerPackCollectionInfo(apiSet: set, namespace: Namespaces.ItemCollection.CloudStickerPacks)
                
                switch set {
                    case let .stickerSet(flags, _, _, _, _, _, _, _, _, _, _):
                        installed = (flags & (1 << 0) != 0)
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
        }
        return .single(.remote(info: info, items: items, installed: installed))
    }
    
    if let collectionId = collectionId {
        return localSignal(collectionId) |> mapError { _ -> RequestStickerSetError in } |> mapToSignal { result -> Signal<RequestStickerSetResult, RequestStickerSetError> in
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
    let items: [StickerPackItem]
    let info: StickerPackCollectionInfo
    public init(info: StickerPackCollectionInfo, items: [StickerPackItem]) {
        self.items = items
        self.info = info
    }
    
    public static func ==(lhs: CoveredStickerSet, rhs: CoveredStickerSet) -> Bool {
        return lhs.items == rhs.items && lhs.info == rhs.info
    }
}

func _internal_installStickerSetInteractively(account: Account, info: StickerPackCollectionInfo, items: [ItemCollectionItem]) -> Signal<InstallStickerSetResult, InstallStickerSetError> {
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
                    
                    let info = StickerPackCollectionInfo(apiSet: apiSet, namespace: Namespaces.ItemCollection.CloudStickerPacks)
                    
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
            
            
            return account.postbox.transaction { transaction -> Void in
                var collections = transaction.getCollectionsItems(namespace: info.id.namespace)
                
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
                
                transaction.replaceItemCollections(namespace: info.id.namespace, itemCollections: collections)
                } |> map { _ in return addResult} |> mapError { _ -> InstallStickerSetError in }
    }
}


func _internal_uninstallStickerSetInteractively(account: Account, info: StickerPackCollectionInfo) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.messages.uninstallStickerSet(stickerset: .inputStickerSetID(id: info.id.id, accessHash: info.accessHash)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> mapToSignal { result -> Signal<Void, NoError> in
        switch result {
            case .boolTrue:
                return account.postbox.transaction { transaction -> Void in
                    var collections = transaction.getCollectionsItems(namespace: info.id.namespace)
                    
                    for i in 0 ..< collections.count {
                        if collections[i].0 == info.id {
                            collections.remove(at: i)
                            break
                        }
                    }
                    
                    transaction.replaceItemCollections(namespace: info.id.namespace, itemCollections: collections)
                }
            case .boolFalse:
                return .complete()
        }
    }
}


