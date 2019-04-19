import Foundation
import Postbox
import SwiftSignalKit

struct ChatArchiveSettings: Equatable, PreferencesEntry {
    var isHiddenByDefault: Bool
    
    static var `default`: ChatArchiveSettings {
        return ChatArchiveSettings(isHiddenByDefault: true)
    }
    
    init(isHiddenByDefault: Bool) {
        self.isHiddenByDefault = isHiddenByDefault
    }
    
    init(decoder: PostboxDecoder) {
        self.isHiddenByDefault = decoder.decodeInt32ForKey("isHiddenByDefault", orElse: 1) != 0
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.isHiddenByDefault ? 1 : 0, forKey: "isHiddenByDefault")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatArchiveSettings {
            return self == to
        } else {
            return false
        }
    }
}

func updateChatArchiveSettings(transaction: Transaction, _ f: @escaping (ChatArchiveSettings) -> ChatArchiveSettings) {
    transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.chatArchiveSettings, { entry in
        let currentSettings: ChatArchiveSettings
        if let entry = entry as? ChatArchiveSettings {
            currentSettings = entry
        } else {
            currentSettings = .default
        }
        return f(currentSettings)
    })
}
