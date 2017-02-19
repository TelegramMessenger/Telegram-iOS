import Foundation

enum ValueBoxKeyType: Int32 {
    case binary
    case int64
}

struct ValueBoxTable {
    let id: Int32
    let keyType: ValueBoxKeyType
}

protocol ValueBox {
    func begin()
    func commit()
    
    func beginStats()
    func endStats()
    
    func range(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, values: (ValueBoxKey, ReadBuffer) -> Bool, limit: Int)
    func range(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, keys: (ValueBoxKey) -> Bool, limit: Int)
    func scan(_ table: ValueBoxTable, values: (ValueBoxKey, ReadBuffer) -> Bool)
    func get(_ table: ValueBoxTable, key: ValueBoxKey) -> ReadBuffer?
    func exists(_ table: ValueBoxTable, key: ValueBoxKey) -> Bool
    func set(_ table: ValueBoxTable, key: ValueBoxKey, value: MemoryBuffer)
    func remove(_ table: ValueBoxTable, key: ValueBoxKey)
    func drop()
}
