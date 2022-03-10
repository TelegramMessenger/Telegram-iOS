import Foundation
import Postbox

public struct AccountBackupData: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case masterDatacenterId
        case peerId
        case masterDatacenterKey
        case masterDatacenterKeyId
        case notificationEncryptionKeyId
        case notificationEncryptionKey
        case additionalDatacenterKeys
    }
    
    public struct DatacenterKey: Codable, Equatable {
        public var id: Int32
        public var keyId: Int64
        public var key: Data
        
        public init(
            id: Int32,
            keyId: Int64,
            key: Data
        ) {
            self.id = id
            self.keyId = keyId
            self.key = key
        }
    }
    
    public var masterDatacenterId: Int32
    public var peerId: Int64
    public var masterDatacenterKey: Data
    public var masterDatacenterKeyId: Int64
    public var notificationEncryptionKeyId: Data?
    public var notificationEncryptionKey: Data?
    public var additionalDatacenterKeys: [Int32: DatacenterKey]

    public init(
        masterDatacenterId: Int32,
        peerId: Int64,
        masterDatacenterKey: Data,
        masterDatacenterKeyId: Int64,
        notificationEncryptionKeyId: Data?,
        notificationEncryptionKey: Data?,
        additionalDatacenterKeys: [Int32: DatacenterKey]
    ) {
    	self.masterDatacenterId = masterDatacenterId
    	self.peerId = peerId
    	self.masterDatacenterKey = masterDatacenterKey
    	self.masterDatacenterKeyId = masterDatacenterKeyId
        self.notificationEncryptionKeyId = notificationEncryptionKeyId
        self.notificationEncryptionKey = notificationEncryptionKey
        self.additionalDatacenterKeys = additionalDatacenterKeys
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.masterDatacenterId = try container.decode(Int32.self, forKey: .masterDatacenterId)
        self.peerId = try container.decode(Int64.self, forKey: .peerId)
        self.masterDatacenterKey = try container.decode(Data.self, forKey: .masterDatacenterKey)
        self.masterDatacenterKeyId = try container.decode(Int64.self, forKey: .masterDatacenterKeyId)
        self.notificationEncryptionKeyId = try container.decodeIfPresent(Data.self, forKey: .notificationEncryptionKeyId)
        self.notificationEncryptionKey = try container.decodeIfPresent(Data.self, forKey: .notificationEncryptionKey)
        self.additionalDatacenterKeys = try container.decodeIfPresent([Int32: DatacenterKey].self, forKey: .additionalDatacenterKeys) ?? [:]
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.masterDatacenterId, forKey: .masterDatacenterId)
        try container.encode(self.peerId, forKey: .peerId)
        try container.encode(self.masterDatacenterKey, forKey: .masterDatacenterKey)
        try container.encode(self.masterDatacenterKeyId, forKey: .masterDatacenterKeyId)
        try container.encodeIfPresent(self.notificationEncryptionKeyId, forKey: .notificationEncryptionKeyId)
        try container.encodeIfPresent(self.notificationEncryptionKey, forKey: .notificationEncryptionKey)
        try container.encode(self.additionalDatacenterKeys, forKey: .additionalDatacenterKeys)
    }
}

public final class AccountBackupDataAttribute: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case data
    }

    public let data: AccountBackupData?
    
    public init(data: AccountBackupData?) {
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.data = try? JSONDecoder().decode(AccountBackupData.self, from: (try? container.decode(Data.self, forKey: .data)) ?? Data())
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let data = self.data, let serializedData = try? JSONEncoder().encode(data) {
            try container.encode(serializedData, forKey: .data)
        } else {
            try container.encodeNil(forKey: .data)
        }
    }
    
    public static func ==(lhs: AccountBackupDataAttribute, rhs: AccountBackupDataAttribute) -> Bool {
        return lhs.data == rhs.data
    }
}
