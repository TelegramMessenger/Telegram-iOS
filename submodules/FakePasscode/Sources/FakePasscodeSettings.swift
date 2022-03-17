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
    public let badPasscodeActivation: String?
    public let fakePasscodeSms: Int32
    public let clearCache: Bool
    public let clearProxies: Bool
    public let accountAction: FakePasscodeAccountActionSettings?

    public static var defaultSettings: FakePasscodeSettings {
        return FakePasscodeSettings(name: "New Fake Passcode", allowLogin: false, clearAfterActivation: false, deleteOtherPasscodes: false, activationMessage: nil, badPasscodeActivation: nil, fakePasscodeSms: 0, clearCache: false, clearProxies: false, accountAction: FakePasscodeAccountActionSettings())
    }

    public init(name: String) {
        self.init(name: name, allowLogin: false, clearAfterActivation: false, deleteOtherPasscodes: false, activationMessage: nil, badPasscodeActivation: nil, fakePasscodeSms: 0, clearCache: false, clearProxies: false, accountAction: FakePasscodeAccountActionSettings())
    }

    public init(name: String, allowLogin: Bool, clearAfterActivation: Bool, deleteOtherPasscodes: Bool, activationMessage: String?, badPasscodeActivation: String?, fakePasscodeSms: Int32, clearCache: Bool, clearProxies: Bool, accountAction: FakePasscodeAccountActionSettings?) {
        self.name = name
        // public var passcode: String
        self.allowLogin = allowLogin
        self.clearAfterActivation = clearAfterActivation
        self.deleteOtherPasscodes = deleteOtherPasscodes
        self.activationMessage = activationMessage
        self.badPasscodeActivation = badPasscodeActivation
        self.fakePasscodeSms = fakePasscodeSms
        self.clearCache = clearCache
        self.clearProxies = clearProxies
        self.accountAction = accountAction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.name = try container.decode(String.self, forKey: "n")
        self.allowLogin = (try container.decode(Int32.self, forKey: "al")) != 0
        self.clearAfterActivation = (try container.decode(Int32.self, forKey: "caa")) != 0
        self.deleteOtherPasscodes = (try container.decode(Int32.self, forKey: "dop")) != 0
        self.activationMessage = (try container.decodeIfPresent(String.self, forKey: "am"))
        self.badPasscodeActivation = (try container.decodeIfPresent(String.self, forKey: "bpa"))
        self.fakePasscodeSms = try container.decode(Int32.self, forKey: "fps")
        self.clearCache = (try container.decode(Int32.self, forKey: "cc")) != 0
        self.clearProxies = (try container.decode(Int32.self, forKey: "cp")) != 0
        self.accountAction = try container.decodeIfPresent(FakePasscodeAccountActionSettings.self, forKey: "aa")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.name, forKey: "n")
        try container.encode((self.allowLogin ? 1 : 0) as Int32, forKey: "al")
        try container.encode((self.clearAfterActivation ? 1 : 0) as Int32, forKey: "caa")
        try container.encode((self.deleteOtherPasscodes ? 1 : 0) as Int32, forKey: "dop")
        try container.encodeIfPresent(self.activationMessage, forKey: "am")
        try container.encodeIfPresent(self.badPasscodeActivation, forKey: "bpa")
        try container.encode(self.fakePasscodeSms, forKey: "fps")
        try container.encode((self.clearCache ? 1 : 0) as Int32, forKey: "cc")
        try container.encode((self.clearProxies ? 1 : 0) as Int32, forKey: "cp")
        try container.encodeIfPresent(self.accountAction, forKey: "aa")
    }

    public static func ==(lhs: FakePasscodeSettings, rhs: FakePasscodeSettings) -> Bool {
        return lhs.name == rhs.name && lhs.allowLogin == rhs.allowLogin && lhs.clearAfterActivation == rhs.clearAfterActivation && lhs.deleteOtherPasscodes == rhs.deleteOtherPasscodes && lhs.activationMessage == rhs.activationMessage && lhs.badPasscodeActivation == rhs.badPasscodeActivation && lhs.fakePasscodeSms == rhs.fakePasscodeSms && lhs.clearCache == rhs.clearCache && lhs.clearProxies == rhs.clearProxies && lhs.accountAction == rhs.accountAction
    }

    public func withUpdatedName(_ name: String) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: name, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, badPasscodeActivation: self.badPasscodeActivation, fakePasscodeSms: self.fakePasscodeSms, clearCache: self.clearCache, clearProxies: self.clearProxies, accountAction: self.accountAction)
    }

    public func withUpdatedAllowLogin(_ allowLogin: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(name: self.name, allowLogin: allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, badPasscodeActivation: self.badPasscodeActivation, fakePasscodeSms: self.fakePasscodeSms, clearCache: self.clearCache, clearProxies: self.clearProxies, accountAction: self.accountAction)
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
