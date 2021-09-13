import Foundation

public enum AddMessagesLocation {
    case Random
    case UpperHistoryBlock
}

enum MessageHistoryIndexOperation {
    case InsertMessage(InternalStoreMessage)
    case InsertExistingMessage(InternalStoreMessage)
    case Remove(index: MessageIndex)
    case Update(MessageIndex, InternalStoreMessage)
    case UpdateTimestamp(MessageIndex, Int32)
}

private let HistoryEntryTypeMask: Int8 = 1
private let HistoryEntryTypeMessage: Int8 = 0
private let HistoryEntryMessageFlagIncoming: Int8 = 1 << 1

private func readHistoryIndexEntry(_ peerId: PeerId, namespace: MessageId.Namespace, key: ValueBoxKey, value: ReadBuffer) -> MessageIndex {
    var flags: Int8 = 0
    value.read(&flags, offset: 0, length: 1)
    var timestamp: Int32 = 0
    value.read(&timestamp, offset: 0, length: 4)
    let index = MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: key.getInt32(8 + 4)), timestamp: timestamp)
    return index
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
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let messageHistoryHoleIndexTable: MessageHistoryHoleIndexTable
    private let globalMessageIdsTable: GlobalMessageIdsTable
    private let metadataTable: MessageHistoryMetadataTable
    private let seedConfiguration: SeedConfiguration
    
    private var cachedExistingNamespaces: [PeerId: Set<MessageId.Namespace>] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, messageHistoryHoleIndexTable: MessageHistoryHoleIndexTable, globalMessageIdsTable: GlobalMessageIdsTable, metadataTable: MessageHistoryMetadataTable, seedConfiguration: SeedConfiguration) {
        self.messageHistoryHoleIndexTable = messageHistoryHoleIndexTable
        self.globalMessageIdsTable = globalMessageIdsTable
        self.seedConfiguration = seedConfiguration
        self.metadataTable = metadataTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(_ id: MessageId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4 + 4)
        key.setInt64(0, value: id.peerId.toInt64())
        key.setInt32(8, value: id.namespace)
        key.setInt32(8 + 4, value: id.id)
        return key
    }
    
    private func lowerBound(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
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
    
    private func upperBound(peerId: PeerId) -> ValueBoxKey {
        return self.lowerBound(peerId: peerId).successor
    }
    
    func addMessages(_ messages: [InternalStoreMessage], operations: inout [MessageHistoryIndexOperation]) {
        if messages.count == 0 {
            return
        }
        
        for message in messages {
            let index = MessageIndex(id: message.id, timestamp: message.timestamp)
            
            if let currentIndex = self.getIndex(index.id) {
                if currentIndex.timestamp == index.timestamp {
                    operations.append(.InsertExistingMessage(message))
                } else {
                    self.justRemove(currentIndex, operations: &operations)
                    self.justInsertMessage(message, operations: &operations)
                }
            } else {
                self.justInsertMessage(message, operations: &operations)
                
                self.cachedExistingNamespaces[message.id.peerId]?.insert(message.id.namespace)
            }
        }
    }
    
    func removeMessage(_ id: MessageId, operations: inout [MessageHistoryIndexOperation]) {
        if let index = self.getIndex(id) {
            self.justRemove(index, operations: &operations)
        }
    }
    
    func removeMessagesInRange(peerId: PeerId, namespace: MessageId.Namespace, minId: MessageId.Id, maxId: MessageId.Id, operations: inout [MessageHistoryIndexOperation]) {
        if minId > maxId {
            assertionFailure()
            return
        }
        var removeMessageIds: [MessageId] = []
        self.valueBox.range(self.table, start: self.key(MessageId(peerId: peerId, namespace: namespace, id: minId)).predecessor, end: self.key(MessageId(peerId: peerId, namespace: namespace, id: maxId)).successor, values: { key, value in
            let index = readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value)
            removeMessageIds.append(index.id)
            return true
        }, limit: 0)
        for id in removeMessageIds {
            self.removeMessage(id, operations: &operations)
        }
    }
    
    func updateMessage(_ id: MessageId, message: InternalStoreMessage, operations: inout [MessageHistoryIndexOperation]) {
        if let previousIndex = self.getIndex(id) {
            if previousIndex != message.index {
                var intermediateOperations: [MessageHistoryIndexOperation] = []
                self.removeMessage(id, operations: &intermediateOperations)
                self.addMessages([message], operations: &intermediateOperations)
                
                for operation in intermediateOperations {
                    switch operation {
                        case let .Remove(index) where index == previousIndex:
                            operations.append(.Update(previousIndex, message))
                        case let .InsertMessage(insertMessage) where insertMessage.index == message.index:
                            break
                        case let .InsertExistingMessage(insertMessage) where insertMessage.index == message.index:
                            operations.removeAll()
                            operations.append(.Remove(index: previousIndex))
                            operations.append(.Update(insertMessage.index, message))
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
        if let previousData = self.valueBox.get(self.table, key: self.key(id)), let previousIndex = self.getIndex(id), previousIndex.timestamp != timestamp {
            let updatedEntry = modifyHistoryIndexEntryTimestamp(value: previousData, timestamp: timestamp)
            self.valueBox.remove(self.table, key: self.key(id), secure: false)
            self.valueBox.set(self.table, key: self.key(id), value: updatedEntry)
            
            operations.append(.UpdateTimestamp(MessageIndex(id: id, timestamp: previousIndex.timestamp), timestamp))
        }
    }
    
    private func justInsertMessage(_ message: InternalStoreMessage, operations: inout [MessageHistoryIndexOperation]) {
        let index = MessageIndex(id: message.id, timestamp: message.timestamp)
        
        let value = WriteBuffer()
        var flags: Int8 = HistoryEntryTypeMessage
        if !message.flags.intersection(.IsIncomingMask).isEmpty {
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
    
    private func justRemove(_ index: MessageIndex, operations: inout [MessageHistoryIndexOperation]) {
        self.valueBox.remove(self.table, key: self.key(index.id), secure: false)
        
        operations.append(.Remove(index: index))
        if self.seedConfiguration.globalMessageIdsPeerIdNamespaces.contains(GlobalMessageIdsNamespace(peerIdNamespace: index.id.peerId.namespace, messageIdNamespace: index.id.namespace)) {
            self.globalMessageIdsTable.remove(index.id.id)
        }
    }
    
    func getIndex(_ id: MessageId) -> MessageIndex? {
        let key = self.key(id)
        if let value = self.valueBox.get(self.table, key: key) {
            return readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
        } else {
            return nil
        }
    }
    
    func top(_ peerId: PeerId, namespace: MessageId.Namespace) -> MessageIndex? {
        var index: MessageIndex?
        self.valueBox.range(self.table, start: self.upperBound(peerId, namespace: namespace), end: self.lowerBound(peerId, namespace: namespace), values: { key, value in
            index = readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value)
            return false
        }, limit: 1)
        return index
    }
    
    func exists(_ id: MessageId) -> Bool {
        return self.valueBox.exists(self.table, key: self.key(id))
    }
    
    func incomingMessageCountInRange(_ peerId: PeerId, namespace: MessageId.Namespace, minId: MessageId.Id, maxId: MessageId.Id) -> (Int, Bool) {
        var count = 0
        var holes = false
        if minId <= maxId {
            self.valueBox.range(self.table, start: self.key(MessageId(peerId: peerId, namespace: namespace, id: minId)).predecessor, end: self.key(MessageId(peerId: peerId, namespace: namespace, id: maxId)).successor, values: { _, value in
                var flags: Int8 = 0
                value.read(&flags, offset: 0, length: 1)
                if (flags & HistoryEntryMessageFlagIncoming) != 0 {
                    count += 1
                }
                return true
            }, limit: 0)
            
            holes = !self.messageHistoryHoleIndexTable.closest(peerId: peerId, namespace: namespace, space: .everywhere, range: minId ... maxId).isEmpty
        }
        
        return (count, holes)
    }
    
    func incomingMessageCountInIds(_ peerId: PeerId, namespace: MessageId.Namespace, ids: [MessageId.Id]) -> (Int, Bool) {
        var count = 0
        var holes = false
        
        for id in ids {
            if let value = self.valueBox.get(self.table, key: self.key(MessageId(peerId: peerId, namespace: namespace, id: id))) {
                var flags: Int8 = 0
                value.read(&flags, offset: 0, length: 1)
                if (flags & HistoryEntryMessageFlagIncoming) != 0 {
                    count += 1
                }
                if !self.messageHistoryHoleIndexTable.containing(id: MessageId(peerId: peerId, namespace: namespace, id: id)).isEmpty {
                    holes = true
                }
            }
        }
        
        return (count, holes)
    }
    
    func indexForId(higherThan id: MessageId) -> MessageIndex? {
        var result: MessageIndex?
        self.valueBox.range(self.table, start: self.key(id), end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
            result = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
            return false
        }, limit: 1)
        return result
    }
    
    func earlierEntries(id: MessageId, count: Int) -> [MessageIndex] {
        var entries: [MessageIndex] = []
        let key = self.key(id)
        self.valueBox.range(self.table, start: key, end: self.lowerBound(id.peerId, namespace: id.namespace), values: { key, value in
            entries.append(readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value))
            return true
        }, limit: count)
        return entries
    }
    
    func existingNamespaces(peerId: PeerId) -> Set<MessageId.Namespace> {
        if let cached = self.cachedExistingNamespaces[peerId] {
            return cached
        } else {
            let namespaces = Set(self.fetchExistingNamespaces(peerId: peerId))
            self.cachedExistingNamespaces[peerId] = namespaces
            return namespaces
        }
    }
    
    private func fetchExistingNamespaces(peerId: PeerId) -> [MessageId.Namespace] {
        var result: [MessageId.Namespace] = []
        var lowerBound = self.lowerBound(peerId: peerId)
        let upperBound = self.upperBound(peerId: peerId)
        while true {
            var namespace: MessageId.Namespace?
            self.valueBox.range(self.table, start: lowerBound, end: upperBound, keys: { key in
                assert(key.getInt64(0) == peerId.toInt64())
                namespace = key.getInt32(8)
                return false
            }, limit: 1)
            if let namespace = namespace {
                result.append(namespace)
                lowerBound = self.lowerBound(peerId, namespace: namespace + 1)
            } else {
                break
            }
        }
        return result
    }
    
    func debugList(_ peerId: PeerId, namespace: MessageId.Namespace) -> [MessageIndex] {
        var list: [MessageIndex] = []
        self.valueBox.range(self.table, start: self.lowerBound(peerId, namespace: namespace), end: self.upperBound(peerId, namespace: namespace), values: { key, value in
            list.append(readHistoryIndexEntry(peerId, namespace: namespace, key: key, value: value))
            
            return true
        }, limit: 0)
        return list
    }
    
    func closestIndex(id: MessageId) -> MessageIndex? {
        if let index = self.getIndex(id) {
            return index
        } else {
            var index: MessageIndex?
            self.valueBox.range(self.table, start: self.key(id).successor, end: self.lowerBound(id.peerId, namespace: id.namespace), values: { key, value in
                index = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
                return true
            }, limit: 1)
            
            if index == nil {
                self.valueBox.range(self.table, start: self.key(id).predecessor, end: self.upperBound(id.peerId, namespace: id.namespace), values: { key, value in
                    index = readHistoryIndexEntry(id.peerId, namespace: id.namespace, key: key, value: value)
                    return true
                }, limit: 1)
            }
            
            return index
        }
    }
    
    override func clearMemoryCache() {
        self.cachedExistingNamespaces.removeAll()
    }
}
