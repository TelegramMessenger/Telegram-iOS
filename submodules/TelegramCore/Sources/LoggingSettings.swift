import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import SyncCore

public func updateLoggingSettings(accountManager: AccountManager, _ f: @escaping (LoggingSettings) -> LoggingSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        var updated: LoggingSettings?
        transaction.updateSharedData(SharedDataKeys.loggingSettings, { current in
            if let current = current as? LoggingSettings {
                updated = f(current)
                return updated
            } else {
                updated = f(LoggingSettings.defaultSettings)
                return updated
            }
        })
        
        if let updated = updated {
            Logger.shared.logToFile = updated.logToFile
            Logger.shared.logToConsole = updated.logToConsole
            Logger.shared.redactSensitiveData = updated.redactSensitiveData
        }
    }
}
