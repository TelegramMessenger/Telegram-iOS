import Foundation

final class GlobalMessageIdsTable: Table {
    let namespace: Int32
    
    let sharedKey = ValueBoxKey(length: 4)
    let sharedBuffer = WriteBuffer()
    
    init(valueBox: ValueBox, tableId: Int32, namespace: Int32) {
        self.namespace = namespace
        
        super.init(valueBox: valueBox, tableId: tableId)
    }
    
    private func key(_ id: Int32) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: id)
        return self.sharedKey
    }
    
    func set(_ globalId: Int32, id: MessageId) {
        self.sharedBuffer.reset()
        var idPeerId: Int64 = id.peerId.toInt64()
        var idNamespace: Int32 = id.namespace
        self.sharedBuffer.write(&idPeerId, offset: 0, length: 8)
        self.sharedBuffer.write(&idNamespace, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(globalId), value: self.sharedBuffer)
    }
    
    func get(_ globalId: Int32) -> MessageId? {
        if let value = self.valueBox.get(self.tableId, key: self.key(globalId)) {
            var idPeerId: Int64 = 0
            var idNamespace: Int32 = 0
            value.read(&idPeerId, offset: 0, length: 8)
            value.read(&idNamespace, offset: 0, length: 4)
            return MessageId(peerId: PeerId(idPeerId), namespace: idNamespace, id: globalId)
        }
        return nil
    }
    
    func remove(_ globalId: Int32) {
        self.valueBox.remove(self.tableId, key: self.key(globalId))
    }
}
