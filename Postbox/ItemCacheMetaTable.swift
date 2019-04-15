import Foundation

public typealias ItemCacheCollectionId = Int8

public struct ItemCacheCollectionSpec {
    public let lowWaterItemCount: Int32
    public let highWaterItemCount: Int32
    
    public init(lowWaterItemCount: Int32, highWaterItemCount: Int32) {
        self.lowWaterItemCount = lowWaterItemCount
        self.highWaterItemCount = highWaterItemCount
    }
}

struct ItemCacheCollectionState: PostboxCoding {
    let nextAccessIndex: Int32
    
    init(decoder: PostboxDecoder) {
        self.nextAccessIndex = decoder.decodeInt32ForKey("i", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.nextAccessIndex, forKey: "i")
    }
}

final class ItemCacheMetaTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedCollectionStates: [ItemCacheCollectionId: ItemCacheCollectionState] = [:]
    private var updatedCollectionStateIds = Set<ItemCacheCollectionId>()
    
    private func key(_ id: ItemCacheCollectionId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: Int64(id))
        return self.sharedKey
    }
    
    private func get(_ id: ItemCacheCollectionId) -> ItemCacheCollectionState? {
        if let cached = self.cachedCollectionStates[id] {
            return cached
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(id)), let state = PostboxDecoder(buffer: value).decodeRootObject() as? ItemCacheCollectionState {
                self.cachedCollectionStates[id] = state
                return state
            } else {
                return nil
            }
        }
    }
    
    private func set(_ id: ItemCacheCollectionId, state: ItemCacheCollectionState) {
        self.cachedCollectionStates[id] = state
        self.updatedCollectionStateIds.insert(id)
    }
    
    override func clearMemoryCache() {
        self.cachedCollectionStates.removeAll()
        self.updatedCollectionStateIds.removeAll()
    }
    
    override func beforeCommit() {
        if !self.updatedCollectionStateIds.isEmpty {
            let sharedEncoder = PostboxEncoder()
            for id in self.updatedCollectionStateIds {
                if let state = self.cachedCollectionStates[id] {
                    sharedEncoder.reset()
                    sharedEncoder.encodeRootObject(state)
                    withExtendedLifetime(sharedEncoder, {
                        self.valueBox.set(self.table, key: self.key(id), value: sharedEncoder.readBufferNoCopy())
                    })
                }
            }
        }
        
        self.updatedCollectionStateIds.removeAll()
    }
}

