import Foundation

enum ManagedFileMode {
    case read
    case readwrite
    case append
}

private func wrappedWrite(_ fd: Int32, _ data: UnsafeRawPointer, _ count: Int) -> Int {
    return write(fd, data, count)
}

private func wrappedRead(_ fd: Int32, _ data: UnsafeMutableRawPointer, _ count: Int) -> Int {
    return read(fd, data, count)
}

final class ManagedFile {
    private let fd: Int32
    private let mode: ManagedFileMode
    
    init?(path: String, mode: ManagedFileMode) {
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
        close(self.fd)
    }
    
    func write(_ data: UnsafeRawPointer, count: Int) -> Int {
        return wrappedWrite(self.fd, data, count)
    }
    
    func read(_ data: UnsafeMutableRawPointer, _ count: Int) -> Int {
        return wrappedRead(self.fd, data, count)
    }
    
    func readData(count: Int) -> Data {
        var result = Data(count: count)
        result.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) -> Void in
            let readCount = self.read(bytes, count)
            assert(readCount == count)
        }
        return result
    }
    
    func seek(position: Int64) {
        lseek(self.fd, position, SEEK_SET)
    }
    
    func truncate(count: Int64) {
        ftruncate(self.fd, count)
    }
    
    func getSize() -> Int? {
        var value = stat()
        if fstat(self.fd, &value) == 0 {
            return Int(value.st_size)
        } else {
            return nil
        }
    }
    
    func sync() {
        fsync(self.fd)
    }
}

