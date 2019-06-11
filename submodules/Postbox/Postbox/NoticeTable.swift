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
    
    public var hashValue: Int {
        return self.combinedKey.hashValue
    }
}

private struct CachedEntry {
    let entry: NoticeEntry?
}

public protocol NoticeEntry: PostboxCoding {
    func isEqual(to: NoticeEntry) -> Bool
}

final class NoticeTable: Table {
    private var cachedEntries: [NoticeEntryKey: CachedEntry] = [:]
    private var updatedEntryKeys = Set<NoticeEntryKey>()
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    func getAll() -> [ValueBoxKey: NoticeEntry] {
        var result: [ValueBoxKey: NoticeEntry] = [:]
        self.valueBox.scan(self.table, values: { key, value in
            if let object = PostboxDecoder(buffer: value).decodeRootObject() as? NoticeEntry {
                result[key] = object
            }
            return true
        })
        return result
    }
    
    func get(key: NoticeEntryKey) -> NoticeEntry? {
        if let cached = self.cachedEntries[key] {
            return cached.entry
        } else {
            if let value = self.valueBox.get(self.table, key: key.combinedKey), let object = PostboxDecoder(buffer: value).decodeRootObject() as? NoticeEntry {
                self.cachedEntries[key] = CachedEntry(entry: object)
                return object
            } else {
                self.cachedEntries[key] = CachedEntry(entry: nil)
                return nil
            }
        }
    }
    
    func set(key: NoticeEntryKey, value: NoticeEntry?) {
        self.cachedEntries[key] = CachedEntry(entry: value)
        updatedEntryKeys.insert(key)
    }
    
    func clear() {
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
    
    override func clearMemoryCache() {
        assert(self.updatedEntryKeys.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedEntryKeys.isEmpty {
            for key in self.updatedEntryKeys {
                if let value = self.cachedEntries[key]?.entry {
                    let encoder = PostboxEncoder()
                    encoder.encodeRootObject(value)
                    withExtendedLifetime(encoder, {
                        self.valueBox.set(self.table, key: key.combinedKey, value: encoder.readBufferNoCopy())
                    })
                } else {
                    self.valueBox.remove(self.table, key: key.combinedKey, secure: false)
                }
            }
            
            self.updatedEntryKeys.removeAll()
        }
    }
}
