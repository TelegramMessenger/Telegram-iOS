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

    static func transform(scale: CGFloat, about point: CGPoint, layerPosition: CGPoint) -> CATransform3D {
        let dx = point.x - layerPosition.x
        let dy = point.y - layerPosition.y
        return CATransform3DConcat(CATransform3DMakeScale(scale, scale, 1.0), CATransform3DMakeTranslation((1.0 - scale) * dx, (1.0 - scale) * dy, 0.0))
    }
}

final class MediaGridZoomTransition {
    enum CameraRole {
        case none
        case outgoing
        case incoming
    }

    static let duration: CFTimeInterval = 0.35

    let outgoing: MediaGridLayoutLayer
    let incoming: MediaGridLayoutLayer
    let anchorPoint: CGPoint
    let scale: CGFloat
    let targetLayout: MediaGridUniformLayout
    let targetOffset: CGFloat
    let targetPixelSize: CGSize
    let camera: UIView?
    let cameraRole: CameraRole
    let cameraAlphaRange: (CGFloat, CGFloat)
    private(set) var progress: CGFloat = 0.0

    init(outgoing: MediaGridLayoutLayer, incoming: MediaGridLayoutLayer, anchorPoint: CGPoint, scale: CGFloat, targetLayout: MediaGridUniformLayout, targetOffset: CGFloat, targetPixelSize: CGSize, camera: UIView?, cameraRole: CameraRole, cameraAlphaRange: (CGFloat, CGFloat)) {
        self.outgoing = outgoing
        self.incoming = incoming
        self.anchorPoint = anchorPoint
        self.scale = scale
        self.targetLayout = targetLayout
        self.targetOffset = targetOffset
        self.targetPixelSize = targetPixelSize
        self.camera = camera
        self.cameraRole = cameraRole
        self.cameraAlphaRange = cameraAlphaRange
    }

    private func outgoingScale(_ progress: CGFloat) -> CGFloat {
        return 1.0 + (self.scale - 1.0) * progress
    }

    private func incomingScale(_ progress: CGFloat) -> CGFloat {
        let start = 1.0 / self.scale
        return start + (1.0 - start) * progress
    }

    private func outgoingTransform(_ progress: CGFloat, layer: CALayer) -> CATransform3D {
        return MediaGridZoomMath.transform(scale: self.outgoingScale(progress), about: self.anchorPoint, layerPosition: layer.position)
    }

    private func incomingTransform(_ progress: CGFloat, layer: CALayer) -> CATransform3D {
        return MediaGridZoomMath.transform(scale: self.incomingScale(progress), about: self.anchorPoint, layerPosition: layer.position)
    }

    private func cameraTransform(_ progress: CGFloat, layer: CALayer) -> CATransform3D {
        switch self.cameraRole {
        case .none:
            return CATransform3DIdentity
        case .outgoing:
            return self.outgoingTransform(progress, layer: layer)
        case .incoming:
            return self.incomingTransform(progress, layer: layer)
        }
    }

    private func cameraAlpha(_ progress: CGFloat) -> CGFloat {
        return self.cameraAlphaRange.0 + (self.cameraAlphaRange.1 - self.cameraAlphaRange.0) * progress
    }

    func apply(progress: CGFloat) {
        self.progress = progress
        self.outgoing.transform = self.outgoingTransform(progress, layer: self.outgoing)
        self.outgoing.opacity = Float(1.0 - progress)
        self.incoming.transform = self.incomingTransform(progress, layer: self.incoming)
        self.incoming.opacity = Float(progress)
        if let camera = self.camera {
            camera.layer.transform = self.cameraTransform(progress, layer: camera.layer)
            camera.alpha = self.cameraAlpha(progress)
        }
    }

    func animate(to progress: CGFloat, completion: @escaping () -> Void) {
        let from = self.progress
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        self.apply(progress: progress)
        self.add(keyPath: "transform", layer: self.outgoing, from: NSValue(caTransform3D: self.outgoingTransform(from, layer: self.outgoing)), to: NSValue(caTransform3D: self.outgoing.transform))
        self.add(keyPath: "opacity", layer: self.outgoing, from: NSNumber(value: Float(1.0 - from)), to: NSNumber(value: self.outgoing.opacity))
        self.add(keyPath: "transform", layer: self.incoming, from: NSValue(caTransform3D: self.incomingTransform(from, layer: self.incoming)), to: NSValue(caTransform3D: self.incoming.transform))
        self.add(keyPath: "opacity", layer: self.incoming, from: NSNumber(value: Float(from)), to: NSNumber(value: self.incoming.opacity))
        if let camera = self.camera {
            self.add(keyPath: "transform", layer: camera.layer, from: NSValue(caTransform3D: self.cameraTransform(from, layer: camera.layer)), to: NSValue(caTransform3D: camera.layer.transform))
            self.add(keyPath: "opacity", layer: camera.layer, from: NSNumber(value: Float(self.cameraAlpha(from))), to: NSNumber(value: camera.layer.opacity))
        }
        CATransaction.commit()
    }

    private func add(keyPath: String, layer: CALayer, from: Any, to: Any) {
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.mass = 1.0
        animation.stiffness = 300.0
        animation.damping = 2.0 * sqrt(animation.stiffness * animation.mass)
        animation.initialVelocity = 0.0
        animation.fromValue = from
        animation.toValue = to
        let settling = animation.settlingDuration
        animation.duration = settling
        animation.speed = Float(settling / MediaGridZoomTransition.duration)
        animation.isRemovedOnCompletion = true
        layer.add(animation, forKey: "mediaGridZoom.\(keyPath)")
    }

    func removeAnimations() {
        for layer in [self.outgoing, self.incoming] as [CALayer] {
            layer.removeAnimation(forKey: "mediaGridZoom.transform")
            layer.removeAnimation(forKey: "mediaGridZoom.opacity")
        }
        if let camera = self.camera {
            camera.layer.removeAnimation(forKey: "mediaGridZoom.transform")
            camera.layer.removeAnimation(forKey: "mediaGridZoom.opacity")
        }
    }
}
