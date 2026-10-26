import Foundation
import Postbox

/// A post's place in a feed: `feedPosition(date, peer, id)` on the wire.
public struct EngineFeedPosition: Codable, Hashable, Comparable, CustomStringConvertible {
    public let date: Int32
    public let peerId: EnginePeer.Id
    public let id: Int32

    public init(date: Int32, peerId: EnginePeer.Id, id: Int32) {
        self.date = date
        self.peerId = peerId
        self.id = id
    }

    /// Chronological: `lhs < rhs` means `lhs` is older. Posts from the same second order by peer id, then
    /// message id (the field order of `feedPosition`).
    public static func <(lhs: EngineFeedPosition, rhs: EngineFeedPosition) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        if lhs.peerId != rhs.peerId {
            return lhs.peerId < rhs.peerId
        }
        return lhs.id < rhs.id
    }

    public var description: String {
        return "\(self.date):\(self.peerId):\(self.id)"
    }
}

/// One feed row: a post, or an album as one entry. The messages live in Postbox; this holds references.
public struct EngineFeedEntry: Codable, Hashable {
    /// The position of the entry's newest message.
    public let position: EngineFeedPosition
    /// Ascending.
    public let messageIds: [EngineMessage.Id]
    public let groupingKey: Int64?

    public init(position: EngineFeedPosition, messageIds: [EngineMessage.Id], groupingKey: Int64?) {
        self.position = position
        self.messageIds = messageIds
        self.groupingKey = groupingKey
    }

    public var peerId: EnginePeer.Id {
        return self.position.peerId
    }
}

public enum EngineForYouItem: Codable, Hashable {
    case post(EngineFeedEntry)
    /// Where the server placed the "What are you interested in?" block.
    case interests

    // Hand-written, flat: the synthesized Codable of an enum with associated values uses a nested keyed
    // container, which Postbox's Codable adapter (`CodableEntry`) does not support and traps on.
    private enum CodingKeys: String, CodingKey {
        case kind = "k"
        case entry = "e"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Int32.self, forKey: .kind)
        switch kind {
        case 0:
            self = .post(try container.decode(EngineFeedEntry.self, forKey: .entry))
        case 1:
            self = .interests
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown EngineForYouItem kind \(kind)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .post(entry):
            try container.encode(0 as Int32, forKey: .kind)
            try container.encode(entry, forKey: .entry)
        case .interests:
            try container.encode(1 as Int32, forKey: .kind)
        }
    }
}

public struct EngineInterestCategory: Codable, Hashable {
    public let id: Int32
    public let title: String
    public let emoji: String?
    public let emojiFileId: Int64?

    public init(id: Int32, title: String, emoji: String?, emojiFileId: Int64?) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.emojiFileId = emojiFileId
    }
}

public struct EngineInterestCategories: Codable, Hashable {
    public var categories: [EngineInterestCategory]
    public var selectedIds: [Int32]

    public init(categories: [EngineInterestCategory], selectedIds: [Int32]) {
        self.categories = categories
        self.selectedIds = selectedIds
    }
}
