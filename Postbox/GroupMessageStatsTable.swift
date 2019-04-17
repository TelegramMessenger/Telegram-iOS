import Foundation

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
    private var cachedEntries: [WrappedPeerGroupId: ChatListTotalUnreadState]?
    private var updatedGroupIds = Set<WrappedPeerGroupId>()
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: true)
    }
    
    private func preloadCache() {
        if self.cachedEntries == nil {
            var entries: [WrappedPeerGroupId: ChatListTotalUnreadState] = [:]
            self.valueBox.scanInt64(self.table, values: { key, value in
                let groupIdValue: Int32 = Int32(clamping: key)
                let groupId: WrappedPeerGroupId
                if groupIdValue == 0 {
                    groupId = WrappedPeerGroupId(groupId: nil)
                } else {
                    groupId = WrappedPeerGroupId(groupId: PeerGroupId(rawValue: groupIdValue))
                }
                let state = ChatListTotalUnreadState(decoder: PostboxDecoder(buffer: value))
                entries[groupId] = state
                return true
            })
            self.cachedEntries = entries
        }
    }
    
    func removeAll() {
        self.preloadCache()
        
        for groupId in self.cachedEntries!.keys {
            self.set(groupId: groupId.groupId, state: ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:]))
        }
    }
    
    func get(groupId: PeerGroupId?) -> ChatListTotalUnreadState {
        self.preloadCache()
        
        if let state = self.cachedEntries?[WrappedPeerGroupId(groupId: groupId)] {
            return state
        } else {
            return ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:])
        }
    }
    
    func set(groupId: PeerGroupId?, state: ChatListTotalUnreadState) {
        self.preloadCache()
        
        let previousState = self.get(groupId: groupId)
        if previousState != state {
            self.cachedEntries![WrappedPeerGroupId(groupId: groupId)] = state
            self.updatedGroupIds.insert(WrappedPeerGroupId(groupId: groupId))
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
                    sharedKey.setInt64(0, value: Int64(groupId.groupId?.rawValue ?? 0))
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
