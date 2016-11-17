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
    
    func range(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, values: @noescape(ValueBoxKey, ReadBuffer) -> Bool, limit: Int)
    func range(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, keys: @noescape(ValueBoxKey) -> Bool, limit: Int)
    func get(_ table: ValueBoxTable, key: ValueBoxKey) -> ReadBuffer?
    func exists(_ table: ValueBoxTable, key: ValueBoxKey) -> Bool
    func set(_ table: ValueBoxTable, key: ValueBoxKey, value: MemoryBuffer)
    func remove(_ table: ValueBoxTable, key: ValueBoxKey)
    func drop()
}
