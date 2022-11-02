import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import SwiftSignalKit

public struct PtgSecretPasscode: Codable, Equatable {
    public let passcode: String
    public let active: Bool
    public let timeout: Int32?
    
    public init(passcode: String, active: Bool, timeout: Int32?) {
        self.passcode = passcode
        self.active = active
        self.timeout = timeout
    }
    
    public init(passcode: String) {
        self.passcode = passcode
        self.active = false
        self.timeout = 5 * 60
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.passcode = try container.decode(String.self, forKey: "p")
        self.active = try container.decode(Int32.self, forKey: "a") != 0
        self.timeout = try container.decodeIfPresent(Int32.self, forKey: "t")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.passcode, forKey: "p")
        try container.encode((self.active ? 1 : 0) as Int32, forKey: "a")
        try container.encodeIfPresent(self.timeout, forKey: "t")
    }
    
    public func withUpdated(passcode: String) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: passcode, active: self.active, timeout: self.timeout)
    }
    
    public func withUpdated(active: Bool) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: self.passcode, active: active, timeout: self.timeout)
    }
    
    public func withUpdated(timeout: Int32?) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: self.passcode, active: self.active, timeout: timeout)
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
    
    public func secretPasscode(passcode: String) -> PtgSecretPasscode? {
        return self.secretPasscodes.first { $0.passcode == passcode }
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
