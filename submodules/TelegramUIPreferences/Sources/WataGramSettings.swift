import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox

public struct WataGramSettings: Codable, Equatable {
    // Ghost Mode toggles
    public var ghostModeReadReceipts: Bool
    public var ghostModeTypingIndicator: Bool
    public var ghostModeOnlineStatus: Bool
    public var ghostModeStorySeen: Bool

    public static var defaultSettings: WataGramSettings {
        return WataGramSettings(
            ghostModeReadReceipts: false,
            ghostModeTypingIndicator: false,
            ghostModeOnlineStatus: false,
            ghostModeStorySeen: false
        )
    }

    public init(
        ghostModeReadReceipts: Bool,
        ghostModeTypingIndicator: Bool,
        ghostModeOnlineStatus: Bool,
        ghostModeStorySeen: Bool
    ) {
        self.ghostModeReadReceipts = ghostModeReadReceipts
        self.ghostModeTypingIndicator = ghostModeTypingIndicator
        self.ghostModeOnlineStatus = ghostModeOnlineStatus
        self.ghostModeStorySeen = ghostModeStorySeen
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.ghostModeReadReceipts = try container.decodeIfPresent(Bool.self, forKey: "ghostModeReadReceipts") ?? false
        self.ghostModeTypingIndicator = try container.decodeIfPresent(Bool.self, forKey: "ghostModeTypingIndicator") ?? false
        self.ghostModeOnlineStatus = try container.decodeIfPresent(Bool.self, forKey: "ghostModeOnlineStatus") ?? false
        self.ghostModeStorySeen = try container.decodeIfPresent(Bool.self, forKey: "ghostModeStorySeen") ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.ghostModeReadReceipts, forKey: "ghostModeReadReceipts")
        try container.encode(self.ghostModeTypingIndicator, forKey: "ghostModeTypingIndicator")
        try container.encode(self.ghostModeOnlineStatus, forKey: "ghostModeOnlineStatus")
        try container.encode(self.ghostModeStorySeen, forKey: "ghostModeStorySeen")
    }

    /// Convenience: any ghost-mode flag enabled.
    public var isAnyGhostModeEnabled: Bool {
        return self.ghostModeReadReceipts
            || self.ghostModeTypingIndicator
            || self.ghostModeOnlineStatus
            || self.ghostModeStorySeen
    }
}

public func updateWataGramSettingsInteractively(
    accountManager: AccountManager<TelegramAccountManagerTypes>,
    _ f: @escaping (WataGramSettings) -> WataGramSettings
) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.wataGramSettings, { entry in
            let currentSettings: WataGramSettings
            if let entry = entry?.get(WataGramSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = .defaultSettings
            }
            return SharedPreferencesEntry(f(currentSettings))
        })
    }
}
