import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public struct CacheStorageSettings: PreferencesEntry, Equatable {
    public let defaultCacheStorageTimeout: Int32
    
    public static var defaultSettings: CacheStorageSettings {
        return CacheStorageSettings(defaultCacheStorageTimeout: 7 * 60 * 60 * 24)
    }
    
    init(defaultCacheStorageTimeout: Int32) {
        self.defaultCacheStorageTimeout = defaultCacheStorageTimeout
    }
    
    public init(decoder: PostboxDecoder) {
        self.defaultCacheStorageTimeout = decoder.decodeInt32ForKey("dt", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.defaultCacheStorageTimeout, forKey: "dt")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? CacheStorageSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: CacheStorageSettings, rhs: CacheStorageSettings) -> Bool {
        return lhs.defaultCacheStorageTimeout == rhs.defaultCacheStorageTimeout
    }
    
    public func withUpdatedDefaultCacheStorageTimeout(_ defaultCacheStorageTimeout: Int32) -> CacheStorageSettings {
        return CacheStorageSettings(defaultCacheStorageTimeout: defaultCacheStorageTimeout)
    }
}

public func updateCacheStorageSettingsInteractively(accountManager: AccountManager, _ f: @escaping (CacheStorageSettings) -> CacheStorageSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(SharedDataKeys.cacheStorageSettings, { entry in
            let currentSettings: CacheStorageSettings
            if let entry = entry as? CacheStorageSettings {
                currentSettings = entry
            } else {
                currentSettings = CacheStorageSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
