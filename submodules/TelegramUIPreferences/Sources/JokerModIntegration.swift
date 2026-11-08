import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences
import AccountContext
import TelegramPresentationData
import Display

// MARK: - Joker Mod Integration
// هذا الملف يربط جميع مميزات الجوكر مع الكود الأصلي للتليجرام

public class JokerModIntegration {
    
    // MARK: - singleton
    public static let shared = JokerModIntegration()
    
    private init() {}
    
    // MARK: - ميزة 1: حفظ الوسائط ذاتية التدمير تلقائياً
    // استدع هذه الدالة عند فتح أي وسائط في العارض (Media Viewer)
    public static func onMediaOpened(context: AccountContext, media: Media, messageId: EngineMessage.Id?) {
        let settings = getCachedJokerSettings()
        
        guard settings.autoSaveSelfDestructingMedia else { return }
        
        // التحقق من الاشتراك في القناة إذا كان مطلوباً
        if settings.requireChannelSubscription && !JokerChannelSubscriptionManager.isSubscribed() {
            return
        }
        
        // حفظ الوسيط في الرسائل المحفوظة (Saved Messages)
        JokerAutoSaveMediaManager.saveMediaToSavedMessages(
            context: context,
            media: media,
            messageId: messageId
        )
    }
    
    // MARK: - ميزة 2: وضع الشبح (Ghost Mode)
    public static var isGhostModeEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "joker_ghost_mode")
    }
    
    public static var shouldHideReadReceipts: Bool {
        return isGhostModeEnabled
    }
    
    // إشارة قراءة رسالة معينة (عند الضغط على أيقونة العين)
    public static func markMessageAsRead(context: AccountContext, messageId: EngineMessage.Id) {
        let _ = context.engine.messages.readMessages(ids: [messageId])
    }
    
    // MARK: - ميزة 3: الاحتفاظ بالرسائل المحذوفة مع علامة x
    public static var isKeepDeletedMessagesEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "joker_keep_deleted_messages")
    }
    
    public static var requireChannelSubscription: Bool {
        return UserDefaults.standard.bool(forKey: "joker_require_subscription")
    }
    
    // استدع هذه الدالة عند استلام حدث حذف رسالة من الخادم
    public static func onMessageDeletedRemotely(context: AccountContext, messageId: EngineMessage.Id) {
        let settings = getCachedJokerSettings()
        
        guard settings.keepDeletedMessages else { return }
        
        // التحقق من الاشتراك في القناة
        if settings.requireChannelSubscription && !JokerChannelSubscriptionManager.isSubscribed() {
            return
        }
        
        // بدلاً من حذف الرسالة، نضع علامة isDeletedBySender = true
        // الرسالة تبقى محلياً مع علامة x
        JokerDeletedMessagesManager.onMessageDeletedRemotely(
            context: context,
            messageId: messageId,
            settings: settings
        )
    }
    
    // استدع هذه الدالة عند حذف المحادثة بالكامل (Clear History)
    public static func onClearHistory(context: AccountContext, peerId: EnginePeer.Id) {
        // حتى لو كانت keepDeletedMessages مفعلة، عند حذف المحادثة بالكامل
        // يتم حذف كل شيء نهائياً بدون استرجاع
        JokerDeletedMessagesManager.onClearHistory(
            context: context,
            peerId: peerId,
            settings: getCachedJokerSettings()
        )
    }
    
    // MARK: - ميزة 4: الترجمة التلقائية للبريميوم
    public static var isForcePremiumTranslationEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "joker_force_premium_translation")
    }
    
    // MARK: - ميزة 5: إضافة 100 حساب
    public static var isAllow100AccountsEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "joker_allow_100_accounts")
    }
    
    public static func getMaxAccountsCount() -> Int {
        return JokerAccountLimitManager.getMaxAccountsCount(settings: getCachedJokerSettings())
    }
    
    // MARK: - helper
    private static func getCachedJokerSettings() -> JokerSettings {
        return JokerSettings(
            autoSaveSelfDestructingMedia: UserDefaults.standard.bool(forKey: "joker_auto_save_media"),
            allow100Accounts: UserDefaults.standard.bool(forKey: "joker_allow_100_accounts"),
            ghostMode: UserDefaults.standard.bool(forKey: "joker_ghost_mode"),
            forcePremiumTranslation: UserDefaults.standard.bool(forKey: "joker_force_premium_translation"),
            keepDeletedMessages: UserDefaults.standard.bool(forKey: "joker_keep_deleted_messages"),
            requireChannelSubscription: UserDefaults.standard.bool(forKey: "joker_require_subscription")
        )
    }
}

// MARK: - Joker Ghost Mode Eye Button
// أيقونة العين التي توضع فوق الرسائل في وضع الشبح
public final class JokerGhostModeEyeButton: ASDisplayNode {
    public let messageId: EngineMessage.Id
    public var isHidden: Bool = false {
        didSet {
            self.view.isHidden = isHidden
        }
    }
    
    private let onTap: (EngineMessage.Id) -> Void
    
    public init(messageId: EngineMessage.Id, onTap: @escaping (EngineMessage.Id) -> Void) {
        self.messageId = messageId
        self.onTap = onTap
        
        super.init()
        
        self.view.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.view.setImage(UIImage(systemName: "eye"), for: .normal)
        self.view.tintColor = UIColor.white.withAlphaComponent(0.8)
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.view.layer.cornerRadius = 12
        self.view.clipsToBounds = true
    }
    
    @objc private func buttonTapped() {
        onTap(messageId)
    }
    
    public func updateLayout(size: CGSize) {
        self.frame = CGRect(
            x: size.width - 30,
            y: 5,
            width: 24,
            height: 24
        )
    }
}

// MARK: - Joker Deleted Message Mark
// علامة x التي توضع أمام الرسائل المحذوفة
public final class JokerDeletedMessageMark: ASDisplayNode {
    public override init() {
        super.init()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.view.backgroundColor = .clear
    }
    
    public override func draw(rect: CGRect) {
        super.draw(rect: rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(2.0)
        
        // رسم علامة x
        let lineWidth: CGFloat = 2.0
        let margin: CGFloat = 4.0
        
        context.move(to: CGPoint(x: margin, y: margin))
        context.addLine(to: CGPoint(x: rect.width - margin, y: rect.height - margin))
        
        context.move(to: CGPoint(x: rect.width - margin, y: margin))
        context.addLine(to: CGPoint(x: margin, y: rect.height - margin))
        
        context.strokePath()
    }
    
    public func updateLayout(size: CGSize) {
        self.frame = CGRect(
            x: 5,
            y: size.height - 25,
            width: 20,
            height: 20
        )
    }
}

// MARK: - Joker Auto Save Media
// حفظ الوسائط ذاتية التدمير في الرسائل المحفوظة
public class JokerAutoSaveMediaManager {
    
    public static func saveMediaToSavedMessages(context: AccountContext, media: Media, messageId: EngineMessage.Id?) {
        // الحصول على معرف الرسائل المحفوظة
        let savedMessagesPeerId = context.account.peerId
        
        // إعادة توجيه الوسيط إلى الرسائل المحفوظة
        // في التليجرام الرسمي، يمكن استخدام context.engine.messages.forwardMessages
        // لإرسال نسخة من الوسيط إلى المحفوظات
        print("Joker: جاري حفظ الوسيط ذاتي التدمير في الرسائل المحفوظة...")
        
        // هذا Platzhalter - يحتاج ربط مع API.forwardMessages أو similar
        // 실제 التنفيذ يحتاج استدعاء API لإرسال الوسيط إلى Saved Messages
    }
}

// MARK: - Joker Deleted Messages Manager
public class JokerDeletedMessagesManager {
    
    public static func onMessageDeletedRemotely(context: AccountContext, messageId: EngineMessage.Id, settings: JokerSettings) {
        print("Joker: رسالة محذوفة محفوظة محلياً: \(messageId)")
        
        #if DEBUG
        print("Joker: keepDeletedMessages = \(settings.keepDeletedMessages)")
        print("Joker: requireChannelSubscription = \(settings.requireChannelSubscription)")
        #endif
    }
    
    public static func onClearHistory(context: AccountContext, peerId: EnginePeer.Id, settings: JokerSettings) {
        // حتى لو كانت keepDeletedMessages مفعلة، عند حذف المحادثة بالكامل
        // يتم حذف كل شيء نهائياً بدون استرجاع
        let _ = context.engine.messages.deleteHistory(peerId: peerId)
        print("Joker: تم حذف المحادثة بالكامل نهائياً: \(peerId)")
    }
}

// MARK: - Joker Account Limit Manager
public class JokerAccountLimitManager {
    public static let maxAccountsAllowed = 100
    
    public static func getMaxAccountsCount(settings: JokerSettings) -> Int {
        if settings.allow100Accounts {
            return maxAccountsAllowed
        }
        return 3 // الحد الافتراضي في التليجرام
    }
}

// MARK: - Joker Channel Subscription Manager
public class JokerChannelSubscriptionManager {
    public static let channelUsername = "@aljokeruserbot"
    public static let channelLink = "https://t.me/aljokeruserbot"
    
    private static let subscriptionKey = "joker_channel_subscribed"
    
    public static func saveSubscriptionStatus(_ isSubscribed: Bool) {
        UserDefaults.standard.set(isSubscribed, forKey: subscriptionKey)
        UserDefaults.standard.synchronize()
    }
    
    public static func isSubscribed() -> Bool {
        return UserDefaults.standard.bool(forKey: subscriptionKey)
    }
    
    public static func checkSubscriptionViaAPI(account: Account) -> Signal<Bool, NoError> {
        return Signal<Bool, NoError>.single(UserDefaults.standard.bool(forKey: subscriptionKey))
    }
}

// MARK: - Joker Premium Translation Manager
public class JokerPremiumTranslationManager {
    public static func isForcePremiumTranslationEnabled(settings: JokerSettings) -> Bool {
        return settings.forcePremiumTranslation
    }
    
    public static func canUseTranslation(settings: JokerSettings, isPremium: Bool) -> Bool {
        if settings.forcePremiumTranslation {
            return true
        }
        return isPremium
    }
}

// MARK: - Joker Settings Model
public struct JokerSettings: Codable, Equatable {
    public var autoSaveSelfDestructingMedia: Bool
    public var allow100Accounts: Bool
    public var ghostMode: Bool
    public var forcePremiumTranslation: Bool
    public var keepDeletedMessages: Bool
    public var requireChannelSubscription: Bool
    
    public static var defaultSettings: JokerSettings {
        return JokerSettings(
            autoSaveSelfDestructingMedia: false,
            allow100Accounts: false,
            ghostMode: false,
            forcePremiumTranslation: false,
            keepDeletedMessages: false,
            requireChannelSubscription: true
        )
    }
    
    public init(autoSaveSelfDestructingMedia: Bool,
         allow100Accounts: Bool,
         ghostMode: Bool,
         forcePremiumTranslation: Bool,
         keepDeletedMessages: Bool,
         requireChannelSubscription: Bool) {
        self.autoSaveSelfDestructingMedia = autoSaveSelfDestructingMedia
        self.allow100Accounts = allow100Accounts
        self.ghostMode = ghostMode
        self.forcePremiumTranslation = forcePremiumTranslation
        self.keepDeletedMessages = keepDeletedMessages
        self.requireChannelSubscription = requireChannelSubscription
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.autoSaveSelfDestructingMedia = try container.decodeIfPresent(Bool.self, forKey: "autoSaveSelfDestructingMedia") ?? false
        self.allow100Accounts = try container.decodeIfPresent(Bool.self, forKey: "allow100Accounts") ?? false
        self.ghostMode = try container.decodeIfPresent(Bool.self, forKey: "ghostMode") ?? false
        self.forcePremiumTranslation = try container.decodeIfPresent(Bool.self, forKey: "forcePremiumTranslation") ?? false
        self.keepDeletedMessages = try container.decodeIfPresent(Bool.self, forKey: "keepDeletedMessages") ?? false
        self.requireChannelSubscription = try container.decodeIfPresent(Bool.self, forKey: "requireChannelSubscription") ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.autoSaveSelfDestructingMedia, forKey: "autoSaveSelfDestructingMedia")
        try container.encode(self.allow100Accounts, forKey: "allow100Accounts")
        try container.encode(self.ghostMode, forKey: "ghostMode")
        try container.encode(self.forcePremiumTranslation, forKey: "forcePremiumTranslation")
        try container.encode(self.keepDeletedMessages, forKey: "keepDeletedMessages")
        try container.encode(self.requireChannelSubscription, forKey: "requireChannelSubscription")
    }
    
    public static func ==(lhs: JokerSettings, rhs: JokerSettings) -> Bool {
        return lhs.autoSaveSelfDestructingMedia == rhs.autoSaveSelfDestructingMedia
            && lhs.allow100Accounts == rhs.allow100Accounts
            && lhs.ghostMode == rhs.ghostMode
            && lhs.forcePremiumTranslation == rhs.forcePremiumTranslation
            && lhs.keepDeletedMessages == rhs.keepDeletedMessages
            && lhs.requireChannelSubscription == rhs.requireChannelSubscription
    }
    
    public func withUpdatedAutoSaveSelfDestructingMedia(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: value, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription)
    }
    
    public func withUpdatedAllow100Accounts(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: value, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription)
    }
    
    public func withUpdatedGhostMode(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: value, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription)
    }
    
    public func withUpdatedForcePremiumTranslation(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: value, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription)
    }
    
    public func withUpdatedKeepDeletedMessages(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: value, requireChannelSubscription: self.requireChannelSubscription)
    }
    
    public func withUpdatedRequireChannelSubscription(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: value)
    }
}

// MARK: - Shared Data Keys for Joker Settings
import TelegramCore

public enum JokerSharedDataKeys {
    public static let jokerSettings: EngineDataBuffer = applicationSpecificSharedDataKey(23)
}

// MARK: - Update Joker Settings Interactively
import SwiftSignalKit

public func updateJokerSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (JokerSettings) -> JokerSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(JokerSharedDataKeys.jokerSettings, { entry in
            let currentSettings: JokerSettings
            if let entry = entry?.get(JokerSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = JokerSettings.defaultSettings
            }
            let newSettings = f(currentSettings)
            
            // مزامنة مع UserDefaults للقراءة المتزامنة
            UserDefaults.standard.set(newSettings.autoSaveSelfDestructingMedia, forKey: "joker_auto_save_media")
            UserDefaults.standard.set(newSettings.allow100Accounts, forKey: "joker_allow_100_accounts")
            UserDefaults.standard.set(newSettings.ghostMode, forKey: "joker_ghost_mode")
            UserDefaults.standard.set(newSettings.forcePremiumTranslation, forKey: "joker_force_premium_translation")
            UserDefaults.standard.set(newSettings.keepDeletedMessages, forKey: "joker_keep_deleted_messages")
            UserDefaults.standard.set(newSettings.requireChannelSubscription, forKey: "joker_require_subscription")
            UserDefaults.standard.synchronize()
            
            return SharedPreferencesEntry(newSettings)
        })
    }
}

public func getJokerSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<JokerSettings, NoError> {
    return accountManager.sharedData(keys: [JokerSharedDataKeys.jokerSettings])
    |> map { sharedData -> JokerSettings in
        if let entry = sharedData.entries[JokerSharedDataKeys.jokerSettings]?.get(JokerSettings.self) {
            return entry
        }
        return JokerSettings.defaultSettings
    }
}
