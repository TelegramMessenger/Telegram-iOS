import SwiftUI

/// Voice-memo-style editor waveform: a faint full-width baseline + top tick ruler, white
/// amplitude bars drawn at a fixed pitch from the left, and a blue vertical scrubber (line +
/// end dots) anchored to the right edge of the bars. Pure — driven entirely by inputs.
///
/// `progress == nil` is the recording state (scrubber rides the live edge of the accumulating
/// bars). A non-nil `progress` (0...1) is the review state: the scrubber rests at the bars' end
/// and tracks playback once it starts.
struct VoiceEditorWaveform: View {
    let samples: [Float]
    let progress: Double?

    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 1
    private let tickSpacing: CGFloat = 14

    var body: some View {
        Canvas { ctx, size in
            let pitch = barWidth + barSpacing
            let capacity = max(1, Int(size.width / pitch))
            let shown = samples.count > capacity ? Array(samples.suffix(capacity)) : samples
            let midY = size.height / 2

            var base = Path()
            base.move(to: CGPoint(x: 0, y: midY)); base.addLine(to: CGPoint(x: size.width, y: midY))
            ctx.stroke(base, with: .color(.white.opacity(0.4)), lineWidth: 1)

            var ticks = Path()
            var tx: CGFloat = 0
            while tx <= size.width {
                ticks.move(to: CGPoint(x: tx, y: 0)); ticks.addLine(to: CGPoint(x: tx, y: 6)); tx += tickSpacing
            }
            ctx.stroke(ticks, with: .color(.white.opacity(0.4)), lineWidth: 1)

            for (i, amp) in shown.enumerated() {
                let h = max(2, CGFloat(min(1, max(0, amp))) * size.height)
                let bx = CGFloat(i) * pitch
                ctx.fill(Path(roundedRect: CGRect(x: bx, y: midY - h / 2, width: barWidth, height: h),
                              cornerRadius: barWidth / 2), with: .color(.white))
            }

            let endX = min(size.width, CGFloat(shown.count) * pitch)
            let scrubX: CGFloat
            if let p = progress {
                scrubX = (p > 0 ? CGFloat(min(1, p)) : 1) * endX
            } else {
                scrubX = endX
            }
            var line = Path()
            line.move(to: CGPoint(x: scrubX, y: 0)); line.addLine(to: CGPoint(x: scrubX, y: size.height))
            ctx.stroke(line, with: .color(.accentColor), lineWidth: 2)
            let r: CGFloat = 3
            ctx.fill(Path(ellipseIn: CGRect(x: scrubX - r, y: 0, width: 2 * r, height: 2 * r)), with: .color(.accentColor))
            ctx.fill(Path(ellipseIn: CGRect(x: scrubX - r, y: size.height - 2 * r, width: 2 * r, height: 2 * r)), with: .color(.accentColor))
        }
        .frame(height: 70)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Recording") {
    VoiceEditorWaveform(
        samples: (0..<30).map { Float(0.3 + 0.6 * abs(sin(Double($0) * 0.4))) },
        progress: nil
    )
    .frame(width: 180)
    .padding()
    .background(Color.black)
    .environment(\.colorScheme, .dark)
}

#Preview("Review — mid playback") {
    VoiceEditorWaveform(
        samples: (0..<30).map { Float(0.2 + 0.7 * abs(cos(Double($0) * 0.3))) },
        progress: 0.4
    )
    .frame(width: 180)
    .padding()
    .background(Color.black)
    .environment(\.colorScheme, .dark)
}
#endif
