import Foundation
import Postbox
import SwiftSignalKit

public struct CallListSettings: PreferencesEntry, Equatable {
    public var showTab: Bool
    
    public static var defaultSettings: CallListSettings {
        return CallListSettings(showTab: false)
    }
    
    public init(showTab: Bool) {
        self.showTab = showTab
    }
    
    public init(decoder: PostboxDecoder) {
        self.showTab = decoder.decodeInt32ForKey("showTab", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.showTab ? 1 : 0, forKey: "showTab")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? CallListSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: CallListSettings, rhs: CallListSettings) -> Bool {
        return lhs.showTab == rhs.showTab
    }
    
    public func withUpdatedShowTab(_ showTab: Bool) -> CallListSettings {
        return CallListSettings(showTab: showTab)
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
