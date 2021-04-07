import Foundation

final class DeviceContactImportInfoTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    func get(_ identifier: ValueBoxKey) -> PostboxCoding? {
        if let value = self.valueBox.get(self.table, key: identifier), let object = PostboxDecoder(buffer: value).decodeRootObject() {
            return object
        } else {
            return nil
        }
    }
    
    func set(_ identifier: ValueBoxKey, value: PostboxCoding?) {
        if let value = value {
            let encoder = PostboxEncoder()
            encoder.encodeRootObject(value)
            withExtendedLifetime(encoder, {
                self.valueBox.set(self.table, key: identifier, value: encoder.readBufferNoCopy())
            })
        } else {
            self.valueBox.remove(self.table, key: identifier, secure: false)
        }
    }
    
    func getIdentifiers() -> [ValueBoxKey] {
        var result: [ValueBoxKey] = []
        self.valueBox.scan(self.table, keys: { key in
            result.append(key)
            return true
        })
        return result
    }
    
    func enumerateDeviceContactImportInfoItems(_ f: (ValueBoxKey, PostboxCoding) -> Bool) {
        self.valueBox.scan(self.table, values: { key, value in
            if let object = PostboxDecoder(buffer: value).decodeRootObject() {
                return f(key, object)
            } else {
                return true
            }
        })
    }
}
