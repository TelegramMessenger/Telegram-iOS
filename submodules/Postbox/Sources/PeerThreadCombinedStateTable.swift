import Foundation

public struct StoredPeerThreadCombinedState: Equatable, Codable {
    public struct Index: Equatable, Comparable, Codable {
        private enum CodingKeys: String, CodingKey {
            case timestamp = "t"
            case threadId = "i"
            case messageId = "m"
        }
        
        public var timestamp: Int32
        public var threadId: Int64
        public var messageId: Int32
        
        public init(timestamp: Int32, threadId: Int64, messageId: Int32) {
            self.timestamp = timestamp
            self.threadId = threadId
            self.messageId = messageId
        }
        
        public static func <(lhs: Index, rhs: Index) -> Bool {
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp < rhs.timestamp
            }
            if lhs.threadId != rhs.threadId {
                return lhs.threadId < rhs.threadId
            }
            return lhs.messageId < rhs.messageId
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case data = "d"
        case validIndexBoundary = "r"
    }
    
    public var data: CodableEntry
    public var validIndexBoundary: Index?
    
    public init(data: CodableEntry, validIndexBoundary: Index?) {
        self.data = data
        self.validIndexBoundary = validIndexBoundary
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.data = CodableEntry(data: try container.decode(Data.self, forKey: .data))
        self.validIndexBoundary = try container.decodeIfPresent(Index.self, forKey: .validIndexBoundary)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.data.data, forKey: .data)
        try container.encodeIfPresent(self.validIndexBoundary, forKey: .validIndexBoundary)
    }
}

class PeerThreadCombinedStateTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private(set) var updatedIds = Set<PeerId>()
    
    override init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool) {
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        return self.sharedKey
    }
    
    func set(peerId: PeerId, state: StoredPeerThreadCombinedState?) {
        if let state = state {
            do {
                let data = try AdaptedPostboxEncoder().encode(state)
                self.valueBox.set(self.table, key: self.key(peerId: peerId), value: MemoryBuffer(data: data))
            } catch {
                assertionFailure()
            }
        } else {
            self.valueBox.remove(self.table, key: self.key(peerId: peerId), secure: false)
        }
    }
    
    func get(peerId: PeerId) -> StoredPeerThreadCombinedState? {
        do {
            guard let value = self.valueBox.get(self.table, key: self.key(peerId: peerId)) else {
                return nil
            }
            let state = try withExtendedLifetime(value, {
                return try AdaptedPostboxDecoder().decode(StoredPeerThreadCombinedState.self, from: value.dataNoCopy())
            })
            return state
        } catch {
            return nil
        }
    }
    
    override func beforeCommit() {
        super.beforeCommit()
    }
}

struct StoredPeerThreadsSummary: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case unreadCount = "u"
    }
    
    var unreadCount: Int32
    
    init(unreadCount: Int32) {
        self.unreadCount = unreadCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.unreadCount = try container.decode(Int32.self, forKey: .unreadCount)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.unreadCount, forKey: .unreadCount)
    }
}

class PeerThreadsSummaryTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private(set) var updatedIds = Set<PeerId>()
    
    override init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool) {
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        return self.sharedKey
    }
    
    private func set(peerId: PeerId, state: StoredPeerThreadsSummary) {
        do {
            let data = try AdaptedPostboxEncoder().encode(state)
            self.valueBox.set(self.table, key: self.key(peerId: peerId), value: MemoryBuffer(data: data))
        } catch {
            assertionFailure()
        }
    }
    
    func get(peerId: PeerId) -> StoredPeerThreadsSummary? {
        do {
            guard let value = self.valueBox.get(self.table, key: self.key(peerId: peerId)) else {
                return nil
            }
            let state = try withExtendedLifetime(value, {
                return try AdaptedPostboxDecoder().decode(StoredPeerThreadsSummary.self, from: value.dataNoCopy())
            })
            return state
        } catch {
            return nil
        }
    }
    
    func update(peerIds: Set<PeerId>, indexTable: MessageHistoryThreadIndexTable, combinedStateTable: PeerThreadCombinedStateTable) -> [PeerId: StoredPeerThreadsSummary] {
        var updatedInitialSummaries: [PeerId: StoredPeerThreadsSummary] = [:]
        
        for peerId in peerIds {
            var unreadCount: Int32 = 0
            for item in indexTable.fetch(peerId: peerId, namespace: 0, start: .upperBound, end: .lowerBound, limit: 20) {
                if item.info.summary.mutedUntil == nil {
                    unreadCount += item.info.summary.totalUnreadCount
                }
            }
            let current = self.get(peerId: peerId)
            if current?.unreadCount != unreadCount {
                updatedInitialSummaries[peerId] = current ?? StoredPeerThreadsSummary(unreadCount: 0)
                self.set(peerId: peerId, state: StoredPeerThreadsSummary(unreadCount: unreadCount))
            }
        }
        
        return updatedInitialSummaries
    }
    
    override func beforeCommit() {
        super.beforeCommit()
    }
}
