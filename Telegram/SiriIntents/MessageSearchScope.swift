import Foundation
import Intents
import Postbox

/// What an `INSearchForMessagesIntent` is asking for.
///
/// Siri sends the same intent in two very different situations. "Read my messages" carries
/// no filters and means every unread message. Announcing a notification (AirPods, CarPlay
/// tap-to-read) carries the delivered notification's request identifier in
/// `notificationIdentifiers` and means only the message behind that notification; answering
/// it with the unread backlog made Siri re-read every earlier message on each new one
/// (bugs.telegram.org/c/6940).
enum MessageSearchScope: Equatable {
    /// Only the messages the named delivered notifications stand for.
    case notifications([String])
    /// The messages Siri already knows by identifier (a "repeat", or a follow-up).
    case messages([MessageId])
    /// Every unread message, minus those behind the named notifications.
    case unread(excludingNotifications: [String])
}

func messageSearchScope(notificationIdentifiers: [String]?, notificationIdentifiersOperator: INConditionalOperator, identifiers: [String]?) -> MessageSearchScope {
    // Message identifiers are the ones this extension handed to Siri, so they name the exact
    // messages and need no lookup; they win over a notification link that may be missing.
    if let identifiers {
        let messageIds = identifiers.compactMap(MessageId.init(string:))
        if !messageIds.isEmpty {
            return .messages(messageIds)
        }
    }
    if let notificationIdentifiers, !notificationIdentifiers.isEmpty {
        switch notificationIdentifiersOperator {
        case .none:
            return .unread(excludingNotifications: notificationIdentifiers)
        case .all, .any:
            return .notifications(notificationIdentifiers)
        @unknown default:
            return .notifications(notificationIdentifiers)
        }
    }
    if let identifiers, !identifiers.isEmpty {
        // Explicit identifiers this build cannot parse name nothing; do not widen to the backlog.
        return .messages([])
    }
    return .unread(excludingNotifications: [])
}

func messageSearchScope(for intent: INSearchForMessagesIntent) -> MessageSearchScope {
    return messageSearchScope(
        notificationIdentifiers: intent.notificationIdentifiers,
        notificationIdentifiersOperator: intent.notificationIdentifiersOperator,
        identifiers: intent.identifiers
    )
}
