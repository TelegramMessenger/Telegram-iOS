import Foundation
import Postbox
import TelegramCore

/// The offline proposal writes the same topic records used by Telegram's forum
/// list, reply-thread history and notification navigation. The permission and
/// burst quota remain keyed by peerId, never by threadId.
public enum AllMentionDemoForumState {
    public static func stored(_ data: MessageHistoryThreadData) -> StoredMessageHistoryThreadInfo {
        var mutedUntil: Int32?
        if case let .muted(until) = data.notificationSettings.muteState { mutedUntil = until }
        return StoredMessageHistoryThreadInfo(data: CodableEntry(data)!, summary: .init(totalUnreadCount: data.incomingUnreadCount, isMarkedUnread: data.isMarkedUnread, mutedUntil: mutedUntil, maxOutgoingReadId: data.maxOutgoingReadId))
    }

    public static func recordingMessage(_ data: MessageHistoryThreadData, id: Int32, incoming: Bool) -> MessageHistoryThreadData {
        var result = data
        result.maxKnownMessageId = max(result.maxKnownMessageId, id)
        if incoming && id > result.maxIncomingReadId { result.incomingUnreadCount += 1 }
        if !incoming { result.maxOutgoingReadId = max(result.maxOutgoingReadId, id) }
        return result
    }

    public static func reading(_ data: MessageHistoryThreadData, through id: Int32, incomingReadCount: Int32, reachedTop: Bool) -> MessageHistoryThreadData {
        guard id > data.maxIncomingReadId else { return data }
        var result = data
        result.maxIncomingReadId = id
        result.maxKnownMessageId = max(result.maxKnownMessageId, id)
        result.incomingUnreadCount = reachedTop ? 0 : max(0, result.incomingUnreadCount - incomingReadCount)
        result.isMarkedUnread = false
        return result
    }

    public static func recordIncoming(transaction: Transaction, peerId: PeerId, threadId: Int64?, messageId: Int32) {
        self.recordMessage(transaction: transaction, peerId: peerId, threadId: threadId, messageId: messageId, incoming: true)
    }

    public static func recordOutgoing(transaction: Transaction, peerId: PeerId, threadId: Int64?, messageId: Int32) {
        self.recordMessage(transaction: transaction, peerId: peerId, threadId: threadId, messageId: messageId, incoming: false)
    }

    private static func recordMessage(transaction: Transaction, peerId: PeerId, threadId: Int64?, messageId: Int32, incoming: Bool) {
        guard peerId == AllMentionDemoConfiguration.forumPeerId, let threadId,
              let data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) else { return }
        transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: self.stored(self.recordingMessage(data, id: messageId, incoming: incoming)))
    }

    public static func markRead(transaction: Transaction, peerId: PeerId, threadId: Int64, through index: MessageIndex) {
        guard index.id.peerId == peerId, index.id.namespace == Namespaces.Message.Cloud,
              let message = transaction.getMessage(index.id), message.threadId == threadId,
              let data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self), index.id.id > data.maxIncomingReadId else { return }
        let top = transaction.getMessageHistoryThreadTopMessage(peerId: peerId, threadId: threadId, namespaces: [Namespaces.Message.Cloud])
        // The complete local fixture has no holes. Count incoming messages only:
        // sending a reply must not consume earlier unread calls in this topic.
        let incomingRead = transaction.getMessagesWithThreadId(peerId: peerId, namespace: Namespaces.Message.Cloud, threadId: threadId, from: index, includeFrom: true, to: .lowerBound(peerId: peerId), limit: Int(Int32.max)).filter {
            $0.id.id > data.maxIncomingReadId && $0.flags.contains(.Incoming)
        }.count
        let updated = self.reading(data, through: index.id.id, incomingReadCount: Int32(incomingRead), reachedTop: top.map { index >= $0 } ?? true)
        transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: self.stored(updated))
        let allRead = transaction.getMessageHistoryThreadIndex(peerId: peerId, limit: 100).allSatisfy { $0.info.summary.totalUnreadCount == 0 && !$0.info.summary.isMarkedUnread }
        if allRead, let topId = transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud) {
            transaction.applyIncomingReadMaxId(topId)
        }
    }
}
