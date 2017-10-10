import Foundation

enum ChatListOperation {
    case InsertEntry(ChatListIndex, IntermediateMessage?, CombinedPeerReadState?, PeerChatListEmbeddedInterfaceState?)
    case InsertHole(ChatListHole)
    case RemoveEntry([ChatListIndex])
    case RemoveHoles([ChatListIndex])
}

enum ChatListEntryInfo {
    case message(ChatListIndex, MessageIndex?)
    case hole(ChatListHole)
    
    var index: ChatListIndex {
        switch self {
            case let .message(index, _):
                return index
            case let .hole(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
        }
    }
}

enum ChatListIntermediateEntry {
    case Message(ChatListIndex, IntermediateMessage?, PeerChatListEmbeddedInterfaceState?)
    case Hole(ChatListHole)
    
    var index: ChatListIndex {
        switch self {
            case let .Message(index, _, _):
                return index
            case let .Hole(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
        }
    }
}

private enum ChatListEntryType: Int8 {
    case Message = 1
    case Hole = 2
}

func chatListPinningIndexFromKeyValue(_ value: UInt16) -> UInt16? {
    if value == 0 {
        return nil
    } else {
        return UInt16.max - 1 - value
    }
}

func keyValueForChatListPinningIndex(_ index: UInt16?) -> UInt16 {
    if let index = index {
        return UInt16.max - 1 - index
    } else {
        return 0
    }
}

final class ChatListTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    let indexTable: ChatListIndexTable
    let emptyMemoryBuffer = MemoryBuffer()
    let metadataTable: MessageHistoryMetadataTable
    let seedConfiguration: SeedConfiguration
    
    init(valueBox: ValueBox, table: ValueBoxTable, indexTable: ChatListIndexTable, metadataTable: MessageHistoryMetadataTable, seedConfiguration: SeedConfiguration) {
        self.indexTable = indexTable
        self.metadataTable = metadataTable
        self.seedConfiguration = seedConfiguration
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(_ index: ChatListIndex, type: ChatListEntryType) -> ValueBoxKey {
        let key = ValueBoxKey(length: 2 + 4 + 4 + 4 + 8 + 1)
        key.setUInt16(0, value: keyValueForChatListPinningIndex(index.pinningIndex))
        key.setInt32(2, value: index.messageIndex.timestamp)
        key.setInt32(2 + 4, value: index.messageIndex.id.namespace)
        key.setInt32(2 + 4 + 4, value: index.messageIndex.id.id)
        key.setInt64(2 + 4 + 4 + 4, value: index.messageIndex.id.peerId.toInt64())
        key.setInt8(2 + 4 + 4 + 4 + 8, value: type.rawValue)
        return key
    }
    
    private func lowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 2 + 4)
        key.setUInt16(0, value: 0)
        key.setInt32(2, value: 0)
        return key
    }
    
    private func upperBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 2 + 4)
        key.setUInt16(0, value: UInt16.max)
        key.setInt32(2, value: Int32.max)
        return key
    }
    
    private func ensureInitialized() {
        if !self.metadataTable.isInitializedChatList() {
            for hole in self.seedConfiguration.initializeChatListWithHoles {
                self.justInsertHole(hole)
            }
            self.metadataTable.setInitializedChatList()
        }
    }
    
    func updateInclusion(peerId: PeerId, updatedChatListInclusions: inout [PeerId: PeerChatListInclusion], _ f: (PeerChatListInclusion) -> PeerChatListInclusion) {
        let currentInclusion: PeerChatListInclusion
        if let updated = updatedChatListInclusions[peerId] {
            currentInclusion = updated
        } else {
            currentInclusion = self.indexTable.get(peerId).inclusion
        }
        let updatedInclusion = f(currentInclusion)
        if currentInclusion != updatedInclusion {
            updatedChatListInclusions[peerId] = updatedInclusion
        }
    }
    
    func getPinnedPeerIds() -> [PeerId] {
        var peerIds: [PeerId] = []
        self.valueBox.range(self.table, start: self.upperBound(), end: self.key(ChatListIndex(pinningIndex: UInt16.max - 1, messageIndex: MessageIndex.absoluteUpperBound()), type: ChatListEntryType.Message).successor, keys: { key in
            peerIds.append(PeerId(key.getInt64(2 + 4 + 4 + 4)))
            return true
        }, limit: 0)
        return peerIds
    }
    
    func setPinnedPeerIds(peerIds: [PeerId], updatedChatListInclusions: inout [PeerId: PeerChatListInclusion]) {
        let updatedIds = Set(peerIds)
        for peerId in self.getPinnedPeerIds() {
            if !updatedIds.contains(peerId) {
                self.updateInclusion(peerId: peerId, updatedChatListInclusions: &updatedChatListInclusions, { inclusion in
                    return inclusion.withoutPinningIndex()
                })
            }
        }
        for i in 0 ..< peerIds.count {
            self.updateInclusion(peerId: peerIds[i], updatedChatListInclusions: &updatedChatListInclusions, { inclusion in
                return inclusion.withPinningIndex(UInt16(i))
            })
        }
    }
    
    func replay(historyOperationsByPeerId: [PeerId : [MessageHistoryOperation]], updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?], updatedChatListInclusions: [PeerId: PeerChatListInclusion], messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable, operations: inout [ChatListOperation]) {
        self.ensureInitialized()
        var changedPeerIds = Set<PeerId>()
        for peerId in historyOperationsByPeerId.keys {
            changedPeerIds.insert(peerId)
        }
        for peerId in updatedPeerChatListEmbeddedStates.keys {
            changedPeerIds.insert(peerId)
        }
        for peerId in updatedChatListInclusions.keys {
            changedPeerIds.insert(peerId)
        }
        for peerId in changedPeerIds {
            let currentIndex: ChatListIndex? = self.indexTable.get(peerId).includedIndex(peerId: peerId)
            
            let topMessage = messageHistoryTable.topMessage(peerId)
            let embeddedChatState = peerChatInterfaceStateTable.get(peerId)?.chatListEmbeddedState
            
            let rawTopMessageIndex: MessageIndex?
            let topMessageIndex: MessageIndex?
            if let topMessage = topMessage {
                var updatedTimestamp = topMessage.timestamp
                rawTopMessageIndex = MessageIndex(id: topMessage.id, timestamp: topMessage.timestamp)
                if let embeddedChatState = embeddedChatState {
                    updatedTimestamp = max(updatedTimestamp, embeddedChatState.timestamp)
                }
                topMessageIndex = MessageIndex(id: topMessage.id, timestamp: updatedTimestamp)
            } else if let embeddedChatState = embeddedChatState, embeddedChatState.timestamp != 0 {
                topMessageIndex = MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 1), timestamp: embeddedChatState.timestamp)
                rawTopMessageIndex = nil
            } else {
                topMessageIndex = nil
                rawTopMessageIndex = nil
            }
            
            var updatedIndex = self.indexTable.setTopMessageIndex(peerId: peerId, index: topMessageIndex)
            if let updatedInclusion = updatedChatListInclusions[peerId] {
                updatedIndex = self.indexTable.setInclusion(peerId: peerId, inclusion: updatedInclusion)
            }
            
            if let updatedOrderingIndex = updatedIndex.includedIndex(peerId: peerId) {
                if let currentIndex = currentIndex, currentIndex != updatedOrderingIndex {
                    self.justRemoveIndex(currentIndex)
                }
                if let currentIndex = currentIndex {
                    operations.append(.RemoveEntry([currentIndex]))
                }
                self.justInsertIndex(updatedOrderingIndex, topMessageIndex: rawTopMessageIndex)
                operations.append(.InsertEntry(updatedOrderingIndex, topMessage, messageHistoryTable.readStateTable.getCombinedState(peerId), embeddedChatState))
            } else {
                if let currentIndex = currentIndex {
                    self.justRemoveIndex(currentIndex)
                    operations.append(.RemoveEntry([currentIndex]))
                }
            }
        }
    }
    
    func addHole(_ hole: ChatListHole, operations: inout [ChatListOperation]) {
        self.ensureInitialized()
        
        if self.valueBox.get(self.table, key: self.key(ChatListIndex(pinningIndex: nil, messageIndex: hole.index), type: .Hole)) == nil {
            self.justInsertHole(hole)
            operations.append(.InsertHole(hole))
        }
    }
    
    func replaceHole(_ index: MessageIndex, hole: ChatListHole?, operations: inout [ChatListOperation]) {
        self.ensureInitialized()
        
        if self.valueBox.get(self.table, key: self.key(ChatListIndex(pinningIndex: nil, messageIndex: index), type: .Hole)) != nil {
            if let hole = hole {
                if hole.index != index {
                    self.justRemoveHole(index)
                    self.justInsertHole(hole)
                    operations.append(.RemoveHoles([ChatListIndex(pinningIndex: nil, messageIndex: index)]))
                    operations.append(.InsertHole(hole))
                }
            } else{
                self.justRemoveHole(index)
                operations.append(.RemoveHoles([ChatListIndex(pinningIndex: nil, messageIndex: index)]))
            }
        }
    }
    
    func addHole(hole: ChatListHole, operations: inout [ChatListOperation]) {
        self.justInsertHole(hole)
        operations.append(.InsertHole(hole))
    }
    
    private func justInsertIndex(_ index: ChatListIndex, topMessageIndex: MessageIndex?) {
        let buffer = WriteBuffer()
        if let topMessageIndex = topMessageIndex {
            var idNamespace = topMessageIndex.id.namespace
            buffer.write(&idNamespace, offset: 0, length: 4)
            var idId = topMessageIndex.id.id
            buffer.write(&idId, offset: 0, length: 4)
            var indexTimestamp = topMessageIndex.timestamp
            buffer.write(&indexTimestamp, offset: 0, length: 4)
        }
        self.valueBox.set(self.table, key: self.key(index, type: .Message), value: buffer)
    }
    
    private func justRemoveIndex(_ index: ChatListIndex) {
        self.valueBox.remove(self.table, key: self.key(index, type: .Message))
    }
    
    private func justInsertHole(_ hole: ChatListHole) {
        self.valueBox.set(self.table, key: self.key(ChatListIndex(pinningIndex: nil, messageIndex: hole.index), type: .Hole), value: self.emptyMemoryBuffer)
    }
    
    private func justRemoveHole(_ index: MessageIndex) {
        self.valueBox.remove(self.table, key: self.key(ChatListIndex(pinningIndex: nil, messageIndex: index), type: .Hole))
    }
    
    func entriesAround(_ index: ChatListIndex, messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable, count: Int) -> (entries: [ChatListIntermediateEntry], lower: ChatListIntermediateEntry?, upper: ChatListIntermediateEntry?) {
        self.ensureInitialized()
        
        var lowerEntries: [ChatListIntermediateEntry] = []
        var upperEntries: [ChatListIntermediateEntry] = []
        var lower: ChatListIntermediateEntry?
        var upper: ChatListIntermediateEntry?
        
        self.valueBox.range(self.table, start: self.key(index, type: .Message), end: self.lowerBound(), values: { key, value in
            let pinningIndexValue: UInt16 = key.getUInt16(0)
            let index = ChatListIndex(pinningIndex: chatListPinningIndexFromKeyValue(pinningIndexValue), messageIndex: MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(2 + 4 + 4 + 4)), namespace: key.getInt32(2 + 4), id: key.getInt32(2 + 4 + 4)), timestamp: key.getInt32(2)))
            let type: Int8 = key.getInt8(2 + 4 + 4 + 4 + 8)
            if type == ChatListEntryType.Message.rawValue {
                var message: IntermediateMessage?
                if value.length != 0 {
                    var idNamespace: Int32 = 0
                    value.read(&idNamespace, offset: 0, length: 4)
                    var idId: Int32 = 0
                    value.read(&idId, offset: 0, length: 4)
                    var indexTimestamp: Int32 = 0
                    value.read(&indexTimestamp, offset: 0, length: 4)
                    
                    message = messageHistoryTable.getMessage(MessageIndex(id: MessageId(peerId: index.messageIndex.id.peerId, namespace: idNamespace, id: idId), timestamp: indexTimestamp))
                }
                lowerEntries.append(.Message(index, message, peerChatInterfaceStateTable.get(index.messageIndex.id.peerId)?.chatListEmbeddedState))
            } else {
                lowerEntries.append(.Hole(ChatListHole(index: index.messageIndex)))
            }
            return true
        }, limit: count / 2 + 1)
        if lowerEntries.count >= count / 2 + 1 {
            lower = lowerEntries.last
            lowerEntries.removeLast()
        }
        
        self.valueBox.range(self.table, start: self.key(index, type: .Message).predecessor, end: self.upperBound(), values: { key, value in
            let pinningIndexValue: UInt16 = key.getUInt16(0)
            let index = ChatListIndex(pinningIndex: chatListPinningIndexFromKeyValue(pinningIndexValue), messageIndex: MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(2 + 4 + 4 + 4)), namespace: key.getInt32(2 + 4), id: key.getInt32(2 + 4 + 4)), timestamp: key.getInt32(2)))
            let type: Int8 = key.getInt8(2 + 4 + 4 + 4 + 8)
            if type == ChatListEntryType.Message.rawValue {
                var message: IntermediateMessage?
                if value.length != 0 {
                    var idNamespace: Int32 = 0
                    value.read(&idNamespace, offset: 0, length: 4)
                    var idId: Int32 = 0
                    value.read(&idId, offset: 0, length: 4)
                    var indexTimestamp: Int32 = 0
                    value.read(&indexTimestamp, offset: 0, length: 4)
                    
                    message = messageHistoryTable.getMessage(MessageIndex(id: MessageId(peerId: index.messageIndex.id.peerId, namespace: idNamespace, id: idId), timestamp: indexTimestamp))
                }
                upperEntries.append(.Message(index, message, peerChatInterfaceStateTable.get(index.messageIndex.id.peerId)?.chatListEmbeddedState))
            } else {
                upperEntries.append(.Hole(ChatListHole(index: index.messageIndex)))
            }
            return true
        }, limit: count - lowerEntries.count + 1)
        if upperEntries.count >= count - lowerEntries.count + 1 {
            upper = upperEntries.last
            upperEntries.removeLast()
        }
        
        if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
            var additionalLowerEntries: [ChatListIntermediateEntry] = []
            let startEntryType: ChatListEntryType
            switch lowerEntries.last! {
                case .Message:
                    startEntryType = .Message
                case .Hole:
                    startEntryType = .Hole
            }
            self.valueBox.range(self.table, start: self.key(lowerEntries.last!.index, type: startEntryType), end: self.lowerBound(), values: { key, value in
                let pinningIndexValue: UInt16 = key.getUInt16(0)
                let index = ChatListIndex(pinningIndex: chatListPinningIndexFromKeyValue(pinningIndexValue), messageIndex: MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(2 + 4 + 4 + 4)), namespace: key.getInt32(2 + 4), id: key.getInt32(2 + 4 + 4)), timestamp: key.getInt32(2)))
                let type: Int8 = key.getInt8(2 + 4 + 4 + 4 + 8)
                if type == ChatListEntryType.Message.rawValue {
                    var message: IntermediateMessage?
                    if value.length != 0 {
                        var idNamespace: Int32 = 0
                        value.read(&idNamespace, offset: 0, length: 4)
                        var idId: Int32 = 0
                        value.read(&idId, offset: 0, length: 4)
                        var indexTimestamp: Int32 = 0
                        value.read(&indexTimestamp, offset: 0, length: 4)
                        
                        message = messageHistoryTable.getMessage(MessageIndex(id: MessageId(peerId: index.messageIndex.id.peerId, namespace: idNamespace, id: idId), timestamp: indexTimestamp))
                    }
                    additionalLowerEntries.append(.Message(index, message, peerChatInterfaceStateTable.get(index.messageIndex.id.peerId)?.chatListEmbeddedState))
                } else {
                    additionalLowerEntries.append(.Hole(ChatListHole(index: index.messageIndex)))
                }
                return true
            }, limit: count - lowerEntries.count - upperEntries.count + 1)
            if additionalLowerEntries.count >= count - lowerEntries.count + upperEntries.count + 1 {
                lower = additionalLowerEntries.last
                additionalLowerEntries.removeLast()
            }
            lowerEntries.append(contentsOf: additionalLowerEntries)
        }
        
        var entries: [ChatListIntermediateEntry] = []
        entries.append(contentsOf: lowerEntries.reversed())
        entries.append(contentsOf: upperEntries)
        return (entries: entries, lower: lower, upper: upper)
    }
    
    func topPeerIds(count: Int) -> [PeerId] {
        var peerIds: [PeerId] = []
        self.valueBox.range(self.table, start: self.upperBound(), end: self.lowerBound(), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0))
            let type: Int8 = key.getInt8(4 + 4 + 4 + 8)
            if type == ChatListEntryType.Message.rawValue {
                peerIds.append(index.id.peerId)
            }
            return true
        }, limit: count)
        return peerIds
    }
    
    func earlierEntries(_ index: ChatListIndex?, messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable, count: Int) -> [ChatListIntermediateEntry] {
        self.ensureInitialized()
        
        var entries: [ChatListIntermediateEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(index, type: .Message)
        } else {
            key = self.upperBound()
        }
        
        self.valueBox.range(self.table, start: key, end: self.lowerBound(), values: { key, value in
            let pinningIndexValue: UInt16 = key.getUInt16(0)
            let index = ChatListIndex(pinningIndex: chatListPinningIndexFromKeyValue(pinningIndexValue), messageIndex: MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(2 + 4 + 4 + 4)), namespace: key.getInt32(2 + 4), id: key.getInt32(2 + 4 + 4)), timestamp: key.getInt32(2)))
            let type: Int8 = key.getInt8(2 + 4 + 4 + 4 + 8)
            if type == ChatListEntryType.Message.rawValue {
                var message: IntermediateMessage?
                if value.length != 0 {
                    var idNamespace: Int32 = 0
                    value.read(&idNamespace, offset: 0, length: 4)
                    var idId: Int32 = 0
                    value.read(&idId, offset: 0, length: 4)
                    var indexTimestamp: Int32 = 0
                    value.read(&indexTimestamp, offset: 0, length: 4)
                    
                    message = messageHistoryTable.getMessage(MessageIndex(id: MessageId(peerId: index.messageIndex.id.peerId, namespace: idNamespace, id: idId), timestamp: indexTimestamp))
                }
                entries.append(.Message(index, message, peerChatInterfaceStateTable.get(index.messageIndex.id.peerId)?.chatListEmbeddedState))
            } else {
                entries.append(.Hole(ChatListHole(index: index.messageIndex)))
            }
            return true
        }, limit: count)
        return entries
    }
    
    func laterEntries(_ index: ChatListIndex?, messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable, count: Int) -> [ChatListIntermediateEntry] {
        self.ensureInitialized()
        
        var entries: [ChatListIntermediateEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(index, type: .Message)
        } else {
            key = self.lowerBound()
        }
        
        self.valueBox.range(self.table, start: key, end: self.upperBound(), values: { key, value in
            let pinningIndexValue: UInt16 = key.getUInt16(0)
            let index = ChatListIndex(pinningIndex: chatListPinningIndexFromKeyValue(pinningIndexValue), messageIndex: MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(2 + 4 + 4 + 4)), namespace: key.getInt32(2 + 4), id: key.getInt32(2 + 4 + 4)), timestamp: key.getInt32(2)))
            let type: Int8 = key.getInt8(2 + 4 + 4 + 4 + 8)
            if type == ChatListEntryType.Message.rawValue {
                var message: IntermediateMessage?
                if value.length != 0 {
                    var idNamespace: Int32 = 0
                    value.read(&idNamespace, offset: 0, length: 4)
                    var idId: Int32 = 0
                    value.read(&idId, offset: 0, length: 4)
                    var indexTimestamp: Int32 = 0
                    value.read(&indexTimestamp, offset: 0, length: 4)
                    
                    message = messageHistoryTable.getMessage(MessageIndex(id: MessageId(peerId: index.messageIndex.id.peerId, namespace: idNamespace, id: idId), timestamp: indexTimestamp))
                }
                entries.append(.Message(index, message, peerChatInterfaceStateTable.get(index.messageIndex.id.peerId)?.chatListEmbeddedState))
            } else {
                entries.append(.Hole(ChatListHole(index: index.messageIndex)))
            }
            return true
        }, limit: count)
        return entries
    }
    
    func allEntries() -> [ChatListEntryInfo] {
        var entries: [ChatListEntryInfo] = []
        self.valueBox.range(self.table, start: self.upperBound(), end: self.lowerBound(), values: { key, value in
            let pinningIndexValue: UInt16 = key.getUInt16(0)
            let index = ChatListIndex(pinningIndex: chatListPinningIndexFromKeyValue(pinningIndexValue), messageIndex: MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(2 + 4 + 4 + 4)), namespace: key.getInt32(2 + 4), id: key.getInt32(2 + 4 + 4)), timestamp: key.getInt32(2)))
            let type: Int8 = key.getInt8(2 + 4 + 4 + 4 + 8)
            if type == ChatListEntryType.Message.rawValue {
                var messageIndex: MessageIndex?
                if value.length != 0 {
                    var idNamespace: Int32 = 0
                    value.read(&idNamespace, offset: 0, length: 4)
                    var idId: Int32 = 0
                    value.read(&idId, offset: 0, length: 4)
                    var indexTimestamp: Int32 = 0
                    value.read(&indexTimestamp, offset: 0, length: 4)
                    messageIndex = MessageIndex(id: MessageId(peerId: index.messageIndex.id.peerId, namespace: idNamespace, id: idId), timestamp: indexTimestamp)
                }
                entries.append(.message(index, messageIndex))
            } else {
                entries.append(.hole(ChatListHole(index: index.messageIndex)))
            }
            return true
        }, limit: 0)
        return entries
    }
    
    func debugList(_ messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable) -> [ChatListIntermediateEntry] {
        return self.laterEntries(ChatListIndex.absoluteLowerBound, messageHistoryTable: messageHistoryTable, peerChatInterfaceStateTable: peerChatInterfaceStateTable, count: 1000)
    }
}
