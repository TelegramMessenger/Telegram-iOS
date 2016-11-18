import Foundation

final class ChatListIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private func key(_ peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    func set(_ index: MessageIndex) {
        let writeBuffer = WriteBuffer()
        var idNamespace: Int32 = index.id.namespace
        var idId: Int32 = index.id.id
        var idTimestamp: Int32 = index.timestamp
        writeBuffer.write(&idNamespace, offset: 0, length: 4)
        writeBuffer.write(&idId, offset: 0, length: 4)
        writeBuffer.write(&idTimestamp, offset: 0, length: 4)
        self.valueBox.set(self.table, key: self.key(index.id.peerId), value: writeBuffer.readBufferNoCopy())
    }
    
    func remove(_ peerId: PeerId) {
        self.valueBox.remove(self.table, key: self.key(peerId))
    }
    
    func get(_ peerId: PeerId) -> MessageIndex? {
        if let value = self.valueBox.get(self.table, key: self.key(peerId)) {
            var idNamespace: Int32 = 0
            var idId: Int32 = 0
            var idTimestamp: Int32 = 0
            value.read(&idNamespace, offset: 0, length: 4)
            value.read(&idId, offset: 0, length: 4)
            value.read(&idTimestamp, offset: 0, length: 4)
            return MessageIndex(id: MessageId(peerId: peerId, namespace: idNamespace, id: idId), timestamp: idTimestamp)
        }
        return nil
    }
}
