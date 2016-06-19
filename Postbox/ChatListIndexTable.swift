import Foundation

final class ChatListIndexTable: Table {
    override init(valueBox: ValueBox, tableId: Int32) {
        super.init(valueBox: valueBox, tableId: tableId)
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
        self.valueBox.set(self.tableId, key: self.key(index.id.peerId), value: writeBuffer.readBufferNoCopy())
    }
    
    func remove(_ peerId: PeerId) {
        self.valueBox.remove(self.tableId, key: self.key(peerId))
    }
    
    func get(_ peerId: PeerId) -> MessageIndex? {
        if let value = self.valueBox.get(self.tableId, key: self.key(peerId)) {
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
