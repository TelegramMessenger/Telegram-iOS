import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

final class SynchronizeGroupedPeersOperation: PostboxCoding {
    let peerId: PeerId
    let groupId: PeerGroupId?
    
    init(peerId: PeerId, groupId: PeerGroupId?) {
        self.peerId = peerId
        self.groupId = groupId
    }
    
    init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("peerId", orElse: 0))
        self.groupId = decoder.decodeOptionalInt32ForKey("groupId").flatMap(PeerGroupId.init(rawValue:))
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "peerId")
        if let groupId = self.groupId {
            encoder.encodeInt32(groupId.rawValue, forKey: "groupId")
        } else {
            encoder.encodeNil(forKey: "groupId")
        }
    }
}

public func updatePeerGroupIdInteractively(postbox: Postbox, peerId: PeerId, groupId: PeerGroupId?) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let previousGroupId = transaction.getPeerGroupId(peerId)
        
        if previousGroupId != groupId {
            transaction.updatePeerGroupId(peerId, groupId: groupId)
            addSynchronizeGroupedPeersOperation(transaction: transaction, peerId: peerId, groupId: groupId)
        }
    }
}

private func addSynchronizeGroupedPeersOperation(transaction: Transaction, peerId: PeerId, groupId: PeerGroupId?) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeGroupedPeers
    let logPeerId = PeerId(namespace: 0, id: 0)
    
    transaction.operationLogAddEntry(peerId: logPeerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeGroupedPeersOperation(peerId: peerId, groupId: groupId))
}
