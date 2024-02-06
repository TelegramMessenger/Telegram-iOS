import Foundation

private func getBits(data: UnsafeRawPointer, length: Int, bitOffset: Int, numBits: Int) -> Int32 {
    let normalizedNumBits = Int(pow(2.0, Double(numBits))) - 1
    let byteOffset = bitOffset / 8
    let normalizedData = data.advanced(by: byteOffset)
    let normalizedBitOffset = bitOffset % 8
    
    var value: Int32 = 0
    if byteOffset + 4 > length {
        let remaining = length - byteOffset
        withUnsafeMutableBytes(of: &value, { (bytes: UnsafeMutableRawBufferPointer) -> Void in
            memcpy(bytes.baseAddress!, normalizedData, remaining)
        })
    } else {
        value = normalizedData.assumingMemoryBound(to: Int32.self).pointee
    }
    return (value >> Int32(normalizedBitOffset)) & Int32(normalizedNumBits)
}

private func setBits(data: UnsafeMutableRawPointer, bitOffset: Int, numBits: Int, value: Int32) {
    let normalizedData = data.advanced(by: bitOffset / 8)
    let normalizedBitOffset = bitOffset % 8
    
    normalizedData.assumingMemoryBound(to: Int32.self).pointee |= value << Int32(normalizedBitOffset)
}

public final class AudioWaveform: Equatable {
    public let samples: Data
    public let peak: Int32
    
    public init(samples: Data, peak: Int32) {
        self.samples = samples
        self.peak = peak
    }
    
    public convenience init(bitstream: Data, bitsPerSample: Int) {
        let numSamples = Int(Float(bitstream.count * 8) / Float(bitsPerSample))
        var result = Data()
        result.count = numSamples * 2
        
        bitstream.withUnsafeBytes { bytes -> Void in
            result.withUnsafeMutableBytes { samples -> Void in
                let norm = Int64((1 << bitsPerSample) - 1)
                for i in 0 ..< numSamples {
                    samples.baseAddress!.assumingMemoryBound(to: Int16.self)[i] = Int16(Int64(getBits(data: bytes.baseAddress!.assumingMemoryBound(to: Int8.self), length: bitstream.count, bitOffset: i * 5, numBits: 5)) * norm / norm)
                }
            }
        }
        
        self.init(samples: result, peak: 31)
    }
    
    public func makeBitstream() -> Data {
        let numSamples = self.samples.count / 2
        let bitstreamLength = (numSamples * 5) / 8 + (((numSamples * 5) % 8) == 0 ? 0 : 1)
        var result = Data()
        result.count = bitstreamLength + 4
        
        let maxSample: Int32 = self.peak
        
        self.samples.withUnsafeBytes { rawSamples -> Void in
            let samples = rawSamples.baseAddress!.assumingMemoryBound(to: Int16.self)
            
            result.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int16.self)

                for i in 0 ..< numSamples {
                    let value: Int32 = min(Int32(31), abs(Int32(samples[i])) * 31 / maxSample)
                    if i == 99 {
                        assert(true)
                    }
                    setBits(data: bytes, bitOffset: i * 5, numBits: 5, value: value & Int32(31))
                }
            }
        }
        
        result.count = bitstreamLength
        
        return result
    }
    
    public static func ==(lhs: AudioWaveform, rhs: AudioWaveform) -> Bool {
        return lhs.peak == rhs.peak && lhs.samples == rhs.samples
    }
}
