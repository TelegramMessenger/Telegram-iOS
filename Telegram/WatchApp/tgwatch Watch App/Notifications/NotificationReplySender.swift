import Foundation
import OSLog

/// Sends the text of a notification's Reply through the app's own TDLib session.
///
/// Once the app has a notification interface for a category, watchOS delivers that
/// category's Reply to the app, not to the iPhone app that mirrored the notification (the
/// legacy WatchKit app had the same: bugs.telegram.org/c/204), so the app sends it. It does
/// what the iPhone app does with the same Reply (`AppDelegate.swift`): marks the chat read up
/// to the notified message and sends a plain message, into the forum topic when there is one,
/// then waits until the message is sent.
@MainActor
final class NotificationReplySender {
    static let shared = NotificationReplySender()

    /// Set by the app at launch; the reply goes through its active account.
    weak var accountManager: AccountManager?

    /// The app may be launched by the reply itself, so its session can still be starting.
    static let readyTimeout: TimeInterval = 15
    static let sendTimeout: TimeInterval = 20

    private let logger = Logger(subsystem: "com.isaac.tgwatch", category: "notification-reply")

    /// False when the reply could not be sent: no logged-in account, a chat the notification
    /// does not name, or a send that failed or timed out.
    func send(_ text: String, userInfo: [AnyHashable: Any]) async -> Bool {
        guard await NotificationChatRouter.waitIsForActiveAccount(userInfo) else {
            logger.error("reply: notification is not for the logged-in account")
            return false
        }
        guard let chatId = NotificationChatRouter.chatId(fromUserInfo: userInfo) else {
            logger.error("reply: notification names no chat")
            return false
        }
        guard let client = await readyClient() else {
            logger.error("reply: no logged-in account")
            return false
        }
        do {
            try await client.sendNotificationReply(
                chatId: chatId,
                text: text,
                forumTopicId: Self.forumTopicId(fromUserInfo: userInfo),
                readUpToMessageId: Self.messageId(fromUserInfo: userInfo),
                timeout: Self.sendTimeout
            )
            logger.notice("reply: sent")
            return true
        } catch {
            logger.error("reply: not sent: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// The logged-in account's user id, known once its session has fetched it (`TDClient.me`).
    func activeUserId() -> Int64? {
        accountManager?.activeClient?.me.map { Int64($0.id) }
    }

    func waitActiveUserId() async -> Int64? {
        let deadline = Date().addingTimeInterval(Self.readyTimeout)
        while Date() < deadline {
            if let userId = activeUserId() {
                return userId
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return nil
    }

    private func readyClient() async -> TDClient? {
        let deadline = Date().addingTimeInterval(Self.readyTimeout)
        while Date() < deadline {
            if let client = accountManager?.activeClient, client.authState == .ready {
                return client
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return nil
    }

    /// The notified message: its server id in `msg_id`, which TDLib shifts by 20 bits.
    nonisolated static func messageId(fromUserInfo userInfo: [AnyHashable: Any]) -> Int64? {
        integer(userInfo["msg_id"]).map { $0 << 20 }
    }

    /// The forum topic of the notified message, `threadId` in the notification.
    nonisolated static func forumTopicId(fromUserInfo userInfo: [AnyHashable: Any]) -> Int? {
        integer(userInfo["threadId"]).flatMap { $0 > 0 ? Int($0) : nil }
    }

    nonisolated private static func integer(_ value: Any?) -> Int64? {
        if let string = value as? String {
            return Int64(string)
        }
        return (value as? NSNumber)?.int64Value
    }
}
