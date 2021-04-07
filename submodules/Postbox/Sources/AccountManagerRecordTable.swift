import Foundation

enum AccountManagerRecordOperation {
    case set(id: AccountRecordId, record: AccountRecord?)
}

final class AccountManagerRecordTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private func key(_ key: AccountRecordId) -> ValueBoxKey {
        let result = ValueBoxKey(length: 8)
        result.setInt64(0, value: key.rawValue)
        return result
    }
    
    func getRecords() -> [AccountRecord] {
        var records: [AccountRecord] = []
        self.valueBox.scan(self.table, values: { _, value in
            let record = AccountRecord(decoder: PostboxDecoder(buffer: value))
            records.append(record)
            return true
        })
        return records
    }
    
    func getRecord(id: AccountRecordId) -> AccountRecord? {
        if let value = self.valueBox.get(self.table, key: self.key(id)) {
            return AccountRecord(decoder: PostboxDecoder(buffer: value))
        } else {
            return nil
        }
    }
    
    func setRecord(id: AccountRecordId, record: AccountRecord?, operations: inout [AccountManagerRecordOperation]) {
        if let record = record {
            let encoder = PostboxEncoder()
            record.encode(encoder)
            withExtendedLifetime(encoder, {
                self.valueBox.set(self.table, key: self.key(id), value: encoder.readBufferNoCopy())
            })
        } else {
            self.valueBox.remove(self.table, key: self.key(id), secure: false)
        }
        operations.append(.set(id: id, record: record))
    }
}
