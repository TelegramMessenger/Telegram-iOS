import Foundation
import Postbox
import SwiftSignalKit
import SyncCore

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

public struct InAppNotificationSettings: PreferencesEntry, Equatable {
    public var playSounds: Bool
    public var vibrate: Bool
    public var displayPreviews: Bool
    public var totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle
    public var totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory
    public var totalUnreadCountIncludeTags: PeerSummaryCounterTags
    public var displayNameOnLockscreen: Bool
    public var displayNotificationsFromAllAccounts: Bool
    public var disabledNotificationsAccountRecords: [AccountRecordId]
    
    public static var defaultSettings: InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: true, vibrate: false, displayPreviews: true, totalUnreadCountDisplayStyle: .filtered, totalUnreadCountDisplayCategory: .messages, totalUnreadCountIncludeTags: .all, displayNameOnLockscreen: true, displayNotificationsFromAllAccounts: true, disabledNotificationsAccountRecords: [])
    }
    
    public init(playSounds: Bool, vibrate: Bool, displayPreviews: Bool, totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: PeerSummaryCounterTags, displayNameOnLockscreen: Bool, displayNotificationsFromAllAccounts: Bool, disabledNotificationsAccountRecords: [AccountRecordId]) {
        self.playSounds = playSounds
        self.vibrate = vibrate
        self.displayPreviews = displayPreviews
        self.totalUnreadCountDisplayStyle = totalUnreadCountDisplayStyle
        self.totalUnreadCountDisplayCategory = totalUnreadCountDisplayCategory
        self.totalUnreadCountIncludeTags = totalUnreadCountIncludeTags
        self.displayNameOnLockscreen = displayNameOnLockscreen
        self.displayNotificationsFromAllAccounts = displayNotificationsFromAllAccounts
        self.disabledNotificationsAccountRecords = disabledNotificationsAccountRecords
    }
    
    public init(decoder: PostboxDecoder) {
        self.playSounds = decoder.decodeInt32ForKey("s", orElse: 0) != 0
        self.vibrate = decoder.decodeInt32ForKey("v", orElse: 0) != 0
        self.displayPreviews = decoder.decodeInt32ForKey("p", orElse: 0) != 0
        self.totalUnreadCountDisplayStyle = TotalUnreadCountDisplayStyle(rawValue: decoder.decodeInt32ForKey("cds", orElse: 0)) ?? .filtered
        self.totalUnreadCountDisplayCategory = TotalUnreadCountDisplayCategory(rawValue: decoder.decodeInt32ForKey("totalUnreadCountDisplayCategory", orElse: 1)) ?? .messages
        if let value = decoder.decodeOptionalInt32ForKey("totalUnreadCountIncludeTags_2") {
            self.totalUnreadCountIncludeTags = PeerSummaryCounterTags(rawValue: value)
        } else if let value = decoder.decodeOptionalInt32ForKey("totalUnreadCountIncludeTags") {
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
        self.displayNameOnLockscreen = decoder.decodeInt32ForKey("displayNameOnLockscreen", orElse: 1) != 0
        self.displayNotificationsFromAllAccounts = decoder.decodeInt32ForKey("displayNotificationsFromAllAccounts", orElse: 1) != 0
        self.disabledNotificationsAccountRecords = decoder.decodeInt64ArrayForKey("disabledIds").map { AccountRecordId(rawValue: $0) }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.playSounds ? 1 : 0, forKey: "s")
        encoder.encodeInt32(self.vibrate ? 1 : 0, forKey: "v")
        encoder.encodeInt32(self.displayPreviews ? 1 : 0, forKey: "p")
        encoder.encodeInt32(self.totalUnreadCountDisplayStyle.rawValue, forKey: "cds")
        encoder.encodeInt32(self.totalUnreadCountDisplayCategory.rawValue, forKey: "totalUnreadCountDisplayCategory")
        encoder.encodeInt32(self.totalUnreadCountIncludeTags.rawValue, forKey: "totalUnreadCountIncludeTags_2")
        encoder.encodeInt32(self.displayNameOnLockscreen ? 1 : 0, forKey: "displayNameOnLockscreen")
        encoder.encodeInt32(self.displayNotificationsFromAllAccounts ? 1 : 0, forKey: "displayNotificationsFromAllAccounts")
        encoder.encodeInt64Array(self.disabledNotificationsAccountRecords.map { $0.int64 }, forKey: "disabledIds")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? InAppNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
}

public func updateInAppNotificationSettingsInteractively(accountManager: AccountManager, _ f: @escaping (InAppNotificationSettings) -> InAppNotificationSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        updateInAppNotificationSettingsInteractively(transaction: transaction, f)
    }
}

public func updateInAppNotificationSettingsInteractively(transaction: AccountManagerModifier, _ f: @escaping (InAppNotificationSettings) -> InAppNotificationSettings) {
    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.inAppNotificationSettings, { entry in
        let currentSettings: InAppNotificationSettings
        if let entry = entry as? InAppNotificationSettings {
            currentSettings = entry
        } else {
            currentSettings = InAppNotificationSettings.defaultSettings
        }
        return f(currentSettings)
    })
}

public func setAccountPushNotificationsEnabledOnThisDevice(accountIds: [AccountRecordId: Bool], accountManager: AccountManager) {
    let _ = accountManager.transaction { transaction -> Void in
        setAccountPushNotificationsEnabledOnThisDevice(accountIds: accountIds,transaction: transaction)
    }.start()
}

public func setAccountPushNotificationsEnabledOnThisDevice(accountIds: [AccountRecordId: Bool], transaction: AccountManagerModifier) {
    updateInAppNotificationSettingsInteractively(transaction: transaction, { settings in
        var settings = settings
        for (accountId, enabled) in accountIds {
            if !enabled {
                if !settings.disabledNotificationsAccountRecords.contains(accountId) {
                    settings.disabledNotificationsAccountRecords.append(accountId)
                }
            } else {
                settings.disabledNotificationsAccountRecords.removeAll(where: {$0 == accountId })
            }
        }
        return settings
    })
}

