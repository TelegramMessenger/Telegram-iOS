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
    case InsertMessage(InternalStoreMessage)
    case InsertHole(MessageHistoryHole)
    case Remove(MessageIndex)
    case Update(MessageIndex, InternalStoreMessage)
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
        var stableId: UInt32 = 0
        value.read(&stableId, offset: 0, length: 4)
        
        var min: Int32 = 0
        value.read(&min, offset: 0, length: 4)
        
        var tags: UInt32 = 0
        value.read(&tags, offset: 0, length: 4)
        
        return .Hole(MessageHistoryHole(stableId: stableId, maxIndex: index, min: min, tags: tags))
    }
}

final class MessageHistoryIndexTable: Table {
    let globalMessageIdsNamespace: Int32
    let globalMessageIdsTable: GlobalMessageIdsTable
    let metadataTable: MessageHistoryMetadataTable
    let seedConfiguration: SeedConfiguration
    
    var cachedMaxEntryByPeerId: [PeerId: [MessageId.Namespace: ValueBoxKey]] = [:]
    
    init(valueBox: ValueBox, tableId: Int32, globalMessageIdsTable: GlobalMessageIdsTable, metadataTable: MessageHistoryMetadataTable, seedConfiguration: SeedConfiguration) {
        self.globalMessageIdsTable = globalMessageIdsTable
        self.globalMessageIdsNamespace = globalMessageIdsTable.namespace
        self.seedConfiguration = seedConfiguration
        self.metadataTable = metadataTable
        
        super.init(valueBox: valueBox, tableId: tableId)
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
    
    private func ensureInitialized(peerId: PeerId, inout operations: [MessageHistoryIndexOperation]) {
        if !self.metadataTable.isInitialized(peerId) {
            for namespace in self.seedConfiguration.initializeMessageNamespacesWithHoles {
                self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: Int32.max), timestamp: Int32.max), min: 1, tags: MessageTags.All.rawValue), operations: &operations)
            }
            
            self.metadataTable.setInitialized(peerId)
        }
    }
    
    func addHole(id: MessageId, inout operations: [MessageHistoryIndexOperation]) {
        self.ensureInitialized(id.peerId, operations: &operations)
        
        let adjacent = self.adjacentItems(id)
        
        if let lowerItem = adjacent.lower {
            switch lowerItem {
                case let .Hole(lowerHole):
                    if lowerHole.tags != MessageTags.All.rawValue {
                        self.justRemove(lowerHole.maxIndex, operations: &operations)
                        self.justInsertHole(MessageHistoryHole(stableId: lowerHole.stableId, maxIndex: lowerHole.maxIndex, min: lowerHole.min, tags: MessageTags.All.rawValue), operations: &operations)
                    }
                case let .Message(lowerMessage):
                    if let upperItem = adjacent.upper {
                        switch upperItem {
                            case .Hole:
                                break
                            case let .Message(upperMessage):
                                if lowerMessage.id.id < upperMessage.id.id - 1 {
                                    self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: upperMessage.id.id - 1), timestamp: upperMessage.timestamp), min: lowerMessage.id.id + 1, tags: MessageTags.All.rawValue), operations: &operations)
                                }
                                break
                        }
                    } else {
                        self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: Int32.max), timestamp: Int32.max), min: lowerMessage.id.id + 1, tags: MessageTags.All.rawValue), operations: &operations)
                    }
            }
        } else if let upperItem = adjacent.upper {
            switch upperItem {
                case let .Message(upperMessage):
                    if upperMessage.id.id > 1 {
                        self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: upperMessage.id.id - 1), timestamp: upperMessage.timestamp), min: 1, tags: MessageTags.All.rawValue), operations: &operations)
                    }
                case .Hole:
                    break
            }
        } else {
            self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: Int32.max), timestamp: Int32.max), min: 1, tags: MessageTags.All.rawValue), operations: &operations)
        }
    }
    
    func addMessages(messages: [InternalStoreMessage], location: AddMessagesLocation, inout operations: [MessageHistoryIndexOperation]) {
        if messages.count == 0 {
            return
        }
        
        var seenPeerIds = Set<PeerId>()
        for message in messages {
            if !seenPeerIds.contains(message.id.peerId) {
                seenPeerIds.insert(message.id.peerId)
                self.ensureInitialized(message.id.peerId, operations: &operations)
            }
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
                        let startKey = self.key(MessageId(peerId: peerId, namespace: namespace, id: lowerIndex.id.id))
                        
                        self.valueBox.range(self.tableId, start: startKey, end: self.upperBound(peerId, namespace: namespace), values: { key, value in
                            let entry = readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value)
                            if case let .Hole(hole) = entry {
                                if lowerIndex.id.id <= hole.min {
                                    removeHoles.append(hole.maxIndex)
                                } else {
                                    modifyHole = (hole.maxIndex, MessageHistoryHole(stableId: hole.stableId, maxIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: lowerIndex.id.id - 1), timestamp: lowerIndex.timestamp), min: hole.min, tags: hole.tags))
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
                            self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: upperHole.maxIndex, min: index.id.id + 1, tags: upperHole.tags), operations: &operations)
                        }
                        if upperHole.min <= index.id.id - 1 {
                            self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: MessageIndex(id: MessageId(peerId: index.id.peerId, namespace: index.id.namespace, id: index.id.id - 1), timestamp: index.timestamp), min: upperHole.min, tags: upperHole.tags), operations: &operations)
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
        self.ensureInitialized(id.peerId, operations: &operations)
        
        if let existingEntry = self.get(id) {
            self.justRemove(existingEntry.index, operations: &operations)
            
            let adjacent = self.adjacentItems(id)
            
            if let lowerItem = adjacent.lower, upperItem = adjacent.upper {
                switch lowerItem {
                    case let .Message(lowerMessage):
                        switch upperItem {
                            case let .Hole(upperHole):
                                self.justRemove(upperHole.maxIndex, operations: &operations)
                                self.justInsertHole(MessageHistoryHole(stableId: upperHole.stableId, maxIndex: upperHole.maxIndex, min: lowerMessage.id.id + 1, tags: upperHole.tags), operations: &operations)
                            case .Message:
                                break
                        }
                    case let .Hole(lowerHole):
                        switch upperItem {
                            case let .Hole(upperHole):
                                self.justRemove(lowerHole.maxIndex, operations: &operations)
                                self.justRemove(upperHole.maxIndex, operations: &operations)
                                self.justInsertHole(MessageHistoryHole(stableId: upperHole.stableId, maxIndex: upperHole.maxIndex, min: lowerHole.min, tags: upperHole.tags | lowerHole.tags), operations: &operations)
                            case let .Message(upperMessage):
                                self.justRemove(lowerHole.maxIndex, operations: &operations)
                                self.justInsertHole(MessageHistoryHole(stableId: lowerHole.stableId, maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: upperMessage.id.id - 1), timestamp: upperMessage.timestamp), min: lowerHole.min, tags: lowerHole.tags), operations: &operations)
                        }
                }
            } else if let lowerItem = adjacent.lower {
                switch lowerItem {
                    case let .Hole(lowerHole):
                        self.justRemove(lowerHole.maxIndex, operations: &operations)
                        self.justInsertHole(MessageHistoryHole(stableId: lowerHole.stableId, maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: Int32.max), timestamp: Int32.max), min: lowerHole.min, tags: lowerHole.tags), operations: &operations)
                        break
                    case .Message:
                        break
                }
            } else if let upperItem = adjacent.upper {
                switch upperItem {
                    case let .Hole(upperHole):
                        self.justRemove(upperHole.maxIndex, operations: &operations)
                        self.justInsertHole(MessageHistoryHole(stableId: upperHole.stableId, maxIndex: upperHole.maxIndex, min: 1, tags: upperHole.tags), operations: &operations)
                        break
                    case .Message:
                        break
                }
            }
        }
    }
    
    func updateMessage(id: MessageId, message: InternalStoreMessage, inout operations: [MessageHistoryIndexOperation]) {
        if let previousEntry = self.get(id), case let .Message(previousIndex) = previousEntry {
            if previousIndex != MessageIndex(message) {
                var intermediateOperations: [MessageHistoryIndexOperation] = []
                self.removeMessage(id, operations: &intermediateOperations)
                self.addMessages([message], location: .Random, operations: &intermediateOperations)
                
                for operation in intermediateOperations {
                    switch operation {
                        case let .Remove(index) where index == previousIndex:
                            operations.append(.Update(previousIndex, message))
                        case let .InsertMessage(insertMessage) where MessageIndex(insertMessage) == MessageIndex(message):
                            break
                        default:
                            operations.append(operation)
                    }
                }
            } else {
                operations.append(.Update(previousIndex, message))
            }
        }
    }
    
    func fillHole(id: MessageId, fillType: HoleFillType, tagMask: MessageTags?, messages: [InternalStoreMessage], inout operations: [MessageHistoryIndexOperation]) {
        self.ensureInitialized(id.peerId, operations: &operations)
        
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
                    if let tagMask = tagMask {
                        var messagesInRange: [InternalStoreMessage] = []
                        var i = 0
                        while i < remainingMessages.count {
                            let message = remainingMessages[i]
                            if message.id.id >= upperHole.min && message.id.id <= upperHole.maxIndex.id.id {
                                messagesInRange.append(message)
                                remainingMessages.removeAtIndex(i)
                            } else {
                                i += 1
                            }
                        }
                        
                        if messagesInRange.isEmpty {
                            self.justRemove(upperHole.maxIndex, operations: &operations)
                            self.justInsertHole(MessageHistoryHole(stableId: upperHole.stableId, maxIndex: upperHole.maxIndex, min: upperHole.min, tags: upperHole.tags & ~tagMask.rawValue), operations: &operations)
                        } else {
                            self.justRemove(upperHole.maxIndex, operations: &operations)
                            
                            let clearedTags = upperHole.tags & ~tagMask.rawValue
                            
                            for i in 0 ..< messagesInRange.count {
                                let message = messagesInRange[i]
                                
                                if i == 0 {
                                    if upperHole.min < message.id.id {
                                        let holeTags: UInt32
                                        switch fillType {
                                            case .LowerToUpper, .Complete:
                                                holeTags = clearedTags
                                            case .UpperToLower:
                                                holeTags = upperHole.tags
                                        }
                                        self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: message.id.id - 1), timestamp: message.timestamp), min: upperHole.min, tags: holeTags), operations: &operations)
                                    }
                                } else {
                                    let previousMessageId = messagesInRange[i - 1].id.id
                                    if previousMessageId + 1 < message.id.id {
                                        self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: message.id.id - 1), timestamp: message.timestamp), min: previousMessageId + 1, tags: clearedTags), operations: &operations)
                                    }
                                }
                                
                                if i == messagesInRange.count - 1 {
                                    if upperHole.maxIndex.id.id > message.id.id {
                                        let holeTags: UInt32
                                        switch fillType {
                                            case .LowerToUpper:
                                                holeTags = upperHole.tags
                                            case .UpperToLower, .Complete:
                                                holeTags = clearedTags
                                        }
                                        self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: upperHole.maxIndex, min: message.id.id + 1, tags: holeTags), operations: &operations)
                                    }
                                }
                                
                                self.justInsertMessage(message, operations: &operations)
                            }
                        }
                    } else {
                        var i = 0
                        var minMessageInRange: InternalStoreMessage?
                        var maxMessageInRange: InternalStoreMessage?
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
                                i += 1
                            }
                        }
                        switch fillType {
                            case .Complete:
                                if !removedHole {
                                    removedHole = true
                                    self.justRemove(upperHole.maxIndex, operations: &operations)
                                }
                            case .LowerToUpper:
                                if let maxMessageInRange = maxMessageInRange where maxMessageInRange.id.id != Int32.max && maxMessageInRange.id.id + 1 <= upperHole.maxIndex.id.id {
                                    let stableId: UInt32
                                    let tags: UInt32
                                    if removedHole {
                                        stableId = upperHole.stableId
                                        tags = upperHole.tags
                                    } else {
                                        stableId = self.metadataTable.getNextStableMessageIndexId()
                                        tags = MessageTags.All.rawValue
                                    }
                                    self.justInsertHole(MessageHistoryHole(stableId: stableId, maxIndex: upperHole.maxIndex, min: maxMessageInRange.id.id + 1, tags: tags), operations: &operations)
                                }
                            case .UpperToLower:
                                if let minMessageInRange = minMessageInRange where minMessageInRange.id.id - 1 >= upperHole.min {
                                    let stableId: UInt32
                                    let tags: UInt32
                                    if removedHole {
                                        stableId = upperHole.stableId
                                        tags = upperHole.tags
                                    } else {
                                        stableId = self.metadataTable.getNextStableMessageIndexId()
                                        tags = MessageTags.All.rawValue
                                    }
                                    self.justInsertHole(MessageHistoryHole(stableId: stableId, maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: minMessageInRange.id.id - 1), timestamp: minMessageInRange.timestamp), min: upperHole.min, tags: tags), operations: &operations)
                                }
                        }
                }
                case .Message:
                    break
            }
        }
        
        for message in remainingMessages {
            self.addMessages([message], location: .Random, operations: &operations)
        }
    }
    
    private func justInsertHole(hole: MessageHistoryHole, inout operations: [MessageHistoryIndexOperation]) {
        let value = WriteBuffer()
        var type: Int8 = 1
        var timestamp: Int32 = hole.maxIndex.timestamp
        var min: Int32 = hole.min
        var tags: UInt32 = hole.tags
        value.write(&type, offset: 0, length: 1)
        value.write(&timestamp, offset: 0, length: 4)
        var stableId: UInt32 = hole.stableId
        value.write(&stableId, offset: 0, length: 4)
        value.write(&min, offset: 0, length: 4)
        value.write(&tags, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(hole.id), value: value)
        
        operations.append(.InsertHole(hole))
    }
    
    private func justInsertMessage(message: InternalStoreMessage, inout operations: [MessageHistoryIndexOperation]) {
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
    
    private func justRemove(index: MessageIndex, inout operations: [MessageHistoryIndexOperation]) {
        self.valueBox.remove(self.tableId, key: self.key(index.id))
        
        operations.append(.Remove(index))
        if index.id.namespace == self.globalMessageIdsNamespace {
            self.globalMessageIdsTable.remove(index.id.id)
        }
    }
    
    private func adjacentItems(id: MessageId) -> (lower: HistoryIndexEntry?, upper: HistoryIndexEntry?) {
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
        var operations: [MessageHistoryIndexOperation] = []
        self.ensureInitialized(id.peerId, operations: &operations)
        
        let key = self.key(id)
        if let value = self.valueBox.get(self.tableId, key: key) {
            return readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
        }
        return nil
    }
    
    func exists(id: MessageId) -> Bool {
        return self.valueBox.exists(self.tableId, key: self.key(id))
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
