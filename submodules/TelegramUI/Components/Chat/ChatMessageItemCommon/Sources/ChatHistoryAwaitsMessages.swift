import Foundation

/// Whether a history view that displays nothing is still waiting for messages, rather than an empty chat.
///
/// "Displays nothing" is decided after the chat's own filtering (`chatHistoryEntriesForView`), which drops entries
/// the view does hold, such as a forum topic's root (`topicCreated`). A cold topic's first view is exactly that: the
/// stored root and a hole over the messages being fetched, not marked as loading. Read as an empty chat, it hid the
/// loading placeholder (or showed the empty-chat notice) until the fetched messages arrived.
public func chatHistoryViewAwaitsMessages(isLoading: Bool, holeEarlier: Bool, holeLater: Bool) -> Bool {
    return isLoading || holeEarlier || holeLater
}
