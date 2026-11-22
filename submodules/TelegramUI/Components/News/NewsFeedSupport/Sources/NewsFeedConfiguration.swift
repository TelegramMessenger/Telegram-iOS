import Foundation
import TelegramCore

public let newsFeedEnabledAppConfigurationKey = "news_feed_enabled"

/// The app config's `dev` is 1: dev-only features are gated on it.
private func isDevAccount(appConfiguration: AppConfiguration) -> Bool {
    guard let data = appConfiguration.data, let isDev = data["dev"] as? Double else {
        return false
    }
    return isDev == 1.0
}

/// The switch `news_feed_enabled` as the server sent it: a bool, or a number (0 is off); nil when it is missing or of
/// another type.
private func newsFeedSwitch(appConfiguration: AppConfiguration) -> Bool? {
    guard let data = appConfiguration.data, let value = data[newsFeedEnabledAppConfigurationKey] else {
        return nil
    }
    if let value = value as? Bool {
        return value
    }
    if let value = value as? Double {
        return value != 0.0
    }
    return nil
}

/// Whether the server's feed (`feed.getFeed`, `feed.getForYou`) is available to this account. Never while the feed API
/// is parked (`newsFeedApiIsAvailable`); then for dev accounts only, unless `news_feed_enabled` is false or 0 (a kill
/// switch there: missing or unparseable means on). `apiIsAvailable` is a parameter only so tests can pin the
/// app-config rule in either build.
public func isNewsFeedServerAvailable(appConfiguration: AppConfiguration, apiIsAvailable: Bool = newsFeedApiIsAvailable) -> Bool {
    guard apiIsAvailable else {
        return false
    }
    return isDevAccount(appConfiguration: appConfiguration) && newsFeedSwitch(appConfiguration: appConfiguration) != false
}

/// Whether News is shown (the tab, Add to News). Never while the feed API is parked (`newsFeedApiIsAvailable`), the
/// device-built Added feed included; then for dev accounts, and for any account the server turns it on for with
/// `news_feed_enabled` true or nonzero (missing or unparseable means off). Without the server's feed the Added page is
/// built on the device from the subscribed channels' posts (`AddedFeedSource.localChannels`). `apiIsAvailable` is a
/// parameter only so tests can pin the app-config rule in either build.
public func isNewsFeedEnabled(appConfiguration: AppConfiguration, apiIsAvailable: Bool = newsFeedApiIsAvailable) -> Bool {
    guard apiIsAvailable else {
        return false
    }
    return isDevAccount(appConfiguration: appConfiguration) || newsFeedSwitch(appConfiguration: appConfiguration) == true
}
