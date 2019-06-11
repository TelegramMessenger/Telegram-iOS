import Foundation

final class AccountManagerSharedDataTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    func get(key: ValueBoxKey) -> PreferencesEntry? {
        if let value = self.valueBox.get(self.table, key: key), let object = PostboxDecoder(buffer: value).decodeRootObject() as? PreferencesEntry {
            return object
        } else {
            return nil
        }
    }
    
    func set(key: ValueBoxKey, value: PreferencesEntry?, updatedKeys: inout Set<ValueBoxKey>) {
        if let value = value {
            if let current = self.get(key: key), current.isEqual(to: value) {
                return
            }
            let encoder = PostboxEncoder()
            encoder.encodeRootObject(value)
            self.valueBox.set(self.table, key: key, value: encoder.makeReadBufferAndReset())
            updatedKeys.insert(key)
        } else if self.get(key: key) != nil {
            self.valueBox.remove(self.table, key: key, secure: false)
            updatedKeys.insert(key)
        }
    }
}

