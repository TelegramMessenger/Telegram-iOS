import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct WidgetSettings: Codable, Equatable {
    public var useHints: Bool
    public var peers: [PeerId]
    
    public static var `default`: WidgetSettings {
        return WidgetSettings(
            useHints: true,
            peers: []
        )
    }
    
    public init(
        useHints: Bool,
        peers: [PeerId]
    ) {
        self.useHints = useHints
        self.peers = peers
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.useHints = try container.decode(Bool.self, forKey: "useHints")
        self.peers = (try container.decode([Int64].self, forKey: "peers")).map { PeerId($0) }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.useHints, forKey: "useHints")
        try container.encode(self.peers.map { $0.toInt64() } as [Int64], forKey: "peers")
    }
}

public func updateWidgetSettingsInteractively(postbox: Postbox, _ f: @escaping (WidgetSettings) -> WidgetSettings) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        updateWidgetSettingsInteractively(transaction: transaction, f)
    }
    |> ignoreValues
}

public func updateWidgetSettingsInteractively(transaction: Transaction, _ f: @escaping (WidgetSettings) -> WidgetSettings) {
    transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.widgetSettings, { entry in
        let currentSettings: WidgetSettings
        if let entry = entry?.get(WidgetSettings.self) {
            currentSettings = entry
        } else {
            currentSettings = .default
        }
        return PreferencesEntry(f(currentSettings))
    })
}
