import Foundation
import Postbox
import SwiftSignalKit

public struct ChatListFilterSettings: Equatable, PreferencesEntry {
    public static var `default`: ChatListFilterSettings {
        return ChatListFilterSettings()
    }
    
    public init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatListFilterSettings {
            return self == to
        } else {
            return false
        }
    }
}

public func updateChatListFilterSettings(transaction: Transaction, _ f: @escaping (ChatListFilterSettings) -> ChatListFilterSettings) {
    transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.chatListFilterSettings, { entry in
        let currentSettings: ChatListFilterSettings
        if let entry = entry as? ChatListFilterSettings {
            currentSettings = entry
        } else {
            currentSettings = .default
        }
        return f(currentSettings)
    })
}
