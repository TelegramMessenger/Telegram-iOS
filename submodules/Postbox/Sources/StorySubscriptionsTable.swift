import Foundation

final class StorySubscriptionsTable: Table {
    enum Event {
        case replaceAll
    }
    
    private struct Key: Hashable {
        var peerId: PeerId
    }
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(_ key: Key) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: key.peerId.toInt64())
        return self.sharedKey
    }
    
    private func getAllKeys() -> [Key] {
        var result: [Key] = []
        
        self.valueBox.scan(self.table, keys: { key in
            let peerId = PeerId(key.getInt64(0))
            
            result.append(Key(peerId: peerId))
            
            return true
        })
        
        return result
    }
    
    public func getAll() -> [PeerId] {
        var result: [PeerId] = []
        
        self.valueBox.scan(self.table, keys: { key in
            let peerId = PeerId(key.getInt64(0))
            result.append(peerId)
            
            return true
        })
        
        return result
    }
    
    public func replaceAll(peerIds: [PeerId], events: inout [Event]) {
        for key in self.getAllKeys() {
            self.valueBox.remove(self.table, key: self.key(key), secure: true)
        }
        
        for peerId in peerIds {
            self.valueBox.set(self.table, key: self.key(Key(peerId: peerId)), value: MemoryBuffer())
        }
        
        events.append(.replaceAll)
    }
    
    override func clearMemoryCache() {
    }
    
    override func beforeCommit() {
    }
}
