import Foundation

class MessageHistoryThreadsTable: Table {
    struct ItemId: Hashable {
        var peerId: PeerId
        var threadId: Int64
    }
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4)
    
    private(set) var updatedIds = Set<ItemId>()
    
    override init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool) {
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(threadId: Int64, index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4)) -> ValueBoxKey {
        key.setInt64(0, value: index.id.peerId.toInt64())
        key.setInt64(8, value: threadId)
        key.setInt32(8 + 8, value: index.id.namespace)
        key.setInt32(8 + 8 + 4, value: index.timestamp)
        key.setInt32(8 + 8 + 4 + 4, value: index.id.id)
        return key
    }
    
    private func extractKey(_ key: ValueBoxKey) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 8), id: key.getInt32(8 + 8 + 4 + 4)), timestamp: key.getInt32(8 + 8 + 4))
    }
    
    private func lowerBound(threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt64(8, value: threadId)
        key.setInt32(8 + 8, value: namespace)
        return key
    }
    
    private func upperBound(threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        return self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace).successor
    }
    
    func add(threadId: Int64, index: MessageIndex) {
        self.valueBox.set(self.table, key: self.key(threadId: threadId, index: index, key: self.sharedKey), value: MemoryBuffer())
        self.updatedIds.insert(ItemId(peerId: index.id.peerId, threadId: threadId))
    }
    
    func remove(threadId: Int64, index: MessageIndex) {
        self.valueBox.remove(self.table, key: self.key(threadId: threadId, index: index, key: self.sharedKey), secure: false)
        self.updatedIds.insert(ItemId(peerId: index.id.peerId, threadId: threadId))
    }
    
    func earlierIndices(threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, count: Int) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(threadId: threadId, index: index).successor
            } else {
                key = self.key(threadId: threadId, index: index)
            }
        } else {
            key = self.upperBound(threadId: threadId, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace), keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func laterIndices(threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, count: Int) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(threadId: threadId, index: index).predecessor
            } else {
                key = self.key(threadId: threadId, index: index)
            }
        } else {
            key = self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: self.upperBound(threadId: threadId, peerId: peerId, namespace: namespace), keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func getTop(peerId: PeerId, threadId: Int64, namespaces: Set<MessageId.Namespace>) -> MessageIndex? {
        var maxIndex: MessageIndex?
        for namespace in namespaces {
            var namespaceIndex: MessageIndex?
            self.valueBox.range(self.table, start: self.upperBound(threadId: threadId, peerId: peerId, namespace: namespace), end: self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace), keys: { key in
                namespaceIndex = extractKey(key)
                return false
            }, limit: 1)
            if let namespaceIndex = namespaceIndex {
                if let maxIndexValue = maxIndex {
                    if namespaceIndex > maxIndexValue {
                        maxIndex = namespaceIndex
                    }
                } else {
                    maxIndex = namespaceIndex
                }
            }
        }
        return maxIndex
    }
    
    func holeLowerBoundForTopValidRange(peerId: PeerId, threadId: Int64, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, holeIndexTable: MessageHistoryThreadHoleIndexTable) -> MessageId.Id {
        let topHole = holeIndexTable.latest(peerId: peerId, threadId: threadId, namespace: namespace, space: space)
        if let topHole = topHole {
            let maxInHole = topHole.upperBound
            var messageNotInHole: MessageId?
            self.valueBox.range(self.table, start: self.upperBound(threadId: threadId, peerId: peerId, namespace: namespace), end: self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace), keys: { key in
                let index = extractKey(key)
                if index.id.id > maxInHole {
                    messageNotInHole = index.id
                    return false
                }
                return true
            }, limit: 32000)
            if let messageNotInHole = messageNotInHole {
                return messageNotInHole.id + 1
            } else {
                return topHole.lowerBound
            }
        } else {
            var messageNotInHole: MessageId?
            self.valueBox.range(self.table, start: self.upperBound(threadId: threadId, peerId: peerId, namespace: namespace), end: self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace), keys: { key in
                let index = extractKey(key)
            
                messageNotInHole = index.id
                return false
            }, limit: 1)
            if let messageNotInHole = messageNotInHole {
                return messageNotInHole.id + 1
            } else {
                return 1
            }
        }
    }
    
    func getMessageCountInRange(threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace, lowerBound: MessageIndex?, upperBound: MessageIndex?) -> Int {
        if let lowerBound = lowerBound {
            precondition(lowerBound.id.namespace == namespace)
        }
        if let upperBound = upperBound {
            precondition(upperBound.id.namespace == namespace)
        }
        var lowerBoundKey: ValueBoxKey
        if let lowerBound = lowerBound {
            lowerBoundKey = self.key(threadId: threadId, index: lowerBound)
            if lowerBound.timestamp > 1 {
                lowerBoundKey = lowerBoundKey.predecessor
            }
        } else {
            lowerBoundKey = self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace)
        }
        var upperBoundKey: ValueBoxKey
        if let upperBound = upperBound {
            upperBoundKey = self.key(threadId: threadId, index: upperBound)
            if upperBound.timestamp < Int32.max - 1 {
                upperBoundKey = upperBoundKey.successor
            }
        } else {
            upperBoundKey = self.upperBound(threadId: threadId, peerId: peerId, namespace: namespace)
        }
        return Int(self.valueBox.count(self.table, start: lowerBoundKey, end: upperBoundKey))
    }
    
    override func beforeCommit() {
        super.beforeCommit()
        
        self.updatedIds.removeAll()
    }
}

class MessageHistoryThreadTagsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let summaryTable: MessageHistoryTagsSummaryTable
    private let summaryTags: MessageTags
    
    private let sharedKey = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4 + 4)
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, seedConfiguration: SeedConfiguration, summaryTable: MessageHistoryTagsSummaryTable) {
        self.summaryTable = summaryTable
        self.summaryTags = seedConfiguration.messageTagsWithSummary
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(tag: MessageTags, threadId: Int64, index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4 + 4)) -> ValueBoxKey {
        key.setInt64(0, value: index.id.peerId.toInt64())
        key.setInt64(8, value: threadId)
        key.setUInt32(8 + 8, value: tag.rawValue)
        key.setInt32(8 + 8 + 4, value: index.id.namespace)
        key.setInt32(8 + 8 + 4 + 4, value: index.timestamp)
        key.setInt32(8 + 8 + 4 + 4 + 4, value: index.id.id)
        return key
    }
    
    private func extractKey(_ key: ValueBoxKey) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 8 + 4), id: key.getInt32(8 + 8 + 4 + 4 + 4)), timestamp: key.getInt32(8 + 8 + 4 + 4))
    }
    
    private func lowerBound(tag: MessageTags, threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 8 + 4 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt64(8, value: threadId)
        key.setUInt32(8 + 8, value: tag.rawValue)
        key.setInt32(8 + 8 + 4, value: namespace)
        return key
    }
    
    private func upperBound(tag: MessageTags, threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        return self.lowerBound(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace).successor
    }
    
    func add(tags: MessageTags, threadId: Int64, index: MessageIndex, isNewlyAdded: Bool, updatedSummaries: inout[MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        for tag in tags {
            self.valueBox.set(self.table, key: self.key(tag: tag, threadId: threadId, index: index, key: self.sharedKey), value: MemoryBuffer())
            if self.summaryTags.contains(tag) {
                self.summaryTable.addMessage(key: MessageHistoryTagsSummaryKey(tag: tag, peerId: index.id.peerId, threadId: threadId, namespace: index.id.namespace), id: index.id.id, isNewlyAdded: isNewlyAdded, updatedSummaries: &updatedSummaries, invalidateSummaries: &invalidateSummaries)
            }
        }
    }
    
    func remove(tags: MessageTags, threadId: Int64, index: MessageIndex, updatedSummaries: inout[MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        for tag in tags {
            self.valueBox.remove(self.table, key: self.key(tag: tag, threadId: threadId, index: index, key: self.sharedKey), secure: false)
            if self.summaryTags.contains(tag) {
                self.summaryTable.removeMessage(key: MessageHistoryTagsSummaryKey(tag: tag, peerId: index.id.peerId, threadId: threadId, namespace: index.id.namespace), id: index.id.id, updatedSummaries: &updatedSummaries, invalidateSummaries: &invalidateSummaries)
            }
        }
    }
    
    func entryExists(tag: MessageTags, threadId: Int64, index: MessageIndex) -> Bool {
        return self.valueBox.exists(self.table, key: self.key(tag: tag, threadId: threadId, index: index, key: self.sharedKey))
    }
    
    func entryLocation(at index: MessageIndex, threadId: Int64, tag: MessageTags) -> MessageHistoryEntryLocation? {
        if let _ = self.valueBox.get(self.table, key: self.key(tag: tag, threadId: threadId, index: index)) {
            var greaterCount = 0
            self.valueBox.range(self.table, start: self.key(tag: tag, threadId: threadId, index: index), end: self.upperBound(tag: tag, threadId: threadId, peerId: index.id.peerId, namespace: index.id.namespace), keys: { _ in
                greaterCount += 1
                return true
            }, limit: 0)
            
            var lowerCount = 0
            self.valueBox.range(self.table, start: self.key(tag: tag, threadId: threadId, index: index), end: self.lowerBound(tag: tag, threadId: threadId, peerId: index.id.peerId, namespace: index.id.namespace), keys: { _ in
                lowerCount += 1
                return true
            }, limit: 0)
            
            return MessageHistoryEntryLocation(index: lowerCount, count: greaterCount + lowerCount + 1)
        }
        return nil
    }
    
    func earlierIndices(tag: MessageTags, threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, minIndex: MessageIndex? = nil, count: Int) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(tag: tag, threadId: threadId, index: index).successor
            } else {
                key = self.key(tag: tag, threadId: threadId, index: index)
            }
        } else {
            key = self.upperBound(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace)
        }
        let endKey: ValueBoxKey
        if let minIndex = minIndex {
            endKey = self.key(tag: tag, threadId: threadId, index: minIndex)
        } else {
            endKey = self.lowerBound(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: endKey, keys: { key in
            indices.append(self.extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func laterIndices(tag: MessageTags, threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, count: Int) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(tag: tag, threadId: threadId, index: index).predecessor
            } else {
                key = self.key(tag: tag, threadId: threadId, index: index)
            }
        } else {
            key = self.lowerBound(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: self.upperBound(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace), keys: { key in
            indices.append(self.extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func getMessageCountInRange(tag: MessageTags, threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace, lowerBound: MessageIndex, upperBound: MessageIndex) -> Int {
        precondition(lowerBound.id.namespace == namespace)
        precondition(upperBound.id.namespace == namespace)
        var lowerBoundKey = self.key(tag: tag, threadId: threadId, index: lowerBound)
        if lowerBound.timestamp > 1 {
            lowerBoundKey = lowerBoundKey.predecessor
        }
        var upperBoundKey = self.key(tag: tag, threadId: threadId, index: upperBound)
        if upperBound.timestamp < Int32.max - 1 {
            upperBoundKey = upperBoundKey.successor
        }
        return Int(self.valueBox.count(self.table, start: lowerBoundKey, end: upperBoundKey))
    }
    
    func latestIndex(tag: MessageTags, threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace) -> MessageIndex? {
        var result: MessageIndex?
        self.valueBox.range(self.table, start: self.lowerBound(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace), end: self.upperBound(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace), keys: { key in
            result = extractKey(key)
            return true
        }, limit: 1)
        return result
    }
    
    func findRandomIndex(peerId: PeerId, threadId: Int64, namespace: MessageId.Namespace, tag: MessageTags, ignoreIds: ([MessageId], Set<MessageId>), isMessage: (MessageIndex) -> Bool) -> MessageIndex? {
        var indices: [MessageIndex] = []
        self.valueBox.range(self.table, start: self.lowerBound(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace), end: self.upperBound(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace), keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: 0)
        var checkedIndices = Set<Int>()
        while checkedIndices.count < indices.count {
            let i = Int(arc4random_uniform(UInt32(indices.count)))
            if checkedIndices.contains(i) {
                continue
            }
            checkedIndices.insert(i)
            let index = indices[i]
            if isMessage(index) && !ignoreIds.1.contains(index.id) {
                return index
            }
        }
        checkedIndices.removeAll()
        let lastId = ignoreIds.0.last
        while checkedIndices.count < indices.count {
            let i = Int(arc4random_uniform(UInt32(indices.count)))
            if checkedIndices.contains(i) {
                continue
            }
            checkedIndices.insert(i)
            let index = indices[i]
            if isMessage(index) && lastId != index.id {
                return index
            }
        }
        return nil
    }
    
    func debugGetAllIndices() -> [MessageIndex] {
        var indices: [MessageIndex] = []
        self.valueBox.scan(self.table, values: { key, value in
            indices.append(extractKey(key))
            return true
        })
        return indices
    }
}
