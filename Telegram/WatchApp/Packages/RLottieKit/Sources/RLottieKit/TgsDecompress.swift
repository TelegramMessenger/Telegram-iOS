import Foundation
import zlib

public enum TgsDecompressError: Error {
    case inflateFailed(Int32)
    case emptyInput
}

/// Inflates a TGS (gzipped lottie JSON) blob into the raw JSON bytes rlottie expects.
/// Uses libz with `windowBits = 15 + 32` so the auto-detect path handles both gzip and
/// plain zlib wrappers (defensive — TGS files in the wild are always gzip).
public func decompressTgs(_ data: Data) throws -> Data {
    guard !data.isEmpty else { throw TgsDecompressError.emptyInput }

    var stream = z_stream()
    var status = inflateInit2_(&stream, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    guard status == Z_OK else { throw TgsDecompressError.inflateFailed(status) }
    defer { inflateEnd(&stream) }

    var output = Data()
    let bufferSize = 64 * 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)

    try data.withUnsafeBytes { (inPtr: UnsafeRawBufferPointer) in
        let basePtr = inPtr.bindMemory(to: UInt8.self).baseAddress!
        stream.next_in = UnsafeMutablePointer(mutating: basePtr)
        stream.avail_in = UInt32(data.count)

        repeat {
            try buffer.withUnsafeMutableBufferPointer { outBuf in
                stream.next_out = outBuf.baseAddress
                stream.avail_out = UInt32(bufferSize)
                status = inflate(&stream, Z_NO_FLUSH)
                if status != Z_OK && status != Z_STREAM_END {
                    throw TgsDecompressError.inflateFailed(status)
                }
                let produced = bufferSize - Int(stream.avail_out)
                if produced > 0 {
                    output.append(outBuf.baseAddress!, count: produced)
                }
            }
        } while status != Z_STREAM_END
    }

    return output
}
