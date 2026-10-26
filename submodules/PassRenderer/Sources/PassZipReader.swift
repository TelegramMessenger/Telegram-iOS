import Foundation
import Compression

let passArchiveMaxFileSize: Int = 10 * 1024 * 1024
let passArchiveMaxUnpackedSize: Int = 20 * 1024 * 1024
let passArchiveMaxEntryCount = 400

struct PassZipReader {
    private struct Entry {
        var method: UInt16
        var compressedSize: Int
        var uncompressedSize: Int
        var localHeaderOffset: Int
    }

    private let data: Data
    private var entries: [String: Entry] = [:]

    var names: Set<String> {
        return Set(self.entries.keys)
    }

    private static func uint16(_ data: Data, _ offset: Int) -> Int? {
        guard offset >= 0, offset + 2 <= data.count else {
            return nil
        }
        let start = data.startIndex + offset
        return Int(data[start]) | (Int(data[start + 1]) << 8)
    }

    private static func uint32(_ data: Data, _ offset: Int) -> Int? {
        guard offset >= 0, offset + 4 <= data.count else {
            return nil
        }
        let start = data.startIndex + offset
        return Int(data[start]) | (Int(data[start + 1]) << 8) | (Int(data[start + 2]) << 16) | (Int(data[start + 3]) << 24)
    }

    init?(path: String) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path), let fileSize = (attributes[.size] as? NSNumber)?.intValue, fileSize >= 22, fileSize <= passArchiveMaxFileSize else {
            return nil
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)), data.count == fileSize else {
            return nil
        }
        self.data = data

        var endOffset: Int?
        var offset = data.count - 22
        let lowestOffset = max(0, data.count - 22 - 0xffff)
        while offset >= lowestOffset {
            if PassZipReader.uint32(data, offset) == 0x06054b50 {
                endOffset = offset
                break
            }
            offset -= 1
        }
        guard let end = endOffset, let entryCount = PassZipReader.uint16(data, end + 10), let directorySize = PassZipReader.uint32(data, end + 12), let directoryOffset = PassZipReader.uint32(data, end + 16) else {
            return nil
        }
        guard entryCount > 0, entryCount <= passArchiveMaxEntryCount, entryCount != 0xffff, directoryOffset != 0xffffffff, directoryOffset + directorySize <= end else {
            return nil
        }

        var totalSize = 0
        var position = directoryOffset
        for _ in 0 ..< entryCount {
            guard PassZipReader.uint32(data, position) == 0x02014b50, let flags = PassZipReader.uint16(data, position + 8), let method = PassZipReader.uint16(data, position + 10), let compressedSize = PassZipReader.uint32(data, position + 20), let uncompressedSize = PassZipReader.uint32(data, position + 24), let nameLength = PassZipReader.uint16(data, position + 28), let extraLength = PassZipReader.uint16(data, position + 30), let commentLength = PassZipReader.uint16(data, position + 32), let localHeaderOffset = PassZipReader.uint32(data, position + 42) else {
                return nil
            }
            let nameStart = position + 46
            guard nameStart + nameLength <= end else {
                return nil
            }
            if (flags & 1) != 0 || compressedSize == 0xffffffff || uncompressedSize == 0xffffffff || localHeaderOffset == 0xffffffff {
                return nil
            }
            totalSize += uncompressedSize
            if totalSize > passArchiveMaxUnpackedSize {
                return nil
            }
            if let name = String(data: data.subdata(in: (data.startIndex + nameStart) ..< (data.startIndex + nameStart + nameLength)), encoding: .utf8), self.entries[name] == nil {
                self.entries[name] = Entry(method: UInt16(method), compressedSize: compressedSize, uncompressedSize: uncompressedSize, localHeaderOffset: localHeaderOffset)
            }
            position = nameStart + nameLength + extraLength + commentLength
        }
    }

    func contents(of name: String) -> Data? {
        guard let entry = self.entries[name] else {
            return nil
        }
        let data = self.data
        guard PassZipReader.uint32(data, entry.localHeaderOffset) == 0x04034b50, let nameLength = PassZipReader.uint16(data, entry.localHeaderOffset + 26), let extraLength = PassZipReader.uint16(data, entry.localHeaderOffset + 28) else {
            return nil
        }
        let start = entry.localHeaderOffset + 30 + nameLength + extraLength
        guard start + entry.compressedSize <= data.count else {
            return nil
        }
        let compressed = data.subdata(in: (data.startIndex + start) ..< (data.startIndex + start + entry.compressedSize))
        switch entry.method {
        case 0:
            return entry.compressedSize == entry.uncompressedSize ? compressed : nil
        case 8:
            if entry.uncompressedSize == 0 {
                return Data()
            }
            let capacity = entry.uncompressedSize + 1
            var result = Data(count: capacity)
            let written = result.withUnsafeMutableBytes { destination -> Int in
                return compressed.withUnsafeBytes { source -> Int in
                    guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress, let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else {
                        return 0
                    }
                    return compression_decode_buffer(destinationBase, capacity, sourceBase, source.count, nil, COMPRESSION_ZLIB)
                }
            }
            guard written == entry.uncompressedSize else {
                return nil
            }
            result.count = written
            return result
        default:
            return nil
        }
    }
}
