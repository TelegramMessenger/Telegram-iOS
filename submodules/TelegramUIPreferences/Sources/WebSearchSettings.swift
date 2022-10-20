import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum WebSearchScope: Int32 {
    case images
    case gifs
}

public struct WebSearchSettings: Codable, Equatable {
    public var scope: WebSearchScope
    
    public static var defaultSettings: WebSearchSettings {
        return WebSearchSettings(scope: .images)
    }
    
    public init(scope: WebSearchScope) {
        self.scope = scope
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.scope = WebSearchScope(rawValue: try container.decode(Int32.self, forKey: "scope")) ?? .images
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.scope.rawValue, forKey: "scope")
    }
}

public func updateWebSearchSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (WebSearchSettings) -> WebSearchSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.webSearchSettings, { entry in
            let currentSettings: WebSearchSettings
            if let entry = entry?.get(WebSearchSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = .defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
