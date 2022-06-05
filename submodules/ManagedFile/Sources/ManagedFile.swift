import Foundation
import SwiftSignalKit

private func wrappedWrite(_ fd: Int32, _ data: UnsafeRawPointer, _ count: Int) -> Int {
    return write(fd, data, count)
}

private func wrappedRead(_ fd: Int32, _ data: UnsafeMutableRawPointer, _ count: Int) -> Int {
    return read(fd, data, count)
}

public final class ManagedFile {
    public enum Mode {
        case read
        case readwrite
        case append
    }
    
    private let queue: Queue?
    private let fd: Int32
    private let mode: Mode
    
    public init?(queue: Queue?, path: String, mode: Mode) {
        if let queue = queue {
            assert(queue.isCurrent())
        }
        self.queue = queue
        self.mode = mode
        let fileMode: Int32
        let accessMode: UInt16
        switch mode {
            case .read:
                fileMode = O_RDONLY
                accessMode = S_IRUSR
            case .readwrite:
                fileMode = O_RDWR | O_CREAT
                accessMode = S_IRUSR | S_IWUSR
            case .append:
                fileMode = O_WRONLY | O_CREAT | O_APPEND
                accessMode = S_IRUSR | S_IWUSR
        }
        let fd = open(path, fileMode, accessMode)
        if fd >= 0 {
            self.fd = fd
        } else {
            return nil
        }
    }
    
    deinit {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        close(self.fd)
    }
    
    public func write(_ data: UnsafeRawPointer, count: Int) -> Int {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        return wrappedWrite(self.fd, data, count)
    }
    
    public func read(_ data: UnsafeMutableRawPointer, _ count: Int) -> Int {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        return wrappedRead(self.fd, data, count)
    }
    
    public func readData(count: Int) -> Data {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        var result = Data(count: count)
        result.withUnsafeMutableBytes { buffer -> Void in
            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            let readCount = self.read(bytes, count)
            assert(readCount == count)
        }
        return result
    }
    
    public func seek(position: Int64) {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        lseek(self.fd, position, SEEK_SET)
    }
    
    public func truncate(count: Int64) {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        ftruncate(self.fd, count)
    }
    
    public func getSize() -> Int64? {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        var value = stat()
        if fstat(self.fd, &value) == 0 {
            return value.st_size
        } else {
            return nil
        }
    }
    
    public func position() -> Int64 {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        
        return lseek(self.fd, 0, SEEK_CUR);
    }
    
    public func sync() {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        fsync(self.fd)
    }
}

public extension ManagedFile {
    func write(_ data: Data) -> Int {
        if data.isEmpty {
            return 0
        }
        return data.withUnsafeBytes { bytes -> Int in
            return self.write(bytes.baseAddress!, count: bytes.count)
        }
    }
    
    func write(_ value: Int32) {
        var value = value
        let _ = self.write(&value, count: 4)
    }
    
    func write(_ value: UInt32) {
        var value = value
        let _ = self.write(&value, count: 4)
    }
    
    func write(_ value: Int64) {
        var value = value
        let _ = self.write(&value, count: 8)
    }
    
    func write(_ value: UInt64) {
        var value = value
        let _ = self.write(&value, count: 8)
    }
    
    func write(_ value: Float32) {
        var value = value
        let _ = self.write(&value, count: 4)
    }
}
