import Foundation

private let emptyMemory = malloc(1)!

public class MeshMemoryBuffer: Equatable, CustomStringConvertible {
    public internal(set) var memory: UnsafeMutableRawPointer
    var capacity: Int
    public internal(set) var length: Int
    var freeWhenDone: Bool

    public init(copyOf buffer: MeshMemoryBuffer) {
        self.memory = malloc(buffer.length)
        memcpy(self.memory, buffer.memory, buffer.length)
        self.capacity = buffer.length
        self.length = buffer.length
        self.freeWhenDone = true
    }

    public init(memory: UnsafeMutableRawPointer, capacity: Int, length: Int, freeWhenDone: Bool) {
        self.memory = memory
        self.capacity = capacity
        self.length = length
        self.freeWhenDone = freeWhenDone
    }

    public init(data: Data) {
        if data.count == 0 {
            self.memory = emptyMemory
            self.capacity = 0
            self.length = 0
            self.freeWhenDone = false
        } else {
            self.memory = malloc(data.count)!
            data.copyBytes(to: self.memory.assumingMemoryBound(to: UInt8.self), count: data.count)
            self.capacity = data.count
            self.length = data.count
            self.freeWhenDone = true
        }
    }

    public init() {
        self.memory = emptyMemory
        self.capacity = 0
        self.length = 0
        self.freeWhenDone = false
    }

    deinit {
        if self.freeWhenDone {
            free(self.memory)
        }
    }

    public var description: String {
        let hexString = NSMutableString()
        let bytes = self.memory.assumingMemoryBound(to: UInt8.self)
        for i in 0 ..< self.length {
            hexString.appendFormat("%02x", UInt(bytes[i]))
        }

        return hexString as String
    }

    public func makeData() -> Data {
        if self.length == 0 {
            return Data()
        } else {
            return Data(bytes: self.memory, count: self.length)
        }
    }

    public func withDataNoCopy(_ f: (Data) -> Void) {
        f(Data(bytesNoCopy: self.memory, count: self.length, deallocator: .none))
    }

    public static func ==(lhs: MeshMemoryBuffer, rhs: MeshMemoryBuffer) -> Bool {
        return lhs.length == rhs.length && memcmp(lhs.memory, rhs.memory, lhs.length) == 0
    }
}

public final class MeshWriteBuffer: MeshMemoryBuffer {
    public var offset = 0

    public override init() {
        super.init(memory: malloc(32), capacity: 32, length: 0, freeWhenDone: true)
    }

    public func makeReadBufferAndReset() -> MeshReadBuffer {
        let buffer = MeshReadBuffer(memory: self.memory, length: self.offset, freeWhenDone: true)
        self.memory = malloc(32)
        self.capacity = 32
        self.offset = 0
        return buffer
    }

    public func readBufferNoCopy() -> MeshReadBuffer {
        return MeshReadBuffer(memory: self.memory, length: self.offset, freeWhenDone: false)
    }

    override public func makeData() -> Data {
        return Data(bytes: self.memory.assumingMemoryBound(to: UInt8.self), count: self.offset)
    }

    public func reset() {
        self.offset = 0
    }

    public func write(_ data: UnsafeRawPointer, length: Int) {
        if self.offset + length > self.capacity {
            self.capacity = self.offset + length + 256
            if self.length == 0 {
                self.memory = malloc(self.capacity)!
            } else {
                self.memory = realloc(self.memory, self.capacity)
            }
        }
        memcpy(self.memory + self.offset, data, length)
        self.offset += length
        self.length = self.offset
    }

    public func writeInt8(_ value: Int8) {
        var value = value
        self.write(&value, length: 1)
    }

    public func writeInt32(_ value: Int32) {
        var value = value
        self.write(&value, length: 4)
    }

    public func writeFloat(_ value: Float) {
        var value: Float32 = value
        self.write(&value, length: 4)
    }

    public func write(_ data: Data) {
        let length = data.count
        if self.offset + length > self.capacity {
            self.capacity = self.offset + length + 256
            if self.length == 0 {
                self.memory = malloc(self.capacity)!
            } else {
                self.memory = realloc(self.memory, self.capacity)
            }
        }
        data.copyBytes(to: self.memory.advanced(by: offset).assumingMemoryBound(to: UInt8.self), count: length)
        self.offset += length
        self.length = self.offset
    }
}

public final class MeshReadBuffer: MeshMemoryBuffer {
    public var offset = 0

    override public init(data: Data) {
        super.init(data: data)
    }

    public init(memory: UnsafeMutableRawPointer, length: Int, freeWhenDone: Bool) {
        super.init(memory: memory, capacity: length, length: length, freeWhenDone: freeWhenDone)
    }

    public init(memoryBufferNoCopy: MeshMemoryBuffer) {
        super.init(memory: memoryBufferNoCopy.memory, capacity: memoryBufferNoCopy.length, length: memoryBufferNoCopy.length, freeWhenDone: false)
    }

    public func dataNoCopy() -> Data {
        return Data(bytesNoCopy: self.memory.assumingMemoryBound(to: UInt8.self), count: self.length, deallocator: .none)
    }

    public func read(_ data: UnsafeMutableRawPointer, length: Int) {
        memcpy(data, self.memory.advanced(by: self.offset), length)
        self.offset += length
    }

    public func readInt8() -> Int8 {
        var result: Int8 = 0
        self.read(&result, length: 1)
        return result
    }

    public func readInt32() -> Int32 {
        var result: Int32 = 0
        self.read(&result, length: 4)
        return result
    }

    public func readFloat() -> Float {
        var result: Float32 = 0
        self.read(&result, length: 4)
        return result
    }

    public func skip(_ length: Int) {
        self.offset += length
    }

    public func reset() {
        self.offset = 0
    }

    public func sharedBufferNoCopy() -> MeshReadBuffer {
        return MeshReadBuffer(memory: memory, length: length, freeWhenDone: false)
    }
}
