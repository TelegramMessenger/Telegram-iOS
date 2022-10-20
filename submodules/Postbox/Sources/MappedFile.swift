import Foundation

public final class MappedFile {
    private var handle: Int32
    private var currentSize: Int
    private var memory: UnsafeMutableRawPointer
    
    public init(path: String) {
        self.handle = open(path, O_RDWR | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
        
        var value = stat()
        stat(path, &value)
        self.currentSize = Int(value.st_size)
        
        self.memory = mmap(nil, self.currentSize, PROT_READ | PROT_WRITE, MAP_SHARED, self.handle, 0)
    }
    
    deinit {
        munmap(self.memory, self.currentSize)
        close(self.handle)
    }
    
    public var size: Int {
        get {
            return self.currentSize
        } set(value) {
            if value != self.currentSize {
                munmap(self.memory, self.currentSize)
                ftruncate(self.handle, off_t(value))
                self.currentSize = value
                self.memory = mmap(nil, self.currentSize, PROT_READ | PROT_WRITE, MAP_SHARED, self.handle, 0)
            }
        }
    }
    
    public func synchronize() {
        msync(self.memory, self.currentSize, MS_ASYNC)
    }
    
    public func write(at range: Range<Int>, from data: UnsafeRawPointer) {
        memcpy(self.memory.advanced(by: range.lowerBound), data, range.count)
    }
    
    public func read(at range: Range<Int>, to data: UnsafeMutableRawPointer) {
        memcpy(data, self.memory.advanced(by: range.lowerBound), range.count)
    }
    
    public func clear() {
        memset(self.memory, 0, self.currentSize)
    }
}
