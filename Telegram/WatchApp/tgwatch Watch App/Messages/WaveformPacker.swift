import Foundation

/// Packs linear amplitudes (each in [0, 1]) into Telegram's 5-bit LSB-first
/// waveform format: exactly 32 samples → 32 × 5 = 160 bits = 20 bytes. Inverse
/// of `unpackWaveform(_:)`. Amplitudes are bucketed by index into 32 bars (peak
/// per bucket, matching the display-side `downsample`) and peak-normalized so
/// quiet recordings still render a full-scale waveform.
enum WaveformPacker {
    static let barCount = 32
    static let byteCount = 20

    static func pack(_ amplitudes: [Float]) -> Data {
        guard !amplitudes.isEmpty else { return Data(count: byteCount) }
        let bars = bucket(amplitudes, into: barCount)
        let peak = max(bars.max() ?? 0, 0.0001)
        var bytes = [UInt8](repeating: 0, count: byteCount)
        for (i, amp) in bars.enumerated() {
            let q = UInt32((min(1, amp / peak) * 31).rounded())   // 0…31
            let bitStart = i * 5
            let byteIndex = bitStart / 8
            let bitOffset = bitStart % 8
            var span = UInt32(bytes[byteIndex])
            if byteIndex + 1 < byteCount { span |= UInt32(bytes[byteIndex + 1]) << 8 }
            if byteIndex + 2 < byteCount { span |= UInt32(bytes[byteIndex + 2]) << 16 }
            span |= (q & 0x1F) << UInt32(bitOffset)
            bytes[byteIndex] = UInt8(span & 0xFF)
            if byteIndex + 1 < byteCount { bytes[byteIndex + 1] = UInt8((span >> 8) & 0xFF) }
            if byteIndex + 2 < byteCount { bytes[byteIndex + 2] = UInt8((span >> 16) & 0xFF) }
        }
        return Data(bytes)
    }

    private static func bucket(_ src: [Float], into n: Int) -> [Float] {
        guard src.count > n else {
            return src + Array(repeating: 0, count: max(0, n - src.count))
        }
        var out = [Float](); out.reserveCapacity(n)
        let size = Double(src.count) / Double(n)
        for i in 0..<n {
            let start = Int(Double(i) * size)
            let end = min(src.count, Int(Double(i + 1) * size))
            let slice = src[start..<max(start + 1, end)]
            out.append(slice.max() ?? 0)
        }
        return out
    }
}
