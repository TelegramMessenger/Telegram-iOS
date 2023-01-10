import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


func addSynchronizeSavedStickersOperation(transaction: Transaction, operation: SynchronizeSavedStickersOperationContent) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeSavedStickers
    let peerId = PeerId(0)
    
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

public func addSavedSticker(postbox: Postbox, network: Network, file: TelegramMediaFile, limit: Int = 5) -> Signal<Void, AddSavedStickerError> {
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
                case .animatedEmoji, .animatedEmojiAnimations, .dice, .premiumGifts, .emojiGenericAnimations, .iconStatusEmoji, .iconTopicEmoji:
                    break
                }
                if let fetchReference = fetchReference {
                    return network.request(Api.functions.messages.getStickerSet(stickerset: fetchReference.apiInputStickerSet, hash: 0))
                        |> mapError { _ -> AddSavedStickerError in
                            return .generic
                        }
                        |> mapToSignal { result -> Signal<Void, AddSavedStickerError> in
                            var stickerStringRepresentations: [String]?
                            switch result {
                                case .stickerSetNotModified:
                                    break
                                case let .stickerSet(_, packs, _, _):
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
                                } |> mapError { _ -> AddSavedStickerError in }
                            } else {
                                return .fail(.notFound)
                            }
                        }
                }
                return .complete()
            }
        }
        return .complete()
    } |> mapError { _ -> AddSavedStickerError in } |> switchToLatest
}

public func addSavedSticker(transaction: Transaction, file: TelegramMediaFile, stringRepresentations: [String], limit: Int = 5) {
    if let resource = file.resource as? CloudDocumentMediaResource {
        if let entry = CodableEntry(SavedStickerItem(file: file, stringRepresentations: stringRepresentations)) {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry), removeTailIfCountExceeds: limit)
        }
        addSynchronizeSavedStickersOperation(transaction: transaction, operation: .add(id: resource.fileId, accessHash: resource.accessHash, fileReference: .standalone(media: file)))
    }
}

public func removeSavedSticker(transaction: Transaction, mediaId: MediaId) {
    if let entry = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, itemId: RecentMediaItemId(mediaId).rawValue), let item = entry.contents.get(SavedStickerItem.self) {
        if let resource = item.file.resource as? CloudDocumentMediaResource {
            transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, itemId: entry.id)
            addSynchronizeSavedStickersOperation(transaction: transaction, operation: .remove(id: resource.fileId, accessHash: resource.accessHash))
        }
    }
}

public func removeSavedSticker(postbox: Postbox, mediaId: MediaId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
        if let entry = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, itemId: RecentMediaItemId(mediaId).rawValue), let item = entry.contents.get(SavedStickerItem.self) {
            if let resource = item.file.resource as? CloudDocumentMediaResource {
                transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudSavedStickers, itemId: entry.id)
                addSynchronizeSavedStickersOperation(transaction: transaction, operation: .remove(id: resource.fileId, accessHash: resource.accessHash))
            }
        }
    }
    
}
