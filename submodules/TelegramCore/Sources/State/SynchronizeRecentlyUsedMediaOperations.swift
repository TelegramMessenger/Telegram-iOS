import Foundation
import Postbox
import SwiftSignalKit


enum RecentlyUsedMediaCategory {
    case stickers
}

func addSynchronizeRecentlyUsedMediaOperation(transaction: Transaction, category: RecentlyUsedMediaCategory, operation: SynchronizeRecentlyUsedMediaOperationContent) {
    let tag: PeerOperationLogTag
    switch category {
        case .stickers:
            tag = OperationLogTags.SynchronizeRecentlyUsedStickers
    }
    let peerId = PeerId(0)
    
    var topOperation: (SynchronizeRecentlyUsedMediaOperation, Int32)?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        if let operation = entry.contents as? SynchronizeRecentlyUsedMediaOperation {
            topOperation = (operation, entry.tagLocalIndex)
        }
        return false
    })
    
    if let (topOperation, topLocalIndex) = topOperation, case .sync = topOperation.content {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeRecentlyUsedMediaOperation(content: operation))
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeRecentlyUsedMediaOperation(content: .sync))
}

func addRecentlyUsedSticker(transaction: Transaction, fileReference: FileMediaReference) {
    if let resource = fileReference.media.resource as? CloudDocumentMediaResource {
        if let entry = CodableEntry(RecentMediaItem(fileReference.media)) {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentStickers, item: OrderedItemListEntry(id: RecentMediaItemId(fileReference.media.fileId).rawValue, contents: entry), removeTailIfCountExceeds: 20)
        }
        addSynchronizeRecentlyUsedMediaOperation(transaction: transaction, category: .stickers, operation: .add(id: resource.fileId, accessHash: resource.accessHash, fileReference: fileReference))
    }
}

func _internal_clearRecentlyUsedStickers(transaction: Transaction) {
    transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudRecentStickers, items: [])
    addSynchronizeRecentlyUsedMediaOperation(transaction: transaction, category: .stickers, operation: .clear)
}

func _internal_clearRecentlyUsedEmoji(transaction: Transaction) {
    transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.LocalRecentEmoji, items: [])
}
