import Foundation

enum AccountManagerMetadataOperation {
    case updateCurrentAccountId(AccountRecordId)
}

private enum MetadataKey: Int64 {
    case currentAccountId = 0
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
}
