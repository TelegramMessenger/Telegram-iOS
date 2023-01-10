import Postbox

public struct CacheStorageSettings: Codable, Equatable {
    public let defaultCacheStorageTimeout: Int32
    public let defaultCacheStorageLimitGigabytes: Int32

    public static var defaultSettings: CacheStorageSettings {
        return CacheStorageSettings(defaultCacheStorageTimeout: Int32.max, defaultCacheStorageLimitGigabytes: 8 * 1024 * 1024)
    }
    
    public init(defaultCacheStorageTimeout: Int32, defaultCacheStorageLimitGigabytes: Int32) {
        self.defaultCacheStorageTimeout = defaultCacheStorageTimeout
        self.defaultCacheStorageLimitGigabytes = defaultCacheStorageLimitGigabytes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.defaultCacheStorageTimeout = (try? container.decode(Int32.self, forKey: "dt")) ?? Int32.max
        
        if let legacyValue = try container.decodeIfPresent(Int32.self, forKey: "dl") {
            self.defaultCacheStorageLimitGigabytes = legacyValue
        } else if let value = try container.decodeIfPresent(Int32.self, forKey: "sizeLimit") {
            self.defaultCacheStorageLimitGigabytes = value
        } else {
            self.defaultCacheStorageLimitGigabytes = 8 * 1024 * 1024
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.defaultCacheStorageTimeout, forKey: "dt")
        try container.encode(self.defaultCacheStorageLimitGigabytes, forKey: "dl")
    }
    
    public func withUpdatedDefaultCacheStorageTimeout(_ defaultCacheStorageTimeout: Int32) -> CacheStorageSettings {
        return CacheStorageSettings(defaultCacheStorageTimeout: defaultCacheStorageTimeout, defaultCacheStorageLimitGigabytes: self.defaultCacheStorageLimitGigabytes)
    }
    public func withUpdatedDefaultCacheStorageLimitGigabytes(_ defaultCacheStorageLimitGigabytes: Int32) -> CacheStorageSettings {
        return CacheStorageSettings(defaultCacheStorageTimeout: self.defaultCacheStorageTimeout, defaultCacheStorageLimitGigabytes: defaultCacheStorageLimitGigabytes)
    }
}
