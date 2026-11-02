import Foundation
import UIKit
import Display

private let mediaCropDialMarkerTop: CGFloat = 0.0
private let mediaCropDialMarkerSize = CGSize(width: 2.0, height: 28.0)
private let mediaCropDialTickBottom: CGFloat = 28.0
private let mediaCropDialTickWidth: CGFloat = 2.0
private let mediaCropDialDotSize: CGFloat = 6.0
private let mediaCropDialDotCenterY: CGFloat = 5.0
private let mediaCropDialFadeLength: CGFloat = 36.0
let mediaCropDialHitInsets = UIEdgeInsets(top: -12.0, left: 0.0, bottom: -12.0, right: 0.0)
private let mediaCropDialMarkerColor = UIColor(rgb: 0xffcc00)
private let mediaCropDialDotColor = UIColor(white: 1.0, alpha: 0.5)

public enum MediaCropDialAxis: Equatable {
    case horizontal
    case vertical(clockwise: Bool)
}

public struct MediaCropDialPlacement: Equatable {
    public let bounds: CGRect
    public let center: CGPoint
    public let transform: CGAffineTransform
}

public func mediaCropDialPlacement(frame: CGRect, axis: MediaCropDialAxis) -> MediaCropDialPlacement {
    let center = CGPoint(x: frame.midX, y: frame.midY)
    switch axis {
    case .horizontal:
        return MediaCropDialPlacement(bounds: CGRect(origin: .zero, size: frame.size), center: center, transform: .identity)
    case let .vertical(clockwise):
        return MediaCropDialPlacement(bounds: CGRect(x: 0.0, y: 0.0, width: frame.height, height: frame.width), center: center, transform: CGAffineTransform(rotationAngle: clockwise ? CGFloat.pi / 2.0 : -CGFloat.pi / 2.0))
    }
}

final class MediaCropRotationDialView: UIView, UIGestureRecognizerDelegate {
    private enum Motion {
        case coasting(startTime: Double, fromRaw: CGFloat, distance: CGFloat, duration: Double)
        case returning(startTime: Double, fromVisual: CGFloat, toRaw: CGFloat)
    }

    private let fadeMaskLayer = CAGradientLayer()
    private let rulerClipView = UIView()
    private let ticks: [MediaCropDialTick]
    private let tickLayers: [CALayer]
    private let zeroDotLayer = CALayer()
    private let markerView = UIView()

    private(set) var angle: CGFloat = 0.0
    private(set) var isTracking = false
    var limit: CGFloat = mediaCropMaximumWheelAngle
    private var rawDegrees: CGFloat = 0.0
    private var visualDegrees: CGFloat = 0.0
    private var selectedTickIndex = 0
    var hitInsets: UIEdgeInsets = mediaCropDialHitInsets
    var rulerScale: CGFloat = 1.0 {
        didSet {
            if self.rulerScale != oldValue {
                self.render()
            }
        }
    }
    private var tickDeselectionTimes: [Int: Double] = [:]
    private var motion: Motion?
    private var isTouching = false
    private var isPanning = false
    private var beganInteraction = false
    private var displayLink: ConstantDisplayLinkAnimator?
    private let hapticFeedback = HapticFeedback()

    var shouldBeginChanging: (() -> Bool)?
    var didBeginChanging: (() -> Void)?
    var didEndChanging: (() -> Void)?
    var angleChanged: ((CGFloat) -> Void)?

    override init(frame: CGRect) {
        self.ticks = mediaCropDialTicks()
        self.tickLayers = self.ticks.map { _ in
            let layer = CALayer()
            layer.backgroundColor = UIColor.white.cgColor
            layer.cornerRadius = mediaCropDialTickWidth / 2.0
            return layer
        }

        super.init(frame: frame)

        self.layer.contents = MediaCropAssets.transparentContents

        self.rulerClipView.isUserInteractionEnabled = false
        self.rulerClipView.layer.mask = self.fadeMaskLayer
        self.fadeMaskLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        self.fadeMaskLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        self.fadeMaskLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        self.addSubview(self.rulerClipView)

        for tickLayer in self.tickLayers {
            self.rulerClipView.layer.addSublayer(tickLayer)
        }

        self.zeroDotLayer.backgroundColor = mediaCropDialDotColor.cgColor
        self.zeroDotLayer.cornerRadius = mediaCropDialDotSize / 2.0
        self.rulerClipView.layer.addSublayer(self.zeroDotLayer)

        self.markerView.isUserInteractionEnabled = false
        self.markerView.backgroundColor = mediaCropDialMarkerColor
        self.markerView.layer.cornerRadius = mediaCropDialMarkerSize.width / 2.0
        self.addSubview(self.markerView)


        let pressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePress(_:)))
        pressGestureRecognizer.minimumPressDuration = 0.1
        pressGestureRecognizer.delegate = self
        self.addGestureRecognizer(pressGestureRecognizer)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        panGestureRecognizer.delegate = self
        self.addGestureRecognizer(panGestureRecognizer)

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let size = self.bounds.size
        UIView.performWithoutAnimation {
            self.rulerClipView.frame = CGRect(origin: .zero, size: size)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.fadeMaskLayer.frame = CGRect(origin: .zero, size: size)
        let fade = size.width > 0.0 ? min(0.5, mediaCropDialFadeLength / size.width) : 0.0
        self.fadeMaskLayer.locations = [0.0, NSNumber(value: Double(fade)), NSNumber(value: Double(1.0 - fade)), 1.0]
        CATransaction.commit()
        self.render()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.inset(by: self.hitInsets).contains(point)
    }

    private var rubberBandDimension: CGFloat {
        return max(1.0, self.bounds.width / 2.0)
    }

    private func render() {
        let now = CACurrentMediaTime()
        let centerX = self.bounds.width / 2.0
        let originX = centerX + mediaCropDialRulerOffset(degrees: self.visualDegrees) * self.rulerScale

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let firstIndex = self.ticks.first.flatMap { Int(($0.degrees / mediaCropDialDegreesPerTick).rounded()) } ?? 0
        var isExcited = false
        for (offset, tick) in self.ticks.enumerated() {
            let index = firstIndex + offset
            let excitation: CGFloat
            if index == self.selectedTickIndex {
                excitation = 1.0
            } else if let time = self.tickDeselectionTimes[index] {
                excitation = mediaCropDialTickExcitation(elapsed: now - time)
                if excitation > 0.0 {
                    isExcited = true
                } else {
                    self.tickDeselectionTimes[index] = nil
                }
            } else {
                excitation = 0.0
            }
            let appearance = mediaCropDialTickAppearance(excitation: excitation, isMajor: tick.isMajor)
            let layer = self.tickLayers[offset]
            layer.frame = CGRect(x: originX + tick.position * self.rulerScale - mediaCropDialTickWidth / 2.0, y: mediaCropDialTickBottom - appearance.height, width: mediaCropDialTickWidth, height: appearance.height)
            layer.opacity = Float(appearance.alpha)
        }
        self.zeroDotLayer.frame = CGRect(x: originX - mediaCropDialDotSize / 2.0, y: mediaCropDialDotCenterY - mediaCropDialDotSize / 2.0, width: mediaCropDialDotSize, height: mediaCropDialDotSize)
        self.zeroDotLayer.isHidden = !mediaCropDialShowsZeroDot(visualDegrees: self.visualDegrees)
        CATransaction.commit()

        let markerX = centerX + mediaCropDialMarkerOffset(visualDegrees: self.visualDegrees) * self.rulerScale
        self.markerView.frame = CGRect(x: markerX - mediaCropDialMarkerSize.width / 2.0, y: mediaCropDialMarkerTop, width: mediaCropDialMarkerSize.width, height: mediaCropDialMarkerSize.height)

        self.updateDisplayLink(needsFrames: isExcited || self.motion != nil)
    }

    private func updateDisplayLink(needsFrames: Bool) {
        if needsFrames {
            if self.displayLink == nil {
                self.displayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.displayLinkTick()
                })
            }
            self.displayLink?.isPaused = false
        } else {
            self.displayLink?.isPaused = true
        }
    }

    private func displayLinkTick() {
        let now = CACurrentMediaTime()
        if let motion = self.motion {
            switch motion {
            case let .coasting(startTime, fromRaw, distance, duration):
                let elapsed = now - startTime
                var raw = mediaCropDialDraggedDegrees(rawDegrees: fromRaw, translation: distance * mediaCropDialInertiaFraction(time: elapsed))
                var finished = elapsed >= duration
                if abs(raw) >= mediaCropMaximumWheelAngle {
                    raw = raw > 0.0 ? mediaCropMaximumWheelAngle : -mediaCropMaximumWheelAngle
                    finished = true
                }
                self.setRaw(raw)
                if finished {
                    self.motion = nil
                    self.finishInteractionIfIdle()
                }
            case let .returning(startTime, fromVisual, toRaw):
                let elapsed = now - startTime
                let progress = mediaCropMirrorFlipProgress(time: elapsed)
                self.rawDegrees = toRaw
                self.setVisual(fromVisual + (toRaw - fromVisual) * progress)
                if elapsed >= mediaCropMirrorDuration {
                    self.motion = nil
                    self.setVisual(mediaCropDialVisualDegrees(rawDegrees: toRaw, dimension: self.rubberBandDimension))
                    self.finishInteractionIfIdle()
                }
            }
        }
        self.render()
    }

    private func setVisual(_ visual: CGFloat) {
        self.visualDegrees = visual
        let index = mediaCropDialSelectedTickIndex(visualDegrees: visual)
        if index != self.selectedTickIndex {
            let now = CACurrentMediaTime()
            for passed in mediaCropDialPassedTickIndices(from: self.selectedTickIndex, to: index) {
                self.tickDeselectionTimes[passed] = now
            }
            self.tickDeselectionTimes[index] = nil
            self.selectedTickIndex = index
        }
    }

    private func setRaw(_ raw: CGFloat) {
        self.rawDegrees = raw
        let previousIndex = self.selectedTickIndex
        self.setVisual(mediaCropDialVisualDegrees(rawDegrees: raw, dimension: self.rubberBandDimension))
        let previousDegrees = mediaCropDialDegrees(value: self.angle * 180.0 / .pi, limit: self.limit)
        let newDegrees = mediaCropDialValue(rawDegrees: raw)
        let detentReached = abs(newDegrees - previousDegrees) > CGFloat(Float.ulpOfOne) && mediaCropDialDetentReached(from: previousDegrees, to: newDegrees)
        if mediaCropDialPlaysTickHaptic(previousIndex: previousIndex, currentIndex: self.selectedTickIndex, detentReached: detentReached) {
            self.hapticFeedback.impact(.veryLight)
        }
        if abs(newDegrees - previousDegrees) > CGFloat(Float.ulpOfOne) {
            if detentReached {
                self.hapticFeedback.tap()
            }
            self.angle = mediaCropDialDegrees(dialDegrees: newDegrees, limit: self.limit) * .pi / 180.0
            self.angleChanged?(self.angle)
        }
    }

    private func resetMotionState(degrees: CGFloat) {
        self.motion = nil
        self.rawDegrees = degrees
        self.visualDegrees = degrees
        self.selectedTickIndex = mediaCropDialSelectedTickIndex(visualDegrees: degrees)
        self.tickDeselectionTimes = [:]
    }

    func setAngle(_ angle: CGFloat) {
        self.angle = angle
        self.resetMotionState(degrees: mediaCropDialDegrees(value: angle * 180.0 / .pi, limit: self.limit))
        self.render()
    }

    func setDimmed(_ dimmed: Bool) {
        let alpha: CGFloat = dimmed ? 0.4 : 1.0
        self.rulerClipView.alpha = alpha
        self.markerView.alpha = alpha
    }

        func setAngle(_ angle: CGFloat, limit: CGFloat) {
        self.limit = limit
        self.setAngle(angle)
    }

    func reset(animated: Bool) {
        let fromVisual = self.visualDegrees
        self.angle = 0.0
        guard animated, abs(fromVisual) > CGFloat(Float.ulpOfOne) else {
            self.resetMotionState(degrees: 0.0)
            self.render()
            return
        }
        self.rawDegrees = 0.0
        self.motion = .returning(startTime: CACurrentMediaTime(), fromVisual: fromVisual, toRaw: 0.0)
        self.render()
    }

    private var isAnimating: Bool {
        if case .returning = self.motion {
            return true
        }
        return false
    }

    private func begin() {
        self.isTouching = true
        if case .coasting = self.motion {
            self.motion = nil
        }
        if self.beganInteraction {
            return
        }
        self.isTracking = true
        self.rawDegrees = mediaCropDialValue(rawDegrees: self.rawDegrees)
        self.hapticFeedback.prepareTap()
        self.hapticFeedback.prepareImpact(.veryLight)
        self.didBeginChanging?()
        self.beganInteraction = true
    }

    private func touchEnded() {
        self.isTouching = false
        self.finishInteractionIfIdle()
    }

    private func finishInteractionIfIdle() {
        if self.isTouching || self.isPanning || self.motion != nil || !self.beganInteraction {
            return
        }
        self.beganInteraction = false
        self.isTracking = false
        self.didEndChanging?()
    }

    private func releaseRuler(velocity: CGFloat) {
        let limit = mediaCropMaximumWheelAngle
        if abs(self.rawDegrees) > limit {
            let target = self.rawDegrees > 0.0 ? limit : -limit
            self.motion = .returning(startTime: CACurrentMediaTime(), fromVisual: self.visualDegrees, toRaw: target)
            self.render()
            return
        }
        let distance = mediaCropDialInertiaDistance(velocity: velocity)
        let duration = mediaCropDialInertiaDuration(distance: distance)
        if duration > 0.0 {
            self.motion = .coasting(startTime: CACurrentMediaTime(), fromRaw: self.rawDegrees, distance: distance, duration: duration)
            self.render()
        }
    }

    @objc private func handlePress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            self.begin()
        case .ended, .cancelled:
            self.touchEnded()
        default:
            break
        }
    }

    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            self.isPanning = true
            self.begin()
        case .changed:
            self.isPanning = true
            let translation = gestureRecognizer.translation(in: self).x / self.rulerScale
            gestureRecognizer.setTranslation(.zero, in: self)
            self.setRaw(mediaCropDialDraggedDegrees(rawDegrees: self.rawDegrees, translation: translation))
            self.render()
        case .ended:
            self.isPanning = false
            self.releaseRuler(velocity: gestureRecognizer.velocity(in: self).x / self.rulerScale)
            self.touchEnded()
        case .cancelled:
            self.isPanning = false
            self.releaseRuler(velocity: 0.0)
            self.touchEnded()
        default:
            break
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !self.isAnimating && (self.shouldBeginChanging?() ?? true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
