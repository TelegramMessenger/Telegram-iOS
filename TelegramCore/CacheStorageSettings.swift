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
        return CacheStorageSettings(defaultCacheStorageTimeout: Int32.max)
    }
    
    init(defaultCacheStorageTimeout: Int32) {
        self.defaultCacheStorageTimeout = defaultCacheStorageTimeout
    }
    
    public init(decoder: Decoder) {
        self.defaultCacheStorageTimeout = decoder.decodeInt32ForKey("dt") as Int32
    }
    
    public func encode(_ encoder: Encoder) {
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

public func updateCacheStorageSettingsInteractively(postbox: Postbox, _ f: @escaping (CacheStorageSettings) -> CacheStorageSettings) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: PreferencesKeys.cacheStorageSettings, { entry in
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
