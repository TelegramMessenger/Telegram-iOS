import Foundation
import Postbox
import SwiftSignalKit

/// State-sync settings set from Debug Settings. They live in the account's preferences
/// (`PreferencesKeys.stateSyncDebugSettings`), so the transaction that starts a poll can read them, and TelegramCore
/// honours them only in DEBUG builds: a release build never reads them.
public struct StateSyncDebugSettings: Codable, Equatable {
    /// Replaces the app-configuration `pts_total_limit` (`currentPtsTotalLimit`). nil: no override, the app
    /// configuration decides. Below 1: no limit. Otherwise the limit sent; a small value (10) makes a short offline
    /// gap answer `updates.differenceTooLong`, so a test account goes through a real reset on a simulator.
    public var ptsTotalLimitOverride: Int32?

    public static var defaultSettings: StateSyncDebugSettings {
        return StateSyncDebugSettings(ptsTotalLimitOverride: nil)
    }

    public init(ptsTotalLimitOverride: Int32?) {
        self.ptsTotalLimitOverride = ptsTotalLimitOverride
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.ptsTotalLimitOverride = try container.decodeIfPresent(Int32.self, forKey: "ptsTotalLimitOverride")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.ptsTotalLimitOverride, forKey: "ptsTotalLimitOverride")
    }
}

/// Updates `StateSyncDebugSettings` in the account's preferences (Debug Settings).
public func updateStateSyncDebugSettings(engine: TelegramEngine, _ f: @escaping (StateSyncDebugSettings) -> StateSyncDebugSettings) -> Signal<Never, NoError> {
    return engine.preferences.update(id: PreferencesKeys.stateSyncDebugSettings, { entry in
        let current = entry?.get(StateSyncDebugSettings.self) ?? StateSyncDebugSettings.defaultSettings
        return PreferencesEntry(f(current))
    })
}
