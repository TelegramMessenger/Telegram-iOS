import Postbox

public struct NetworkSettings: PreferencesEntry, Equatable {
    public var reducedBackupDiscoveryTimeout: Bool
    public var applicationUpdateUrlPrefix: String?
    public var backupHostOverride: String?
    public var defaultEnableTempKeys: Bool
    public var userEnableTempKeys: Bool?
    
    public static var defaultSettings: NetworkSettings {
        return NetworkSettings(reducedBackupDiscoveryTimeout: false, applicationUpdateUrlPrefix: nil, backupHostOverride: nil, defaultEnableTempKeys: false, userEnableTempKeys: nil)
    }
    
    public init(reducedBackupDiscoveryTimeout: Bool, applicationUpdateUrlPrefix: String?, backupHostOverride: String?, defaultEnableTempKeys: Bool, userEnableTempKeys: Bool?) {
        self.reducedBackupDiscoveryTimeout = reducedBackupDiscoveryTimeout
        self.applicationUpdateUrlPrefix = applicationUpdateUrlPrefix
        self.backupHostOverride = backupHostOverride
        self.defaultEnableTempKeys = defaultEnableTempKeys
        self.userEnableTempKeys = userEnableTempKeys
    }
    
    public init(decoder: PostboxDecoder) {
        self.reducedBackupDiscoveryTimeout = decoder.decodeInt32ForKey("reducedBackupDiscoveryTimeout", orElse: 0) != 0
        self.applicationUpdateUrlPrefix = decoder.decodeOptionalStringForKey("applicationUpdateUrlPrefix")
        self.backupHostOverride = decoder.decodeOptionalStringForKey("backupHostOverride")
        self.defaultEnableTempKeys = decoder.decodeBoolForKey("defaultEnableTempKeys", orElse: false)
        self.userEnableTempKeys = decoder.decodeOptionalBoolForKey("userEnableTempKeys")
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
        encoder.encodeBool(self.defaultEnableTempKeys, forKey: "defaultEnableTempKeys")
        if let userEnableTempKeys = self.userEnableTempKeys {
            encoder.encodeBool(userEnableTempKeys, forKey: "userEnableTempKeys")
        } else {
            encoder.encodeNil(forKey: "userEnableTempKeys")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? NetworkSettings else {
            return false
        }
        
        return self == to
    }
}
