import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

enum SynchronizeInstalledStickerPacksOperationNamespace: Int32 {
    case stickers = 0
    case masks = 1
}

final class SynchronizeInstalledStickerPacksOperation: Coding {
    let previousPacks: [ItemCollectionId]
    
    init(previousPacks: [ItemCollectionId]) {
        self.previousPacks = previousPacks
    }
    
    init(decoder: Decoder) {
        self.previousPacks = ItemCollectionId.decodeArrayFromBuffer(decoder.decodeBytesForKey("p")!)
    }
    
    func encode(_ encoder: Encoder) {
        let buffer = WriteBuffer()
        ItemCollectionId.encodeArrayToBuffer(self.previousPacks, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "p")
    }
}

func addSynchronizeInstalledStickerPacksOperation(modifier: Modifier, namespace: SynchronizeInstalledStickerPacksOperationNamespace) {
    var updateLocalIndex: Int32?
    let tag: PeerOperationLogTag
    let itemCollectionNamespace: ItemCollectionId.Namespace
    switch namespace {
        case .stickers:
            tag = OperationLogTags.SynchronizeInstalledStickerPacks
            itemCollectionNamespace = Namespaces.ItemCollection.CloudStickerPacks
        case .masks:
            tag = OperationLogTags.SynchronizeInstalledMasks
            itemCollectionNamespace = Namespaces.ItemCollection.CloudMaskPacks
    }
    var previousSrickerPackIds: [ItemCollectionId]?
    modifier.operationLogEnumerateEntries(peerId: PeerId(namespace: 0, id: 0), tag: tag, { entry in
        updateLocalIndex = entry.tagLocalIndex
        if let operation = entry.contents as? SynchronizeInstalledStickerPacksOperation {
            previousSrickerPackIds = operation.previousPacks
        }
        return false
    })
    let operationContents = SynchronizeInstalledStickerPacksOperation(previousPacks: previousSrickerPackIds ?? modifier.getItemCollectionsInfos(namespace: itemCollectionNamespace).map { $0.0 })
    if let updateLocalIndex = updateLocalIndex {
        let _ = modifier.operationLogRemoveEntry(peerId: PeerId(namespace: 0, id: 0), tag: tag, tagLocalIndex: updateLocalIndex)
    }
    modifier.operationLogAddEntry(peerId: PeerId(namespace: 0, id: 0), tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}
