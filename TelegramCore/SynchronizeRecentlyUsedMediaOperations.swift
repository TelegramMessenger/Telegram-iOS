import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

private enum SynchronizeRecentlyUsedMediaOperationContentType: Int32 {
    case add
    case remove
    case clear
    case sync
}

enum SynchronizeRecentlyUsedMediaOperationContent: PostboxCoding {
    case add(id: Int64, accessHash: Int64, fileReference: FileMediaReference?)
    case remove(id: Int64, accessHash: Int64)
    case clear
    case sync
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case SynchronizeRecentlyUsedMediaOperationContentType.add.rawValue:
                self = .add(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0), fileReference: decoder.decodeAnyObjectForKey("fr", decoder: { FileMediaReference(decoder: $0) }) as? FileMediaReference)
            case SynchronizeRecentlyUsedMediaOperationContentType.remove.rawValue:
                self = .remove(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case SynchronizeRecentlyUsedMediaOperationContentType.clear.rawValue:
                self = .clear
            case SynchronizeRecentlyUsedMediaOperationContentType.sync.rawValue:
                self = .sync
            default:
                assertionFailure()
                self = .sync
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .add(id, accessHash, fileReference):
                encoder.encodeInt32(SynchronizeRecentlyUsedMediaOperationContentType.add.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
                if let fileReference = fileReference {
                    encoder.encodeObjectWithEncoder(fileReference, encoder: fileReference.encode, forKey: "fr")
                } else {
                    encoder.encodeNil(forKey: "fr")
                }
            case let .remove(id, accessHash):
                encoder.encodeInt32(SynchronizeRecentlyUsedMediaOperationContentType.remove.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case .clear:
                encoder.encodeInt32(SynchronizeRecentlyUsedMediaOperationContentType.clear.rawValue, forKey: "r")
            case .sync:
                encoder.encodeInt32(SynchronizeRecentlyUsedMediaOperationContentType.sync.rawValue, forKey: "r")
        }
    }
}

final class SynchronizeRecentlyUsedMediaOperation: PostboxCoding {
    let content: SynchronizeRecentlyUsedMediaOperationContent
    
    init(content: SynchronizeRecentlyUsedMediaOperationContent) {
        self.content = content
    }
    
    init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { SynchronizeRecentlyUsedMediaOperationContent(decoder: $0) }) as! SynchronizeRecentlyUsedMediaOperationContent
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}

enum RecentlyUsedMediaCategory {
    case stickers
}

func addSynchronizeRecentlyUsedMediaOperation(transaction: Transaction, category: RecentlyUsedMediaCategory, operation: SynchronizeRecentlyUsedMediaOperationContent) {
    let tag: PeerOperationLogTag
    switch category {
        case .stickers:
            tag = OperationLogTags.SynchronizeRecentlyUsedStickers
    }
    let peerId = PeerId(namespace: 0, id: 0)
    
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
        transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentStickers, item: OrderedItemListEntry(id: RecentMediaItemId(fileReference.media.fileId).rawValue, contents: RecentMediaItem(fileReference.media)), removeTailIfCountExceeds: 20)
        addSynchronizeRecentlyUsedMediaOperation(transaction: transaction, category: .stickers, operation: .add(id: resource.fileId, accessHash: resource.accessHash, fileReference: fileReference))
    }
}

public func clearRecentlyUsedStickers(transaction: Transaction) {
    transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudRecentStickers, items: [])
    addSynchronizeRecentlyUsedMediaOperation(transaction: transaction, category: .stickers, operation: .clear)
}

