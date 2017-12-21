import Foundation

public final class GroupFeedState {
}

private struct GroupFeedStateEntry {
    let state: GroupFeedState?
    
    init(_ state: GroupFeedState?) {
        self.state = state
    }
}

final class GroupFeedStateTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private var cachedStates: [PeerGroupId: GroupFeedStateEntry] = [:]
    private var updatedGroupIds = Set<PeerGroupId>()
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(_ id: PeerGroupId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: Int64(id.rawValue))
        return self.sharedKey
    }
    
    func get(_ id: PeerGroupId) -> GroupFeedState? {
        if let state = self.cachedStates[id] {
            return state.state
        } else {
            /*if let value = self.valueBox.get(self.table, key: self.key(id)), let state = PostboxDecoder(buffer: value).decodeRootObject() {
                self.cachedPeerChatStates[id] = state
                return state
            } else {
                self.cachedPeerChatStates[id] = nil
                return nil
            }*/
            return nil
        }
    }
    
    func set(_ id: PeerGroupId, state: GroupFeedState?) {
        self.cachedStates[id] = GroupFeedStateEntry(state)
        self.updatedGroupIds.insert(id)
    }
    
    override func clearMemoryCache() {
        self.cachedStates.removeAll()
        self.updatedGroupIds.removeAll()
    }
    
    override func beforeCommit() {
        if !self.updatedGroupIds.isEmpty {
            for id in self.updatedGroupIds {
                if let entry = self.cachedStates[id], let state = entry.state {
                    /*sharedEncoder.reset()
                    sharedEncoder.encodeRootObject(state)
                    self.valueBox.set(self.table, key: self.key(id), value: sharedEncoder.readBufferNoCopy())*/
                } else {
                    self.valueBox.remove(self.table, key: self.key(id))
                }
            }
            self.updatedGroupIds.removeAll()
        }
    }
}

