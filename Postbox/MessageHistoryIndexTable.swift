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

public enum HoleFillDirection: Equatable {
    case UpperToLower
    case LowerToUpper
    case AroundIndex(MessageIndex)
}

public func ==(lhs: HoleFillDirection, rhs: HoleFillDirection) -> Bool {
    switch lhs {
        case .UpperToLower:
            switch rhs {
                case .UpperToLower:
                    return true
                default:
                    return false
            }
        case .LowerToUpper:
            switch rhs {
                case .LowerToUpper:
                    return true
                default:
                    return false
            }
        case let .AroundIndex(lhsIndex):
            switch rhs {
                case let .AroundIndex(rhsIndex) where lhsIndex == rhsIndex:
                    return true
                default:
                    return false
            }
    }
}

public struct HoleFill {
    public let complete: Bool
    public let direction: HoleFillDirection
    
    public init(complete: Bool, direction: HoleFillDirection) {
        self.complete = complete
        self.direction = direction
    }
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

private let HistoryEntryTypeMask: Int8 = 1
private let HistoryEntryTypeMessage: Int8 = 0
private let HistoryEntryTypeHole: Int8 = 1
private let HistoryEntryMessageFlagIncoming: Int8 = 1 << 1

private func readHistoryIndexEntry(_ peerId: PeerId, namespace: MessageId.Namespace, key: ValueBoxKey, value: ReadBuffer) -> HistoryIndexEntry {
    var flags: Int8 = 0
    value.read(&flags, offset: 0, length: 1)
    var timestamp: Int32 = 0
    value.read(&timestamp, offset: 0, length: 4)
    let index = MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: key.getInt32(8 + 4)), timestamp: timestamp)
    
    if (flags & HistoryEntryTypeMask) == 0 {
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
    
    private func key(_ id: MessageId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4 + 4)
        key.setInt64(0, value: id.peerId.toInt64())
        key.setInt32(8, value: id.namespace)
        key.setInt32(8 + 4, value: id.id)
        return key
    }
    
    private func lowerBound(_ peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key
    }
    
    private func upperBound(_ peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key.successor
    }
    
    func ensureInitialized(_ peerId: PeerId, operations: inout [MessageHistoryIndexOperation]) {
        if !self.metadataTable.isInitialized(peerId) {
            for namespace in self.seedConfiguration.initializeMessageNamespacesWithHoles {
                self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: Int32.max), timestamp: Int32.max), min: 1, tags: MessageTags.All.rawValue), operations: &operations)
            }
            
            self.metadataTable.setInitialized(peerId)
        }
    }
    
    func addHole(_ id: MessageId, operations: inout [MessageHistoryIndexOperation]) {
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
    
    func addMessages(_ messages: [InternalStoreMessage], location: AddMessagesLocation, operations: inout [MessageHistoryIndexOperation]) {
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
    
    func removeMessage(_ id: MessageId, operations: inout [MessageHistoryIndexOperation]) {
        self.ensureInitialized(id.peerId, operations: &operations)
        
        if let existingEntry = self.get(id) {
            self.justRemove(existingEntry.index, operations: &operations)
            
            let adjacent = self.adjacentItems(id)
            
            if let lowerItem = adjacent.lower, let upperItem = adjacent.upper {
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
    
    func updateMessage(_ id: MessageId, message: InternalStoreMessage, operations: inout [MessageHistoryIndexOperation]) {
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
    
    func fillHole(_ id: MessageId, fillType: HoleFill, tagMask: MessageTags?, messages: [InternalStoreMessage], operations: inout [MessageHistoryIndexOperation]) {
        self.ensureInitialized(id.peerId, operations: &operations)
        
        var upperItem: HistoryIndexEntry?
        self.valueBox.range(self.tableId, start: self.key(id).predecessor, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            upperItem = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        let sortedByIdMessages = messages.sorted(by: {$0.id < $1.id})
        
        var remainingMessages = sortedByIdMessages
        
        if let upperItem = upperItem {
            switch upperItem {
                case let .Hole(upperHole):
                    if let tagMask = tagMask {
                        if case .AroundIndex = fillType.direction {
                            assertionFailure(".AroundIndex not supported")
                        }
                        
                        var messagesInRange: [InternalStoreMessage] = []
                        var i = 0
                        while i < remainingMessages.count {
                            let message = remainingMessages[i]
                            if message.id.id >= upperHole.min && message.id.id <= upperHole.maxIndex.id.id {
                                messagesInRange.append(message)
                                remainingMessages.remove(at: i)
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
                                        if fillType.complete || fillType.direction == .LowerToUpper {
                                            holeTags = clearedTags
                                        } else {
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
                                        if fillType.complete || fillType.direction == .UpperToLower {
                                            holeTags = clearedTags
                                        } else {
                                            holeTags = upperHole.tags
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
                                if (minMessageInRange == nil || minMessageInRange!.id > message.id) {
                                    minMessageInRange = message
                                    if (fillType.complete || fillType.direction == .UpperToLower) {
                                        if !removedHole {
                                            removedHole = true
                                            self.justRemove(upperHole.maxIndex, operations: &operations)
                                        }
                                    }
                                }
                                
                                if (maxMessageInRange == nil || maxMessageInRange!.id < message.id) {
                                    maxMessageInRange = message
                                    if (fillType.complete || fillType.direction == .LowerToUpper) {
                                        if !removedHole {
                                            removedHole = true
                                            self.justRemove(upperHole.maxIndex, operations: &operations)
                                        }
                                    }
                                }
                                
                                self.justInsertMessage(message, operations: &operations)
                                remainingMessages.remove(at: i)
                            } else {
                                i += 1
                            }
                        }
                        if fillType.complete {
                            if !removedHole {
                                removedHole = true
                                self.justRemove(upperHole.maxIndex, operations: &operations)
                            }
                        } else if fillType.direction == .LowerToUpper {
                            if let maxMessageInRange = maxMessageInRange , maxMessageInRange.id.id != Int32.max && maxMessageInRange.id.id + 1 <= upperHole.maxIndex.id.id {
                                let stableId: UInt32
                                let tags: UInt32 = upperHole.tags
                                if removedHole {
                                    stableId = upperHole.stableId
                                } else {
                                    stableId = self.metadataTable.getNextStableMessageIndexId()
                                }
                                self.justInsertHole(MessageHistoryHole(stableId: stableId, maxIndex: upperHole.maxIndex, min: maxMessageInRange.id.id + 1, tags: tags), operations: &operations)
                            }
                        } else if fillType.direction == .UpperToLower {
                            if let minMessageInRange = minMessageInRange , minMessageInRange.id.id - 1 >= upperHole.min {
                                let stableId: UInt32
                                let tags: UInt32 = upperHole.tags
                                if removedHole {
                                    stableId = upperHole.stableId
                                } else {
                                    stableId = self.metadataTable.getNextStableMessageIndexId()
                                }
                                self.justInsertHole(MessageHistoryHole(stableId: stableId, maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: minMessageInRange.id.id - 1), timestamp: minMessageInRange.timestamp), min: upperHole.min, tags: tags), operations: &operations)
                            }
                        } else if case .AroundIndex = fillType.direction {
                            if !removedHole {
                                self.justRemove(upperHole.maxIndex, operations: &operations)
                                removedHole = true
                            }
                            
                            if let minMessageInRange = minMessageInRange , minMessageInRange.id.id - 1 >= upperHole.min {
                                let stableId: UInt32 = upperHole.stableId
                                let tags: UInt32 = upperHole.tags
                                
                                self.justInsertHole(MessageHistoryHole(stableId: stableId, maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: minMessageInRange.id.id - 1), timestamp: minMessageInRange.timestamp), min: upperHole.min, tags: tags), operations: &operations)
                            }
                            
                            if let maxMessageInRange = maxMessageInRange , maxMessageInRange.id.id != Int32.max && maxMessageInRange.id.id + 1 <= upperHole.maxIndex.id.id {
                                let stableId: UInt32 = self.metadataTable.getNextStableMessageIndexId()
                                let tags: UInt32 = upperHole.tags
                                self.justInsertHole(MessageHistoryHole(stableId: stableId, maxIndex: upperHole.maxIndex, min: maxMessageInRange.id.id + 1, tags: tags), operations: &operations)
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
    
    private func justInsertHole(_ hole: MessageHistoryHole, operations: inout [MessageHistoryIndexOperation]) {
        let value = WriteBuffer()
        var flags: Int8 = HistoryEntryTypeHole
        var timestamp: Int32 = hole.maxIndex.timestamp
        var min: Int32 = hole.min
        var tags: UInt32 = hole.tags
        value.write(&flags, offset: 0, length: 1)
        value.write(&timestamp, offset: 0, length: 4)
        var stableId: UInt32 = hole.stableId
        value.write(&stableId, offset: 0, length: 4)
        value.write(&min, offset: 0, length: 4)
        value.write(&tags, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(hole.id), value: value)
        
        operations.append(.InsertHole(hole))
    }
    
    private func justInsertMessage(_ message: InternalStoreMessage, operations: inout [MessageHistoryIndexOperation]) {
        let index = MessageIndex(id: message.id, timestamp: message.timestamp)
        
        let value = WriteBuffer()
        var flags: Int8 = HistoryEntryTypeMessage
        if message.flags.contains(.Incoming) {
            flags |= HistoryEntryMessageFlagIncoming
        }
        var timestamp: Int32 = index.timestamp
        value.write(&flags, offset: 0, length: 1)
        value.write(&timestamp, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(index.id), value: value)
        
        operations.append(.InsertMessage(message))
        
        if index.id.namespace == self.globalMessageIdsNamespace {
            self.globalMessageIdsTable.set(index.id.id, id: index.id)
        }
    }
    
    private func justRemove(_ index: MessageIndex, operations: inout [MessageHistoryIndexOperation]) {
        self.valueBox.remove(self.tableId, key: self.key(index.id))
        
        operations.append(.Remove(index))
        if index.id.namespace == self.globalMessageIdsNamespace {
            self.globalMessageIdsTable.remove(index.id.id)
        }
    }
    
    func adjacentItems(_ id: MessageId, bindUpper: Bool = true) -> (lower: HistoryIndexEntry?, upper: HistoryIndexEntry?) {
        let key = self.key(id)
        
        var lowerItem: HistoryIndexEntry?
        self.valueBox.range(self.tableId, start: bindUpper ? key : key.successor, end: self.lowerBound(id.peerId, namespace: id.namespace), values: { key, value in
            lowerItem = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        var upperItem: HistoryIndexEntry?
        self.valueBox.range(self.tableId, start: bindUpper ? key.predecessor : key, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            upperItem = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        return (lower: lowerItem, upper: upperItem)
    }
    
    func get(_ id: MessageId) -> HistoryIndexEntry? {
        var operations: [MessageHistoryIndexOperation] = []
        self.ensureInitialized(id.peerId, operations: &operations)
        
        let key = self.key(id)
        if let value = self.valueBox.get(self.tableId, key: key) {
            return readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
        }
        return nil
    }
    
    func top(_ peerId: PeerId, namespace: MessageId.Namespace) -> HistoryIndexEntry? {
        var operations: [MessageHistoryIndexOperation] = []
        self.ensureInitialized(peerId, operations: &operations)
        
        var entry: HistoryIndexEntry?
        self.valueBox.range(self.tableId, start: self.upperBound(peerId, namespace: namespace), end: self.lowerBound(peerId, namespace: namespace), values: { key, value in
            entry = readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value)
            return false
        }, limit: 1)
        
        return entry
    }
    
    func exists(_ id: MessageId) -> Bool {
        return self.valueBox.exists(self.tableId, key: self.key(id))
    }
    
    func holeContainingId(_ id: MessageId) -> MessageHistoryHole? {
        var result: MessageHistoryHole?
        self.valueBox.range(self.tableId, start: self.key(MessageId(peerId: id.peerId, namespace: id.namespace, id: id.id)).predecessor, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            if case let .Hole(hole) = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value) {
                result = hole
            }
            return true
        }, limit: 1)
        
        return result
    }
    
    func incomingMessageCountInRange(_ peerId: PeerId, namespace: MessageId.Namespace, minId: MessageId.Id, maxId: MessageId.Id) -> (Int, Bool) {
        var count = 0
        var holes = false
        
        self.valueBox.range(self.tableId, start: self.key(MessageId(peerId: peerId, namespace: namespace, id: minId)).predecessor, end: self.key(MessageId(peerId: peerId, namespace: namespace, id: maxId)).successor, values: { _, value in
            var flags: Int8 = 0
            value.read(&flags, offset: 0, length: 1)
            if (flags & HistoryEntryTypeMask) == HistoryEntryTypeMessage {
                if (flags & HistoryEntryMessageFlagIncoming) != 0 {
                    count += 1
                }
            } else {
                holes = true
            }
            return true
        }, limit: 0)
        
        self.valueBox.range(self.tableId, start: self.key(MessageId(peerId: peerId, namespace: namespace, id: maxId)), end: self.upperBound(peerId, namespace: namespace), values: { key, value in
            var flags: Int8 = 0
            value.read(&flags, offset: 0, length: 1)
            if (flags & HistoryEntryTypeMask) == HistoryEntryTypeHole {
                value.reset()
                if case let .Hole(hole) = readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value) , hole.min <= maxId && hole.maxIndex.id.id >= maxId {
                    holes = true
                }
            }
            return false
        }, limit: 1)
        
        return (count, holes)
    }
    
    func incomingMessageCountInIds(_ peerId: PeerId, namespace: MessageId.Namespace, ids: [MessageId.Id]) -> (Int, Bool) {
        var count = 0
        var holes = false
        
        for id in ids {
            self.valueBox.range(self.tableId, start: self.key(MessageId(peerId: peerId, namespace: namespace, id: id)).predecessor, end: self.upperBound(peerId, namespace: namespace), values: { key, value in
                let entryId = key.getInt32(8 + 4)
                var flags: Int8 = 0
                value.read(&flags, offset: 0, length: 1)
                
                if entryId == id {
                    if (flags & HistoryEntryTypeMask) == HistoryEntryTypeMessage {
                        if (flags & HistoryEntryMessageFlagIncoming) != 0 {
                            count += 1
                        }
                    } else {
                        holes = true
                    }
                } else if (flags & HistoryEntryTypeMask) == HistoryEntryTypeHole {
                    holes = true
                }
                
                return true
            }, limit: 1)
        }
        
        return (count, holes)
    }
    
    func debugList(_ peerId: PeerId, namespace: MessageId.Namespace) -> [HistoryIndexEntry] {
        var list: [HistoryIndexEntry] = []
        self.valueBox.range(self.tableId, start: self.lowerBound(peerId, namespace: namespace), end: self.upperBound(peerId, namespace: namespace), values: { key, value in
            list.append(readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value))
            
            return true
        }, limit: 0)
        return list
    }
}
