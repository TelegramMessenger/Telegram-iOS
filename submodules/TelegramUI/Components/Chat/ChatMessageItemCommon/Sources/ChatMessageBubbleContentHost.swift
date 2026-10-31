import Foundation

/// Where a bubble keeps one of its content nodes. An album of files gives each of its messages a container of its own
/// (selected, lifted into a context menu and laid out apart); everything else is in the bubble itself.
///
/// The bubble reads this on every layout, not only when it creates a node: a lone message of an album keeps the album's
/// identity (`ChatMessageEntryAttributes.groupStableId`), so it becomes the album in place, and back, reusing its node.
/// A node left in its previous host is laid out in the wrong space: in the bubble, a container-relative frame puts it at
/// the top of the item, over a date header (#123); in a container that is no longer laid out, it lands below the bubble.
public enum ChatMessageBubbleContentHost: Equatable {
    /// The bubble's clipping node: a message's content, and an album's attachments (its reactions, its comments).
    case bubble
    /// The container of one message of an album of files, keyed on the message's stable id.
    case messageContainer(stableId: UInt32)
}

/// - Parameter containerStableIds: the messages this layout gives a container (none unless the item is an album of files).
public func chatMessageBubbleContentHost(messageStableId: UInt32, isAttachment: Bool, containerStableIds: [UInt32]) -> ChatMessageBubbleContentHost {
    if !isAttachment && containerStableIds.contains(messageStableId) {
        return .messageContainer(stableId: messageStableId)
    }
    return .bubble
}

/// The containers a bubble has that this layout no longer lays out: those of an album's messages after the album became a
/// lone message, or lost a message.
public func chatMessageBubbleStaleContentContainers(existing: [UInt32], laidOut: [UInt32]) -> [UInt32] {
    return existing.filter { !laidOut.contains($0) }
}
