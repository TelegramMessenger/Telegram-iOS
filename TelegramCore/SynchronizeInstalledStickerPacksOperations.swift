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
    switch namespace {
        case .stickers:
            tag = OperationLogTags.SynchronizeInstalledStickerPacks
        case .masks:
            tag = OperationLogTags.SynchronizeInstalledMasks
    }
    modifier.operationLogEnumerateEntries(peerId: PeerId(namespace: 0, id: 0), tag: tag, { entry in
        updateLocalIndex = entry.tagLocalIndex
        return false
    })
    let operationContents = SynchronizePinnedChatsOperation(previousPeerIds: modifier.getPinnedPeerIds())
    if let updateLocalIndex = updateLocalIndex {
        let _ = modifier.operationLogRemoveEntry(peerId: PeerId(namespace: 0, id: 0), tag: tag, tagLocalIndex: updateLocalIndex)
    }
    modifier.operationLogAddEntry(peerId: PeerId(namespace: 0, id: 0), tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}
