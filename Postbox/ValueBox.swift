import Foundation

enum ValueBoxKeyType: Int32 {
    case binary
    case int64
}

struct ValueBoxTable {
    let id: Int32
    let keyType: ValueBoxKeyType
}

struct ValueBoxFullTextTable {
    let id: Int32
}

protocol ValueBox {
    func begin()
    func commit()
    
    func beginStats()
    func endStats()
    
    func range(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, values: (ValueBoxKey, ReadBuffer) -> Bool, limit: Int)
    func range(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, keys: (ValueBoxKey) -> Bool, limit: Int)
    func scan(_ table: ValueBoxTable, values: (ValueBoxKey, ReadBuffer) -> Bool)
    func scan(_ table: ValueBoxTable, keys: (ValueBoxKey) -> Bool)
    func scanInt64(_ table: ValueBoxTable, values: (Int64, ReadBuffer) -> Bool)
    func get(_ table: ValueBoxTable, key: ValueBoxKey) -> ReadBuffer?
    func exists(_ table: ValueBoxTable, key: ValueBoxKey) -> Bool
    func set(_ table: ValueBoxTable, key: ValueBoxKey, value: MemoryBuffer)
    func remove(_ table: ValueBoxTable, key: ValueBoxKey)
    func move(_ table: ValueBoxTable, from previousKey: ValueBoxKey, to updatedKey: ValueBoxKey)
    func removeRange(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey)
    func fullTextSet(_ table: ValueBoxFullTextTable, collectionId: String, itemId: String, contents: String, tags: String)
    func fullTextMatch(_ table: ValueBoxFullTextTable, collectionId: String?, query: String, tags: String?, values: (String, String) -> Bool)
    func fullTextRemove(_ table: ValueBoxFullTextTable, itemId: String)
    func dropTable(_ table: ValueBoxTable)
    func drop()
}
