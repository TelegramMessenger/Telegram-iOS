import Foundation

class LegacyBuffer: CustomStringConvertible {
    var data: UnsafeMutableRawPointer?
    var _size: UInt = 0
    private var capacity: UInt = 0
    private let freeWhenDone: Bool
    
    var size: Int {
        return Int(self._size)
    }
    
    deinit {
        if self.freeWhenDone {
            free(self.data)
        }
    }
    
    init(memory: UnsafeMutableRawPointer?, size: Int, capacity: Int, freeWhenDone: Bool) {
        self.data = memory
        self._size = UInt(size)
        self.capacity = UInt(capacity)
        self.freeWhenDone = freeWhenDone
    }
    
    init() {
        self.data = nil
        self._size = 0
        self.capacity = 0
        self.freeWhenDone = true
    }
    
    convenience init(data: Data?) {
        self.init()
        
        if let data = data {
            data.withUnsafeBytes { bytes in
                self.appendBytes(bytes, length: UInt(data.count))
            }
        }
    }
    
    func makeData() -> Data {
        return self.withUnsafeMutablePointer { pointer, size -> Data in
            if let pointer = pointer {
                return Data(bytes: pointer.assumingMemoryBound(to: UInt8.self), count: Int(size))
            } else {
                return Data()
            }
        }
    }
    
    var description: String {
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
    
    func appendBytes(_ bytes: UnsafeRawPointer, length: UInt) {
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
    
    func appendBuffer(_ buffer: LegacyBuffer) {
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
    
    func appendInt32(_ value: Int32) {
        var v = value
        self.appendBytes(&v, length: 4)
    }
    
    func appendInt64(_ value: Int64) {
        var v = value
        self.appendBytes(&v, length: 8)
    }
    
    func appendDouble(_ value: Double) {
        var v = value
        self.appendBytes(&v, length: 8)
    }
    
    func withUnsafeMutablePointer<R>(_ f: (UnsafeMutableRawPointer?, UInt) -> R) -> R {
        return f(self.data, self._size)
    }
}

class LegacyBufferReader {
    private let buffer: LegacyBuffer
    private(set) var offset: UInt = 0
    
    init(_ buffer: LegacyBuffer) {
        self.buffer = buffer
    }
    
    func reset() {
        self.offset = 0
    }
    
    func skip(_ count: Int) {
        self.offset = min(self.buffer._size, self.offset + UInt(count))
    }
    
    func readInt32() -> Int32? {
        if self.offset + 4 <= self.buffer._size {
            let value: Int32 = buffer.data!.advanced(by: Int(self.offset)).assumingMemoryBound(to: Int32.self).pointee
            self.offset += 4
            return value
        }
        return nil
    }
    
    func readInt64() -> Int64? {
        if self.offset + 8 <= self.buffer._size {
            let value: Int64 = buffer.data!.advanced(by: Int(self.offset)).assumingMemoryBound(to: Int64.self).pointee
            self.offset += 8
            return value
        }
        return nil
    }
    
    func readDouble() -> Double? {
        if self.offset + 8 <= self.buffer._size {
            let value: Double = buffer.data!.advanced(by: Int(self.offset)).assumingMemoryBound(to: Double.self).pointee
            self.offset += 8
            return value
        }
        return nil
    }
    
    func readBytesAsInt32(_ count: Int) -> Int32? {
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
    
    func readBuffer(_ count: Int) -> LegacyBuffer? {
        if count >= 0 && self.offset + UInt(count) <= self.buffer._size {
            let buffer = LegacyBuffer()
            buffer.appendBytes((self.buffer.data?.advanced(by: Int(self.offset)))!, length: UInt(count))
            self.offset += UInt(count)
            return buffer
        }
        return nil
    }
    
    func withReadBufferNoCopy<T>(_ count: Int, _ f: (LegacyBuffer) -> T) -> T? {
        if count >= 0 && self.offset + UInt(count) <= self.buffer._size {
            return f(LegacyBuffer(memory: self.buffer.data!.advanced(by: Int(self.offset)), size: count, capacity: count, freeWhenDone: false))
        }
        return nil
    }
}
