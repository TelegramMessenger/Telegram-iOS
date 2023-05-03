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
    
    var removeOperations: [(SynchronizeRecentlyUsedMediaOperation, Int32)] = []
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        if let operation = entry.contents as? SynchronizeRecentlyUsedMediaOperation {
            if case .sync = operation.content {
                removeOperations.append((operation, entry.tagLocalIndex))
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    })
    
    for (_, topLocalIndex) in removeOperations {
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
