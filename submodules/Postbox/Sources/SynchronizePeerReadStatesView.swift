import Foundation

final class MutableSynchronizePeerReadStatesView {
    var operations: [PeerId: PeerReadStateSynchronizationOperation]
    
    init(operations: [PeerId: PeerReadStateSynchronizationOperation]) {
        self.operations = operations
    }
    
    func refreshDueToExternalTransaction(fetchSynchronizePeerReadStateOperations: () -> [PeerId: PeerReadStateSynchronizationOperation]) -> Bool {
        let operations = fetchSynchronizePeerReadStateOperations()
        if self.operations != operations {
            self.operations = operations
            return true
        } else {
            return false
        }
    }
    
    func replay(_ updatedOperations: [PeerId: PeerReadStateSynchronizationOperation?]) -> Bool {
        var updated = false
        for (peerId, operation) in updatedOperations {
            if let operation = operation {
                if self.operations[peerId] == nil || self.operations[peerId]! != operation {
                    self.operations[peerId] = operation
                    updated = true
                }
            } else {
                if let _ = self.operations[peerId] {
                    let _ = self.operations.removeValue(forKey: peerId)
                    updated = true
                }
            }
        }
        
        return updated
    }
}

public final class SynchronizePeerReadStatesView {
    public let operations: [PeerId: PeerReadStateSynchronizationOperation]
    
    init(_ mutableView: MutableSynchronizePeerReadStatesView) {
        self.operations = mutableView.operations
    }
}
