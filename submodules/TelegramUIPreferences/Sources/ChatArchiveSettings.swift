import Foundation
import Postbox
import SwiftSignalKit

public struct ChatArchiveSettings: Equatable, PreferencesEntry {
    public var isHiddenByDefault: Bool
    
    public static var `default`: ChatArchiveSettings {
        return ChatArchiveSettings(isHiddenByDefault: false)
    }
    
    public init(isHiddenByDefault: Bool) {
        self.isHiddenByDefault = isHiddenByDefault
    }
    
    public init(decoder: PostboxDecoder) {
        self.isHiddenByDefault = decoder.decodeInt32ForKey("isHiddenByDefault", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.isHiddenByDefault ? 1 : 0, forKey: "isHiddenByDefault")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatArchiveSettings {
            return self == to
        } else {
            return false
        }
    }
}

public func updateChatArchiveSettings(transaction: Transaction, _ f: @escaping (ChatArchiveSettings) -> ChatArchiveSettings) {
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
