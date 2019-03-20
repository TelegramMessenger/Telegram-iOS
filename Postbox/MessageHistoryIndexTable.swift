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
    case UpperToLower(updatedMinIndex: MessageIndex?, clippingMaxIndex: MessageIndex?)
    case LowerToUpper(updatedMaxIndex: MessageIndex?, clippingMinIndex: MessageIndex?)
    case AroundId(MessageId, lowerComplete: Bool, upperComplete: Bool)
    case AroundIndex(MessageIndex, lowerComplete: Bool, upperComplete: Bool, clippingMinIndex: MessageIndex?, clippingMaxIndex: MessageIndex?)

    public static func ==(lhs: HoleFillDirection, rhs: HoleFillDirection) -> Bool {
        switch lhs {
            case let .UpperToLower(lhsUpdatedMinIndex, lhsClippingMaxIndex):
                switch rhs {
                    case let .UpperToLower(rhsUpdatedMinIndex, rhsClippingMaxIndex):
                        if lhsUpdatedMinIndex == rhsUpdatedMinIndex && lhsClippingMaxIndex == rhsClippingMaxIndex {
                            return true
                        } else {
                            return false
                        }
                    default:
                        return false
                }
            case let .LowerToUpper(lhsUpdatedMaxIndex, lhsClippingMinIndex):
                switch rhs {
                    case let .LowerToUpper(rhsUpdatedMaxIndex, lhsClippingMaxIndex):
                        if lhsUpdatedMaxIndex == rhsUpdatedMaxIndex && lhsClippingMinIndex == lhsClippingMaxIndex {
                            return true
                        } else {
                            return false
                        }
                    default:
                        return false
                }
            case let .AroundId(id, lowerComplete, upperComplete):
                if case .AroundId(id, lowerComplete, upperComplete) = rhs {
                        return true
                } else {
                    return false
                }
            case let .AroundIndex(lhsIndex, lhsLowerComplete, lhsUpperComplete, lhsClippingMinIndex, lhsClippingMaxIndex):
                if case let .AroundIndex(rhsIndex, rhsLowerComplete, rhsUpperComplete, rhsClippingMinIndex, rhsClippingMaxIndex) = rhs, lhsIndex == rhsIndex, lhsLowerComplete == rhsLowerComplete, lhsUpperComplete == rhsUpperComplete, lhsClippingMinIndex == rhsClippingMinIndex, lhsClippingMaxIndex == rhsClippingMaxIndex {
                    return true
                } else {
                    return false
                }
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
    case InsertExistingMessage(InternalStoreMessage)
    case InsertHole(MessageHistoryHole)
    case Remove(index: MessageIndex, isMessage: Bool)
    case Update(MessageIndex, InternalStoreMessage)
    case UpdateTimestamp(MessageIndex, Int32)
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

private func modifyHistoryIndexEntryTimestamp(value: ReadBuffer, timestamp: Int32) -> MemoryBuffer {
    let buffer = WriteBuffer()
    buffer.write(value.memory.advanced(by: 0), offset: 0, length: 1)
    var varTimestamp: Int32 = timestamp
    buffer.write(&varTimestamp, offset: 0, length: 4)
    buffer.write(value.memory.advanced(by: 5), offset: 0, length: value.length - 5)
    return buffer
}

final class MessageHistoryIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    let globalMessageIdsTable: GlobalMessageIdsTable
    let metadataTable: MessageHistoryMetadataTable
    let seedConfiguration: SeedConfiguration
    
    var cachedMaxEntryByPeerId: [PeerId: [MessageId.Namespace: ValueBoxKey]] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, globalMessageIdsTable: GlobalMessageIdsTable, metadataTable: MessageHistoryMetadataTable, seedConfiguration: SeedConfiguration) {
        self.globalMessageIdsTable = globalMessageIdsTable
        self.seedConfiguration = seedConfiguration
        self.metadataTable = metadataTable
        
        super.init(valueBox: valueBox, table: table)
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
            var processedMessageNamespaces = Set<MessageId.Namespace>()
            for (peerNamespace, messageNamespace) in self.seedConfiguration.initializeMessageNamespacesWithHoles {
                if peerId.namespace == peerNamespace, !processedMessageNamespaces.contains(messageNamespace) {
                    processedMessageNamespaces.insert(messageNamespace)
                    self.justInsertHole(MessageHistoryHole(stableId: self.metadataTable.getNextStableMessageIndexId(), maxIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: messageNamespace, id: Int32.max), timestamp: Int32.max), min: 1, tags: MessageTags.All.rawValue), operations: &operations)
                }
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
                        self.justRemove(lowerHole.maxIndex, isMessage: false, operations: &operations)
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
                case let .Hole(upperHole):
                    if id.id < upperHole.min {
                        self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                        self.justInsertHole(MessageHistoryHole(stableId: upperHole.stableId, maxIndex: upperHole.maxIndex, min: id.id, tags: MessageTags.All.rawValue), operations: &operations)
                    }
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
                        
                        self.valueBox.range(self.table, start: startKey, end: self.upperBound(peerId, namespace: namespace), values: { key, value in
                            let entry = readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value)
                            if case let .Hole(hole) = entry {
                                if lowerIndex.id.id <= hole.min {
                                    removeHoles.append(hole.maxIndex)
                                } else {
                                    assert(modifyHole == nil)
                                    modifyHole = (hole.maxIndex, MessageHistoryHole(stableId: hole.stableId, maxIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: lowerIndex.id.id - 1), timestamp: lowerIndex.timestamp), min: hole.min, tags: hole.tags))
                                }
                            }
                            return true
                        }, limit: 0)
                        
                        for index in removeHoles {
                            self.justRemove(index, isMessage: false, operations: &operations)
                        }
                        
                        if let modifyHole = modifyHole {
                            self.justRemove(modifyHole.0, isMessage: false, operations: &operations)
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
            self.valueBox.range(self.table, start: self.key(index.id).predecessor, end: self.upperBound(index.id.peerId, namespace: index.id.namespace), values: { key, value in
                upperItem = readHistoryIndexEntry(index.id.peerId, namespace: index.id.namespace, key: key, value: value)
                return true
            }, limit: 1)
            
            var exists = false
            
            if let upperItem = upperItem {
                switch upperItem {
                    case let .Hole(upperHole):
                        self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                        if upperHole.maxIndex.id.id >= index.id.id + 1 {
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
            } else {
                operations.append(.InsertExistingMessage(message))
            }
        }
    }
    
    func removeMessage(_ id: MessageId, operations: inout [MessageHistoryIndexOperation]) {
        self.ensureInitialized(id.peerId, operations: &operations)
        
        if let existingEntry = self.getEnsureInitialized(id, operations: &operations), case .Message = existingEntry {
            self.justRemove(existingEntry.index, isMessage: true, operations: &operations)
            
            let adjacent = self.adjacentItems(id)
            
            if let lowerItem = adjacent.lower, let upperItem = adjacent.upper {
                switch lowerItem {
                    case let .Message(lowerMessage):
                        switch upperItem {
                            case let .Hole(upperHole):
                                self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                                self.justInsertHole(MessageHistoryHole(stableId: upperHole.stableId, maxIndex: upperHole.maxIndex, min: lowerMessage.id.id + 1, tags: upperHole.tags), operations: &operations)
                            case .Message:
                                break
                        }
                    case let .Hole(lowerHole):
                        switch upperItem {
                            case let .Hole(upperHole):
                                self.justRemove(lowerHole.maxIndex, isMessage: false, operations: &operations)
                                self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                                self.justInsertHole(MessageHistoryHole(stableId: upperHole.stableId, maxIndex: upperHole.maxIndex, min: lowerHole.min, tags: upperHole.tags | lowerHole.tags), operations: &operations)
                            case let .Message(upperMessage):
                                self.justRemove(lowerHole.maxIndex, isMessage: false, operations: &operations)
                                self.justInsertHole(MessageHistoryHole(stableId: lowerHole.stableId, maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: upperMessage.id.id - 1), timestamp: upperMessage.timestamp), min: lowerHole.min, tags: lowerHole.tags), operations: &operations)
                        }
                }
            } else if let lowerItem = adjacent.lower {
                switch lowerItem {
                    case let .Hole(lowerHole):
                        self.justRemove(lowerHole.maxIndex, isMessage: false, operations: &operations)
                        self.justInsertHole(MessageHistoryHole(stableId: lowerHole.stableId, maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: Int32.max), timestamp: Int32.max), min: lowerHole.min, tags: lowerHole.tags), operations: &operations)
                        break
                    case .Message:
                        break
                }
            } else if let upperItem = adjacent.upper {
                switch upperItem {
                    case let .Hole(upperHole):
                        self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                        self.justInsertHole(MessageHistoryHole(stableId: upperHole.stableId, maxIndex: upperHole.maxIndex, min: 1, tags: upperHole.tags), operations: &operations)
                        break
                    case .Message:
                        break
                }
            }
        }
    }
    
    func removeMessagesInRange(peerId: PeerId, namespace: MessageId.Namespace, minId: MessageId.Id, maxId: MessageId.Id, operations: inout [MessageHistoryIndexOperation]) {
        if minId > maxId {
            assertionFailure()
            return
        }
        var removeMessageIds: [MessageId] = []
        var removeHoles: [MessageHistoryHole] = []
        var addHoles: [MessageHistoryHole] = []
        var insertHoles: [MessageId] = []
        self.valueBox.range(self.table, start: self.key(MessageId(peerId: peerId, namespace: namespace, id: minId)).predecessor, end: self.key(MessageId(peerId: peerId, namespace: namespace, id: maxId)).successor, values: { key, value in
            switch readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value) {
                case let .Message(index):
                    removeMessageIds.append(index.id)
                case let .Hole(hole):
                    removeHoles.append(hole)
                    if hole.min < minId {
                        insertHoles.append(MessageId(peerId: peerId, namespace: namespace, id: hole.min))
                    }
                
                    if hole.maxIndex.id.id > maxId {
                        let stableId: UInt32 = hole.stableId
                        addHoles.append(MessageHistoryHole(stableId: stableId, maxIndex: hole.maxIndex, min: maxId == Int32.max ? maxId : (maxId + 1), tags: hole.tags))
                    }
            }
            return true
        }, limit: 0)
        if let upper = self.adjacentItems(MessageId(peerId: peerId, namespace: namespace, id: maxId)).1, case let .Hole(hole) = upper, removeHoles.index(of: hole) == nil {
            if hole.min < maxId {
                removeHoles.append(hole)
                let stableId: UInt32 = hole.stableId
                addHoles.append(MessageHistoryHole(stableId: stableId, maxIndex: hole.maxIndex, min: maxId == Int32.max ? maxId : (maxId + 1), tags: hole.tags))
            }
        }
        
        for id in removeMessageIds {
            self.removeMessage(id, operations: &operations)
        }
        for hole in removeHoles {
            self.justRemove(hole.maxIndex, isMessage: false, operations: &operations)
        }
        for hole in addHoles {
            self.justInsertHole(hole, operations: &operations)
        }
        for id in insertHoles {
            self.addHole(id, operations: &operations)
        }
    }
    
    func updateMessage(_ id: MessageId, message: InternalStoreMessage, operations: inout [MessageHistoryIndexOperation]) {
        if let previousEntry = self.getEnsureInitialized(id, operations: &operations), case let .Message(previousIndex) = previousEntry {
            if previousIndex != MessageIndex(message) {
                var intermediateOperations: [MessageHistoryIndexOperation] = []
                self.removeMessage(id, operations: &intermediateOperations)
                self.addMessages([message], location: .Random, operations: &intermediateOperations)
                
                for operation in intermediateOperations {
                    switch operation {
                        case let .Remove(index, _) where index == previousIndex:
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
    
    func updateTimestamp(_ id: MessageId, timestamp: Int32, operations: inout [MessageHistoryIndexOperation]) {
        if let previousData = self.valueBox.get(self.table, key: self.key(id)), let previousEntry = self.getEnsureInitialized(id, operations: &operations), case let .Message(previousIndex) = previousEntry, previousIndex.timestamp != timestamp {
            let updatedEntry = modifyHistoryIndexEntryTimestamp(value: previousData, timestamp: timestamp)
            self.valueBox.remove(self.table, key: self.key(id))
            self.valueBox.set(self.table, key: self.key(id), value: updatedEntry)
            
            operations.append(.UpdateTimestamp(MessageIndex(id: id, timestamp: previousIndex.timestamp), timestamp))
        }
    }
    
    func fillMultipleHoles(mainHoleId: MessageId, fillType: HoleFill, tagMask: MessageTags?, messages: [InternalStoreMessage], operations: inout [MessageHistoryIndexOperation]) {
        let peerId = mainHoleId.peerId
        self.ensureInitialized(peerId, operations: &operations)
        
        let sortedByIdMessages = messages.sorted(by: {$0.id < $1.id})
        
        var collectedHoles: [MessageId] = []
        var messagesByHole: [MessageId: [InternalStoreMessage]] = [:]
        var holesByHole: [MessageId: MessageHistoryHole] = [:]
        
        var filledUpperBound: MessageId.Id?
        var filledLowerBound: MessageId.Id?
        
        var adjustedMainHoleId: MessageId?
        do {
            var upperItem: HistoryIndexEntry?
            self.valueBox.range(self.table, start: self.key(mainHoleId).predecessor, end: self.upperBound(peerId, namespace: mainHoleId.namespace), values: { key, value in
                upperItem = readHistoryIndexEntry(peerId, namespace: mainHoleId.namespace, key: key, value: value)
                return true
            }, limit: 1)
            if let upperItem = upperItem, case let .Hole(upperHole) = upperItem {
                collectedHoles.append(upperHole.maxIndex.id)
                messagesByHole[upperHole.maxIndex.id] = []
                adjustedMainHoleId = upperHole.maxIndex.id
                holesByHole[upperHole.maxIndex.id] = upperHole
                
                if !sortedByIdMessages.isEmpty {
                    var currentLowerBound = sortedByIdMessages[0].id.id
                    var currentUpperBound = sortedByIdMessages[sortedByIdMessages.count - 1].id.id
                    
                    switch fillType.direction {
                        case .LowerToUpper:
                            currentLowerBound = min(currentLowerBound, upperHole.min)
                            if fillType.complete {
                                currentUpperBound = Int32.max
                            }
                        case .UpperToLower:
                            currentUpperBound = max(currentUpperBound, upperHole.maxIndex.id.id)
                            if fillType.complete {
                                currentLowerBound = 1
                            }
                        case .AroundId, .AroundIndex:
                            break
                    }
                    
                    filledLowerBound = currentLowerBound
                    filledUpperBound = currentUpperBound
                } else {
                    switch fillType.direction {
                        case .LowerToUpper:
                            filledLowerBound = upperHole.min
                            if fillType.complete {
                                filledUpperBound = Int32.max
                            }
                        case .UpperToLower:
                            filledUpperBound = upperHole.maxIndex.id.id
                            if fillType.complete {
                                filledLowerBound = 1
                            }
                        case .AroundId, .AroundIndex:
                            break
                    }
                }
            }
        }
        
        if filledLowerBound == nil {
            if !sortedByIdMessages.isEmpty {
                let currentLowerBound = sortedByIdMessages[0].id.id
                let currentUpperBound = sortedByIdMessages[sortedByIdMessages.count - 1].id.id
                filledLowerBound = currentLowerBound
                filledUpperBound = currentUpperBound
            }
        }
        
        var remainingMessages: [InternalStoreMessage] = []
        
        if let lowestMessageId = filledLowerBound, let highestMessageId = filledUpperBound {
            self.valueBox.range(self.table, start: self.key(MessageId(peerId: mainHoleId.peerId, namespace: mainHoleId.namespace, id: lowestMessageId)), end: self.key(MessageId(peerId: mainHoleId.peerId, namespace: mainHoleId.namespace, id: highestMessageId)), values: { key, value in
                let item = readHistoryIndexEntry(peerId, namespace: mainHoleId.namespace, key: key, value: value)
                if case let .Hole(itemHole) = item {
                    if itemHole.min <= highestMessageId && itemHole.maxIndex.id.id >= lowestMessageId {
                        if messagesByHole[itemHole.maxIndex.id] == nil {
                            collectedHoles.append(itemHole.maxIndex.id)
                            holesByHole[itemHole.maxIndex.id] = itemHole
                            messagesByHole[itemHole.maxIndex.id] = []
                        } 
                    }
                }
                return true
            }, limit: 0)
        }
        
        for message in sortedByIdMessages {
            var upperItem: HistoryIndexEntry?
            self.valueBox.range(self.table, start: self.key(message.id).predecessor, end: self.upperBound(peerId, namespace: message.id.namespace), values: { key, value in
                upperItem = readHistoryIndexEntry(peerId, namespace: message.id.namespace, key: key, value: value)
                return true
            }, limit: 1)
            if let upperItem = upperItem, case let .Hole(upperHole) = upperItem, message.id.id >= upperHole.min && message.id.id <= upperHole.maxIndex.id.id {
                if messagesByHole[upperHole.maxIndex.id] == nil {
                    messagesByHole[upperHole.maxIndex.id] = [message]
                    collectedHoles.append(upperHole.maxIndex.id)
                    holesByHole[upperHole.maxIndex.id] = upperHole
                } else {
                    messagesByHole[upperHole.maxIndex.id]!.append(message)
                }
            } else {
                remainingMessages.append(message)
            }
        }
        
        for holeId in collectedHoles {
            let holeMessages = messagesByHole[holeId]!
            let currentFillType: HoleFill
            
            var adjustedLowerComplete = false
            var adjustedUpperComplete = false
            
            if !sortedByIdMessages.isEmpty {
                let currentHole = holesByHole[holeId]!
                
                if filledLowerBound! <= currentHole.min {
                    adjustedLowerComplete = true
                }
                if filledUpperBound! >= currentHole.maxIndex.id.id {
                    adjustedUpperComplete = true
                }
            } else {
                adjustedLowerComplete = true
                adjustedUpperComplete = true
            }
            
            if let adjustedMainHoleId = adjustedMainHoleId {
                if holeId == adjustedMainHoleId {
                    switch fillType.direction {
                        case let .AroundId(id, lowerComplete, upperComplete):
                            if lowerComplete {
                                adjustedLowerComplete = true
                            }
                            if upperComplete {
                                adjustedUpperComplete = true
                            }
                            
                            currentFillType = HoleFill(complete: fillType.complete, direction: .AroundId(id, lowerComplete: adjustedLowerComplete, upperComplete: adjustedUpperComplete))
                        case let .AroundIndex(index, lowerComplete, upperComplete, _, _):
                            if lowerComplete {
                                adjustedLowerComplete = true
                            }
                            if upperComplete {
                                adjustedUpperComplete = true
                            }
                            
                            currentFillType = HoleFill(complete: fillType.complete, direction: .AroundId(index.id, lowerComplete: adjustedLowerComplete, upperComplete: adjustedUpperComplete))
                        case let .LowerToUpper(updatedMaxIndex, clippingMinIndex):
                            currentFillType = HoleFill(complete: fillType.complete || adjustedUpperComplete, direction: .LowerToUpper(updatedMaxIndex: updatedMaxIndex, clippingMinIndex: clippingMinIndex))
                        case let .UpperToLower(updatedMinIndex, clippingMaxIndex):
                            currentFillType = HoleFill(complete: fillType.complete || adjustedLowerComplete, direction: .UpperToLower(updatedMinIndex: updatedMinIndex, clippingMaxIndex: clippingMaxIndex))
                    }
                } else {
                    if holeId < adjustedMainHoleId {
                        currentFillType = HoleFill(complete: adjustedLowerComplete, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil))
                    } else {
                        currentFillType = HoleFill(complete: adjustedUpperComplete, direction: .LowerToUpper(updatedMaxIndex: nil, clippingMinIndex: nil))
                    }
                }
            } else {
                if holeId < mainHoleId {
                    currentFillType = HoleFill(complete: adjustedLowerComplete, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil))
                } else {
                    currentFillType = HoleFill(complete: adjustedUpperComplete, direction: .LowerToUpper(updatedMaxIndex: nil, clippingMinIndex: nil))
                }
            }
            self.fillHole(holeId, fillType: currentFillType, tagMask: tagMask, messages: holeMessages, operations: &operations)
        }
        
        for message in remainingMessages {
            self.addMessages([message], location: .Random, operations: &operations)
        }
    }
    
    func fillHole(_ id: MessageId, fillType: HoleFill, tagMask: MessageTags?, messages: [InternalStoreMessage], operations: inout [MessageHistoryIndexOperation]) {
        self.ensureInitialized(id.peerId, operations: &operations)
        
        var upperItem: HistoryIndexEntry?
        self.valueBox.range(self.table, start: self.key(id).predecessor, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            upperItem = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        let sortedByIdMessages = messages.sorted(by: {$0.id < $1.id})
        
        var remainingMessages = sortedByIdMessages
        
        if let upperItem = upperItem {
            switch upperItem {
                case let .Hole(upperHole):
                    if let tagMask = tagMask {
                        if case .AroundId = fillType.direction {
                            assertionFailure(".AroundId not supported")
                            return
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
                            self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                            self.justInsertHole(MessageHistoryHole(stableId: upperHole.stableId, maxIndex: upperHole.maxIndex, min: upperHole.min, tags: upperHole.tags & ~tagMask.rawValue), operations: &operations)
                        } else {
                            self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                            
                            let clearedTags = upperHole.tags & ~tagMask.rawValue
                            
                            for i in 0 ..< messagesInRange.count {
                                let message = messagesInRange[i]
                                
                                if i == 0 {
                                    if upperHole.min < message.id.id {
                                        let holeTags: UInt32
                                        var holeClosed = false
                                        if fillType.complete {
                                            holeClosed = true
                                        } else if case .LowerToUpper = fillType.direction {
                                            holeClosed = true
                                        }
                                        
                                        if holeClosed {
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
                                        if fillType.complete {
                                            holeTags = clearedTags
                                        } else if case .UpperToLower = fillType.direction {
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
                                    if fillType.complete {
                                        if !removedHole {
                                            removedHole = true
                                            self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                                        }
                                    } else if case .UpperToLower = fillType.direction {
                                        if !removedHole {
                                            removedHole = true
                                            self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                                        }
                                    }
                                }
                                
                                if (maxMessageInRange == nil || maxMessageInRange!.id < message.id) {
                                    maxMessageInRange = message
                                    var holeClosed = false
                                    if fillType.complete {
                                        holeClosed = true
                                    } else if case .LowerToUpper = fillType.direction {
                                        holeClosed = true
                                    }
                                    if holeClosed {
                                        if !removedHole {
                                            removedHole = true
                                            self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                                        }
                                    }
                                }
                                
                                if message.id == upperHole.maxIndex.id {
                                    removedHole = true
                                    self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
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
                                self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                            }
                        } else if case let .LowerToUpper(updatedMaxIndex, _) = fillType.direction {
                            if let maxMessageInRange = maxMessageInRange , maxMessageInRange.id.id != Int32.max && maxMessageInRange.id.id + 1 <= upperHole.maxIndex.id.id {
                                let stableId: UInt32
                                let tags: UInt32 = upperHole.tags
                                if removedHole {
                                    stableId = upperHole.stableId
                                } else {
                                    stableId = self.metadataTable.getNextStableMessageIndexId()
                                }
                                self.justInsertHole(MessageHistoryHole(stableId: stableId, maxIndex: updatedMaxIndex ?? upperHole.maxIndex, min: maxMessageInRange.id.id + 1, tags: tags), operations: &operations)
                            }
                        } else if case .UpperToLower = fillType.direction {
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
                        } else if case let .AroundId(_, lowerComplete, upperComplete) = fillType.direction {
                            if !removedHole {
                                self.justRemove(upperHole.maxIndex, isMessage: false, operations: &operations)
                                removedHole = true
                            }
                            
                            if let minMessageInRange = minMessageInRange, minMessageInRange.id.id - 1 >= upperHole.min && !lowerComplete {
                                let stableId: UInt32 = upperHole.stableId
                                let tags: UInt32 = upperHole.tags
                                
                                self.justInsertHole(MessageHistoryHole(stableId: stableId, maxIndex: MessageIndex(id: MessageId(peerId: id.peerId, namespace: id.namespace, id: minMessageInRange.id.id - 1), timestamp: minMessageInRange.timestamp), min: upperHole.min, tags: tags), operations: &operations)
                            }
                            
                            if let maxMessageInRange = maxMessageInRange, maxMessageInRange.id.id != Int32.max && maxMessageInRange.id.id + 1 <= upperHole.maxIndex.id.id && !upperComplete {
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
        self.valueBox.set(self.table, key: self.key(hole.id), value: value)
        
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
        self.valueBox.set(self.table, key: self.key(index.id), value: value)
        
        operations.append(.InsertMessage(message))
        
        if self.seedConfiguration.globalMessageIdsPeerIdNamespaces.contains(GlobalMessageIdsNamespace(peerIdNamespace: index.id.peerId.namespace, messageIdNamespace: index.id.namespace)) {
            self.globalMessageIdsTable.set(index.id.id, id: index.id)
        }
    }
    
    private func justRemove(_ index: MessageIndex, isMessage: Bool, operations: inout [MessageHistoryIndexOperation]) {
        self.valueBox.remove(self.table, key: self.key(index.id))
        
        operations.append(.Remove(index: index, isMessage: isMessage))
        if self.seedConfiguration.globalMessageIdsPeerIdNamespaces.contains(GlobalMessageIdsNamespace(peerIdNamespace: index.id.peerId.namespace, messageIdNamespace: index.id.namespace)) {
            self.globalMessageIdsTable.remove(index.id.id)
        }
    }
    
    func adjacentItems(_ id: MessageId, bindUpper: Bool = true) -> (lower: HistoryIndexEntry?, upper: HistoryIndexEntry?) {
        let key = self.key(id)
        
        var lowerItem: HistoryIndexEntry?
        self.valueBox.range(self.table, start: bindUpper ? key : key.successor, end: self.lowerBound(id.peerId, namespace: id.namespace), values: { key, value in
            lowerItem = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        var upperItem: HistoryIndexEntry?
        self.valueBox.range(self.table, start: bindUpper ? key.predecessor : key, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            upperItem = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return true
        }, limit: 1)
        
        return (lower: lowerItem, upper: upperItem)
    }
    
    func getEnsureInitialized(_ id: MessageId, operations: inout [MessageHistoryIndexOperation]) -> HistoryIndexEntry? {
        return self.getInternal(id, ensureInitialized: true, operations: &operations)
    }
    
    func getMaybeUninitialized(_ id: MessageId) -> HistoryIndexEntry? {
        var operations: [MessageHistoryIndexOperation] = []
        let result = self.getInternal(id, ensureInitialized: false, operations: &operations)
        assert(operations.isEmpty)
        return result
    }
    
    private func getInternal(_ id: MessageId, ensureInitialized: Bool, operations: inout [MessageHistoryIndexOperation]) -> HistoryIndexEntry? {
        if ensureInitialized {
            self.ensureInitialized(id.peerId, operations: &operations)
        }
        
        let key = self.key(id)
        if let value = self.valueBox.get(self.table, key: key) {
            return readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
        }
        return nil
    }
    
    func top(_ peerId: PeerId, namespace: MessageId.Namespace, operations: inout [MessageHistoryIndexOperation]) -> HistoryIndexEntry? {
        self.ensureInitialized(peerId, operations: &operations)
        
        var entry: HistoryIndexEntry?
        self.valueBox.range(self.table, start: self.upperBound(peerId, namespace: namespace), end: self.lowerBound(peerId, namespace: namespace), values: { key, value in
            entry = readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value)
            return false
        }, limit: 1)
        
        return entry
    }
    
    func topMaybeUninitialized(_ peerId: PeerId, namespace: MessageId.Namespace) -> HistoryIndexEntry? {
        var entry: HistoryIndexEntry?
        self.valueBox.range(self.table, start: self.upperBound(peerId, namespace: namespace), end: self.lowerBound(peerId, namespace: namespace), values: { key, value in
            entry = readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value)
            return false
        }, limit: 1)
        
        return entry
    }
    
    func exists(_ id: MessageId) -> Bool {
        return self.valueBox.exists(self.table, key: self.key(id))
    }
    
    func holeContainingId(_ id: MessageId) -> MessageHistoryHole? {
        var result: MessageHistoryHole?
        self.valueBox.range(self.table, start: self.key(MessageId(peerId: id.peerId, namespace: id.namespace, id: id.id)).predecessor, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
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
        
        if minId <= maxId {
            self.valueBox.range(self.table, start: self.key(MessageId(peerId: peerId, namespace: namespace, id: minId)).predecessor, end: self.key(MessageId(peerId: peerId, namespace: namespace, id: maxId)).successor, values: { _, value in
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
            
            self.valueBox.range(self.table, start: self.key(MessageId(peerId: peerId, namespace: namespace, id: maxId)), end: self.upperBound(peerId, namespace: namespace), values: { key, value in
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
        }
        
        return (count, holes)
    }
    
    func incomingMessageCountInIds(_ peerId: PeerId, namespace: MessageId.Namespace, ids: [MessageId.Id]) -> (Int, Bool) {
        var count = 0
        var holes = false
        
        for id in ids {
            self.valueBox.range(self.table, start: self.key(MessageId(peerId: peerId, namespace: namespace, id: id)).predecessor, end: self.upperBound(peerId, namespace: namespace), values: { key, value in
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
    
    func entriesAround(id: MessageId, count: Int) -> ([HistoryIndexEntry], HistoryIndexEntry?, HistoryIndexEntry?) {
        var lowerEntries: [HistoryIndexEntry] = []
        var upperEntries: [HistoryIndexEntry] = []
        var lower: HistoryIndexEntry?
        var upper: HistoryIndexEntry?
        
        self.valueBox.range(self.table, start: self.key(id), end: self.lowerBound(id.peerId, namespace: id.namespace), values: { key, value in
            lowerEntries.append(readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value))
            return true
        }, limit: count / 2 + 1)
        
        if lowerEntries.count >= count / 2 + 1 {
            lower = lowerEntries.last
            lowerEntries.removeLast()
        }
        
        self.valueBox.range(self.table, start: self.key(id).predecessor, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            upperEntries.append(readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value))
            return true
        }, limit: count - lowerEntries.count + 1)
        if upperEntries.count >= count - lowerEntries.count + 1 {
            upper = upperEntries.last
            upperEntries.removeLast()
        }
        
        if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
            var additionalLowerEntries: [HistoryIndexEntry] = []
            self.valueBox.range(self.table, start: self.key(lowerEntries.last!.index.id), end: self.lowerBound(id.peerId, namespace: id.namespace), values: { key, value in
                additionalLowerEntries.append(readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value))
                return true
            }, limit: count - lowerEntries.count - upperEntries.count + 1)
            if additionalLowerEntries.count >= count - lowerEntries.count + upperEntries.count + 1 {
                lower = additionalLowerEntries.last
                additionalLowerEntries.removeLast()
            }
            lowerEntries.append(contentsOf: additionalLowerEntries)
        }
        
        var entries: [HistoryIndexEntry] = []
        entries.append(contentsOf: lowerEntries.reversed())
        entries.append(contentsOf: upperEntries)
        return (entries: entries, lower: lower, upper: upper)
    }
    
    func earlierEntries(id: MessageId, count: Int) -> [HistoryIndexEntry] {
        var entries: [HistoryIndexEntry] = []
        let key = self.key(id)
        self.valueBox.range(self.table, start: key, end: self.lowerBound(id.peerId, namespace: id.namespace), values: { key, value in
            entries.append(readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value))
            return true
        }, limit: count)
        return entries
    }
    
    func laterEntries(id: MessageId, count: Int) -> [HistoryIndexEntry] {
        var entries: [HistoryIndexEntry] = []
        let key = self.key(id)
        self.valueBox.range(self.table, start: key, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            entries.append(readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value))
            return true
        }, limit: count)
        return entries
    }
    
    func debugList(_ peerId: PeerId, namespace: MessageId.Namespace) -> [HistoryIndexEntry] {
        var list: [HistoryIndexEntry] = []
        self.valueBox.range(self.table, start: self.lowerBound(peerId, namespace: namespace), end: self.upperBound(peerId, namespace: namespace), values: { key, value in
            list.append(readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value))
            
            return true
        }, limit: 0)
        return list
    }
}
