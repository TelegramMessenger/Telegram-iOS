import Foundation

final class AdditionalChatListItemsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private var cachedItems: [PeerId]?
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
    
    func set(_ items: [PeerId]) -> Bool {
        if self.get() == items {
            return false
        }
        self.cachedItems = items
        self.updatedItems = true
        
        return true
    }
    
    func get() -> [PeerId] {
        if let cachedItems = self.cachedItems {
            return cachedItems
        }
        var items: [PeerId] = []
        self.valueBox.range(self.table, start: self.lowerBound(), end: self.upperBound(), values: { key, value in
            assert(key.getInt32(0) == Int32(items.count))
            var peerIdValue: Int64 = 0
            value.read(&peerIdValue, offset: 0, length: 8)
            items.append(PeerId(peerIdValue))
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
                    var peerIdValue = item.toInt64()
                    self.valueBox.set(self.table, key: self.key(index), value: MemoryBuffer(memory: &peerIdValue, capacity: 8, length: 8, freeWhenDone: false))
                    index += 1
                }
            } else {
                assertionFailure()
            }
            
            self.updatedItems = false
        }
    }
}
