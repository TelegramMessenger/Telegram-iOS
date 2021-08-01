import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public struct ContentSettings: Equatable {
    public static var `default` = ContentSettings(ignoreContentRestrictionReasons: [])
    
    public var ignoreContentRestrictionReasons: Set<String>
    
    public init(ignoreContentRestrictionReasons: Set<String>) {
        self.ignoreContentRestrictionReasons = ignoreContentRestrictionReasons
    }
}

private extension ContentSettings {
    init(appConfiguration: AppConfiguration) {
        var reasons: [String] = []
        if let data = appConfiguration.data, let reasonsData = data["ignore_restriction_reasons"] as? [String] {
            reasons = reasonsData
        }
        self.init(ignoreContentRestrictionReasons: Set(reasons))
    }
}

public func getContentSettings(transaction: Transaction) -> ContentSettings {
    let appConfiguration: AppConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration) as? AppConfiguration ?? AppConfiguration.defaultValue
    return ContentSettings(appConfiguration: appConfiguration)
}

public func getContentSettings(postbox: Postbox) -> Signal<ContentSettings, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
    |> map { view -> ContentSettings in
        let appConfiguration: AppConfiguration = view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? AppConfiguration.defaultValue
        return ContentSettings(appConfiguration: appConfiguration)
    }
    |> distinctUntilChanged
}

public struct ContentSettingsConfiguration: Equatable {
    public static var `default` = ContentSettingsConfiguration(sensitiveContentEnabled: false, canAdjustSensitiveContent: false)
    
    public var sensitiveContentEnabled: Bool
    public var canAdjustSensitiveContent: Bool
    
    public init(sensitiveContentEnabled: Bool, canAdjustSensitiveContent: Bool) {
        self.sensitiveContentEnabled = sensitiveContentEnabled
        self.canAdjustSensitiveContent = canAdjustSensitiveContent
    }
}

public func contentSettingsConfiguration(network: Network) -> Signal<ContentSettingsConfiguration, NoError> {
    return network.request(Api.functions.account.getContentSettings())
    |> map { result -> ContentSettingsConfiguration in
        switch result {
        case let .contentSettings(flags):
            return ContentSettingsConfiguration(sensitiveContentEnabled: (flags & (1 << 0)) != 0, canAdjustSensitiveContent: (flags & (1 << 1)) != 0)
        }
    }
    |> `catch` { _ -> Signal<ContentSettingsConfiguration, NoError> in
        return .single(.default)
    }
}

public func updateRemoteContentSettingsConfiguration(postbox: Postbox, network: Network, sensitiveContentEnabled: Bool) -> Signal<Never, NoError> {
    var flags: Int32 = 0
    if sensitiveContentEnabled {
        flags |= 1 << 0
    }
    return network.request(Api.functions.account.setContentSettings(flags: flags))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> mapToSignal { _ -> Signal<Never, NoError> in
        return updateAppConfigurationOnce(postbox: postbox, network: network)
        |> ignoreValues
    }
}
