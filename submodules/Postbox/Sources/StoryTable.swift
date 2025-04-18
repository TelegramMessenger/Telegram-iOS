import Foundation

final class StoryTable: Table {
    enum Event {
        case updated(id: StoryId)
    }
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private let sharedKey = ValueBoxKey(length: 8 + 4)
    
    private func key(_ key: StoryId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: key.peerId.toInt64())
        self.sharedKey.setInt32(8, value: key.id)
        return self.sharedKey
    }
    
    public func get(id: StoryId) -> CodableEntry? {
        if let value = self.valueBox.get(self.table, key: self.key(id)) {
            return CodableEntry(data: value.makeData())
        } else {
            return nil
        }
    }
    
    public func set(id: StoryId, value: CodableEntry, events: inout [Event]) {
        if self.get(id: id) != value {
            self.valueBox.set(self.table, key: self.key(id), value: MemoryBuffer(data: value.data))
            events.append(.updated(id: id))
        }
    }
    
    override func clearMemoryCache() {
    }
    
    override func beforeCommit() {
    }
}
