import Foundation
import Postbox
import SwiftSignalKit

public struct ChatListFilterSettings: Equatable, PreferencesEntry {
    public var displayTabs: Bool
    
    public static var `default`: ChatListFilterSettings {
        return ChatListFilterSettings(displayTabs: true)
    }
    
    public init(displayTabs: Bool) {
        self.displayTabs = displayTabs
    }
    
    public init(decoder: PostboxDecoder) {
        self.displayTabs = decoder.decodeInt32ForKey("displayTabs", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.displayTabs ? 1 : 0, forKey: "displayTabs")
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
