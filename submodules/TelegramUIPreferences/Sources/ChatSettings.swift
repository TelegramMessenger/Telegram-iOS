import Foundation
import TelegramCore
import SwiftSignalKit

public struct ChatSettings: Codable, Equatable {
    public let sendWithCmdEnter: Bool
    
    public static var defaultSettings: ChatSettings {
        return ChatSettings(sendWithCmdEnter: false)
    }
    
    public init(sendWithCmdEnter: Bool) {
        self.sendWithCmdEnter = sendWithCmdEnter
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.sendWithCmdEnter = (try container.decode(Int32.self, forKey: "sendWithCmdEnter")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.sendWithCmdEnter ? 1 : 0) as Int32, forKey: "sendWithCmdEnter")
    }
    
    public static func ==(lhs: ChatSettings, rhs: ChatSettings) -> Bool {
        return lhs.sendWithCmdEnter == rhs.sendWithCmdEnter
    }
    
    public func withUpdatedSendWithCmdEnter(_ sendWithCmdEnter: Bool) -> ChatSettings {
        return ChatSettings(sendWithCmdEnter: sendWithCmdEnter)
    }
}

public func updateChatSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (ChatSettings) -> ChatSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.chatSettings, { entry in
            let currentSettings: ChatSettings
            if let entry = entry?.get(ChatSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = ChatSettings.defaultSettings
            }
            return SharedPreferencesEntry(f(currentSettings))
        })
    }
}
