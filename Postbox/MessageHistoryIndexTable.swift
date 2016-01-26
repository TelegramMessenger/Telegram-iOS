import Foundation

enum HistoryIndexEntry {
    case Message(MessageIndex)
    case Hole(MessageHistoryHole)
}

enum HoleFillType {
    case UpperToLower
    case LowerToUpper
    case Complete
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
    
    init(valueBox: ValueBox, tableId: Int32) {
        self.valueBox = valueBox
        self.tableId = tableId
    }
    
    func key(id: MessageId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4 + 4)
        key.setInt64(0, value: id.peerId.toInt64())
        key.setInt32(8, value: id.namespace)
        key.setInt32(8 + 4, value: id.id)
        return key
    }
    
    func lowerBound(peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key
    }
    
    func upperBound(peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key.successor
    }
    
    func addHole(id: MessageId) {
        let adjacent = self.adjacentItems(id)
        
        /*
        
        1. [x] nothing
        2. [x] message - * - nothing
        3. [x] nothing - * - message
        4. [x] nothing - * - hole
        5. [x] message - * - message
        6. [x] hole - * - message
        7. [x] message - * - hole
        
        */
        
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
                                self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: upperMessage.id.id - 1), timestamp: upperMessage.timestamp), min: lowerMessage.id.id + 1))
                            }
                            break
                    }
            }
        } else if let lowerItem = adjacent.lower {
            switch lowerItem {
                case let .Message(lowerMessage):
                    self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: Int32.max), timestamp: Int32.max), min: lowerMessage.id.id + 1))
                case .Hole:
                    break
            }
        } else if let upperItem = adjacent.upper {
            switch upperItem {
                case let .Message(upperMessage):
                    if upperMessage.id.id > 1 {
                        self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: upperMessage.id.id - 1), timestamp: upperMessage.timestamp), min: 1))
                    }
                case .Hole:
                    break
            }
        } else {
            self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: Int32.max), timestamp: Int32.max), min: 1))
        }
    }
    
    func addMessage(index: MessageIndex) {
        var upperItem: HistoryIndexEntry?
        self.valueBox.range(self.tableId, start: self.key(index.id).predecessor, end: self.upperBound(index.id.peerId, namespace: index.id.namespace), values: { key, value in
            upperItem = readHistoryIndexEntry(index.id.peerId, namespace: index.id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        if let upperItem = upperItem {
            switch upperItem {
                case let .Hole(upperHole):
                    self.justRemove(upperHole.id)
                    if upperHole.maxIndex.id.id > index.id.id + 1 {
                        self.justInsertHole(MessageHistoryHole(maxIndex: upperHole.maxIndex, min: index.id.id + 1))
                    }
                    if upperHole.min <= index.id.id - 1 {
                        self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: index.id.peerId, namespace: index.id.namespace, id: index.id.id - 1), timestamp: index.timestamp), min: upperHole.min))
                    }
                    break
                case .Message:
                    break
            }
        }
        
        self.justInsertMessage(index)
    }
    
    func removeMessage(id: MessageId) {
        let key = self.key(id)
        if self.valueBox.exists(self.tableId, key: key) {
            self.justRemove(id)
            
            let adjacent = self.adjacentItems(id)
            
            if let lowerItem = adjacent.lower, upperItem = adjacent.upper {
                switch lowerItem {
                    case let .Message(lowerMessage):
                        switch upperItem {
                            case let .Hole(upperHole):
                                self.justRemove(upperHole.id)
                                self.justInsertHole(MessageHistoryHole(maxIndex: upperHole.maxIndex, min: lowerMessage.id.id + 1))
                            case .Message:
                                break
                        }
                    case let .Hole(lowerHole):
                        switch upperItem {
                            case let .Hole(upperHole):
                                self.justRemove(lowerHole.id)
                                self.justRemove(upperHole.id)
                                self.justInsertHole(MessageHistoryHole(maxIndex: upperHole.maxIndex, min: lowerHole.min))
                            case let .Message(upperMessage):
                                self.justRemove(lowerHole.id)
                                self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: upperMessage.id.id - 1), timestamp: upperMessage.timestamp), min: lowerHole.min))
                        }
                }
            } else if let lowerItem = adjacent.lower {
                switch lowerItem {
                    case let .Hole(lowerHole):
                        self.justRemove(lowerHole.id)
                        self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: Int32.max), timestamp: Int32.max), min: lowerHole.min))
                        break
                    case .Message:
                        break
                }
            } else if let upperItem = adjacent.upper {
                switch upperItem {
                    case let .Hole(upperHole):
                        self.justRemove(upperHole.id)
                        self.justInsertHole(MessageHistoryHole(maxIndex: upperHole.maxIndex, min: 1))
                        break
                    case .Message:
                        break
                }
            }
        }
    }
    
    func fillHole(id: MessageId, fillType: HoleFillType, indices: [MessageIndex]) {
        var upperItem: HistoryIndexEntry?
        self.valueBox.range(self.tableId, start: self.key(id).predecessor, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            upperItem = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        let sortedByIdIndices = indices.sort({$0.id < $1.id})
        var remainingIndices = sortedByIdIndices
        
        if let upperItem = upperItem {
            switch upperItem {
                case let .Hole(upperHole):
                    var i = 0
                    var minIndexInRange: MessageIndex?
                    var maxIndexInRange: MessageIndex?
                    var removedHole = false
                    while i < remainingIndices.count {
                        let index = remainingIndices[i]
                        if index.id.id >= upperHole.min && index.id.id <= upperHole.maxIndex.id.id {
                            if (fillType == .UpperToLower || fillType == .Complete) && (minIndexInRange == nil || minIndexInRange!.id > index.id) {
                                minIndexInRange = index
                                if !removedHole {
                                    removedHole = true
                                    self.justRemove(upperHole.id)
                                }
                            }
                            if (fillType == .LowerToUpper || fillType == .Complete) && (maxIndexInRange == nil || maxIndexInRange!.id < index.id) {
                                maxIndexInRange = index
                                if !removedHole {
                                    removedHole = true
                                    self.justRemove(upperHole.id)
                                }
                            }
                            self.justInsertMessage(index)
                            remainingIndices.removeAtIndex(i)
                        } else {
                            i++
                        }
                    }
                    switch fillType {
                        case .Complete:
                            if !removedHole {
                                self.justRemove(upperHole.id)
                            }
                        case .LowerToUpper:
                            if let maxIndexInRange = maxIndexInRange where maxIndexInRange.id.id != Int32.max && maxIndexInRange.id.id + 1 <= upperHole.maxIndex.id.id {
                                self.justInsertHole(MessageHistoryHole(maxIndex: upperHole.maxIndex, min: maxIndexInRange.id.id + 1))
                            }
                        case .UpperToLower:
                            if let minIndexInRange = minIndexInRange where minIndexInRange.id.id - 1 >= upperHole.min {
                                self.justInsertHole(MessageHistoryHole(maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: minIndexInRange.id.id - 1), timestamp: minIndexInRange.timestamp), min: upperHole.min))
                            }
                    }
                    break
                case .Message:
                    break
            }
        }
        
        for index in remainingIndices {
            self.addMessage(index)
        }
    }
    
    func justInsertHole(hole: MessageHistoryHole) {
        let value = WriteBuffer()
        var type: Int8 = 1
        var timestamp: Int32 = hole.maxIndex.timestamp
        var min: Int32 = hole.min
        value.write(&type, offset: 0, length: 1)
        value.write(&timestamp, offset: 0, length: 4)
        value.write(&min, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(hole.id), value: value)
    }
    
    func justInsertMessage(index: MessageIndex) {
        let value = WriteBuffer()
        var type: Int8 = 0
        var timestamp: Int32 = index.timestamp
        value.write(&type, offset: 0, length: 1)
        value.write(&timestamp, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(index.id), value: value)
    }
    
    func justRemove(id: MessageId) {
        self.valueBox.remove(self.tableId, key: self.key(id))
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
    
    func messageExists(id: MessageId) -> Bool {
        if let entry = self.get(id) {
            if case .Message = entry {
                return true
            }
        }
        
        return false
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
