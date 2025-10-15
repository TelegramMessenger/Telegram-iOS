import Foundation

public struct PeerGroupUnreadCounters: PostboxCoding, Equatable {
    public var messageCount: Int32
    public var chatCount: Int32
    
    public init(messageCount: Int32, chatCount: Int32) {
        self.messageCount = messageCount
        self.chatCount = chatCount
    }
    
    public init(decoder: PostboxDecoder) {
        self.messageCount = decoder.decodeInt32ForKey("m", orElse: 0)
        self.chatCount = decoder.decodeInt32ForKey("c", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.messageCount, forKey: "m")
        encoder.encodeInt32(self.chatCount, forKey: "c")
    }
}

public struct PeerGroupUnreadCountersSummary: PostboxCoding, Equatable {
    public var all: PeerGroupUnreadCounters
    
    public init(all: PeerGroupUnreadCounters) {
        self.all = all
    }
    
    public init(decoder: PostboxDecoder) {
        self.all = decoder.decodeObjectForKey("a", decoder: { PeerGroupUnreadCounters(decoder: $0) }) as! PeerGroupUnreadCounters
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.all, forKey: "a")
    }
}

public struct PeerGroupUnreadCountersCombinedSummary: PostboxCoding, Equatable {
    public enum CountingCategory {
        case chats
        case messages
    }
    
    public enum MuteCategory {
        case all
    }
    
    public var namespaces: [MessageId.Namespace: PeerGroupUnreadCountersSummary]
    
    public init(namespaces: [MessageId.Namespace: PeerGroupUnreadCountersSummary]) {
        self.namespaces = namespaces
    }
    
    public init(decoder: PostboxDecoder) {
        self.namespaces = decoder.decodeObjectDictionaryForKey("n", keyDecoder: { $0.decodeInt32ForKey("k", orElse: 0) }, valueDecoder: { PeerGroupUnreadCountersSummary(decoder: $0) })
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectDictionary(self.namespaces, forKey: "n", keyEncoder: { $1.encodeInt32($0, forKey: "k") })
    }
    
    public func count(countingCategory: CountingCategory, mutedCategory: MuteCategory) -> Int32 {
        var result: Int32 = 0
        for (_, summary) in self.namespaces {
            switch mutedCategory {
                case .all:
                    switch countingCategory {
                        case .chats:
                            result = result &+ summary.all.chatCount
                        case .messages:
                            result = result &+ summary.all.messageCount
                    }
            }
        }
        return result
    }
}

public enum ChatListTotalUnreadStateCategory: Int32 {
    case filtered = 0
    case raw = 1
}

public enum ChatListTotalUnreadStateStats: Int32 {
    case messages = 0
    case chats = 1
}

public struct ChatListTotalUnreadState: PostboxCoding, Equatable {
    public var absoluteCounters: [PeerSummaryCounterTags: ChatListTotalUnreadCounters]
    public var filteredCounters: [PeerSummaryCounterTags: ChatListTotalUnreadCounters]
    
    public init(absoluteCounters: [PeerSummaryCounterTags: ChatListTotalUnreadCounters], filteredCounters: [PeerSummaryCounterTags: ChatListTotalUnreadCounters]) {
        self.absoluteCounters = absoluteCounters
        self.filteredCounters = filteredCounters
    }
    
    public init(decoder: PostboxDecoder) {
        self.absoluteCounters = decoder.decodeObjectDictionaryForKey("ad", keyDecoder: { decoder in
            return PeerSummaryCounterTags(rawValue: decoder.decodeInt32ForKey("k", orElse: 0))
        }, valueDecoder: { decoder in
            return ChatListTotalUnreadCounters(decoder: decoder)
        })
        self.filteredCounters = decoder.decodeObjectDictionaryForKey("fd", keyDecoder: { decoder in
            return PeerSummaryCounterTags(rawValue: decoder.decodeInt32ForKey("k", orElse: 0))
        }, valueDecoder: { decoder in
            return ChatListTotalUnreadCounters(decoder: decoder)
        })
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectDictionary(self.absoluteCounters, forKey: "ad", keyEncoder: { key, encoder in
            encoder.encodeInt32(key.rawValue, forKey: "k")
        })
        encoder.encodeObjectDictionary(self.filteredCounters, forKey: "fd", keyEncoder: { key, encoder in
            encoder.encodeInt32(key.rawValue, forKey: "k")
        })
    }
    
    public func count(for category: ChatListTotalUnreadStateCategory, in statsType: ChatListTotalUnreadStateStats, with tags: PeerSummaryCounterTags) -> Int32 {
        let counters: [PeerSummaryCounterTags: ChatListTotalUnreadCounters]
        switch category {
            case .raw:
                counters = self.absoluteCounters
            case .filtered:
                counters = self.filteredCounters
        }
        var result: Int32 = 0
        for tag in tags {
            if let category = counters[tag] {
                switch statsType {
                    case .messages:
                        result = result &+ category.messageCount
                    case .chats:
                        result = result &+ category.chatCount
                }
            }
        }
        return result
    }
}

final class GroupMessageStatsTable: Table {
    private var cachedEntries: [PeerGroupId: PeerGroupUnreadCountersCombinedSummary]?
    private var updatedGroupIds = Set<PeerGroupId>()
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: true)
    }
    
    private func preloadCache() {
        if self.cachedEntries == nil {
            var entries: [PeerGroupId: PeerGroupUnreadCountersCombinedSummary] = [:]
            self.valueBox.scanInt64(self.table, values: { key, value in
                let groupIdValue: Int32 = Int32(clamping: key)
                let groupId = PeerGroupId(rawValue: groupIdValue)
                let state = PeerGroupUnreadCountersCombinedSummary(decoder: PostboxDecoder(buffer: value))
                entries[groupId] = state
                return true
            })
            self.cachedEntries = entries
        }
    }
    
    func removeAll() {
        self.preloadCache()
        
        for groupId in self.cachedEntries!.keys {
            self.set(groupId: groupId, summary: PeerGroupUnreadCountersCombinedSummary(namespaces: [:]))
        }
    }
    
    func get(groupId: PeerGroupId) -> PeerGroupUnreadCountersCombinedSummary {
        self.preloadCache()
        
        if let state = self.cachedEntries?[groupId] {
            return state
        } else {
            return PeerGroupUnreadCountersCombinedSummary(namespaces: [:])
        }
    }
    
    func set(groupId: PeerGroupId, summary: PeerGroupUnreadCountersCombinedSummary) {
        self.preloadCache()
        
        let previousSummary = self.get(groupId: groupId)
        if previousSummary != summary {
            self.cachedEntries![groupId] = summary
            self.updatedGroupIds.insert(groupId)
        }
    }
    
    override func clearMemoryCache() {
        self.cachedEntries = nil
        assert(self.updatedGroupIds.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedGroupIds.isEmpty {
            if let cachedEntries = self.cachedEntries {
                let sharedKey = ValueBoxKey(length: 8)
                let sharedEncoder = PostboxEncoder()
                for groupId in self.updatedGroupIds {
                    sharedKey.setInt64(0, value: Int64(groupId.rawValue))
                    sharedEncoder.reset()
                    
                    if let state = cachedEntries[groupId] {
                        state.encode(sharedEncoder)
                        self.valueBox.set(self.table, key: sharedKey, value: sharedEncoder.readBufferNoCopy())
                    } else {
                        self.valueBox.remove(self.table, key: sharedKey, secure: false)
                    }
                }
            } else {
                assertionFailure()
            }
            
            self.updatedGroupIds.removeAll()
        }
    }
}
