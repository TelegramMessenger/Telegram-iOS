import Foundation

public struct PeerChatThreadId: Hashable {
    public var peerId: PeerId
    public var threadId: Int64

    public init(peerId: PeerId, threadId: Int64) {
        self.peerId = peerId
        self.threadId = threadId
    }
}

final class PeerChatThreadInterfaceStateTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private var states: [PeerChatThreadId: PeerChatInterfaceState?] = [:]
    private var peerIdsWithUpdatedStates = Set<PeerChatThreadId>()
    
    private let sharedKey = ValueBoxKey(length: 8 + 8)
    
    private func key(_ peerId: PeerChatThreadId, sharedKey: ValueBoxKey = ValueBoxKey(length: 8)) -> ValueBoxKey {
        sharedKey.setInt64(0, value: peerId.peerId.toInt64())
        sharedKey.setInt64(8, value: peerId.threadId)
        return sharedKey
    }
    
    func get(_ peerId: PeerChatThreadId) -> PeerChatInterfaceState? {
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
    
    func set(_ peerId: PeerChatThreadId, state: PeerChatInterfaceState?) -> Bool {
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
        return updated
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
