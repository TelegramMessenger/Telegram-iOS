import Foundation

/*public protocol PeerChatListEmbeddedInterfaceState: Codable {
    var timestamp: Int32 { get }
    
    func isEqual(to: PeerChatListEmbeddedInterfaceState) -> Bool
}*/

public final class StoredPeerChatInterfaceState: Codable, Equatable {
    private enum CodingKeys: CodingKey {
        case overrideChatTimestamp
        case historyScrollMessageIndex
        case associatedMessageIds
        case data
    }

    public let overrideChatTimestamp: Int32?
    public let historyScrollMessageIndex: MessageIndex?
    public let associatedMessageIds: [MessageId]
    public let data: Data?

    public init(
        overrideChatTimestamp: Int32?,
        historyScrollMessageIndex: MessageIndex?,
        associatedMessageIds: [MessageId],
        data: Data?
    ) {
        self.overrideChatTimestamp = overrideChatTimestamp
        self.historyScrollMessageIndex = historyScrollMessageIndex
        self.associatedMessageIds = associatedMessageIds
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.overrideChatTimestamp = try? container.decodeIfPresent(Int32.self, forKey: .overrideChatTimestamp)
        self.historyScrollMessageIndex = try? container.decodeIfPresent(MessageIndex.self, forKey: .historyScrollMessageIndex)
        self.associatedMessageIds = try container.decode([MessageId].self, forKey: .associatedMessageIds)
        self.data = try? container.decodeIfPresent(Data.self, forKey: .data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(self.overrideChatTimestamp, forKey: .overrideChatTimestamp)
        try container.encodeIfPresent(self.historyScrollMessageIndex, forKey: .historyScrollMessageIndex)
        try container.encodeIfPresent(self.associatedMessageIds, forKey: .associatedMessageIds)
        try container.encodeIfPresent(self.data, forKey: .data)
    }

    public static func ==(lhs: StoredPeerChatInterfaceState, rhs: StoredPeerChatInterfaceState) -> Bool {
        if lhs.overrideChatTimestamp != rhs.overrideChatTimestamp {
            return false
        }
        if lhs.historyScrollMessageIndex != rhs.historyScrollMessageIndex {
            return false
        }
        if lhs.associatedMessageIds != rhs.associatedMessageIds {
            return false
        }
        if lhs.data != rhs.data {
            return false
        }
        return true
    }
}

/*public protocol PeerChatInterfaceState: PostboxCoding {
    var chatListEmbeddedState: PeerChatListEmbeddedInterfaceState? { get }
    var historyScrollMessageIndex: MessageIndex? { get }
    var associatedMessageIds: [MessageId] { get }
    
    func isEqual(to: PeerChatInterfaceState) -> Bool
}*/
