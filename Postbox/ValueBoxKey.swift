import Foundation

private final class ValueBoxKeyImpl {
    let memory: UnsafeMutablePointer<Void>
    
    init(memory: UnsafeMutablePointer<Void>) {
        self.memory = memory
    }
    
    deinit {
        free(self.memory)
    }
}

public struct ValueBoxKey: Comparable, CustomStringConvertible {
    public let memory: UnsafeMutablePointer<Void>
    public let length: Int
    private let impl: ValueBoxKeyImpl

    public init(length: Int) {
        self.memory = malloc(length)
        self.length = length
        self.impl = ValueBoxKeyImpl(memory: self.memory)
    }
    
    public init(_ value: String) {
        let data = value.data(using: .utf8, allowLossyConversion: true)!
        self.memory = malloc(data.count)
        self.length = data.count
        self.impl = ValueBoxKeyImpl(memory: self.memory)
        data.copyBytes(to: UnsafeMutablePointer<UInt8>(self.memory), count: data.count)
    }
    
    public init(_ buffer: MemoryBuffer) {
        self.memory = malloc(buffer.length)
        self.length = buffer.length
        self.impl = ValueBoxKeyImpl(memory: self.memory)
        memcpy(self.memory, buffer.memory, buffer.length)
    }
    
    public func setInt32(_ offset: Int, value: Int32) {
        var bigEndianValue = Int32(bigEndian: value)
        memcpy(self.memory + offset, &bigEndianValue, 4)
    }
    
    public func setUInt32(_ offset: Int, value: UInt32) {
        var bigEndianValue = UInt32(bigEndian: value)
        memcpy(self.memory + offset, &bigEndianValue, 4)
    }
    
    public func setInt64(_ offset: Int, value: Int64) {
        var bigEndianValue = Int64(bigEndian: value)
        memcpy(self.memory + offset, &bigEndianValue, 8)
    }
    
    public func setInt8(_ offset: Int, value: Int8) {
        var varValue = value
        memcpy(self.memory + offset, &varValue, 1)
    }
    
    public func getInt32(_ offset: Int) -> Int32 {
        var value: Int32 = 0
        memcpy(&value, self.memory + offset, 4)
        return Int32(bigEndian: value)
    }
    
    public func getUInt32(_ offset: Int) -> UInt32 {
        var value: UInt32 = 0
        memcpy(&value, self.memory + offset, 4)
        return UInt32(bigEndian: value)
    }
    
    public func getInt64(_ offset: Int) -> Int64 {
        var value: Int64 = 0
        memcpy(&value, self.memory + offset, 8)
        return Int64(bigEndian: value)
    }
    
    public func getInt8(_ offset: Int) -> Int8 {
        var value: Int8 = 0
        memcpy(&value, self.memory + offset, 1)
        return value
    }
    
    public func prefix(_ length: Int) -> ValueBoxKey {
        assert(length <= self.length, "length <= self.length")
        let key = ValueBoxKey(length: length)
        memcpy(key.memory, self.memory, length)
        return key
    }
    
    public var successor: ValueBoxKey {
        let key = ValueBoxKey(length: self.length)
        memcpy(key.memory, self.memory, self.length)
        let memory = UnsafeMutablePointer<UInt8>(key.memory)
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
        let memory = UnsafeMutablePointer<UInt8>(key.memory)
        var i = self.length - 1
        while i >= 0 {
            var byte = memory[i]
            if byte != 0x00 {
                byte -= 1
                memory[i] = byte
                break
            } else {
                byte = 0xff
                memory[i] = byte
            }
            i -= 1
        }
        return key
    }
    
    public var description: String {
        let string = NSMutableString()
        let memory = UnsafeMutablePointer<UInt8>(self.memory)
        for i in 0 ..< self.length {
            let byte: Int = Int(memory[i])
            string.appendFormat("%02x", byte)
        }
        return string as String
    }
}

public func ==(lhs: ValueBoxKey, rhs: ValueBoxKey) -> Bool {
    return lhs.length == rhs.length && memcmp(lhs.memory, rhs.memory, lhs.length) == 0
}

private func mdb_cmp_memn(_ a_memory: UnsafeMutablePointer<Void>, _ a_length: Int, _ b_memory: UnsafeMutablePointer<Void>, _ b_length: Int) -> Int
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

public func <(lhs: ValueBoxKey, rhs: ValueBoxKey) -> Bool {
    return mdb_cmp_memn(lhs.memory, lhs.length, rhs.memory, rhs.length) < 0
}
