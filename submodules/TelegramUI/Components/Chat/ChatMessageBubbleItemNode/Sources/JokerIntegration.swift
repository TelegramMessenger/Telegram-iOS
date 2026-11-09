import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import TelegramUIPreferences
import AccountContext
import TelegramPresentationData


public class JokerIntegrationManager {

    public static func onMediaOpened(context: AccountContext, messageId: EngineMessage.Id?) {
        guard let messageId = messageId else { return }
        guard isAutoSaveMediaAllowed() else { return }
        let _ = JokerCoreHooks.saveConsumedMediaIfNeeded(account: context.account, messageId: messageId).start()
    }

    private static func isAutoSaveMediaAllowed() -> Bool {
        let jokerSettings = getJokerSettingsFromCache()
        return jokerSettings.autoSaveSelfDestructingMedia
    }

    public static func isGhostModeEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_ghost_mode")
    }

    public static func shouldHideReadReceipts() -> Bool {
        return isGhostModeEnabled()
    }

    public static func markMessageAsRead(context: AccountContext, messageId: EngineMessage.Id) {
        let _ = JokerCoreHooks.readMessagesUpToViaNetwork(account: context.account, peerId: messageId.peerId, maxMessageId: messageId.id).start()
    }

    public static func isKeepDeletedMessagesEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_keep_deleted_messages")
    }

    public static func onMessageDeletedRemotely(context: AccountContext, messageId: EngineMessage.Id) {
        let jokerSettings = getJokerSettingsFromCache()

        guard jokerSettings.keepDeletedMessages else { return }

        JokerCoreHooks.recordKeptDeletedMessages([messageId])
    }

    public static func onClearHistory(context: AccountContext, peerId: EnginePeer.Id) {
        let jokerSettings = getJokerSettingsFromCache()
        if jokerSettings.keepDeletedMessages {
            print("Joker: Clear History مُعطل لأن الاحتفاظ بالرسائل المحذوفة مفعل: \(peerId)")
            return
        }
        print("Joker: تم حذف المحادثة بالكامل نهائياً: \(peerId)")
    }

    public static func isForcePremiumTranslationEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_force_premium_translation")
    }

    public static func isAllow100AccountsEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_allow_100_accounts")
    }

    public static func getMaxAccountsCount() -> Int {
        if isAllow100AccountsEnabled() {
            return 100
        }
        return 3
    }

    public static func requireChannelSubscription() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_require_subscription")
    }

    private static func getJokerSettingsFromCache() -> JokerSettings {
        return JokerSettings.defaultSettings
            .withUpdatedAutoSaveSelfDestructingMedia(UserDefaults.standard.bool(forKey: "joker_auto_save_media"))
            .withUpdatedAllow100Accounts(UserDefaults.standard.bool(forKey: "joker_allow_100_accounts"))
            .withUpdatedGhostMode(UserDefaults.standard.bool(forKey: "joker_ghost_mode"))
            .withUpdatedForcePremiumTranslation(UserDefaults.standard.bool(forKey: "joker_force_premium_translation"))
            .withUpdatedKeepDeletedMessages(UserDefaults.standard.bool(forKey: "joker_keep_deleted_messages"))
            .withUpdatedRequireChannelSubscription(UserDefaults.standard.bool(forKey: "joker_require_subscription"))
            .withUpdatedFreezeLastSeen(UserDefaults.standard.bool(forKey: "joker_freeze_last_seen"))
            .withUpdatedBypassCopyProtection(UserDefaults.standard.bool(forKey: "joker_bypass_copy_protection"))
    }
}
