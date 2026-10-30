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
    /// `isSelected` is nil with bubbles; without them, whether the message (every message of a group) is selected, which
    /// a neighbour reads to join its selection band to this one (spec 5.8, 6.7).
    case message(dateHeaderId: ListViewItemNode.HeaderId,
                 topicHeaderId: ListViewItemNode.HeaderId?,
                 merge: ChatMessageMergeFingerprint,
                 isSelected: Bool? = nil)
    case unread(dateHeaderId: ListViewItemNode.HeaderId)
    case replyCount(dateHeaderId: ListViewItemNode.HeaderId)

    public var dateHeaderId: ListViewItemNode.HeaderId {
        switch self {
        case let .message(dateHeaderId, _, _, _):
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

/// Without bubbles: whether an item counts as selected for its neighbours' bands, every message in it selected and the
/// item drawing a band of its own (`chatMessageBubblelessHasSelectionBand`), so a band never joins toward a row without
/// one. Nil with bubbles, so that selecting a message changes nothing a neighbour reads there and nothing relayouts.
public func chatMessageBubblelessNeighborSelection(bubbleMode: Bool, selected: [Bool], drawsBand: Bool) -> Bool? {
    if bubbleMode {
        return nil
    }
    return drawsBand && !selected.isEmpty && selected.allSatisfy({ $0 })
}

/// Without bubbles: whether the rows right above and below a row are selected with no date or topic header between them,
/// so that its selection band joins theirs.
public func chatMessageBubblelessSelectedNeighbors(above: ChatHistoryItemNeighbor?, below: ChatHistoryItemNeighbor?, dateHeaderId: ListViewItemNode.HeaderId, topicHeaderId: ListViewItemNode.HeaderId?) -> (above: Bool, below: Bool) {
    func joinsSelected(_ neighbor: ChatHistoryItemNeighbor?) -> Bool {
        guard case let .message(neighborDateHeaderId, neighborTopicHeaderId, _, isSelected) = neighbor, isSelected == true, neighborDateHeaderId == dateHeaderId else {
            return false
        }
        if let topicHeaderId, neighborTopicHeaderId != topicHeaderId {
            return false
        }
        return true
    }
    return (joinsSelected(above), joinsSelected(below))
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
