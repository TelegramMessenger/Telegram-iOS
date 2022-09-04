import Foundation

final class PeerTimeoutPropertiesTable: Table {
    private struct Key: Hashable {
        var peerId: PeerId
        var timestamp: UInt32
    }
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private let sharedKey = ValueBoxKey(length: 4 + 8)
    
    private var cache: [Key: Bool] = [:]
    private var updated = Set<Key>()
    
    var hasUpdates: Bool {
        return !self.updated.isEmpty
    }
    
    private func key(_ key: Key) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: Int32(bitPattern: key.timestamp))
        self.sharedKey.setInt64(4, value: key.peerId.toInt64())
        return self.sharedKey
    }
    
    private func lowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: 0)
        return key
    }
    
    private func upperBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: Int32(bitPattern: UInt32.max))
        key.setInt64(4, value: Int64(bitPattern: UInt64.max))
        return key
    }
    
    func min() -> (peerId: PeerId, timestamp: UInt32)? {
        var result: Key?
        self.valueBox.range(self.table, start: self.lowerBound(), end: self.upperBound(), keys: { key in
            result = Key(peerId: PeerId(key.getInt64(4)), timestamp: UInt32(bitPattern: key.getInt32(0)))
            return false
        }, limit: 1)
        return result.flatMap { result -> (peerId: PeerId, timestamp: UInt32) in
            return (result.peerId, result.timestamp)
        }
    }
    
    private func get(peerId: PeerId, timestamp: UInt32) -> Bool {
        let key = Key(peerId: peerId, timestamp: timestamp)
        if let cachedValue = self.cache[key] {
            return cachedValue
        } else {
            let value = self.valueBox.exists(self.table, key: self.key(Key(peerId: peerId, timestamp: timestamp)))
            self.cache[key] = value
            return value
        }
    }
    
    func remove(peerId: PeerId, timestamp: UInt32) {
        let key = Key(peerId: peerId, timestamp: timestamp)
        if self.get(peerId: peerId, timestamp: timestamp) {
            self.cache[key] = false
            self.updated.insert(key)
        }
    }
    
    func add(peerId: PeerId, timestamp: UInt32) {
        let key = Key(peerId: peerId, timestamp: timestamp)
        if !self.get(peerId: peerId, timestamp: timestamp) {
            self.cache[key] = true
            self.updated.insert(key)
        }
    }
    
    override func clearMemoryCache() {
        self.cache.removeAll()
    }
    
    override func beforeCommit() {
        if !self.updated.isEmpty {
            for key in self.updated {
                if let value = self.cache[key] {
                    if value {
                        self.valueBox.set(self.table, key: self.key(key), value: MemoryBuffer())
                    } else {
                        self.valueBox.remove(self.table, key: self.key(key), secure: false)
                    }
                }
            }
            
            self.updated.removeAll()
            
            if !self.useCaches {
                self.cache.removeAll()
            }
        }
    }
}
