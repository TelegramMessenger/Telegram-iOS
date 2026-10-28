import Foundation
import TelegramUIPreferences

public let sharedMediaGridV2KillswitchKey = "ios_killswitch_disable_shared_media_grid_v2"

public func sharedMediaGridV2Enabled(legacyOverride: Bool, killswitchPresent: Bool) -> Bool {
    return !legacyOverride && !killswitchPresent
}

public extension AccountContext {
    var usesSharedMediaGridV2: Bool {
        return sharedMediaGridV2Enabled(
            legacyOverride: self.sharedContext.immediateExperimentalUISettings.sharedMediaGridLegacy,
            killswitchPresent: self.getAppConfigValue(sharedMediaGridV2KillswitchKey) != nil
        )
    }
}
