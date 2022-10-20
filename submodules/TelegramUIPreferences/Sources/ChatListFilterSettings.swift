import Foundation
import Postbox
import SwiftSignalKit

public struct ChatListFilterSettings: Equatable, Codable {
    public static var `default`: ChatListFilterSettings {
        return ChatListFilterSettings()
    }
    
    public init() {
    }
    
    public init(from decoder: Decoder) throws {
    }
    
    public func encode(to encoder: Encoder) throws {
    }
}

public func updateChatListFilterSettings(transaction: Transaction, _ f: @escaping (ChatListFilterSettings) -> ChatListFilterSettings) {
    transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.chatListFilterSettings, { entry in
        let currentSettings: ChatListFilterSettings
        if let entry = entry?.get(ChatListFilterSettings.self) {
            currentSettings = entry
        } else {
            currentSettings = .default
        }
        return PreferencesEntry(f(currentSettings))
    })
}
