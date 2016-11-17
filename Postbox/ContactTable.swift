import Foundation

final class ContactTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private var originalPeerIds: Set<PeerId>?
    private var peerIds: Set<PeerId>?
    
    private var addedPeerIds = Set<PeerId>()
    private var removedPeerIds = Set<PeerId>()
    
    private func key(_ id: PeerId, sharedKey: ValueBoxKey = ValueBoxKey(length: 8)) -> ValueBoxKey {
        sharedKey.setInt64(0, value: id.toInt64())
        return sharedKey
    }
    
    private func lowerBound() -> ValueBoxKey {
        return self.key(PeerId(namespace: 0, id: 0))
    }
    
    private func upperBound() -> ValueBoxKey {
        return self.key(PeerId(namespace: Int32.max, id: Int32.max))
    }
    
    func isContact(peerId: PeerId) -> Bool {
        if let peerIds = self.peerIds {
            return peerIds.contains(peerId)
        } else {
            var peerIds = Set<PeerId>()
            self.valueBox.range(self.table, start: self.lowerBound(), end: self.upperBound(), keys: { key in
                peerIds.insert(PeerId(key.getInt64(0)))
                return true
                }, limit: 0)
            self.peerIds = peerIds
            self.originalPeerIds = peerIds
            return peerIds.contains(peerId)
        }
    }
    
    func get() -> Set<PeerId> {
        if let peerIds = self.peerIds {
            return peerIds
        } else {
            var peerIds = Set<PeerId>()
            self.valueBox.range(self.table, start: self.lowerBound(), end: self.upperBound(), keys: { key in
                peerIds.insert(PeerId(key.getInt64(0)))
                return true
            }, limit: 0)
            self.peerIds = peerIds
            self.originalPeerIds = peerIds
            return peerIds
        }
    }
    
    func replace(_ ids: Set<PeerId>) {
        let currentPeerIds = self.get()
        
        let previousPeerIds: Set<PeerId>
        if let originalPeerIds = self.originalPeerIds {
            previousPeerIds = originalPeerIds
        } else {
            previousPeerIds = currentPeerIds
            self.originalPeerIds = currentPeerIds
        }
        
        self.removedPeerIds = previousPeerIds.subtracting(ids)
        self.addedPeerIds = ids.subtracting(previousPeerIds)
        
        self.peerIds = ids
    }
    
    override func clearMemoryCache() {
        self.originalPeerIds = nil
        self.peerIds = nil
        self.addedPeerIds.removeAll()
        self.removedPeerIds.removeAll()
    }
    
    override func beforeCommit() {
        let sharedKey = self.key(PeerId(namespace: 0, id: 0))
        
        for peerId in self.removedPeerIds {
            self.valueBox.remove(self.table, key: self.key(peerId, sharedKey: sharedKey))
        }
        
        for peerId in self.addedPeerIds {
            self.valueBox.set(self.table, key: self.key(peerId, sharedKey: sharedKey), value: MemoryBuffer())
        }
        
        self.originalPeerIds = self.peerIds
        
        self.addedPeerIds.removeAll()
        self.removedPeerIds.removeAll()
    }
}
