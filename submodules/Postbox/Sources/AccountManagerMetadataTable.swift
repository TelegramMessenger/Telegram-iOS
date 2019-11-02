import Foundation

public struct AccessChallengeAttempts: Equatable {
    public let count: Int32
    public var bootTimestamp: Int32
    public var uptime: Int32
    
    public init(count: Int32, bootTimestamp: Int32, uptime: Int32) {
        self.count = count
        self.bootTimestamp = bootTimestamp
        self.uptime = uptime
    }
}

public enum PostboxAccessChallengeData: PostboxCoding, Equatable {
    case none
    case numericalPassword(value: String)
    case plaintextPassword(value: String)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case 0:
                self = .none
            case 1:
                self = .numericalPassword(value: decoder.decodeStringForKey("t", orElse: ""))
            case 2:
                self = .plaintextPassword(value: decoder.decodeStringForKey("t", orElse: ""))
            default:
                assertionFailure()
                self = .none
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .none:
                encoder.encodeInt32(0, forKey: "r")
            case let .numericalPassword(text):
                encoder.encodeInt32(1, forKey: "r")
                encoder.encodeString(text, forKey: "t")
            case let .plaintextPassword(text):
                encoder.encodeInt32(2, forKey: "r")
                encoder.encodeString(text, forKey: "t")
        }
    }
    
    public var isLockable: Bool {
        if case .none = self {
            return false
        } else {
            return true
        }
    }
}

public struct AuthAccountRecord: PostboxCoding, Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }
    
    public let id: AccountRecordId
    public let attributes: [AccountRecordAttribute]
    
    init(id: AccountRecordId, attributes: [AccountRecordAttribute]) {
        self.id = id
        self.attributes = attributes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(AccountRecordId.self, forKey: .id)
        let attributesData = try container.decode(Array<Data>.self, forKey: .attributes)
        var attributes: [AccountRecordAttribute] = []
        for data in attributesData {
            if let object = PostboxDecoder(buffer: MemoryBuffer(data: data)).decodeRootObject() as? AccountRecordAttribute {
                attributes.append(object)
            }
        }
        self.attributes = attributes
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        let attributesData: [Data] = self.attributes.map { attribute in
            let encoder = PostboxEncoder()
            encoder.encodeRootObject(attribute)
            return encoder.makeData()
        }
        try container.encode(attributesData, forKey: .attributes)
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = AccountRecordId(rawValue: decoder.decodeOptionalInt64ForKey("id")!)
        self.attributes = decoder.decodeObjectArrayForKey("attributes").compactMap({ $0 as? AccountRecordAttribute })
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id.rawValue, forKey: "id")
        encoder.encodeGenericObjectArray(self.attributes.map { $0 as PostboxCoding }, forKey: "attributes")
    }
}

enum AccountManagerMetadataOperation {
    case updateCurrentAccountId(AccountRecordId)
    case updateCurrentAuthAccountRecord(AuthAccountRecord?)
}

private enum MetadataKey: Int64 {
    case currentAccountId = 0
    case currentAuthAccount = 1
    case accessChallenge = 2
    case version = 3
}

final class AccountManagerMetadataTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private func key(_ key: MetadataKey) -> ValueBoxKey {
        let result = ValueBoxKey(length: 8)
        result.setInt64(0, value: key.rawValue)
        return result
    }
    
    func getVersion() -> Int32? {
        if let value = self.valueBox.get(self.table, key: self.key(.version)) {
            var id: Int32 = 0
            value.read(&id, offset: 0, length: 4)
            return id
        } else {
            return 0
        }
    }
    
    func setVersion(_ version: Int32) {
        var value: Int32 = version
        self.valueBox.set(self.table, key: self.key(.version), value: MemoryBuffer(memory: &value, capacity: 4, length: 4, freeWhenDone: false))
    }
    
    func getCurrentAccountId() -> AccountRecordId? {
        if let value = self.valueBox.get(self.table, key: self.key(.currentAccountId)) {
            var id: Int64 = 0
            value.read(&id, offset: 0, length: 8)
            return AccountRecordId(rawValue: id)
        } else {
            return nil
        }
    }
    
    func setCurrentAccountId(_ id: AccountRecordId, operations: inout [AccountManagerMetadataOperation]) {
        var rawValue = id.rawValue
        self.valueBox.set(self.table, key: self.key(.currentAccountId), value: MemoryBuffer(memory: &rawValue, capacity: 8, length: 8, freeWhenDone: false))
        operations.append(.updateCurrentAccountId(id))
    }
    
    func getCurrentAuthAccount() -> AuthAccountRecord? {
        if let value = self.valueBox.get(self.table, key: self.key(.currentAuthAccount)), let object = PostboxDecoder(buffer: value).decodeRootObject() as? AuthAccountRecord {
            return object
        } else {
            return nil
        }
    }
    
    func setCurrentAuthAccount(_ record: AuthAccountRecord?, operations: inout [AccountManagerMetadataOperation]) {
        if let record = record {
            let encoder = PostboxEncoder()
            encoder.encodeRootObject(record)
            withExtendedLifetime(encoder, {
                self.valueBox.set(self.table, key: self.key(.currentAuthAccount), value: encoder.readBufferNoCopy())
            })
        } else {
            self.valueBox.remove(self.table, key: self.key(.currentAuthAccount), secure: false)
        }
        operations.append(.updateCurrentAuthAccountRecord(record))
    }
    
    func getAccessChallengeData() -> PostboxAccessChallengeData {
        if let value = self.valueBox.get(self.table, key: self.key(.accessChallenge)) {
            return PostboxAccessChallengeData(decoder: PostboxDecoder(buffer: value))
        } else {
            return .none
        }
    }
    
    func setAccessChallengeData(_ data: PostboxAccessChallengeData) {
        let encoder = PostboxEncoder()
        data.encode(encoder)
        withExtendedLifetime(encoder, {
            self.valueBox.set(self.table, key: self.key(.accessChallenge), value: encoder.readBufferNoCopy())
        })
    }
}
