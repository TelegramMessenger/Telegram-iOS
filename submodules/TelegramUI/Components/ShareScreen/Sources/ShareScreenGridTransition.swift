import UIKit
import Display
import TelegramCore

// Matches SharePeersContainerNode / ShareTopicsContainerNode. Positions are
// captured in content coordinates; a scroll offset the sheet changes without
// animation between laying out the two grids is applied as a shift, while an
// animated expansion moves both grids together with the content.
final class ShareScreenGridTransition {
    let peerId: EnginePeer.Id
    private let opening: Bool
    private let sourceCenter: CGPoint?
    private let capturedOffset: CGFloat
    private var outgoingViews: [UIView] = []
    private var outgoingContainer: UIView?
    private var incomingViews: [UIView] = []
    private var didAnimateOutgoing = false
    private(set) var isCompleted = false

    init(opening: Bool, peerId: EnginePeer.Id, views: [UIView], sourceView: UIView?, contentView: UIView, visibleBounds: CGRect) {
        self.opening = opening
        self.peerId = peerId
        self.capturedOffset = max(0.0, visibleBounds.minY)
        self.sourceCenter = sourceView.map { $0.convert(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY), to: contentView) }
        let outgoing = UIView(frame: contentView.bounds)
        outgoing.isUserInteractionEnabled = false
        contentView.addSubview(outgoing)
        self.outgoingContainer = outgoing
        for view in views {
            let frame = view.convert(view.bounds, to: contentView)
            guard frame.intersects(visibleBounds) else { continue }
            view.layer.removeAllAnimations()
            outgoing.addSubview(view)
            view.frame = frame
            self.outgoingViews.append(view)
        }
    }

    func cancel() {
        self.outgoingContainer?.removeFromSuperview()
        self.outgoingContainer = nil
        self.outgoingViews.removeAll()
        for view in self.incomingViews {
            view.layer.removeAnimation(forKey: "position")
            view.layer.removeAnimation(forKey: "transform.scale")
            view.layer.removeAnimation(forKey: "opacity")
        }
        self.incomingViews.removeAll()
        self.isCompleted = true
    }

    func animate(in container: UIView, views: [UIView], targetView: UIView?, visibleBounds: CGRect) {
        guard !self.isCompleted else { return }
        let shift = max(0.0, visibleBounds.minY) - self.capturedOffset
        let center: CGPoint
        if self.opening, let sourceCenter = self.sourceCenter {
            center = CGPoint(x: sourceCenter.x, y: sourceCenter.y + shift)
        } else if let targetView {
            center = targetView.convert(CGPoint(x: targetView.bounds.midX, y: targetView.bounds.midY), to: container)
        } else {
            self.cancel()
            return
        }

        if !self.didAnimateOutgoing {
            self.didAnimateOutgoing = true
            guard let outgoing = self.outgoingContainer else { return }
            outgoing.superview?.bringSubviewToFront(outgoing)
            outgoing.frame = container.bounds.offsetBy(dx: 0.0, dy: shift)
            outgoing.layer.rasterizationScale = UIScreenScale
            outgoing.layer.shouldRasterize = true
            let accelerate = CAMediaTimingFunction(controlPoints: 0.5, 0.0, 0.9, 0.55)
            for snapshot in self.outgoingViews {
                let position = snapshot.center
                let destination = self.opening ? CGPoint(x: position.x + (position.x - center.x) * 2.8, y: position.y + (position.y - center.y) * 2.8) : center
                snapshot.layer.animatePosition(from: position, to: destination, duration: 0.32, mediaTimingFunction: accelerate, removeOnCompletion: false)
                snapshot.layer.animateScale(from: 1.0, to: self.opening ? 1.35 : 0.2, duration: 0.32, mediaTimingFunction: accelerate, removeOnCompletion: false)
            }
            self.outgoingViews.removeAll()
            outgoing.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak self, weak outgoing] _ in
                outgoing?.removeFromSuperview()
                self?.outgoingContainer = nil
            })
        }

        // Cached topics/community chats can arrive on the next model update.
        guard !views.isEmpty else { return }
        self.isCompleted = true
        self.incomingViews = views
        var parents: [UIView] = []
        for view in views {
            if let parent = view.superview, !parents.contains(where: { $0 === parent }) {
                parents.append(parent)
            }
        }
        let endRasterizations = parents.map { $0.layer.beginRasterizedAnimation() }
        var remaining = views.count
        let incomingCompleted: (Bool) -> Void = { finished in
            remaining -= 1
            if remaining == 0 {
                endRasterizations.forEach { $0(finished) }
            }
        }
        var maxDistance: CGFloat = 1.0
        var distances: [CGFloat] = []
        for view in views {
            let localCenter = view.superview.map { $0.convert(center, from: container) } ?? center
            let distance = hypot(view.center.x - localCenter.x, view.center.y - localCenter.y)
            distances.append(distance)
            maxDistance = max(maxDistance, distance)
        }
        for (index, view) in views.enumerated() {
            guard let parent = view.superview else {
                incomingCompleted(true)
                continue
            }
            let localCenter = parent.convert(center, from: container)
            let position = view.center
            let offset = self.opening ? CGPoint(x: localCenter.x - position.x, y: localCenter.y - position.y) : CGPoint(x: (position.x - localCenter.x) * 2.8, y: (position.y - localCenter.y) * 2.8)
            let fraction = distances[index] / maxDistance
            let delay = Double(self.opening ? fraction : (1.0 - fraction)) * 0.06
            ShareScreenGridTransition.addSpring(layer: view.layer, keyPath: "position", from: NSValue(cgPoint: offset), to: NSValue(cgPoint: .zero), additive: true, stiffness: 420.0, dampingRatio: 0.82, delay: delay)
            ShareScreenGridTransition.addSpring(layer: view.layer, keyPath: "transform.scale", from: (self.opening ? 0.2 : 1.35) as NSNumber, to: 1.0 as NSNumber, additive: false, stiffness: 420.0, dampingRatio: 0.66, delay: delay, completion: { [weak self] finished in
                incomingCompleted(finished)
                self?.incomingViews.removeAll()
            })
            view.layer.animateAlpha(from: 0.0, to: 1.0, duration: self.opening ? 0.22 : 0.15, delay: delay)
        }
    }

    private static func addSpring(layer: CALayer, keyPath: String, from: Any, to: Any, additive: Bool, stiffness: CGFloat, dampingRatio: CGFloat, delay: Double, completion: ((Bool) -> Void)? = nil) {
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.mass = 1.0
        animation.stiffness = stiffness
        animation.damping = dampingRatio * 2.0 * sqrt(stiffness)
        animation.fromValue = from
        animation.toValue = to
        animation.isAdditive = additive
        animation.duration = animation.settlingDuration
        animation.fillMode = .both
        animation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
        if let completion {
            animation.delegate = ShareScreenAnimationDelegate(completion: completion)
        }
        layer.add(animation, forKey: keyPath)
    }
}

private final class ShareScreenAnimationDelegate: NSObject, CAAnimationDelegate {
    private var completion: ((Bool) -> Void)?

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        let completion = self.completion
        self.completion = nil
        completion?(flag)
    }
}
