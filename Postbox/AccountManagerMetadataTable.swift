import Foundation

public struct AccessChallengeAttempts: PostboxCoding, Equatable {
    public let count: Int32
    public let timestamp: Int32
    
    public init(count: Int32, timestamp: Int32) {
        self.count = count
        self.timestamp = timestamp
    }
    
    public init(decoder: PostboxDecoder) {
        self.count = decoder.decodeInt32ForKey("c", orElse: 0)
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.count, forKey: "c")
        encoder.encodeInt32(self.timestamp, forKey: "t")
    }
}

public enum PostboxAccessChallengeData: PostboxCoding, Equatable {
    case none
    case numericalPassword(value: String, timeout: Int32?, attempts: AccessChallengeAttempts?)
    case plaintextPassword(value: String, timeout: Int32?, attempts: AccessChallengeAttempts?)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case 0:
                self = .none
            case 1:
                self = .numericalPassword(value: decoder.decodeStringForKey("t", orElse: ""), timeout: decoder.decodeOptionalInt32ForKey("a"), attempts: decoder.decodeObjectForKey("att", decoder: { AccessChallengeAttempts(decoder: $0) }) as? AccessChallengeAttempts)
            case 2:
                self = .plaintextPassword(value: decoder.decodeStringForKey("t", orElse: ""), timeout: decoder.decodeOptionalInt32ForKey("a"), attempts: decoder.decodeObjectForKey("att", decoder: { AccessChallengeAttempts(decoder: $0) }) as? AccessChallengeAttempts)
            default:
                assertionFailure()
                self = .none
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .none:
                encoder.encodeInt32(0, forKey: "r")
            case let .numericalPassword(text, timeout, attempts):
                encoder.encodeInt32(1, forKey: "r")
                encoder.encodeString(text, forKey: "t")
                if let timeout = timeout {
                    encoder.encodeInt32(timeout, forKey: "a")
                } else {
                    encoder.encodeNil(forKey: "a")
                }
                if let attempts = attempts {
                    encoder.encodeObject(attempts, forKey: "att")
                } else {
                    encoder.encodeNil(forKey: "att")
                }
            case let .plaintextPassword(text, timeout, attempts):
                encoder.encodeInt32(2, forKey: "r")
                encoder.encodeString(text, forKey: "t")
                if let timeout = timeout {
                    encoder.encodeInt32(timeout, forKey: "a")
                } else {
                    encoder.encodeNil(forKey: "a")
                }
                if let attempts = attempts {
                    encoder.encodeObject(attempts, forKey: "att")
                } else {
                    encoder.encodeNil(forKey: "att")
                }
        }
    }
    
    public var isLockable: Bool {
        if case .none = self {
            return false
        } else {
            return true
        }
    }
    
    public var autolockDeadline: Int32? {
        switch self {
            case .none:
                return nil
            case let .numericalPassword(_, timeout, _):
                return timeout
            case let .plaintextPassword(_, timeout, _):
                return timeout
        }
    }
    
    public var attempts: AccessChallengeAttempts? {
        switch self {
            case .none:
                return nil
            case let .numericalPassword(_, _, attempts):
                return attempts
            case let .plaintextPassword(_, _, attempts):
                return attempts
        }
    }
    
    public func withUpdatedAutolockDeadline(_ autolockDeadline: Int32?) -> PostboxAccessChallengeData {
        switch self {
            case .none:
                return self
            case let .numericalPassword(value, _, attempts):
                return .numericalPassword(value: value, timeout: autolockDeadline, attempts: attempts)
            case let .plaintextPassword(value, _, attempts):
                return .plaintextPassword(value: value, timeout: autolockDeadline, attempts: attempts)
        }
    }
}

public struct AuthAccountRecord: PostboxCoding {
    public let id: AccountRecordId
    public let attributes: [AccountRecordAttribute]
    
    init(id: AccountRecordId, attributes: [AccountRecordAttribute]) {
        self.id = id
        self.attributes = attributes
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
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private func key(_ key: MetadataKey) -> ValueBoxKey {
        let result = ValueBoxKey(length: 8)
        result.setInt64(0, value: key.rawValue)
        return result
    }
    
    func getVersion() -> Int32 {
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
            self.valueBox.remove(self.table, key: self.key(.currentAuthAccount))
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
