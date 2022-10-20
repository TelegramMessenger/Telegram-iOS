import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

public func updateLoggingSettings(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (LoggingSettings) -> LoggingSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        var updated: LoggingSettings?
        transaction.updateSharedData(SharedDataKeys.loggingSettings, { current in
            if let current = current?.get(LoggingSettings.self) {
                updated = f(current)
                return PreferencesEntry(updated)
            } else {
                updated = f(LoggingSettings.defaultSettings)
                return PreferencesEntry(updated)
            }
        })
        
        if let updated = updated {
            Logger.shared.logToFile = updated.logToFile
            Logger.shared.logToConsole = updated.logToConsole
            Logger.shared.redactSensitiveData = updated.redactSensitiveData
        }
    }
}
