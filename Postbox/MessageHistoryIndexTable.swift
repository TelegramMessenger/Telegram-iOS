import Foundation

enum HistoryIndexEntry {
    case Message(MessageIndex)
    case Hole(MessageHistoryHole)
    
    var index: MessageIndex {
        switch self {
            case let .Message(index):
                return index
            case let .Hole(hole):
                return hole.maxIndex
        }
    }
}

public enum HoleFillType {
    case UpperToLower
    case LowerToUpper
    case Complete
}

public enum AddMessagesLocation {
    case Random
    case UpperHistoryBlock
}

enum MessageHistoryIndexOperation {
    case InsertMessage(StoreMessage)
    case InsertHole(MessageHistoryHole)
    case Remove(MessageIndex)
}

private func readHistoryIndexEntry(peerId: PeerId, namespace: MessageId.Namespace, key: ValueBoxKey, value: ReadBuffer) -> HistoryIndexEntry {
    var type: Int8 = 0
    value.read(&type, offset: 0, length: 1)
    var timestamp: Int32 = 0
    value.read(&timestamp, offset: 0, length: 4)
    let index = MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: key.getInt32(8 + 4)), timestamp: timestamp)
    
    if type == 0 {
        return .Message(index)
    } else {
        var min: Int32 = 0
        value.read(&min, offset: 0, length: 4)
        return .Hole(MessageHistoryHole(maxIndex: index, min: min))
    }
}

final class MessageHistoryIndexTable {
    let valueBox: ValueBox
    let tableId: Int32
    let globalMessageIdsNamespace: Int32
    let globalMessageIdsTable: GlobalMessageIdsTable
    
    init(valueBox: ValueBox, tableId: Int32, globalMessageIdsTable: GlobalMessageIdsTable) {
        self.valueBox = valueBox
        self.tableId = tableId
        self.globalMessageIdsTable = globalMessageIdsTable
        self.globalMessageIdsNamespace = globalMessageIdsTable.namespace
    }
    
    private func key(id: MessageId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4 + 4)
        key.setInt64(0, value: id.peerId.toInt64())
        key.setInt32(8, value: id.namespace)
        key.setInt32(8 + 4, value: id.id)
        return key
    }
    
    private func lowerBound(peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key
    }
    
    private func upperBound(peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key.successor
    }
    
    func addHole(id: MessageId, inout operations: [MessageHistoryIndexOperation]) {
        let adjacent = self.adjacentItems(id)
        
        if let lowerItem = adjacent.lower, upperItem = adjacent.upper {
            switch lowerItem {
                case .Hole:
                    break
                case let .Message(lowerMessage):
                    switch upperItem {
                        case .Hole:
                            break
                        case let .Message(upperMessage):
                            if lowerMessage.id.id < upperMessage.id.id - 1 {
                                self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: upperMessage.id.id - 1), timestamp: upperMessage.timestamp), min: lowerMessage.id.id + 1), operations: &operations)
                            }
                            break
                    }
            }
        } else if let lowerItem = adjacent.lower {
            switch lowerItem {
                case let .Message(lowerMessage):
                    self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: Int32.max), timestamp: Int32.max), min: lowerMessage.id.id + 1), operations: &operations)
                case .Hole:
                    break
            }
        } else if let upperItem = adjacent.upper {
            switch upperItem {
                case let .Message(upperMessage):
                    if upperMessage.id.id > 1 {
                        self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: upperMessage.id.id - 1), timestamp: upperMessage.timestamp), min: 1), operations: &operations)
                    }
                case .Hole:
                    break
            }
        } else {
            self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: Int32.max), timestamp: Int32.max), min: 1), operations: &operations)
        }
    }
    
    func addMessages(messages: [StoreMessage], location: AddMessagesLocation, inout operations: [MessageHistoryIndexOperation]) {
        if messages.count == 0 {
            return
        }
        
        switch location {
            case .UpperHistoryBlock:
                var lowerIds = SimpleDictionary<PeerId, SimpleDictionary<MessageId.Namespace, MessageIndex>>()
                for message in messages {
                    if lowerIds[message.id.peerId] == nil {
                        var dict = SimpleDictionary<MessageId.Namespace, MessageIndex>()
                        dict[message.id.namespace] = MessageIndex(id: message.id, timestamp: message.timestamp)
                        lowerIds[message.id.peerId] = dict
                    } else {
                        let lowerIndex = lowerIds[message.id.peerId]![message.id.namespace]
                        if lowerIndex == nil || lowerIndex!.id.id > message.id.id {
                            lowerIds[message.id.peerId]![message.id.namespace] = MessageIndex(id: message.id, timestamp: message.timestamp)
                        }
                    }
                }
                
                for (peerId, lowerIdsByNamespace) in lowerIds {
                    for (namespace, lowerIndex) in lowerIdsByNamespace {
                        var removeHoles: [MessageIndex] = []
                        var modifyHole: (MessageIndex, MessageHistoryHole)?
                        self.valueBox.range(self.tableId, start: self.key(MessageId(peerId: peerId, namespace: namespace, id: lowerIndex.id.id)), end: self.upperBound(peerId, namespace: namespace), values: { key, value in
                            let entry = readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value)
                            if case let .Hole(hole) = entry {
                                if lowerIndex.id.id <= hole.min {
                                    removeHoles.append(hole.maxIndex)
                                } else {
                                    modifyHole = (hole.maxIndex, MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: lowerIndex.id.id - 1), timestamp: lowerIndex.timestamp), min: hole.min))
                                }
                            }
                            return true
                        }, limit: 0)
                        
                        for index in removeHoles {
                            self.justRemove(index, operations: &operations)
                        }
                        
                        if let modifyHole = modifyHole {
                            self.justRemove(modifyHole.0, operations: &operations)
                            self.justInsertHole(modifyHole.1, operations: &operations)
                        }
                    }
                }
            case .Random:
                break
        }
        
        for message in messages {
            let index = MessageIndex(id: message.id, timestamp: message.timestamp)
            
            var upperItem: HistoryIndexEntry?
            self.valueBox.range(self.tableId, start: self.key(index.id).predecessor, end: self.upperBound(index.id.peerId, namespace: index.id.namespace), values: { key, value in
                upperItem = readHistoryIndexEntry(index.id.peerId, namespace: index.id.namespace, key: key, value: value)
                return true
            }, limit: 1)
            
            var exists = false
            
            if let upperItem = upperItem {
                switch upperItem {
                    case let .Hole(upperHole):
                        self.justRemove(upperHole.maxIndex, operations: &operations)
                        if upperHole.maxIndex.id.id > index.id.id + 1 {
                            self.justInsertHole(MessageHistoryHole(maxIndex: upperHole.maxIndex, min: index.id.id + 1), operations: &operations)
                        }
                        if upperHole.min <= index.id.id - 1 {
                            self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: index.id.peerId, namespace: index.id.namespace, id: index.id.id - 1), timestamp: index.timestamp), min: upperHole.min), operations: &operations)
                        }
                    case let .Message(messageIndex):
                        if messageIndex.id == index.id {
                            exists = true
                        }
                }
            }
            
            if !exists {
                self.justInsertMessage(message, operations: &operations)
            }
        }
    }
    
    func removeMessage(id: MessageId, inout operations: [MessageHistoryIndexOperation]) {
        if let existingEntry = self.get(id) {
            self.justRemove(existingEntry.index, operations: &operations)
            
            let adjacent = self.adjacentItems(id)
            
            if let lowerItem = adjacent.lower, upperItem = adjacent.upper {
                switch lowerItem {
                    case let .Message(lowerMessage):
                        switch upperItem {
                            case let .Hole(upperHole):
                                self.justRemove(upperHole.maxIndex, operations: &operations)
                                self.justInsertHole(MessageHistoryHole(maxIndex: upperHole.maxIndex, min: lowerMessage.id.id + 1), operations: &operations)
                            case .Message:
                                break
                        }
                    case let .Hole(lowerHole):
                        switch upperItem {
                            case let .Hole(upperHole):
                                self.justRemove(lowerHole.maxIndex, operations: &operations)
                                self.justRemove(upperHole.maxIndex, operations: &operations)
                                self.justInsertHole(MessageHistoryHole(maxIndex: upperHole.maxIndex, min: lowerHole.min), operations: &operations)
                            case let .Message(upperMessage):
                                self.justRemove(lowerHole.maxIndex, operations: &operations)
                                self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: upperMessage.id.id - 1), timestamp: upperMessage.timestamp), min: lowerHole.min), operations: &operations)
                        }
                }
            } else if let lowerItem = adjacent.lower {
                switch lowerItem {
                    case let .Hole(lowerHole):
                        self.justRemove(lowerHole.maxIndex, operations: &operations)
                        self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: Int32.max), timestamp: Int32.max), min: lowerHole.min), operations: &operations)
                        break
                    case .Message:
                        break
                }
            } else if let upperItem = adjacent.upper {
                switch upperItem {
                    case let .Hole(upperHole):
                        self.justRemove(upperHole.maxIndex, operations: &operations)
                        self.justInsertHole(MessageHistoryHole(maxIndex: upperHole.maxIndex, min: 1), operations: &operations)
                        break
                    case .Message:
                        break
                }
            }
        }
    }
    
    func fillHole(id: MessageId, fillType: HoleFillType, messages: [StoreMessage], inout operations: [MessageHistoryIndexOperation]) {
        var upperItem: HistoryIndexEntry?
        self.valueBox.range(self.tableId, start: self.key(id).predecessor, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            upperItem = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        let sortedByIdMessages = messages.sort({$0.id < $1.id})
        var remainingMessages = sortedByIdMessages
        
        if let upperItem = upperItem {
            switch upperItem {
                case let .Hole(upperHole):
                    var i = 0
                    var minMessageInRange: StoreMessage?
                    var maxMessageInRange: StoreMessage?
                    var removedHole = false
                    while i < remainingMessages.count {
                        let message = remainingMessages[i]
                        if message.id.id >= upperHole.min && message.id.id <= upperHole.maxIndex.id.id {
                            if (fillType == .UpperToLower || fillType == .Complete) && (minMessageInRange == nil || minMessageInRange!.id > message.id) {
                                minMessageInRange = message
                                if !removedHole {
                                    removedHole = true
                                    self.justRemove(upperHole.maxIndex, operations: &operations)
                                }
                            }
                            if (fillType == .LowerToUpper || fillType == .Complete) && (maxMessageInRange == nil || maxMessageInRange!.id < message.id) {
                                maxMessageInRange = message
                                if !removedHole {
                                    removedHole = true
                                    self.justRemove(upperHole.maxIndex, operations: &operations)
                                }
                            }
                            self.justInsertMessage(message, operations: &operations)
                            remainingMessages.removeAtIndex(i)
                        } else {
                            i++
                        }
                    }
                    switch fillType {
                        case .Complete:
                            if !removedHole {
                                self.justRemove(upperHole.maxIndex, operations: &operations)
                            }
                        case .LowerToUpper:
                            if let maxMessageInRange = maxMessageInRange where maxMessageInRange.id.id != Int32.max && maxMessageInRange.id.id + 1 <= upperHole.maxIndex.id.id {
                                self.justInsertHole(MessageHistoryHole(maxIndex: upperHole.maxIndex, min: maxMessageInRange.id.id + 1), operations: &operations)
                            }
                        case .UpperToLower:
                            if let minMessageInRange = minMessageInRange where minMessageInRange.id.id - 1 >= upperHole.min {
                                self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: minMessageInRange.id.id - 1), timestamp: minMessageInRange.timestamp), min: upperHole.min), operations: &operations)
                            }
                    }
                    break
                case .Message:
                    break
            }
        }
        
        for message in remainingMessages {
            self.addMessages([message], location: .Random, operations: &operations)
        }
    }
    
    func justInsertHole(hole: MessageHistoryHole, inout operations: [MessageHistoryIndexOperation]) {
        let value = WriteBuffer()
        var type: Int8 = 1
        var timestamp: Int32 = hole.maxIndex.timestamp
        var min: Int32 = hole.min
        value.write(&type, offset: 0, length: 1)
        value.write(&timestamp, offset: 0, length: 4)
        value.write(&min, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(hole.id), value: value)
        
        operations.append(.InsertHole(hole))
    }
    
    func justInsertMessage(message: StoreMessage, inout operations: [MessageHistoryIndexOperation]) {
        let index = MessageIndex(id: message.id, timestamp: message.timestamp)
        
        let value = WriteBuffer()
        var type: Int8 = 0
        var timestamp: Int32 = index.timestamp
        value.write(&type, offset: 0, length: 1)
        value.write(&timestamp, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(index.id), value: value)
        
        operations.append(.InsertMessage(message))
        if index.id.namespace == self.globalMessageIdsNamespace {
            self.globalMessageIdsTable.set(index.id.id, id: index.id)
        }
    }
    
    func justRemove(index: MessageIndex, inout operations: [MessageHistoryIndexOperation]) {
        self.valueBox.remove(self.tableId, key: self.key(index.id))
        
        operations.append(.Remove(index))
        if index.id.namespace == self.globalMessageIdsNamespace {
            self.globalMessageIdsTable.remove(index.id.id)
        }
    }
    
    func adjacentItems(id: MessageId) -> (lower: HistoryIndexEntry?, upper: HistoryIndexEntry?) {
        let key = self.key(id)
        
        var lowerItem: HistoryIndexEntry?
        self.valueBox.range(self.tableId, start: key, end: self.lowerBound(id.peerId, namespace: id.namespace), values: { key, value in
            lowerItem = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        var upperItem: HistoryIndexEntry?
        self.valueBox.range(self.tableId, start: key.predecessor, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            upperItem = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        return (lower: lowerItem, upper: upperItem)
    }
    
    func get(id: MessageId) -> HistoryIndexEntry? {
        let key = self.key(id)
        if let value = self.valueBox.get(self.tableId, key: key) {
            return readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
        }
        return nil
    }
    
    func debugList(peerId: PeerId, namespace: MessageId.Namespace) -> [HistoryIndexEntry] {
        var list: [HistoryIndexEntry] = []
        self.valueBox.range(self.tableId, start: self.lowerBound(peerId, namespace: namespace), end: self.upperBound(peerId, namespace: namespace), values: { key, value in
            list.append(readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value))
            
            return true
        }, limit: 0)
        return list
    }
}
