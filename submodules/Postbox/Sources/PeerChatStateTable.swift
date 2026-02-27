import Foundation

final class PeerChatStateTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private var cachedPeerChatStates: [PeerId: CodableEntry?] = [:]
    private var updatedPeerIds = Set<PeerId>()
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    func get(_ id: PeerId) -> CodableEntry? {
        if let state = self.cachedPeerChatStates[id] {
            return state
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(id)) {
                let state = CodableEntry(data: value.makeData())
                self.cachedPeerChatStates[id] = state
                return state
            } else {
                self.cachedPeerChatStates[id] = nil
                return nil
            }
        }
    }
    
    func set(_ id: PeerId, state: CodableEntry?) {
        self.cachedPeerChatStates[id] = state
        self.updatedPeerIds.insert(id)
    }
    
    override func clearMemoryCache() {
        self.cachedPeerChatStates.removeAll()
        self.updatedPeerIds.removeAll()
    }
    
    override func beforeCommit() {
        if !self.updatedPeerIds.isEmpty {
            for id in self.updatedPeerIds {
                if let wrappedState = self.cachedPeerChatStates[id], let state = wrappedState {
                    self.valueBox.set(self.table, key: self.key(id), value: ReadBuffer(data: state.data))
                } else {
                    self.valueBox.remove(self.table, key: self.key(id), secure: false)
                }
            }
            self.updatedPeerIds.removeAll()
        }
    }
}
