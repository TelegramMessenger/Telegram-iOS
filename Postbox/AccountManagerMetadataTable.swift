import Foundation

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
}
