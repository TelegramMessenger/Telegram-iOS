import Foundation

public enum PeerReadStateSynchronizationOperation: Equatable {
    case Push(state: CombinedPeerReadState?, thenSync: Bool)
    case Validate
}

final class MessageHistorySynchronizeReadStateTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        return self.sharedKey
    }
    
    private var updatedPeerIds: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
    
    private func lowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: 0)
        return key
    }
    
    private func upperBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        memset(key.memory, 0xff, key.length)
        return key
    }
    
    func set(_ peerId: PeerId, operation: PeerReadStateSynchronizationOperation?, operations: inout [PeerId: PeerReadStateSynchronizationOperation?]) {
        self.updatedPeerIds[peerId] = operation
        operations[peerId] = operation
    }
    
    func get(getCombinedPeerReadState: (PeerId) -> CombinedPeerReadState?) -> [PeerId: PeerReadStateSynchronizationOperation] {
        self.beforeCommit()
        
        var operations: [PeerId: PeerReadStateSynchronizationOperation] = [:]
        self.valueBox.range(self.table, start: self.lowerBound(), end: self.upperBound(), values: { key, value in
            let peerId = PeerId(key.getInt64(0))
            var operationValue: Int8 = 0
            value.read(&operationValue, offset: 0, length: 1)
            
            let operation: PeerReadStateSynchronizationOperation
            if operationValue == 0 {
                var syncValue: Int8 = 0
                value.read(&syncValue, offset: 0, length: 1)
                operation = .Push(state: getCombinedPeerReadState(peerId), thenSync: syncValue != 0)
            } else {
                operation = .Validate
            }
            
            operations[peerId] = operation
            return true
        }, limit: 0)
        return operations
    }
    
    override func beforeCommit() {
        if !self.updatedPeerIds.isEmpty {
            let key = ValueBoxKey(length: 8)
            let buffer = WriteBuffer()
            for (peerId, operation) in self.updatedPeerIds {
                key.setInt64(0, value: peerId.toInt64())
                if let operation = operation {
                    buffer.reset()
                    switch operation {
                        case let .Push(_, thenSync):
                            var operationValue: Int8 = 0
                            buffer.write(&operationValue, offset: 0, length: 1)
                            var syncValue: Int8 = thenSync ? 1 : 0
                            buffer.write(&syncValue, offset: 0, length: 1)
                        case .Validate:
                            var operationValue: Int8 = 1
                            buffer.write(&operationValue, offset: 0, length: 1)
                    }
                    
                    self.valueBox.set(self.table, key: key, value: buffer)
                } else {
                    self.valueBox.remove(self.table, key: key, secure: false)
                }
            }
            self.updatedPeerIds.removeAll()
        }
    }
}
