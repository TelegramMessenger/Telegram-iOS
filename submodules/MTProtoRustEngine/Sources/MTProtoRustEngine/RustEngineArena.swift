import Foundation
import MTProtoEngineFFI

final class RustEngineArena {
    private var allocations: [(UnsafeMutableRawPointer, Int)] = []

    init() {
    }

    deinit {
        for (pointer, size) in self.allocations {
            memset(pointer, 0, size)
            pointer.deallocate()
        }
    }

    private func copy(_ bytes: UnsafeRawBufferPointer) -> UnsafeRawPointer? {
        if bytes.count == 0 {
            return nil
        }
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: bytes.count, alignment: 8)
        pointer.copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
        self.allocations.append((pointer, bytes.count))
        return UnsafeRawPointer(pointer)
    }

    func string(_ value: String?) -> MTString {
        guard let value = value, !value.isEmpty else {
            return MTString(data: nil, length: 0)
        }
        let utf8 = Array(value.utf8)
        let pointer = utf8.withUnsafeBytes { self.copy($0) }
        return MTString(data: pointer?.assumingMemoryBound(to: CChar.self), length: utf8.count)
    }

    func bytes(_ value: Data?) -> MTBytes {
        guard let value = value, !value.isEmpty else {
            return MTBytes(data: nil, length: 0)
        }
        let pointer = value.withUnsafeBytes { self.copy($0) }
        return MTBytes(data: pointer?.assumingMemoryBound(to: UInt8.self), length: value.count)
    }

    func array<T>(_ values: [T]) -> UnsafePointer<T>? {
        if values.isEmpty {
            return nil
        }
        let pointer = values.withUnsafeBytes { self.copy($0) }
        return pointer?.assumingMemoryBound(to: T.self)
    }

    func value<T>(_ value: T) -> UnsafePointer<T> {
        let pointer = withUnsafeBytes(of: value) { self.copy($0) }
        return pointer!.assumingMemoryBound(to: T.self)
    }
}

func rustEngineString(_ value: MTString) -> String {
    guard let data = value.data, value.length > 0 else {
        return ""
    }
    return data.withMemoryRebound(to: UInt8.self, capacity: value.length) { pointer in
        return String(decoding: UnsafeBufferPointer(start: pointer, count: value.length), as: UTF8.self)
    }
}

func rustEngineTakePayload(_ buffer: OpaquePointer?) -> Data? {
    guard let buffer = buffer else {
        return nil
    }
    let length = mt_buffer_length(buffer)
    guard length > 0, let bytes = mt_buffer_data(buffer) else {
        mt_buffer_free(buffer)
        return Data()
    }
    return Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes), count: length, deallocator: .custom({ _, _ in
        mt_buffer_free(buffer)
    }))
}
