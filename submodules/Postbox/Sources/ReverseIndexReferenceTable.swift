import Foundation

protocol ReverseIndexReference: Comparable, Hashable {
    static func decodeArray(_ buffer: MemoryBuffer) -> [Self]
    static func encodeArray(_ array: [Self]) -> MemoryBuffer
}

private final class ReverseIndexReferencesEntry<T: ReverseIndexReference> {
    var orderedReferences: [T] = []
    
    init() {
    }
    
    init(buffer: MemoryBuffer) {
        self.orderedReferences = T.decodeArray(buffer)
    }
    
    private func index(of reference: T) -> Int? {
        var lowerIndex = 0
        var upperIndex = self.orderedReferences.count - 1
        
        if lowerIndex > upperIndex {
            return nil
        }
        
        while (true) {
            let currentIndex = (lowerIndex + upperIndex) / 2
            if self.orderedReferences[currentIndex] == reference {
                return currentIndex
            } else if lowerIndex > upperIndex {
                return nil
            } else {
                if self.orderedReferences[currentIndex] > reference {
                    upperIndex = currentIndex - 1
                } else {
                    lowerIndex = currentIndex + 1
                }
            }
        }
    }
    
    func remove(_ reference: T) -> Bool {
        if let index = self.index(of: reference) {
            self.orderedReferences.remove(at: index)
            return true
        } else {
            return false
        }
    }
    
    func insert(_ reference: T) -> Bool {
        let insertItem = reference
        var lo = 0
        var hi = self.orderedReferences.count - 1
        while lo <= hi {
            let mid = (lo + hi)/2
            if self.orderedReferences[mid] < insertItem {
                lo = mid + 1
            } else if insertItem < self.orderedReferences[mid] {
                hi = mid - 1
            } else {
                return false
            }
        }
        self.orderedReferences.insert(insertItem, at: lo)
        return true
    }
    
    func withMemoryBuffer(_ f: (MemoryBuffer) -> Void) {
        f(T.encodeArray(self.orderedReferences))
    }
}

struct ReverseIndexNamespace: Hashable {
    let value: Int32?
    
    init(_ value: Int32?) {
        self.value = value
    }
}

final class ReverseIndexReferenceTable<T: ReverseIndexReference>: Table {
    private var cachedEntriesByNamespace: [ReverseIndexNamespace: [ValueBoxKey: ReverseIndexReferencesEntry<T>]] = [:]
    private var updatedCachedEntriesByNamespace: [ReverseIndexNamespace: Set<ValueBoxKey>] = [:]
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private func key(namespace: ReverseIndexNamespace, token: ValueBoxKey) -> ValueBoxKey {
        if let value = namespace.value {
            let key = ValueBoxKey(length: 4 + token.length)
            key.setInt32(0, value: value)
            memcpy(key.memory.advanced(by: 4), token.memory, token.length)
            return key
        } else {
            return token
        }
    }
    
    private func getEntry(namespace: ReverseIndexNamespace, token: ValueBoxKey) -> ReverseIndexReferencesEntry<T>? {
        if let cachedNamespace = self.cachedEntriesByNamespace[namespace], let cached = cachedNamespace[token] {
            return cached
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(namespace: namespace, token: token)) {
                let entry = ReverseIndexReferencesEntry<T>(buffer: value)
                if self.cachedEntriesByNamespace[namespace] == nil {
                    self.cachedEntriesByNamespace[namespace] = [token: entry]
                } else {
                    self.cachedEntriesByNamespace[namespace]![token] = entry
                }
                return entry
            } else {
                return nil
            }
        }
    }
    
    private func add(namespace: ReverseIndexNamespace, token: ValueBoxKey, reference: T) {
        let entry: ReverseIndexReferencesEntry<T>
        var addToCache = false
        if let current = self.getEntry(namespace: namespace, token: token) {
            entry = current
        } else {
            entry = ReverseIndexReferencesEntry<T>()
            addToCache = true
        }
        if entry.insert(reference) {
            if self.updatedCachedEntriesByNamespace[namespace] == nil {
                self.updatedCachedEntriesByNamespace[namespace] = Set()
            }
            self.updatedCachedEntriesByNamespace[namespace]!.insert(token)
            if addToCache {
                if self.cachedEntriesByNamespace[namespace] == nil {
                    self.cachedEntriesByNamespace[namespace] = [token: entry]
                } else {
                    self.cachedEntriesByNamespace[namespace]![token] = entry
                }
            }
        }
    }
    
    private func remove(namespace: ReverseIndexNamespace, token: ValueBoxKey, reference: T) {
        let entry: ReverseIndexReferencesEntry<T>
        var addToCache = false
        if let current = self.getEntry(namespace: namespace, token: token) {
            entry = current
        } else {
            entry = ReverseIndexReferencesEntry<T>()
            addToCache = true
        }
        if entry.remove(reference) {
            if self.updatedCachedEntriesByNamespace[namespace] == nil {
                self.updatedCachedEntriesByNamespace[namespace] = Set()
            }
            self.updatedCachedEntriesByNamespace[namespace]!.insert(token)
            if addToCache {
                if self.cachedEntriesByNamespace[namespace] == nil {
                    self.cachedEntriesByNamespace[namespace] = [token: entry]
                } else {
                    self.cachedEntriesByNamespace[namespace]![token] = entry
                }
            }
        }
    }
    
    func add(namespace: ReverseIndexNamespace, reference: T, tokens: [ValueBoxKey]) {
        for token in tokens {
            self.add(namespace: namespace, token: token, reference: reference)
        }
    }
    
    func remove(namespace: ReverseIndexNamespace, reference: T, tokens: [ValueBoxKey]) {
        for token in tokens {
            self.remove(namespace: namespace, token: token, reference: reference)
        }
    }
    
    func matchingReferences(namespace: ReverseIndexNamespace, tokens: [ValueBoxKey], union: Bool = false) -> Set<T> {
        var references: Set<T>?
        for token in tokens {
            if let references = references, references.isEmpty {
                return Set()
            }
            var currentReferences = Set<T>()
            self.valueBox.range(self.table, start: self.key(namespace: namespace, token: token).predecessor, end: self.key(namespace: namespace, token: token).successor, values: { key, value in
                if let cachedNamespace = self.cachedEntriesByNamespace[namespace], let cached = cachedNamespace[token] {
                    for reference in cached.orderedReferences {
                        currentReferences.insert(reference)
                    }
                } else {
                    for reference in ReverseIndexReferencesEntry<T>(buffer: value).orderedReferences {
                        currentReferences.insert(reference)
                    }
                }
                return true
            }, limit: 0)
            if let previousReferences = references {
                if union {
                    references = previousReferences.union(currentReferences)
                } else {
                    references = previousReferences.intersection(currentReferences)
                }
            } else {
                references = currentReferences
            }
        }
        if let references = references {
            return references
        } else {
            return Set()
        }
    }
    
    func exactReferences(namespace: ReverseIndexNamespace, token: ValueBoxKey) -> [T] {
        if let value = self.valueBox.get(self.table, key: self.key(namespace: namespace, token: token)) {
            var currentReferences: [T] = []
            if let cachedNamespace = self.cachedEntriesByNamespace[namespace], let cached = cachedNamespace[token] {
                for reference in cached.orderedReferences {
                    currentReferences.append(reference)
                }
            } else {
                for reference in ReverseIndexReferencesEntry<T>(buffer: value).orderedReferences {
                    currentReferences.append(reference)
                }
            }
            return currentReferences
        } else {
            return []
        }
    }
    
    override func clearMemoryCache() {
        for (_, cachedEntries) in self.cachedEntriesByNamespace {
            assert(cachedEntries.isEmpty)
        }
        for (_, updatedCachedEntries) in self.updatedCachedEntriesByNamespace {
            assert(updatedCachedEntries.isEmpty)
        }
    }
    
    override func beforeCommit() {
        if !self.updatedCachedEntriesByNamespace.isEmpty {
            for (namespace, updatedCachedEntries) in self.updatedCachedEntriesByNamespace {
                for token in updatedCachedEntries {
                    if let cachedNamespace = self.cachedEntriesByNamespace[namespace], let cached = cachedNamespace[token] {
                        cached.withMemoryBuffer { buffer in
                            if buffer.length == 0 {
                                self.valueBox.remove(self.table, key: self.key(namespace: namespace, token: token), secure: false)
                            } else {
                                self.valueBox.set(self.table, key: self.key(namespace: namespace, token: token), value: buffer)
                            }
                        }
                    } else {
                        assertionFailure()
                    }
                }
            }
            self.updatedCachedEntriesByNamespace.removeAll()
        }
        
        if !self.cachedEntriesByNamespace.isEmpty {
            self.cachedEntriesByNamespace.removeAll()
        }
    }
}
