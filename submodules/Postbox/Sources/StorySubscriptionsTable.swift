import Foundation

final class StorySubscriptionsTable: Table {
    enum Event {
        case replaceAll(key: PostboxStorySubscriptionsKey)
    }
    
    private struct Key: Hashable {
        var subscriptionsKey: PostboxStorySubscriptionsKey
        var peerId: PeerId
    }
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private let sharedKey = ValueBoxKey(length: 4 + 8)
    
    private func key(_ key: Key) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: key.subscriptionsKey.rawValue)
        self.sharedKey.setInt64(4, value: key.peerId.toInt64())
        return self.sharedKey
    }
    
    private func getAllKeys(subscriptionsKey: PostboxStorySubscriptionsKey) -> [Key] {
        var result: [Key] = []
        
        self.valueBox.scan(self.table, keys: { key in
            if key.length != 4 + 8 {
                return true
            }
            if let readSubscriptionsKey = PostboxStorySubscriptionsKey(rawValue: key.getInt32(0)) {
                if readSubscriptionsKey == subscriptionsKey {
                    let peerId = PeerId(key.getInt64(4))
                    result.append(Key(subscriptionsKey: subscriptionsKey, peerId: peerId))
                }
            }
            
            return true
        })
        
        return result
    }
    
    public func getAll(subscriptionsKey: PostboxStorySubscriptionsKey) -> [PeerId] {
        var result: [PeerId] = []
        
        self.valueBox.scan(self.table, keys: { key in
            if key.length != 4 + 8 {
                return true
            }
            if let readSubscriptionsKey = PostboxStorySubscriptionsKey(rawValue: key.getInt32(0)) {
                if readSubscriptionsKey == subscriptionsKey {
                    let peerId = PeerId(key.getInt64(4))
                    result.append(peerId)
                }
            }
            
            return true
        })
        
        return result
    }
    
    public func contains(subscriptionsKey: PostboxStorySubscriptionsKey, peerId: PeerId) -> Bool {
        if let _ = self.valueBox.get(self.table, key: self.key(Key(subscriptionsKey: subscriptionsKey, peerId: peerId))) {
            return true
        } else {
            return false
        }
    }
    
    public func replaceAll(subscriptionsKey: PostboxStorySubscriptionsKey, peerIds: [PeerId], events: inout [Event]) {
        for key in self.getAllKeys(subscriptionsKey: subscriptionsKey) {
            self.valueBox.remove(self.table, key: self.key(key), secure: true)
        }
        
        for peerId in peerIds {
            self.valueBox.set(self.table, key: self.key(Key(subscriptionsKey: subscriptionsKey, peerId: peerId)), value: MemoryBuffer())
        }
        
        events.append(.replaceAll(key: subscriptionsKey))
    }
    
    override func clearMemoryCache() {
    }
    
    override func beforeCommit() {
    }
}
