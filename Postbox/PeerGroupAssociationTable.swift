import Foundation

public struct PeerGroupId: Comparable, Hashable {
    public let rawValue: Int32
    
    public var hashValue: Int {
        return self.rawValue.hashValue
    }
    
    public static func ==(lhs: PeerGroupId, rhs: PeerGroupId) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public static func <(lhs: PeerGroupId, rhs: PeerGroupId) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

private struct PeerAndGroupId: Equatable, Hashable {
    let peerId: PeerId
    let peerGroupId: PeerGroupId
    
    init(peerId: PeerId, peerGroupId: PeerGroupId) {
        self.peerId = peerId
        self.peerGroupId = peerGroupId
    }
    
    public var hashValue: Int {
        return self.peerId.hashValue &* 31 &+ self.peerGroupId.hashValue
    }
    
    public static func ==(lhs: PeerAndGroupId, rhs: PeerAndGroupId) -> Bool {
        return lhs.peerId == rhs.peerId && lhs.peerGroupId == rhs.peerGroupId
    }
}

final class PeerGroupAssociationTable: Table {
    private var cachedEntries: [PeerId: Set<PeerGroupId>]?
    private var updatedEntries = Set<PeerAndGroupId>()
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    private func get() -> [PeerId: Set<PeerGroupId>] {
        if let cached = self.cachedEntries {
            return cached
        } else {
            var entries: [PeerId: Set<PeerGroupId>] = [:]
            self.valueBox.scan(self.table, keys: { key in
                let peerIdValue: Int64 = key.getInt64(0)
                let peerId = PeerId(peerIdValue)
                let groupIdValue: Int32 = key.getInt32(8)
                if entries[peerId] == nil {
                    entries[peerId] = Set()
                }
                entries[peerId]!.insert(PeerGroupId(rawValue: groupIdValue))
                return true
            })
            self.cachedEntries = entries
            return entries
        }
    }
    
    func set(peerId: PeerId, groupId: PeerGroupId, participates: Bool) {
        let peerGroupIds = self.get()[peerId]
        if participates {
            if peerGroupIds == nil || !peerGroupIds!.contains(groupId) {
                if self.cachedEntries![peerId] == nil {
                    self.cachedEntries![peerId] = Set()
                }
                self.cachedEntries![peerId]!.insert(groupId)
                self.updatedEntries.insert(PeerAndGroupId(peerId: peerId, peerGroupId: groupId))
            }
        } else if let peerGroupIds = peerGroupIds, peerGroupIds.contains(groupId) {
            self.cachedEntries![peerId]!.remove(groupId)
            if self.cachedEntries![peerId]!.isEmpty {
                self.cachedEntries!.removeValue(forKey: peerId)
            }
            self.updatedEntries.insert(PeerAndGroupId(peerId: peerId, peerGroupId: groupId))
        }
    }
    
    override func clearMemoryCache() {
        assert(self.updatedEntries.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedEntries.isEmpty {
            if let cachedEntries = self.cachedEntries {
                let sharedKey = ValueBoxKey(length: 8 + 4)
                for peerAndGroupId in self.updatedEntries {
                    sharedKey.setInt64(0, value: peerAndGroupId.peerId.toInt64())
                    sharedKey.setInt32(8, value: peerAndGroupId.peerGroupId.rawValue)
                    
                    if let entry = cachedEntries[peerAndGroupId.peerId], entry.contains(peerAndGroupId.peerGroupId) {
                        self.valueBox.set(self.table, key: sharedKey, value: MemoryBuffer())
                    } else {
                        self.valueBox.remove(self.table, key: sharedKey)
                    }
                }
            } else {
                assertionFailure()
            }
            
            self.updatedEntries.removeAll()
        }
    }
}
