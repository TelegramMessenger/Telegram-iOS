import Foundation
import Postbox

enum AccountManagerRecordOperation<Attribute: AccountRecordAttribute> {
    case set(id: AccountRecordId, record: AccountRecord<Attribute>?)
}

final class AccountManagerRecordTable<Attribute: AccountRecordAttribute>: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private func key(_ key: AccountRecordId) -> ValueBoxKey {
        let result = ValueBoxKey(length: 8)
        result.setInt64(0, value: key.rawValue)
        return result
    }
    
    func getRecords() -> [AccountRecord<Attribute>] {
        var records: [AccountRecord<Attribute>] = []
        self.valueBox.scan(self.table, values: { _, value in
            if let record = try? AdaptedPostboxDecoder().decode(AccountRecord<Attribute>.self, from: value.makeData()) {
                records.append(record)
            }
            return true
        })
        return records
    }
    
    func getRecord(id: AccountRecordId) -> AccountRecord<Attribute>? {
        if let value = self.valueBox.get(self.table, key: self.key(id)) {
            if let record = try? AdaptedPostboxDecoder().decode(AccountRecord<Attribute>.self, from: value.makeData()) {
                return record
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func setRecord(id: AccountRecordId, record: AccountRecord<Attribute>?, operations: inout [AccountManagerRecordOperation<Attribute>]) {
        if let record = record {
            let data = try! AdaptedPostboxEncoder().encode(record)
            self.valueBox.set(self.table, key: self.key(id), value: ReadBuffer(data: data))
        } else {
            self.valueBox.remove(self.table, key: self.key(id), secure: false)
        }
        operations.append(.set(id: id, record: record))
    }
}
