import Foundation

final class SynchronizePeerReadStatesView {
    var operations: [PeerId: PeerReadStateSynchronizationOperation]
    
    init(operations: [PeerId: PeerReadStateSynchronizationOperation]) {
        self.operations = operations
    }
    
    func replay(updatedOperations: [PeerId: PeerReadStateSynchronizationOperation?]) -> [PeerId: PeerReadStateSynchronizationOperation?] {
        var updates: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        
        for (peerId, operation) in updatedOperations {
            if let operation = operation {
                if self.operations[peerId] == nil || self.operations[peerId]! != operation {
                    self.operations[peerId] = operation
                    updates[peerId] = operation
                }
            } else {
                if let _ = self.operations[peerId] {
                    self.operations.removeValueForKey(peerId)
                    updates[peerId] = nil
                }
            }
        }
        
        return updates
    }
}
