import Foundation

private final class PeerNameTokenIndexTableEntry {
    var sortedPeerIds: [Int64] = []
    
    init() {
    }
    
    init(buffer: MemoryBuffer) {
        assert(buffer.length % 8 == 0)
        
        self.sortedPeerIds.reserveCapacity(buffer.length % 8)
        withExtendedLifetime(buffer, {
            let memory = buffer.memory.assumingMemoryBound(to: Int64.self)
            for i in 0 ..< buffer.length / 8 {
                self.sortedPeerIds.append(memory[i])
            }
        })
    }
    
    private func index(of peerId: Int64) -> Int? {
        var lowerIndex = 0
        var upperIndex = self.sortedPeerIds.count - 1
        
        if lowerIndex > upperIndex {
            return nil
        }
        
        while (true) {
            let currentIndex = (lowerIndex + upperIndex) / 2
            if self.sortedPeerIds[currentIndex] == peerId {
                return currentIndex
            } else if lowerIndex > upperIndex {
                return nil
            } else {
                if self.sortedPeerIds[currentIndex] > peerId {
                    upperIndex = currentIndex - 1
                } else {
                    lowerIndex = currentIndex + 1
                }
            }
        }
    }
    
    func remove(_ peerId: PeerId) -> Bool {
        if let index = self.index(of: peerId.toInt64()) {
            self.sortedPeerIds.remove(at: index)
            return true
        } else {
            return false
        }
    }
    
    func insert(_ peerId: PeerId) -> Bool {
        let insertItem = peerId.toInt64()
        var lo = 0
        var hi = self.sortedPeerIds.count - 1
        while lo <= hi {
            let mid = (lo + hi)/2
            if self.sortedPeerIds[mid] < insertItem {
                lo = mid + 1
            } else if insertItem < self.sortedPeerIds[mid] {
                hi = mid - 1
            } else {
                return false
            }
        }
        self.sortedPeerIds.insert(insertItem, at: lo)
        return true
    }
    
    func withMemoryBuffer(_ f: (MemoryBuffer) -> Void) {
        let buffer = MemoryBuffer(memory: malloc(self.sortedPeerIds.count * 8), capacity: self.sortedPeerIds.count * 8, length: self.sortedPeerIds.count * 8, freeWhenDone: true)
        let memory = buffer.memory.assumingMemoryBound(to: Int64.self)
        var index = 0
        for peerId in self.sortedPeerIds {
            memory[index] = peerId
            index += 1
        }
        f(buffer)
    }
}

final class PeerNameTokenIndexTable: Table {
    private var cachedEntries: [ValueBoxKey: PeerNameTokenIndexTableEntry] = [:]
    private var updatedCachedEntries = Set<ValueBoxKey>()
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    private func getEntry(token: ValueBoxKey) -> PeerNameTokenIndexTableEntry? {
        if let cached = self.cachedEntries[token] {
            return cached
        } else {
            if let value = self.valueBox.get(self.table, key: token) {
                let entry = PeerNameTokenIndexTableEntry(buffer: value)
                self.cachedEntries[token] = entry
                return entry
            } else {
                return nil
            }
        }
    }
    
    private func add(token: ValueBoxKey, peerId: PeerId) {
        let entry: PeerNameTokenIndexTableEntry
        var addToCache = false
        if let current = self.getEntry(token: token) {
            entry = current
        } else {
            entry = PeerNameTokenIndexTableEntry()
            addToCache = true
        }
        if entry.insert(peerId) {
            self.updatedCachedEntries.insert(token)
            if addToCache {
                self.cachedEntries[token] = entry
            }
        }
    }
    
    private func remove(token: ValueBoxKey, peerId: PeerId) {
        let entry: PeerNameTokenIndexTableEntry
        var addToCache = false
        if let current = self.getEntry(token: token) {
            entry = current
        } else {
            entry = PeerNameTokenIndexTableEntry()
            addToCache = true
        }
        if entry.remove(peerId) {
            self.updatedCachedEntries.insert(token)
            if addToCache {
                self.cachedEntries[token] = entry
            }
        }
    }
    
    func add(peerId: PeerId, tokens: [ValueBoxKey]) {
        for token in tokens {
            self.add(token: token, peerId: peerId)
        }
    }
    
    func remove(peerId: PeerId, tokens: [ValueBoxKey]) {
        for token in tokens {
            self.remove(token: token, peerId: peerId)
        }
    }
    
    func matchingPeerIds(tokens: [ValueBoxKey]) -> Set<PeerId> {
        var peerIds: Set<PeerId>?
        for token in tokens {
            if let peerIds = peerIds, peerIds.isEmpty {
                return Set()
            }
            var currentPeerIds = Set<PeerId>()
            self.valueBox.range(self.table, start: token.predecessor, end: token.successor, values: { key, value in
                if let cached = self.cachedEntries[key] {
                    for peerId in cached.sortedPeerIds {
                        currentPeerIds.insert(PeerId(peerId))
                    }
                } else {
                    for peerId in PeerNameTokenIndexTableEntry(buffer: value).sortedPeerIds {
                        currentPeerIds.insert(PeerId(peerId))
                    }
                }
                return true
            }, limit: 0)
            if let previousPeerIds = peerIds {
                peerIds = previousPeerIds.intersection(currentPeerIds)
            } else {
                peerIds = currentPeerIds
            }
        }
        if let peerIds = peerIds {
            return peerIds
        } else {
            return Set()
        }
    }
    
    override func clearMemoryCache() {
        assert(self.cachedEntries.isEmpty)
        assert(self.updatedCachedEntries.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedCachedEntries.isEmpty {
            for token in self.updatedCachedEntries {
                if let entry = self.cachedEntries[token] {
                    entry.withMemoryBuffer { buffer in
                        if buffer.length == 0 {
                            self.valueBox.remove(self.table, key: token)
                        } else {
                            self.valueBox.set(self.table, key: token, value: buffer)
                        }
                    }
                } else {
                    assertionFailure()
                }
            }
            self.updatedCachedEntries.removeAll()
        }
        
        if !self.cachedEntries.isEmpty {
            self.cachedEntries.removeAll()
        }
    }
}
