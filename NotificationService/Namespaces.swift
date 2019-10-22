import PostboxDataTypes

extension PeerSummaryCounterTags {
    static let regularChatsAndPrivateGroups = PeerSummaryCounterTags(rawValue: 1 << 0)
    static let publicGroups = PeerSummaryCounterTags(rawValue: 1 << 1)
    static let channels = PeerSummaryCounterTags(rawValue: 1 << 2)
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