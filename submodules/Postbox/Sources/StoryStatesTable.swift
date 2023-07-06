import Foundation

public struct StoredStoryPeerState: Equatable {
    public var entry: CodableEntry
    public var maxSeenId: Int32
    
    public init(entry: CodableEntry, maxSeenId: Int32) {
        self.entry = entry
        self.maxSeenId = maxSeenId
    }
}

private extension StoredStoryPeerState {
    init?(buffer: MemoryBuffer) {
        let readBuffer = ReadBuffer(memoryBufferNoCopy: buffer)
        var version: UInt8 = 0
        readBuffer.read(&version, offset: 0, length: 1)
        if version != 100 {
            return nil
        }
        
        var entryLength: Int32 = 0
        readBuffer.read(&entryLength, offset: 0, length: 4)
        if entryLength < 0 || readBuffer.offset + Int(entryLength) > readBuffer.length {
            return nil
        }
        self.entry = CodableEntry(data: readBuffer.readData(length: Int(entryLength)))
        
        var maxSeenId: Int32 = 0
        readBuffer.read(&maxSeenId, offset: 0, length: 4)
        self.maxSeenId = maxSeenId
    }
    
    func serialize(buffer: WriteBuffer) {
        var version: UInt8 = 100
        buffer.write(&version, length: 1)
        
        var entryLength: Int32 = Int32(self.entry.data.count)
        buffer.write(&entryLength, length: 4)
        buffer.write(self.entry.data)
        
        var maxSeenId: Int32 = self.maxSeenId
        buffer.write(&maxSeenId, length: 4)
    }
}

final class StoryGeneralStatesTable: Table {
    enum Event {
        case set(Key)
    }
    
    enum Key: Hashable {
        case local
        case subscriptions(PostboxStorySubscriptionsKey)
        
        init?(key: ValueBoxKey) {
            switch key.getUInt8(0) {
            case 0:
                self = .local
            case 1:
                if key.length != 1 + 4 {
                    return nil
                }
                guard let subscriptionsKey = PostboxStorySubscriptionsKey(rawValue: key.getInt32(1)) else {
                    return nil
                }
                self = .subscriptions(subscriptionsKey)
            default:
                assertionFailure()
                self = .subscriptions(.hidden)
            }
        }
        
        func asKey() -> ValueBoxKey {
            switch self {
            case .local:
                let key = ValueBoxKey(length: 1)
                key.setUInt8(0, value: 0)
                return key
            case let .subscriptions(subscriptionsKey):
                let key = ValueBoxKey(length: 1 + 4)
                key.setUInt8(0, value: 1)
                key.setInt32(1, value: subscriptionsKey.rawValue)
                return key
            }
        }
    }
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    func get(key: Key) -> CodableEntry? {
        return self.valueBox.get(self.table, key: key.asKey()).flatMap { CodableEntry(data: $0.makeData()) }
    }
    
    func set(key: Key, value: CodableEntry?, events: inout [Event]) {
        if let value = value {
            self.valueBox.set(self.table, key: key.asKey(), value: MemoryBuffer(data: value.data))
        } else {
            self.valueBox.remove(self.table, key: key.asKey(), secure: true)
        }
        events.append(.set(key))
    }
    
    override func clearMemoryCache() {
    }
    
    override func beforeCommit() {
    }
}

final class StoryPeerStatesTable: Table {
    enum Event {
        case set(Key)
    }
    
    enum Key: Hashable {
        case peer(PeerId)
        
        init?(key: ValueBoxKey) {
            switch key.getUInt8(0) {
            case 0:
                self = .peer(PeerId(key.getInt64(1)))
            default:
                assertionFailure()
                self = .peer(PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: ._internalFromInt64Value(0)))
            }
        }
        
        func asKey() -> ValueBoxKey {
            switch self {
            case let .peer(peerId):
                let key = ValueBoxKey(length: 1 + 8)
                key.setUInt8(0, value: 2)
                key.setInt64(1, value: peerId.toInt64())
                return key
            }
        }
    }
    
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    func get(key: Key) -> StoredStoryPeerState? {
        return self.valueBox.get(self.table, key: key.asKey()).flatMap { StoredStoryPeerState(buffer: $0) }
    }
    
    func set(key: Key, value: StoredStoryPeerState?, events: inout [Event]) {
        if let value = value {
            let buffer = WriteBuffer()
            value.serialize(buffer: buffer)
            self.valueBox.set(self.table, key: key.asKey(), value: buffer.readBufferNoCopy())
        } else {
            self.valueBox.remove(self.table, key: key.asKey(), secure: true)
        }
        events.append(.set(key))
    }
    
    override func clearMemoryCache() {
    }
    
    override func beforeCommit() {
    }
}
