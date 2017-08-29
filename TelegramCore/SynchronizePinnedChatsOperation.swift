import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

final class SynchronizePinnedChatsOperation: PostboxCoding {
    let previousPeerIds: [PeerId]
    
    init(previousPeerIds: [PeerId]) {
        self.previousPeerIds = previousPeerIds
    }
    
    init(decoder: PostboxDecoder) {
        self.previousPeerIds = PeerId.decodeArrayFromBuffer(decoder.decodeBytesForKey("p")!)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        PeerId.encodeArrayToBuffer(self.previousPeerIds, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "p")
    }
}

func addSynchronizePinnedChatsOperation(modifier: Modifier) {
    var updateLocalIndex: Int32?
    modifier.operationLogEnumerateEntries(peerId: PeerId(namespace: 0, id: 0), tag: OperationLogTags.SynchronizePinnedChats, { entry in
        updateLocalIndex = entry.tagLocalIndex
        return false
    })
    let operationContents = SynchronizePinnedChatsOperation(previousPeerIds: modifier.getPinnedPeerIds())
    if let updateLocalIndex = updateLocalIndex {
        let _ = modifier.operationLogRemoveEntry(peerId: PeerId(namespace: 0, id: 0), tag: OperationLogTags.SynchronizePinnedChats, tagLocalIndex: updateLocalIndex)
    }
    modifier.operationLogAddEntry(peerId: PeerId(namespace: 0, id: 0), tag: OperationLogTags.SynchronizePinnedChats, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}
