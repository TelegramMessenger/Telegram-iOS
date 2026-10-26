import UIKit

final class TestableScrollView: UIScrollView {
    enum Mode {
        case idle
        case programmatic(initialOffsetY: CGFloat, targetY: CGFloat, startTime: TimeInterval, duration: TimeInterval, lastEased: CGFloat)
        case decelerating(velocity: CGFloat, deceleration: CGFloat)
        case rubberBand(targetEdge: CGFloat, velocity: CGFloat, stiffness: CGFloat, damping: CGFloat)
    }

    let clock: SyntheticClock
    private(set) var mode: Mode = .idle

    /// Duration of `setContentOffset(_:animated:)`. Tests can override per-instance.
    var programmaticDuration: TimeInterval = 0.3

    /// Deceleration in points/second². Tests can override per-instance.
    var deceleration: CGFloat = 2000

    /// Resistance constant when dragging past an edge. Higher = more resistance.
    var edgeResistance: CGFloat = 2.0

    /// Spring stiffness (1/s²) for rubber-band return.
    var rubberBandStiffness: CGFloat = 200

    /// Spring damping ratio for rubber-band return. 1.0 = critically damped.
    var rubberBandDamping: CGFloat = 1.0

    private var topEdge: CGFloat { 0 }
    private var bottomEdge: CGFloat { max(0, contentSize.height - bounds.height) }

    private func resistedOvershoot(_ overshoot: CGFloat) -> CGFloat {
        let viewport = max(1, bounds.height)
        return overshoot / (1 + edgeResistance * abs(overshoot) / viewport)
    }

    init(clock: SyntheticClock, frame: CGRect = .zero) {
        self.clock = clock
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not used in tests")
    }

    func simulateFlick(velocity: CGFloat) {
        mode = .decelerating(velocity: velocity, deceleration: deceleration)
    }

    func simulateDrag(by deltaY: CGFloat) {
        mode = .idle
        let proposed = bounds.origin.y + deltaY
        if proposed < topEdge {
            let overshoot = topEdge - proposed
            bounds.origin.y = topEdge - resistedOvershoot(overshoot)
        } else if proposed > bottomEdge {
            let overshoot = proposed - bottomEdge
            bounds.origin.y = bottomEdge + resistedOvershoot(overshoot)
        } else {
            bounds.origin.y = proposed
        }
        delegate?.scrollViewDidScroll?(self)
    }

    func simulateRelease() {
        if bounds.origin.y < topEdge {
            mode = .rubberBand(targetEdge: topEdge,
                               velocity: 0,
                               stiffness: rubberBandStiffness,
                               damping: rubberBandDamping)
        } else if bounds.origin.y > bottomEdge {
            mode = .rubberBand(targetEdge: bottomEdge,
                               velocity: 0,
                               stiffness: rubberBandStiffness,
                               damping: rubberBandDamping)
        }
    }

    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        if animated {
            mode = .programmatic(initialOffsetY: bounds.origin.y,
                                 targetY: contentOffset.y,
                                 startTime: clock.now,
                                 duration: programmaticDuration,
                                 lastEased: 0)
        } else {
            mode = .idle
            super.setContentOffset(contentOffset, animated: false)
        }
    }

    var isActive: Bool {
        if case .idle = mode { return false }
        return true
    }

    func tick(dt: TimeInterval) {
        guard !dt.isZero else { return }
        switch mode {
        case .idle:
            return
        case let .programmatic(initialOffsetY, targetY, startTime, duration, lastEased):
            let elapsed = clock.now - startTime
            let t = max(0, min(1, elapsed / duration))
            let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            let delta = (eased - lastEased) * (targetY - initialOffsetY)
            bounds.origin.y += delta
            delegate?.scrollViewDidScroll?(self)
            if t >= 1.0 {
                mode = .idle
            } else {
                mode = .programmatic(initialOffsetY: initialOffsetY,
                                     targetY: targetY,
                                     startTime: startTime,
                                     duration: duration,
                                     lastEased: eased)
            }
        case let .decelerating(velocity, decel):
            let absV = abs(velocity)
            let stopTime = absV / decel
            let usedDt = min(dt, stopTime)
            let endV = max(0, absV - decel * usedDt) * (velocity >= 0 ? 1 : -1)
            let signedEndV = endV
            let distance = (velocity + signedEndV) / 2 * CGFloat(usedDt)
            bounds.origin.y += distance
            delegate?.scrollViewDidScroll?(self)
            if abs(endV) < 1e-6 {
                mode = .idle
            } else {
                mode = .decelerating(velocity: endV, deceleration: decel)
            }
        case let .rubberBand(target, velocity, stiffness, damping):
            // Critically-damped spring integration: F = -k(x - target) - c·v ; c = 2·sqrt(k)·damping
            let displacement = bounds.origin.y - target
            let c = 2 * sqrt(stiffness) * damping
            let accel = -stiffness * displacement - c * velocity
            let newV = velocity + accel * CGFloat(dt)
            let newY = bounds.origin.y + newV * CGFloat(dt)
            bounds.origin.y = newY
            delegate?.scrollViewDidScroll?(self)
            // Settle when displacement and velocity are both small
            if abs(newY - target) < 0.25 && abs(newV) < 1.0 {
                bounds.origin.y = target
                mode = .idle
            } else {
                mode = .rubberBand(targetEdge: target, velocity: newV, stiffness: stiffness, damping: damping)
            }
        }
    }
}
