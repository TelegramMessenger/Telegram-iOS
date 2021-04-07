import Foundation
import Postbox
import SwiftSignalKit

public struct WebBrowserSettings: PreferencesEntry, Equatable {
    public let defaultWebBrowser: String?
    
    public static var defaultSettings: WebBrowserSettings {
        return WebBrowserSettings(defaultWebBrowser: nil)
    }
    
    public init(defaultWebBrowser: String?) {
        self.defaultWebBrowser = defaultWebBrowser
    }
    
    public init(decoder: PostboxDecoder) {
        self.defaultWebBrowser = decoder.decodeOptionalStringForKey("defaultWebBrowser")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let defaultWebBrowser = self.defaultWebBrowser {
            encoder.encodeString(defaultWebBrowser, forKey: "defaultWebBrowser")
        } else {
            encoder.encodeNil(forKey: "defaultWebBrowser")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? WebBrowserSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: WebBrowserSettings, rhs: WebBrowserSettings) -> Bool {
        return lhs.defaultWebBrowser == rhs.defaultWebBrowser
    }
    
    public func withUpdatedDefaultWebBrowser(_ defaultWebBrowser: String?) -> WebBrowserSettings {
        return WebBrowserSettings(defaultWebBrowser: defaultWebBrowser)
    }
}

public func updateWebBrowserSettingsInteractively(accountManager: AccountManager, _ f: @escaping (WebBrowserSettings) -> WebBrowserSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.webBrowserSettings, { entry in
            let currentSettings: WebBrowserSettings
            if let entry = entry as? WebBrowserSettings {
                currentSettings = entry
            } else {
                currentSettings = WebBrowserSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
