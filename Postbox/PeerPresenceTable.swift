import Foundation

final class PeerPresenceTable: Table {
    private let sharedEncoder = Encoder()
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedPresences: [PeerId: PeerPresence] = [:]
    private var updatedPeerIds = Set<PeerId>()
    
    override init(valueBox: ValueBox, tableId: Int32) {
        super.init(valueBox: valueBox, tableId: tableId)
    }
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    func set(id: PeerId, presence: PeerPresence) {
        self.cachedPresences[id] = presence
        self.updatedPeerIds.insert(id)
    }
    
    func get(_ id: PeerId) -> PeerPresence? {
        if let presence = self.cachedPresences[id] {
            return presence
        }
        if let value = self.valueBox.get(self.tableId, key: self.key(id)) {
            if let presence = Decoder(buffer: value).decodeRootObject() as? PeerPresence {
                self.cachedPresences[id] = presence
                return presence
            }
        }
        return nil
    }
    
    override func clearMemoryCache() {
        self.cachedPresences.removeAll()
        self.updatedPeerIds.removeAll()
    }
    
    override func beforeCommit() {
        for peerId in self.updatedPeerIds {
            if let presence = self.cachedPresences[peerId] {
                self.sharedEncoder.reset()
                self.sharedEncoder.encodeRootObject(presence)
                
                self.valueBox.set(self.tableId, key: self.key(peerId), value: self.sharedEncoder.readBufferNoCopy())
            }
        }
        
        self.updatedPeerIds.removeAll()
    }
}
