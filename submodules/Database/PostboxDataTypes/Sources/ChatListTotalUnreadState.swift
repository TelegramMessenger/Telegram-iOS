import Foundation
import PostboxCoding

public enum ChatListTotalUnreadStateCategory: Int32 {
    case filtered = 0
    case raw = 1
}

public enum ChatListTotalUnreadStateStats: Int32 {
    case messages = 0
    case chats = 1
}

public struct ChatListTotalUnreadCounters: PostboxCoding, Equatable {
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
