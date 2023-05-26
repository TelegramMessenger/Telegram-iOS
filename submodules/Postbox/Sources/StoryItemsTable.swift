import Foundation

public final class StoryItemsTableEntry: Equatable {
    public let value: CodableEntry
    public let id: Int32
    
    public init(
        value: CodableEntry,
        id: Int32
    ) {
        self.value = value
        self.id = id
    }
    
    public static func ==(lhs: StoryItemsTableEntry, rhs: StoryItemsTableEntry) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.id != rhs.id {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
}

final class StoryItemsTable: Table {
    enum Event {
        case replace(peerId: PeerId)
    }
    
    private struct Key: Hashable {
        var peerId: PeerId
        var id: Int32
    }
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private let sharedKey = ValueBoxKey(length: 8 + 4)
    
    private func key(_ key: Key) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: key.peerId.toInt64())
        self.sharedKey.setInt32(8, value: key.id)
        return self.sharedKey
    }
    
    private func lowerBound(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    private func upperBound(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key.successor
    }
    
    public func get(peerId: PeerId) -> [StoryItemsTableEntry] {
        var result: [StoryItemsTableEntry] = []

        self.valueBox.range(self.table, start: self.lowerBound(peerId: peerId), end: self.upperBound(peerId: peerId), values: { key, value in
            let id = key.getInt32(8)
            
            let entry = CodableEntry(data: value.makeData())
            result.append(StoryItemsTableEntry(value: entry, id: id))
            
            return true
        }, limit: 10000)
        
        return result
    }
    
    public func replace(peerId: PeerId, entries: [StoryItemsTableEntry], events: inout [Event]) {
        var previousKeys: [ValueBoxKey] = []
        self.valueBox.range(self.table, start: self.lowerBound(peerId: peerId), end: self.upperBound(peerId: peerId), keys: { key in
            previousKeys.append(key)
            
            return true
        }, limit: 10000)
        for key in previousKeys {
            self.valueBox.remove(self.table, key: key, secure: true)
        }
        
        for entry in entries {
            self.valueBox.set(self.table, key: self.key(Key(peerId: peerId, id: entry.id)), value: MemoryBuffer(data: entry.value.data))
        }
        
        events.append(.replace(peerId: peerId))
    }
    
    override func clearMemoryCache() {
    }
    
    override func beforeCommit() {
    }
}
