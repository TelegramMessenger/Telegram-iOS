import Foundation
import Postbox
import SwiftSignalKit

import SyncCore

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
