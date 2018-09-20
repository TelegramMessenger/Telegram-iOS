import Foundation

class MessageHistoryTagsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    private let sharedKey = ValueBoxKey(length: 8 + 4 + 4 + 4 + 4)
    
    private let summaryTable: MessageHistoryTagsSummaryTable
    private let summaryTags: MessageTags
    
    init(valueBox: ValueBox, table: ValueBoxTable, seedConfiguration: SeedConfiguration, summaryTable: MessageHistoryTagsSummaryTable) {
        self.summaryTable = summaryTable
        self.summaryTags = seedConfiguration.messageTagsWithSummary
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(_ tagMask: MessageTags, index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 8 + 4 + 4 + 4 + 4)) -> ValueBoxKey {
        key.setInt64(0, value: index.id.peerId.toInt64())
        key.setUInt32(8, value: tagMask.rawValue)
        key.setInt32(8 + 4, value: index.timestamp)
        key.setInt32(8 + 4 + 4, value: index.id.namespace)
        key.setInt32(8 + 4 + 4 + 4, value: index.id.id)
        return key
    }
    
    private func lowerBound(_ tagMask: MessageTags, peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setUInt32(8, value: tagMask.rawValue)
        return key
    }
    
    private func upperBound(_ tagMask: MessageTags, peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setUInt32(8, value: tagMask.rawValue)
        return key.successor
    }
    
    func add(_ tagMask: MessageTags, index: MessageIndex, isHole: Bool, updatedSummaries: inout[MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        if !isHole && tagMask.contains(MessageTags(rawValue: 8)) && index.id.namespace == 0 && index.id.peerId.id == 1097505041 {
            assert(true)
        }
        for tag in tagMask {
            self.valueBox.set(self.table, key: self.key(tag, index: index, key: self.sharedKey), value: MemoryBuffer())
            if !isHole && self.summaryTags.contains(tag) {
                self.summaryTable.addMessage(key: MessageHistoryTagsSummaryKey(tag: tag, peerId: index.id.peerId, namespace: index.id.namespace), id: index.id.id, updatedSummaries: &updatedSummaries, invalidateSummaries: &invalidateSummaries)
            }
        }
    }
    
    func remove(_ tagMask: MessageTags, index: MessageIndex, isHole: Bool, updatedSummaries: inout[MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        if !isHole && tagMask.contains(MessageTags(rawValue: 8)) && index.id.namespace == 0 && index.id.peerId.id == 1097505041 {
            assert(true)
        }
        for tag in tagMask {
            self.valueBox.remove(self.table, key: self.key(tag, index: index, key: self.sharedKey))
            
            if !isHole && self.summaryTags.contains(tag) {
                self.summaryTable.removeMessage(key: MessageHistoryTagsSummaryKey(tag: tag, peerId: index.id.peerId, namespace: index.id.namespace), id: index.id.id, updatedSummaries: &updatedSummaries, invalidateSummaries: &invalidateSummaries)
            }
        }
    }
    
    func entryLocation(at index: MessageIndex, tagMask: MessageTags) -> MessageHistoryEntryLocation? {
        if let _ = self.valueBox.get(self.table, key: self.key(tagMask, index: index)) {
            var greaterCount = 0
            self.valueBox.range(self.table, start: self.key(tagMask, index: index), end: self.upperBound(tagMask, peerId: index.id.peerId), keys: { _ in
                greaterCount += 1
                return true
            }, limit: 0)
            
            var lowerCount = 0
            self.valueBox.range(self.table, start: self.key(tagMask, index: index), end: self.lowerBound(tagMask, peerId: index.id.peerId), keys: { _ in
                lowerCount += 1
                return true
            }, limit: 0)
            
            return MessageHistoryEntryLocation(index: lowerCount, count: greaterCount + lowerCount + 1)
        }
        return nil
    }
    
    func indicesAround(_ tagMask: MessageTags, index: MessageIndex, count: Int) -> (indices: [MessageIndex], lower: MessageIndex?, upper: MessageIndex?) {
        var lowerEntries: [MessageIndex] = []
        var upperEntries: [MessageIndex] = []
        var lower: MessageIndex?
        var upper: MessageIndex?
        
        self.valueBox.range(self.table, start: self.key(tagMask, index: index), end: self.lowerBound(tagMask, peerId: index.id.peerId), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4 + 4), id: key.getInt32(8 + 4 + 4 + 4)), timestamp: key.getInt32(8 + 4))
            lowerEntries.append(index)
            return true
        }, limit: count / 2 + 1)
        
        if lowerEntries.count >= count / 2 + 1 {
            lower = lowerEntries.last
            lowerEntries.removeLast()
        }
        
        self.valueBox.range(self.table, start: self.key(tagMask, index: index).predecessor, end: self.upperBound(tagMask, peerId: index.id.peerId), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4 + 4), id: key.getInt32(8 + 4 + 4 + 4)), timestamp: key.getInt32(8 + 4))
            upperEntries.append(index)
            return true
        }, limit: count - lowerEntries.count + 1)
        if upperEntries.count >= count - lowerEntries.count + 1 {
            upper = upperEntries.last
            upperEntries.removeLast()
        }
        
        if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
            var additionalLowerEntries: [MessageIndex] = []
            self.valueBox.range(self.table, start: self.key(tagMask, index: lowerEntries.last!), end: self.lowerBound(tagMask, peerId: index.id.peerId), keys: { key in
                let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4 + 4), id: key.getInt32(8 + 4 + 4 + 4)), timestamp: key.getInt32(8 + 4))
                additionalLowerEntries.append(index)
                return true
            }, limit: count - lowerEntries.count - upperEntries.count + 1)
            if additionalLowerEntries.count >= count - lowerEntries.count + upperEntries.count + 1 {
                lower = additionalLowerEntries.last
                additionalLowerEntries.removeLast()
            }
            lowerEntries.append(contentsOf: additionalLowerEntries)
        }
        
        var entries: [MessageIndex] = []
        entries.append(contentsOf: lowerEntries.reversed())
        entries.append(contentsOf: upperEntries)
        return (indices: entries, lower: lower, upper: upper)
    }
    
    func earlierIndices(_ tagMask: MessageTags, peerId: PeerId, index: MessageIndex?, count: Int) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(tagMask, index: index)
        } else {
            key = self.upperBound(tagMask, peerId: peerId)
        }
        self.valueBox.range(self.table, start: key, end: self.lowerBound(tagMask, peerId: peerId), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4 + 4), id: key.getInt32(8 + 4 + 4 + 4)), timestamp: key.getInt32(8 + 4))
            indices.append(index)
            return true
        }, limit: count)
        return indices
    }
    
    func laterIndices(_ tagMask: MessageTags, peerId: PeerId, index: MessageIndex?, count: Int) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(tagMask, index: index)
        } else {
            key = self.lowerBound(tagMask, peerId: peerId)
        }
        self.valueBox.range(self.table, start: key, end: self.upperBound(tagMask, peerId: peerId), keys: { key in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4 + 4), id: key.getInt32(8 + 4 + 4 + 4)), timestamp: key.getInt32(8 + 4))
            indices.append(index)
            return true
        }, limit: count)
        return indices
    }
    
    func getMessageCountInRange(tagMask: MessageTags, peerId: PeerId, lowerBound: MessageIndex, upperBound: MessageIndex) -> Int32 {
        var count: Int32 = 0
        self.valueBox.range(self.table, start: self.key(tagMask, index: lowerBound).predecessor, end: self.key(tagMask, index: upperBound.successor()), keys: { _ in
            count += 1
            return true
        }, limit: 0)
        return count
    }
    
    func findRandomIndex(peerId: PeerId, tagMask: MessageTags, ignoreId: MessageId, isMessage: (MessageIndex) -> Bool) -> MessageIndex? {
        var indices: [MessageIndex] = []
        self.valueBox.range(self.table, start: self.lowerBound(tagMask, peerId: peerId), end: self.upperBound(tagMask, peerId: peerId), keys: { key in
            indices.append(MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4 + 4), id: key.getInt32(8 + 4 + 4 + 4)), timestamp: key.getInt32(8 + 4)))
            return true
        }, limit: 0)
        var checkedIndices = Set<Int>()
        loop: while checkedIndices.count < indices.count {
            let i = Int(arc4random_uniform(UInt32(indices.count)))
            if checkedIndices.contains(i) {
                continue loop
            }
            checkedIndices.insert(i)
            let index = indices[i]
            if isMessage(index) && ignoreId != index.id {
                return index
            }
        }
        return nil
    }
    
    func debugGetAllIndices() -> [MessageIndex] {
        var indices: [MessageIndex] = []
        self.valueBox.scan(self.table, values: { key, value in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4 + 4), id: key.getInt32(8 + 4 + 4 + 4)), timestamp: key.getInt32(8 + 4))
            indices.append(index)
            return true
        })
        return indices
    }
}
