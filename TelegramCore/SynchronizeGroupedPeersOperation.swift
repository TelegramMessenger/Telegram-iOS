import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

final class SynchronizeGroupedPeersOperation: PostboxCoding {
    let groupId: PeerGroupId
    let initialPeerIds: Set<PeerId>
    
    init(groupId: PeerGroupId, initialPeerIds: Set<PeerId>) {
        self.groupId = groupId
        self.initialPeerIds = initialPeerIds
    }
    
    init(decoder: PostboxDecoder) {
        self.groupId = PeerGroupId(rawValue: decoder.decodeOptionalInt32ForKey("groupId")!)
        self.initialPeerIds = Set(PeerId.decodeArrayFromBuffer(decoder.decodeBytesForKeyNoCopy("initialPeerIds")!))
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.groupId.rawValue, forKey: "groupId")
        let buffer = WriteBuffer()
        PeerId.encodeArrayToBuffer(Array(self.initialPeerIds), buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "initialPeerIds")
    }
}

/*public func updatePeerGroupIdInteractively(postbox: Postbox, peerId: PeerId, groupId: PeerGroupId?) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let previousGroupId = transaction.getPeerGroupId(peerId)
        
        if previousGroupId != groupId {
            var previousGroupPeerIds = Set<PeerId>()
            if let previousGroupId = previousGroupId {
                previousGroupPeerIds = transaction.getPeerIdsInGroup(previousGroupId)
            }
            
            var updatedGroupPeerIds = Set<PeerId>()
            if let groupId = groupId {
                updatedGroupPeerIds = transaction.getPeerIdsInGroup(groupId)
            }
            
            transaction.updatePeerGroupId(peerId, groupId: groupId)
            if let previousGroupId = previousGroupId {
                addSynchronizeGroupedPeersOperation(transaction: transaction, groupId: previousGroupId, initialPeerIds: previousGroupPeerIds)
            }
            if let groupId = groupId {
                addSynchronizeGroupedPeersOperation(transaction: transaction, groupId: groupId, initialPeerIds: updatedGroupPeerIds)
            }
        }
    }
}

public func clearPeerGroupInteractively(postbox: Postbox, groupId: PeerGroupId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        var previousGroupPeerIds = Set<PeerId>()
        previousGroupPeerIds = transaction.getPeerIdsInGroup(groupId)
        
        for peerId in transaction.getPeerIdsInGroup(groupId) {
            transaction.updatePeerGroupId(peerId, groupId: nil)
        }
        addSynchronizeGroupedPeersOperation(transaction: transaction, groupId: groupId, initialPeerIds: previousGroupPeerIds)
    }
}

private func addSynchronizeGroupedPeersOperation(transaction: Transaction, groupId: PeerGroupId, initialPeerIds: Set<PeerId>) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeGroupedPeers
    let peerId = PeerId(namespace: 0, id: groupId.rawValue)
    
    var topLocalIndex: Int32?
    var previousInitialPeerIds: Set<PeerId>?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        topLocalIndex = entry.tagLocalIndex
        if let operation = entry.contents as? SynchronizeGroupedPeersOperation {
            previousInitialPeerIds = operation.initialPeerIds
        }
        return false
    })
    
    if let topLocalIndex = topLocalIndex {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    let initialPeerIds: Set<PeerId> = previousInitialPeerIds ?? initialPeerIds
    
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeGroupedPeersOperation(groupId: groupId, initialPeerIds: initialPeerIds))
}
*/
