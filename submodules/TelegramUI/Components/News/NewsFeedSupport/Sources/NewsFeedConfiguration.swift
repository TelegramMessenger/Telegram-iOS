import Foundation
import TelegramCore

public let newsFeedEnabledAppConfigurationKey = "news_feed_enabled"

/// Whether the server's feed (`feed.getFeed`, `feed.getForYou`) is available to this account: for dev accounts only
/// (the app config's `dev` is 1, as other dev-only features are gated), and then unless the kill switch
/// `news_feed_enabled` is false or 0. A missing or unparseable kill switch means on.
public func isNewsFeedServerAvailable(appConfiguration: AppConfiguration) -> Bool {
    guard let data = appConfiguration.data, let isDev = data["dev"] as? Double, isDev == 1.0 else {
        return false
    }
    return isNewsFeedEnabled(appConfiguration: appConfiguration)
}

/// Whether the News tab is shown: unless the kill switch `news_feed_enabled` is false or 0. Without the server's
/// feed the Added page is built on the device from the subscribed channels' posts (`AddedFeedSource.localChannels`).
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
