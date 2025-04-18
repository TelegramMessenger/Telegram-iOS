import Foundation
import Postbox
import SwiftSignalKit


func currentWebDocumentsHostDatacenterId(postbox: Postbox, isTestingEnvironment: Bool) -> Signal<Int32, NoError> {
    return postbox.transaction { transaction -> Int32 in
        if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.remoteStorageConfiguration)?.get(RemoteStorageConfiguration.self) {
            return entry.webDocumentsHostDatacenterId
        } else {
            if isTestingEnvironment {
                return 2
            } else {
                return 4
            }
        }
    }
}

func updateRemoteStorageConfiguration(transaction: Transaction, configuration: RemoteStorageConfiguration) {
    let current = transaction.getPreferencesEntry(key: PreferencesKeys.remoteStorageConfiguration)?.get(RemoteStorageConfiguration.self)
    if let current = current, current == configuration {
        return
    }
    
    transaction.setPreferencesEntry(key: PreferencesKeys.remoteStorageConfiguration, value: PreferencesEntry(configuration))
}
