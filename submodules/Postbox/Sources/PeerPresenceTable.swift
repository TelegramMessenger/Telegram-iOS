import Foundation

final class PeerPresenceTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private let sharedEncoder = PostboxEncoder()
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedPresences: [PeerId: PeerPresence] = [:]
    private var updatedPeerIds = Set<PeerId>()
    
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
        if let value = self.valueBox.get(self.table, key: self.key(id)) {
            if let presence = PostboxDecoder(buffer: value).decodeRootObject() as? PeerPresence {
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
        if !self.updatedPeerIds.isEmpty {
            for peerId in self.updatedPeerIds {
                if let presence = self.cachedPresences[peerId] {
                    self.sharedEncoder.reset()
                    self.sharedEncoder.encodeRootObject(presence)
                    
                    self.valueBox.set(self.table, key: self.key(peerId), value: self.sharedEncoder.readBufferNoCopy())
                }
            }
            
            self.updatedPeerIds.removeAll()
        }
    }
}
