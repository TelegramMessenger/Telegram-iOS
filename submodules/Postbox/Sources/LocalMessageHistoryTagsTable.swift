import Foundation

enum IntermediateMessageHistoryLocalTagsOperation {
    case Insert(LocalMessageTags, MessageId)
    case Remove(LocalMessageTags, MessageId)
    case Update(LocalMessageTags, MessageId)
}

final class LocalMessageHistoryTagsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 4 + 4 + 4 + 8)
    
    private func key(_ id: MessageId, tag: LocalMessageTags) -> ValueBoxKey {
        assert(tag.isSingleTag)
        self.sharedKey.setUInt32(0, value: tag.rawValue)
        self.sharedKey.setInt32(4, value: id.namespace)
        self.sharedKey.setInt32(4 + 4, value: id.id)
        self.sharedKey.setInt64(4 + 4 + 4, value: id.peerId.toInt64())
        
        return self.sharedKey
    }
    
    private func lowerBound(tag: LocalMessageTags) -> ValueBoxKey {
        assert(tag.isSingleTag)
        
        let key = ValueBoxKey(length: 4)
        key.setUInt32(0, value: tag.rawValue)
        return key
    }
    
    private func upperBound(tag: LocalMessageTags) -> ValueBoxKey {
        assert(tag.isSingleTag)
        
        let key = ValueBoxKey(length: 4)
        key.setUInt32(0, value: tag.rawValue)
        return key.successor
    }
    
    func set(id: MessageId, tags: LocalMessageTags, previousTags: LocalMessageTags, operations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        let addedTags = tags.subtracting(previousTags)
        let removedTags = previousTags.subtracting(tags)
        for tag in addedTags {
            self.valueBox.set(self.table, key: self.key(id, tag: tag), value: MemoryBuffer())
            operations.append(.Insert(tag, id))
        }
        for tag in removedTags {
            self.valueBox.remove(self.table, key: self.key(id, tag: tag), secure: false)
            operations.append(.Remove(tag, id))
        }
    }
    
    func get(tag: LocalMessageTags) -> [MessageId] {
        assert(tag.isSingleTag)
        var ids: [MessageId] = []
        self.valueBox.range(self.table, start: self.lowerBound(tag: tag), end: self.upperBound(tag: tag), keys: { key in
            ids.append(MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)))
            return true
        }, limit: 0)
        return ids
    }
}
