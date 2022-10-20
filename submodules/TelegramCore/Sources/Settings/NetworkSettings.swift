import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit


public func updateNetworkSettingsInteractively(postbox: Postbox, network: Network, _ f: @escaping (NetworkSettings) -> NetworkSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        updateNetworkSettingsInteractively(transaction: transaction, network: network, f)
    }
}

extension NetworkSettings {
    var mtNetworkSettings: MTNetworkSettings {
        return MTNetworkSettings(reducedBackupDiscoveryTimeout: self.reducedBackupDiscoveryTimeout)
    }
}

public func updateNetworkSettingsInteractively(transaction: Transaction, network: Network?, _ f: @escaping (NetworkSettings) -> NetworkSettings) {
    var updateNetwork = false
    var updatedSettings: NetworkSettings?
    transaction.updatePreferencesEntry(key: PreferencesKeys.networkSettings, { current in
        let previous = current?.get(NetworkSettings.self) ?? NetworkSettings.defaultSettings
        let updated = f(previous)
        updatedSettings = updated
        if updated.reducedBackupDiscoveryTimeout != previous.reducedBackupDiscoveryTimeout {
            updateNetwork = true
        }
        if updated.backupHostOverride != previous.backupHostOverride {
            updateNetwork = true
        }
        return PreferencesEntry(updated)
    })
    
    if let network = network, updateNetwork, let updatedSettings = updatedSettings {
        network.context.updateApiEnvironment { current in
            return current?.withUpdatedNetworkSettings(updatedSettings.mtNetworkSettings)
        }
    }
}
