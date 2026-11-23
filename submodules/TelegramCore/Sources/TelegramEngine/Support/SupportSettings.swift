import Foundation
import Postbox
import SwiftSignalKit

public struct SupportSettings: Codable, Equatable {

    public static var `default`: SupportSettings {
        return SupportSettings(sendAllSilently: false)
    }

    public var sendAllSilently: Bool

    public init(sendAllSilently: Bool) {
        self.sendAllSilently = sendAllSilently
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        let defaults = SupportSettings.default

        self.sendAllSilently = try container.decodeIfPresent(Bool.self, forKey: "sendAllSilently") ?? defaults.sendAllSilently
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.sendAllSilently, forKey: "sendAllSilently")
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
