import Foundation
import TelegramCore

public let newsFeedEnabledAppConfigurationKey = "news_feed_enabled"

/// The News kill switch: enabled unless the app config sets `news_feed_enabled` to false or 0. A missing
/// or unparseable value means enabled.
public func isNewsFeedEnabled(appConfiguration: AppConfiguration) -> Bool {
    guard let data = appConfiguration.data, let value = data[newsFeedEnabledAppConfigurationKey] else {
        return true
    }
    if let value = value as? Bool {
        return value
    }
    if let value = value as? Double {
        return value != 0.0
    }
    return true
}
