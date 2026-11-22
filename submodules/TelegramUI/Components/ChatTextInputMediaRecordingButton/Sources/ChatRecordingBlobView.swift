import Foundation
import UIKit
import Display
import ComponentFlow
import LegacyComponents
import LiquidGlassShapes

/// The blob around the chat input's microphone button while recording a voice or video message: two outlines that
/// morph and swell with the microphone level around a static centre circle, drawn by `LiquidGlassShapesLayer` as
/// liquid glass on iOS 26 and later. The Objective-C mic button positions and transforms the view and adds the icon
/// on top of it.
final class ChatRecordingBlobView: UIView, TGModernConversationInputMicButtonDecoration {
    /// How far the shapes reach past a view of `side`: the outer blob grows up to its largest scale and its outline
    /// overshoots its points by under 5% (measured when the radial kernel was written), and the shadow and the rims
    /// reach past it.
    private static func overflow(side: CGFloat) -> CGFloat {
        let appearance = ChatRecordingBlobAppearance.appearance(mode: .glass, isDarkAppearance: false)
        let outlineReach = side * 0.5 * ChatRecordingBlobAppearance.outerWaveScales.upperBound * 1.05
        return ceil(max(0.0, outlineReach - side * 0.5) + CGFloat(appearance.shadowDrop + 3.0 * appearance.shadowBlur + appearance.rimWidth * 0.5))
    }

    /// Taps register only in a centred square of this side, as with the previous blob.
    var hitTestSize: CGFloat?

    /// Only the centre circle, still, for when animations are disabled to save energy.
    var isFlat: Bool {
        get {
            return self.shapesLayer.isFlat
        } set {
            self.shapesLayer.isFlat = newValue
        }
    }

    var isDarkAppearance: Bool = false {
        didSet {
            self.shapesLayer.isDarkAppearance = self.isDarkAppearance
        }
    }

    private let shapesLayer: LiquidGlassShapesLayer
    private let outerBlob: ChatRecordingBlobMotion
    private let middleBlob: ChatRecordingBlobMotion
    private var presence: ChatRecordingBlobPresence
    private var audioLevel: CGFloat = 0.0
    private var presentationAudioLevel: CGFloat = 0.0
    private var isRecording = false

    override init(frame: CGRect) {
        self.shapesLayer = LiquidGlassShapesLayer(colors: (.white, .white))
        self.outerBlob = ChatRecordingBlobMotion(parameters: ChatRecordingBlobAppearance.waveMotion)
        self.middleBlob = ChatRecordingBlobMotion(parameters: ChatRecordingBlobAppearance.waveMotion)
        self.presence = ChatRecordingBlobPresence(value: ChatRecordingBlobAppearance.restingPresence, easing: { bezierPoint(0.42, 0.0, 0.58, 1.0, $0) })

        super.init(frame: frame)

        prewarmLiquidGlassShapes([.radial])

        self.isOpaque = false
        self.shapesLayer.source = self
        // The view is kept for as long as its chat is open, but shown only while recording.
        self.shapesLayer.releasesSurfacesWhenHidden = true
        self.layer.addSublayer(self.shapesLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLevel(_ level: CGFloat) {
        let normalizedLevel = min(1.0, max(level / ChatRecordingBlobAppearance.maxLevel, 0.0))
        self.outerBlob.updateSpeedLevel(normalizedLevel)
        self.middleBlob.updateSpeedLevel(normalizedLevel)
        self.audioLevel = normalizedLevel
    }

    func setColor(_ color: UIColor) {
        self.shapesLayer.updateColors((color, color), animated: true)
    }

    func startAnimating() {
        if self.isRecording {
            return
        }
        self.isRecording = true
        self.presence.animate(to: 1.0, duration: ChatRecordingBlobAppearance.presenceInDuration)
        self.shapesLayer.isAnimating = true
    }

    func stopAnimating() {
        if !self.isRecording {
            return
        }
        self.isRecording = false
        // The display link keeps running until the blobs have shrunk, then the last frame stays. Out of the window
        // there is no display link to finish the shrink, so the next recording would start part-grown: land at once.
        let canAdvance = self.window != nil
        self.presence.animate(to: ChatRecordingBlobAppearance.restingPresence, duration: ChatRecordingBlobAppearance.presenceOutDuration, canAdvance: canAdvance)
        if !canAdvance {
            self.shapesLayer.isAnimating = false
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if self.window == nil && !self.isRecording {
            // Out of the window the display link stops, so a shrink still running would otherwise leave the next
            // recording (which reuses this view) starting part-grown.
            self.presence.settle(at: ChatRecordingBlobAppearance.restingPresence)
            self.shapesLayer.isAnimating = false
        }
        self.shapesLayer.isInWindow = self.window != nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let overflow = ChatRecordingBlobView.overflow(side: self.bounds.width)
        let shapesFrame = self.bounds.insetBy(dx: -overflow, dy: -overflow)
        if self.shapesLayer.frame != shapesFrame {
            self.shapesLayer.frame = shapesFrame
            self.shapesLayer.updateLayout()
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let hitTestSize = self.hitTestSize {
            if !CGSize(width: hitTestSize, height: hitTestSize).centered(in: self.bounds).contains(point) {
                return nil
            }
        }
        return super.hitTest(point, with: event)
    }
}

extension ChatRecordingBlobView: LiquidGlassShapesSource {
    func liquidGlassShapesAdvance(by deltaTime: CGFloat) {
        let smoothing = pow(ChatRecordingBlobAppearance.levelSmoothing, deltaTime * 60.0)
        self.presentationAudioLevel = self.presentationAudioLevel * smoothing + self.audioLevel * (1.0 - smoothing)
        self.outerBlob.advance(by: deltaTime)
        self.middleBlob.advance(by: deltaTime)
        self.presence.advance(by: Double(deltaTime))
        if !self.isRecording && self.presence.isSettled {
            self.shapesLayer.isAnimating = false
        }
    }

    func liquidGlassShapes(size: CGSize, isFlat: Bool) -> LiquidGlassShapeSet? {
        if self.bounds.width <= 0.0 {
            return nil
        }
        let parameters = ChatRecordingBlobAppearance.radialParameters(
            outer: isFlat ? nil : self.outerBlob,
            middle: isFlat ? nil : self.middleBlob,
            size: Float(self.bounds.width),
            level: self.presentationAudioLevel,
            presence: self.presence.value,
            easing: { bezierPoint(0.42, 0.0, 0.58, 1.0, $0) }
        )
        return .radial(parameters, center: SIMD2<Float>(Float(size.width * 0.5), Float(size.height * 0.5)))
    }

    func liquidGlassAppearance(mode: LiquidGlassRenderMode, isDarkAppearance: Bool) -> LiquidGlassAppearance {
        return ChatRecordingBlobAppearance.appearance(mode: mode, isDarkAppearance: isDarkAppearance)
    }
}
