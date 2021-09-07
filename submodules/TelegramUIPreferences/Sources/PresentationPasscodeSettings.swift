import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct PresentationPasscodeSettings: Codable, Equatable {
    public var enableBiometrics: Bool
    public var autolockTimeout: Int32?
    public var biometricsDomainState: Data?
    public var shareBiometricsDomainState: Data?
    
    public static var defaultSettings: PresentationPasscodeSettings {
        return PresentationPasscodeSettings(enableBiometrics: false, autolockTimeout: nil, biometricsDomainState: nil, shareBiometricsDomainState: nil)
    }
    
    public init(enableBiometrics: Bool, autolockTimeout: Int32?, biometricsDomainState: Data?, shareBiometricsDomainState: Data?) {
        self.enableBiometrics = enableBiometrics
        self.autolockTimeout = autolockTimeout
        self.biometricsDomainState = biometricsDomainState
        self.shareBiometricsDomainState = shareBiometricsDomainState
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.enableBiometrics = (try container.decode(Int32.self, forKey: "s")) != 0
        self.autolockTimeout = try container.decodeIfPresent(Int32.self, forKey: "al")
        self.biometricsDomainState = try container.decodeIfPresent(Data.self, forKey: "ds")
        self.shareBiometricsDomainState = try container.decodeIfPresent(Data.self, forKey: "sds")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.enableBiometrics ? 1 : 0) as Int32, forKey: "s")
        try container.encodeIfPresent(self.autolockTimeout, forKey: "al")
        try container.encodeIfPresent(self.biometricsDomainState, forKey: "ds")
        try container.encodeIfPresent(self.shareBiometricsDomainState, forKey: "sds")
    }
    
    public static func ==(lhs: PresentationPasscodeSettings, rhs: PresentationPasscodeSettings) -> Bool {
        return lhs.enableBiometrics == rhs.enableBiometrics && lhs.autolockTimeout == rhs.autolockTimeout && lhs.biometricsDomainState == rhs.biometricsDomainState && lhs.shareBiometricsDomainState == rhs.shareBiometricsDomainState
    }
    
    public func withUpdatedEnableBiometrics(_ enableBiometrics: Bool) -> PresentationPasscodeSettings {
        return PresentationPasscodeSettings(enableBiometrics: enableBiometrics, autolockTimeout: self.autolockTimeout, biometricsDomainState: self.biometricsDomainState, shareBiometricsDomainState: self.shareBiometricsDomainState)
    }
    
    public func withUpdatedAutolockTimeout(_ autolockTimeout: Int32?) -> PresentationPasscodeSettings {
        return PresentationPasscodeSettings(enableBiometrics: self.enableBiometrics, autolockTimeout: autolockTimeout, biometricsDomainState: self.biometricsDomainState, shareBiometricsDomainState: self.shareBiometricsDomainState)
    }
    
    public func withUpdatedBiometricsDomainState(_ biometricsDomainState: Data?) -> PresentationPasscodeSettings {
        return PresentationPasscodeSettings(enableBiometrics: self.enableBiometrics, autolockTimeout: autolockTimeout, biometricsDomainState: biometricsDomainState, shareBiometricsDomainState: self.shareBiometricsDomainState)
    }
    
    public func withUpdatedShareBiometricsDomainState(_ shareBiometricsDomainState: Data?) -> PresentationPasscodeSettings {
        return PresentationPasscodeSettings(enableBiometrics: self.enableBiometrics, autolockTimeout: autolockTimeout, biometricsDomainState: self.biometricsDomainState, shareBiometricsDomainState: shareBiometricsDomainState)
    }
}

public func updatePresentationPasscodeSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (PresentationPasscodeSettings) -> PresentationPasscodeSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        updatePresentationPasscodeSettingsInternal(transaction: transaction, f)
    }
}

public func updatePresentationPasscodeSettingsInternal(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, _ f: @escaping (PresentationPasscodeSettings) -> PresentationPasscodeSettings) {
    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationPasscodeSettings, { entry in
        let currentSettings: PresentationPasscodeSettings
        if let entry = entry?.get(PresentationPasscodeSettings.self) {
            currentSettings = entry
        } else {
            currentSettings = PresentationPasscodeSettings.defaultSettings
        }
        return PreferencesEntry(f(currentSettings))
    })
}
