import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct ExperimentalSettings: Codable, Equatable {
    public static var defaultSettings: ExperimentalSettings {
        return ExperimentalSettings()
    }
    
    public init() {
    }
    
    public init(from decoder: Decoder) throws {
    }
    
    public func encode(to encoder: Encoder) throws {
    }
    
    public static func ==(lhs: ExperimentalSettings, rhs: ExperimentalSettings) -> Bool {
        return true
    }
}

public func updateExperimentalSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (ExperimentalSettings) -> ExperimentalSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalSettings, { entry in
            let currentSettings: ExperimentalSettings
            if let entry = entry?.get(ExperimentalSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = ExperimentalSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
