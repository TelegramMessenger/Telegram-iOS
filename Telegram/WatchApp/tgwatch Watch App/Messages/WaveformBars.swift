import Foundation
import SwiftUI

/// Unpacks Telegram's 5-bit packed waveform format into amplitudes in [0, 1].
/// Each input byte contributes 8 bits of an LSB-first bit stream; every 5 bits
/// form one 0…31 amplitude. Trailing bits that don't form a complete sample
/// are dropped. An empty `Data` returns an empty array.
func unpackWaveform(_ data: Data) -> [Float] {
    guard !data.isEmpty else { return [] }
    let totalBits = data.count * 8
    let sampleCount = totalBits / 5
    guard sampleCount > 0 else { return [] }

    var out: [Float] = []
    out.reserveCapacity(sampleCount)

    for i in 0..<sampleCount {
        let bitStart = i * 5
        let byteIndex = bitStart / 8
        let bitOffset = bitStart % 8

        // Read up to 24 bits starting at byteIndex; we only ever need 12 of them
        // (5-bit sample + up to 7-bit offset), but loading the trailing byte
        // avoids a hot-path branch on the most common path.
        var raw: UInt32 = UInt32(data[data.startIndex + byteIndex])
        if byteIndex + 1 < data.count {
            raw |= UInt32(data[data.startIndex + byteIndex + 1]) << 8
        }
        if byteIndex + 2 < data.count {
            raw |= UInt32(data[data.startIndex + byteIndex + 2]) << 16
        }
        let value = (raw >> UInt32(bitOffset)) & 0x1F   // 5-bit mask
        out.append(Float(value) / 31.0)
    }
    return out
}

/// 32-bar waveform rendered via `Canvas`. Bars at indices below
/// `progress * 32` use the foreground tint; the rest are dimmed.
/// When `amplitudes` is empty, draws a thin progress bar instead.
struct WaveformBarsView: View {
    let amplitudes: [Float]
    let progress: Double
    let isOutgoing: Bool

    private let barCount = 32
    private let barSpacing: CGFloat = 1

    private var foregroundTint: Color { isOutgoing ? .white : .accentColor }
    private var dimTint: Color { isOutgoing ? .white.opacity(0.35) : .accentColor.opacity(0.3) }

    var body: some View {
        GeometryReader { geo in
            if amplitudes.isEmpty {
                emptyProgress(in: geo.size)
            } else {
                Canvas { ctx, size in
                    let totalSpacing = barSpacing * CGFloat(barCount - 1)
                    let barWidth = max(1, (size.width - totalSpacing) / CGFloat(barCount))
                    let midY = size.height / 2
                    let downsampled = downsample(amplitudes, to: barCount)
                    let playedBars = Int((Double(barCount) * progress).rounded(.down))
                    for i in 0..<barCount {
                        let amp = max(0.1, CGFloat(downsampled[i]))
                        let h = max(2, amp * size.height)
                        let x = CGFloat(i) * (barWidth + barSpacing)
                        let rect = CGRect(x: x, y: midY - h/2, width: barWidth, height: h)
                        let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                        ctx.fill(path, with: .color(i < playedBars ? foregroundTint : dimTint))
                    }
                }
            }
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func emptyProgress(in size: CGSize) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(dimTint).frame(height: 2)
            Capsule()
                .fill(foregroundTint)
                .frame(width: size.width * progress, height: 2)
        }
        .frame(height: 18)
    }

    private func downsample(_ src: [Float], to n: Int) -> [Float] {
        guard src.count != n else { return src }
        if src.count < n {
            return src + Array(repeating: 0, count: n - src.count)
        }
        var out: [Float] = []
        out.reserveCapacity(n)
        let bucketSize = Double(src.count) / Double(n)
        for i in 0..<n {
            let start = Int(Double(i) * bucketSize)
            let end = min(src.count, Int(Double(i + 1) * bucketSize))
            let slice = src[start..<max(start + 1, end)]
            out.append(slice.max() ?? 0)
        }
        return out
    }
}

#if DEBUG
#Preview("Waveform — incoming, 40%") {
    WaveformBarsView(
        amplitudes: (0..<60).map { i in
            Float(0.3 + 0.6 * abs(sin(Double(i) * 0.3)))
        },
        progress: 0.4,
        isOutgoing: false
    )
    .frame(width: 140)
    .padding()
}

#Preview("Waveform — outgoing, 80%") {
    WaveformBarsView(
        amplitudes: (0..<60).map { i in
            Float(0.2 + 0.7 * abs(cos(Double(i) * 0.5)))
        },
        progress: 0.8,
        isOutgoing: true
    )
    .frame(width: 140)
    .padding()
    .background(Color.accentColor)
}

#Preview("Waveform — empty data, 50%") {
    WaveformBarsView(amplitudes: [], progress: 0.5, isOutgoing: false)
        .frame(width: 140)
        .padding()
}
#endif
