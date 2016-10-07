import Foundation

final class PeerStatusTable: Table {
    private let sharedEncoder = Encoder()
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedStatuses: [PeerId: Coding] = [:]
    private var updatedPeerIds = Set<PeerId>()
    
    override init(valueBox: ValueBox, tableId: Int32) {
        super.init(valueBox: valueBox, tableId: tableId)
    }
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    func set(id: PeerId, status: Coding) {
        self.cachedStatuses[id] = status
        self.updatedPeerIds.insert(id)
    }
    
    func get(_ id: PeerId) -> Coding? {
        if let status = self.cachedStatuses[id] {
            return status
        }
        if let value = self.valueBox.get(self.tableId, key: self.key(id)) {
            if let status = Decoder(buffer: value).decodeRootObject() {
                self.cachedStatuses[id] = status
                return status
            }
        }
        return nil
    }
    
    override func clearMemoryCache() {
        self.cachedStatuses.removeAll()
        self.updatedPeerIds.removeAll()
    }
    
    override func beforeCommit() {
        for peerId in self.updatedPeerIds {
            if let status = self.cachedStatuses[peerId] {
                self.sharedEncoder.reset()
                self.sharedEncoder.encodeRootObject(status)
                
                self.valueBox.set(self.tableId, key: self.key(peerId), value: self.sharedEncoder.readBufferNoCopy())
            }
        }
        
        self.updatedPeerIds.removeAll()
    }
}
