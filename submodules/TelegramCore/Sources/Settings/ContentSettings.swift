import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public struct ContentSettings: Equatable {
    public static var `default` = ContentSettings(ignoreContentRestrictionReasons: [], addContentRestrictionReasons: [], ignoreAllContentRestrictions: false)
    
    public var ignoreContentRestrictionReasons: Set<String>
    public var addContentRestrictionReasons: [String]
    public let ignoreAllContentRestrictions: Bool
    
    public init(ignoreContentRestrictionReasons: Set<String>, addContentRestrictionReasons: [String], ignoreAllContentRestrictions: Bool) {
        self.ignoreContentRestrictionReasons = ignoreContentRestrictionReasons
        self.addContentRestrictionReasons = addContentRestrictionReasons
        self.ignoreAllContentRestrictions = ignoreAllContentRestrictions
    }
}

extension ContentSettings {
    init(appConfiguration: AppConfiguration, ignoreAllContentRestrictions: Bool = false) {
        var reasons: [String] = []
        var addContentRestrictionReasons: [String] = []
        if let data = appConfiguration.data {
            if let reasonsData = data["ignore_restriction_reasons"] as? [String] {
                reasons = reasonsData
            }
            if let addContentRestrictionReasonsData = data["restriction_add_platforms"] as? [String] {
                addContentRestrictionReasons = addContentRestrictionReasonsData
            }
        }
        self.init(ignoreContentRestrictionReasons: Set(reasons), addContentRestrictionReasons: addContentRestrictionReasons, ignoreAllContentRestrictions: ignoreAllContentRestrictions)
    }
}

public func getContentSettings(transaction: Transaction) -> ContentSettings {
    let appConfiguration: AppConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
    return ContentSettings(appConfiguration: appConfiguration)
}

public func getContentSettings(postbox: Postbox, ignoreAllContentRestrictions: Signal<Bool, NoError>) -> Signal<ContentSettings, NoError> {
    return combineLatest(postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]), ignoreAllContentRestrictions)
    |> map { view, ignoreAllContentRestrictions -> ContentSettings in
        let appConfiguration: AppConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
        return ContentSettings(appConfiguration: appConfiguration, ignoreAllContentRestrictions: ignoreAllContentRestrictions)
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
