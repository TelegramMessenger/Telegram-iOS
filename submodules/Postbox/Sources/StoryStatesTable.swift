import Foundation

final class StoryStatesTable: Table {
    enum Event {
        case set(Key)
    }
    
    enum Key: Hashable {
        case local
        case subscriptions(PostboxStorySubscriptionsKey)
        case peer(PeerId)
        
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
            case 2:
                self = .peer(PeerId(key.getInt64(1)))
            default:
                assertionFailure()
                self = .peer(PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: ._internalFromInt64Value(0)))
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
    
    private let sharedKey = ValueBoxKey(length: 8 + 4)
    
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
