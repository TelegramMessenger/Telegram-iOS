import Foundation
import Postbox
import SwiftSignalKit

public enum WebSearchScope: Int32 {
    case images
    case gifs
}

public struct WebSearchSettings: Equatable, PreferencesEntry {
    public var scope: WebSearchScope
    
    public static var defaultSettings: WebSearchSettings {
        return WebSearchSettings(scope: .images)
    }
    
    public init(scope: WebSearchScope) {
        self.scope = scope
    }
    
    public init(decoder: PostboxDecoder) {
        self.scope = WebSearchScope(rawValue: decoder.decodeInt32ForKey("scope", orElse: 0)) ?? .images
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.scope.rawValue, forKey: "scope")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? WebSearchSettings {
            return self == to
        } else {
            return false
        }
    }
}

public func updateWebSearchSettingsInteractively(accountManager: AccountManager, _ f: @escaping (WebSearchSettings) -> WebSearchSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.webSearchSettings, { entry in
            let currentSettings: WebSearchSettings
            if let entry = entry as? WebSearchSettings {
                currentSettings = entry
            } else {
                currentSettings = .defaultSettings
            }
            return f(currentSettings)
        })
    }
}
