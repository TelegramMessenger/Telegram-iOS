import Foundation

final class GlobalMessageIdsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    let sharedKey = ValueBoxKey(length: 8)
    let sharedBuffer = WriteBuffer()
    
    private func key(_ id: Int32) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: Int64(id))
        return self.sharedKey
    }
    
    func set(_ globalId: Int32, id: MessageId) {
        assert(id.namespace == 0)
        assert(id.peerId.namespace == 0 || id.peerId.namespace == 1)
        
        self.sharedBuffer.reset()
        var idPeerId: Int64 = id.peerId.toInt64()
        var idNamespace: Int32 = id.namespace
        self.sharedBuffer.write(&idPeerId, offset: 0, length: 8)
        self.sharedBuffer.write(&idNamespace, offset: 0, length: 4)
        self.valueBox.set(self.table, key: self.key(globalId), value: self.sharedBuffer)
    }
    
    func get(_ globalId: Int32) -> MessageId? {
        if let value = self.valueBox.get(self.table, key: self.key(globalId)) {
            var idPeerId: Int64 = 0
            var idNamespace: Int32 = 0
            value.read(&idPeerId, offset: 0, length: 8)
            value.read(&idNamespace, offset: 0, length: 4)
            return MessageId(peerId: PeerId(idPeerId), namespace: idNamespace, id: globalId)
        }
        return nil
    }
    
    func remove(_ globalId: Int32) {
        self.valueBox.remove(self.table, key: self.key(globalId))
    }
}
