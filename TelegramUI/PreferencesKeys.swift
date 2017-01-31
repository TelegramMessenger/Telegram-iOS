import Foundation
import TelegramCore

private enum ApplicationSpecificPreferencesKeyValues: Int32 {
    case inAppNotificationSettings
}

struct ApplicationSpecificPreferencesKeys {
    static let inAppNotificationSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.inAppNotificationSettings.rawValue)
}
