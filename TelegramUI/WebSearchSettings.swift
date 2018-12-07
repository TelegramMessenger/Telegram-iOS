import Foundation
import Postbox
import SwiftSignalKit

struct WebSearchSettings: Equatable, PreferencesEntry {
    var mode: WebSearchMode
    
    static var defaultSettings: WebSearchSettings {
        return WebSearchSettings(mode: .images)
    }
    
    init(mode: WebSearchMode) {
        self.mode = mode
    }
    
    init(decoder: PostboxDecoder) {
        self.mode = WebSearchMode(rawValue: decoder.decodeInt32ForKey("mode", orElse: 0)) ?? .images
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.mode.rawValue, forKey: "mode")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? WebSearchSettings {
            return self == to
        } else {
            return false
        }
    }
}

func updateWebSearchSettingsInteractively(postbox: Postbox, _ f: @escaping (WebSearchSettings) -> WebSearchSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.webSearchSettings, { entry in
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
