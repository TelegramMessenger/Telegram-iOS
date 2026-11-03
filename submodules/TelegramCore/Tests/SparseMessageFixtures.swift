import Foundation
import Postbox
@testable import TelegramCore

/// Shared fixtures for the shared-media list and calendar tests: a channel and the basic group
/// it was migrated from, and readable descriptions of published list states.
enum SparseFixtures {
    static var channelId: PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1))
    }

    static var groupId: PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(2))
    }

    static func messageId(_ peerId: PeerId, _ id: Int32) -> MessageId {
        return MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)
    }

    static func message(_ peerId: PeerId, _ id: Int32, timestamp: Int32) -> Message {
        let stableId = UInt32(truncatingIfNeeded: peerId.id._internalGetInt64Value()) &* 1_000_000 &+ UInt32(bitPattern: id)
        return Message(
            stableId: stableId,
            stableVersion: 0,
            id: messageId(peerId, id),
            globallyUniqueId: nil,
            groupingKey: nil,
            groupInfo: nil,
            threadId: nil,
            timestamp: timestamp,
            flags: [],
            tags: [],
            globalTags: [],
            localTags: [],
            customTags: [],
            forwardInfo: nil,
            author: nil,
            text: "",
            attributes: [],
            media: [],
            peers: SimpleDictionary(),
            associatedMessages: SimpleDictionary(),
            associatedMessageIds: [],
            associatedMedia: [:],
            associatedThreadInfo: nil,
            associatedStories: [:]
        )
    }

    enum Cell: Equatable {
        case message(index: Int, id: MessageId, isLocal: Bool)
        case placeholder(index: Int, id: MessageId)
    }

    static func cells(_ items: [SparseMessageList.State.Item]) -> [Cell] {
        return items.map { item -> Cell in
            switch item.content {
            case let .message(message, isLocal):
                return .message(index: item.index, id: message.id, isLocal: isLocal)
            case let .placeholder(id, _):
                return .placeholder(index: item.index, id: id)
            }
        }
    }

    struct Summary: Equatable {
        var cells: [Cell]
        var totalCount: Int
        var isLoading: Bool
    }

    static func summary(_ state: SparseMessageList.State?) -> Summary? {
        guard let state else {
            return nil
        }
        return Summary(cells: cells(state.items), totalCount: state.totalCount, isLoading: state.isLoading)
    }
}
