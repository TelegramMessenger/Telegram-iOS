import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences

enum AllMentionDemoDestinationFailure: Equatable {
    case topicDeleted
    case topicClosed
    case sendPermissionDenied
    case groupUnavailable
}

/// Local counterpart of the server's destination checks. Never reserve quota or
/// copy a scheduled message to Cloud until the current destination accepts it.
enum AllMentionDemoScheduledDestination {
    static func failure(transaction: Transaction, peerId: PeerId, threadId: Int64?, hasText: Bool) -> AllMentionDemoDestinationFailure? {
        guard peerId == AllMentionDemoConfiguration.forumPeerId else { return nil }
        guard let channel = transaction.getPeer(peerId) as? TelegramChannel, channel.participationStatus == .member else { return .groupUnavailable }
        guard let threadId, let topic = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) else { return .topicDeleted }
        guard channel.hasPermission(hasText ? .sendText : .sendSomething) else { return .sendPermissionDenied }
        if topic.isClosed && !topic.isOwnedByMe && !channel.flags.contains(.isCreator) && !channel.hasPermission(.manageTopics) {
            return .topicClosed
        }
        return nil
    }

    static func rejectUnavailableBatch(transaction: Transaction, messages: [Message], timestamp: TimeInterval, force: Bool) -> AllMentionDemoDestinationFailure? {
        guard let first = messages.first, force || (!messages.contains(where: { $0.flags.contains(.Failed) }) && TimeInterval(first.timestamp) <= timestamp) else { return nil }
        guard let reason = messages.compactMap({ failure(transaction: transaction, peerId: $0.id.peerId, threadId: $0.threadId, hasText: !$0.text.isEmpty) }).first else { return nil }
        for message in messages {
            transaction.updateMessage(message.id, update: { original in
                return .update(StoreMessage(id: original.id, customStableId: nil, globallyUniqueId: original.globallyUniqueId, groupingKey: original.groupingKey, threadId: original.threadId, timestamp: original.timestamp, flags: StoreMessageFlags(original.flags).union(.Failed), tags: original.tags, globalTags: original.globalTags, localTags: original.localTags, forwardInfo: original.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: original.author?.id, text: original.text, attributes: original.attributes, media: original.media))
            })
        }
        return reason
    }
}
