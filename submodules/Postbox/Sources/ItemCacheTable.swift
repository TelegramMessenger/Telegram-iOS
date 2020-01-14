import Foundation

public final class ItemCacheEntryId: Equatable, Hashable {
    public let collectionId: ItemCacheCollectionId
    public let key: ValueBoxKey
    
    public init(collectionId: ItemCacheCollectionId, key: ValueBoxKey) {
        self.collectionId = collectionId
        self.key = key
    }
    
    public static func ==(lhs: ItemCacheEntryId, rhs: ItemCacheEntryId) -> Bool {
        return lhs.collectionId == rhs.collectionId && lhs.key == rhs.key
    }
    
    public var hashValue: Int {
        return self.collectionId.hashValue &* 31 &+ self.key.hashValue
    }
}

private enum ItemCacheSection: Int8 {
    case items = 0
    case accessIndexToItemId = 1
    case itemIdToAccessIndex = 2
}

final class ItemCacheTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private func itemKey(id: ItemCacheEntryId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 1 + id.key.length)
        key.setInt8(0, value: ItemCacheSection.items.rawValue)
        key.setInt8(1, value: id.collectionId)
        memcpy(key.memory.advanced(by: 2), id.key.memory, id.key.length)
        return key
    }
    
    private func lowerBound(collectionId: ItemCacheCollectionId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 1)
        key.setInt8(0, value: ItemCacheSection.items.rawValue)
        key.setInt8(1, value: collectionId)
        return key
    }
    
    private func upperBound(collectionId: ItemCacheCollectionId) -> ValueBoxKey {
        return self.lowerBound(collectionId: collectionId).successor
    }
    
    private func itemIdToAccessIndexKey(id: ItemCacheEntryId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 1 + id.key.length)
        key.setInt8(0, value: ItemCacheSection.accessIndexToItemId.rawValue)
        key.setInt8(1, value: id.collectionId)
        memcpy(key.memory.advanced(by: 2), id.key.memory, id.key.length)
        return key
    }
    
    private func accessIndexToItemId(collectionId: ItemCacheCollectionId, index: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 1 + 4)
        key.setInt8(0, value: ItemCacheSection.accessIndexToItemId.rawValue)
        key.setInt8(1, value: collectionId)
        key.setInt32(2, value: index)
        return key
    }
    
    func put(id: ItemCacheEntryId, entry: PostboxCoding, metaTable: ItemCacheMetaTable) {
        let encoder = PostboxEncoder()
        encoder.encodeRootObject(entry)
        withExtendedLifetime(encoder, {
            self.valueBox.set(self.table, key: self.itemKey(id: id), value: encoder.readBufferNoCopy())
        })
    }
    
    func retrieve(id: ItemCacheEntryId, metaTable: ItemCacheMetaTable) -> PostboxCoding? {
        if let value = self.valueBox.get(self.table, key: self.itemKey(id: id)), let entry = PostboxDecoder(buffer: value).decodeRootObject() {
            return entry
        }
        return nil
    }
    
    func remove(id: ItemCacheEntryId, metaTable: ItemCacheMetaTable) {
        self.valueBox.remove(self.table, key: self.itemKey(id: id), secure: false)
    }
    
    func removeAll(collectionId: ItemCacheCollectionId) {
        self.valueBox.removeRange(self.table, start: self.lowerBound(collectionId: collectionId), end: self.upperBound(collectionId: collectionId))
    }
    
    override func clearMemoryCache() {
        
    }
    
    override func beforeCommit() {
        
    }
}
