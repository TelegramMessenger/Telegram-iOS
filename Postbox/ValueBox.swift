import Foundation

public protocol ValueBox {
    func begin()
    func commit()
    
    func beginStats()
    func endStats()
    
    func range(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey, values: @noescape(ValueBoxKey, ReadBuffer) -> Bool, limit: Int)
    func range(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey, keys: @noescape(ValueBoxKey) -> Bool, limit: Int)
    func get(_ table: Int32, key: ValueBoxKey) -> ReadBuffer?
    func exists(_ table: Int32, key: ValueBoxKey) -> Bool
    func set(_ table: Int32, key: ValueBoxKey, value: MemoryBuffer)
    func remove(_ table: Int32, key: ValueBoxKey)
    func drop()
}
