import Foundation

protocol RatingTableItem {
    static func emptyKey() -> ValueBoxKey
    static func fromKey(key: ValueBoxKey) -> Self
    func ratingKey(rating: Int32, sharedKey: ValueBoxKey) -> ValueBoxKey
}

extension PeerId: RatingTableItem {
    static func emptyKey() -> ValueBoxKey {
        return ValueBoxKey(length: 4 + 8)
    }
    
    static func fromKey(key: ValueBoxKey) -> PeerId {
        return PeerId(key.getInt64(4))
    }
    
    func ratingKey(rating: Int32, sharedKey: ValueBoxKey) -> ValueBoxKey {
        sharedKey.setInt32(0, value: rating)
        sharedKey.setInt64(4, value: self.toInt64())
        return sharedKey
    }
}

final class RatingTable<T: RatingTableItem>: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private var items: [T]?
    
    func get() -> [T] {
        if let items = self.items {
            return items
        } else {
            let lowerBound = T.emptyKey()
            let upperBound = T.emptyKey()
            memset(lowerBound.memory, 0, lowerBound.length)
            memset(upperBound.memory, 0xff, upperBound.length)
            
            var result: [T] = []
            self.valueBox.range(self.table, start: lowerBound, end: upperBound, keys: { key in
                result.append(T.fromKey(key: key))
                return true
            }, limit: 0)
            
            self.items = result
            return result
        }
    }
    
    func replace(items: [T]) {
        var keys: [ValueBoxKey] = []
        let lowerBound = T.emptyKey()
        let upperBound = T.emptyKey()
        memset(lowerBound.memory, 0, lowerBound.length)
        memset(upperBound.memory, 0xff, upperBound.length)
        self.valueBox.range(self.table, start: lowerBound, end: upperBound, keys: { key in
            keys.append(key)
            return true
        }, limit: 0)
        
        for key in keys {
            self.valueBox.remove(self.table, key: key, secure: false)
        }
        
        let sharedKey = T.emptyKey()
        var index: Int32 = 0
        for item in items {
            self.valueBox.set(self.table, key: item.ratingKey(rating: index, sharedKey: sharedKey), value: MemoryBuffer())
            index += 1
        }
        
        self.items = items
    }
    
    override func clearMemoryCache() {
        self.items = nil
    }
    
    override func beforeCommit() {
        
    }
}
