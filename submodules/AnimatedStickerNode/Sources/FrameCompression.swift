import Foundation
import Compression
import YuvConversion

func compressFrame(width: Int, height: Int, rgbData: Data, unpremultiply: Bool) -> Data? {
    let bytesPerRow = rgbData.count / height
    
    let yuvaPixelsPerAlphaRow = (Int(width) + 1) & (~1)
    assert(yuvaPixelsPerAlphaRow % 2 == 0)
    
    let yuvaLength = Int(width) * Int(height) * 2 + yuvaPixelsPerAlphaRow * Int(height) / 2
    let yuvaFrameData = malloc(yuvaLength)!
    defer {
        free(yuvaFrameData)
    }
    memset(yuvaFrameData, 0, yuvaLength)
    
    var compressedFrameData = Data(count: yuvaLength)
    let compressedFrameDataLength = compressedFrameData.count
    
    let scratchData = malloc(compression_encode_scratch_buffer_size(COMPRESSION_LZFSE))!
    defer {
        free(scratchData)
    }
    
    var rgbData = rgbData
    rgbData.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> Void in
        if let baseAddress = buffer.baseAddress {
            encodeRGBAToYUVA(yuvaFrameData.assumingMemoryBound(to: UInt8.self), baseAddress.assumingMemoryBound(to: UInt8.self), Int32(width), Int32(height), Int32(bytesPerRow), unpremultiply)
        }
    }
    
    var maybeResultSize: Int?
    
    compressedFrameData.withUnsafeMutableBytes { buffer -> Void in
        guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return
        }
        let length = compression_encode_buffer(bytes, compressedFrameDataLength, yuvaFrameData.assumingMemoryBound(to: UInt8.self), yuvaLength, scratchData, COMPRESSION_LZFSE)
        maybeResultSize = length
    }
    
    guard let resultSize = maybeResultSize else {
        return nil
    }
    compressedFrameData.count = resultSize
    return compressedFrameData
}

func compressFrame(width: Int, height: Int, yuvaData: Data) -> Data? {
    let yuvaLength = yuvaData.count
    
    var compressedFrameData = Data(count: yuvaLength)
    let compressedFrameDataLength = compressedFrameData.count
    
    let scratchData = malloc(compression_encode_scratch_buffer_size(COMPRESSION_LZFSE))!
    defer {
        free(scratchData)
    }

    var maybeResultSize: Int?
    
    yuvaData.withUnsafeBytes { yuvaBuffer -> Void in
        if let yuvaFrameData = yuvaBuffer.baseAddress {
            compressedFrameData.withUnsafeMutableBytes { buffer -> Void in
                guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }
                let length = compression_encode_buffer(bytes, compressedFrameDataLength, yuvaFrameData.assumingMemoryBound(to: UInt8.self), yuvaLength, scratchData, COMPRESSION_LZFSE)
                maybeResultSize = length
            }
        }
    }
    
    guard let resultSize = maybeResultSize else {
        return nil
    }
    compressedFrameData.count = resultSize
    return compressedFrameData
}
