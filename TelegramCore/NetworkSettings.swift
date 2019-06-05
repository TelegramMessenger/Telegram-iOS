import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
#else
import Postbox
import SwiftSignalKit
    #if BUCK
        import MtProtoKit
    #else
        import MtProtoKitDynamic
    #endif
#endif

public struct NetworkSettings: PreferencesEntry, Equatable {
    public var reducedBackupDiscoveryTimeout: Bool
    public internal(set) var applicationUpdateUrlPrefix: String?
    
    public static var defaultSettings: NetworkSettings {
        return NetworkSettings(reducedBackupDiscoveryTimeout: false, applicationUpdateUrlPrefix: nil)
    }
    
    public init(reducedBackupDiscoveryTimeout: Bool, applicationUpdateUrlPrefix: String?) {
        self.reducedBackupDiscoveryTimeout = reducedBackupDiscoveryTimeout
        self.applicationUpdateUrlPrefix = applicationUpdateUrlPrefix
    }
    
    public init(decoder: PostboxDecoder) {
        self.reducedBackupDiscoveryTimeout = decoder.decodeInt32ForKey("reducedBackupDiscoveryTimeout", orElse: 0) != 0
        self.applicationUpdateUrlPrefix = decoder.decodeOptionalStringForKey("applicationUpdateUrlPrefix")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.reducedBackupDiscoveryTimeout ? 1 : 0, forKey: "reducedBackupDiscoveryTimeout")
        if let applicationUpdateUrlPrefix = self.applicationUpdateUrlPrefix {
            encoder.encodeString(applicationUpdateUrlPrefix, forKey: "applicationUpdateUrlPrefix")
        } else {
            encoder.encodeNil(forKey: "applicationUpdateUrlPrefix")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? NetworkSettings else {
            return false
        }
        
        return self == to
    }
}

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

public func updateNetworkSettingsInteractively(transaction: Transaction, network: Network, _ f: @escaping (NetworkSettings) -> NetworkSettings) {
    var updateNetwork = false
    var updatedSettings: NetworkSettings?
    transaction.updatePreferencesEntry(key: PreferencesKeys.networkSettings, { current in
        let previous = (current as? NetworkSettings) ?? NetworkSettings.defaultSettings
        let updated = f(previous)
        updatedSettings = updated
        if updated.reducedBackupDiscoveryTimeout != previous.reducedBackupDiscoveryTimeout {
            updateNetwork = true
        }
        return updated
    })
    
    if updateNetwork, let updatedSettings = updatedSettings {
        network.context.updateApiEnvironment { current in
            return current?.withUpdatedNetworkSettings(updatedSettings.mtNetworkSettings)
        }
    }
}
