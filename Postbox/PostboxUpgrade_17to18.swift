import Foundation

private func convertNamespaces(value: ReadBuffer, buffer: WriteBuffer) {
    var count: Int32 = 0
    value.read(&count, offset: 0, length: 4)
    buffer.write(&count, offset: 0, length: 4)
    for _ in 0 ..< count {
        var namespaceId: Int32 = 0
        value.read(&namespaceId, offset: 0, length: 4)
        buffer.write(&namespaceId, offset: 0, length: 4)
        
        var kind: Int8 = 0
        value.read(&kind, offset: 0, length: 1)
        buffer.write(&kind, offset: 0, length: 1)
        if kind == 0 {
            var maxIncomingReadId: Int32 = 0
            var maxOutgoingReadId: Int32 = 0
            var maxKnownId: Int32 = 0
            var count: Int32 = 0
            
            value.read(&maxIncomingReadId, offset: 0, length: 4)
            buffer.write(&maxIncomingReadId, offset: 0, length: 4)
            value.read(&maxOutgoingReadId, offset: 0, length: 4)
            buffer.write(&maxOutgoingReadId, offset: 0, length: 4)
            value.read(&maxKnownId, offset: 0, length: 4)
            buffer.write(&maxKnownId, offset: 0, length: 4)
            value.read(&count, offset: 0, length: 4)
            buffer.write(&count, offset: 0, length: 4)
            
            var flags: Int32 = 0
            buffer.write(&flags, offset: 0, length: 4)
        } else {
            var maxIncomingReadTimestamp: Int32 = 0
            var maxIncomingReadIdPeerId: Int64 = 0
            var maxIncomingReadIdNamespace: Int32 = 0
            var maxIncomingReadIdId: Int32 = 0
            
            var maxOutgoingReadTimestamp: Int32 = 0
            var maxOutgoingReadIdPeerId: Int64 = 0
            var maxOutgoingReadIdNamespace: Int32 = 0
            var maxOutgoingReadIdId: Int32 = 0
            
            var count: Int32 = 0
            
            value.read(&maxIncomingReadTimestamp, offset: 0, length: 4)
            buffer.write(&maxIncomingReadTimestamp, offset: 0, length: 4)
            value.read(&maxIncomingReadIdPeerId, offset: 0, length: 8)
            buffer.write(&maxIncomingReadIdPeerId, offset: 0, length: 8)
            value.read(&maxIncomingReadIdNamespace, offset: 0, length: 4)
            buffer.write(&maxIncomingReadIdNamespace, offset: 0, length: 4)
            value.read(&maxIncomingReadIdId, offset: 0, length: 4)
            buffer.write(&maxIncomingReadIdId, offset: 0, length: 4)
            
            value.read(&maxOutgoingReadTimestamp, offset: 0, length: 4)
            buffer.write(&maxOutgoingReadTimestamp, offset: 0, length: 4)
            value.read(&maxOutgoingReadIdPeerId, offset: 0, length: 8)
            buffer.write(&maxOutgoingReadIdPeerId, offset: 0, length: 8)
            value.read(&maxOutgoingReadIdNamespace, offset: 0, length: 4)
            buffer.write(&maxOutgoingReadIdNamespace, offset: 0, length: 4)
            value.read(&maxOutgoingReadIdId, offset: 0, length: 4)
            buffer.write(&maxOutgoingReadIdId, offset: 0, length: 4)
            
            value.read(&count, offset: 0, length: 4)
            buffer.write(&count, offset: 0, length: 4)
            
            var flags: Int32 = 0
            buffer.write(&flags, offset: 0, length: 4)
        }
    }
}

func postboxUpgrade_17to18(metadataTable: MetadataTable, valueBox: ValueBox, progress: (Float) -> Void) {
    var converted: [Int64: Data] = [:]
    
    let readStateTable = ValueBoxTable(id: 14, keyType: .int64, compactValuesOnCreation: false)
    let buffer = WriteBuffer()
    valueBox.scanInt64(readStateTable, values: { key, value in
        buffer.reset()
        convertNamespaces(value: value, buffer: buffer)
        converted[key] = buffer.makeData()
        return true
    })
    
    valueBox.removeAllFromTable(readStateTable)
    let key = ValueBoxKey(length: 8)
    for (int64key, data) in converted {
        key.setInt64(0, value: int64key)
        valueBox.set(readStateTable, key: key, value: MemoryBuffer(data: data))
    }
    
    metadataTable.setUserVersion(18)
}
