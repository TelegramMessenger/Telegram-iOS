import Foundation

public protocol ValueBox {
    func begin()
    func commit()
    
    func beginStats()
    func endStats()
    
    func range(table: Int32, start: ValueBoxKey, end: ValueBoxKey, @noescape values: (ValueBoxKey, ReadBuffer) -> Bool, limit: Int)
    func range(table: Int32, start: ValueBoxKey, end: ValueBoxKey, keys: ValueBoxKey -> Bool, limit: Int)
    func get(table: Int32, key: ValueBoxKey) -> ReadBuffer?
    func exists(table: Int32, key: ValueBoxKey) -> Bool
    func set(table: Int32, key: ValueBoxKey, value: MemoryBuffer)
    func remove(table: Int32, key: ValueBoxKey)
    func drop()
}
