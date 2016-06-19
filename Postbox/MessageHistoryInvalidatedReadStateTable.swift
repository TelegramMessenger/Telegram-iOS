import Foundation

public enum PeerReadStateSynchronizationOperation: Equatable {
    case Push(thenSync: Bool)
    case Validate
}

public func ==(lhs: PeerReadStateSynchronizationOperation, rhs: PeerReadStateSynchronizationOperation) -> Bool {
    switch lhs {
        case let .Push(lhsThenSync):
            switch rhs {
                case let .Push(rhsThenSync) where lhsThenSync == rhsThenSync:
                    return true
                default:
                    return false
            }
        case .Validate:
            switch rhs {
                case .Validate:
                    return true
                default:
                    return false
            }
    }
}

final class MessageHistorySynchronizeReadStateTable: Table {
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        return self.sharedKey
    }
    
    private var updatedPeerIds: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
    
    private func lowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 1)
        key.setInt8(0, value: 0)
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
    
    func get() -> [PeerId: PeerReadStateSynchronizationOperation] {
        self.beforeCommit()
        
        var operations: [PeerId: PeerReadStateSynchronizationOperation] = [:]
        self.valueBox.range(self.tableId, start: self.lowerBound(), end: self.upperBound(), values: { key, value in
            var operationValue: Int8 = 0
            value.read(&operationValue, offset: 0, length: 1)
            
            let operation: PeerReadStateSynchronizationOperation
            if operationValue == 0 {
                var syncValue: Int8 = 0
                value.read(&syncValue, offset: 0, length: 1)
                operation = .Push(thenSync: syncValue != 0)
            } else {
                operation = .Validate
            }
            
            operations[PeerId(key.getInt64(0))] = operation
            return true
        }, limit: 0)
        return operations
    }
    
    override func beforeCommit() {
        let key = ValueBoxKey(length: 8)
        let buffer = WriteBuffer()
        for (peerId, operation) in self.updatedPeerIds {
            key.setInt64(0, value: peerId.toInt64())
            if let operation = operation {
                buffer.reset()
                switch operation {
                    case let .Push(thenSync):
                        var operationValue: Int8 = 0
                        buffer.write(&operationValue, offset: 0, length: 1)
                        var syncValue: Int8 = thenSync ? 1 : 0
                        buffer.write(&syncValue, offset: 0, length: 1)
                    case .Validate:
                        var operationValue: Int8 = 1
                        buffer.write(&operationValue, offset: 0, length: 1)
                }
                
                self.valueBox.set(self.tableId, key: key, value: buffer)
            } else {
                self.valueBox.remove(self.tableId, key: key)
            }
        }
        self.updatedPeerIds.removeAll()
    }
}
