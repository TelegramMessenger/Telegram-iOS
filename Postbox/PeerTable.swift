import Foundation

final class PeerTable {
    let valueBox: ValueBox
    let tableId: Int32
    
    private let sharedEncoder = Encoder()
    private let sharedKey = ValueBoxKey(length: 8)
    private var cachedPeers: [PeerId: Peer] = [:]
    
    init(valueBox: ValueBox, tableId: Int32) {
        self.valueBox = valueBox
        self.tableId = tableId
    }
    
    private func key(id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    func set(peer: Peer) {
        self.sharedEncoder.reset()
        self.sharedEncoder.encodeRootObject(peer)
        
        self.valueBox.set(self.tableId, key: self.key(peer.id), value: self.sharedEncoder.readBufferNoCopy())
    }
    
    func get(id: PeerId) -> Peer? {
        if let peer = self.cachedPeers[id] {
            return peer
        }
        if let value = self.valueBox.get(self.tableId, key: self.key(id)) {
            if let peer = Decoder(buffer: value).decodeRootObject() as? Peer {
                self.cachedPeers[id] = peer
                return peer
            }
        }
        return nil
    }
}