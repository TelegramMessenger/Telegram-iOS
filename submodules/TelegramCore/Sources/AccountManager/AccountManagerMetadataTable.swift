import Foundation
import Postbox

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

public enum PostboxAccessChallengeData: PostboxCoding, Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case numericalPassword
        case plaintextPassword
    }
    
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .numericalPassword) {
            self = .numericalPassword(value: value)
        } else if let value = try? container.decode(String.self, forKey: .plaintextPassword) {
            self = .plaintextPassword(value: value)
        } else {
            self = .none
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            break
        case let .numericalPassword(value):
            try container.encode(value, forKey: .numericalPassword)
        case let .plaintextPassword(value):
            try container.encode(value, forKey: .plaintextPassword)
        }
    }
    
    public var isLockable: Bool {
        if case .none = self {
            return false
        } else {
            return true
        }
    }
    
    public var lockId: String? {
        switch self {
        case .none:
            return nil
        case let .numericalPassword(value):
            return "numericalPassword:\(value)"
        case let .plaintextPassword(value):
            return "plaintextPassword:\(value)"
        }
    }
}

public struct AuthAccountRecord<Attribute: AccountRecordAttribute>: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }
    
    public let id: AccountRecordId
    public let attributes: [Attribute]
    
    init(id: AccountRecordId, attributes: [Attribute]) {
        self.id = id
        self.attributes = attributes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(AccountRecordId.self, forKey: .id)

        if let attributesData = try? container.decode(Array<Data>.self, forKey: .attributes) {
            var attributes: [Attribute] = []
            for data in attributesData {
                if let attribute = try? AdaptedPostboxDecoder().decode(Attribute.self, from: data) {
                    attributes.append(attribute)
                }
            }
            self.attributes = attributes
        } else {
            let attributes = try container.decode([Attribute].self, forKey: .attributes)
            self.attributes = attributes
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.attributes, forKey: .attributes)
    }
}

enum AccountManagerMetadataOperation<Attribute: AccountRecordAttribute> {
    case updateCurrentAccountId(AccountRecordId)
    case updateCurrentAuthAccountRecord(AuthAccountRecord<Attribute>?)
}

private enum MetadataKey: Int64 {
    case currentAccountId = 0
    case currentAuthAccount = 1
    case accessChallenge = 2
    case version = 3
}

final class AccountManagerMetadataTable<Attribute: AccountRecordAttribute>: Table {
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
    
    func setCurrentAccountId(_ id: AccountRecordId, operations: inout [AccountManagerMetadataOperation<Attribute>]) {
        var rawValue = id.rawValue
        self.valueBox.set(self.table, key: self.key(.currentAccountId), value: MemoryBuffer(memory: &rawValue, capacity: 8, length: 8, freeWhenDone: false))
        operations.append(.updateCurrentAccountId(id))
    }
    
    func getCurrentAuthAccount() -> AuthAccountRecord<Attribute>? {
        if let value = self.valueBox.get(self.table, key: self.key(.currentAuthAccount)) {
            let object = try? AdaptedPostboxDecoder().decode(AuthAccountRecord<Attribute>.self, from: value.makeData())

            return object
        } else {
            return nil
        }
    }
    
    func setCurrentAuthAccount(_ record: AuthAccountRecord<Attribute>?, operations: inout [AccountManagerMetadataOperation<Attribute>]) {
        if let record = record {
            let data = try! AdaptedPostboxEncoder().encode(record)
            self.valueBox.set(self.table, key: self.key(.currentAuthAccount), value: ReadBuffer(data: data))
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
