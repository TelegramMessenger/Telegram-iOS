import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

public enum TotalUnreadCountDisplayStyle: Int32 {
    case filtered = 0
    
    public var category: ChatListTotalUnreadStateCategory {
        switch self {
            case .filtered:
                return .filtered
        }
    }
}

public enum TotalUnreadCountDisplayCategory: Int32 {
    case chats = 0
    case messages = 1
    
    public var statsType: ChatListTotalUnreadStateStats {
        switch self {
            case .chats:
                return .chats
            case .messages:
                return .messages
        }
    }
}

public struct InAppNotificationSettings: Codable, Equatable {
    public var playSounds: Bool
    public var vibrate: Bool
    public var displayPreviews: Bool
    public var totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle
    public var totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory
    public var totalUnreadCountIncludeTags: PeerSummaryCounterTags
    public var displayNameOnLockscreen: Bool
    public var displayNotificationsFromAllAccounts: Bool
    public var disabledNotificationsAccountRecords: [AccountRecordId]
    public var disabledNotificationsAccountRecordsMasterPasscodeSnapshot: [AccountRecordId]
    public var disabledNotificationsAccountRecordsLogoutSnapshot: [AccountRecordId]
    public var hasDisabledNotificationsAccountRecordsMasterPasscodeSnapshot: Bool
    public var hasDisabledNotificationsAccountRecordsLogoutSnapshot: Bool
    
    public static var defaultSettings: InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: true, vibrate: false, displayPreviews: true, totalUnreadCountDisplayStyle: .filtered, totalUnreadCountDisplayCategory: .messages, totalUnreadCountIncludeTags: .all, displayNameOnLockscreen: true, displayNotificationsFromAllAccounts: true, disabledNotificationsAccountRecords: [], savedDisabledNotificationsAccountRecords: [], disabledNotificationsAccountRecordsLogoutSnapshot: [], hasDisabledNotificationsAccountRecordsMasterPasscodeSnapshot: false, hasDisabledNotificationsAccountRecordsLogoutSnapshot: false)
    }
    
    public init(playSounds: Bool, vibrate: Bool, displayPreviews: Bool, totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: PeerSummaryCounterTags, displayNameOnLockscreen: Bool, displayNotificationsFromAllAccounts: Bool, disabledNotificationsAccountRecords: [AccountRecordId], savedDisabledNotificationsAccountRecords: [AccountRecordId], disabledNotificationsAccountRecordsLogoutSnapshot: [AccountRecordId], hasDisabledNotificationsAccountRecordsMasterPasscodeSnapshot: Bool, hasDisabledNotificationsAccountRecordsLogoutSnapshot: Bool) {
        self.playSounds = playSounds
        self.vibrate = vibrate
        self.displayPreviews = displayPreviews
        self.totalUnreadCountDisplayStyle = totalUnreadCountDisplayStyle
        self.totalUnreadCountDisplayCategory = totalUnreadCountDisplayCategory
        self.totalUnreadCountIncludeTags = totalUnreadCountIncludeTags
        self.displayNameOnLockscreen = displayNameOnLockscreen
        self.displayNotificationsFromAllAccounts = displayNotificationsFromAllAccounts
        self.disabledNotificationsAccountRecords = disabledNotificationsAccountRecords
        self.disabledNotificationsAccountRecordsMasterPasscodeSnapshot = savedDisabledNotificationsAccountRecords
        self.disabledNotificationsAccountRecordsLogoutSnapshot = disabledNotificationsAccountRecordsLogoutSnapshot
        self.hasDisabledNotificationsAccountRecordsMasterPasscodeSnapshot = hasDisabledNotificationsAccountRecordsMasterPasscodeSnapshot
        self.hasDisabledNotificationsAccountRecordsLogoutSnapshot = hasDisabledNotificationsAccountRecordsLogoutSnapshot
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.playSounds = (try container.decode(Int32.self, forKey: "s")) != 0
        self.vibrate = (try container.decode(Int32.self, forKey: "v")) != 0
        self.displayPreviews = (try container.decode(Int32.self, forKey: "p")) != 0
        self.totalUnreadCountDisplayStyle = TotalUnreadCountDisplayStyle(rawValue: try container.decode(Int32.self, forKey: "cds")) ?? .filtered
        self.totalUnreadCountDisplayCategory = TotalUnreadCountDisplayCategory(rawValue: try container.decodeIfPresent(Int32.self, forKey: "totalUnreadCountDisplayCategory") ?? 1) ?? .messages
        if let value = try container.decodeIfPresent(Int32.self, forKey: "totalUnreadCountIncludeTags_2") {
            self.totalUnreadCountIncludeTags = PeerSummaryCounterTags(rawValue: value)
        } else if let value = try container.decodeIfPresent(Int32.self, forKey: "totalUnreadCountIncludeTags") {
            var resultTags: PeerSummaryCounterTags = []
            for legacyTag in LegacyPeerSummaryCounterTags(rawValue: value) {
                if legacyTag == .regularChatsAndPrivateGroups {
                    resultTags.insert(.contact)
                    resultTags.insert(.nonContact)
                    resultTags.insert(.bot)
                    resultTags.insert(.group)
                } else if legacyTag == .publicGroups {
                    resultTags.insert(.group)
                } else if legacyTag == .channels {
                    resultTags.insert(.channel)
                }
            }
            self.totalUnreadCountIncludeTags = resultTags
        } else {
            self.totalUnreadCountIncludeTags = .all
        }
        self.displayNameOnLockscreen = (try container.decodeIfPresent(Int32.self, forKey: "displayNameOnLockscreen") ?? 1) != 0
        self.displayNotificationsFromAllAccounts = (try container.decodeIfPresent(Int32.self, forKey: "displayNotificationsFromAllAccounts") ?? 1) != 0
        self.disabledNotificationsAccountRecords = (try container.decode([Int64].self, forKey: "disabledIds")).map { AccountRecordId(rawValue: $0) }
        self.disabledNotificationsAccountRecordsMasterPasscodeSnapshot = (try container.decode([Int64].self, forKey: "disabledIdsMasterPasscodeSnapshot")).map { AccountRecordId(rawValue: $0) }
        self.disabledNotificationsAccountRecordsLogoutSnapshot = (try container.decode([Int64].self, forKey: "disabledIdsLogoutSnapshot")).map { AccountRecordId(rawValue: $0) }
        self.hasDisabledNotificationsAccountRecordsMasterPasscodeSnapshot = (try container.decodeIfPresent(Int32.self, forKey: "hasDisabledIdsMasterPasscodeSnapshot") ?? 0) != 0
        self.hasDisabledNotificationsAccountRecordsLogoutSnapshot = (try container.decodeIfPresent(Int32.self, forKey: "hasDisabledIdsLogoutSnapshot") ?? 0) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.playSounds ? 1 : 0) as Int32, forKey: "s")
        try container.encode((self.vibrate ? 1 : 0) as Int32, forKey: "v")
        try container.encode((self.displayPreviews ? 1 : 0) as Int32, forKey: "p")
        try container.encode(self.totalUnreadCountDisplayStyle.rawValue, forKey: "cds")
        try container.encode(self.totalUnreadCountDisplayCategory.rawValue, forKey: "totalUnreadCountDisplayCategory")
        try container.encode(self.totalUnreadCountIncludeTags.rawValue, forKey: "totalUnreadCountIncludeTags_2")
        try container.encode((self.displayNameOnLockscreen ? 1 : 0) as Int32, forKey: "displayNameOnLockscreen")
        try container.encode((self.displayNotificationsFromAllAccounts ? 1 : 0) as Int32, forKey: "displayNotificationsFromAllAccounts")
        try container.encode(self.disabledNotificationsAccountRecords.map { $0.int64 }, forKey: "disabledIds")
        try container.encode(self.disabledNotificationsAccountRecordsMasterPasscodeSnapshot.map { $0.int64 }, forKey: "disabledIdsMasterPasscodeSnapshot")
        try container.encode(self.disabledNotificationsAccountRecordsLogoutSnapshot.map { $0.int64 }, forKey: "disabledIdsLogoutSnapshot")
        try container.encode((self.hasDisabledNotificationsAccountRecordsMasterPasscodeSnapshot ? 1 : 0) as Int32, forKey: "hasDisabledIdsMasterPasscodeSnapshot")
        try container.encode((self.hasDisabledNotificationsAccountRecordsLogoutSnapshot ? 1 : 0) as Int32, forKey: "hasDisabledIdsLogoutSnapshot")
    }
}

public func updateInAppNotificationSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (InAppNotificationSettings) -> InAppNotificationSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        updateInAppNotificationSettingsInteractively(transaction: transaction, f)
    }
}

public func updateInAppNotificationSettingsInteractively(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, _ f: @escaping (InAppNotificationSettings) -> InAppNotificationSettings) {
    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.inAppNotificationSettings, { entry in
        let currentSettings: InAppNotificationSettings
        if let entry = entry?.get(InAppNotificationSettings.self) {
            currentSettings = entry
        } else {
            currentSettings = InAppNotificationSettings.defaultSettings
        }
        return PreferencesEntry(f(currentSettings))
    })
}

public func updatePushNotificationsSettingsAfterOffMasterPasscode(transaction: AccountManagerModifier<TelegramAccountManagerTypes>) {
    let accountIds = transaction.getRecords()
        .filter { $0.attributes.contains { $0.isHiddenAccountAttribute } }
        .map { $0.id }

    updateInAppNotificationSettingsInteractively(transaction: transaction, { settings in
        var settings = settings
        settings.disabledNotificationsAccountRecords = accountIds
        return settings
    })
}

public func updatePushNotificationsSettingsAfterOnMasterPasscode(transaction: AccountManagerModifier<TelegramAccountManagerTypes>) {
    updateInAppNotificationSettingsInteractively(transaction: transaction, { settings in
        var settings = settings
        settings.disabledNotificationsAccountRecords = []
        return settings
    })
}

public func updatePushNotificationsSettingsAfterAllPublicLogout(accountManager: AccountManager<TelegramAccountManagerTypes>) {
    let _ = (accountManager.transaction { transaction in
        let accountIds = transaction.getRecords()
            .filter { $0.attributes.contains { $0.isHiddenAccountAttribute } }
            .map { $0.id }
        
        updateInAppNotificationSettingsInteractively(transaction: transaction, { settings in
            var settings = settings
            settings.disabledNotificationsAccountRecords = accountIds
            return settings
        })
    } |> deliverOnMainQueue).start()
}

public func updatePushNotificationsSettingsAfterLogin(accountManager: AccountManager<TelegramAccountManagerTypes>) {
    let _ = (accountManager.transaction { transaction -> Void in
        updateInAppNotificationSettingsInteractively(transaction: transaction, { settings in
            var settings = settings
            settings.disabledNotificationsAccountRecords = []
            return settings
        })
    } |> deliverOnMainQueue).start()
}
