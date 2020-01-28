import PostboxDataTypes

struct LegacyPeerSummaryCounterTags: OptionSet, Sequence, Hashable {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let regularChatsAndPrivateGroups = LegacyPeerSummaryCounterTags(rawValue: 1 << 0)
    static let publicGroups = LegacyPeerSummaryCounterTags(rawValue: 1 << 1)
    static let channels = LegacyPeerSummaryCounterTags(rawValue: 1 << 2)
    
    public func makeIterator() -> AnyIterator<LegacyPeerSummaryCounterTags> {
        var index = 0
        return AnyIterator { () -> LegacyPeerSummaryCounterTags? in
            while index < 31 {
                let currentTags = self.rawValue >> UInt32(index)
                let tag = LegacyPeerSummaryCounterTags(rawValue: 1 << UInt32(index))
                index += 1
                if currentTags == 0 {
                    break
                }
                
                if (currentTags & 1) != 0 {
                    return tag
                }
            }
            return nil
        }
    }
}

extension PeerSummaryCounterTags {
    static let privateChat = PeerSummaryCounterTags(rawValue: 1 << 3)
    static let secretChat = PeerSummaryCounterTags(rawValue: 1 << 4)
    static let privateGroup = PeerSummaryCounterTags(rawValue: 1 << 5)
    static let bot = PeerSummaryCounterTags(rawValue: 1 << 6)
    static let channel = PeerSummaryCounterTags(rawValue: 1 << 7)
    static let publicGroup = PeerSummaryCounterTags(rawValue: 1 << 8)
}

struct Namespaces {
    struct Message {
        static let Cloud: Int32 = 0
    }

    struct Peer {
        static let CloudUser: Int32 = 0
        static let CloudGroup: Int32 = 1
        static let CloudChannel: Int32 = 2
        static let SecretChat: Int32 = 3
    }
}
