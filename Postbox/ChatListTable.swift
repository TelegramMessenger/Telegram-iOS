import Foundation

enum ChatListOperation {
    case InsertMessage(IntermediateMessage, CombinedPeerReadState?)
    case InsertHole(ChatListHole)
    case InsertNothing(MessageIndex)
    case RemoveMessage([MessageIndex])
    case RemoveHoles([MessageIndex])
}

enum ChatListIntermediateEntry {
    case Message(IntermediateMessage)
    case Hole(ChatListHole)
    case Nothing(MessageIndex)
    
    var index: MessageIndex {
        switch self {
            case let .Message(message):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .Hole(hole):
                return hole.index
            case let .Nothing(index):
                return index
        }
    }
}

private enum ChatListEntryType: Int8 {
    case Message = 1
    case Hole = 2
}

final class ChatListTable: Table {
    let indexTable: ChatListIndexTable
    let emptyMemoryBuffer = MemoryBuffer()
    let metadataTable: MessageHistoryMetadataTable
    let seedConfiguration: SeedConfiguration
    
    init(valueBox: ValueBox, tableId: Int32, indexTable: ChatListIndexTable, metadataTable: MessageHistoryMetadataTable, seedConfiguration: SeedConfiguration) {
        self.indexTable = indexTable
        self.metadataTable = metadataTable
        self.seedConfiguration = seedConfiguration
        
        super.init(valueBox: valueBox, tableId: tableId)
    }
    
    private func key(_ index: MessageIndex, type: ChatListEntryType) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 4 + 4 + 8 + 1)
        key.setInt32(0, value: index.timestamp)
        key.setInt32(4, value: index.id.namespace)
        key.setInt32(4 + 4, value: index.id.id)
        key.setInt64(4 + 4 + 4, value: index.id.peerId.toInt64())
        key.setInt8(4 + 4 + 4 + 8, value: type.rawValue)
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
    
    private func ensureInitialized() {
        if !self.metadataTable.isInitializedChatList() {
            for hole in self.seedConfiguration.initializeChatListWithHoles {
                self.justInsertHole(hole)
            }
            self.metadataTable.setInitializedChatList()
        }
    }
    
    func replay(_ historyOperationsByPeerId: [PeerId : [MessageHistoryOperation]], messageHistoryTable: MessageHistoryTable, operations: inout [ChatListOperation]) {
        self.ensureInitialized()
        
        for (peerId, _) in historyOperationsByPeerId {
            let currentIndex: MessageIndex? = self.indexTable.get(peerId)
            if let topMessage = messageHistoryTable.topMessage(peerId) {
                let index = MessageIndex(id: topMessage.id, timestamp: topMessage.timestamp)
                
                if let currentIndex = currentIndex , currentIndex != index {
                    self.justRemoveMessage(currentIndex)
                }
                if let currentIndex = currentIndex {
                    operations.append(.RemoveMessage([currentIndex]))
                }
                self.indexTable.set(index)
                self.justInsertMessage(index)
                operations.append(.InsertMessage(topMessage, messageHistoryTable.readStateTable.getCombinedState(peerId)))
            } else {
                if let currentIndex = currentIndex {
                    operations.append(.RemoveMessage([currentIndex]))
                    operations.append(.InsertNothing(currentIndex))
                }
            }
        }
    }
    
    func addHole(_ hole: ChatListHole, operations: inout [ChatListOperation]) {
        self.ensureInitialized()
        
        if self.valueBox.get(self.tableId, key: self.key(hole.index, type: .Hole)) == nil {
            self.justInsertHole(hole)
            operations.append(.InsertHole(hole))
        }
    }
    
    func replaceHole(_ index: MessageIndex, hole: ChatListHole?, operations: inout [ChatListOperation]) {
        self.ensureInitialized()
        
        if self.valueBox.get(self.tableId, key: self.key(index, type: .Hole)) != nil {
            if let hole = hole {
                if hole.index != index {
                    self.justRemoveHole(index)
                    self.justInsertHole(hole)
                    operations.append(.RemoveHoles([index]))
                    operations.append(.InsertHole(hole))
                }
            } else{
                self.justRemoveHole(index)
                operations.append(.RemoveHoles([index]))
            }
        }
    }
    
    private func justInsertMessage(_ index: MessageIndex) {
        self.valueBox.set(self.tableId, key: self.key(index, type: .Message), value: self.emptyMemoryBuffer)
    }
    
    private func justRemoveMessage(_ index: MessageIndex) {
        self.valueBox.remove(self.tableId, key: self.key(index, type: .Message))
    }
    
    private func justInsertHole(_ hole: ChatListHole) {
        self.valueBox.set(self.tableId, key: self.key(hole.index, type: .Hole), value: self.emptyMemoryBuffer)
    }
    
    private func justRemoveHole(_ index: MessageIndex) {
        self.valueBox.remove(self.tableId, key: self.key(index, type: .Hole))
    }
    
    func entriesAround(_ index: MessageIndex, messageHistoryTable: MessageHistoryTable, count: Int) -> (entries: [ChatListIntermediateEntry], lower: ChatListIntermediateEntry?, upper: ChatListIntermediateEntry?) {
        self.ensureInitialized()
        
        var lowerEntries: [ChatListIntermediateEntry] = []
        var upperEntries: [ChatListIntermediateEntry] = []
        var lower: ChatListIntermediateEntry?
        var upper: ChatListIntermediateEntry?
        
        self.valueBox.range(self.tableId, start: self.key(index, type: .Message), end: self.lowerBound(), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0))
            let type: Int8 = key.getInt8(4 + 4 + 4 + 8)
            if type == ChatListEntryType.Message.rawValue {
                if let message = messageHistoryTable.getMessage(index) {
                    lowerEntries.append(.Message(message))
                } else {
                    lowerEntries.append(.Nothing(index))
                }
            } else {
                lowerEntries.append(.Hole(ChatListHole(index: index)))
            }
            return true
        }, limit: count / 2 + 1)
        if lowerEntries.count >= count / 2 + 1 {
            lower = lowerEntries.last
            lowerEntries.removeLast()
        }
        
        self.valueBox.range(self.tableId, start: self.key(index, type: .Message).predecessor, end: self.upperBound(), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0))
            let type: Int8 = key.getInt8(4 + 4 + 4 + 8)
            if type == ChatListEntryType.Message.rawValue {
                if let message = messageHistoryTable.getMessage(index) {
                    upperEntries.append(.Message(message))
                } else {
                    upperEntries.append(.Nothing(index))
                }
            } else {
                upperEntries.append(.Hole(ChatListHole(index: index)))
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
                case .Message, .Nothing:
                    startEntryType = .Message
                case .Hole:
                    startEntryType = .Hole
            }
            self.valueBox.range(self.tableId, start: self.key(lowerEntries.last!.index, type: startEntryType), end: self.lowerBound(), keys: { key in
                let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0))
                let type: Int8 = key.getInt8(4 + 4 + 4 + 8)
                if type == ChatListEntryType.Message.rawValue {
                    if let message = messageHistoryTable.getMessage(index) {
                        additionalLowerEntries.append(.Message(message))
                    } else {
                        additionalLowerEntries.append(.Nothing(index))
                    }
                } else {
                    additionalLowerEntries.append(.Hole(ChatListHole(index: index)))
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
    
    func earlierEntries(_ index: MessageIndex?, messageHistoryTable: MessageHistoryTable, count: Int) -> [ChatListIntermediateEntry] {
        self.ensureInitialized()
        
        var entries: [ChatListIntermediateEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(index, type: .Message)
        } else {
            key = self.upperBound()
        }
        
        self.valueBox.range(self.tableId, start: key, end: self.lowerBound(), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0))
            let type: Int8 = key.getInt8(4 + 4 + 4 + 8)
            if type == ChatListEntryType.Message.rawValue {
                if let message = messageHistoryTable.getMessage(index) {
                    entries.append(.Message(message))
                } else {
                    entries.append(.Nothing(index))
                }
            } else {
                entries.append(.Hole(ChatListHole(index: index)))
            }
            return true
        }, limit: count)
        return entries
    }
    
    func laterEntries(_ index: MessageIndex?, messageHistoryTable: MessageHistoryTable, count: Int) -> [ChatListIntermediateEntry] {
        self.ensureInitialized()
        
        var entries: [ChatListIntermediateEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(index, type: .Message)
        } else {
            key = self.lowerBound()
        }
        
        self.valueBox.range(self.tableId, start: key, end: self.upperBound(), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0))
            let type: Int8 = key.getInt8(4 + 4 + 4 + 8)
            if type == ChatListEntryType.Message.rawValue {
                if let message = messageHistoryTable.getMessage(index) {
                    entries.append(.Message(message))
                } else {
                    entries.append(.Nothing(index))
                }
            } else {
                entries.append(.Hole(ChatListHole(index: index)))
            }
            return true
        }, limit: count)
        return entries
    }
    
    func debugList(_ messageHistoryTable: MessageHistoryTable) -> [ChatListIntermediateEntry] {
        return self.laterEntries(MessageIndex.absoluteLowerBound(), messageHistoryTable: messageHistoryTable, count: 1000)
    }
}
