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
    public var customSound: String?
    
    public static var defaultSettings: InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: true, vibrate: false, displayPreviews: true, totalUnreadCountDisplayStyle: .filtered, totalUnreadCountDisplayCategory: .messages, totalUnreadCountIncludeTags: .all, displayNameOnLockscreen: true, displayNotificationsFromAllAccounts: true, customSound: nil)
    }
    
    public init(playSounds: Bool, vibrate: Bool, displayPreviews: Bool, totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: PeerSummaryCounterTags, displayNameOnLockscreen: Bool, displayNotificationsFromAllAccounts: Bool, customSound: String?) {
        self.playSounds = playSounds
        self.vibrate = vibrate
        self.displayPreviews = displayPreviews
        self.totalUnreadCountDisplayStyle = totalUnreadCountDisplayStyle
        self.totalUnreadCountDisplayCategory = totalUnreadCountDisplayCategory
        self.totalUnreadCountIncludeTags = totalUnreadCountIncludeTags
        self.displayNameOnLockscreen = displayNameOnLockscreen
        self.displayNotificationsFromAllAccounts = displayNotificationsFromAllAccounts
        self.customSound = customSound
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
        
        self.customSound = try container.decodeIfPresent(String.self, forKey: "customSound")
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
        try container.encodeIfPresent(self.customSound, forKey: "customSound")
    }
}

public func updateInAppNotificationSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (InAppNotificationSettings) -> InAppNotificationSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
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
}
