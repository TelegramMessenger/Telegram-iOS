import Foundation
import Postbox
import SwiftSignalKit

public struct CallListSettings: PreferencesEntry, Equatable {
    public var _showTab: Bool?
    public var defaultShowTab: Bool?
    
    public static var defaultSettings: CallListSettings {
        return CallListSettings(showTab: true)
    }
    
    public var showTab: Bool {
        get {
            if let value = self._showTab {
                return value
            } else if let defaultValue = self.defaultShowTab {
                return defaultValue
            } else {
                return CallListSettings.defaultSettings.showTab
            }
        } set {
            self._showTab = newValue
        }
    }
    
    public init(showTab: Bool) {
        self._showTab = showTab
    }
    
    public init(showTab: Bool?, defaultShowTab: Bool?) {
        self._showTab = showTab
        self.defaultShowTab = defaultShowTab
    }
    
    public init(decoder: PostboxDecoder) {
        var defaultValue = CallListSettings.defaultSettings.showTab
        if let alternativeDefaultValue = decoder.decodeOptionalInt32ForKey("defaultShowTab") {
            defaultValue = alternativeDefaultValue != 0
            self.defaultShowTab = alternativeDefaultValue != 0
        }
        if let value = decoder.decodeOptionalInt32ForKey("showTab") {
            self._showTab = value != 0
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let defaultShowTab = self.defaultShowTab {
            encoder.encodeInt32(defaultShowTab ? 1 : 0, forKey: "defaultShowTab")
        } else {
            encoder.encodeNil(forKey: "defaultShowTab")
        }
        if let showTab = self._showTab {
            encoder.encodeInt32(showTab ? 1 : 0, forKey: "showTab")
        } else {
            encoder.encodeNil(forKey: "showTab")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? CallListSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: CallListSettings, rhs: CallListSettings) -> Bool {
        return lhs._showTab == rhs._showTab && lhs.defaultShowTab == rhs.defaultShowTab
    }
    
    public func withUpdatedShowTab(_ showTab: Bool) -> CallListSettings {
        return CallListSettings(showTab: showTab, defaultShowTab: self.defaultShowTab)
    }
}

public func updateCallListSettingsInteractively(accountManager: AccountManager, _ f: @escaping (CallListSettings) -> CallListSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.callListSettings, { entry in
            let currentSettings: CallListSettings
            if let entry = entry as? CallListSettings {
                currentSettings = entry
            } else {
                currentSettings = CallListSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

public func storeCurrentCallListTabDefaultValue(accountManager: AccountManager) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.callListSettings, { entry in
            let currentSettings: CallListSettings
            if let entry = entry as? CallListSettings {
                currentSettings = entry
            } else {
                currentSettings = CallListSettings(showTab: nil, defaultShowTab: CallListSettings.defaultSettings.showTab)
            }
            return currentSettings
        })
    }
}
