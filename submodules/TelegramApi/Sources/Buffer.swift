import Foundation

public struct Int128 {
    public var _0: Int64
    public var _1: Int64
}

public struct Int256 {
    public var _0: Int64
    public var _1: Int64
    public var _2: Int64
    public var _3: Int64
}

func serializeInt32(_ value: Int32, buffer: Buffer, boxed: Bool) {
    if boxed {
        buffer.appendInt32(-1471112230)
    }
    buffer.appendInt32(value)
}

func serializeInt64(_ value: Int64, buffer: Buffer, boxed: Bool) {
    if boxed {
        buffer.appendInt32(570911930)
    }
    buffer.appendInt64(value)
}

func serializeDouble(_ value: Double, buffer: Buffer, boxed: Bool) {
    if boxed {
        buffer.appendInt32(571523412)
    }
    buffer.appendDouble(value)
}

func serializeString(_ value: String, buffer: Buffer, boxed: Bool) {
    let stringBuffer = Buffer()
    let data = value.data(using: .utf8, allowLossyConversion: true) ?? Data()
    data.withUnsafeBytes { bytes in
        stringBuffer.appendBytes(bytes.baseAddress!, length: UInt(bytes.count))
    }
    serializeBytes(stringBuffer, buffer: buffer, boxed: boxed)
}

public func serializeBytes(_ value: Buffer, buffer: Buffer, boxed: Bool) {
        if boxed {
            buffer.appendInt32(-1255641564)
        }
        
        var length: Int32 = Int32(value.size)
        var padding: Int32 = 0
        if (length >= 254)
        {
            var tmp: UInt8 = 254
            buffer.appendBytes(&tmp, length: 1)
            buffer.appendBytes(&length, length: 3)
            padding = (((length % 4) == 0 ? length : (length + 4 - (length % 4)))) - length;
        }
        else
        {
            buffer.appendBytes(&length, length: 1)
            
            let e1 = (((length + 1) % 4) == 0 ? (length + 1) : ((length + 1) + 4 - ((length + 1) % 4)))
            padding = (e1) - (length + 1)
        }
    
        if value.size != 0 {
            buffer.appendBytes(value.data!, length: UInt(length))
        }

        var i: Int32 = 0
        var tmp: UInt8 = 0
        while i < padding {
            buffer.appendBytes(&tmp, length: 1)
            i += 1
        }
}

func serializeInt128(_ value: Int128, buffer: Buffer, boxed: Bool) {
    if boxed {
        buffer.appendInt32(1270167083)
    }
    
    buffer.appendInt64(value._0)
    buffer.appendInt64(value._1)
}

func serializeInt256(_ value: Int256, buffer: Buffer, boxed: Bool) {
    if boxed {
        buffer.appendInt32(153731887)
    }
    
    buffer.appendInt64(value._0)
    buffer.appendInt64(value._1)
    buffer.appendInt64(value._2)
    buffer.appendInt64(value._3)
}

func parseInt128(_ reader: BufferReader) -> Int128? {
    let _0 = reader.readInt64()
    let _1 = reader.readInt64()
    if _0 != nil && _1 != nil {
        return Int128(_0: _0!, _1: _1!)
    }
    return nil
}

func parseInt256(_ reader: BufferReader) -> Int256? {
    let _0 = reader.readInt64()
    let _1 = reader.readInt64()
    let _2 = reader.readInt64()
    let _3 = reader.readInt64()
    if _0 != nil && _1 != nil && _2 != nil && _3 != nil {
        return Int256(_0: _0!, _1: _1!, _2: _2!, _3: _3!)
    }
    return nil
}

private func roundUp(_ numToRound: Int, multiple: Int) -> Int
{
    if multiple == 0 {
        return numToRound
    }
    
    let remainder = numToRound % multiple
    if remainder == 0 {
        return numToRound;
    }
    
    return numToRound + multiple - remainder
}

public func parseBytes(_ reader: BufferReader) -> Buffer? {
    if let tmp = reader.readBytesAsInt32(1) {
        var paddingBytes: Int = 0
        var length: Int = 0
        if tmp == 254 {
            if let len = reader.readBytesAsInt32(3) {
                length = Int(len)
                paddingBytes = roundUp(length, multiple: 4) - length
            }
            else {
                return nil
            }
        }
        else {
            length = Int(tmp)
            paddingBytes = roundUp(length + 1, multiple: 4) - (length + 1)
        }
        
        let buffer = reader.readBuffer(length)
        reader.skip(paddingBytes)
        return buffer
    }
    return nil
}

func parseString(_ reader: BufferReader) -> String? {
    if let buffer = parseBytes(reader) {
        return String(data: buffer.makeData(), encoding: .utf8) ?? ""
    }
    return nil
}

public class Buffer: CustomStringConvertible {
    public var data: UnsafeMutableRawPointer?
    public var _size: UInt = 0
    private var capacity: UInt = 0
    private let freeWhenDone: Bool
    
    public var size: Int {
        return Int(self._size)
    }
    
    deinit {
        if self.freeWhenDone {
            free(self.data)
        }
    }
    
    public init(memory: UnsafeMutableRawPointer?, size: Int, capacity: Int, freeWhenDone: Bool) {
        self.data = memory
        self._size = UInt(size)
        self.capacity = UInt(capacity)
        self.freeWhenDone = freeWhenDone
    }
    
    public init() {
        self.data = nil
        self._size = 0
        self.capacity = 0
        self.freeWhenDone = true
    }
    
    convenience public init(data: Data?) {
        self.init()
        
        if let data = data {
            data.withUnsafeBytes { bytes in
                self.appendBytes(bytes.baseAddress!, length: UInt(bytes.count))
            }
        }
    }
    
    public func makeData() -> Data {
        return self.withUnsafeMutablePointer { pointer, size -> Data in
            if let pointer = pointer {
                return Data(bytes: pointer.assumingMemoryBound(to: UInt8.self), count: Int(size))
            } else {
                return Data()
            }
        }
    }
    
    public var description: String {
        get {
            var string = ""
            if let data = self.data {
                var i: UInt = 0
                let bytes = data.assumingMemoryBound(to: UInt8.self)
                while i < _size && i < 8 {
                    string += String(format: "%02x", Int(bytes.advanced(by: Int(i)).pointee))
                    i += 1
                }
                if i < _size {
                    string += "...\(_size)b"
                }
            } else {
                string += "<null>"
            }
            return string
        }
    }
    
    public func appendBytes(_ bytes: UnsafeRawPointer, length: UInt) {
        if self.capacity < self._size + length {
            self.capacity = self._size + length + 128
            if self.data == nil {
                self.data = malloc(Int(self.capacity))!
            }
            else {
                self.data = realloc(self.data, Int(self.capacity))!
            }
        }
        
        memcpy(self.data?.advanced(by: Int(self._size)), bytes, Int(length))
        self._size += length
    }
    
    public func appendBuffer(_ buffer: Buffer) {
        if self.capacity < self._size + buffer._size {
            self.capacity = self._size + buffer._size + 128
            if self.data == nil {
                self.data = malloc(Int(self.capacity))!
            }
            else {
                self.data = realloc(self.data, Int(self.capacity))!
            }
        }
        
        memcpy(self.data?.advanced(by: Int(self._size)), buffer.data, Int(buffer._size))
    }
    
    public func appendInt32(_ value: Int32) {
        var v = value
        self.appendBytes(&v, length: 4)
    }
    
    public func appendInt64(_ value: Int64) {
        var v = value
        self.appendBytes(&v, length: 8)
    }
    
    public func appendDouble(_ value: Double) {
        var v = value
        self.appendBytes(&v, length: 8)
    }
    
    public func withUnsafeMutablePointer<R>(_ f: (UnsafeMutableRawPointer?, UInt) -> R) -> R {
        return f(self.data, self._size)
    }
}

public class BufferReader {
    private let buffer: Buffer
    public private(set) var offset: UInt = 0
    
    public init(_ buffer: Buffer) {
        self.buffer = buffer
    }
    
    public func reset() {
        self.offset = 0
    }
    
    public func skip(_ count: Int) {
        self.offset = min(self.buffer._size, self.offset + UInt(count))
    }
    
    public func readInt32() -> Int32? {
        if self.offset + 4 <= self.buffer._size {
            let value: Int32 = buffer.data!.advanced(by: Int(self.offset)).assumingMemoryBound(to: Int32.self).pointee
            self.offset += 4
            return value
        }
        return nil
    }
    
    public func readInt64() -> Int64? {
        if self.offset + 8 <= self.buffer._size {
            let value: Int64 = buffer.data!.advanced(by: Int(self.offset)).assumingMemoryBound(to: Int64.self).pointee
            self.offset += 8
            return value
        }
        return nil
    }
    
    public func readDouble() -> Double? {
        if self.offset + 8 <= self.buffer._size {
            let value: Double = buffer.data!.advanced(by: Int(self.offset)).assumingMemoryBound(to: Double.self).pointee
            self.offset += 8
            return value
        }
        return nil
    }
    
    public func readBytesAsInt32(_ count: Int) -> Int32? {
        if count == 0 {
            return 0
        }
        else if count > 0 && count <= 4 || self.offset + UInt(count) <= self.buffer._size {
            var value: Int32 = 0
            memcpy(&value, self.buffer.data?.advanced(by: Int(self.offset)), count)
            self.offset += UInt(count)
            return value
        }
        return nil
    }
    
    public func readBuffer(_ count: Int) -> Buffer? {
        if count >= 0 && self.offset + UInt(count) <= self.buffer._size {
            let buffer = Buffer()
            buffer.appendBytes((self.buffer.data?.advanced(by: Int(self.offset)))!, length: UInt(count))
            self.offset += UInt(count)
            return buffer
        }
        return nil
    }
    
    public func withReadBufferNoCopy<T>(_ count: Int, _ f: (Buffer) -> T) -> T? {
        if count >= 0 && self.offset + UInt(count) <= self.buffer._size {
            return f(Buffer(memory: self.buffer.data!.advanced(by: Int(self.offset)), size: count, capacity: count, freeWhenDone: false))
        }
        return nil
    }
}
