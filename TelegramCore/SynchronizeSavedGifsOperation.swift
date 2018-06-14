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
    case add(id: Int64, accessHash: Int64)
    case remove(id: Int64, accessHash: Int64)
    case sync
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case SynchronizeSavedGifsOperationContentType.add.rawValue:
                self = .add(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
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
            case let .add(id, accessHash):
                encoder.encodeInt32(SynchronizeSavedGifsOperationContentType.add.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
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

public func addSavedGif(postbox: Postbox, file: TelegramMediaFile) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let resource = file.resource as? CloudDocumentMediaResource {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: RecentMediaItem(file)), removeTailIfCountExceeds: 200)
            addSynchronizeSavedGifsOperation(transaction: transaction, operation: .add(id: resource.fileId, accessHash: resource.accessHash))
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
