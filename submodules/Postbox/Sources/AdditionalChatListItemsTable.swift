import Foundation

public protocol AdditionalChatListItem: PostboxCoding {
    var peerId: PeerId { get }
    var includeIfNoHistory: Bool { get }
    
    func isEqual(to other: AdditionalChatListItem) -> Bool
}

final class AdditionalChatListItemsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private var cachedItems: [AdditionalChatListItem]?
    private var updatedItems = false
    
    private func key(_ index: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: index)
        return key
    }
    
    private func lowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 1)
        key.setInt8(0, value: 0)
        return key
    }
    
    private func upperBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: Int32.max)
        return key
    }
    
    func set(_ items: [AdditionalChatListItem]) -> Bool {
        let current = self.get()
        var updated = false
        if current.count != items.count {
            updated = true
        } else {
            for i in 0 ..< current.count {
                if !current[i].isEqual(to: items[i]) {
                    updated = true
                    break
                }
            }
        }
        if !updated {
            return false
        }
        self.cachedItems = items
        self.updatedItems = true
        
        return true
    }
    
    func get() -> [AdditionalChatListItem] {
        if let cachedItems = self.cachedItems {
            return cachedItems
        }
        var items: [AdditionalChatListItem] = []
        self.valueBox.range(self.table, start: self.lowerBound(), end: self.upperBound(), values: { key, value in
            assert(key.getInt32(0) == Int32(items.count))
            if value.length <= 8 {
                return true
            }
            if let decoded = PostboxDecoder(buffer: value).decodeRootObject() as? AdditionalChatListItem {
                items.append(decoded)
            }
            return true
        }, limit: 0)
        self.cachedItems = items
        return items
    }
    
    override func clearMemoryCache() {
        self.cachedItems = nil
        assert(!self.updatedItems)
    }
    
    override func beforeCommit() {
        if self.updatedItems {
            var keys: [ValueBoxKey] = []
            self.valueBox.range(self.table, start: self.lowerBound(), end: self.upperBound(), keys: { key in
                keys.append(key)
                return true
            }, limit: 0)
            for key in keys {
                self.valueBox.remove(self.table, key: key, secure: false)
            }
            
            if let items = self.cachedItems {
                var index: Int32 = 0
                for item in items {
                    let encoder = PostboxEncoder()
                    encoder.encodeRootObject(item)
                    self.valueBox.set(self.table, key: self.key(index), value: encoder.memoryBuffer())
                    index += 1
                }
            } else {
                assertionFailure()
            }
            
            self.updatedItems = false
        }
    }
}
