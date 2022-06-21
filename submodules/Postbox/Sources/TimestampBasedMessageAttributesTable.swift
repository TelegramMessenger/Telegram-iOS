import Foundation

public struct TimestampBasedMessageAttributesEntry: CustomStringConvertible {
    public let tag: UInt16
    public let timestamp: Int32
    public let messageId: MessageId
    
    public var index: MessageIndex {
        return MessageIndex(id: self.messageId, timestamp: timestamp)
    }

    public var description: String {
        return "(tag: \(self.tag), timestamp: \(self.timestamp), messageId: \(self.messageId))"
    }
}

enum TimestampBasedMessageAttributesOperation {
    case add(TimestampBasedMessageAttributesEntry)
    case remove(TimestampBasedMessageAttributesEntry)
}

final class TimestampBasedMessageAttributesTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let indexTable: TimestampBasedMessageAttributesIndexTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, indexTable: TimestampBasedMessageAttributesIndexTable) {
        self.indexTable = indexTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(tag: UInt16, timestamp: Int32, id: MessageId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 2 + 4 + 8 + 4 + 4)
        key.setUInt16(0, value: tag)
        key.setInt32(2, value: timestamp)
        key.setInt64(2 + 4, value: id.peerId.toInt64())
        key.setInt32(2 + 4 + 8, value: id.namespace)
        key.setInt32(2 + 4 + 8 + 4, value: id.id)
        return key
    }
    
    private func lowerBound(tag: UInt16) -> ValueBoxKey {
        let key = ValueBoxKey(length: 3)
        key.setUInt16(0, value: tag)
        key.setInt8(2, value: 0)
        return key
    }
    
    private func upperBound(tag: UInt16) -> ValueBoxKey {
        let key = ValueBoxKey(length: 3)
        key.setUInt16(0, value: tag + 1)
        key.setInt8(2, value: 0)
        return key
    }
    
    func set(tag: UInt16, id: MessageId, timestamp: Int32, operations: inout [TimestampBasedMessageAttributesOperation]) {
        let previousTimestamp = self.indexTable.get(tag: tag, id: id)

        postboxLog("TimestampBasedMessageAttributesTable set(tag: \(tag), id: \(id), timestamp: \(timestamp)) previousTimestamp: \(String(describing: previousTimestamp))")

        if let previousTimestamp = previousTimestamp {
            if previousTimestamp == timestamp {
                return
            } else {
                self.valueBox.remove(self.table, key: self.key(tag: tag, timestamp: previousTimestamp, id: id), secure: false)
                operations.append(.remove(TimestampBasedMessageAttributesEntry(tag: tag, timestamp: previousTimestamp, messageId: id)))
            }
        }
        self.valueBox.set(self.table, key: self.key(tag: tag, timestamp: timestamp, id: id), value: MemoryBuffer())
        self.indexTable.set(tag: tag, id: id, timestamp: timestamp)
        operations.append(.add(TimestampBasedMessageAttributesEntry(tag: tag, timestamp: timestamp, messageId: id)))
    }
    
    func remove(tag: UInt16, id: MessageId, operations: inout [TimestampBasedMessageAttributesOperation]) {
        let previousTimestamp = self.indexTable.get(tag: tag, id: id)

        postboxLog("TimestampBasedMessageAttributesTable remove(tag: \(tag), id: \(id)) previousTimestamp: \(String(describing: previousTimestamp))")

        if let previousTimestamp = previousTimestamp {
            self.valueBox.remove(self.table, key: self.key(tag: tag, timestamp: previousTimestamp, id: id), secure: false)
            self.indexTable.remove(tag: tag, id: id)
        }
        
        operations.append(.remove(TimestampBasedMessageAttributesEntry(tag: tag, timestamp: previousTimestamp ?? 0, messageId: id)))
    }
    
    func head(tag: UInt16) -> TimestampBasedMessageAttributesEntry? {
        var result: TimestampBasedMessageAttributesEntry?
        self.valueBox.range(self.table, start: self.lowerBound(tag: tag), end: self.upperBound(tag: tag), keys: { key in
            let timestamp = key.getInt32(2)
            let idPeerId = key.getInt64(2 + 4)
            let idNamespace = key.getInt32(2 + 4 + 8)
            let idId = key.getInt32(2 + 4 + 8 + 4)
            result = TimestampBasedMessageAttributesEntry(tag: tag, timestamp: timestamp, messageId: MessageId(peerId: PeerId(idPeerId), namespace: idNamespace, id: idId))
            return false
        }, limit: 1)
        return result
    }
}
