import Foundation

private func extractKey(_ key: ValueBoxKey) -> MessageIndex {
    return MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4), id: key.getInt32(8 + 4 + 4 + 4)), timestamp: key.getInt32(8 + 4 + 4))
}

class MessageHistoryTagsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 8 + 4 + 4 + 4 + 4)
    
    private let summaryTable: MessageHistoryTagsSummaryTable
    private let summaryTags: MessageTags
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, seedConfiguration: SeedConfiguration, summaryTable: MessageHistoryTagsSummaryTable) {
        self.summaryTable = summaryTable
        self.summaryTags = seedConfiguration.messageTagsWithSummary
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(tag: MessageTags, index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 8 + 4 + 4 + 4 + 4)) -> ValueBoxKey {
        key.setInt64(0, value: index.id.peerId.toInt64())
        key.setUInt32(8, value: tag.rawValue)
        key.setInt32(8 + 4, value: index.id.namespace)
        key.setInt32(8 + 4 + 4, value: index.timestamp)
        key.setInt32(8 + 4 + 4 + 4, value: index.id.id)
        return key
    }
    
    private func lowerBound(tag: MessageTags, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setUInt32(8, value: tag.rawValue)
        key.setInt32(8 + 4, value: namespace)
        return key
    }
    
    private func upperBound(tag: MessageTags, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        return self.lowerBound(tag: tag, peerId: peerId, namespace: namespace).successor
    }
    
    func add(tags: MessageTags, index: MessageIndex, isNewlyAdded: Bool, updatedSummaries: inout[MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        for tag in tags {
            self.valueBox.set(self.table, key: self.key(tag: tag, index: index, key: self.sharedKey), value: MemoryBuffer())
            if self.summaryTags.contains(tag) {
                self.summaryTable.addMessage(key: MessageHistoryTagsSummaryKey(tag: tag, peerId: index.id.peerId, threadId: nil, namespace: index.id.namespace, customTag: nil), id: index.id.id, isNewlyAdded: isNewlyAdded, updatedSummaries: &updatedSummaries, invalidateSummaries: &invalidateSummaries)
            }
        }
    }
    
    func remove(tags: MessageTags, index: MessageIndex, updatedSummaries: inout[MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        for tag in tags {
            self.valueBox.remove(self.table, key: self.key(tag: tag, index: index, key: self.sharedKey), secure: false)
            
            if self.summaryTags.contains(tag) {
                self.summaryTable.removeMessage(key: MessageHistoryTagsSummaryKey(tag: tag, peerId: index.id.peerId, threadId: nil, namespace: index.id.namespace, customTag: nil), id: index.id.id, updatedSummaries: &updatedSummaries, invalidateSummaries: &invalidateSummaries)
            }
        }
    }
    
    func entryExists(tag: MessageTags, index: MessageIndex) -> Bool {
        return self.valueBox.exists(self.table, key: self.key(tag: tag, index: index, key: self.sharedKey))
    }
    
    func entryLocation(at index: MessageIndex, tag: MessageTags) -> MessageHistoryEntryLocation? {
        if let _ = self.valueBox.get(self.table, key: self.key(tag: tag, index: index)) {
            var greaterCount = 0
            self.valueBox.range(self.table, start: self.key(tag: tag, index: index), end: self.upperBound(tag: tag, peerId: index.id.peerId, namespace: index.id.namespace), keys: { _ in
                greaterCount += 1
                return true
            }, limit: 0)
            
            var lowerCount = 0
            self.valueBox.range(self.table, start: self.key(tag: tag, index: index), end: self.lowerBound(tag: tag, peerId: index.id.peerId, namespace: index.id.namespace), keys: { _ in
                lowerCount += 1
                return true
            }, limit: 0)
            
            return MessageHistoryEntryLocation(index: lowerCount, count: greaterCount + lowerCount + 1)
        }
        return nil
    }
    
    func earlierIndices(tag: MessageTags, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, minIndex: MessageIndex? = nil, count: Int) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(tag: tag, index: index).successor
            } else {
                key = self.key(tag: tag, index: index)
            }
        } else {
            key = self.upperBound(tag: tag, peerId: peerId, namespace: namespace)
        }
        let endKey: ValueBoxKey
        if let minIndex = minIndex {
            endKey = self.key(tag: tag, index: minIndex)
        } else {
            endKey = self.lowerBound(tag: tag, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: endKey, keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func laterIndices(tag: MessageTags, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, count: Int) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(tag: tag, index: index).predecessor
            } else {
                key = self.key(tag: tag, index: index)
            }
        } else {
            key = self.lowerBound(tag: tag, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: self.upperBound(tag: tag, peerId: peerId, namespace: namespace), keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    /// The indices carrying `tag` whose id lies in `idRange`, read from the part of the tag's index strictly
    /// between `lower` and `upper` (nil: that end of the chat's index), in index order: nearest `upper` first
    /// with `fromUpper`, else nearest `lower`. At most `limit` of them (`limit <= 0`: all). The index orders by
    /// (date, id), so a message of `idRange` dated before `lower` or after `upper` is outside that part and is
    /// not returned, whichever of them was imported. Only when `lower` does not sort below `upper` (crossed:
    /// `lower` dated after `upper`) is the chat's whole index for the tag read instead.
    func indices(tag: MessageTags, peerId: PeerId, namespace: MessageId.Namespace, idRange: ClosedRange<MessageId.Id>, after lower: MessageIndex?, before upper: MessageIndex?, fromUpper: Bool, limit: Int) -> [MessageIndex] {
        var lowerKey = lower.map { self.key(tag: tag, index: $0) } ?? self.lowerBound(tag: tag, peerId: peerId, namespace: namespace)
        var upperKey = upper.map { self.key(tag: tag, index: $0) } ?? self.upperBound(tag: tag, peerId: peerId, namespace: namespace)
        // Cost: this whole-index read, and a window an old-dated (imported) neighbour widens, are a keys-only
        // scan of the tag's index on the Postbox queue until `limit` matches are found. Only chats with
        // imported history out of order with its ids pay it, on each candidate search of a tag fill there.
        if !(lowerKey < upperKey) {
            lowerKey = self.lowerBound(tag: tag, peerId: peerId, namespace: namespace)
            upperKey = self.upperBound(tag: tag, peerId: peerId, namespace: namespace)
        }
        var indices: [MessageIndex] = []
        // The range bounds of `ValueBox.range` are exclusive. The limit counts matching ids only, so the
        // statement itself runs without one.
        self.valueBox.range(self.table, start: fromUpper ? upperKey : lowerKey, end: fromUpper ? lowerKey : upperKey, keys: { key in
            let index = extractKey(key)
            if idRange.contains(index.id.id) {
                indices.append(index)
                if limit > 0 && indices.count >= limit {
                    return false
                }
            }
            return true
        }, limit: 0)
        return indices
    }

    func getMessageCountInRange(tag: MessageTags, peerId: PeerId, namespace: MessageId.Namespace, lowerBound: MessageIndex, upperBound: MessageIndex) -> Int {
        precondition(lowerBound.id.namespace == namespace)
        precondition(upperBound.id.namespace == namespace)
        var lowerBoundKey = self.key(tag: tag, index: lowerBound)
        if lowerBound.timestamp > 1 {
            lowerBoundKey = lowerBoundKey.predecessor
        }
        var upperBoundKey = self.key(tag: tag, index: upperBound)
        if upperBound.timestamp < Int32.max - 1 {
            upperBoundKey = upperBoundKey.successor
        }
        return Int(self.valueBox.count(self.table, start: lowerBoundKey, end: upperBoundKey))
    }
    
    func latestIndex(tag: MessageTags, peerId: PeerId, namespace: MessageId.Namespace) -> MessageIndex? {
        var result: MessageIndex?
        self.valueBox.range(self.table, start: self.lowerBound(tag: tag, peerId: peerId, namespace: namespace), end: self.upperBound(tag: tag, peerId: peerId, namespace: namespace), keys: { key in
            result = extractKey(key)
            return true
        }, limit: 1)
        return result
    }
    
    func findRandomIndex(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags, ignoreIds: ([MessageId], Set<MessageId>), isMessage: (MessageIndex) -> Bool) -> MessageIndex? {
        var indices: [MessageIndex] = []
        self.valueBox.range(self.table, start: self.lowerBound(tag: tag, peerId: peerId, namespace: namespace), end: self.upperBound(tag: tag, peerId: peerId, namespace: namespace), keys: { key in
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
