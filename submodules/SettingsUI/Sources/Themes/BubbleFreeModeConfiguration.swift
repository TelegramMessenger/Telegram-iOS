import Foundation
import TelegramCore

let bubbleFreeModeAppConfigurationKey = "ios_bubble_free_mode"

/// Whether the bubble-free mode's settings (Appearance's Bubble Mode switch, Text Size's New York choice) are offered to
/// this account: to dev accounts (the app config's `dev` is 1), and to any account the server turns them on for with
/// `ios_bubble_free_mode` true or nonzero (missing or unparseable means off).
func isBubbleFreeModeAvailable(appConfiguration: AppConfiguration) -> Bool {
    guard let data = appConfiguration.data else {
        return false
    }
    if let isDev = data["dev"] as? Double, isDev == 1.0 {
        return true
    }
    if let value = data[bubbleFreeModeAppConfigurationKey] as? Bool {
        return value
    }
    if let value = data[bubbleFreeModeAppConfigurationKey] as? Double {
        return value != 0.0
    }
    return false
}

/// Whether one of the bubble-free mode's settings is shown: where the mode is available, and wherever the setting is
/// already in use (bubbles off, New York chosen), so that it can be turned back.
func showsBubbleFreeModeSetting(isBubbleFreeModeAvailable: Bool, isInUse: Bool) -> Bool {
    return isBubbleFreeModeAvailable || isInUse
}
