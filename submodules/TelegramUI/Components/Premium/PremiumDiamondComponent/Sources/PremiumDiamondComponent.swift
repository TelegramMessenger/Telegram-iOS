import UIKit
import Display
import ComponentFlow
import Metal
import MetalEngine
import SwiftSignalKit
import TelegramPresentationData

public final class InteractiveDiamondComponent: Component {
    public enum Appearance: UInt32, CaseIterable, Sendable {
        case blue = 0
        case white = 1
        case cool = 2
    }

    public enum ExpansionStyle {
        case centered
        case downward
        case wallet
    }

    public enum AnimationMode: Equatable {
        case continuous
        case idle
        case lottie(loop: Bool)
    }

    public struct MotionState {
        public let rotation: CGFloat
        public let time: CFTimeInterval
        public let transferEnergy: CGFloat?
    }

    public struct RefractionGeometry {
        public var center: CGPoint
        public var hull: [CGPoint]
        public let strength: CGFloat
        public let rotation: Float
    }

    public struct RefractionSource: Equatable {
        let texture: MTLTexture
        let uv: SIMD4<Float>
        let rect: CGRect
        let preservesColors: Bool

        public init(texture: MTLTexture, uv: SIMD4<Float>, rect: CGRect, preservesColors: Bool = false) {
            self.texture = texture
            self.uv = uv
            self.rect = rect
            self.preservesColors = preservesColors
        }

        public static func ==(lhs: RefractionSource, rhs: RefractionSource) -> Bool {
            return lhs.texture === rhs.texture && lhs.uv == rhs.uv && lhs.rect == rhs.rect
                && lhs.preservesColors == rhs.preservesColors
        }
    }

    private let size: CGSize
    private let diamondWidth: CGFloat
    private let isVisible: Bool
    private let theme: PresentationTheme
    private let appearance: Appearance
    private let expansionStyle: ExpansionStyle
    private let expandedCenter: CGPoint?
    private let animationMode: AnimationMode
    private let animateOnAppear: Bool
    private let tapToSpin: Bool

    public init(size: CGSize, diamondWidth: CGFloat, isVisible: Bool, theme: PresentationTheme, appearance: Appearance = .blue, expansionStyle: ExpansionStyle = .centered, expandedCenter: CGPoint? = nil, animationMode: AnimationMode = .continuous, animateOnAppear: Bool = false, tapToSpin: Bool = false) {
        self.size = size
        self.diamondWidth = diamondWidth
        self.isVisible = isVisible
        self.theme = theme
        self.appearance = appearance
        self.expansionStyle = expansionStyle
        self.expandedCenter = expandedCenter
        self.animationMode = animationMode
        self.animateOnAppear = animateOnAppear
        self.tapToSpin = tapToSpin
    }

    public static func ==(lhs: InteractiveDiamondComponent, rhs: InteractiveDiamondComponent) -> Bool {
        return lhs.size == rhs.size && lhs.diamondWidth == rhs.diamondWidth
            && lhs.isVisible == rhs.isVisible && lhs.theme === rhs.theme && lhs.appearance == rhs.appearance
            && lhs.expansionStyle == rhs.expansionStyle
            && lhs.expandedCenter == rhs.expandedCenter
            && lhs.animationMode == rhs.animationMode
            && lhs.animateOnAppear == rhs.animateOnAppear
            && lhs.tapToSpin == rhs.tapToSpin
    }

    public final class View: UIView, UIGestureRecognizerDelegate {
        private struct Expansion {
            let start: CFTimeInterval
            let from: CGFloat
            let holding: Bool
        }

        private let diamondLayer = InteractiveDiamondLayer(backgroundStars: false)
        public let pressGesture = UILongPressGestureRecognizer()
        private let pinchGesture = UIPinchGestureRecognizer()
        private var initialZoom: Float?
        private var isHolding = false
        public private(set) var isExpanded = false
        public var onExpansionChanged: ((Bool) -> Void)?
        public var onLanding: ((CGFloat) -> Void)?
        public var onMotionUpdated: ((MotionState?) -> Void)?
        public var onRefractionUpdated: ((RefractionGeometry?) -> Void)? {
            didSet {
                if self.onRefractionUpdated == nil {
                    self.diamondLayer.onRefractionUpdated = nil
                } else {
                    self.diamondLayer.onRefractionUpdated = { [weak self] geometry in
                        guard let self else { return }
                        let origin = self.diamondLayer.position
                        self.onRefractionUpdated?(geometry.map { geometry in
                            var result = geometry
                            result.center = CGPoint(x: geometry.center.x + origin.x, y: geometry.center.y + origin.y)
                            result.hull = geometry.hull.map { CGPoint(x: $0.x + origin.x, y: $0.y + origin.y) }
                            return result
                        })
                    }
                }
            }
        }
        public var scrollTiltProvider: ((CFTimeInterval) -> Float)? {
            get { return self.diamondLayer.scrollTiltProvider }
            set { self.diamondLayer.scrollTiltProvider = newValue }
        }
        /// Runs on the stone's display link. A nil time suspends the external motion.
        /// The rotation is additive and does not restart the authored animation.
        public var externalMotion: ((CFTimeInterval?) -> (rotation: Float, isAnimating: Bool))? {
            get { return self.diamondLayer.externalMotion }
            set { self.diamondLayer.externalMotion = newValue }
        }

        public func requestExternalMotionUpdate() {
            self.diamondLayer.requestExternalMotionUpdate()
        }
        private var restingSize = CGSize.zero
        private var diamondWidth: CGFloat = 0.0
        private var walletScale: CGFloat = 1.0
        private var walletLeftInset: CGFloat = .greatestFiniteMagnitude
        private var walletStarCanvasSize = CGSize(width: 240.0, height: 240.0)
        private var expansionStyle: ExpansionStyle = .centered
        private var expandedCenter: CGPoint?
        private var refractionSource: RefractionSource?
        private var animationMode: AnimationMode = .continuous
        private var expansion: Expansion?
        private var grip: CGFloat = 0.0
        private var dragPosition: CGPoint?
        private var pressStart: (position: CGPoint, time: CFTimeInterval)?
        private var dragSamples: [(x: CGFloat, time: CFTimeInterval)] = []
        private var landingFeedback: DispatchWorkItem?
        private var isWalletTransfer = false
        private var openingScale: CGFloat?

        public override var isUserInteractionEnabled: Bool {
            didSet {
                if !self.isUserInteractionEnabled { self.cancelInteraction() }
            }
        }

        public var isRenderingEnabled: Bool {
            get { return self.diamondLayer.isRenderingEnabled }
            set {
                if !newValue { self.cancelInteraction() }
                self.diamondLayer.isRenderingEnabled = newValue
            }
        }

        public var isPlaying: Bool {
            return self.diamondLayer.isPlaying
        }

        public func playOnce() {
            guard self.animationMode == .lottie(loop: false) else { return }
            self.diamondLayer.resetAnimation()
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.accessibilityElementsHidden = true
            self.diamondLayer.isRenderingEnabled = false
            var style = DiamondStyle()
            style.animationMode = .continuous
            style.rotationSpeed = 2 * .pi / 26
            style.swayScale = 1
            style.backgroundStars = false
            style.mainSparkleOnRotation = true
            style.releaseTilt = 2.6
            self.diamondLayer.update(style: style)
            self.layer.addSublayer(self.diamondLayer)
            self.diamondLayer.onHold = { [weak self] holding in
                self?.setHolding(holding)
            }
            self.diamondLayer.onPoseUpdated = { [weak self] pose in
                guard let self else { return }
                if self.expansionStyle != .centered {
                    self.applyExpansion()
                } else {
                    self.updateExpansion(at: CACurrentMediaTime())
                }
                if let onMotionUpdated = self.onMotionUpdated {
                    if let state = self.diamondLayer.animationState {
                        onMotionUpdated(MotionState(
                            rotation: CGFloat(pose.yaw),
                            time: CFTimeInterval(state.time),
                            transferEnergy: state.transferEnergy.map { CGFloat($0) }
                        ))
                    } else {
                        onMotionUpdated(nil)
                    }
                }
            }
            self.pressGesture.minimumPressDuration = 0.0
            self.pressGesture.allowableMovement = .greatestFiniteMagnitude
            self.pressGesture.addTarget(self, action: #selector(self.handlePress(_:)))
            self.addGestureRecognizer(self.pressGesture)
            self.pinchGesture.delegate = self
            self.pinchGesture.addTarget(self, action: #selector(self.handlePinch(_:)))
            self.pinchGesture.isEnabled = false
            self.addGestureRecognizer(self.pinchGesture)
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true
            NotificationCenter.default.addObserver(self, selector: #selector(self.reduceMotionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
            self.reduceMotionChanged()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        deinit {
            self.landingFeedback?.cancel()
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func reduceMotionChanged() {
            self.diamondLayer.setReduceMotion(UIAccessibility.isReduceMotionEnabled)
            if UIAccessibility.isReduceMotionEnabled {
                self.expansion = nil
                self.grip = self.isHolding ? 1.0 : 0.0
                self.diamondLayer.resetGrowth()
                self.applyExpansion()
            }
        }

        @objc private func applicationWillResignActive() {
            self.cancelInteraction()
        }

        public override func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window == nil { self.cancelInteraction() }
        }

        public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            if self.animationMode != .continuous {
                return super.point(inside: point, with: event)
            }
            if self.expansionStyle == .wallet {
                let radius = self.restingSize.width * (30.0 * 0.9 / 96.0) * self.walletScale
                return hypot(point.x - self.diamondLayer.position.x, point.y - self.diamondLayer.position.y) <= radius
            }
            return CGRect(x: self.bounds.midX - 32.0, y: self.bounds.midY - 32.0, width: 64.0, height: 64.0).contains(point)
        }

        @objc private func handlePress(_ gesture: UILongPressGestureRecognizer) {
            let now = CACurrentMediaTime()
            let position = gesture.location(in: self)
            switch gesture.state {
            case .began:
                self.cancelLandingFeedback()
                Haptics.prime()
                self.dragPosition = position
                self.pressStart = (position, now)
                self.dragSamples = [(position.x, now)]
                self.diamondLayer.updateDrag(state: .began)
            case .changed, .ended:
                guard let previous = self.dragPosition else { return }
                let wasHolding = self.isHolding
                let releasePower = CGFloat(self.diamondLayer.refractionStrength)
                let translation = CGPoint(x: position.x - previous.x, y: position.y - previous.y)
                self.dragSamples.append((position.x, now))
                while self.dragSamples.count > 2 && self.dragSamples[0].time < now - 0.08 {
                    self.dragSamples.removeFirst()
                }
                let sample = self.dragSamples[0]
                let interval = CGFloat(max(now - sample.time, 1.0 / 240.0))
                let velocity = CGPoint(x: (position.x - sample.x) / interval, y: 0.0)
                let tapDirection: Float?
                if gesture.state == .ended, self.diamondLayer.diamondStyle.tapToSpin,
                   let pressStart = self.pressStart, now - pressStart.time < 0.25,
                   hypot(position.x - pressStart.position.x, position.y - pressStart.position.y) < 10.0 {
                    let centerX = self.expansionStyle == .wallet ? self.diamondLayer.position.x : self.bounds.midX
                    tapDirection = position.x < centerX ? -1.0 : 1.0
                } else {
                    tapDirection = nil
                }
                self.dragPosition = gesture.state == .ended ? nil : position
                if gesture.state == .ended {
                    self.pressStart = nil
                    self.dragSamples.removeAll(keepingCapacity: true)
                }
                self.diamondLayer.updateDrag(
                    state: gesture.state, translation: translation, velocity: velocity,
                    scale: self.expansionStyle == .wallet ? min(self.restingSize.width, self.restingSize.height) : 220.0,
                    releaseImpulse: self.expansionStyle == .wallet ? nil : 3.0 * 6.5,
                    playFlingHaptic: self.expansionStyle == .wallet,
                    allowsFlingBurst: self.expansionStyle == .wallet, tapSpinDirection: tapDirection
                )
                if self.expansionStyle == .wallet, tapDirection != nil, !UIAccessibility.isReduceMotionEnabled {
                    Haptics.hit(0.4)
                }
                if gesture.state == .ended, wasHolding, self.expansionStyle != .wallet {
                    self.scheduleLandingFeedback(power: releasePower)
                }
            case .cancelled, .failed:
                self.cancelLandingFeedback()
                self.dragPosition = nil
                self.pressStart = nil
                self.dragSamples.removeAll(keepingCapacity: true)
                self.diamondLayer.updateDrag(state: .cancelled)
            default:
                break
            }
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began, .changed:
                if self.initialZoom == nil { self.initialZoom = self.diamondLayer.zoom }
                self.diamondLayer.zoom = (self.initialZoom ?? 1.0) * Float(gesture.scale)
            default:
                self.initialZoom = nil
            }
        }

        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return (gestureRecognizer === self.pinchGesture && otherGestureRecognizer === self.pressGesture)
                || (gestureRecognizer === self.pressGesture && otherGestureRecognizer === self.pinchGesture)
        }

        private func scheduleLandingFeedback(power: CGFloat) {
            self.cancelLandingFeedback()
            guard power > 0.0, (power > 0.2 || self.onLanding != nil), !self.isHolding else { return }
            let impact = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.landingFeedback = nil
                guard self.window != nil, self.isRenderingEnabled, self.isUserInteractionEnabled,
                      !self.isHolding, UIApplication.shared.applicationState == .active else { return }
                if power > 0.2 {
                    Haptics.hit(0.35 + 0.4 * min(1.0, power))
                }
                self.onLanding?(min(1.0, power))
            }
            self.landingFeedback = impact
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: impact)
        }

        private func cancelLandingFeedback() {
            self.landingFeedback?.cancel()
            self.landingFeedback = nil
        }

        private func setHolding(_ holding: Bool) {
            guard self.isHolding != holding else { return }
            let now = CACurrentMediaTime()
            self.updateExpansion(at: now)
            self.isHolding = holding
            if self.expansionStyle != .centered {
                if UIAccessibility.isReduceMotionEnabled {
                    self.diamondLayer.resetGrowth()
                }
                self.applyExpansion()
                return
            }
            if UIAccessibility.isReduceMotionEnabled {
                self.expansion = nil
                self.grip = holding ? 1.0 : 0.0
            } else {
                self.expansion = Expansion(start: now, from: self.grip, holding: holding)
            }
            self.applyExpansion()
        }

        private func updateExpansion(at time: CFTimeInterval) {
            guard let expansion = self.expansion else { return }
            let elapsed = max(0.0, time - expansion.start)
            if expansion.holding {
                let t = min(1.0, elapsed / 0.46)
                let u = t * t * (3.0 - 2.0 * t)
                let settle = 1.0 - exp(-5.6 * u) * (cos(6.2 * u) + 5.6 / 6.2 * sin(6.2 * u))
                self.grip = expansion.from + (1.0 - expansion.from) * CGFloat(settle)
                if t == 1.0 {
                    self.grip = 1.0
                    self.expansion = nil
                }
            } else {
                self.grip = expansion.from * CGFloat(exp(-4.2 * elapsed) * cos(7.0 * elapsed))
                if elapsed >= 1.96 {
                    self.grip = 0.0
                    self.expansion = nil
                }
            }
            self.applyExpansion()
        }

        private func applyExpansion() {
            if self.isWalletTransfer {
                self.diamondLayer.usesHighFrameRate = true
                self.diamondLayer.interactionScale = 1.0
                self.diamondLayer.refractionStrength = 0.0
                self.diamondLayer.position = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
                self.diamondLayer.renderSize = CGSize(width: 150.0, height: 150.0)
                return
            }
            let expanded = self.isHolding || self.expansion != nil || self.diamondLayer.isGrowthAnimating
            self.diamondLayer.usesHighFrameRate = expanded || self.openingScale != nil || self.diamondLayer.hasTransferAnimation
            self.diamondLayer.interactionScale = (self.expansionStyle != .centered ? 1.0 : Float(1.0 + 2.75 * self.grip)) * Float(self.openingScale ?? 1.0)
            let refractionStrength = self.expansionStyle != .centered && self.diamondLayer.diamondStyle.dragGrow != 1.0
                ? (self.diamondLayer.pose.grow - 1.0) / (self.diamondLayer.diamondStyle.dragGrow - 1.0)
                : Float(self.grip)
            self.diamondLayer.refractionStrength = min(1.0, max(0.0, refractionStrength))
            let restingCenter = CGPoint(x: self.restingSize.width * 0.5, y: self.restingSize.height * 0.5)
            let expandedCenter = self.expandedCenter ?? restingCenter
            self.diamondLayer.position = CGPoint(
                x: restingCenter.x + (expandedCenter.x - restingCenter.x) * CGFloat(refractionStrength),
                y: restingCenter.y + (expandedCenter.y - restingCenter.y) * CGFloat(refractionStrength)
            )
            if self.expansionStyle == .wallet {
                let halfWidth = self.diamondWidth * CGFloat(self.diamondLayer.pose.grow * self.diamondLayer.zoom) * self.walletScale * 0.55
                self.diamondLayer.position.x = restingCenter.x + max(0.0, halfWidth - self.walletLeftInset)
            }
            self.diamondLayer.starOffset = self.expansionStyle == .wallet
                ? CGPoint(x: restingCenter.x - self.diamondLayer.position.x, y: restingCenter.y - self.diamondLayer.position.y)
                : .zero
            self.updateRefractionPosition()
            if self.openingScale != nil {
                self.diamondLayer.renderSize = CGSize(width: 320.0, height: 320.0)
            } else if self.diamondLayer.isCompletingTransfer || self.diamondLayer.hasStarBursts {
                self.diamondLayer.renderSize = self.expansionStyle == .wallet
                    ? self.walletStarCanvasSize
                    : CGSize(width: 240.0, height: 240.0)
            } else if expanded {
                self.diamondLayer.renderSize = CGSize(width: 220.0, height: 220.0)
            } else if self.diamondLayer.hasTransferAnimation {
                self.diamondLayer.renderSize = CGSize(width: 96.0, height: 96.0)
            } else {
                self.diamondLayer.renderSize = self.restingSize
            }
            self.diamondLayer.setNeedsUpdate()
            if self.isExpanded != expanded {
                self.isExpanded = expanded
                self.onExpansionChanged?(expanded)
            }
        }

        public func cancelInteraction() {
            if self.pinchGesture.state == .began || self.pinchGesture.state == .changed {
                self.pinchGesture.isEnabled = false
                self.pinchGesture.isEnabled = self.expansionStyle == .wallet
            }
            self.initialZoom = nil
            self.cancelLandingFeedback()
            self.diamondLayer.cancelTapSpin()
            guard self.isHolding || self.expansion != nil || self.dragPosition != nil || self.diamondLayer.isGrowthAnimating else {
                self.applyExpansion()
                return
            }
            if self.pressGesture.state == .began || self.pressGesture.state == .changed {
                self.pressGesture.isEnabled = false
                self.pressGesture.isEnabled = true
            }
            if self.isHolding { self.diamondLayer.updateDrag(state: .cancelled) }
            self.dragPosition = nil
            self.pressStart = nil
            self.dragSamples.removeAll(keepingCapacity: true)
            self.isHolding = false
            self.expansion = nil
            self.grip = 0.0
            self.diamondLayer.resetGrowth()
            self.applyExpansion()
        }

        public func updateWalletTilt(pitch: CGFloat, roll: CGFloat, scale: CGFloat, leftInset: CGFloat, starCanvasSize: CGSize) {
            guard self.expansionStyle == .wallet else { return }
            self.walletScale = scale
            self.walletLeftInset = leftInset
            self.walletStarCanvasSize = CGSize(
                width: max(240.0, ceil(starCanvasSize.width)),
                height: max(240.0, ceil(starCanvasSize.height))
            )
            var style = self.diamondLayer.diamondStyle
            style.tilt = Float(-pitch * 2.8)
            style.lean = Float(roll * 2.6)
            style.widthPoints = Float(self.diamondWidth * scale)
            self.diamondLayer.update(style: style)
            self.applyExpansion()
        }

        /// Wallet screens change the rendered width, keeping one surface for the whole entrance.
        /// This is independent of holding the stone: it does not enable the lens or emit stars.
        public func updateOpeningScale(_ scale: CGFloat?) {
            guard self.openingScale != scale else { return }
            self.openingScale = scale
            self.applyExpansion()
        }

        public func spin(_ velocity: Float, decay: Float) {
            self.diamondLayer.spin(velocity, decay: decay)
        }

        public func prepareForWalletTransfer() {
            self.cancelInteraction()
            self.isWalletTransfer = true
            self.openingScale = nil
            self.isUserInteractionEnabled = false
            self.onExpansionChanged = nil
            self.onLanding = nil
            self.onMotionUpdated = nil
            self.onRefractionUpdated = nil
            self.scrollTiltProvider = nil
            self.externalMotion = nil
            self.updateRefractionSource(nil)
            self.bounds = CGRect(x: 0.0, y: 0.0, width: 150.0, height: 150.0)
            self.applyExpansion()
        }

        public func updateWalletTransfer(width: CGFloat, rotationSpeed: Float, completion: Bool, isDark: Bool, appearance: Appearance = .blue) {
            self.diamondLayer.lightBackground = !isDark
            var style = self.diamondLayer.diamondStyle
            let startsCompletion = completion && !style.backgroundStars
            style.animationMode = .continuous
            style.appearance = appearance
            style.widthPoints = Float(width)
            style.rotationSpeed = rotationSpeed
            style.swayScale = 2.4
            style.floatAmplitude = 0.0
            style.backgroundStars = completion
            style.steadyStars = false
            style.starZoom = 0.55
            style.starEmission = 0.3
            style.burstSize = 0.7
            style.burstFadeInDuration = 0.0
            self.diamondLayer.update(style: style, preservingMotion: true)
            if startsCompletion {
                self.spin(12.0, decay: 0.7)
                self.diamondLayer.emitStarBurst()
            }
            self.applyExpansion()
        }

        public func pushFromBelow(strength: Float = 1.0) {
            self.diamondLayer.pushFromBelow(strength: strength)
        }

        public func updateTransferState(isSending: Bool, animateCompletion: Bool) {
            self.diamondLayer.updateTransferState(isSending: isSending, animateCompletion: animateCompletion)
        }

        public func beginReceivingTransfer(at startTime: CFTimeInterval, completionDelay: Double) {
            self.diamondLayer.beginReceivingTransfer(at: startTime, completionDelay: Float(completionDelay))
        }

        public func endReceivingTransfer() {
            self.diamondLayer.endReceivingTransfer()
        }

        public func updateRefractionSource(_ source: RefractionSource?) {
            guard self.refractionSource != source else { return }
            self.refractionSource = source
            self.updateRefractionPosition()
            self.diamondLayer.setNeedsUpdate()
        }

        private func updateRefractionPosition() {
            guard let source = self.refractionSource else {
                self.diamondLayer.refractionSource = nil
                return
            }
            self.diamondLayer.refractionSource = RefractionSource(
                texture: source.texture,
                uv: source.uv,
                rect: source.rect.offsetBy(
                    dx: self.restingSize.width * 0.5 - self.diamondLayer.position.x,
                    dy: self.restingSize.height * 0.5 - self.diamondLayer.position.y
                ),
                preservesColors: source.preservesColors
            )
        }

        @discardableResult
        public func update(component: InteractiveDiamondComponent) -> CGSize {
            let returningFromFlight = self.isWalletTransfer
            self.isWalletTransfer = false
            if self.animationMode != component.animationMode {
                self.cancelInteraction()
                self.animationMode = component.animationMode
            }
            let isInteractive = component.animationMode == .continuous
            self.pressGesture.isEnabled = isInteractive
            self.disablesInteractiveModalDismiss = isInteractive
            self.disablesInteractiveTransitionGestureRecognizer = isInteractive
            if self.expansionStyle != component.expansionStyle {
                self.cancelInteraction()
                self.expansionStyle = component.expansionStyle
            }
            self.pinchGesture.isEnabled = isInteractive && component.expansionStyle == .wallet
            self.restingSize = component.size
            self.diamondWidth = component.diamondWidth
            self.expandedCenter = component.expandedCenter
            var style = self.diamondLayer.diamondStyle
            if returningFromFlight {
                style.rotationSpeed = 2.0 * .pi / 26.0
                let defaults = DiamondStyle()
                style.backgroundStars = false
                style.steadyStars = defaults.steadyStars
                style.starZoom = defaults.starZoom
                style.starEmission = defaults.starEmission
                style.burstSize = defaults.burstSize
                style.burstFadeInDuration = defaults.burstFadeInDuration
            }
            style.animateOnAppear = component.animateOnAppear
            style.isRotating = component.animationMode != .idle
            switch component.animationMode {
            case .continuous, .idle:
                style.animationMode = .continuous
                style.referenceAnimationLoops = true
            case let .lottie(loop):
                style.animationMode = .reference
                style.referenceAnimationLoops = loop
            }
            style.swayScale = isInteractive ? 1.0 : 0.0
            style.floatAmplitude = isInteractive && component.expansionStyle == .downward ? 1.5 : 0.0
            style.floatPeriod = 3.2
            self.diamondLayer.highlightBoost = isInteractive ? 0.4 : 0.0
            style.mainSparkleOnRotation = isInteractive
            style.widthPoints = Float(component.diamondWidth * (component.expansionStyle == .wallet ? self.walletScale : 1.0))
            style.appearance = component.appearance
            style.widthCompensation = component.expansionStyle != .wallet
            style.dragGrow = component.expansionStyle == .wallet ? 2.6 : (component.expansionStyle == .downward ? 3.0 : 1.0)
            style.growShift = component.expansionStyle == .downward && component.expandedCenter == nil ? 12.0 : 0.0
            style.growDamping = component.expansionStyle != .centered ? 0.62 : 0.42
            style.releaseDecay = component.expansionStyle != .centered ? 1.1 : 0.0
            style.releaseTilt = component.expansionStyle != .centered ? 0.0 : 2.6
            style.tapToSpin = isInteractive && component.tapToSpin
            style.starOpacity = component.expansionStyle == .wallet ? 0.0 : 1.0
            style.rightwardStars = component.expansionStyle == .wallet
            style.starReferenceSize = component.expansionStyle == .wallet ? 240.0 : 0.0
            if component.expansionStyle != .wallet {
                style.tilt = 0.0
                style.lean = 0.0
            }
            self.diamondLayer.update(style: style)
            self.diamondLayer.lightBackground = component.expansionStyle == .centered && !component.theme.overallDarkAppearance
            self.isRenderingEnabled = component.isVisible
            self.applyExpansion()
            return component.size
        }
    }

    public func makeView() -> View { return View(frame: .zero) }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self)
    }
}

public final class PremiumDiamondComponent: Component {
    let theme: PresentationTheme

    public init(theme: PresentationTheme) {
        self.theme = theme
    }

    public static func ==(lhs: PremiumDiamondComponent, rhs: PremiumDiamondComponent) -> Bool {
        return lhs.theme === rhs.theme
    }

    public final class View: UIView, ComponentTaggedView {
        public final class Tag {
            public init() {
            }
        }

        private let diamondLayer = InteractiveDiamondLayer()
        private let readyPromise = Promise<Bool>()

        public var ready: Signal<Bool, NoError> {
            return self.readyPromise.get()
        }

        public func matches(tag: Any) -> Bool {
            return tag is Tag
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isOpaque = false
            self.diamondLayer.onReady = { [weak self] in
                self?.readyPromise.set(.single(true))
            }
            self.layer.addSublayer(self.diamondLayer)

            let panGesture = UIPanGestureRecognizer(target: self.diamondLayer, action: #selector(InteractiveDiamondLayer.handlePan(_:)))
            self.addGestureRecognizer(panGesture)
            let tapGesture = UITapGestureRecognizer(target: self.diamondLayer, action: #selector(InteractiveDiamondLayer.handleTap(_:)))
            tapGesture.require(toFail: panGesture)
            self.addGestureRecognizer(tapGesture)
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: PremiumDiamondComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.diamondLayer.bounds = CGRect(origin: .zero, size: availableSize)
            self.diamondLayer.position = CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5 - 8.0)
            self.diamondLayer.lightBackground = !component.theme.overallDarkAppearance
            self.diamondLayer.setNeedsUpdate()
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

public enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let firm = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static var pendingRefusal: DispatchWorkItem?

    public static func prime() { light.prepare() }

    public static func hit(_ intensity: CGFloat = 0.45) {
        light.impactOccurred(intensity: intensity)
        light.prepare()
    }

    public static func strong() {
        heavy.impactOccurred(intensity: 1)
        heavy.prepare()
    }

    public static func refuse() {
        cancelRefusal()
        firm.impactOccurred(intensity: 0.8)
        firm.prepare()
        let secondImpact = DispatchWorkItem {
            pendingRefusal = nil
            guard UIApplication.shared.applicationState == .active else { return }
            firm.impactOccurred(intensity: 0.55)
            firm.prepare()
        }
        pendingRefusal = secondImpact
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: secondImpact)
    }

    public static func cancelRefusal() {
        pendingRefusal?.cancel()
        pendingRefusal = nil
    }
}
