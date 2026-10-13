import Observation
import UserNotifications
import WatchKit

/// The chat a tapped notification asks the app to open, until the chat list opens it.
@Observable @MainActor
final class NotificationChatRouter {
    static let shared = NotificationChatRouter()

    /// TDLib chat id.
    private(set) var pendingChatId: Int64?
    private var pendingSince = Date.distantPast

    /// A tap that could not be served while the app launched (the chat is not in the loaded
    /// list) is dropped rather than opening the chat later, when the user scrolls to it.
    static let pendingLifetime: TimeInterval = 15

    func request(chatId: Int64) {
        pendingChatId = chatId
        pendingSince = Date()
    }

    /// The pending chat id, unless it has expired (then it is cleared).
    func currentRequest(now: Date = Date()) -> Int64? {
        if pendingChatId != nil, now.timeIntervalSince(pendingSince) > Self.pendingLifetime {
            pendingChatId = nil
        }
        return pendingChatId
    }

    func clear() {
        pendingChatId = nil
    }

    /// The iPhone app's notification service extension names the chat by its server id, in one
    /// of three keys by peer kind (`NotificationService.swift`). TDLib derives its chat ids from
    /// those: a user's chat id is the user id, a basic group's is `-id`, and a channel's or
    /// supergroup's is `-1000000000000 - id`.
    nonisolated static func chatId(fromUserInfo userInfo: [AnyHashable: Any]) -> Int64? {
        func id(_ key: String) -> Int64? {
            (userInfo[key] as? String).flatMap(Int64.init) ?? (userInfo[key] as? NSNumber)?.int64Value
        }
        if let userId = id("from_id") {
            return userId
        }
        if let groupId = id("chat_id") {
            return -groupId
        }
        if let channelId = id("channel_id") {
            return -1_000_000_000_000 - channelId
        }
        return nil
    }
}

/// Receives the response when a notification's interface opens the app
/// (`performNotificationDefaultAction()`), and routes it to its chat. Other actions are left
/// alone: Reply on a notification the iPhone app mirrored is handled by the iPhone app.
final class TgwatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let chatId = NotificationChatRouter.chatId(fromUserInfo: response.notification.request.content.userInfo) {
            Task { @MainActor in
                NotificationChatRouter.shared.request(chatId: chatId)
            }
        }
        completionHandler()
    }
}
