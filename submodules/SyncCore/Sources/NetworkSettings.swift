import Postbox

public struct NetworkSettings: PreferencesEntry, Equatable {
    public var reducedBackupDiscoveryTimeout: Bool
    public var applicationUpdateUrlPrefix: String?
    public var backupHostOverride: String?
    
    public static var defaultSettings: NetworkSettings {
        return NetworkSettings(reducedBackupDiscoveryTimeout: false, applicationUpdateUrlPrefix: nil, backupHostOverride: nil)
    }
    
    public init(reducedBackupDiscoveryTimeout: Bool, applicationUpdateUrlPrefix: String?, backupHostOverride: String?) {
        self.reducedBackupDiscoveryTimeout = reducedBackupDiscoveryTimeout
        self.applicationUpdateUrlPrefix = applicationUpdateUrlPrefix
        self.backupHostOverride = backupHostOverride
    }
    
    public init(decoder: PostboxDecoder) {
        self.reducedBackupDiscoveryTimeout = decoder.decodeInt32ForKey("reducedBackupDiscoveryTimeout", orElse: 0) != 0
        self.applicationUpdateUrlPrefix = decoder.decodeOptionalStringForKey("applicationUpdateUrlPrefix")
        self.backupHostOverride = decoder.decodeOptionalStringForKey("backupHostOverride")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.reducedBackupDiscoveryTimeout ? 1 : 0, forKey: "reducedBackupDiscoveryTimeout")
        if let applicationUpdateUrlPrefix = self.applicationUpdateUrlPrefix {
            encoder.encodeString(applicationUpdateUrlPrefix, forKey: "applicationUpdateUrlPrefix")
        } else {
            encoder.encodeNil(forKey: "applicationUpdateUrlPrefix")
        }
        if let backupHostOverride = self.backupHostOverride {
            encoder.encodeString(backupHostOverride, forKey: "backupHostOverride")
        } else {
            encoder.encodeNil(forKey: "backupHostOverride")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? NetworkSettings else {
            return false
        }
        
        return self == to
    }
}
