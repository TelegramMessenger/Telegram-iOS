import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private enum SynchronizeSavedGifsOperationContentType: Int32 {
    case add
    case remove
    case sync
}

enum SynchronizeSavedGifsOperationContent: PostboxCoding {
    case add(id: Int64, accessHash: Int64, fileReference: FileMediaReference?)
    case remove(id: Int64, accessHash: Int64)
    case sync
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case SynchronizeSavedGifsOperationContentType.add.rawValue:
                self = .add(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0), fileReference: decoder.decodeAnyObjectForKey("fr", decoder: { FileMediaReference(decoder: $0) }) as? FileMediaReference)
            case SynchronizeSavedGifsOperationContentType.remove.rawValue:
                self = .remove(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case SynchronizeSavedGifsOperationContentType.sync.rawValue:
                self = .sync
            default:
                assertionFailure()
                self = .sync
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .add(id, accessHash, fileReference):
                encoder.encodeInt32(SynchronizeSavedGifsOperationContentType.add.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
                if let fileReference = fileReference {
                    encoder.encodeObjectWithEncoder(fileReference, encoder: fileReference.encode, forKey: "fr")
                } else {
                    encoder.encodeNil(forKey: "fr")
                }
            case let .remove(id, accessHash):
                encoder.encodeInt32(SynchronizeSavedGifsOperationContentType.remove.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case .sync:
                encoder.encodeInt32(SynchronizeSavedGifsOperationContentType.sync.rawValue, forKey: "r")
        }
    }
}

final class SynchronizeSavedGifsOperation: PostboxCoding {
    let content: SynchronizeSavedGifsOperationContent
    
    init(content: SynchronizeSavedGifsOperationContent) {
        self.content = content
    }
    
    init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { SynchronizeSavedGifsOperationContent(decoder: $0) }) as! SynchronizeSavedGifsOperationContent
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}

func addSynchronizeSavedGifsOperation(transaction: Transaction, operation: SynchronizeSavedGifsOperationContent) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeSavedGifs
    let peerId = PeerId(namespace: 0, id: 0)
    
    var topOperation: (SynchronizeSavedGifsOperation, Int32)?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        if let operation = entry.contents as? SynchronizeSavedGifsOperation {
            topOperation = (operation, entry.tagLocalIndex)
        }
        return false
    })
    
    if let (topOperation, topLocalIndex) = topOperation, case .sync = topOperation.content {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeSavedGifsOperation(content: operation))
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeSavedGifsOperation(content: .sync))
}

public func addSavedGif(postbox: Postbox, fileReference: FileMediaReference) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let resource = fileReference.media.resource as? CloudDocumentMediaResource {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, item: OrderedItemListEntry(id: RecentMediaItemId(fileReference.media.fileId).rawValue, contents: RecentMediaItem(fileReference.media)), removeTailIfCountExceeds: 200)
            addSynchronizeSavedGifsOperation(transaction: transaction, operation: .add(id: resource.fileId, accessHash: resource.accessHash, fileReference: fileReference))
        }
    }
}

public func removeSavedGif(postbox: Postbox, mediaId: MediaId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let entry = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, itemId: RecentMediaItemId(mediaId).rawValue), let item = entry.contents as? RecentMediaItem {
            if let file = item.media as? TelegramMediaFile, let resource = file.resource as? CloudDocumentMediaResource {
                transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, itemId: entry.id)
                addSynchronizeSavedGifsOperation(transaction: transaction, operation: .remove(id: resource.fileId, accessHash: resource.accessHash))
            }
        }
    }
}
