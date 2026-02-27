import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct WebBrowserException: Codable, Equatable {
    public let domain: String
    public let title: String
    public let icon: TelegramMediaImage?
    
    public init(domain: String, title: String, icon: TelegramMediaImage?) {
        self.domain = domain
        self.title = title
        self.icon = icon
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.domain = try container.decode(String.self, forKey: "domain")
        self.title = try container.decode(String.self, forKey: "title")
        self.icon = try container.decodeIfPresent(TelegramMediaImage.self, forKey: "icon")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.domain, forKey: "domain")
        try container.encode(self.title, forKey: "title")
        if let icon = self.icon {
            try container.encode(icon, forKey: "icon")
        } else {
            try container.encodeNil(forKey: "icon")
        }
    }
}

public struct WebBrowserSettings: Codable, Equatable {
    public let defaultWebBrowser: String?
    public let exceptions: [WebBrowserException]
    
    public static var defaultSettings: WebBrowserSettings {
        return WebBrowserSettings(defaultWebBrowser: nil, exceptions: [])
    }
    
    public init(defaultWebBrowser: String?, exceptions: [WebBrowserException]) {
        self.defaultWebBrowser = defaultWebBrowser
        self.exceptions = exceptions
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.defaultWebBrowser = try? container.decodeIfPresent(String.self, forKey: "defaultWebBrowser")
        self.exceptions = (try? container.decodeIfPresent([WebBrowserException].self, forKey: "exceptions")) ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.defaultWebBrowser, forKey: "defaultWebBrowser")
        try container.encode(self.exceptions, forKey: "exceptions")
    }
    
    public static func ==(lhs: WebBrowserSettings, rhs: WebBrowserSettings) -> Bool {
        if lhs.defaultWebBrowser != rhs.defaultWebBrowser {
            return false
        }
        if lhs.exceptions != rhs.exceptions {
            return false
        }
        return true
    }
    
    public func withUpdatedDefaultWebBrowser(_ defaultWebBrowser: String?) -> WebBrowserSettings {
        return WebBrowserSettings(defaultWebBrowser: defaultWebBrowser, exceptions: self.exceptions)
    }
        
    public func withUpdatedExceptions(_ exceptions: [WebBrowserException]) -> WebBrowserSettings {
        return WebBrowserSettings(defaultWebBrowser: self.defaultWebBrowser, exceptions: exceptions)
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
