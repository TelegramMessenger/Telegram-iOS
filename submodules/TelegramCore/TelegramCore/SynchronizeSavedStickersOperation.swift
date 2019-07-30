import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
    import SwiftSignalKit
#endif

private enum SynchronizeSavedStickersOperationContentType: Int32 {
    case add
    case remove
    case sync
}

enum SynchronizeSavedStickersOperationContent: PostboxCoding {
    case add(id: Int64, accessHash: Int64, fileReference: FileMediaReference?)
    case remove(id: Int64, accessHash: Int64)
    case sync
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case SynchronizeSavedStickersOperationContentType.add.rawValue:
                self = .add(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0), fileReference: decoder.decodeAnyObjectForKey("fr", decoder: { FileMediaReference(decoder: $0) }) as? FileMediaReference)
            case SynchronizeSavedStickersOperationContentType.remove.rawValue:
                self = .remove(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case SynchronizeSavedStickersOperationContentType.sync.rawValue:
                self = .sync
            default:
                assertionFailure()
                self = .sync
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .add(id, accessHash, fileReference):
                encoder.encodeInt32(SynchronizeSavedStickersOperationContentType.add.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
                if let fileReference = fileReference {
                    encoder.encodeObjectWithEncoder(fileReference, encoder: fileReference.encode, forKey: "fr")
                } else {
                    encoder.encodeNil(forKey: "fr")
                }
            case let .remove(id, accessHash):
                encoder.encodeInt32(SynchronizeSavedStickersOperationContentType.remove.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case .sync:
                encoder.encodeInt32(SynchronizeSavedStickersOperationContentType.sync.rawValue, forKey: "r")
        }
    }
}

final class SynchronizeSavedStickersOperation: PostboxCoding {
    let content: SynchronizeSavedStickersOperationContent
    
    init(content: SynchronizeSavedStickersOperationContent) {
        self.content = content
    }
    
    init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { SynchronizeSavedStickersOperationContent(decoder: $0) }) as! SynchronizeSavedStickersOperationContent
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}

func addSynchronizeSavedStickersOperation(transaction: Transaction, operation: SynchronizeSavedStickersOperationContent) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeSavedStickers
    let peerId = PeerId(namespace: 0, id: 0)
    
    var topOperation: (SynchronizeSavedStickersOperation, Int32)?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        if let operation = entry.contents as? SynchronizeSavedStickersOperation {
            topOperation = (operation, entry.tagLocalIndex)
        }
        return false
    })
    
    if let (topOperation, topLocalIndex) = topOperation, case .sync = topOperation.content {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeSavedStickersOperation(content: operation))
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeSavedStickersOperation(content: .sync))
}

public enum AddSavedStickerError {
    case generic
    case notFound
}

public func getIsStickerSaved(transaction: Transaction, fileId: MediaId) -> Bool {
    if let _ = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, itemId: RecentMediaItemId(fileId).rawValue) {
        return true
    } else{
        return false
    }
}

public func addSavedSticker(postbox: Postbox, network: Network, file: TelegramMediaFile) -> Signal<Void, AddSavedStickerError> {
    return postbox.transaction { transaction -> Signal<Void, AddSavedStickerError> in
        for attribute in file.attributes {
            if case let .Sticker(_, maybePackReference, _) = attribute, let packReference = maybePackReference {
                var fetchReference: StickerPackReference?
                switch packReference {
                    case .name:
                        fetchReference = packReference
                    case let .id(id, _):
                        let items = transaction.getItemCollectionItems(collectionId: ItemCollectionId(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: id))
                        var found = false
                        inner: for item in items {
                            if let stickerItem = item as? StickerPackItem {
                                if stickerItem.file.fileId == file.fileId {
                                    let stringRepresentations = stickerItem.getStringRepresentationsOfIndexKeys()
                                    found = true
                                    addSavedSticker(transaction: transaction, file: stickerItem.file, stringRepresentations: stringRepresentations)
                                    break inner
                                }
                            }
                        }
                        if !found {
                            fetchReference = packReference
                        }
                    case .animatedEmoji:
                        break
                }
                if let fetchReference = fetchReference {
                    return network.request(Api.functions.messages.getStickerSet(stickerset: fetchReference.apiInputStickerSet))
                        |> mapError { _ -> AddSavedStickerError in
                            return .generic
                        }
                        |> mapToSignal { result -> Signal<Void, AddSavedStickerError> in
                            var stickerStringRepresentations: [String]?
                            switch result {
                                case let .stickerSet(_, packs, _):
                                    var stringRepresentationsByFile: [MediaId: [String]] = [:]
                                    for pack in packs {
                                        switch pack {
                                            case let .stickerPack(text, fileIds):
                                                for fileId in fileIds {
                                                    let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                                    if stringRepresentationsByFile[mediaId] == nil {
                                                        stringRepresentationsByFile[mediaId] = [text]
                                                    } else {
                                                        stringRepresentationsByFile[mediaId]!.append(text)
                                                    }
                                                }
                                        }
                                    }
                                    stickerStringRepresentations = stringRepresentationsByFile[file.fileId]
                            }
                            if let stickerStringRepresentations = stickerStringRepresentations {
                                return postbox.transaction { transaction -> Void in
                                    addSavedSticker(transaction: transaction, file: file, stringRepresentations: stickerStringRepresentations)
                                } |> mapError { _ in return AddSavedStickerError.generic }
                            } else {
                                return .fail(.notFound)
                            }
                        }
                }
                return .complete()
            }
        }
        return .complete()
    } |> mapError { _ in return AddSavedStickerError.generic } |> switchToLatest
}

public func addSavedSticker(transaction: Transaction, file: TelegramMediaFile, stringRepresentations: [String]) {
    if let resource = file.resource as? CloudDocumentMediaResource {
        transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: SavedStickerItem(file: file, stringRepresentations: stringRepresentations)), removeTailIfCountExceeds: 5)
        addSynchronizeSavedStickersOperation(transaction: transaction, operation: .add(id: resource.fileId, accessHash: resource.accessHash, fileReference: .standalone(media: file)))
    }
}

public func removeSavedSticker(transaction: Transaction, mediaId: MediaId) {
    if let entry = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, itemId: RecentMediaItemId(mediaId).rawValue), let item = entry.contents as? SavedStickerItem {
        if let resource = item.file.resource as? CloudDocumentMediaResource {
            transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, itemId: entry.id)
            addSynchronizeSavedStickersOperation(transaction: transaction, operation: .remove(id: resource.fileId, accessHash: resource.accessHash))
        }
    }
}

public func removeSavedSticker(postbox: Postbox, mediaId: MediaId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
        if let entry = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, itemId: RecentMediaItemId(mediaId).rawValue), let item = entry.contents as? SavedStickerItem {
            if let resource = item.file.resource as? CloudDocumentMediaResource {
                transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, itemId: entry.id)
                addSynchronizeSavedStickersOperation(transaction: transaction, operation: .remove(id: resource.fileId, accessHash: resource.accessHash))
            }
        }
    }
    
}
