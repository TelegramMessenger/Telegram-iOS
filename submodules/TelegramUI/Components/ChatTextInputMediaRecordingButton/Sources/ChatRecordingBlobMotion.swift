import Foundation
import LiquidGlassShapes

/// The recording blob's look and motion, kept free of UIKit.
enum ChatRecordingBlobAppearance {
    static let maxLevel: CGFloat = 4.0
    /// Per-frame smoothing of the microphone level at 60 fps.
    static let levelSmoothing: CGFloat = 0.9
    static let centreScale: Float = 0.45
    /// The outer blobs' size when not recording, relative to their level size; they grow from it when recording starts.
    static let restingPresence: CGFloat = 0.75
    static let presenceInDuration: Double = 0.35
    static let presenceOutDuration: Double = 0.15
    /// Handle length of the closed curve through 8 points: the standard cubic circle approximation.
    static let smoothness: Float = {
        let angle = 2.0 * Double.pi / Double(LiquidGlassShapesConstants.radialPointCount)
        return Float(((4.0 / 3.0) * tan(angle / 4.0)) / sin(angle / 2.0) / 2.0)
    }()

    static let goldenRatio: CGFloat = (1.0 + sqrt(5.0)) / 2.0
    /// The outer wave's scale, of the view, from silence to full level. Silent, it is VoiceBlobView's 0.57, 1.1 times
    /// larger. At full level it is the centre circle times φ², so that with the middle wave at the geometric mean the
    /// three circles grow by φ each; it then reaches past the view.
    static let outerWaveScales: ClosedRange<CGFloat> = (0.57 * 1.1) ... (CGFloat(centreScale) * goldenRatio * goldenRatio)
    /// Both waves morph alike; only their sizes differ.
    static let waveMotion = ChatRecordingBlobMotion.Parameters(minRandomness: 1.0, maxRandomness: 1.0, minSpeed: 0.9, maxSpeed: 4.0)

    static func appearance(mode: LiquidGlassRenderMode, isDarkAppearance: Bool) -> LiquidGlassAppearance {
        return LiquidGlassAppearance(
            layers: [
                LiquidGlassLayerStyle(alpha: 0.35, fill: 0.5, saturation: 0.0, matte: 0.0, rim: 0.3, refracts: true, plainAlpha: 0.15),
                LiquidGlassLayerStyle(alpha: 0.55, fill: 0.5, saturation: 0.0, matte: 0.0, rim: 0.3, refracts: true, plainAlpha: 0.30),
                // The centre is the button: a strong matte keeps it close to the solid color, letting through only
                // 1 - matte of what is behind it. Dark themes get the stronger matte: there the multiplied color would
                // otherwise darken the centre.
                LiquidGlassLayerStyle(alpha: 1.0, fill: 0.0, saturation: 1.0, matte: isDarkAppearance ? 0.82 : 0.685, rim: 0.3, refracts: true, plainAlpha: 1.0)
            ],
            shadowStrength: mode == .glass ? 0.07 : 0.0,
            shadowBlur: 6.0,
            shadowDrop: 2.0,
            rimWidth: 1.0,
            rimDarkAppearanceScale: 0.45,
            glassBand: 20.0,
            glassShift: 10.0
        )
    }

    /// The three shapes: the outer and middle blobs (circles when nil, as in the flat style) and the centre circle.
    static func radialParameters(outer: ChatRecordingBlobMotion?, middle: ChatRecordingBlobMotion?, size: Float, level: CGFloat, presence: CGFloat, easing: (CGFloat) -> CGFloat) -> LiquidGlassRadialParameters {
        let centre = LiquidGlassRadialShape.circle(scale: ChatRecordingBlobAppearance.centreScale)
        let scales = ChatRecordingBlobAppearance.outerWaveScales
        let outerScale = (scales.lowerBound + (scales.upperBound - scales.lowerBound) * level) * presence
        // The middle wave is the geometric mean of the centre circle and the outer wave: the three circles grow by one
        // ratio, which reads as an evenly expanding ripple (φ at full level).
        let middleScale = sqrt(CGFloat(ChatRecordingBlobAppearance.centreScale) * outerScale)
        return LiquidGlassRadialParameters(
            shapes: (
                outer?.radialShape(scale: outerScale, easing: easing) ?? centre,
                middle?.radialShape(scale: middleScale, easing: easing) ?? centre,
                centre
            ),
            size: size,
            smoothness: ChatRecordingBlobAppearance.smoothness
        )
    }
}

/// One morphing outline: 8 points around the centre, morphing to a new random shape whenever the last morph ends,
/// faster and wider the louder the microphone was meanwhile. As VoiceBlobView did, so the blob moves as before.
final class ChatRecordingBlobMotion {
    struct Parameters {
        var minRandomness: CGFloat
        var maxRandomness: CGFloat
        var minSpeed: CGFloat
        var maxSpeed: CGFloat
    }

    let parameters: Parameters
    private let random: () -> CGFloat

    /// Normalized, relative to the centre: 0.5 reaches the view's edge.
    private(set) var fromPoints: [SIMD2<Float>] = []
    private(set) var toPoints: [SIMD2<Float>] = []
    private(set) var duration: CGFloat = 1.0
    private var elapsed: CGFloat = 0.0
    private var speedLevel: CGFloat = 0.0

    init(parameters: Parameters, random: @escaping () -> CGFloat = { CGFloat.random(in: 0.0 ..< 1.0) }) {
        self.parameters = parameters
        self.random = random

        self.fromPoints = self.generatePoints()
        self.startNextShape()
    }

    /// The loudest normalized level since the current shape started decides the next one's speed and randomness.
    func updateSpeedLevel(_ level: CGFloat) {
        self.speedLevel = max(self.speedLevel, level)
    }

    func advance(by deltaTime: CGFloat) {
        self.elapsed += deltaTime
        while self.elapsed >= self.duration {
            self.elapsed -= self.duration
            self.fromPoints = self.toPoints
            self.startNextShape()
        }
    }

    /// The current outline at `scale` of the view.
    func radialShape(scale: CGFloat, easing: (CGFloat) -> CGFloat) -> LiquidGlassRadialShape {
        func radialPoints(_ points: [SIMD2<Float>]) -> LiquidGlassRadialPoints {
            return (points[0], points[1], points[2], points[3], points[4], points[5], points[6], points[7])
        }
        let progress = easing(max(0.0, min(1.0, self.elapsed / self.duration)))
        return LiquidGlassRadialShape(fromPoints: radialPoints(self.fromPoints), toPoints: radialPoints(self.toPoints), progress: Float(progress), scale: Float(scale))
    }

    private func startNextShape() {
        self.toPoints = self.generatePoints()
        let speed = self.parameters.minSpeed + (self.parameters.maxSpeed - self.parameters.minSpeed) * self.speedLevel
        self.duration = 1.0 / max(speed, 0.05)
        self.speedLevel = 0.0
    }

    private func generatePoints() -> [SIMD2<Float>] {
        let randomness = self.parameters.minRandomness + (self.parameters.maxRandomness - self.parameters.minRandomness) * self.speedLevel
        let count = LiquidGlassShapesConstants.radialPointCount
        let angle = 2.0 * CGFloat.pi / CGFloat(count)
        let rangeStart = 1.0 / (1.0 + randomness / 10.0)
        let startAngle = angle * self.random()
        return (0 ..< count).map { index -> SIMD2<Float> in
            let radius = (rangeStart + self.random() * (1.0 - rangeStart)) / 2.0
            let angleRandomness = angle * 0.1
            let pointAngle = angle + angle * (angleRandomness * self.random() - angleRandomness * 0.5)
            let pointAngleFromStart = startAngle + CGFloat(index) * pointAngle
            return SIMD2<Float>(Float(sin(pointAngleFromStart) * radius), Float(cos(pointAngleFromStart) * radius))
        }
    }
}

/// How grown the outer blobs are: 0.75 at rest, easing to 1 when recording starts and back when it stops, always
/// from wherever it is, so a quick stop does not jump.
struct ChatRecordingBlobPresence {
    private(set) var value: CGFloat
    private var from: CGFloat
    private var target: CGFloat
    private var elapsed: Double = 0.0
    private var duration: Double = 0.0
    private let easing: (CGFloat) -> CGFloat

    init(value: CGFloat, easing: @escaping (CGFloat) -> CGFloat) {
        self.value = value
        self.from = value
        self.target = value
        self.easing = easing
    }

    var isSettled: Bool {
        return self.elapsed >= self.duration
    }

    /// `canAdvance` is false when nothing will advance the animation (the view is out of its window): it then lands at
    /// `target` at once.
    mutating func animate(to target: CGFloat, duration: Double, canAdvance: Bool = true) {
        if !canAdvance {
            self.settle(at: target)
            return
        }
        self.from = self.value
        self.target = target
        self.elapsed = 0.0
        self.duration = duration
    }

    /// Jumps to `value` and stops.
    mutating func settle(at value: CGFloat) {
        self.value = value
        self.from = value
        self.target = value
        self.elapsed = 0.0
        self.duration = 0.0
    }

    mutating func advance(by deltaTime: Double) {
        if self.isSettled {
            return
        }
        self.elapsed = min(self.duration, self.elapsed + deltaTime)
        self.value = self.from + (self.target - self.from) * self.easing(CGFloat(self.elapsed / self.duration))
    }
}
