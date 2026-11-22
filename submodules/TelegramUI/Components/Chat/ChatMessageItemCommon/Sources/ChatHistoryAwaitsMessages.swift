import Foundation

/// Whether a history view that displays nothing is still waiting for messages, rather than an empty chat.
///
/// "Displays nothing" is decided after the chat's own filtering (`chatHistoryEntriesForView`), which drops a forum
/// topic's root (`topicCreated`, or `groupCreated` in a monoforum's or a forum bot's topic). A cold topic's first view is exactly that: the stored root and a hole over the
/// messages being fetched, not marked as loading. Read as an empty chat, it hid the loading placeholder (or showed the
/// empty-chat notice) until the fetched messages arrived. So a topic view that holds only its root is still loading
/// while a hole remains. Any other view is loading only while it is marked so, as before: a hole that a definite server
/// answer leaves open must not keep a chat's placeholders up in place of its empty state.
public func chatHistoryViewAwaitsMessages(isLoading: Bool, holeEarlier: Bool, holeLater: Bool, holdsOnlyForumTopicRoot: Bool) -> Bool {
    if isLoading {
        return true
    }
    return holdsOnlyForumTopicRoot && (holeEarlier || holeLater)
}
