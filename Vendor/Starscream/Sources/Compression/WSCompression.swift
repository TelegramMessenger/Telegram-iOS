//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WSCompression.swift
//
//  Created by Joseph Ross on 7/16/14.
//  Copyright © 2017 Joseph Ross & Vluxe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Compression implementation is implemented in conformance with RFC 7692 Compression Extensions
//  for WebSocket: https://tools.ietf.org/html/rfc7692
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation
import zlib

public class WSCompression: CompressionHandler {
    let headerWSExtensionName = "Sec-WebSocket-Extensions"
    var decompressor: Decompressor?
    var compressor: Compressor?
    var decompressorTakeOver = false
    var compressorTakeOver = false
    
    public init() {
        
    }
    
    public func load(headers: [String: String]) {
        guard let extensionHeader = headers[headerWSExtensionName] else { return }
        decompressorTakeOver = false
        compressorTakeOver = false
        
        let parts = extensionHeader.components(separatedBy: ";")
        for p in parts {
            let part = p.trimmingCharacters(in: .whitespaces)
            if part.hasPrefix("server_max_window_bits=") {
                let valString = part.components(separatedBy: "=")[1]
                if let val = Int(valString.trimmingCharacters(in: .whitespaces)) {
                    decompressor = Decompressor(windowBits: val)
                }
            } else if part.hasPrefix("client_max_window_bits=") {
                let valString = part.components(separatedBy: "=")[1]
                if let val = Int(valString.trimmingCharacters(in: .whitespaces)) {
                    compressor = Compressor(windowBits: val)
                }
            } else if part == "client_no_context_takeover" {
                compressorTakeOver = true
            } else if part == "server_no_context_takeover" {
                decompressorTakeOver = true
            }
        }
    }
    
    public func decompress(data: Data, isFinal: Bool) -> Data? {
        guard let decompressor = decompressor else { return nil }
        do {
            let decompressedData = try decompressor.decompress(data, finish: isFinal)
            if decompressorTakeOver {
                try decompressor.reset()
            }
            return decompressedData
        } catch {
            //do nothing with the error for now
        }
        return nil
    }
    
    public func compress(data: Data) -> Data? {
        guard let compressor = compressor else { return nil }
        do {
            let compressedData = try compressor.compress(data)
            if compressorTakeOver {
                try compressor.reset()
            }
            return compressedData
        } catch {
            //do nothing with the error for now
        }
        return nil
    }
    

}

class Decompressor {
    private var strm = z_stream()
    private var buffer = [UInt8](repeating: 0, count: 0x2000)
    private var inflateInitialized = false
    private let windowBits: Int

    init?(windowBits: Int) {
        self.windowBits = windowBits
        guard initInflate() else { return nil }
    }

    private func initInflate() -> Bool {
        if Z_OK == inflateInit2_(&strm, -CInt(windowBits),
                                 ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
        {
            inflateInitialized = true
            return true
        }
        return false
    }

    func reset() throws {
        teardownInflate()
        guard initInflate() else { throw WSError(type: .compressionError, message: "Error for decompressor on reset", code: 0) }
    }

    func decompress(_ data: Data, finish: Bool) throws -> Data {
        return try data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Data in
            return try decompress(bytes: bytes, count: data.count, finish: finish)
        }
    }

    func decompress(bytes: UnsafePointer<UInt8>, count: Int, finish: Bool) throws -> Data {
        var decompressed = Data()
        try decompress(bytes: bytes, count: count, out: &decompressed)

        if finish {
            let tail:[UInt8] = [0x00, 0x00, 0xFF, 0xFF]
            try decompress(bytes: tail, count: tail.count, out: &decompressed)
        }

        return decompressed
    }

    private func decompress(bytes: UnsafePointer<UInt8>, count: Int, out: inout Data) throws {
        var res: CInt = 0
        strm.next_in = UnsafeMutablePointer<UInt8>(mutating: bytes)
        strm.avail_in = CUnsignedInt(count)

        repeat {
            buffer.withUnsafeMutableBytes { (bufferPtr) in
                strm.next_out = bufferPtr.bindMemory(to: UInt8.self).baseAddress
                strm.avail_out = CUnsignedInt(bufferPtr.count)

                res = inflate(&strm, 0)
            }

            let byteCount = buffer.count - Int(strm.avail_out)
            out.append(buffer, count: byteCount)
        } while res == Z_OK && strm.avail_out == 0

        guard (res == Z_OK && strm.avail_out > 0)
            || (res == Z_BUF_ERROR && Int(strm.avail_out) == buffer.count)
            else {
                throw WSError(type: .compressionError, message: "Error on decompressing", code: 0)
        }
    }

    private func teardownInflate() {
        if inflateInitialized, Z_OK == inflateEnd(&strm) {
            inflateInitialized = false
        }
    }

    deinit {
        teardownInflate()
    }
}

class Compressor {
    private var strm = z_stream()
    private var buffer = [UInt8](repeating: 0, count: 0x2000)
    private var deflateInitialized = false
    private let windowBits: Int

    init?(windowBits: Int) {
        self.windowBits = windowBits
        guard initDeflate() else { return nil }
    }

    private func initDeflate() -> Bool {
        if Z_OK == deflateInit2_(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
                                 -CInt(windowBits), 8, Z_DEFAULT_STRATEGY,
                                 ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
        {
            deflateInitialized = true
            return true
        }
        return false
    }

    func reset() throws {
        teardownDeflate()
        guard initDeflate() else { throw WSError(type: .compressionError, message: "Error for compressor on reset", code: 0) }
    }

    func compress(_ data: Data) throws -> Data {
        var compressed = Data()
        var res: CInt = 0
        data.withUnsafeBytes { (ptr:UnsafePointer<UInt8>) -> Void in
            strm.next_in = UnsafeMutablePointer<UInt8>(mutating: ptr)
            strm.avail_in = CUnsignedInt(data.count)

            repeat {
                buffer.withUnsafeMutableBytes { (bufferPtr) in
                    strm.next_out = bufferPtr.bindMemory(to: UInt8.self).baseAddress
                    strm.avail_out = CUnsignedInt(bufferPtr.count)

                    res = deflate(&strm, Z_SYNC_FLUSH)
                }

                let byteCount = buffer.count - Int(strm.avail_out)
                compressed.append(buffer, count: byteCount)
            }
            while res == Z_OK && strm.avail_out == 0

        }

        guard res == Z_OK && strm.avail_out > 0
            || (res == Z_BUF_ERROR && Int(strm.avail_out) == buffer.count)
        else {
            throw WSError(type: .compressionError, message: "Error on compressing", code: 0)
        }

        compressed.removeLast(4)
        return compressed
    }

    private func teardownDeflate() {
        if deflateInitialized, Z_OK == deflateEnd(&strm) {
            deflateInitialized = false
        }
    }

    deinit {
        teardownDeflate()
    }
}
