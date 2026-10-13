import Foundation
import UIKit
import Display
import LiquidGlassShapes

/// The call status bar's waves: three morphing waves filled with the call state gradient, following the WaveLab
/// prototype and drawn by `LiquidGlassShapesLayer` (liquid glass on iOS 26 and later). This layer only moves them:
/// it times their shapes and smooths the audio level.
final class CallStatusBarWavesLayer: SimpleLayer {
    /// Space below the bar that the layer extends into. The crests rest on the bar's bottom edge. The random points
    /// reach a quarter of the randomness (in amplitudes) below it, the curve through them overshoots them by up to
    /// about a quarter more (10.7 pt at most for the deepest wave, over 200k random shapes), the wave sinks by its
    /// level travel, and its shadow and rim reach a little further.
    static let bottomOverflow: CGFloat = {
        let maxRandomness = CallStatusBarWavesLayer.waveMotions.map(\.maxRandomness).max() ?? 0.0
        let maxOffset = CallStatusBarWavesLayer.waveMotions.map(\.maxOffset).max() ?? 0.0
        let appearance = CallStatusBarWavesAppearance.appearance
        let deepestCrest = Constants.amplitude * maxRandomness * 0.25 * 1.3 + Constants.travel * maxOffset
        let shadowReach = CGFloat(appearance.shadowDrop + 3.0 * appearance.shadowBlur)
        return ceil(deepestCrest + shadowReach + CGFloat(appearance.rimWidth) * 0.5)
    }()

    private enum Constants {
        static let smoothness: CGFloat = 0.5
        static let amplitude: CGFloat = 20.0
        /// How far the lower waves sink at the full audio level.
        static let travel: CGFloat = 16.0
        /// Per-frame smoothing of the audio level at 60 fps.
        static let levelSmoothing: CGFloat = 0.93
        static let maxLevel: CGFloat = 1.5
        static let speedMultiplier: CGFloat = 0.85
    }

    private struct WaveMotion {
        var minRandomness: CGFloat
        var maxRandomness: CGFloat
        var minSpeed: CGFloat
        var maxSpeed: CGFloat
        var minOffset: CGFloat
        var maxOffset: CGFloat
    }

    /// Bottom to top.
    private static let waveMotions: [WaveMotion] = [
        WaveMotion(minRandomness: 1.2, maxRandomness: 1.7, minSpeed: 1.0, maxSpeed: 5.8, minOffset: 0.1, maxOffset: 1.0),
        WaveMotion(minRandomness: 1.2, maxRandomness: 1.5, minSpeed: 1.0, maxSpeed: 4.4, minOffset: 0.1, maxOffset: 0.55),
        WaveMotion(minRandomness: 1.0, maxRandomness: 1.3, minSpeed: 0.9, maxSpeed: 3.2, minOffset: 0.0, maxOffset: 0.0)
    ]

    /// One morphing wave: when its crest should be where. The crest itself is built on the GPU from these points.
    private final class Wave {
        let motion: WaveMotion

        /// Normalized: x in 0...1 across the bar, y in units of the wave amplitude.
        private var fromPoints: [CGPoint]
        private var toPoints: [CGPoint]
        private var elapsed: CGFloat = 0.0
        private var duration: CGFloat = 1.0
        private var speedLevel: CGFloat = 0.0

        init(motion: WaveMotion) {
            self.motion = motion
            self.fromPoints = []
            self.toPoints = []

            self.fromPoints = self.generatePoints()
            self.startNextShape()
        }

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

        func crestShape(level: CGFloat) -> LiquidGlassCrestShape {
            func crestPoints(_ points: [CGPoint]) -> LiquidGlassCrestPoints {
                func point(_ index: Int) -> SIMD2<Float> {
                    return SIMD2<Float>(Float(points[index].x), Float(points[index].y))
                }
                return (point(0), point(1), point(2), point(3), point(4), point(5))
            }

            // easeInEaseOut, as the shape layer animation this replaced.
            let progress = bezierPoint(0.42, 0.0, 0.58, 1.0, max(0.0, min(1.0, self.elapsed / self.duration)))
            var offset: CGFloat = 0.0
            if self.motion.minOffset > 0.0 {
                offset = (self.motion.minOffset + (self.motion.maxOffset - self.motion.minOffset) * level) * Constants.travel
            }
            return LiquidGlassCrestShape(fromPoints: crestPoints(self.fromPoints), toPoints: crestPoints(self.toPoints), progress: Float(progress), offset: Float(offset))
        }

        private func startNextShape() {
            self.toPoints = self.generatePoints()
            let speed = (self.motion.minSpeed + (self.motion.maxSpeed - self.motion.minSpeed) * self.speedLevel) * Constants.speedMultiplier
            self.duration = 1.0 / max(speed, 0.05)
            self.speedLevel = 0.0
        }

        private func generatePoints() -> [CGPoint] {
            let randomness = self.motion.minRandomness + (self.motion.maxRandomness - self.motion.minRandomness) * self.speedLevel
            let count = LiquidGlassShapesConstants.crestPointCount
            let segment = 1.0 / CGFloat(count - 1)
            let rangeStart: CGFloat = 1.0 / (1.0 + randomness / 10.0)

            return (0 ..< count).map { index -> CGPoint in
                if index == 0 {
                    return CGPoint(x: 0.0, y: 0.0)
                } else if index == count - 1 {
                    return CGPoint(x: 1.0, y: 0.0)
                }
                let randomPointOffset = (rangeStart + CGFloat.random(in: 0.0 ..< 1.0) * (1.0 - rangeStart)) / 2.0
                let x = segment * CGFloat(index) + segment - segment * randomPointOffset
                let y = (randomness * CGFloat.random(in: 0.0 ..< 1.0) - randomness * 0.5) * randomPointOffset
                return CGPoint(x: x, y: y)
            }
        }
    }

    /// Nothing animates or renders while the bar is out of the window.
    var isInWindow: Bool {
        get {
            return self.shapesLayer.isInWindow
        } set {
            self.shapesLayer.isInWindow = newValue
        }
    }

    /// A still bar without waves, for when animations are disabled to save energy.
    var isFlat: Bool {
        get {
            return self.shapesLayer.isFlat
        } set {
            self.shapesLayer.isFlat = newValue
        }
    }

    var isDarkAppearance: Bool {
        get {
            return self.shapesLayer.isDarkAppearance
        } set {
            self.shapesLayer.isDarkAppearance = newValue
        }
    }

    private let shapesLayer: LiquidGlassShapesLayer
    private let waves: [Wave]
    private var audioLevel: CGFloat = 0.0
    private var presentationAudioLevel: CGFloat = 0.0
    private var barHeight: CGFloat = 0.0

    init(colors: (UIColor, UIColor)) {
        self.shapesLayer = LiquidGlassShapesLayer(colors: colors)
        self.waves = CallStatusBarWavesLayer.waveMotions.map(Wave.init(motion:))

        super.init()

        prewarmLiquidGlassShapes([.crest])

        self.isOpaque = false
        // The crests run across the bar, so the map and the mask only need the screen scale vertically.
        self.shapesLayer.glassMapScale = CGSize(width: 1.0, height: UIScreenScale)
        self.shapesLayer.source = self
        self.shapesLayer.isAnimating = true
        self.addSublayer(self.shapesLayer)
    }

    override init(layer: Any) {
        guard let layer = layer as? CallStatusBarWavesLayer else {
            preconditionFailure()
        }
        self.shapesLayer = layer.shapesLayer
        self.waves = layer.waves

        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lays the waves out for a bar of `barHeight`: their crests rest on its bottom edge. The layer itself is
    /// `bottomOverflow` taller than the bar.
    func update(barHeight: CGFloat) {
        self.barHeight = barHeight
        self.shapesLayer.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        // The gradient runs over twice the bar width, as a CAGradientLayer ending at x = 2 would.
        self.shapesLayer.gradientLength = self.bounds.width * 2.0
        self.shapesLayer.updateLayout()
    }

    func updateAudioLevel(_ level: CGFloat) {
        let normalizedLevel = min(1.0, max(level / Constants.maxLevel, 0.0))
        for wave in self.waves {
            wave.updateSpeedLevel(normalizedLevel)
        }
        self.audioLevel = normalizedLevel
    }

    func updateColors(_ colors: (UIColor, UIColor), animated: Bool) {
        self.shapesLayer.updateColors(colors, animated: animated)
    }
}

extension CallStatusBarWavesLayer: LiquidGlassShapesSource {
    func liquidGlassShapesAdvance(by deltaTime: CGFloat) {
        let smoothing = pow(Constants.levelSmoothing, deltaTime * 60.0)
        self.presentationAudioLevel = self.presentationAudioLevel * smoothing + self.audioLevel * (1.0 - smoothing)
        for wave in self.waves {
            wave.advance(by: deltaTime)
        }
    }

    func liquidGlassShapes(size: CGSize, isFlat: Bool) -> LiquidGlassShapeSet? {
        if self.barHeight <= 0.0 {
            return nil
        }
        var parameters = LiquidGlassCrestParameters(
            shapes: (.flat, .flat, .flat),
            width: Float(size.width),
            restY: Float(self.barHeight),
            amplitude: Float(Constants.amplitude),
            smoothness: Float(Constants.smoothness)
        )
        if !isFlat {
            parameters.shapes = (
                self.waves[0].crestShape(level: self.presentationAudioLevel),
                self.waves[1].crestShape(level: self.presentationAudioLevel),
                self.waves[2].crestShape(level: self.presentationAudioLevel)
            )
        }
        return .crest(parameters)
    }

    func liquidGlassAppearance(mode: LiquidGlassRenderMode, isDarkAppearance: Bool) -> LiquidGlassAppearance {
        return CallStatusBarWavesAppearance.appearance
    }
}
