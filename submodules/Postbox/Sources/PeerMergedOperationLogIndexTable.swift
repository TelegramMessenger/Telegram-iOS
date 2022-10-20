import Foundation

final class PeerMergedOperationLogIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let metadataTable: PeerOperationLogMetadataTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, metadataTable: PeerOperationLogMetadataTable) {
        self.metadataTable = metadataTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(tag: PeerOperationLogTag, index: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 5)
        key.setUInt8(0, value: tag.rawValue)
        key.setInt32(1, value: index)
        return key
    }
    
    func add(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32) -> Int32 {
        let index = self.metadataTable.takeNextMergedIndex()
        let buffer = WriteBuffer()
        var peerIdValue: Int64 = peerId.toInt64()
        var tagLocalIndexValue: Int32 = tagLocalIndex
        buffer.write(&peerIdValue, offset: 0, length: 8)
        buffer.write(&tagLocalIndexValue, offset: 0, length: 4)
        self.valueBox.set(self.table, key: self.key(tag: tag, index: index), value: buffer)
        return index
    }
    
    func remove(tag: PeerOperationLogTag, mergedIndices: [Int32]) {
        for index in mergedIndices {
            assert(self.valueBox.exists(self.table, key: self.key(tag: tag, index: index)))
            self.valueBox.remove(self.table, key: self.key(tag: tag, index: index), secure: false)
        }
    }
    
    func getTagLocalIndices(tag: PeerOperationLogTag, fromMergedIndex: Int32, limit: Int) -> [(PeerId, Int32, Int32)] {
        var result: [(PeerId, Int32, Int32)] = []
        self.valueBox.range(self.table, start: self.key(tag: tag, index: fromMergedIndex == 0 ? 0 : fromMergedIndex - 1), end: self.key(tag: tag, index: Int32.max), values: { key, value in
            assert(key.getUInt8(0) == tag.rawValue)
            var peerIdValue: Int64 = 0
            var tagLocalIndexValue: Int32 = 0
            value.read(&peerIdValue, offset: 0, length: 8)
            value.read(&tagLocalIndexValue, offset: 0, length: 4)
            result.append((PeerId(peerIdValue), tagLocalIndexValue, key.getInt32(1)))
            return true
        }, limit: limit)
        return result
    }
    
    func tailIndex(tag: PeerOperationLogTag) -> Int32? {
        var result: Int32?
        self.valueBox.range(self.table, start: self.key(tag: tag, index: Int32.max), end: self.key(tag: tag, index: 0), keys: {
            key in
            result = key.getInt32(1)
            return false
        }, limit: 1)
        return result
    }
}
