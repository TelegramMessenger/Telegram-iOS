import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import SwiftSignalKit

public struct FakePasscodeAccountActionSettings: Codable, Equatable {
    public init() {

    }

    public init(from decoder: Decoder) throws {
        let _ = try decoder.container(keyedBy: StringCodingKey.self)

        // TODO Implement
    }

    public func encode(to encoder: Encoder) throws {
        var _ = encoder.container(keyedBy: StringCodingKey.self)

        // TODO Implement
    }
}

public struct FakePasscodeSmsActionSettings: Codable, Equatable {
    public init() {

    }

    public init(from decoder: Decoder) throws {
        let _ = try decoder.container(keyedBy: StringCodingKey.self)

        // TODO Implement
    }

    public func encode(to encoder: Encoder) throws {
        var _ = encoder.container(keyedBy: StringCodingKey.self)

        // TODO Implement
    }
}


public struct FakePasscodeSettingsHolder: Codable, Equatable {  // TODO probably replace with some PartisanSettings structure, and put [FakePasscodeSettings] under it because PostboxDecoder cannot decode Arrays directly and we need some structure to hold it
    public var settings: [FakePasscodeSettings]

    public static var defaultSettings: FakePasscodeSettingsHolder {
        return FakePasscodeSettingsHolder(settings: [])
    }

    public init(settings: [FakePasscodeSettings]) {
        self.settings = settings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.settings = try container.decode([FakePasscodeSettings].self, forKey: "afps")// ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.settings, forKey: "afps")
    }
}

public struct FakePasscodeSettings: Codable, Equatable {
    public let name: String
    // public var passcode: String
    public let allowLogin: Bool
    public let clearAfterActivation: Bool
    public let deleteOtherPasscodes: Bool
    public let activationMessage: String?
    public let activationAttempts: Int32
    public let smsActions: FakePasscodeSmsActionSettings?
    public let clearCache: Bool
    public let clearProxies: Bool
    public let accountActions: FakePasscodeAccountActionSettings?

    public static var defaultSettings: FakePasscodeSettings {
        return FakePasscodeSettings(name: "New Fake Passcode")
    }

    public init(name: String) {
        self.init(name: name, allowLogin: false, clearAfterActivation: false, deleteOtherPasscodes: false, activationMessage: nil, activationAttempts: -1, smsActions: FakePasscodeSmsActionSettings(), clearCache: false, clearProxies: false, accountActions: FakePasscodeAccountActionSettings())
    }

    public init(name: String, allowLogin: Bool, clearAfterActivation: Bool, deleteOtherPasscodes: Bool, activationMessage: String?, activationAttempts: Int32, smsActions: FakePasscodeSmsActionSettings?, clearCache: Bool, clearProxies: Bool, accountActions: FakePasscodeAccountActionSettings?) {
        self.name = name
        // public var passcode: String
        self.allowLogin = allowLogin
        self.clearAfterActivation = clearAfterActivation
        self.deleteOtherPasscodes = deleteOtherPasscodes
        self.activationMessage = activationMessage
        self.activationAttempts = activationAttempts
        self.smsActions = smsActions
        self.clearCache = clearCache
        self.clearProxies = clearProxies
        self.accountActions = accountActions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.name = try container.decode(String.self, forKey: "n")
        self.allowLogin = (try container.decode(Int32.self, forKey: "al")) != 0
        self.clearAfterActivation = (try container.decode(Int32.self, forKey: "caa")) != 0
        self.deleteOtherPasscodes = (try container.decode(Int32.self, forKey: "dop")) != 0
        self.activationMessage = (try container.decodeIfPresent(String.self, forKey: "am"))
        self.activationAttempts = try container.decode(Int32.self, forKey: "bpa")
        self.smsActions = try container.decodeIfPresent(FakePasscodeSmsActionSettings.self, forKey: "fps")
        self.clearCache = (try container.decode(Int32.self, forKey: "cc")) != 0
        self.clearProxies = (try container.decode(Int32.self, forKey: "cp")) != 0
        self.accountActions = try container.decodeIfPresent(FakePasscodeAccountActionSettings.self, forKey: "aa")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.name, forKey: "n")
        try container.encode((self.allowLogin ? 1 : 0) as Int32, forKey: "al")
        try container.encode((self.clearAfterActivation ? 1 : 0) as Int32, forKey: "caa")
        try container.encode((self.deleteOtherPasscodes ? 1 : 0) as Int32, forKey: "dop")
        try container.encodeIfPresent(self.activationMessage, forKey: "am")
        try container.encodeIfPresent(self.activationAttempts, forKey: "bpa")
        try container.encodeIfPresent(self.smsActions, forKey: "fps")
        try container.encode((self.clearCache ? 1 : 0) as Int32, forKey: "cc")
        try container.encode((self.clearProxies ? 1 : 0) as Int32, forKey: "cp")
        try container.encodeIfPresent(self.accountActions, forKey: "aa")
    }

    public static func ==(lhs: FakePasscodeSettings, rhs: FakePasscodeSettings) -> Bool {
        return lhs.name == rhs.name && lhs.allowLogin == rhs.allowLogin && lhs.clearAfterActivation == rhs.clearAfterActivation && lhs.deleteOtherPasscodes == rhs.deleteOtherPasscodes && lhs.activationMessage == rhs.activationMessage && lhs.activationAttempts == rhs.activationAttempts && lhs.smsActions == rhs.smsActions && lhs.clearCache == rhs.clearCache && lhs.clearProxies == rhs.clearProxies && lhs.accountActions == rhs.accountActions
    }

    public func withUpdatedName(_ name: String) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: name, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedAllowLogin(_ allowLogin: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: self.name, allowLogin: allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedClearAfterActivation(_ clearAfterActivation: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: self.name, allowLogin: self.allowLogin, clearAfterActivation: clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedDeleteOtherPasscodes(_ deleteOtherPasscodes: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: self.name, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedActivationMessage(_ activationMessage: String) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: self.name, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedBadPasscodeActivation(_ activationAttempts: Int32) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: self.name, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedSms(_ smsActions: FakePasscodeSmsActionSettings?) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: self.name, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedClearCache(_ clearCache: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: self.name, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedClearProxies(_ clearProxies: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: self.name, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedAccountActions(_ clearProxies: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: self.name, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: accountActions)
    }
}

public func updateFakePasscodeSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, index: Int, _ f: @escaping (FakePasscodeSettings) -> FakePasscodeSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        updateFakePasscodeSettingsInternal(transaction: transaction, index: index, f)
    }
}

public func updateFakePasscodeSettingsInternal(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, index: Int, _ f: @escaping (FakePasscodeSettings) -> FakePasscodeSettings) {
    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.fakePasscodeSettings, { entry in
        if var holder = entry?.get(FakePasscodeSettingsHolder.self) {
            holder.settings[index] = f(holder.settings[index])
            return PreferencesEntry(holder)
        } else {
            assertionFailure("FakePasscodeSettingsHolder should exists at this moment")
            let settings = f(FakePasscodeSettings.defaultSettings)
            return PreferencesEntry(FakePasscodeSettingsHolder(settings: [settings]))
        }
    })
}
