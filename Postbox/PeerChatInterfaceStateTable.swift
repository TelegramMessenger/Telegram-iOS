import Foundation

final class PeerChatInterfaceStateTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
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
        } else if let value = self.valueBox.get(self.table, key: self.key(peerId, sharedKey: self.sharedKey)), let state = PostboxDecoder(buffer: value).decodeRootObject() as? PeerChatInterfaceState {
            self.states[peerId] = state
            return state
        } else {
            self.states[peerId] = nil
            return nil
        }
    }
    
    func set(_ peerId: PeerId, state: PeerChatInterfaceState?) -> (updated: Bool, updatedEmbeddedState: Bool) {
        let currentState = self.get(peerId)
        var updated = false
        var updatedEmbeddedState = false
        if let currentState = currentState, let state = state {
            if !currentState.isEqual(to: state) {
                updated = true
                if let currentEmbeddedState = currentState.chatListEmbeddedState, let embeddedState = state.chatListEmbeddedState {
                    if !currentEmbeddedState.isEqual(to: embeddedState) {
                        updatedEmbeddedState = true
                    }
                } else if (currentState.chatListEmbeddedState != nil) != (state.chatListEmbeddedState != nil) {
                    updatedEmbeddedState = true
                }
            }
        } else if (currentState != nil) != (state != nil) {
            updated = true
            updatedEmbeddedState = true
        }
        if updated {
            self.states[peerId] = state
            self.peerIdsWithUpdatedStates.insert(peerId)
        }
        return (updated, updatedEmbeddedState)
    }
    
    override func clearMemoryCache() {
        self.states.removeAll()
        self.peerIdsWithUpdatedStates.removeAll()
    }
    
    override func beforeCommit() {
        if !self.peerIdsWithUpdatedStates.isEmpty {
            let sharedEncoder = PostboxEncoder()
            for peerId in self.peerIdsWithUpdatedStates {
                if let state = self.states[peerId] {
                    if let state = state {
                    sharedEncoder.reset()
                    sharedEncoder.encodeRootObject(state)
                    self.valueBox.set(self.table, key: self.key(peerId, sharedKey: self.sharedKey), value: sharedEncoder.readBufferNoCopy())
                    } else {
                        self.valueBox.remove(self.table, key: self.key(peerId, sharedKey: self.sharedKey), secure: false)
                    }
                }
            }
            self.peerIdsWithUpdatedStates.removeAll()
        }
    }
}
