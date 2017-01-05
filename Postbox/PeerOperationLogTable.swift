import Foundation

public enum PeerOperationLogTag: Int8 {
    case inbox = 0
    case outbox = 1
}

public struct PeerOperationLogEntry {
    let tagLocalIndex: Int32
    let contents: Coding
}

final class PeerOperationLogQueue: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    private let metadataTable: PeerOperationLogMetadataTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, metadataTable: PeerOperationLogMetadataTable) {
        self.metadataTable = metadataTable
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(peerId: PeerId, tag: PeerOperationLogTag, index: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 1 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt8(1, value: tag.rawValue)
        key.setInt32(9, value: index)
        return key
    }
    
    func addEntryAndTakeNextTagLocalIndex(peerId: PeerId, tag: PeerOperationLogTag, contents: Coding) -> Int32 {
        let index = self.metadataTable.takeNextLocalIndex(peerId: peerId, tag: tag)
        let encoder = Encoder()
        encoder.encodeRootObject(contents)
        self.valueBox.set(self.table, key: self.key(peerId: peerId, tag: tag, index: index), value: encoder.readBufferNoCopy())
        return index
    }
    
    func removeEntries(peerId: PeerId, tag: PeerOperationLogTag, withIndicesLowerThan index: Int32) {
        var indices: [Int32] = []
        self.valueBox.range(self.table, start: self.key(peerId: peerId, tag: tag, index: 0).predecessor, end: self.key(peerId: peerId, tag: tag, index: index), keys: { key in
            indices.append(key.getInt32(9))
            return true
        }, limit: 0)
        
        for index in indices {
            self.valueBox.remove(self.table, key: self.key(peerId: peerId, tag: tag, index: index))
        }
    }
}
