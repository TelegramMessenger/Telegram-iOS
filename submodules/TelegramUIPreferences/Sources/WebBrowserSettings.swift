import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct WebBrowserSettings: Codable, Equatable {
    public let defaultWebBrowser: String?
    
    public static var defaultSettings: WebBrowserSettings {
        return WebBrowserSettings(defaultWebBrowser: nil)
    }
    
    public init(defaultWebBrowser: String?) {
        self.defaultWebBrowser = defaultWebBrowser
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.defaultWebBrowser = try? container.decodeIfPresent(String.self, forKey: "defaultWebBrowser")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.defaultWebBrowser, forKey: "defaultWebBrowser")
    }
    
    public static func ==(lhs: WebBrowserSettings, rhs: WebBrowserSettings) -> Bool {
        return lhs.defaultWebBrowser == rhs.defaultWebBrowser
    }
    
    public func withUpdatedDefaultWebBrowser(_ defaultWebBrowser: String?) -> WebBrowserSettings {
        return WebBrowserSettings(defaultWebBrowser: defaultWebBrowser)
    }
}

public func updateWebBrowserSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (WebBrowserSettings) -> WebBrowserSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.webBrowserSettings, { entry in
            let currentSettings: WebBrowserSettings
            if let entry = entry?.get(WebBrowserSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = WebBrowserSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
