import Foundation

final class PeerChatInterfaceStateTable: Table {
    private var states: [PeerId: PeerChatInterfaceState?] = [:]
    private var peerIdsWithUpdatedStates = Set<PeerId>()
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(_ peerId: PeerId, sharedKey: ValueBoxKey = ValueBoxKey(length: 8)) -> ValueBoxKey {
        sharedKey.setInt64(0, value: peerId.toInt64())
        return sharedKey
    }
    
    func get(_ peerId: PeerId) -> PeerChatInterfaceState? {
        if let cachedValue = self.states[peerId] {
            return cachedValue
        } else if let value = self.valueBox.get(self.tableId, key: self.key(peerId, sharedKey: self.sharedKey)), let state = Decoder(buffer: value).decodeRootObject() as? PeerChatInterfaceState {
            self.states[peerId] = state
            return state
        } else {
            self.states[peerId] = nil
            return nil
        }
    }
    
    func set(_ peerId: PeerId, state: PeerChatInterfaceState?) {
        let currentState = self.get(peerId)
        var updated = false
        if let currentState = currentState, let state = state {
            if !currentState.isEqual(to: state) {
                updated = true
            }
        } else if (currentState != nil) != (state != nil) {
            updated = true
        }
        if updated {
            self.states[peerId] = state
            self.peerIdsWithUpdatedStates.insert(peerId)
        }
    }
    
    override func clearMemoryCache() {
        self.states.removeAll()
        self.peerIdsWithUpdatedStates.removeAll()
    }
    
    override func beforeCommit() {
        if !self.peerIdsWithUpdatedStates.isEmpty {
            let sharedEncoder = Encoder()
            for peerId in self.peerIdsWithUpdatedStates {
                if let state = self.states[peerId] {
                    if let state = state {
                    sharedEncoder.reset()
                    sharedEncoder.encodeRootObject(state)
                    self.valueBox.set(self.tableId, key: self.key(peerId, sharedKey: self.sharedKey), value: sharedEncoder.readBufferNoCopy())
                    } else {
                        self.valueBox.remove(self.tableId, key: self.key(peerId, sharedKey: self.sharedKey))
                    }
                }
            }
            self.peerIdsWithUpdatedStates.removeAll()
        }
    }
}
