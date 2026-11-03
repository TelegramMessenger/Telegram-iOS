import Foundation
import Display

/// What a chat history item publishes about itself for its neighbors.
///
/// There is deliberately no `other` case. A neighbor that is none of these three types and *no
/// neighbor at all* produce identical results in both consumers — `merged(with:isRotated:)`'s
/// trailing branch sets `hasDate = true` for either, and `chatItemsHaveCommonDateHeader` returns
/// false for either — so foreign descriptors decode to nil. `ChatBotInfoItem`, `ChatUserInfoItem`
/// and `ChatNewThreadInfoItem` accordingly publish `AnyEquatable.noNeighborInfluence`.
public enum ChatHistoryItemNeighbor: Equatable {
    case message(dateHeaderId: ListViewItemNode.HeaderId,
                 topicHeaderId: ListViewItemNode.HeaderId?,
                 merge: ChatMessageMergeFingerprint)
    case unread(dateHeaderId: ListViewItemNode.HeaderId)
    case replyCount(dateHeaderId: ListViewItemNode.HeaderId)

    public var dateHeaderId: ListViewItemNode.HeaderId {
        switch self {
        case let .message(dateHeaderId, _, _):
            return dateHeaderId
        case let .unread(dateHeaderId):
            return dateHeaderId
        case let .replyCount(dateHeaderId):
            return dateHeaderId
        }
    }
}

public struct ChatHistoryItemNeighbors: Equatable {
    public var previous: ChatHistoryItemNeighbor?
    public var next: ChatHistoryItemNeighbor?

    public init(_ neighbors: ListViewItemNeighbors) {
        self.previous = neighbors.previous?.base(ChatHistoryItemNeighbor.self)
        self.next = neighbors.next?.base(ChatHistoryItemNeighbor.self)
    }
}

/// Replaces `chatItemsHaveCommonDateHeader(_ lhs: ListViewItem, _ rhs: ListViewItem?)`.
///
/// The original's `lhs` was always `self` — a `ChatUnreadItem` or `ChatReplyCountItem`, both of
/// which always carry a header — and it returned false whenever the right-hand header was absent.
public func chatItemsHaveCommonDateHeader(_ dateHeaderId: ListViewItemNode.HeaderId,
                                          _ neighbor: ChatHistoryItemNeighbor?) -> Bool {
    guard let neighbor = neighbor else {
        return false
    }
    return neighbor.dateHeaderId == dateHeaderId
}
