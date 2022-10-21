import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct QuickReactionSettings: Codable, Equatable {
    public var enableQuickReaction: Bool

    public static var defaultSettings: QuickReactionSettings {
        return QuickReactionSettings(enableQuickReaction: true)
    }

    init(enableQuickReaction: Bool) {
        self.enableQuickReaction = enableQuickReaction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.enableQuickReaction = try container.decodeIfPresent(Bool.self, forKey: "enableQuickReaction") ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.enableQuickReaction, forKey: "enableQuickReaction")
    }
    
    public static func ==(lhs: QuickReactionSettings, rhs: QuickReactionSettings) -> Bool {
        return lhs.enableQuickReaction == rhs.enableQuickReaction
    }

    public func withUpdatedQuickReactions(_ enableQuickReaction: Bool) -> QuickReactionSettings {
        return QuickReactionSettings(enableQuickReaction: enableQuickReaction)
    }
}

public func updateQuickReactionSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (QuickReactionSettings) -> QuickReactionSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.quickReactionSettings, { entry in
            let currentSettings: QuickReactionSettings
            if let entry = entry?.get(QuickReactionSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = QuickReactionSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
