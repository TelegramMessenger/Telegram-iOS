import Foundation
import Postbox
import SwiftSignalKit

public struct PresentationPasscodeSettings: PreferencesEntry, Equatable {
    public var enableBiometrics: Bool
    public var autolockTimeout: Int32?
    
    public static var defaultSettings: PresentationPasscodeSettings {
        return PresentationPasscodeSettings(enableBiometrics: false, autolockTimeout: nil)
    }
    
    init(enableBiometrics: Bool, autolockTimeout: Int32?) {
        self.enableBiometrics = enableBiometrics
        self.autolockTimeout = autolockTimeout
    }
    
    public init(decoder: PostboxDecoder) {
        self.enableBiometrics = decoder.decodeInt32ForKey("s", orElse: 0) != 0
        self.autolockTimeout = decoder.decodeOptionalInt32ForKey("al")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.enableBiometrics ? 1 : 0, forKey: "s")
        if let autolockTimeout = self.autolockTimeout {
            encoder.encodeInt32(autolockTimeout, forKey: "al")
        } else {
            encoder.encodeNil(forKey: "al")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? PresentationPasscodeSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: PresentationPasscodeSettings, rhs: PresentationPasscodeSettings) -> Bool {
        return lhs.enableBiometrics == rhs.enableBiometrics && lhs.autolockTimeout == rhs.autolockTimeout
    }
    
    func withUpdatedEnableBiometrics(_ enableBiometrics: Bool) -> PresentationPasscodeSettings {
        return PresentationPasscodeSettings(enableBiometrics: enableBiometrics, autolockTimeout: self.autolockTimeout)
    }
    
    func withUpdatedAutolockTimeout(_ autolockTimeout: Int32?) -> PresentationPasscodeSettings {
        return PresentationPasscodeSettings(enableBiometrics: self.enableBiometrics, autolockTimeout: autolockTimeout)
    }
}

func updatePresentationPasscodeSettingsInteractively(accountManager: AccountManager, _ f: @escaping (PresentationPasscodeSettings) -> PresentationPasscodeSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        updatePresentationPasscodeSettingsInternal(transaction: transaction, f)
    }
}

func updatePresentationPasscodeSettingsInternal(transaction: AccountManagerModifier, _ f: @escaping (PresentationPasscodeSettings) -> PresentationPasscodeSettings) {
    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationPasscodeSettings, { entry in
        let currentSettings: PresentationPasscodeSettings
        if let entry = entry as? PresentationPasscodeSettings {
            currentSettings = entry
        } else {
            currentSettings = PresentationPasscodeSettings.defaultSettings
        }
        return f(currentSettings)
    })
}
