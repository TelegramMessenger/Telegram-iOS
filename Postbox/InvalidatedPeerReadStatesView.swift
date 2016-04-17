import Foundation

final class InvalidatedPeerReadStatesView {
    var peerIds = Set<PeerId>()
    
    init(peerIds: [PeerId]) {
        for peerId in peerIds {
            self.peerIds.insert(peerId)
        }
    }
    
    func replay(operations: [IntermediateMessageHistoryInvalidatedReadStateOperation]) -> Bool {
        var updated = false
        for operation in operations {
            switch operation {
            case let .Insert(peerId):
                if !self.peerIds.contains(peerId) {
                    self.peerIds.insert(peerId)
                    updated = true
                }
            case let .Remove(peerId):
                if let _ = self.peerIds.remove(peerId) {
                    updated = true
                }
            }
        }
        
        return updated
    }
}
