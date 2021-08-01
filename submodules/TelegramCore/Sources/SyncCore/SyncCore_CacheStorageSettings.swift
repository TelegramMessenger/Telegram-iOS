import Postbox

public struct CacheStorageSettings: PreferencesEntry, Equatable {
    public let defaultCacheStorageTimeout: Int32
    public let defaultCacheStorageLimitGigabytes: Int32

    public static var defaultSettings: CacheStorageSettings {
        return CacheStorageSettings(defaultCacheStorageTimeout: Int32.max, defaultCacheStorageLimitGigabytes: Int32.max)
    }
    
    public init(defaultCacheStorageTimeout: Int32, defaultCacheStorageLimitGigabytes: Int32) {
        self.defaultCacheStorageTimeout = defaultCacheStorageTimeout
        self.defaultCacheStorageLimitGigabytes = defaultCacheStorageLimitGigabytes
    }
    
    public init(decoder: PostboxDecoder) {
        self.defaultCacheStorageTimeout = decoder.decodeInt32ForKey("dt", orElse: Int32.max)
        self.defaultCacheStorageLimitGigabytes = decoder.decodeInt32ForKey("dl", orElse: Int32.max)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.defaultCacheStorageTimeout, forKey: "dt")
        encoder.encodeInt32(self.defaultCacheStorageLimitGigabytes, forKey: "dl")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? CacheStorageSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: CacheStorageSettings, rhs: CacheStorageSettings) -> Bool {
        return lhs.defaultCacheStorageTimeout == rhs.defaultCacheStorageTimeout && lhs.defaultCacheStorageLimitGigabytes == rhs.defaultCacheStorageLimitGigabytes
    }
    
    public func withUpdatedDefaultCacheStorageTimeout(_ defaultCacheStorageTimeout: Int32) -> CacheStorageSettings {
        return CacheStorageSettings(defaultCacheStorageTimeout: defaultCacheStorageTimeout, defaultCacheStorageLimitGigabytes: self.defaultCacheStorageLimitGigabytes)
    }
    public func withUpdatedDefaultCacheStorageLimitGigabytes(_ defaultCacheStorageLimitGigabytes: Int32) -> CacheStorageSettings {
        return CacheStorageSettings(defaultCacheStorageTimeout: self.defaultCacheStorageTimeout, defaultCacheStorageLimitGigabytes: defaultCacheStorageLimitGigabytes)
    }
}
