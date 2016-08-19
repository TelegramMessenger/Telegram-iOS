import Foundation

final class PostboxTransaction {
    let currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]]
    let peerIdsWithFilledHoles: [PeerId: [MessageIndex: HoleFillDirection]]
    let removedHolesByPeerId: [PeerId: [MessageIndex: HoleFillDirection]]
    let chatListOperations: [ChatListOperation]
    let currentUpdatedPeers: [PeerId: Peer]
    let unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation]
    let updatedSynchronizePeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]
    let updatedMedia: [MediaId: Media?]
    let replaceContactPeerIds: Set<PeerId>?
    let currentUpdatedMasterClientId: Int64?
    
    var isEmpty: Bool {
        if !currentOperationsByPeerId.isEmpty {
            return false
        }
        if !peerIdsWithFilledHoles.isEmpty {
            return false
        }
        if !removedHolesByPeerId.isEmpty {
            return false
        }
        if !chatListOperations.isEmpty {
            return false
        }
        if !currentUpdatedPeers.isEmpty {
            return false
        }
        if !unsentMessageOperations.isEmpty {
            return false
        }
        if !updatedSynchronizePeerReadStateOperations.isEmpty {
            return false
        }
        if !updatedMedia.isEmpty {
            return false
        }
        if let replaceContactPeerIds = replaceContactPeerIds, !replaceContactPeerIds.isEmpty {
            return false
        }
        if currentUpdatedMasterClientId != nil {
            return false
        }
        return true
    }
    
    init(currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]], peerIdsWithFilledHoles: [PeerId: [MessageIndex: HoleFillDirection]], removedHolesByPeerId: [PeerId: [MessageIndex: HoleFillDirection]], chatListOperations: [ChatListOperation], currentUpdatedPeers: [PeerId: Peer], unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation], updatedSynchronizePeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?], updatedMedia: [MediaId: Media?], replaceContactPeerIds: Set<PeerId>?, currentUpdatedMasterClientId: Int64?) {
        self.currentOperationsByPeerId = currentOperationsByPeerId
        self.peerIdsWithFilledHoles = peerIdsWithFilledHoles
        self.removedHolesByPeerId = removedHolesByPeerId
        self.chatListOperations = chatListOperations
        self.currentUpdatedPeers = currentUpdatedPeers
        self.unsentMessageOperations = unsentMessageOperations
        self.updatedSynchronizePeerReadStateOperations = updatedSynchronizePeerReadStateOperations
        self.updatedMedia = updatedMedia
        self.replaceContactPeerIds = replaceContactPeerIds
        self.currentUpdatedMasterClientId = currentUpdatedMasterClientId
    }
}
