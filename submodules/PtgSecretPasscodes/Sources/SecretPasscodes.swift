import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import SwiftSignalKit
import AppLockState
import MonotonicTime

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
    
    public func withUpdated(active: Bool) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: self.passcode, active: active, timeout: self.timeout, secretChats: self.secretChats)
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
    
    public func inactiveSecretChatPeerIds(accountId: AccountRecordId) -> Set<PeerId> {
        var result = Set<PeerId>()
        for secretPasscode in self.secretPasscodes {
            if !secretPasscode.active {
                for secretChat in secretPasscode.secretChats {
                    if secretChat.accountRecordId == accountId {
                        result.insert(secretChat.peerId)
                    }
                }
            }
        }
        return result
    }
    
    public func allSecretChatPeerIds(accountId: AccountRecordId) -> Set<PeerId> {
        var result = Set<PeerId>()
        for secretPasscode in self.secretPasscodes {
            for secretChat in secretPasscode.secretChats {
                if secretChat.accountRecordId == accountId {
                    result.insert(secretChat.peerId)
                }
            }
        }
        return result
    }
    
    // used by app extensions to apply timeouts to handle cases when main app wasn't running for some time
    // changes are not saved to storage, only main app does that to avoid conflicts
    public func withCheckedTimeoutUsingLockStateFile(rootPath: String) -> PtgSecretPasscodes {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data) {
            return PtgSecretPasscodes(secretPasscodes: self.secretPasscodes.map { sp in
                return sp.withUpdated(active: sp.active && (sp.timeout == nil || !isSecretPasscodeTimedout(timeout: sp.timeout!, state: state)))
            })
        } else {
            assertionFailure()
            return self
        }
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

public func isSecretPasscodeTimedout(timeout: Int32, state: LockState) -> Bool {
    if let applicationActivityTimestamp = state.applicationActivityTimestamp {
        let timestamp = MonotonicTimestamp()
        
        if timestamp.bootTimestamp.absDiff(with: applicationActivityTimestamp.bootTimestamp) > 0.1 {
            return true
        }
        if timestamp.uptime < applicationActivityTimestamp.uptime {
            return true
        }
        if timestamp.uptime >= applicationActivityTimestamp.uptime + timeout {
            return true
        }
        
        return false
    } else {
        return true
    }
}
