import Foundation
import TelegramUIPreferences

public let mediaPickerGridV2KillswitchKey = "ios_killswitch_disable_media_grid_v2"

public func mediaPickerGridV2Enabled(legacyOverride: Bool, killswitchPresent: Bool) -> Bool {
    return !legacyOverride && !killswitchPresent
}

public extension AccountContext {
    var usesMediaPickerGridV2: Bool {
        return mediaPickerGridV2Enabled(
            legacyOverride: self.sharedContext.immediateExperimentalUISettings.mediaGridLegacy,
            killswitchPresent: self.getAppConfigValue(mediaPickerGridV2KillswitchKey) != nil
        )
    }
}
