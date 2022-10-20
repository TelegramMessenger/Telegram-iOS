import Foundation

enum PendingMessageActionsMetadataCountKey: Hashable {
    case peerNamespace(PeerId, MessageId.Namespace)
    case peerNamespaceAction(PeerId, MessageId.Namespace, PendingMessageActionType)
}

enum PendingMessageActionsMetadataKey {
    case count(PendingMessageActionsMetadataCountKey)
}

final class PendingMessageActionsMetadataTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private var cachedCounts: [PendingMessageActionsMetadataCountKey: Int32] = [:]
    private var updatedCounts = Set<PendingMessageActionsMetadataCountKey>()
    
    private func key(_ key: PendingMessageActionsMetadataKey) -> ValueBoxKey {
        switch key {
            case let .count(countKey):
                switch countKey {
                    case let .peerNamespace(peerId, namespace):
                        let result = ValueBoxKey(length: 1 + 8 + 4)
                        result.setUInt8(0, value: 0)
                        result.setInt64(1, value: peerId.toInt64())
                        result.setInt32(1 + 8, value: namespace)
                        return result
                    case let .peerNamespaceAction(peerId, namespace, actionType):
                        let result = ValueBoxKey(length: 1 + 8 + 4 + 4)
                        result.setUInt8(0, value: 1)
                        result.setInt64(1, value: peerId.toInt64())
                        result.setInt32(1 + 8, value: namespace)
                        result.setUInt32(1 + 8 + 4, value: actionType.rawValue)
                        return result
                }
        }
    }
    
    func getCount(_ key: PendingMessageActionsMetadataCountKey) -> Int32 {
        if let cached = self.cachedCounts[key] {
            return cached
        } else if let value = self.valueBox.get(self.table, key: self.key(.count(key))) {
            var count: Int32 = 0
            value.read(&count, offset: 0, length: 4)
            self.cachedCounts[key] = count
            return count
        } else {
            self.cachedCounts[key] = 0
            return 0
        }
    }
    
    func setCount(_ key: PendingMessageActionsMetadataCountKey, value: Int32) {
        if self.cachedCounts[key] != value {
            self.cachedCounts[key] = value
            self.updatedCounts.insert(key)
        }
    }
    
    func addCount(_ key: PendingMessageActionsMetadataCountKey, value: Int32) -> Int32 {
        let updatedCount = self.getCount(key) + value
        self.setCount(key, value: updatedCount)
        return updatedCount
    }
    
    override func clearMemoryCache() {
        self.cachedCounts.removeAll()
        assert(self.updatedCounts.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedCounts.isEmpty {
            for key in self.updatedCounts {
                if let count = self.cachedCounts[key] {
                    var countValue: Int32 = count
                    self.valueBox.set(self.table, key: self.key(.count(key)), value: MemoryBuffer(memory: &countValue, capacity: 4, length: 4, freeWhenDone: false))
                } else {
                    assertionFailure()
                }
            }
            
            self.updatedCounts.removeAll()
        }
    }
}
