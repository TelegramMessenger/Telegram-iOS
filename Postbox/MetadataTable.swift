import Foundation

private enum MetadataKey: Int32 {
    case UserVersion = 1
    case State = 2
    case TransactionStateVersion = 3
    case MasterClientId = 4
    case AccessChallenge = 5
    case RemoteContactCount = 6
}

public struct AccessChallengeAttempts: Coding, Equatable {
    public let count: Int32
    public let timestamp: Int32
    
    public init(count: Int32, timestamp: Int32) {
        self.count = count
        self.timestamp = timestamp
    }
    
    public init(decoder: Decoder) {
        self.count = decoder.decodeInt32ForKey("c", orElse: 0)
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.count, forKey: "c")
        encoder.encodeInt32(self.timestamp, forKey: "t")
    }
    
    public static func ==(lhs: AccessChallengeAttempts, rhs: AccessChallengeAttempts) -> Bool {
        return lhs.count == rhs.count && lhs.timestamp == rhs.timestamp
    }
}

public enum PostboxAccessChallengeData: Coding, Equatable {
    case none
    case numericalPassword(value: String, timeout: Int32?, attempts: AccessChallengeAttempts?)
    case plaintextPassword(value: String, timeout: Int32?, attempts: AccessChallengeAttempts?)
    
    public init(decoder: Decoder) {
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
    
    public func encode(_ encoder: Encoder) {
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
    
    public static func ==(lhs: PostboxAccessChallengeData, rhs: PostboxAccessChallengeData) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .numericalPassword(lhsText, lhsTimeout, lhsAttempts):
                if case let .numericalPassword(rhsText, rhsTimeout, rhsAttempts) = rhs, lhsText == rhsText, lhsTimeout == rhsTimeout, lhsAttempts == rhsAttempts {
                    return true
                } else {
                    return false
                }
            case let .plaintextPassword(lhsText, lhsTimeout, lhsAttempts):
                if case let .plaintextPassword(rhsText, rhsTimeout, rhsAttempts) = rhs, lhsText == rhsText, lhsTimeout == rhsTimeout, lhsAttempts == rhsAttempts {
                    return true
                } else {
                    return false
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

final class MetadataTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private var cachedState: Coding?
    private var cachedRemoteContactCount: Int32?
    
    private let sharedBuffer = WriteBuffer()
    
    override init(valueBox: ValueBox, table: ValueBoxTable) {
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(_ key: MetadataKey) -> ValueBoxKey {
        let valueBoxKey = ValueBoxKey(length: 8)
        valueBoxKey.setInt64(0, value: Int64(key.rawValue))
        return valueBoxKey
    }
    
    func userVersion() -> Int32? {
        if let value = self.valueBox.get(self.table, key: self.key(.UserVersion)) {
            var version: Int32 = 0
            value.read(&version, offset: 0, length: 4)
            return version
        }
        return nil
    }
    
    func setUserVersion(_ version: Int32) {
        sharedBuffer.reset()
        let buffer = sharedBuffer
        var varVersion: Int32 = version
        buffer.write(&varVersion, offset: 0, length: 4)
        self.valueBox.set(self.table, key: self.key(.UserVersion), value: buffer)
    }
    
    func state() -> Coding? {
        if let cachedState = self.cachedState {
            return cachedState
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(.State)) {
                if let state = Decoder(buffer: value).decodeRootObject() {
                    self.cachedState = state
                    return state
                }
            }
            return nil
        }
    }
    
    func setState(_ state: Coding) {
        self.cachedState = state
        
        let encoder = Encoder()
        encoder.encodeRootObject(state)
        withExtendedLifetime(encoder, {
            self.valueBox.set(self.table, key: self.key(.State), value: encoder.readBufferNoCopy())
        })
    }
    
    func transactionStateVersion() -> Int64 {
        if let value = self.valueBox.get(self.table, key: self.key(.TransactionStateVersion)) {
            var version: Int64 = 0
            value.read(&version, offset: 0, length: 8)
            return version
        } else {
            return 0
        }
    }
    
    func incrementTransactionStateVersion() -> Int64 {
        var version = self.transactionStateVersion() + 1
        sharedBuffer.reset()
        let buffer = sharedBuffer
        buffer.write(&version, offset: 0, length: 8)
        self.valueBox.set(self.table, key: self.key(.TransactionStateVersion), value: buffer)
        return version
    }
    
    func masterClientId() -> Int64 {
        if let value = self.valueBox.get(self.table, key: self.key(.MasterClientId)) {
            var clientId: Int64 = 0
            value.read(&clientId, offset: 0, length: 8)
            return clientId
        } else {
            return 0
        }
    }
    
    func setMasterClientId(_ id: Int64) {
        sharedBuffer.reset()
        let buffer = sharedBuffer
        var clientId = id
        buffer.write(&clientId, offset: 0, length: 8)
        self.valueBox.set(self.table, key: self.key(.MasterClientId), value: buffer)
    }
    
    func accessChallengeData() -> PostboxAccessChallengeData {
        if let value = self.valueBox.get(self.table, key: self.key(.AccessChallenge)) {
            return PostboxAccessChallengeData(decoder: Decoder(buffer: value))
        } else {
            return .none
        }
    }
    
    func setAccessChallengeData(_ data: PostboxAccessChallengeData) {
        let encoder = Encoder()
        data.encode(encoder)
        withExtendedLifetime(encoder, {
            self.valueBox.set(self.table, key: self.key(.AccessChallenge), value: encoder.readBufferNoCopy())
        })
    }
    
    func setRemoteContactCount(_ count: Int32) {
        self.cachedRemoteContactCount = count
        var mutableCount: Int32 = count
        self.valueBox.set(self.table, key: self.key(.RemoteContactCount), value: MemoryBuffer(memory: &mutableCount, capacity: 4, length: 4, freeWhenDone: false))
    }
    
    func getRemoteContactCount() -> Int32 {
        if let cachedRemoteContactCount = self.cachedRemoteContactCount {
            return cachedRemoteContactCount
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(.RemoteContactCount)) {
                var count: Int32 = 0
                value.read(&count, offset: 0, length: 4)
                self.cachedRemoteContactCount = count
                return count
            } else {
                self.cachedRemoteContactCount = 0
                return 0
            }
        }
    }
    
    override func clearMemoryCache() {
        self.cachedState = nil
        self.cachedRemoteContactCount = nil
    }
}
