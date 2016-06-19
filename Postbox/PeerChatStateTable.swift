import Foundation

final class PeerChatStateTable: Table {
    private var cachedPeerChatStates: [PeerId: Coding?] = [:]
    private var updatedPeerIds = Set<PeerId>()
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    func get(_ id: PeerId) -> Coding? {
        if let state = self.cachedPeerChatStates[id] {
            return state
        } else {
            if let value = self.valueBox.get(self.tableId, key: self.key(id)), state = Decoder(buffer: value).decodeRootObject() {
                self.cachedPeerChatStates[id] = state
                return state
            } else {
                self.cachedPeerChatStates[id] = nil
                return nil
            }
        }
    }
    
    func set(_ id: PeerId, state: Coding?) {
        self.cachedPeerChatStates[id] = state
        self.updatedPeerIds.insert(id)
    }
    
    override func beforeCommit() {
        let sharedEncoder = Encoder()
        for id in self.updatedPeerIds {
            if let wrappedState = self.cachedPeerChatStates[id], state = wrappedState {
                sharedEncoder.reset()
                sharedEncoder.encodeRootObject(state)
                self.valueBox.set(self.tableId, key: self.key(id), value: sharedEncoder.readBufferNoCopy())
            } else {
                self.valueBox.remove(self.tableId, key: self.key(id))
            }
        }
        self.updatedPeerIds.removeAll()
    }
}
