import Foundation
import Postbox
import SwiftSignalKit

public enum SupportSwitchBehavior: Int32 {
    case none = 0
    case next = 1
    case previous = 2
}

public enum SupportChatListBeside: Int32 {
    case off = 0
    case landscape = 1
    case everywhere = 2
}

public func supportChatListBesideUsesSplitView(_ value: SupportChatListBeside, isLandscape: Bool) -> Bool {
    return value == .everywhere || (value == .landscape && isLandscape)
}

public func supportChatListBesideNarrowsList(_ value: SupportChatListBeside, isLandscape: Bool) -> Bool {
    return value == .everywhere && !isLandscape
}

public struct SupportSettings: Codable, Equatable {
    public static let allChatsLoadPeriod: Int32 = 0

    public static var `default`: SupportSettings {
        return SupportSettings(switchBehavior: .next, fixChatsOrder: true, templatesAutocomplete: true, chatLoadPeriod: 7 * 24 * 60 * 60, allSearchResults: false, sendAllSilently: false, automaticMediaDownload: false, inAppNotifications: false)
    }

    public var switchBehavior: SupportSwitchBehavior
    public var fixChatsOrder: Bool
    public var templatesAutocomplete: Bool
    public var chatLoadPeriod: Int32
    public var allSearchResults: Bool
    public var sendAllSilently: Bool
    public var automaticMediaDownload: Bool
    public var inAppNotifications: Bool
    public var chatListBeside: SupportChatListBeside
    public var shortcutOverrides: [SupportShortcutOverride] = []
    public var trailingTags: Bool = true
    public var collapseMiddleTags: Bool = true
    public var hideProfilePhotos: Bool = false
    public var hideKeyboardOnSwitch: Bool = true
    public var swipeToNextChat: Bool = false
    public var hideChatsWithoutIncomingMessages: Bool = false

    public init(switchBehavior: SupportSwitchBehavior, fixChatsOrder: Bool, templatesAutocomplete: Bool, chatLoadPeriod: Int32, allSearchResults: Bool, sendAllSilently: Bool, automaticMediaDownload: Bool, inAppNotifications: Bool, chatListBeside: SupportChatListBeside = .off) {
        self.switchBehavior = switchBehavior
        self.fixChatsOrder = fixChatsOrder
        self.templatesAutocomplete = templatesAutocomplete
        self.chatLoadPeriod = chatLoadPeriod
        self.allSearchResults = allSearchResults
        self.sendAllSilently = sendAllSilently
        self.automaticMediaDownload = automaticMediaDownload
        self.inAppNotifications = inAppNotifications
        self.chatListBeside = chatListBeside
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        let defaults = SupportSettings.default

        self.switchBehavior = (try container.decodeIfPresent(Int32.self, forKey: "switchBehavior")).flatMap(SupportSwitchBehavior.init(rawValue:)) ?? defaults.switchBehavior
        self.fixChatsOrder = try container.decodeIfPresent(Bool.self, forKey: "fixChatsOrder") ?? defaults.fixChatsOrder
        self.templatesAutocomplete = try container.decodeIfPresent(Bool.self, forKey: "templatesAutocomplete") ?? defaults.templatesAutocomplete
        self.chatLoadPeriod = try container.decodeIfPresent(Int32.self, forKey: "chatLoadPeriod") ?? defaults.chatLoadPeriod
        self.allSearchResults = try container.decodeIfPresent(Bool.self, forKey: "allSearchResults") ?? defaults.allSearchResults
        self.sendAllSilently = try container.decodeIfPresent(Bool.self, forKey: "sendAllSilently") ?? defaults.sendAllSilently
        self.automaticMediaDownload = try container.decodeIfPresent(Bool.self, forKey: "automaticMediaDownload") ?? defaults.automaticMediaDownload
        self.inAppNotifications = try container.decodeIfPresent(Bool.self, forKey: "inAppNotifications") ?? defaults.inAppNotifications
        self.chatListBeside = (try container.decodeIfPresent(Int32.self, forKey: "chatListBeside")).flatMap(SupportChatListBeside.init(rawValue:)) ?? defaults.chatListBeside
        self.shortcutOverrides = try container.decodeIfPresent([SupportShortcutOverride].self, forKey: "shortcutOverrides") ?? defaults.shortcutOverrides
        self.trailingTags = try container.decodeIfPresent(Bool.self, forKey: "trailingTags") ?? defaults.trailingTags
        self.collapseMiddleTags = try container.decodeIfPresent(Bool.self, forKey: "collapseMiddleTags") ?? defaults.collapseMiddleTags
        self.hideProfilePhotos = try container.decodeIfPresent(Bool.self, forKey: "hideProfilePhotos") ?? defaults.hideProfilePhotos
        self.hideKeyboardOnSwitch = try container.decodeIfPresent(Bool.self, forKey: "hideKeyboardOnSwitch") ?? defaults.hideKeyboardOnSwitch
        self.swipeToNextChat = try container.decodeIfPresent(Bool.self, forKey: "swipeToNextChat") ?? defaults.swipeToNextChat
        self.hideChatsWithoutIncomingMessages = try container.decodeIfPresent(Bool.self, forKey: "hideChatsWithoutIncomingMessages") ?? defaults.hideChatsWithoutIncomingMessages
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.switchBehavior.rawValue, forKey: "switchBehavior")
        try container.encode(self.fixChatsOrder, forKey: "fixChatsOrder")
        try container.encode(self.templatesAutocomplete, forKey: "templatesAutocomplete")
        try container.encode(self.chatLoadPeriod, forKey: "chatLoadPeriod")
        try container.encode(self.allSearchResults, forKey: "allSearchResults")
        try container.encode(self.sendAllSilently, forKey: "sendAllSilently")
        try container.encode(self.automaticMediaDownload, forKey: "automaticMediaDownload")
        try container.encode(self.inAppNotifications, forKey: "inAppNotifications")
        try container.encode(self.chatListBeside.rawValue, forKey: "chatListBeside")
        try container.encode(self.shortcutOverrides, forKey: "shortcutOverrides")
        try container.encode(self.trailingTags, forKey: "trailingTags")
        try container.encode(self.collapseMiddleTags, forKey: "collapseMiddleTags")
        try container.encode(self.hideProfilePhotos, forKey: "hideProfilePhotos")
        try container.encode(self.hideKeyboardOnSwitch, forKey: "hideKeyboardOnSwitch")
        try container.encode(self.swipeToNextChat, forKey: "swipeToNextChat")
        try container.encode(self.hideChatsWithoutIncomingMessages, forKey: "hideChatsWithoutIncomingMessages")
    }
}

public func updateSupportSettingsInteractively(engine: TelegramEngine, _ f: @escaping (SupportSettings) -> SupportSettings) -> Signal<Never, NoError> {
    return engine.preferences.update(id: PreferencesKeys.supportSettings, { entry in
        return PreferencesEntry(f(entry?.get(SupportSettings.self) ?? .default))
    })
}

func supportSettingsSignal(postbox: Postbox) -> Signal<SupportSettings, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.supportSettings])
    |> map { view -> SupportSettings in
        return view.values[PreferencesKeys.supportSettings]?.get(SupportSettings.self) ?? .default
    }
}

func supportSettings(transaction: Transaction) -> SupportSettings {
    return transaction.getPreferencesEntry(key: PreferencesKeys.supportSettings)?.get(SupportSettings.self) ?? .default
}

func supportSendsAllSilently(transaction: Transaction, accountPeerId: PeerId) -> Bool {
    guard supportSettings(transaction: transaction).sendAllSilently, let user = transaction.getPeer(accountPeerId) as? TelegramUser else {
        return false
    }
    return isSupportAccountPhone(user.phone)
}

func supportSilentMessageAttributes(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    if attributes.contains(where: { ($0 as? NotificationInfoMessageAttribute)?.flags.contains(.muted) == true }) {
        return attributes
    }
    return attributes + [NotificationInfoMessageAttribute(flags: .muted)]
}
