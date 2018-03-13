import Foundation

public protocol DeviceContactImportIdentifier: PostboxCoding {
    var key: ValueBoxKey { get }
}

final class DeviceContactImportInfoTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    func get(_ identifier: DeviceContactImportIdentifier) -> PostboxCoding? {
        if let value = self.valueBox.get(self.table, key: identifier.key), let object = PostboxDecoder(buffer: value).decodeRootObject() {
            return object
        } else {
            return nil
        }
    }
    
    func set(_ identifier: DeviceContactImportIdentifier, value: PostboxCoding?) {
        if let value = value {
            let encoder = PostboxEncoder()
            encoder.encodeRootObject(value)
            withExtendedLifetime(encoder, {
                self.valueBox.set(self.table, key: identifier.key, value: encoder.readBufferNoCopy())
            })
        } else {
            self.valueBox.remove(self.table, key: identifier.key)
        }
    }
}
