//
//  SettingsSection.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a section of the application settings
public indirect enum SettingsSection: Codable, Equatable, Hashable {

    /// The appearance section
    case settingsSectionAppearance(SettingsSectionAppearance)

    /// The "Ask a question" section
    case settingsSectionAskQuestion

    /// The "Telegram Business" section
    case settingsSectionBusiness(SettingsSectionBusiness)

    /// The chat folder settings section
    case settingsSectionChatFolders(SettingsSectionChatFolders)

    /// The data and storage settings section
    case settingsSectionDataAndStorage(SettingsSectionDataAndStorage)

    /// The Devices section
    case settingsSectionDevices(SettingsSectionDevices)

    /// The profile edit section
    case settingsSectionEditProfile(SettingsSectionEditProfile)

    /// The FAQ section
    case settingsSectionFaq

    /// The "Telegram Features" section
    case settingsSectionFeatures

    /// The in-app browser settings section
    case settingsSectionInAppBrowser(SettingsSectionInAppBrowser)

    /// The application language section
    case settingsSectionLanguage(SettingsSectionLanguage)

    /// The Telegram Star balance and transaction section
    case settingsSectionMyStars(SettingsSectionMyStars)

    /// The Toncoin balance and transaction section
    case settingsSectionMyToncoins

    /// The notification settings section
    case settingsSectionNotifications(SettingsSectionNotifications)

    /// The power saving settings section
    case settingsSectionPowerSaving(SettingsSectionPowerSaving)

    /// The "Telegram Premium" section
    case settingsSectionPremium

    /// The privacy and security section
    case settingsSectionPrivacyAndSecurity(SettingsSectionPrivacyAndSecurity)

    /// The "Privacy Policy" section
    case settingsSectionPrivacyPolicy

    /// The current user's QR code section
    case settingsSectionQrCode(SettingsSectionQrCode)

    /// Search in Settings
    case settingsSectionSearch

    /// The "Send a gift" section
    case settingsSectionSendGift(SettingsSectionSendGift)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case settingsSectionAppearance
        case settingsSectionAskQuestion
        case settingsSectionBusiness
        case settingsSectionChatFolders
        case settingsSectionDataAndStorage
        case settingsSectionDevices
        case settingsSectionEditProfile
        case settingsSectionFaq
        case settingsSectionFeatures
        case settingsSectionInAppBrowser
        case settingsSectionLanguage
        case settingsSectionMyStars
        case settingsSectionMyToncoins
        case settingsSectionNotifications
        case settingsSectionPowerSaving
        case settingsSectionPremium
        case settingsSectionPrivacyAndSecurity
        case settingsSectionPrivacyPolicy
        case settingsSectionQrCode
        case settingsSectionSearch
        case settingsSectionSendGift
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .settingsSectionAppearance:
            let value = try SettingsSectionAppearance(from: decoder)
            self = .settingsSectionAppearance(value)
        case .settingsSectionAskQuestion:
            self = .settingsSectionAskQuestion
        case .settingsSectionBusiness:
            let value = try SettingsSectionBusiness(from: decoder)
            self = .settingsSectionBusiness(value)
        case .settingsSectionChatFolders:
            let value = try SettingsSectionChatFolders(from: decoder)
            self = .settingsSectionChatFolders(value)
        case .settingsSectionDataAndStorage:
            let value = try SettingsSectionDataAndStorage(from: decoder)
            self = .settingsSectionDataAndStorage(value)
        case .settingsSectionDevices:
            let value = try SettingsSectionDevices(from: decoder)
            self = .settingsSectionDevices(value)
        case .settingsSectionEditProfile:
            let value = try SettingsSectionEditProfile(from: decoder)
            self = .settingsSectionEditProfile(value)
        case .settingsSectionFaq:
            self = .settingsSectionFaq
        case .settingsSectionFeatures:
            self = .settingsSectionFeatures
        case .settingsSectionInAppBrowser:
            let value = try SettingsSectionInAppBrowser(from: decoder)
            self = .settingsSectionInAppBrowser(value)
        case .settingsSectionLanguage:
            let value = try SettingsSectionLanguage(from: decoder)
            self = .settingsSectionLanguage(value)
        case .settingsSectionMyStars:
            let value = try SettingsSectionMyStars(from: decoder)
            self = .settingsSectionMyStars(value)
        case .settingsSectionMyToncoins:
            self = .settingsSectionMyToncoins
        case .settingsSectionNotifications:
            let value = try SettingsSectionNotifications(from: decoder)
            self = .settingsSectionNotifications(value)
        case .settingsSectionPowerSaving:
            let value = try SettingsSectionPowerSaving(from: decoder)
            self = .settingsSectionPowerSaving(value)
        case .settingsSectionPremium:
            self = .settingsSectionPremium
        case .settingsSectionPrivacyAndSecurity:
            let value = try SettingsSectionPrivacyAndSecurity(from: decoder)
            self = .settingsSectionPrivacyAndSecurity(value)
        case .settingsSectionPrivacyPolicy:
            self = .settingsSectionPrivacyPolicy
        case .settingsSectionQrCode:
            let value = try SettingsSectionQrCode(from: decoder)
            self = .settingsSectionQrCode(value)
        case .settingsSectionSearch:
            self = .settingsSectionSearch
        case .settingsSectionSendGift:
            let value = try SettingsSectionSendGift(from: decoder)
            self = .settingsSectionSendGift(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .settingsSectionAppearance(let value):
            try container.encode(Kind.settingsSectionAppearance, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionAskQuestion:
            try container.encode(Kind.settingsSectionAskQuestion, forKey: .type)
        case .settingsSectionBusiness(let value):
            try container.encode(Kind.settingsSectionBusiness, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionChatFolders(let value):
            try container.encode(Kind.settingsSectionChatFolders, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionDataAndStorage(let value):
            try container.encode(Kind.settingsSectionDataAndStorage, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionDevices(let value):
            try container.encode(Kind.settingsSectionDevices, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionEditProfile(let value):
            try container.encode(Kind.settingsSectionEditProfile, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionFaq:
            try container.encode(Kind.settingsSectionFaq, forKey: .type)
        case .settingsSectionFeatures:
            try container.encode(Kind.settingsSectionFeatures, forKey: .type)
        case .settingsSectionInAppBrowser(let value):
            try container.encode(Kind.settingsSectionInAppBrowser, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionLanguage(let value):
            try container.encode(Kind.settingsSectionLanguage, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionMyStars(let value):
            try container.encode(Kind.settingsSectionMyStars, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionMyToncoins:
            try container.encode(Kind.settingsSectionMyToncoins, forKey: .type)
        case .settingsSectionNotifications(let value):
            try container.encode(Kind.settingsSectionNotifications, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionPowerSaving(let value):
            try container.encode(Kind.settingsSectionPowerSaving, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionPremium:
            try container.encode(Kind.settingsSectionPremium, forKey: .type)
        case .settingsSectionPrivacyAndSecurity(let value):
            try container.encode(Kind.settingsSectionPrivacyAndSecurity, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionPrivacyPolicy:
            try container.encode(Kind.settingsSectionPrivacyPolicy, forKey: .type)
        case .settingsSectionQrCode(let value):
            try container.encode(Kind.settingsSectionQrCode, forKey: .type)
            try value.encode(to: encoder)
        case .settingsSectionSearch:
            try container.encode(Kind.settingsSectionSearch, forKey: .type)
        case .settingsSectionSendGift(let value):
            try container.encode(Kind.settingsSectionSendGift, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The appearance section
public struct SettingsSectionAppearance: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "themes", "themes/edit", "themes/create", "wallpapers", "wallpapers/edit", "wallpapers/set", "wallpapers/choose-photo", "your-color/profile", "your-color/profile/add-icons", "your-color/profile/use-gift", "your-color/profile/reset", "your-color/name", "your-color/name/add-icons", "your-color/name/use-gift", "night-mode", "auto-night-mode", "text-size", "text-size/use-system", "message-corners", "animations", "stickers-and-emoji", "stickers-and-emoji/edit", "stickers-and-emoji/trending", "stickers-and-emoji/archived", "stickers-and-emoji/archived/edit", "stickers-and-emoji/emoji", "stickers-and-emoji/emoji/edit", "stickers-and-emoji/emoji/archived", "stickers-and-emoji/emoji/archived/edit", "stickers-and-emoji/emoji/suggest", "stickers-and-emoji/emoji/quick-reaction", "stickers-and-emoji/emoji/quick-reaction/choose", "stickers-and-emoji/suggest-by-emoji", "stickers-and-emoji/large-emoji", "stickers-and-emoji/dynamic-order", "stickers-and-emoji/emoji/show-more", "app-icon", "tap-for-next-media"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The "Telegram Business" section
public struct SettingsSectionBusiness: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "do-not-hide-ads"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The chat folder settings section
public struct SettingsSectionChatFolders: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "edit", "create", "add-recommended", "show-tags", "tab-view"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The data and storage settings section
public struct SettingsSectionDataAndStorage: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "storage", "storage/edit", "storage/auto-remove", "storage/clear-cache", "storage/max-cache", "usage", "usage/mobile", "usage/wifi", "usage/reset", "usage/roaming", "auto-download/mobile", "auto-download/mobile/enable", "auto-download/mobile/usage", "auto-download/mobile/photos", "auto-download/mobile/stories", "auto-download/mobile/videos", "auto-download/mobile/files", "auto-download/wifi", "auto-download/wifi/enable", "auto-download/wifi/usage", "auto-download/wifi/photos", "auto-download/wifi/stories", "auto-download/wifi/videos", "auto-download/wifi/files", "auto-download/roaming", "auto-download/roaming/enable", "auto-download/roaming/usage", "auto-download/roaming/photos", "auto-download/roaming/stories", "auto-download/roaming/videos", "auto-download/roaming/files", "auto-download/reset", "save-to-photos/chats", "save-to-photos/chats/max-video-size", "save-to-photos/chats/add-exception", "save-to-photos/chats/delete-all", "save-to-photos/groups", "save-to-photos/groups/max-video-size", "save-to-photos/groups/add-exception", "save-to-photos/groups/delete-all", "save-to-photos/channels", "save-to-photos/channels/max-video-size", "save-to-photos/channels/add-exception", "save-to-photos/channels/delete-all", "less-data-calls", "open-links", "share-sheet", "share-sheet/suggested-chats", "share-sheet/suggest-by", "share-sheet/reset", "saved-edited-photos", "pause-music", "raise-to-listen", "raise-to-speak", "show-18-content", "proxy", "proxy/edit", "proxy/use-proxy", "proxy/add-proxy", "proxy/share-list", "proxy/use-for-calls"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The Devices section
public struct SettingsSectionDevices: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "edit", "link-desktop", "terminate-sessions", "auto-terminate"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The profile edit section
public struct SettingsSectionEditProfile: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "set-photo", "first-name", "last-name", "emoji-status", "bio", "birthday", "change-number", "username", "your-color", "channel", "add-account", "log-out", "profile-color/profile", "profile-color/profile/add-icons", "profile-color/profile/use-gift", "profile-color/name", "profile-color/name/add-icons", "profile-color/name/use-gift", "profile-photo/use-emoji"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The in-app browser settings section
public struct SettingsSectionInAppBrowser: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "enable-browser", "clear-cookies", "clear-cache", "history", "clear-history", "never-open", "clear-list", "search"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The application language section
public struct SettingsSectionLanguage: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "show-button" for Show Translate Button toggle, "translate-chats" for Translate Entire Chats toggle, "do-not-translate" - for Do Not Translate language list
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The Telegram Star balance and transaction section
public struct SettingsSectionMyStars: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "top-up", "stats", "gift", "earn"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The notification settings section
public struct SettingsSectionNotifications: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "accounts", "private-chats", "private-chats/edit", "private-chats/show", "private-chats/preview", "private-chats/sound", "private-chats/add-exception", "private-chats/delete-exceptions", "private-chats/light-color", "private-chats/vibrate", "private-chats/priority", "groups", "groups/edit", "groups/show", "groups/preview", "groups/sound", "groups/add-exception", "groups/delete-exceptions", "groups/light-color", "groups/vibrate", "groups/priority", "channels", "channels/edit", "channels/show", "channels/preview", "channels/sound", "channels/add-exception", "channels/delete-exceptions", "channels/light-color", "channels/vibrate", "channels/priority", "stories", "stories/new", "stories/important", "stories/show-sender", "stories/sound", "stories/add-exception", "stories/delete-exceptions", "stories/light-color", "stories/vibrate", "stories/priority", "reactions", "reactions/messages", "reactions/stories", "reactions/show-sender", "reactions/sound", "reactions/light-color", "reactions/vibrate", "reactions/priority", "in-app-sounds", "in-app-vibrate", "in-app-preview", "in-chat-sounds", "in-app-popup", "lock-screen-names", "include-channels", "include-muted-chats", "count-unread-messages", "new-contacts", "pinned-messages", "reset", "web"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The power saving settings section
public struct SettingsSectionPowerSaving: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "videos", "gifs", "stickers", "emoji", "effects", "preload", "background", "call-animations", "particles", "transitions"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The privacy and security section
public struct SettingsSectionPrivacyAndSecurity: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "blocked", "blocked/edit", "blocked/block-user", "blocked/block-user/chats", "blocked/block-user/contacts", "active-websites", "active-websites/edit", "active-websites/disconnect-all", "passcode", "passcode/disable", "passcode/change", "passcode/auto-lock", "passcode/face-id", "passcode/fingerprint", "2sv", "2sv/change", "2sv/disable", "2sv/change-email", "passkey", "passkey/create", "auto-delete", "auto-delete/set-custom", "login-email", "phone-number", "phone-number/never", "phone-number/always", "last-seen", "last-seen/never", "last-seen/always", "last-seen/hide-read-time", "profile-photos", "profile-photos/never", "profile-photos/always", "profile-photos/set-public", "profile-photos/update-public", "profile-photos/remove-public", "bio", "bio/never", "bio/always", "gifts", "gifts/show-icon", "gifts/never", "gifts/always", "gifts/accepted-types", "birthday", "birthday/add", "birthday/never", "birthday/always", "saved-music", "saved-music/never", "saved-music/always", "forwards", "forwards/never", "forwards/always", "calls", "calls/never", "calls/always", "calls/p2p", "calls/p2p/never", "calls/p2p/always", "calls/ios-integration", "voice", "voice/never", "voice/always", "messages", "messages/set-price", "messages/exceptions", "invites", "invites/never", "invites/always", "self-destruct", "data-settings", "data-settings/sync-contacts", "data-settings/delete-synced", "data-settings/suggest-contacts", "data-settings/delete-cloud-drafts", "data-settings/clear-payment-info", "data-settings/link-previews", "data-settings/bot-settings", "data-settings/map-provider", "archive-and-mute"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The current user's QR code section
public struct SettingsSectionQrCode: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "share", "scan"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

/// The "Send a gift" section
public struct SettingsSectionSendGift: Codable, Equatable, Hashable {

    /// Subsection of the section; may be one of "", "self"
    public let subsection: String


    public init(subsection: String) {
        self.subsection = subsection
    }
}

