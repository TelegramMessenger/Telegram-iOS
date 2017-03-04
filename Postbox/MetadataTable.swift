import Foundation

private enum MetadataKey: Int32 {
    case UserVersion = 1
    case State = 2
    case TransactionStateVersion = 3
    case MasterClientId = 4
    case AccessChallenge = 5
}

enum PostboxAccessChallengeData: Coding {
    case none
    case numericalPassword(String)
    case plaintextPassword(String)
    
    init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("r") as Int32 {
            case 0:
                self = .none
            case 1:
                self = .numericalPassword(decoder.decodeStringForKey("t"))
            case 2:
                self = .plaintextPassword(decoder.decodeStringForKey("t"))
            default:
                assertionFailure()
                self = .none
        }
    }
    
    func encode(_ encoder: Encoder) {
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
}

final class MetadataTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private var cachedState: Coding?
    
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
        self.valueBox.set(self.table, key: self.key(.State), value: encoder.readBufferNoCopy())
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
        self.valueBox.set(self.table, key: self.key(.AccessChallenge), value: encoder.readBufferNoCopy())
    }
    
    override func clearMemoryCache() {
        self.cachedState = nil
    }
}
