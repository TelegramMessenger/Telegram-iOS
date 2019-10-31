import Postbox

public struct CacheStorageSettings: PreferencesEntry, Equatable {
    public let defaultCacheStorageTimeout: Int32
    
    public static var defaultSettings: CacheStorageSettings {
        return CacheStorageSettings(defaultCacheStorageTimeout: Int32.max)
    }
    
    public init(defaultCacheStorageTimeout: Int32) {
        self.defaultCacheStorageTimeout = defaultCacheStorageTimeout
    }
    
    public init(decoder: PostboxDecoder) {
        self.defaultCacheStorageTimeout = decoder.decodeInt32ForKey("dt", orElse: Int32.max)
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
