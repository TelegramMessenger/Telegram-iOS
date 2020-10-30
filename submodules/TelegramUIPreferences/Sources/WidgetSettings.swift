
import Foundation
import Postbox
import SwiftSignalKit

public struct WidgetSettings: PreferencesEntry, Equatable {
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
    
    public init(decoder: PostboxDecoder) {
        self.useHints = decoder.decodeBoolForKey("useHints", orElse: true)
        self.peers = decoder.decodeInt64ArrayForKey("peers").map { PeerId($0) }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBool(self.useHints, forKey: "useHints")
        encoder.encodeInt64Array(self.peers.map { $0.toInt64() }, forKey: "peers")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? WidgetSettings {
            return self == to
        } else {
            return false
        }
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
        if let entry = entry as? WidgetSettings {
            currentSettings = entry
        } else {
            currentSettings = .default
        }
        return f(currentSettings)
    })
}
