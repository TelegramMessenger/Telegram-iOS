import Foundation

public protocol PeerGroupState: PostboxCoding {
    func equals(_ other: PeerGroupState) -> Bool
}

private struct PeerGroupStateEntry {
    let state: PeerGroupState?
    
    init(_ state: PeerGroupState?) {
        self.state = state
    }
}

final class PeerGroupStateTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private var cachedStates: [PeerGroupId: PeerGroupStateEntry] = [:]
    private var updatedGroupIds = Set<PeerGroupId>()
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(_ id: PeerGroupId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: Int64(id.rawValue))
        return self.sharedKey
    }
    
    func get(_ id: PeerGroupId) -> PeerGroupState? {
        if let state = self.cachedStates[id] {
            return state.state
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(id)), let state = PostboxDecoder(buffer: value).decodeRootObject() as? PeerGroupState {
                self.cachedStates[id] = PeerGroupStateEntry(state)
                return state
            } else {
                self.cachedStates[id] = PeerGroupStateEntry(nil)
                return nil
            }
        }
    }
    
    func set(_ id: PeerGroupId, state: PeerGroupState?) {
        self.cachedStates[id] = PeerGroupStateEntry(state)
        self.updatedGroupIds.insert(id)
    }
    
    override func clearMemoryCache() {
        self.cachedStates.removeAll()
        self.updatedGroupIds.removeAll()
    }
    
    override func beforeCommit() {
        if !self.updatedGroupIds.isEmpty {
            for id in self.updatedGroupIds {
                let sharedEncoder = PostboxEncoder()
                if let entry = self.cachedStates[id], let state = entry.state {
                    sharedEncoder.reset()
                    sharedEncoder.encodeRootObject(state)
                    self.valueBox.set(self.table, key: self.key(id), value: sharedEncoder.readBufferNoCopy())
                } else {
                    self.valueBox.remove(self.table, key: self.key(id))
                }
            }
            self.updatedGroupIds.removeAll()
        }
    }
}


