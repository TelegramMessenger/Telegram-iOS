import Foundation

private enum MetadataKey: Int32 {
    case UserVersion = 1
    case State = 2
}

final class MetadataTable: Table {
    override init(valueBox: ValueBox, tableId: Int32) {
        super.init(valueBox: valueBox, tableId: tableId)
    }
    
    private func key(_ key: MetadataKey) -> ValueBoxKey {
        let valueBoxKey = ValueBoxKey(length: 4)
        valueBoxKey.setInt32(0, value: key.rawValue)
        return valueBoxKey
    }
    
    func userVersion() -> Int32? {
        if let value = self.valueBox.get(self.tableId, key: self.key(.UserVersion)) {
            var version: Int32 = 0
            value.read(&version, offset: 0, length: 4)
            return version
        }
        return nil
    }
    
    func setUserVersion(_ version: Int32) {
        let buffer = WriteBuffer()
        var varVersion: Int32 = version
        buffer.write(&varVersion, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(.UserVersion), value: buffer)
    }
    
    func state() -> Coding? {
        if let value = self.valueBox.get(self.tableId, key: self.key(.State)) {
            if let state = Decoder(buffer: value).decodeRootObject() {
                return state
            }
        }
        return nil
    }
    
    func setState(_ state: Coding) {
        let encoder = Encoder()
        encoder.encodeRootObject(state)
        self.valueBox.set(self.tableId, key: self.key(.State), value: encoder.readBufferNoCopy())
    }
}
