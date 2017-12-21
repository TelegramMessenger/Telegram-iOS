import Foundation

public struct PeerGroupId: Comparable, Hashable {
    public let rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
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

struct WrappedPeerGroupId: Hashable {
    let groupId: PeerGroupId?
    
    var hashValue: Int {
        return self.groupId?.hashValue ?? 0
    }
    
    static func ==(lhs: WrappedPeerGroupId, rhs: WrappedPeerGroupId) -> Bool {
        return lhs.groupId == rhs.groupId
    }
}

final class PeerGroupAssociationTable: Table {
    private var cachedEntries: [PeerId: PeerGroupId]?
    private var updatedPeerIds = Set<PeerId>()
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private func preloadCache() {
        if self.cachedEntries == nil {
            var entries: [PeerId: PeerGroupId] = [:]
            self.valueBox.scanInt64(self.table, values: { key, value in
                let peerIdValue: Int64 = key
                let peerId = PeerId(peerIdValue)
                var groupIdValue: Int32 = 0
                value.read(&groupIdValue, offset: 0, length: 4)
                entries[peerId] = PeerGroupId(rawValue: groupIdValue)
                return true
            })
            self.cachedEntries = entries
        }
    }
    
    func get(peerIds: Set<PeerId>) -> Set<PeerGroupId> {
        self.preloadCache()
        
        var result = Set<PeerGroupId>()
        if let cachedEntries = self.cachedEntries {
            for peerId in peerIds {
                if let groupId = cachedEntries[peerId] {
                    result.insert(groupId)
                }
            }
        } else {
            assertionFailure()
        }
        return result
    }
    
    func get(peerId: PeerId) -> PeerGroupId? {
        self.preloadCache()
        return self.cachedEntries![peerId]
    }
    
    func get(groupId: PeerGroupId) -> Set<PeerId> {
        self.preloadCache()
        var result = Set<PeerId>()
        for (peerId, itemGroupId) in self.cachedEntries! {
            if groupId == itemGroupId {
                result.insert(peerId)
            }
        }
        return result
    }
    
    func set(peerId: PeerId, groupId: PeerGroupId?, initialPeerGroupIdsBeforeUpdate: inout [PeerId: WrappedPeerGroupId]) {
        self.preloadCache()
        
        let previousGroupId = self.cachedEntries![peerId]
        if previousGroupId != groupId {
            if initialPeerGroupIdsBeforeUpdate[peerId] == nil {
                initialPeerGroupIdsBeforeUpdate[peerId] = WrappedPeerGroupId(groupId: previousGroupId)
            }
            if let groupId = groupId {
                self.cachedEntries![peerId] = groupId
            } else {
                self.cachedEntries!.removeValue(forKey: peerId)
            }
            self.updatedPeerIds.insert(peerId)
        }
    }
    
    override func clearMemoryCache() {
        assert(self.updatedPeerIds.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedPeerIds.isEmpty {
            if let cachedEntries = self.cachedEntries {
                let sharedKey = ValueBoxKey(length: 8)
                for peerId in self.updatedPeerIds {
                    sharedKey.setInt64(0, value: peerId.toInt64())
                    
                    if let groupId = cachedEntries[peerId] {
                        var groupIdValue: Int32 = groupId.rawValue
                        self.valueBox.set(self.table, key: sharedKey, value: MemoryBuffer(memory: &groupIdValue, capacity: 4, length: 4, freeWhenDone: false))
                    } else {
                        self.valueBox.remove(self.table, key: sharedKey)
                    }
                }
            } else {
                assertionFailure()
            }
            
            self.updatedPeerIds.removeAll()
        }
    }
}
