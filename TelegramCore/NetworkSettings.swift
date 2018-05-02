import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
#else
import Postbox
import SwiftSignalKit
import MtProtoKitDynamic
#endif

public struct NetworkSettings: PreferencesEntry, Equatable {
    public var reducedBackupDiscoveryTimeout: Bool
    
    public static var defaultSettings: NetworkSettings {
        return NetworkSettings(reducedBackupDiscoveryTimeout: false)
    }
    
    public init(reducedBackupDiscoveryTimeout: Bool) {
        self.reducedBackupDiscoveryTimeout = reducedBackupDiscoveryTimeout
    }
    
    public init(decoder: PostboxDecoder) {
        self.reducedBackupDiscoveryTimeout = decoder.decodeInt32ForKey("reducedBackupDiscoveryTimeout", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.reducedBackupDiscoveryTimeout ? 1 : 0, forKey: "reducedBackupDiscoveryTimeout")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? NetworkSettings else {
            return false
        }
        
        return self == to
    }
}

public func updateNetworkSettingsInteractively(postbox: Postbox, network: Network, _ f: @escaping (NetworkSettings) -> NetworkSettings) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        updateNetworkSettingsInteractively(modifier: modifier, network: network, f)
    }
}

extension NetworkSettings {
    var mtNetworkSettings: MTNetworkSettings {
        return MTNetworkSettings(reducedBackupDiscoveryTimeout: self.reducedBackupDiscoveryTimeout)
    }
}

public func updateNetworkSettingsInteractively(modifier: Modifier, network: Network, _ f: @escaping (NetworkSettings) -> NetworkSettings) {
    var updateNetwork = false
    var updatedSettings: NetworkSettings?
    modifier.updatePreferencesEntry(key: PreferencesKeys.proxySettings, { current in
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
