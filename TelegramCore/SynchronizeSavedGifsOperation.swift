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

enum SynchronizeSavedGifsOperationContent: Coding {
    case add(id: Int64, accessHash: Int64)
    case remove(id: Int64, accessHash: Int64)
    case sync
    
    init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("r") as Int32 {
            case SynchronizeSavedGifsOperationContentType.add.rawValue:
                self = .add(id: decoder.decodeInt64ForKey("i"), accessHash: decoder.decodeInt64ForKey("h"))
            case SynchronizeSavedGifsOperationContentType.remove.rawValue:
                self = .remove(id: decoder.decodeInt64ForKey("i"), accessHash: decoder.decodeInt64ForKey("h"))
            case SynchronizeSavedGifsOperationContentType.sync.rawValue:
                self = .sync
            default:
                assertionFailure()
                self = .sync
        }
    }
    
    func encode(_ encoder: Encoder) {
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

final class SynchronizeSavedGifsOperation: Coding {
    let content: SynchronizeSavedGifsOperationContent
    
    init(content: SynchronizeSavedGifsOperationContent) {
        self.content = content
    }
    
    init(decoder: Decoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { SynchronizeSavedGifsOperationContent(decoder: $0) }) as! SynchronizeSavedGifsOperationContent
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}

func addSynchronizeSavedGifsOperation(modifier: Modifier, operation: SynchronizeSavedGifsOperationContent) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeSavedGifs
    let peerId = PeerId(namespace: 0, id: 0)
    
    var topOperation: (SynchronizeSavedGifsOperation, Int32)?
    modifier.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        if let operation = entry.contents as? SynchronizeSavedGifsOperation {
            topOperation = (operation, entry.tagLocalIndex)
        }
        return false
    })
    
    if let (topOperation, topLocalIndex) = topOperation, case .sync = topOperation.content {
        let _ = modifier.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    modifier.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeSavedGifsOperation(content: operation))
    modifier.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeSavedGifsOperation(content: .sync))
}

public func addSavedGif(postbox: Postbox, file: TelegramMediaFile) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        if let resource = file.resource as? CloudDocumentMediaResource {
            modifier.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: RecentMediaItem(file)), removeTailIfCountExceeds: 200)
            addSynchronizeSavedGifsOperation(modifier: modifier, operation: .add(id: resource.fileId, accessHash: resource.accessHash))
        }
    }
}

public func removeSavedGif(postbox: Postbox, mediaId: MediaId) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        if let entry = modifier.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, itemId: RecentMediaItemId(mediaId).rawValue), let item = entry.contents as? RecentMediaItem {
            if let file = item.media as? TelegramMediaFile, let resource = file.resource as? CloudDocumentMediaResource {
                modifier.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, itemId: entry.id)
                addSynchronizeSavedGifsOperation(modifier: modifier, operation: .remove(id: resource.fileId, accessHash: resource.accessHash))
            }
        }
    }
}
