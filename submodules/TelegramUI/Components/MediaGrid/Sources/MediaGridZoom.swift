import Foundation
import UIKit
import QuartzCore

public struct MediaGridZoomAnchor: Equatable {
    public var index: Int
    public var pointInView: CGPoint

    public init(index: Int, pointInView: CGPoint) {
        self.index = index
        self.pointInView = pointInView
    }
}

public enum MediaGridZoomMath {
    public static func targetOffset(anchor: MediaGridZoomAnchor, in layout: MediaGridLayout, viewportHeight: CGFloat, relativePosition: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> CGFloat {
        let maxOffset = max(0.0, layout.contentHeight - viewportHeight)
        guard anchor.index >= 0, anchor.index < layout.count else {
            return 0.0
        }
        let frame = layout.frame(at: anchor.index)
        let fraction = min(1.0, max(0.0, relativePosition.y))
        let offset = frame.minY + fraction * frame.height - anchor.pointInView.y
        guard offset.isFinite else {
            return 0.0
        }
        return min(max(0.0, offset), maxOffset)
    }

    public static func scale(from: MediaGridLayout, to: MediaGridLayout, anchorIndex: Int) -> CGFloat {
        guard anchorIndex >= 0, anchorIndex < from.count, anchorIndex < to.count else {
            return 1.0
        }
        let fromWidth = from.frame(at: anchorIndex).width
        let toWidth = to.frame(at: anchorIndex).width
        guard fromWidth > 0.0, toWidth > 0.0 else {
            return 1.0
        }
        return toWidth / fromWidth
    }

    static func relativePosition(of point: CGPoint, in frame: CGRect) -> CGPoint {
        guard frame.width > 0.0, frame.height > 0.0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        return CGPoint(x: min(1.0, max(0.0, (point.x - frame.minX) / frame.width)), y: min(1.0, max(0.0, (point.y - frame.minY) / frame.height)))
    }

    static func scaled(_ rect: CGRect, about point: CGPoint, by scale: CGFloat) -> CGRect {
        guard scale.isFinite, scale > 0.0 else {
            return rect
        }
        return CGRect(x: point.x + (rect.minX - point.x) * scale, y: point.y + (rect.minY - point.y) * scale, width: rect.width * scale, height: rect.height * scale)
    }

    static func transform(scale: CGFloat, about point: CGPoint, layerPosition: CGPoint) -> CATransform3D {
        return MediaGridZoomMath.transform(scaleX: scale, scaleY: scale, about: point, layerPosition: layerPosition)
    }

    static func transform(scaleX: CGFloat, scaleY: CGFloat, about point: CGPoint, layerPosition: CGPoint) -> CATransform3D {
        let dx = point.x - layerPosition.x
        let dy = point.y - layerPosition.y
        return CATransform3DConcat(CATransform3DMakeScale(scaleX, scaleY, 1.0), CATransform3DMakeTranslation((1.0 - scaleX) * dx, (1.0 - scaleY) * dy, 0.0))
    }

    static func scaled(_ rect: CGRect, about point: CGPoint, byX scaleX: CGFloat, y scaleY: CGFloat) -> CGRect {
        guard scaleX.isFinite, scaleX > 0.0, scaleY.isFinite, scaleY > 0.0 else {
            return rect
        }
        return CGRect(x: point.x + (rect.minX - point.x) * scaleX, y: point.y + (rect.minY - point.y) * scaleY, width: rect.width * scaleX, height: rect.height * scaleY)
    }
}

public struct MediaGridPinchState {
    static let maxOvershoot: CGFloat = 0.12
    static let velocityThreshold: CGFloat = 0.5
    private static let epsilon: CGFloat = 1e-9

    public let startLevel: MediaGridLevel
    public let anchor: MediaGridZoomAnchor
    private let startPosition: CGFloat
    private var scale: CGFloat = 1.0
    private var rawPosition: CGFloat
    private(set) var current: (from: MediaGridLevel, to: MediaGridLevel, progress: CGFloat)

    public init(startLevel: MediaGridLevel, anchor: MediaGridZoomAnchor) {
        self.init(startLevel: startLevel, anchor: anchor, toward: startLevel, startProgress: 0.0)
    }

    init(startLevel: MediaGridLevel, anchor: MediaGridZoomAnchor, toward target: MediaGridLevel, startProgress: CGFloat) {
        self.startLevel = startLevel
        self.anchor = anchor
        let from = MediaGridPinchState.position(of: startLevel)
        let to = MediaGridPinchState.position(of: target)
        self.startPosition = from + (to - from) * min(1.25, max(-0.25, startProgress))
        self.rawPosition = self.startPosition
        self.current = (startLevel, startLevel, 0.0)
        self.current = self.resolve(self.startPosition)
    }

    private static let levels: [MediaGridLevel] = MediaGridLevel.allCases.sorted()

    static func position(of level: MediaGridLevel) -> CGFloat {
        return log(CGFloat(level.columns))
    }

    private var bounds: (CGFloat, CGFloat) {
        return (MediaGridPinchState.position(of: MediaGridPinchState.levels[0]), MediaGridPinchState.position(of: MediaGridPinchState.levels[MediaGridPinchState.levels.count - 1]))
    }

    private func resolve(_ position: CGFloat) -> (from: MediaGridLevel, to: MediaGridLevel, progress: CGFloat) {
        let levels = MediaGridPinchState.levels
        let start = MediaGridPinchState.position(of: self.startLevel)
        if position > start + MediaGridPinchState.epsilon {
            for index in 1 ..< levels.count {
                let upper = MediaGridPinchState.position(of: levels[index])
                if upper >= position - MediaGridPinchState.epsilon && upper > start {
                    let lower = MediaGridPinchState.position(of: levels[index - 1])
                    return (levels[index - 1], levels[index], min(1.0, max(0.0, (position - lower) / (upper - lower))))
                }
            }
        } else if position < start - MediaGridPinchState.epsilon {
            for index in stride(from: levels.count - 2, through: 0, by: -1) {
                let lower = MediaGridPinchState.position(of: levels[index])
                if lower <= position + MediaGridPinchState.epsilon && lower < start {
                    let upper = MediaGridPinchState.position(of: levels[index + 1])
                    return (levels[index + 1], levels[index], min(1.0, max(0.0, (upper - position) / (upper - lower))))
                }
            }
        }
        return (self.startLevel, self.startLevel, 0.0)
    }

    public mutating func update(scale: CGFloat) -> (from: MediaGridLevel, to: MediaGridLevel, progress: CGFloat) {
        let scale = scale.isFinite && scale > 0.0 ? scale : self.scale
        self.scale = scale
        self.rawPosition = self.startPosition - log(scale)
        let (lower, upper) = self.bounds
        self.current = self.resolve(min(upper, max(lower, self.rawPosition)))
        return self.current
    }

    var overshoot: CGFloat {
        let (lower, upper) = self.bounds
        let excess: CGFloat
        if self.rawPosition > upper {
            excess = self.rawPosition - upper
        } else if self.rawPosition < lower {
            excess = self.rawPosition - lower
        } else {
            return 0.0
        }
        let limit = MediaGridPinchState.maxOvershoot
        let banded = (1.0 - 1.0 / (abs(excess) * 0.55 / limit + 1.0)) * limit
        return excess > 0.0 ? banded : -banded
    }

    func progressVelocity(scaleVelocity: CGFloat) -> CGFloat {
        let (from, to, _) = self.current
        guard from != to, scaleVelocity.isFinite else {
            return 0.0
        }
        let span = MediaGridPinchState.position(of: to) - MediaGridPinchState.position(of: from)
        return -scaleVelocity / self.scale / span
    }

    public func settle(velocity: CGFloat) -> MediaGridLevel {
        let (from, to, progress) = self.current
        guard from != to else {
            return from
        }
        if abs(velocity) > MediaGridPinchState.velocityThreshold {
            let towardFewerColumns = velocity > 0.0
            return (to < from) == towardFewerColumns ? to : from
        }
        return progress >= 0.5 ? to : from
    }
}

final class MediaGridZoomTransition {
    enum CameraRole {
        case none
        case outgoing
        case incoming
        case moving(from: CGRect, to: CGRect)
    }

    static let duration: CFTimeInterval = 0.35

    let sourceLevel: MediaGridLevel
    let targetLevel: MediaGridLevel
    let sourceLayout: MediaGridLayout
    let outgoing: MediaGridLayoutLayer
    let incoming: MediaGridLayoutLayer
    let anchorPoint: CGPoint
    let scale: CGFloat
    let heightRatio: CGFloat
    let targetLayout: MediaGridLayout
    let targetOffset: CGFloat
    let camera: UIView?
    let cameraRole: CameraRole
    let cameraAlphaRange: (CGFloat, CGFloat)
    private(set) var progress: CGFloat = 0.0
    private(set) var destination: CGFloat?
    var viewport: CGRect = .zero
    var shift: CGFloat = 0.0
    var boundRange: ClosedRange<CGFloat>?
    private var animationToken = 0

    init(sourceLevel: MediaGridLevel, targetLevel: MediaGridLevel, sourceLayout: MediaGridLayout, outgoing: MediaGridLayoutLayer, outgoingLocalAnchor: CGPoint, incoming: MediaGridLayoutLayer, incomingLocalAnchor: CGPoint, anchorPoint: CGPoint, viewportSize: CGSize, scale: CGFloat, heightRatio: CGFloat = 1.0, targetLayout: MediaGridLayout, targetOffset: CGFloat, camera: UIView?, cameraRole: CameraRole, cameraAlphaRange: (CGFloat, CGFloat)) {
        self.sourceLevel = sourceLevel
        self.targetLevel = targetLevel
        self.sourceLayout = sourceLayout
        self.outgoing = outgoing
        self.incoming = incoming
        self.anchorPoint = anchorPoint
        self.scale = scale
        self.heightRatio = heightRatio.isFinite && heightRatio > 0.0 ? heightRatio : 1.0
        self.targetLayout = targetLayout
        self.targetOffset = targetOffset
        self.camera = camera
        self.cameraRole = cameraRole
        self.cameraAlphaRange = cameraAlphaRange
        MediaGridZoomTransition.pivot(outgoing, localAnchor: outgoingLocalAnchor, hostAnchor: anchorPoint, viewportSize: viewportSize)
        MediaGridZoomTransition.pivot(incoming, localAnchor: incomingLocalAnchor, hostAnchor: anchorPoint, viewportSize: viewportSize)
    }

    private static func pivot(_ layer: CALayer, localAnchor: CGPoint, hostAnchor: CGPoint, viewportSize: CGSize) {
        layer.transform = CATransform3DIdentity
        let width = max(1.0, viewportSize.width)
        let height = max(1.0, viewportSize.height)
        layer.anchorPoint = CGPoint(x: localAnchor.x / width, y: 0.5)
        layer.bounds = CGRect(x: 0.0, y: localAnchor.y - height * 0.5, width: width, height: height)
        layer.position = hostAnchor
    }

    static func resetPivot(_ layer: CALayer, width: CGFloat, height: CGFloat, originY: CGFloat) {
        layer.transform = CATransform3DIdentity
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.bounds = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        layer.position = CGPoint(x: width * 0.5, y: originY + height * 0.5)
    }

    private func outgoingScale(_ progress: CGFloat) -> CGFloat {
        return 1.0 + (self.scale - 1.0) * progress
    }

    private func incomingScale(_ progress: CGFloat) -> CGFloat {
        let start = 1.0 / self.scale
        return start + (1.0 - start) * progress
    }

    private func outgoingScaleY(_ progress: CGFloat) -> CGFloat {
        return self.outgoingScale(progress) * pow(self.heightRatio, progress)
    }

    private func incomingScaleY(_ progress: CGFloat) -> CGFloat {
        return self.incomingScale(progress) * pow(self.heightRatio, progress - 1.0)
    }

    func incomingRect(at progress: CGFloat) -> CGRect {
        return MediaGridZoomMath.scaled(self.viewport, about: self.anchorPoint, byX: 1.0 / self.incomingScale(progress), y: 1.0 / self.incomingScaleY(progress)).offsetBy(dx: 0.0, dy: -self.shift)
    }

    func outgoingRect(at progress: CGFloat) -> CGRect {
        return MediaGridZoomMath.scaled(self.viewport, about: self.anchorPoint, byX: 1.0 / self.outgoingScale(progress), y: 1.0 / self.outgoingScaleY(progress))
    }

    private func outgoingTransform(_ progress: CGFloat) -> CATransform3D {
        return CATransform3DMakeScale(self.outgoingScale(progress), self.outgoingScaleY(progress), 1.0)
    }

    private func incomingTransform(_ progress: CGFloat) -> CATransform3D {
        return CATransform3DMakeScale(self.incomingScale(progress), self.incomingScaleY(progress), 1.0)
    }

    private func cameraTransform(_ progress: CGFloat, layer: CALayer) -> CATransform3D {
        switch self.cameraRole {
        case .none, .moving:
            return CATransform3DIdentity
        case .outgoing:
            return MediaGridZoomMath.transform(scaleX: self.outgoingScale(progress), scaleY: self.outgoingScaleY(progress), about: self.anchorPoint, layerPosition: layer.position)
        case .incoming:
            return MediaGridZoomMath.transform(scaleX: self.incomingScale(progress), scaleY: self.incomingScaleY(progress), about: self.anchorPoint, layerPosition: layer.position)
        }
    }

    private func cameraFrame(_ progress: CGFloat) -> CGRect? {
        guard case let .moving(from, to) = self.cameraRole else {
            return nil
        }
        return CGRect(x: from.minX + (to.minX - from.minX) * progress, y: from.minY + (to.minY - from.minY) * progress, width: from.width + (to.width - from.width) * progress, height: from.height + (to.height - from.height) * progress)
    }

    private func cameraAlpha(_ progress: CGFloat) -> CGFloat {
        return self.cameraAlphaRange.0 + (self.cameraAlphaRange.1 - self.cameraAlphaRange.0) * progress
    }

    func apply(progress: CGFloat) {
        self.progress = progress
        self.outgoing.transform = self.outgoingTransform(progress)
        let clamped = min(1.0, max(0.0, progress))
        self.outgoing.opacity = Float(1.0 - clamped)
        self.incoming.transform = self.incomingTransform(progress)
        self.incoming.opacity = Float(clamped)
        if let camera = self.camera {
            if let frame = self.cameraFrame(progress) {
                camera.layer.transform = CATransform3DIdentity
                camera.layer.bounds = CGRect(origin: .zero, size: frame.size)
                camera.layer.position = CGPoint(x: frame.midX, y: frame.midY)
            } else {
                camera.layer.transform = self.cameraTransform(progress, layer: camera.layer)
            }
            camera.alpha = self.cameraAlpha(clamped)
        }
    }

    var isAnimating: Bool {
        return self.incoming.animation(forKey: "mediaGridZoom.opacity") != nil
    }

    var presentedProgress: CGFloat {
        guard self.isAnimating, let presentation = self.incoming.presentation() else {
            return self.clampedExtrapolation(self.progress)
        }
        let start = 1.0 / self.scale
        guard abs(1.0 - start) > 1e-6 else {
            return min(1.0, max(0.0, CGFloat(presentation.opacity)))
        }
        return self.clampedExtrapolation((presentation.transform.m11 - start) / (1.0 - start))
    }

    private func clampedExtrapolation(_ progress: CGFloat) -> CGFloat {
        guard progress.isFinite else {
            return 0.0
        }
        return min(1.25, max(-0.25, progress))
    }

    func interrupt() {
        let presented = self.presentedProgress
        self.removeAnimations()
        self.apply(progress: presented)
    }

    func animate(to progress: CGFloat, velocity: CGFloat = 0.0, completion: @escaping () -> Void) {
        let from = self.progress
        self.animationToken += 1
        let token = self.animationToken
        self.destination = progress
        let distance = progress - from
        let relativeVelocity = abs(distance) > 1e-6 ? min(30.0, max(-30.0, velocity / distance)) : 0.0
        self.springVelocity = relativeVelocity
        CATransaction.begin()
        CATransaction.setCompletionBlock({ [weak self] in
            guard let self, self.animationToken == token else {
                return
            }
            completion()
        })
        self.apply(progress: progress)
        self.add(keyPath: "transform", layer: self.outgoing, from: NSValue(caTransform3D: self.outgoingTransform(from)), to: NSValue(caTransform3D: self.outgoing.transform))
        let clampedFrom = min(1.0, max(0.0, from))
        self.add(keyPath: "opacity", layer: self.outgoing, from: NSNumber(value: Float(1.0 - clampedFrom)), to: NSNumber(value: self.outgoing.opacity))
        self.add(keyPath: "transform", layer: self.incoming, from: NSValue(caTransform3D: self.incomingTransform(from)), to: NSValue(caTransform3D: self.incoming.transform))
        self.add(keyPath: "opacity", layer: self.incoming, from: NSNumber(value: Float(clampedFrom)), to: NSNumber(value: self.incoming.opacity))
        if let camera = self.camera {
            if let fromFrame = self.cameraFrame(from) {
                self.add(keyPath: "position", layer: camera.layer, from: NSValue(cgPoint: CGPoint(x: fromFrame.midX, y: fromFrame.midY)), to: NSValue(cgPoint: camera.layer.position))
                self.add(keyPath: "bounds", layer: camera.layer, from: NSValue(cgRect: CGRect(origin: .zero, size: fromFrame.size)), to: NSValue(cgRect: camera.layer.bounds))
            } else {
                self.add(keyPath: "transform", layer: camera.layer, from: NSValue(caTransform3D: self.cameraTransform(from, layer: camera.layer)), to: NSValue(caTransform3D: camera.layer.transform))
            }
            self.add(keyPath: "opacity", layer: camera.layer, from: NSNumber(value: Float(self.cameraAlpha(clampedFrom))), to: NSNumber(value: camera.layer.opacity))
        }
        CATransaction.commit()
        self.springVelocity = 0.0
    }

    private var springVelocity: CGFloat = 0.0

    private func add(keyPath: String, layer: CALayer, from: Any, to: Any) {
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.mass = 1.0
        animation.stiffness = 300.0
        animation.damping = 2.0 * sqrt(animation.stiffness * animation.mass)
        animation.initialVelocity = 0.0
        animation.fromValue = from
        animation.toValue = to
        let speed = animation.settlingDuration / MediaGridZoomTransition.duration
        animation.initialVelocity = self.springVelocity / speed
        animation.duration = animation.settlingDuration
        animation.speed = Float(speed)
        animation.isRemovedOnCompletion = true
        layer.add(animation, forKey: "mediaGridZoom.\(keyPath)")
    }

    func removeAnimations() {
        self.animationToken += 1
        self.destination = nil
        for layer in [self.outgoing, self.incoming] as [CALayer] {
            layer.removeAnimation(forKey: "mediaGridZoom.transform")
            layer.removeAnimation(forKey: "mediaGridZoom.opacity")
        }
        if let camera = self.camera {
            for key in ["transform", "opacity", "position", "bounds"] {
                camera.layer.removeAnimation(forKey: "mediaGridZoom.\(key)")
            }
        }
    }
}
