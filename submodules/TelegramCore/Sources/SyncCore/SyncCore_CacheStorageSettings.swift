import Foundation
import Postbox

public struct CacheStorageSettings: Codable, Equatable {
    public enum PeerStorageCategory: String, Codable, Hashable {
        case privateChats = "privateChats"
        case groups = "groups"
        case channels = "channels"
    }
    
    private struct CategoryStorageTimeoutRepresentation: Codable {
        var key: PeerStorageCategory
        var value: Int32
    }
    
    public var defaultCacheStorageTimeout: Int32
    public var defaultCacheStorageLimitGigabytes: Int32
    
    public var categoryStorageTimeout: [PeerStorageCategory: Int32]

    public static var defaultSettings: CacheStorageSettings {
        return CacheStorageSettings(
            defaultCacheStorageTimeout: Int32.max,
            defaultCacheStorageLimitGigabytes: 8 * 1024 * 1024,
            categoryStorageTimeout: [
                .privateChats: Int32.max,
                .groups: Int32.max,
                .channels: Int32(1 * 24 * 60 * 60)
            ]
        )
    }
    
    public init(
        defaultCacheStorageTimeout: Int32,
        defaultCacheStorageLimitGigabytes: Int32,
        categoryStorageTimeout: [PeerStorageCategory: Int32]
    ) {
        self.defaultCacheStorageTimeout = defaultCacheStorageTimeout
        self.defaultCacheStorageLimitGigabytes = defaultCacheStorageLimitGigabytes
        self.categoryStorageTimeout = categoryStorageTimeout
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
        
        if let data = try container.decodeIfPresent(Data.self, forKey: "categoryStorageTimeoutJson") {
            if let items = try? JSONDecoder().decode([CategoryStorageTimeoutRepresentation].self, from: data) {
                var categoryStorageTimeout: [PeerStorageCategory: Int32] = [:]
                for item in items {
                    categoryStorageTimeout[item.key] = item.value
                }
                self.categoryStorageTimeout = categoryStorageTimeout
            } else {
                self.categoryStorageTimeout = CacheStorageSettings.defaultSettings.categoryStorageTimeout
            }
        } else {
            self.categoryStorageTimeout = CacheStorageSettings.defaultSettings.categoryStorageTimeout
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.defaultCacheStorageTimeout, forKey: "dt")
        try container.encode(self.defaultCacheStorageLimitGigabytes, forKey: "dl")
        
        var categoryStorageTimeoutValues: [CategoryStorageTimeoutRepresentation] = []
        for (key, value) in self.categoryStorageTimeout {
            categoryStorageTimeoutValues.append(CategoryStorageTimeoutRepresentation(key: key, value: value))
        }
        if let data = try? JSONEncoder().encode(categoryStorageTimeoutValues) {
            try container.encode(data, forKey: "categoryStorageTimeoutJson")
        }
    }
}

public struct AccountSpecificCacheStorageSettings: Codable, Equatable {
    private struct PeerStorageTimeoutExceptionRepresentation: Codable {
        var key: PeerId
        var value: Int32
    }
    
    public var peerStorageTimeoutExceptions: [PeerId: Int32]

    public static var defaultSettings: AccountSpecificCacheStorageSettings {
        return AccountSpecificCacheStorageSettings(
            peerStorageTimeoutExceptions: [:]
        )
    }
    
    public init(
        peerStorageTimeoutExceptions: [PeerId: Int32]
    ) {
        self.peerStorageTimeoutExceptions = peerStorageTimeoutExceptions
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let data = try container.decodeIfPresent(Data.self, forKey: "peerStorageTimeoutExceptionsJson") {
            if let items = try? JSONDecoder().decode([PeerStorageTimeoutExceptionRepresentation].self, from: data) {
                var peerStorageTimeoutExceptions: [PeerId: Int32] = [:]
                for item in items {
                    peerStorageTimeoutExceptions[item.key] = item.value
                }
                self.peerStorageTimeoutExceptions = peerStorageTimeoutExceptions
            } else {
                self.peerStorageTimeoutExceptions = AccountSpecificCacheStorageSettings.defaultSettings.peerStorageTimeoutExceptions
            }
        } else {
            self.peerStorageTimeoutExceptions = AccountSpecificCacheStorageSettings.defaultSettings.peerStorageTimeoutExceptions
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        var peerStorageTimeoutExceptionsValues: [PeerStorageTimeoutExceptionRepresentation] = []
        for (key, value) in self.peerStorageTimeoutExceptions {
            peerStorageTimeoutExceptionsValues.append(PeerStorageTimeoutExceptionRepresentation(key: key, value: value))
        }
        if let data = try? JSONEncoder().encode(peerStorageTimeoutExceptionsValues) {
            try container.encode(data, forKey: "peerStorageTimeoutExceptionsJson")
        }
    }
}
