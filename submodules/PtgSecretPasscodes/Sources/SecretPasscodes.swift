import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import SwiftSignalKit

public struct PtgSecretChatId: Codable, Hashable {
    public let accountRecordId: AccountRecordId
    public let peerId: PeerId
    
    public init(accountRecordId: AccountRecordId, peerId: PeerId) {
        self.accountRecordId = accountRecordId
        self.peerId = peerId
    }
}

public struct PtgSecretPasscode: Codable, Equatable {
    public let passcode: String
    public let active: Bool
    public let timeout: Int32?
    public let secretChats: Set<PtgSecretChatId>
    
    public init(passcode: String, active: Bool, timeout: Int32?, secretChats: Set<PtgSecretChatId>) {
        self.passcode = passcode
        self.active = active
        self.timeout = timeout
        self.secretChats = secretChats
    }
    
    public init(passcode: String) {
        self.passcode = passcode
        self.active = false
        self.timeout = 5 * 60
        self.secretChats = []
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.passcode = try container.decode(String.self, forKey: "p")
        self.active = try container.decode(Int32.self, forKey: "a") != 0
        self.timeout = try container.decodeIfPresent(Int32.self, forKey: "t")
        self.secretChats = try container.decodeIfPresent(Set<PtgSecretChatId>.self, forKey: "sc") ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.passcode, forKey: "p")
        try container.encode((self.active ? 1 : 0) as Int32, forKey: "a")
        try container.encodeIfPresent(self.timeout, forKey: "t")
        try container.encodeIfPresent(self.secretChats, forKey: "sc")
    }
    
    public func withUpdated(passcode: String) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: passcode, active: self.active, timeout: self.timeout, secretChats: self.secretChats)
    }
    
    public func withUpdated(active: Bool) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: self.passcode, active: active, timeout: self.timeout, secretChats: self.secretChats)
    }
    
    public func withUpdated(timeout: Int32?) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: self.passcode, active: self.active, timeout: timeout, secretChats: self.secretChats)
    }
    
    public func withUpdated(secretChats: Set<PtgSecretChatId>) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: self.passcode, active: self.active, timeout: self.timeout, secretChats: secretChats)
    }
}

public struct PtgSecretPasscodes: Codable, Equatable {
    public let secretPasscodes: [PtgSecretPasscode]
    
    public static var defaultSettings: PtgSecretPasscodes {
        return PtgSecretPasscodes(secretPasscodes: [])
    }
    
    public init(secretPasscodes: [PtgSecretPasscode]) {
        self.secretPasscodes = secretPasscodes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.secretPasscodes = try container.decode([PtgSecretPasscode].self, forKey: "spc")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.secretPasscodes, forKey: "spc")
    }
    
    public init(_ entry: PreferencesEntry?) {
        self = entry?.get(PtgSecretPasscodes.self) ?? .defaultSettings
    }
    
    public init(_ transaction: AccountManagerModifier<TelegramAccountManagerTypes>) {
        let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.ptgSecretPasscodes)
        self.init(entry)
    }
    
    public func inactiveSecretChatPeerIds(for account: Account) -> Set<PeerId> {
        var result = Set<PeerId>()
        for secretPasscode in self.secretPasscodes {
            if !secretPasscode.active {
                for secretChat in secretPasscode.secretChats {
                    if secretChat.accountRecordId == account.id {
                        result.insert(secretChat.peerId)
                    }
                }
            }
        }
        return result
    }
}

public func updatePtgSecretPasscodes(_ accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (PtgSecretPasscodes) -> PtgSecretPasscodes) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.ptgSecretPasscodes, { current in
            let updated = f(PtgSecretPasscodes(current))
            return PreferencesEntry(updated)
        })
    }
}
