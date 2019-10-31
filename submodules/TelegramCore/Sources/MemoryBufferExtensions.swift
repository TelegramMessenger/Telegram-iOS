import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif


public extension MemoryBuffer {
    convenience init(_ buffer: Buffer) {
        let memory = malloc(Int(buffer.size))!
        memcpy(memory, buffer.data, Int(buffer.size))
        self.init(memory: memory, capacity: Int(buffer.size), length: Int(buffer.size), freeWhenDone: true)
    }
}

extension Buffer {
    convenience init(bufferNoCopy: MemoryBuffer) {
        self.init(memory: bufferNoCopy.memory, size: bufferNoCopy.length, capacity: bufferNoCopy.length, freeWhenDone: false)
    }
    
    convenience init(buffer: MemoryBuffer) {
        let memory = malloc(buffer.length)!
        memcpy(memory, buffer.memory, buffer.length)
        self.init(memory: memory, size: buffer.length, capacity: buffer.length, freeWhenDone: true)
    }
}
