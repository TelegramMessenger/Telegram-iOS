import Foundation
import Postbox
import SwiftSignalKit

public enum SupportSwitchBehavior: Int32 {
    case none = 0
    case next = 1
    case previous = 2
}

public struct SupportSettings: Codable, Equatable {
    public static let allChatsLoadPeriod: Int32 = 0

    public static var `default`: SupportSettings {
        return SupportSettings(switchBehavior: .next, fixChatsOrder: true, chatLoadPeriod: 7 * 24 * 60 * 60, sendAllSilently: false)
    }

    public var switchBehavior: SupportSwitchBehavior
    public var fixChatsOrder: Bool
    public var chatLoadPeriod: Int32
    public var sendAllSilently: Bool
    public var hideKeyboardOnSwitch: Bool = true

    public init(switchBehavior: SupportSwitchBehavior, fixChatsOrder: Bool, chatLoadPeriod: Int32, sendAllSilently: Bool) {
        self.switchBehavior = switchBehavior
        self.fixChatsOrder = fixChatsOrder
        self.chatLoadPeriod = chatLoadPeriod
        self.sendAllSilently = sendAllSilently
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        let defaults = SupportSettings.default

        self.switchBehavior = (try container.decodeIfPresent(Int32.self, forKey: "switchBehavior")).flatMap(SupportSwitchBehavior.init(rawValue:)) ?? defaults.switchBehavior
        self.fixChatsOrder = try container.decodeIfPresent(Bool.self, forKey: "fixChatsOrder") ?? defaults.fixChatsOrder
        self.chatLoadPeriod = try container.decodeIfPresent(Int32.self, forKey: "chatLoadPeriod") ?? defaults.chatLoadPeriod
        self.sendAllSilently = try container.decodeIfPresent(Bool.self, forKey: "sendAllSilently") ?? defaults.sendAllSilently
        self.hideKeyboardOnSwitch = try container.decodeIfPresent(Bool.self, forKey: "hideKeyboardOnSwitch") ?? defaults.hideKeyboardOnSwitch
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.switchBehavior.rawValue, forKey: "switchBehavior")
        try container.encode(self.fixChatsOrder, forKey: "fixChatsOrder")
        try container.encode(self.chatLoadPeriod, forKey: "chatLoadPeriod")
        try container.encode(self.sendAllSilently, forKey: "sendAllSilently")
        try container.encode(self.hideKeyboardOnSwitch, forKey: "hideKeyboardOnSwitch")
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
