import Foundation

private final class ValueBoxKeyImpl {
    let memory: UnsafeMutableRawPointer
    
    init(memory: UnsafeMutableRawPointer) {
        self.memory = memory
    }
    
    deinit {
        free(self.memory)
    }
}

public struct ValueBoxKey: Equatable, Hashable, CustomStringConvertible, Comparable {
    public let memory: UnsafeMutableRawPointer
    public let length: Int
    private let impl: ValueBoxKeyImpl

    public init(length: Int) {
        self.memory = malloc(length)!
        self.length = length
        self.impl = ValueBoxKeyImpl(memory: self.memory)
    }
    
    public init(_ value: String) {
        let data = value.data(using: .utf8, allowLossyConversion: true) ?? Data()
        self.memory = malloc(data.count)
        self.length = data.count
        self.impl = ValueBoxKeyImpl(memory: self.memory)
        data.copyBytes(to: self.memory.assumingMemoryBound(to: UInt8.self), count: data.count)
    }
    
    public init(_ buffer: MemoryBuffer) {
        self.memory = malloc(buffer.length)
        self.length = buffer.length
        self.impl = ValueBoxKeyImpl(memory: self.memory)
        memcpy(self.memory, buffer.memory, buffer.length)
    }
    
    public func setData(_ offset: Int, value: Data) {
        assert(offset >= 0 && offset + value.count <= self.length)
        let valueLength = value.count
        value.withUnsafeBytes { rawBytes -> Void in
            let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            memcpy(self.memory + offset, bytes, valueLength)
        }
    }
    
    public func setInt32(_ offset: Int, value: Int32) {
        assert(offset >= 0 && offset + 4 <= self.length)
        var bigEndianValue = Int32(bigEndian: value)
        memcpy(self.memory + offset, &bigEndianValue, 4)
    }
    
    public func setUInt32(_ offset: Int, value: UInt32) {
        assert(offset >= 0 && offset + 4 <= self.length)
        var bigEndianValue = UInt32(bigEndian: value)
        memcpy(self.memory + offset, &bigEndianValue, 4)
    }
    
    public func setInt64(_ offset: Int, value: Int64) {
        assert(offset >= 0 && offset + 8 <= self.length)
        var bigEndianValue = Int64(bigEndian: value)
        memcpy(self.memory + offset, &bigEndianValue, 8)
    }
    
    public func setInt8(_ offset: Int, value: Int8) {
        assert(offset >= 0 && offset + 1 <= self.length)
        var varValue = value
        memcpy(self.memory + offset, &varValue, 1)
    }
    
    public func setUInt8(_ offset: Int, value: UInt8) {
        assert(offset >= 0 && offset + 1 <= self.length)
        var varValue = value
        memcpy(self.memory + offset, &varValue, 1)
    }
    
    public func setUInt16(_ offset: Int, value: UInt16) {
        assert(offset >= 0 && offset + 2 <= self.length)
        var varValue = value
        memcpy(self.memory + offset, &varValue, 2)
    }
    
    public func getInt32(_ offset: Int) -> Int32 {
        assert(offset >= 0 && offset + 4 <= self.length)
        var value: Int32 = 0
        memcpy(&value, self.memory + offset, 4)
        return Int32(bigEndian: value)
    }
    
    public func getUInt32(_ offset: Int) -> UInt32 {
        assert(offset >= 0 && offset + 4 <= self.length)
        var value: UInt32 = 0
        memcpy(&value, self.memory + offset, 4)
        return UInt32(bigEndian: value)
    }
    
    public func getInt64(_ offset: Int) -> Int64 {
        assert(offset >= 0 && offset + 8 <= self.length)
        var value: Int64 = 0
        memcpy(&value, self.memory + offset, 8)
        return Int64(bigEndian: value)
    }
    
    public func getInt8(_ offset: Int) -> Int8 {
        assert(offset >= 0 && offset + 1 <= self.length)
        var value: Int8 = 0
        memcpy(&value, self.memory + offset, 1)
        return value
    }
    
    public func getUInt8(_ offset: Int) -> UInt8 {
        assert(offset >= 0 && offset + 1 <= self.length)
        var value: UInt8 = 0
        memcpy(&value, self.memory + offset, 1)
        return value
    }
    
    public func getUInt16(_ offset: Int) -> UInt16 {
        assert(offset >= 0 && offset + 2 <= self.length)
        var value: UInt16 = 0
        memcpy(&value, self.memory + offset, 2)
        return value
    }
    
    public func prefix(_ length: Int) -> ValueBoxKey {
        assert(length <= self.length, "length <= self.length")
        let key = ValueBoxKey(length: length)
        memcpy(key.memory, self.memory, length)
        return key
    }
    
    public func isPrefix(to other: ValueBoxKey) -> Bool {
        if self.length == 0 {
            return true
        } else if self.length <= other.length {
            return memcmp(self.memory, other.memory, self.length) == 0
        } else {
            return false
        }
    }
    
    public var reversed: ValueBoxKey {
        let key = ValueBoxKey(length: self.length)
        let keyMemory = key.memory.assumingMemoryBound(to: UInt8.self)
        let selfMemory = self.memory.assumingMemoryBound(to: UInt8.self)
        var i = self.length - 1
        while i >= 0 {
            keyMemory[i] = selfMemory[self.length - 1 - i]
            i -= 1
        }
        return key
    }
    
    public var successor: ValueBoxKey {
        let key = ValueBoxKey(length: self.length)
        memcpy(key.memory, self.memory, self.length)
        let memory = key.memory.assumingMemoryBound(to: UInt8.self)
        var i = self.length - 1
        while i >= 0 {
            var byte = memory[i]
            if byte != 0xff {
                byte += 1
                memory[i] = byte
                break
            } else {
                byte = 0
                memory[i] = byte
            }
            i -= 1
        }
        return key
    }

    public var predecessor: ValueBoxKey {
        let key = ValueBoxKey(length: self.length)
        memcpy(key.memory, self.memory, self.length)
        let memory = key.memory.assumingMemoryBound(to: UInt8.self)
        var i = self.length - 1
        while i >= 0 {
            var byte = memory[i]
            if byte != 0x00 {
                byte -= 1
                memory[i] = byte
                break
            } else {
                if i == 0 {
                    assert(self.length > 1)
                    let previousKey = ValueBoxKey(length: self.length - 1)
                    memcpy(previousKey.memory, self.memory, self.length - 1)
                    return previousKey
                } else {
                    byte = 0xff
                    memory[i] = byte
                }
            }
            i -= 1
        }
        return key
    }
    
    public var description: String {
        let string = NSMutableString()
        let memory = self.memory.assumingMemoryBound(to: UInt8.self)
        for i in 0 ..< self.length {
            let byte: Int = Int(memory[i])
            string.appendFormat("%02x", byte)
        }
        return string as String
    }
    
    public var stringValue: String {
        if let string = String(data: Data(bytes: self.memory, count: self.length), encoding: .utf8) {
            return string
        } else {
            return "<unavailable>"
        }
    }
    
    public func substringValue(_ range: Range<Int>) -> String? {
        assert(range.lowerBound >= 0 && range.upperBound <= self.length)
        return String(data: Data(bytes: self.memory.advanced(by: range.lowerBound), count: range.count), encoding: .utf8)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes: UnsafeRawBufferPointer(start: self.memory, count: self.length))
    }
    
    public static func ==(lhs: ValueBoxKey, rhs: ValueBoxKey) -> Bool {
        return lhs.length == rhs.length && memcmp(lhs.memory, rhs.memory, lhs.length) == 0
    }
    
    public static func <(lhs: ValueBoxKey, rhs: ValueBoxKey) -> Bool {
        return mdb_cmp_memn(lhs.memory, lhs.length, rhs.memory, rhs.length) < 0
    }
    
    public func toMemoryBuffer() -> MemoryBuffer {
        let data = malloc(self.length)!
        memcpy(data, self.memory, self.length)
        return MemoryBuffer(memory: data, capacity: self.length, length: self.length, freeWhenDone: true)
    }
    
    public static func +(lhs: ValueBoxKey, rhs: ValueBoxKey) -> ValueBoxKey {
        let result = ValueBoxKey(length: lhs.length + rhs.length)
        memcpy(result.memory, lhs.memory, lhs.length)
        memcpy(result.memory.advanced(by: lhs.length), rhs.memory, rhs.length)
        return result
    }
}

private func mdb_cmp_memn(_ a_memory: UnsafeMutableRawPointer, _ a_length: Int, _ b_memory: UnsafeMutableRawPointer, _ b_length: Int) -> Int
{
    var diff: Int = 0
    var len_diff: Int = 0
    var len: Int = 0
    
    len = a_length
    len_diff = a_length - b_length
    if len_diff > 0 {
        len = b_length
        len_diff = 1
    }
    
    diff = Int(memcmp(a_memory, b_memory, len))
    return diff != 0 ? diff : len_diff < 0 ? -1 : len_diff
}
