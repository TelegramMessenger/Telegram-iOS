import Foundation

private func extractKey(_ key: ValueBoxKey) -> MessageIndex {
    return MessageIndex(
        id: MessageId(
            peerId: PeerId(key.getInt64(0)),
            namespace: key.getInt32(8 + 8 + 4 + 4),
            id: key.getInt32(8 + 8 + 4 + 4 + 4 + 4)
        ),
        timestamp: key.getInt32(8 + 8 + 4 + 4 + 4)
    )
}

class MessageCustomTagWithTagTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let messageCustomTagIdTable: MessageCustomTagIdTable
    private let summaryTable: MessageHistoryTagsSummaryTable
    private let summaryTags: MessageTags
    
    private let sharedKey = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4 + 4 + 4)
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, messageCustomTagIdTable: MessageCustomTagIdTable, seedConfiguration: SeedConfiguration, summaryTable: MessageHistoryTagsSummaryTable) {
        self.messageCustomTagIdTable = messageCustomTagIdTable
        self.summaryTable = summaryTable
        self.summaryTags = seedConfiguration.messageTagsWithSummary
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(threadId: Int64?, tag: Int32, regularTag: UInt32, index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4 + 4 + 4)) -> ValueBoxKey {
        key.setInt64(0, value: index.id.peerId.toInt64())
        key.setInt64(8, value: threadId ?? 0)
        key.setInt32(8 + 8, value: tag)
        key.setUInt32(8 + 8 + 4, value: regularTag)
        key.setInt32(8 + 8 + 4 + 4, value: index.id.namespace)
        key.setInt32(8 + 8 + 4 + 4 + 4, value: index.timestamp)
        key.setInt32(8 + 8 + 4 + 4 + 4 + 4, value: index.id.id)
        return key
    }
    
    private func lowerBound(threadId: Int64?, tag: Int32, regularTag: UInt32, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt64(8, value: threadId ?? 0)
        key.setInt32(8 + 8, value: tag)
        key.setUInt32(8 + 8 + 4, value: regularTag)
        key.setInt32(8 + 8 + 4 + 4, value: namespace)
        return key
    }
    
    private func upperBound(threadId: Int64?, tag: Int32, regularTag: UInt32, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        return self.lowerBound(threadId: threadId, tag: tag, regularTag: regularTag, peerId: peerId, namespace: namespace).successor
    }
    
    func add(threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32, index: MessageIndex, isNewlyAdded: Bool, updatedSummaries: inout[MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        self.valueBox.set(self.table, key: self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: index, key: self.sharedKey), value: MemoryBuffer())
        
        if self.summaryTags.contains(MessageTags(rawValue: regularTag)) {
            self.summaryTable.addMessage(key: MessageHistoryTagsSummaryKey(tag: MessageTags(rawValue: regularTag), peerId: index.id.peerId, threadId: threadId, namespace: index.id.namespace, customTag: tag), id: index.id.id, isNewlyAdded: isNewlyAdded, updatedSummaries: &updatedSummaries, invalidateSummaries: &invalidateSummaries)
        }
    }
    
    func remove(threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32, index: MessageIndex, updatedSummaries: inout[MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        self.valueBox.remove(self.table, key: self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: index, key: self.sharedKey), secure: false)
        
        if self.summaryTags.contains(MessageTags(rawValue: regularTag)) {
            self.summaryTable.removeMessage(key: MessageHistoryTagsSummaryKey(tag: MessageTags(rawValue: regularTag), peerId: index.id.peerId, threadId: threadId, namespace: index.id.namespace, customTag: tag), id: index.id.id, updatedSummaries: &updatedSummaries, invalidateSummaries: &invalidateSummaries)
        }
    }
    
    func entryExists(threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32, index: MessageIndex) -> Bool {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        return self.valueBox.exists(self.table, key: self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: index, key: self.sharedKey))
    }
    
    func entryLocation(threadId: Int64?, index: MessageIndex, tag: MemoryBuffer, regularTag: UInt32) -> MessageHistoryEntryLocation? {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        if let _ = self.valueBox.get(self.table, key: self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: index)) {
            var greaterCount = 0
            self.valueBox.range(self.table, start: self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: index), end: self.upperBound(threadId: threadId, tag: mappedTag, regularTag: regularTag, peerId: index.id.peerId, namespace: index.id.namespace), keys: { _ in
                greaterCount += 1
                return true
            }, limit: 0)
            
            var lowerCount = 0
            self.valueBox.range(self.table, start: self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: index), end: self.lowerBound(threadId: threadId, tag: mappedTag, regularTag: regularTag, peerId: index.id.peerId, namespace: index.id.namespace), keys: { _ in
                lowerCount += 1
                return true
            }, limit: 0)
            
            return MessageHistoryEntryLocation(index: lowerCount, count: greaterCount + lowerCount + 1)
        }
        return nil
    }
    
    func earlierIndices(threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, minIndex: MessageIndex? = nil, count: Int) -> [MessageIndex] {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: index).successor
            } else {
                key = self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: index)
            }
        } else {
            key = self.upperBound(threadId: threadId, tag: mappedTag, regularTag: regularTag, peerId: peerId, namespace: namespace)
        }
        let endKey: ValueBoxKey
        if let minIndex = minIndex {
            endKey = self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: minIndex)
        } else {
            endKey = self.lowerBound(threadId: threadId, tag: mappedTag, regularTag: regularTag, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: endKey, keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func laterIndices(threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, count: Int) -> [MessageIndex] {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: index).predecessor
            } else {
                key = self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: index)
            }
        } else {
            key = self.lowerBound(threadId: threadId, tag: mappedTag, regularTag: regularTag, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: self.upperBound(threadId: threadId, tag: mappedTag, regularTag: regularTag, peerId: peerId, namespace: namespace), keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func getMessageCountInRange(threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32, peerId: PeerId, namespace: MessageId.Namespace, lowerBound: MessageIndex, upperBound: MessageIndex) -> Int {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        precondition(lowerBound.id.namespace == namespace)
        precondition(upperBound.id.namespace == namespace)
        var lowerBoundKey = self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: lowerBound)
        if lowerBound.timestamp > 1 {
            lowerBoundKey = lowerBoundKey.predecessor
        }
        var upperBoundKey = self.key(threadId: threadId, tag: mappedTag, regularTag: regularTag, index: upperBound)
        if upperBound.timestamp < Int32.max - 1 {
            upperBoundKey = upperBoundKey.successor
        }
        return Int(self.valueBox.count(self.table, start: lowerBoundKey, end: upperBoundKey))
    }
    
    func latestIndex(threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32, peerId: PeerId, namespace: MessageId.Namespace) -> MessageIndex? {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        var result: MessageIndex?
        self.valueBox.range(self.table, start: self.lowerBound(threadId: threadId, tag: mappedTag, regularTag: regularTag, peerId: peerId, namespace: namespace), end: self.upperBound(threadId: threadId, tag: mappedTag, regularTag: regularTag, peerId: peerId, namespace: namespace), keys: { key in
            result = extractKey(key)
            return true
        }, limit: 1)
        return result
    }
}
