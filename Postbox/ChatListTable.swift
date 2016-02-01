import Foundation

enum ChatListOperation {
    case InsertMessage(IntermediateMessage)
    case InsertNothing(MessageIndex)
    case Remove([MessageIndex])
}

enum ChatListIntermediateEntry {
    case Message(IntermediateMessage)
    case Nothing(MessageIndex)
}

final class ChatListTable {
    let valueBox: ValueBox
    let tableId: Int32
    let indexTable: ChatListIndexTable
    
    init(valueBox: ValueBox, tableId: Int32, indexTable: ChatListIndexTable) {
        self.valueBox = valueBox
        self.tableId = tableId
        self.indexTable = indexTable
    }
    
    private func key(index: MessageIndex) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 4 + 4 + 8)
        key.setInt32(0, value: index.timestamp)
        key.setInt32(4, value: index.id.namespace)
        key.setInt32(4 + 4, value: index.id.id)
        key.setInt64(4 + 4 + 4, value: index.id.peerId.toInt64())
        return key
    }
    
    private func lowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: 0)
        return key
    }
    
    private func upperBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: Int32.max)
        return key
    }
    
    func replay(historyOperationsByPeerId: [PeerId : [MessageHistoryOperation]], messageHistoryTable: MessageHistoryTable, inout operations: [ChatListOperation]) {
        for (peerId, _) in historyOperationsByPeerId {
            let currentIndex: MessageIndex? = self.indexTable.get(peerId)
            if let topMessage = messageHistoryTable.topMessage(peerId) {
                let index = MessageIndex(id: topMessage.id, timestamp: topMessage.timestamp)
                
                if let currentIndex = currentIndex where currentIndex != index {
                    self.justRemove(currentIndex)
                }
                if let currentIndex = currentIndex {
                    operations.append(.Remove([currentIndex]))
                }
                self.indexTable.set(index)
                self.justInsert(index)
                operations.append(.InsertMessage(topMessage))
            } else {
                if let currentIndex = currentIndex {
                    operations.append(.Remove([currentIndex]))
                    operations.append(.InsertNothing(currentIndex))
                }
            }
        }
    }
    
    func justInsert(index: MessageIndex) {
        self.valueBox.set(self.tableId, key: self.key(index), value: MemoryBuffer(memory: nil, capacity: 0, length: 0, freeWhenDone: false))
    }
    
    func justRemove(index: MessageIndex) {
        self.valueBox.remove(self.tableId, key: self.key(index))
    }
    
    func entriesAround(index: MessageIndex, messageHistoryTable: MessageHistoryTable, count: Int) -> [ChatListIntermediateEntry] {
        var lowerEntries: [ChatListIntermediateEntry] = []
        
        self.valueBox.range(self.tableId, start: self.key(index).successor, end: self.lowerBound(), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0))
            if let message = messageHistoryTable.getMessage(index) {
                lowerEntries.append(.Message(message))
            } else {
                lowerEntries.append(.Nothing(index))
            }
            return true
        }, limit: count)
        
        var upperEntries: [ChatListIntermediateEntry] = []
        self.valueBox.range(self.tableId, start: self.key(index), end: self.upperBound(), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0))
            if let message = messageHistoryTable.getMessage(index) {
                upperEntries.append(.Message(message))
            } else {
                upperEntries.append(.Nothing(index))
            }
            return true
        }, limit: count)
        
        var entries: [ChatListIntermediateEntry] = []
        for entry in lowerEntries.reverse() {
            entries.append(entry)
        }
        entries.appendContentsOf(upperEntries)
        
        return entries
    }
    
    func earlierEntries(index: MessageIndex?, messageHistoryTable: MessageHistoryTable, count: Int) -> [ChatListIntermediateEntry] {
        var entries: [ChatListIntermediateEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(index)
        } else {
            key = self.upperBound()
        }
        
        self.valueBox.range(self.tableId, start: key, end: self.lowerBound(), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0))
            if let message = messageHistoryTable.getMessage(index) {
                entries.append(.Message(message))
            } else {
                entries.append(.Nothing(index))
            }
            return true
        }, limit: count)
        return entries
    }
    
    func laterEntries(index: MessageIndex?, messageHistoryTable: MessageHistoryTable, count: Int) -> [ChatListIntermediateEntry] {
        var entries: [ChatListIntermediateEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(index)
        } else {
            key = self.lowerBound()
        }
        
        self.valueBox.range(self.tableId, start: key, end: self.upperBound(), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0))
            if let message = messageHistoryTable.getMessage(index) {
                entries.append(.Message(message))
            } else {
                entries.append(.Nothing(index))
            }
            return true
        }, limit: count)
        return entries
    }
    
    func debugList(messageHistoryTable: MessageHistoryTable) -> [ChatListIntermediateEntry] {
        return self.entriesAround(MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: 0), timestamp: 0), messageHistoryTable: messageHistoryTable, count: 1000)
    }
}
