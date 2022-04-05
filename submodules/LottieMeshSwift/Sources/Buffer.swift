import Foundation
import Postbox
import ManagedFile

private let emptyMemory = malloc(1)!

public class MeshMemoryBuffer {
    public internal(set) var data: Data
    public internal(set) var length: Int

    public init(data: Data) {
        self.data = data
        self.length = data.count
    }

    public func makeData() -> Data {
        if self.data.count == self.length {
            return self.data
        } else {
            return self.data.subdata(in: 0 ..< self.length)
        }
    }
}

extension WriteBuffer {
    func writeInt32(_ value: Int32) {
        var value = value
        self.write(&value, length: 4)
    }
    
    func writeFloat(_ value: Float) {
        var value: Float32 = value
        self.write(&value, length: 4)
    }
}

public final class MeshWriteBuffer {
    let file: ManagedFile
    private(set) var offset: Int = 0

    public init(file: ManagedFile) {
        self.file = file
    }

    public func write(_ data: UnsafeRawPointer, length: Int) {
        let _ = self.file.write(data, count: length)
        self.offset += length
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
        data.withUnsafeBytes { bytes in
            self.write(bytes.baseAddress!, length: bytes.count)
        }
    }
    
    func write(_ data: DataRange) {
        data.data.withUnsafeBytes { bytes in
            self.write(bytes.baseAddress!.advanced(by: data.range.lowerBound), length: data.count)
        }
    }
    
    public func seek(offset: Int) {
        self.file.seek(position: Int64(offset))
        self.offset = offset
    }
}

public final class MeshReadBuffer: MeshMemoryBuffer {
    public var offset = 0

    override public init(data: Data) {
        super.init(data: data)
    }

    public func read(_ data: UnsafeMutableRawPointer, length: Int) {
        self.data.copyBytes(to: data.assumingMemoryBound(to: UInt8.self), from: self.offset ..< (self.offset + length))
        self.offset += length
    }
    
    func readDataRange(count: Int) -> DataRange {
        let result = DataRange(data: self.data, range: self.offset ..< (self.offset + count))
        self.offset += count
        return result
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
}
