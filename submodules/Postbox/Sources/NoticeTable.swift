import Foundation

public struct NoticeEntryKey: Hashable {
    public let namespace: ValueBoxKey
    public let key: ValueBoxKey
    
    fileprivate let combinedKey: ValueBoxKey
    
    public init(namespace: ValueBoxKey, key: ValueBoxKey) {
        self.namespace = namespace
        self.key = key
        
        let combinedKey = ValueBoxKey(length: namespace.length + key.length)
        memcpy(combinedKey.memory, namespace.memory, namespace.length)
        memcpy(combinedKey.memory.advanced(by: namespace.length), key.memory, key.length)
        self.combinedKey = combinedKey
    }
    
    public static func ==(lhs: NoticeEntryKey, rhs: NoticeEntryKey) -> Bool {
        return lhs.combinedKey == rhs.combinedKey
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.combinedKey)
    }
}

private struct CachedEntry {
    let entry: CodableEntry?
}

public final class NoticeTable: Table {
    private var cachedEntries: [NoticeEntryKey: CachedEntry] = [:]
    private var updatedEntryKeys = Set<NoticeEntryKey>()
    
    public static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }

    public override init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool) {
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    public func getAll() -> [ValueBoxKey: CodableEntry] {
        var result: [ValueBoxKey: CodableEntry] = [:]
        self.valueBox.scan(self.table, values: { key, value in
            let object = CodableEntry(data: value.makeData())
            result[key] = object
            return true
        })
        return result
    }
    
    public func get(key: NoticeEntryKey) -> CodableEntry? {
        if let cached = self.cachedEntries[key] {
            return cached.entry
        } else {
            if let value = self.valueBox.get(self.table, key: key.combinedKey) {
                let object = CodableEntry(data: value.makeData())
                self.cachedEntries[key] = CachedEntry(entry: object)
                return object
            } else {
                self.cachedEntries[key] = CachedEntry(entry: nil)
                return nil
            }
        }
    }
    
    public func set(key: NoticeEntryKey, value: CodableEntry?) {
        self.cachedEntries[key] = CachedEntry(entry: value)
        updatedEntryKeys.insert(key)
    }
    
    public func clear() {
        var keys: [ValueBoxKey] = []
        self.valueBox.scan(self.table, keys: { key in
            keys.append(key)
            return true
        })
        for key in keys {
            self.valueBox.remove(self.table, key: key, secure: false)
        }
        self.updatedEntryKeys.formUnion(cachedEntries.keys)
        self.cachedEntries.removeAll()
    }
    
    override public func clearMemoryCache() {
        assert(self.updatedEntryKeys.isEmpty)
    }
    
    override public func beforeCommit() {
        if !self.updatedEntryKeys.isEmpty {
            for key in self.updatedEntryKeys {
                if let value = self.cachedEntries[key]?.entry {
                    self.valueBox.set(self.table, key: key.combinedKey, value: ReadBuffer(data: value.data))
                } else {
                    self.valueBox.remove(self.table, key: key.combinedKey, secure: false)
                }
            }
            
            self.updatedEntryKeys.removeAll()
        }
    }
}
