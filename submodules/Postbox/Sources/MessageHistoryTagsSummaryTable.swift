import Foundation

public struct MessageHistoryTagNamespaceCountValidityRange: Equatable {
    public let maxId: MessageId.Id
    
    public init(maxId: MessageId.Id) {
        self.maxId = maxId
    }
    
    public static func ==(lhs: MessageHistoryTagNamespaceCountValidityRange, rhs: MessageHistoryTagNamespaceCountValidityRange) -> Bool {
        return lhs.maxId == rhs.maxId
    }
    
    public func contains(_ id: MessageId.Id) -> Bool {
        return id <= self.maxId
    }
}

public struct MessageHistoryTagNamespaceSummary: Equatable, CustomStringConvertible {
    public let version: Int32
    public let count: Int32
    public let range: MessageHistoryTagNamespaceCountValidityRange
    
    public init(version: Int32, count: Int32, range: MessageHistoryTagNamespaceCountValidityRange) {
        self.version = version
        self.count = count
        self.range = range
    }
    
    public static func ==(lhs: MessageHistoryTagNamespaceSummary, rhs: MessageHistoryTagNamespaceSummary) -> Bool {
        return lhs.version == rhs.version && lhs.count == rhs.count && lhs.range == rhs.range
    }
    
    func withAddedCount(_ value: Int32) -> MessageHistoryTagNamespaceSummary {
        return MessageHistoryTagNamespaceSummary(version: self.version, count: self.count + value, range: self.range)
    }
    
    public var description: String {
        return "(version: \(self.version), count: \(self.count), range: (maxId: \(self.range.maxId)))"
    }
}

struct MessageHistoryTagsSummaryKey: Equatable, Hashable {
    let tag: MessageTags
    let peerId: PeerId
    let namespace: MessageId.Namespace
}

private func readSummary(_ value: ReadBuffer) -> MessageHistoryTagNamespaceSummary {
    var versionValue: Int32 = 0
    value.read(&versionValue, offset: 0, length: 4)
    var countValue: Int32 = 0
    value.read(&countValue, offset: 0, length: 4)
    var maxIdValue: Int32 = 0
    value.read(&maxIdValue, offset: 0, length: 4)

    return MessageHistoryTagNamespaceSummary(version: versionValue, count: countValue, range: MessageHistoryTagNamespaceCountValidityRange(maxId: maxIdValue))
}

private func writeSummary(_ summary: MessageHistoryTagNamespaceSummary, to buffer: WriteBuffer) {
    var versionValue: Int32 = summary.version
    buffer.write(&versionValue, offset: 0, length: 4)
    var countValue: Int32 = summary.count
    buffer.write(&countValue, offset: 0, length: 4)
    var maxIdValue: Int32 = summary.range.maxId
    buffer.write(&maxIdValue, offset: 0, length: 4)
}

private struct CachedEntry {
    let summary: MessageHistoryTagNamespaceSummary?
}

class MessageHistoryTagsSummaryTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let invalidateTable: InvalidatedMessageHistoryTagsSummaryTable
    
    private var cachedSummaries: [MessageHistoryTagsSummaryKey: CachedEntry] = [:]
    private var updatedKeys = Set<MessageHistoryTagsSummaryKey>()
    
    private let sharedKey = ValueBoxKey(length: 4 + 8 + 4)
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, invalidateTable: InvalidatedMessageHistoryTagsSummaryTable) {
        self.invalidateTable = invalidateTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(key: MessageHistoryTagsSummaryKey, sharedKey: ValueBoxKey = ValueBoxKey(length: 4 + 8 + 4)) -> ValueBoxKey {
        sharedKey.setUInt32(0, value: key.tag.rawValue)
        sharedKey.setInt64(4, value: key.peerId.toInt64())
        sharedKey.setInt32(4 + 8, value: key.namespace)
        return sharedKey
    }
    
    func get(_ key: MessageHistoryTagsSummaryKey) -> MessageHistoryTagNamespaceSummary? {
        if let cached = self.cachedSummaries[key] {
            return cached.summary
        } else if let value = self.valueBox.get(self.table, key: self.key(key: key, sharedKey: self.sharedKey)) {
            let entry = readSummary(value)
            self.cachedSummaries[key] = CachedEntry(summary: entry)
            return entry
        } else {
            self.cachedSummaries[key] = CachedEntry(summary: nil)
            return nil
        }
    }
    
    private func set(_ key: MessageHistoryTagsSummaryKey, summary: MessageHistoryTagNamespaceSummary, updatedSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary]) {
        if self.get(key) != summary {
            self.updatedKeys.insert(key)
            self.cachedSummaries[key] = CachedEntry(summary: summary)
            updatedSummaries[key] = summary
        }
    }
    
    func addMessage(key: MessageHistoryTagsSummaryKey, id: MessageId.Id, isNewlyAdded: Bool, updatedSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        if let current = self.get(key) {
            if !isNewlyAdded || !current.range.contains(id) {
                self.set(key, summary: current.withAddedCount(1), updatedSummaries: &updatedSummaries)
                if current.range.maxId == 0 {
                    self.invalidateTable.insert(InvalidatedMessageHistoryTagsSummaryKey(peerId: key.peerId, namespace: key.namespace, tagMask: key.tag), operations: &invalidateSummaries)
                }
            }
        } else {
            self.set(key, summary: MessageHistoryTagNamespaceSummary(version: 0, count: 1, range: MessageHistoryTagNamespaceCountValidityRange(maxId: 0)), updatedSummaries: &updatedSummaries)
            self.invalidateTable.insert(InvalidatedMessageHistoryTagsSummaryKey(peerId: key.peerId, namespace: key.namespace, tagMask: key.tag), operations: &invalidateSummaries)
        }
    }
    
    func removeMessage(key: MessageHistoryTagsSummaryKey, id: MessageId.Id, updatedSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        if let current = self.get(key) {
            if current.count == 0 {
                //self.invalidateTable.insert(InvalidatedMessageHistoryTagsSummaryKey(peerId: key.peerId, namespace: key.namespace, tagMask: key.tag), operations: &invalidateSummaries)
            } else {
                self.set(key, summary: current.withAddedCount(-1), updatedSummaries: &updatedSummaries)
            }
        }
    }
    
    func replace(key: MessageHistoryTagsSummaryKey, count: Int32, maxId: MessageId.Id, updatedSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary]) {
        var version: Int32 = 0
        if let current = self.get(key) {
            version = current.version + 1
        }
        self.set(key, summary: MessageHistoryTagNamespaceSummary(version: version, count: count, range: MessageHistoryTagNamespaceCountValidityRange(maxId: maxId)), updatedSummaries: &updatedSummaries)
    }
    
    override func clearMemoryCache() {
        self.cachedSummaries.removeAll()
        assert(self.updatedKeys.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedKeys.isEmpty {
            let buffer = WriteBuffer()
            for key in self.updatedKeys {
                if let cached = self.cachedSummaries[key] {
                    if let summary = cached.summary {
                        buffer.reset()
                        writeSummary(summary, to: buffer)
                        self.valueBox.set(self.table, key: self.key(key: key, sharedKey: self.sharedKey), value: buffer)
                    } else {
                        assertionFailure()
                        self.valueBox.remove(self.table, key: self.key(key: key, sharedKey: self.sharedKey), secure: false)
                    }
                } else {
                    assertionFailure()
                }
            }
            self.updatedKeys.removeAll()
        }

        if !self.useCaches {
            self.cachedSummaries.removeAll()
        }
    }
}
