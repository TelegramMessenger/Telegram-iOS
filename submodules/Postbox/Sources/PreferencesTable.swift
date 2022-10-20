import Foundation

enum PreferencesOperation {
    case update(ValueBoxKey, PreferencesEntry?)
}

private struct CachedEntry {
    let entry: PreferencesEntry?
}

final class PreferencesTable: Table {
    private var cachedEntries: [ValueBoxKey: CachedEntry] = [:]
    private var updatedEntryKeys = Set<ValueBoxKey>()
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    func enumerateEntries(_ f: (PreferencesEntry) -> Bool) {
        self.valueBox.scan(self.table, values: { _, value in
            return f(PreferencesEntry(data: value.makeData()))
        })
    }
    
    func get(key: ValueBoxKey) -> PreferencesEntry? {
        if let cached = self.cachedEntries[key] {
            return cached.entry
        } else {
            if let value = self.valueBox.get(self.table, key: key) {
                let object = PreferencesEntry(data: value.makeData())
                self.cachedEntries[key] = CachedEntry(entry: object)
                return object
            } else {
                self.cachedEntries[key] = CachedEntry(entry: nil)
                return nil
            }
        }
    }
    
    func set(key: ValueBoxKey, value: PreferencesEntry?, operations: inout [PreferencesOperation]) {
        self.cachedEntries[key] = CachedEntry(entry: value)
        updatedEntryKeys.insert(key)
        operations.append(.update(key, value))
    }
    
    override func clearMemoryCache() {
        assert(self.updatedEntryKeys.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedEntryKeys.isEmpty {
            for key in self.updatedEntryKeys {
                if let value = self.cachedEntries[key]?.entry {
                    self.valueBox.set(self.table, key: key, value: ReadBuffer(data: value.data))
                } else {
                    self.valueBox.remove(self.table, key: key, secure: false)
                }
            }
            
            self.updatedEntryKeys.removeAll()
        }
    }
}
