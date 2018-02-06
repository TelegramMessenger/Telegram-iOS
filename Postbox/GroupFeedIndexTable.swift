import Foundation

private enum GroupFeedIndexEntryType: Int8 {
    case message = 0
    case hole = 1
}

private struct GroupFeedIndexHole {
    let lowerIndex: MessageIndex
    let upperIndex: MessageIndex
}

private enum GroupFeedIndexEntry {
    case message(MessageIndex)
    case hole(stableId: UInt32, hole: GroupFeedIndexHole)
}

enum GroupFeedIndexOperation {
    case insertMessage(IntermediateMessage)
    case removeMessage(MessageIndex)
    case insertHole(MessageHistoryHole, lowerIndex: MessageIndex)
    case removeHole(MessageIndex)
}

private func addOperation(groupId: PeerGroupId, operation: GroupFeedIndexOperation, to operations: inout [PeerGroupId: [GroupFeedIndexOperation]]) {
    if operations[groupId] == nil {
        operations[groupId] = []
    }
    operations[groupId]!.append(operation)
}

private func extractKey(_ key: ValueBoxKey) -> (PeerGroupId, MessageIndex) {
    return (
        PeerGroupId(rawValue: key.getInt32(0)),
        MessageIndex(
            id: MessageId(peerId: PeerId(key.getInt64(4 + 4)), namespace: key.getInt32(4 + 4 + 8), id: key.getInt32(4 + 4 + 8 + 4)),
            timestamp: key.getInt32(4)
        )
    )
}

private func writeEntry(_ entry: GroupFeedIndexEntry, to buffer: WriteBuffer) {
    switch entry {
        case .message:
            var typeValue: Int8 = GroupFeedIndexEntryType.message.rawValue
            buffer.write(&typeValue, offset: 0, length: 1)
        case let .hole(stableId, hole):
            var typeValue: Int8 = GroupFeedIndexEntryType.hole.rawValue
            buffer.write(&typeValue, offset: 0, length: 1)
            
            var stableIdValue: UInt32 = stableId
            var timestampValue: Int32 = hole.lowerIndex.timestamp
            if timestampValue == 0 {
                //print("writing 0 hole")
            }
            var idPeerIdValue: Int64 = hole.lowerIndex.id.peerId.toInt64()
            var idNamespaceValue: Int32 = hole.lowerIndex.id.namespace
            var idIdValue: Int32 = hole.lowerIndex.id.id
            buffer.write(&stableIdValue, offset: 0, length: 4)
            buffer.write(&timestampValue, offset: 0, length: 4)
            buffer.write(&idPeerIdValue, offset: 0, length: 8)
            buffer.write(&idNamespaceValue, offset: 0, length: 4)
            buffer.write(&idIdValue, offset: 0, length: 4)
    }
}

private func readEntry(groupId: PeerGroupId, key: ValueBoxKey, value: ReadBuffer) -> GroupFeedIndexEntry {
    let (keyGroupId, index) = extractKey(key)
    assert(keyGroupId == groupId)
    
    var typeValue: Int8 = 0
    value.read(&typeValue, offset: 0, length: 1)
    switch typeValue {
        case GroupFeedIndexEntryType.message.rawValue:
            return .message(index)
        case GroupFeedIndexEntryType.hole.rawValue:
            var stableIdValue: UInt32 = 0
            var timestampValue: Int32 = 0
            var idPeerIdValue: Int64 = 0
            var idNamespaceValue: Int32 = 0
            var idIdValue: Int32 = 0
            value.read(&stableIdValue, offset: 0, length: 4)
            value.read(&timestampValue, offset: 0, length: 4)
            value.read(&idPeerIdValue, offset: 0, length: 8)
            value.read(&idNamespaceValue, offset: 0, length: 4)
            value.read(&idIdValue, offset: 0, length: 4)
            return .hole(stableId: stableIdValue, hole: GroupFeedIndexHole(lowerIndex: MessageIndex(id: MessageId(peerId: PeerId(idPeerIdValue), namespace: idNamespaceValue, id: idIdValue), timestamp: timestampValue), upperIndex: index))
        default:
            assertionFailure()
            return GroupFeedIndexEntry.hole(stableId: 0, hole: GroupFeedIndexHole(lowerIndex: MessageIndex.absoluteLowerBound(), upperIndex: MessageIndex.absoluteUpperBound()))
    }
}

final class GroupFeedIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    private let metadataTable: MessageHistoryMetadataTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, metadataTable: MessageHistoryMetadataTable) {
        self.metadataTable = metadataTable
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func lowerBound(groupId: PeerGroupId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: groupId.rawValue)
        return key
    }
    
    private func upperBound(groupId: PeerGroupId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: groupId.rawValue)
        return key.successor
    }
    
    private func key(groupId: PeerGroupId, index: MessageIndex, sharedKey: ValueBoxKey = ValueBoxKey(length: 4 + 4 + 8 + 4 + 4)) -> ValueBoxKey {
        sharedKey.setInt32(0, value: groupId.rawValue)
        sharedKey.setInt32(4, value: index.timestamp)
        sharedKey.setInt64(4 + 4, value: index.id.peerId.toInt64())
        sharedKey.setInt32(4 + 4 + 8, value: index.id.namespace)
        sharedKey.setInt32(4 + 4 + 8 + 4, value: index.id.id)
        return sharedKey
    }
    
    private func ensureInitialized(_ groupId: PeerGroupId) {
        if !self.metadataTable.isGroupFeedIndexInitialized(groupId) {
            let buffer = WriteBuffer()
            writeEntry(.hole(stableId: self.metadataTable.getNextStableMessageIndexId(), hole: GroupFeedIndexHole(lowerIndex: MessageIndex.absoluteLowerBound().successor(), upperIndex: MessageIndex.absoluteUpperBound().predecessor())), to: buffer)
            self.valueBox.set(self.table, key: self.key(groupId: groupId, index: MessageIndex.absoluteUpperBound().predecessor()), value: buffer.readBufferNoCopy())
            self.metadataTable.setGroupFeedIndexInitialized(groupId)
        }
    }
    
    func add(groupId: PeerGroupId, message: IntermediateMessage, operations: inout [PeerGroupId: [GroupFeedIndexOperation]]) {
        self.ensureInitialized(groupId)
        
        let messageIndex = MessageIndex(message)
        
        var exists = false
        var inHole = false
        self.valueBox.range(self.table, start: self.key(groupId: groupId, index: messageIndex).predecessor, end: self.key(groupId: groupId, index: MessageIndex.absoluteUpperBound()), values: { key, value in
            switch readEntry(groupId: groupId, key: key, value: value) {
                case let .message(index):
                    if index.id == messageIndex.id {
                        assert(index == messageIndex)
                        exists = true
                    }
                case let .hole(_, hole):
                    if messageIndex >= hole.lowerIndex && messageIndex <= hole.upperIndex {
                        inHole = true
                    }
            }
            return false
        }, limit: 1)
        
        if !exists && !inHole {
            let buffer = WriteBuffer()
            writeEntry(.message(messageIndex), to: buffer)
            self.valueBox.set(self.table, key: self.key(groupId: groupId, index: messageIndex), value: buffer.readBufferNoCopy())
            addOperation(groupId: groupId, operation: .insertMessage(message), to: &operations)
        }
    }
    
    func remove(groupId: PeerGroupId, messageIndex: MessageIndex, operations: inout [PeerGroupId: [GroupFeedIndexOperation]]) {
        self.ensureInitialized(groupId)
        let key = self.key(groupId: groupId, index: messageIndex)
        if let value = self.valueBox.get(self.table, key: key) {
            switch readEntry(groupId: groupId, key: key, value: value) {
                case .message:
                    self.valueBox.remove(self.table, key: self.key(groupId: groupId, index: messageIndex))
                    addOperation(groupId: groupId, operation: .removeMessage(messageIndex), to: &operations)
                case .hole:
                    assertionFailure()
                    break
            }
        }
    }
    
    func addHoleFromLatestEntries(groupId: PeerGroupId, messageHistoryTable: MessageHistoryTable, operations: inout [PeerGroupId: [GroupFeedIndexOperation]]) {
        self.ensureInitialized(groupId)
        let entries = self.entriesInRange(groupId: groupId, fromIndex: MessageIndex.absoluteUpperBound(), toIndex: MessageIndex.absoluteLowerBound(), count: 1, messageHistoryTable: messageHistoryTable)
        if let entry = entries.first {
            switch entry {
                case .Message:
                    self.addHole(groupId: groupId, stableId: self.metadataTable.getNextStableMessageIndexId(), hole: GroupFeedIndexHole(lowerIndex: entry.index.successor(), upperIndex: MessageIndex.absoluteUpperBound().predecessor()), addOperation: { groupId, operation in
                        addOperation(groupId: groupId, operation: operation, to: &operations)
                    })
                case let .Hole(hole, lowerIndex):
                    if hole.maxIndex.timestamp != Int32.max {
                        if let lowerIndex = lowerIndex {
                            self.removeHole(groupId: groupId, messageIndex: entry.index, addOperation: { groupId, operation in
                                addOperation(groupId: groupId, operation: operation, to: &operations)
                            })
                            self.addHole(groupId: groupId, stableId: self.metadataTable.getNextStableMessageIndexId(), hole: GroupFeedIndexHole(lowerIndex: lowerIndex, upperIndex: MessageIndex.absoluteUpperBound().predecessor()), addOperation: { groupId, operation in
                                addOperation(groupId: groupId, operation: operation, to: &operations)
                            })
                        } else {
                            assertionFailure()
                        }
                    }
            }
        }
    }
    
    private func addHole(groupId: PeerGroupId, stableId: UInt32, hole: GroupFeedIndexHole, addOperation: (PeerGroupId, GroupFeedIndexOperation) -> Void) {
        self.ensureInitialized(groupId)
        
        let buffer = WriteBuffer()
        writeEntry(.hole(stableId: stableId, hole: hole), to: buffer)
        self.valueBox.set(self.table, key: self.key(groupId: groupId, index: hole.upperIndex), value: buffer.readBufferNoCopy())
        addOperation(groupId, .insertHole(MessageHistoryHole(stableId: stableId, maxIndex: hole.upperIndex, min: hole.upperIndex.id.id, tags: 0), lowerIndex: hole.lowerIndex))
    }
    
    private func removeHole(groupId: PeerGroupId, messageIndex: MessageIndex, addOperation: (PeerGroupId, GroupFeedIndexOperation) -> Void) {
        let key = self.key(groupId: groupId, index: messageIndex)
        if let value = self.valueBox.get(self.table, key: key) {
            switch readEntry(groupId: groupId, key: key, value: value) {
                case .hole:
                    self.valueBox.remove(self.table, key: self.key(groupId: groupId, index: messageIndex))
                    addOperation(groupId, .removeHole(messageIndex))
                case .message:
                    assertionFailure()
                    break
            }
        }
    }
    
    func dropPeerEntries(groupId: PeerGroupId, peerId: PeerId, operations: inout [PeerGroupId: [GroupFeedIndexOperation]]) {
        self.ensureInitialized(groupId)
        
        var removeKeys: [ValueBoxKey] = []
        self.valueBox.range(self.table, start: self.lowerBound(groupId: groupId), end: self.upperBound(groupId: groupId), values: { key, value in
            switch readEntry(groupId: groupId, key: key, value: value) {
                case let .message(index):
                    if index.id.peerId == peerId {
                        removeKeys.append(key)
                        addOperation(groupId: groupId, operation: .removeMessage(index), to: &operations)
                    }
                case .hole:
                    break
            }
            return true
        }, limit: 0)
        for key in removeKeys {
            self.valueBox.remove(self.table, key: key)
        }
    }
    
    func dropEntries(groupId: PeerGroupId, operations: inout [PeerGroupId: [GroupFeedIndexOperation]]) {
        self.ensureInitialized(groupId)
        
        var removeKeys: [ValueBoxKey] = []
        self.valueBox.range(self.table, start: self.lowerBound(groupId: groupId), end: self.upperBound(groupId: groupId), values: { key, value in
            removeKeys.append(key)
            switch readEntry(groupId: groupId, key: key, value: value) {
                case let .message(index):
                    addOperation(groupId: groupId, operation: .removeMessage(index), to: &operations)
                case let .hole(_, hole):
                    addOperation(groupId: groupId, operation: .removeHole(hole.upperIndex), to: &operations)
            }
            return true
        }, limit: 0)
        for key in removeKeys {
            self.valueBox.remove(self.table, key: key)
        }
        
        let buffer = WriteBuffer()
        let hole = GroupFeedIndexHole(lowerIndex: MessageIndex.absoluteLowerBound().successor(), upperIndex: MessageIndex.absoluteUpperBound().predecessor())
        let holeStableId = self.metadataTable.getNextStableMessageIndexId()
        let holeEntry: GroupFeedIndexEntry = .hole(stableId: holeStableId, hole: hole)
        writeEntry(holeEntry, to: buffer)
        self.valueBox.set(self.table, key: self.key(groupId: groupId, index: hole.upperIndex), value: buffer.readBufferNoCopy())
        addOperation(groupId: groupId, operation: .insertHole(MessageHistoryHole(stableId: holeStableId, maxIndex: hole.upperIndex, min: hole.upperIndex.id.id, tags: 0), lowerIndex: hole.lowerIndex), to: &operations)
    }
    
    func copyPeerEntries(groupId: PeerGroupId, peerId: PeerId, messageHistoryTable: MessageHistoryTable, operations: inout [PeerGroupId: [GroupFeedIndexOperation]]) {
        for index in messageHistoryTable.allMessageIndices(peerId) {
            if let message = messageHistoryTable.getMessage(index) {
                self.add(groupId: groupId, message: message, operations: &operations)
            }
        }
    }
    
    func fillMultipleHoles(insertMessage: (InternalStoreMessage) -> Void, groupId: PeerGroupId, mainHoleMaxIndex: MessageIndex, fillType: HoleFill, messages: [InternalStoreMessage], addOperation: (PeerGroupId, GroupFeedIndexOperation) -> Void) {
        self.ensureInitialized(groupId)
        
        let sortedByIndexMessages = messages.sorted(by: { MessageIndex($0) < MessageIndex($1) })
        
        var collectedHoles: [MessageIndex] = []
        var messagesByHole: [MessageIndex: [InternalStoreMessage]] = [:]
        var holesByHole: [MessageIndex: GroupFeedIndexHole] = [:]
        
        var filledUpperBound: MessageIndex?
        var filledLowerBound: MessageIndex?
        
        //self.debugPrintEntries(groupId: groupId)
        
        var adjustedMainHoleIndex: MessageIndex?
        do {
            var upperItem: GroupFeedIndexEntry?
            self.valueBox.range(self.table, start: self.key(groupId: groupId, index: mainHoleMaxIndex).predecessor, end: self.upperBound(groupId: groupId), values: { key, value in
                upperItem = readEntry(groupId: groupId, key: key, value: value)
                return true
            }, limit: 1)
            if let upperItem = upperItem, case let .hole(_, upperHole) = upperItem {
                collectedHoles.append(upperHole.upperIndex)
                messagesByHole[upperHole.upperIndex] = []
                adjustedMainHoleIndex = upperHole.upperIndex
                holesByHole[upperHole.upperIndex] = upperHole
                
                if !sortedByIndexMessages.isEmpty {
                    var currentLowerBound = MessageIndex(sortedByIndexMessages[0])
                    var currentUpperBound = MessageIndex(sortedByIndexMessages[sortedByIndexMessages.count - 1])
                    
                    switch fillType.direction {
                        case .LowerToUpper:
                            if upperHole.lowerIndex < currentLowerBound {
                                currentLowerBound = upperHole.lowerIndex
                            }
                            if fillType.complete {
                                currentUpperBound = MessageIndex.absoluteUpperBound()
                            }
                        case .UpperToLower:
                            if upperHole.upperIndex > currentUpperBound {
                                currentUpperBound = upperHole.upperIndex
                            }
                            if fillType.complete {
                                currentLowerBound = MessageIndex.absoluteLowerBound()
                            }
                        case .AroundId, .AroundIndex:
                            break
                    }
                    
                    filledLowerBound = currentLowerBound
                    filledUpperBound = currentUpperBound
                } else {
                    switch fillType.direction {
                        case .LowerToUpper:
                            filledLowerBound = upperHole.lowerIndex
                            if fillType.complete {
                                filledUpperBound = MessageIndex.absoluteUpperBound()
                            }
                        case .UpperToLower:
                            filledUpperBound = upperHole.upperIndex
                            if fillType.complete {
                                filledLowerBound = MessageIndex.absoluteLowerBound()
                            }
                        case .AroundId, .AroundIndex:
                            break
                    }
                }
            }
        }
        
        if filledLowerBound == nil {
            if !sortedByIndexMessages.isEmpty {
                let currentLowerBound = MessageIndex(sortedByIndexMessages[0])
                let currentUpperBound = MessageIndex(sortedByIndexMessages[sortedByIndexMessages.count - 1])
                filledLowerBound = currentLowerBound
                filledUpperBound = currentUpperBound
            }
        }
        
        var remainingMessages: [InternalStoreMessage] = []
        
        if let lowestMessageIndex = filledLowerBound, let highestMessageIndex = filledUpperBound {
            self.valueBox.range(self.table, start: self.key(groupId: groupId, index: lowestMessageIndex), end: self.key(groupId: groupId, index: highestMessageIndex), values: { key, value in
                let item = readEntry(groupId: groupId, key: key, value: value)
                if case let .hole(_, itemHole) = item {
                    if itemHole.lowerIndex <= highestMessageIndex && itemHole.upperIndex >= lowestMessageIndex {
                        if messagesByHole[itemHole.upperIndex] == nil {
                            collectedHoles.append(itemHole.upperIndex)
                            holesByHole[itemHole.upperIndex] = itemHole
                            messagesByHole[itemHole.upperIndex] = []
                        }
                    }
                }
                return true
            }, limit: 0)
        }
        
        for message in sortedByIndexMessages {
            var upperItem: GroupFeedIndexEntry?
            self.valueBox.range(self.table, start: self.key(groupId: groupId, index: MessageIndex(message)).predecessor, end: self.upperBound(groupId: groupId), values: { key, value in
                upperItem = readEntry(groupId: groupId, key: key, value: value)
                return true
            }, limit: 1)
            if let upperItem = upperItem, case let .hole(_, upperHole) = upperItem, MessageIndex(message) >= upperHole.lowerIndex && MessageIndex(message) <= upperHole.upperIndex {
                if messagesByHole[upperHole.upperIndex] == nil {
                    messagesByHole[upperHole.upperIndex] = [message]
                    collectedHoles.append(upperHole.upperIndex)
                    holesByHole[upperHole.upperIndex] = upperHole
                } else {
                    messagesByHole[upperHole.upperIndex]!.append(message)
                }
            } else {
                remainingMessages.append(message)
            }
        }
        
        for holeIndex in collectedHoles {
            let holeMessages = messagesByHole[holeIndex]!
            let currentFillType: HoleFill
            
            var adjustedLowerComplete = false
            var adjustedUpperComplete = false
            
            if !sortedByIndexMessages.isEmpty {
                let currentHole = holesByHole[holeIndex]!
                
                if filledLowerBound! <= currentHole.lowerIndex {
                    adjustedLowerComplete = true
                }
                if filledUpperBound! >= currentHole.upperIndex {
                    adjustedUpperComplete = true
                }
            } else {
                adjustedLowerComplete = true
                adjustedUpperComplete = true
            }
            
            if let adjustedMainHoleIndex = adjustedMainHoleIndex {
                if holeIndex == adjustedMainHoleIndex {
                    switch fillType.direction {
                        case .AroundId:
                            preconditionFailure()
                            break
                        case let .AroundIndex(index, lowerComplete, upperComplete, clippingMinIndex, clippingMaxIndex):
                            if lowerComplete {
                                adjustedLowerComplete = true
                            }
                            if upperComplete {
                                adjustedUpperComplete = true
                            }
                            
                            currentFillType = HoleFill(complete: fillType.complete, direction: .AroundIndex(index, lowerComplete: adjustedLowerComplete, upperComplete: adjustedUpperComplete, clippingMinIndex: clippingMinIndex, clippingMaxIndex: clippingMaxIndex))
                        case let .LowerToUpper(updatedMaxIndex, clippingMinIndex):
                            currentFillType = HoleFill(complete: fillType.complete || adjustedUpperComplete, direction: .LowerToUpper(updatedMaxIndex: updatedMaxIndex, clippingMinIndex: clippingMinIndex))
                        case let .UpperToLower(updatedMinIndex, clippingMaxIndex):
                            currentFillType = HoleFill(complete: fillType.complete || adjustedLowerComplete, direction: .UpperToLower(updatedMinIndex: updatedMinIndex, clippingMaxIndex: clippingMaxIndex))
                    }
                } else {
                    if holeIndex < adjustedMainHoleIndex {
                        currentFillType = HoleFill(complete: adjustedLowerComplete, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil))
                    } else {
                        currentFillType = HoleFill(complete: adjustedUpperComplete, direction: .LowerToUpper(updatedMaxIndex: nil, clippingMinIndex: nil))
                    }
                }
            } else {
                if holeIndex < mainHoleMaxIndex {
                    currentFillType = HoleFill(complete: adjustedLowerComplete, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil))
                } else {
                    currentFillType = HoleFill(complete: adjustedUpperComplete, direction: .LowerToUpper(updatedMaxIndex: nil, clippingMinIndex: nil))
                }
            }
            self.fillHole(insertMessage: insertMessage, groupId: groupId, index: holeIndex, fillType: currentFillType, messages: holeMessages, addOperation: addOperation)
        }
        
        //self.debugPrintEntries(groupId: groupId)
        
        for message in remainingMessages {
            insertMessage(message)
        }
        
        //self.debugPrintEntries(groupId: groupId)
    }
    
    private func fillHole(insertMessage: (InternalStoreMessage) -> Void, groupId: PeerGroupId, index: MessageIndex, fillType: HoleFill, messages: [InternalStoreMessage], addOperation: (PeerGroupId, GroupFeedIndexOperation) -> Void) {
        
        var upperItem: GroupFeedIndexEntry?
        self.valueBox.range(self.table, start: self.key(groupId: groupId, index: index).predecessor, end: self.upperBound(groupId: groupId), values: { key, value in
            upperItem = readEntry(groupId: groupId, key: key, value: value)
            return true
        }, limit: 1)
        
        let sortedByIndexMessages = messages.sorted(by: { MessageIndex($0) < MessageIndex($1) })
        
        var remainingMessages = sortedByIndexMessages
        
        if let upperItem = upperItem {
            switch upperItem {
                case let .hole(upperHoleStableId, upperHole):
                    var i = 0
                    var minMessageInRange: InternalStoreMessage?
                    var maxMessageInRange: InternalStoreMessage?
                    var removedHole = false
                    while i < remainingMessages.count {
                        let message = remainingMessages[i]
                        if MessageIndex(message) >= upperHole.lowerIndex && MessageIndex(message) <= upperHole.upperIndex {
                            if minMessageInRange == nil || MessageIndex(minMessageInRange!) > MessageIndex(message) {
                                minMessageInRange = message
                                
                                if !removedHole {
                                    removedHole = true
                                    self.removeHole(groupId: groupId, messageIndex: upperHole.upperIndex, addOperation: addOperation)
                                }
                            }
                            
                            if (maxMessageInRange == nil || MessageIndex(maxMessageInRange!) < MessageIndex(message)) {
                                maxMessageInRange = message

                                if !removedHole {
                                    removedHole = true
                                    self.removeHole(groupId: groupId, messageIndex: upperHole.upperIndex, addOperation: addOperation)
                                }
                            }
                            
                            if MessageIndex(message) == upperHole.upperIndex {
                                removedHole = true
                                self.removeHole(groupId: groupId, messageIndex: upperHole.upperIndex, addOperation: addOperation)
                            }
                            
                            insertMessage(message)
                            
                            remainingMessages.remove(at: i)
                        } else {
                            i += 1
                        }
                    }
                    if fillType.complete {
                        if !removedHole {
                            removedHole = true
                            self.removeHole(groupId: groupId, messageIndex: upperHole.upperIndex, addOperation: addOperation)
                        }
                    } else if case let .LowerToUpper(updatedMaxIndex, clippingMinIndex) = fillType.direction {
                        if let maxMessageInRange = maxMessageInRange, MessageIndex(maxMessageInRange).successor() <= upperHole.upperIndex {
                            let stableId: UInt32
                            if removedHole {
                                stableId = upperHoleStableId
                            } else {
                                stableId = self.metadataTable.getNextStableMessageIndexId()
                            }
                            self.addHole(groupId: groupId, stableId: stableId, hole: GroupFeedIndexHole(lowerIndex: clippingMinIndex ?? MessageIndex(maxMessageInRange).successor(), upperIndex: updatedMaxIndex ?? upperHole.upperIndex), addOperation: addOperation)
                        }
                    } else if case let .UpperToLower(_, clippingMaxIndex) = fillType.direction {
                        if let minMessageInRange = minMessageInRange , MessageIndex(minMessageInRange).predecessor() >= upperHole.lowerIndex {
                            let stableId: UInt32
                            if removedHole {
                                stableId = upperHoleStableId
                            } else {
                                stableId = self.metadataTable.getNextStableMessageIndexId()
                            }
                            let updatedUpperIndex: MessageIndex
                            let messageUpperIndex = MessageIndex(minMessageInRange).predecessor()
                            if let clippingMaxIndex = clippingMaxIndex, clippingMaxIndex < messageUpperIndex {
                                updatedUpperIndex = clippingMaxIndex
                            } else {
                                updatedUpperIndex = messageUpperIndex
                            }
                            self.addHole(groupId: groupId, stableId: stableId, hole: GroupFeedIndexHole(lowerIndex: upperHole.lowerIndex, upperIndex: updatedUpperIndex), addOperation: addOperation)
                        }
                    } else if case let .AroundIndex(_, lowerComplete, upperComplete, clippingMinIndex, clippingMaxIndex) = fillType.direction {
                        if !removedHole {
                            self.removeHole(groupId: groupId, messageIndex: upperHole.upperIndex, addOperation: addOperation)
                            removedHole = true
                        }
                        
                        let lowerHoleIndex: MessageIndex?
                        if let minMessageInRange = minMessageInRange, let clippingMinIndex = clippingMinIndex {
                            if clippingMinIndex < MessageIndex(minMessageInRange) {
                                lowerHoleIndex = clippingMinIndex
                            } else {
                                lowerHoleIndex = MessageIndex(minMessageInRange)
                            }
                        } else if let minMessageInRange = minMessageInRange {
                            lowerHoleIndex = MessageIndex(minMessageInRange)
                        } else {
                            lowerHoleIndex = clippingMinIndex
                        }
                        
                        let upperHoleIndex: MessageIndex?
                        if let maxMessageInRange = maxMessageInRange, let clippingMaxIndex = clippingMaxIndex {
                            if clippingMaxIndex > MessageIndex(maxMessageInRange) {
                                upperHoleIndex = clippingMaxIndex
                            } else {
                                upperHoleIndex = MessageIndex(maxMessageInRange)
                            }
                        } else if let maxMessageInRange = maxMessageInRange {
                            upperHoleIndex = MessageIndex(maxMessageInRange)
                        } else {
                            upperHoleIndex = clippingMaxIndex
                        }
                        
                        if let lowerHoleIndex = lowerHoleIndex, lowerHoleIndex.predecessor() >= upperHole.lowerIndex && !lowerComplete {
                            let stableId: UInt32 = upperHoleStableId
                            
                            self.addHole(groupId: groupId, stableId: stableId, hole: GroupFeedIndexHole(lowerIndex: upperHole.lowerIndex, upperIndex: lowerHoleIndex.predecessor()), addOperation: addOperation)
                        }
                        
                        if let upperHoleIndex = upperHoleIndex, upperHoleIndex.successor() <= upperHole.upperIndex && !upperComplete {
                            let stableId: UInt32 = self.metadataTable.getNextStableMessageIndexId()
                            
                            self.addHole(groupId: groupId, stableId: stableId, hole: GroupFeedIndexHole(lowerIndex: upperHoleIndex.successor(), upperIndex: upperHole.upperIndex), addOperation: addOperation)
                        }
                    }
                case .message:
                    break
            }
        }
        
        for message in remainingMessages {
            insertMessage(message)
        }
    }
    
    func entriesAround(groupId: PeerGroupId, index: MessageIndex, count: Int, messageHistoryTable: MessageHistoryTable) -> (entries: [IntermediateMessageHistoryEntry], lower: IntermediateMessageHistoryEntry?, upper: IntermediateMessageHistoryEntry?) {
        var lowerEntries: [IntermediateMessageHistoryEntry] = []
        var upperEntries: [IntermediateMessageHistoryEntry] = []
        var lower: IntermediateMessageHistoryEntry?
        var upper: IntermediateMessageHistoryEntry?
        
        lowerEntries.append(contentsOf: self.earlierEntries(groupId: groupId, index: index, count: count / 2 + 1, messageHistoryTable: messageHistoryTable))
        
        if lowerEntries.count >= count / 2 + 1 {
            lower = lowerEntries.last
            lowerEntries.removeLast()
        }
        
        upperEntries.append(contentsOf: self.laterEntries(groupId: groupId, index: index.predecessor(), count: count - lowerEntries.count + 1, messageHistoryTable: messageHistoryTable))
        
        if upperEntries.count >= count - lowerEntries.count + 1 {
            upper = upperEntries.last
            upperEntries.removeLast()
        }
        
        if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
            var additionalLowerEntries: [IntermediateMessageHistoryEntry] = []
            
            additionalLowerEntries.append(contentsOf: self.earlierEntries(groupId: groupId, index: lowerEntries.last!.index, count: count - lowerEntries.count - upperEntries.count + 1, messageHistoryTable: messageHistoryTable))
            
            if additionalLowerEntries.count >= count - lowerEntries.count + upperEntries.count + 1 {
                lower = additionalLowerEntries.last
                additionalLowerEntries.removeLast()
            }
            lowerEntries.append(contentsOf: additionalLowerEntries)
        }
        
        var entries: [IntermediateMessageHistoryEntry] = []
        entries.append(contentsOf: lowerEntries.reversed())
        entries.append(contentsOf: upperEntries)
        return (entries: entries, lower: lower, upper: upper)
    }
    
    func earlierEntries(groupId: PeerGroupId, index: MessageIndex?, count: Int, messageHistoryTable: MessageHistoryTable) -> [IntermediateMessageHistoryEntry] {
        return self.entriesInRange(groupId: groupId, fromIndex: index ?? MessageIndex.absoluteUpperBound(), toIndex: MessageIndex.absoluteLowerBound(), count: count, messageHistoryTable: messageHistoryTable)
    }
    
    func laterEntries(groupId: PeerGroupId, index: MessageIndex?, count: Int, messageHistoryTable: MessageHistoryTable) -> [IntermediateMessageHistoryEntry] {
        return self.entriesInRange(groupId: groupId, fromIndex: index ?? MessageIndex.absoluteLowerBound(), toIndex: MessageIndex.absoluteUpperBound(), count: count, messageHistoryTable: messageHistoryTable)
    }
    
    private func entriesInRange(groupId: PeerGroupId, fromIndex: MessageIndex, toIndex: MessageIndex, count: Int, messageHistoryTable: MessageHistoryTable) -> [IntermediateMessageHistoryEntry] {
        self.ensureInitialized(groupId)
        var entries: [IntermediateMessageHistoryEntry] = []
        self.valueBox.range(self.table, start: self.key(groupId: groupId, index: fromIndex), end: self.key(groupId: groupId, index: toIndex), values: { key, value in
            switch readEntry(groupId: groupId, key: key, value: value) {
                case let .message(index):
                    if let message = messageHistoryTable.getMessage(index) {
                        entries.append(.Message(message))
                    } else {
                        assertionFailure()
                    }
                case let .hole(stableId, hole):
                    entries.append(IntermediateMessageHistoryEntry.Hole(MessageHistoryHole(stableId: stableId, maxIndex: hole.upperIndex, min: hole.upperIndex.id.id, tags: 0), lowerIndex: hole.lowerIndex))
            }
            return true
        }, limit: count)
        return entries
    }
    
    func incomingStatsInRange(messageHistoryTable: MessageHistoryTable, groupId: PeerGroupId, lowerBound: MessageIndex, upperBound: MessageIndex) -> (count: Int32, holes: Bool, messagesByBeers: [PeerId: MessageIndex]) {
        var count: Int32 = 0
        var holes: Bool = false
        var messagesByBeers: [PeerId: MessageIndex] = [:]
        self.valueBox.range(self.table, start: self.key(groupId: groupId, index: lowerBound), end: self.key(groupId: groupId, index: upperBound), values: { key, value in
            let entry = readEntry(groupId: groupId, key: key, value: value)
            switch entry {
                case let .message(index):
                    if let message = messageHistoryTable.getMessage(index) {
                        if message.flags.contains(.Incoming) {
                            count += 1
                            messagesByBeers[index.id.peerId] = index
                        }
                    } else {
                        assertionFailure()
                        holes = true
                    }
                case .hole:
                    holes = true
            }
            return true
        }, limit: 0)
        
        self.valueBox.range(self.table, start: self.key(groupId: groupId, index: lowerBound.predecessor()), end: self.upperBound(groupId: groupId), values: { key, value in
            let entry = readEntry(groupId: groupId, key: key, value: value)
            switch entry {
                case .message:
                    break
                case let .hole(_, hole):
                    if upperBound >= hole.lowerIndex && upperBound <= hole.upperIndex {
                        holes = true
                    }
            }
            return false
        }, limit: 1)
        return (count, holes, messagesByBeers)
    }
    
    func topMessageIndex(groupId: PeerGroupId) -> MessageIndex? {
        var result: MessageIndex?
        self.valueBox.range(self.table, start: self.upperBound(groupId: groupId), end: self.lowerBound(groupId: groupId), values: { key, value in
            let entry = readEntry(groupId: groupId, key: key, value: value)
            switch entry {
                case let .message(index):
                    result = index
                case .hole:
                    break
            }
            return false
        }, limit: 1)
        return result
    }
    
    private func debugPrintEntries(groupId: PeerGroupId) {
        print("-----------------------------")
        self.valueBox.range(self.table, start: self.lowerBound(groupId: groupId), end: self.upperBound(groupId: groupId), values: { key, value in
            let entry = readEntry(groupId: groupId, key: key, value: value)
            switch entry {
                case let .message(index):
                    print("message timestamp: \(index.timestamp), peerId: \(index.id.peerId.id), id: \(index.id.id)")
                case let .hole(_, hole):
                    print("hole upper timestamp: \(hole.upperIndex.timestamp), \(hole.upperIndex.id.peerId.id), \(hole.upperIndex.id.id), lower \(hole.lowerIndex.timestamp), \(hole.lowerIndex.id.peerId.id), \(hole.lowerIndex.id.id)")
            }
            return true
        }, limit: 0)
        print("-----------------------------")
    }
}
