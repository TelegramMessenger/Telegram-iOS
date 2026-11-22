import UIKit
import QuartzCore

extension CALayer {
    /// Executor-path animation: built through the shared factory, so it emits exactly what the model
    /// path and the rest of the app emit — a `CABasicAnimation` with a `CAMediaTimingFunction` for
    /// bezier curves, a real `CASpringAnimation` for the two system-spring durations. Nothing here
    /// samples a curve into keyframes any more.
    ///
    /// Slow Animations is applied HERE, exactly once, as `speed` — mirroring Display's
    /// `CAAnimationUtils`. The model path applies it in `ListAnimationController` and never reaches
    /// this function.
    ///
    /// The spring kind is resolved from the LOGICAL `duration`, before scaling — resolving it after
    /// would miss the system-spring branches under Slow Animations.
    func animate(from: CGFloat,
                 to: CGFloat,
                 keyPath: String,
                 duration: Double,
                 delay: Double = 0.0,
                 curve: CoreListTransition.Animation.Curve,
                 removeOnCompletion: Bool = true,
                 additive: Bool = false,
                 completion: ((Bool) -> Void)? = nil,
                 key: String? = nil) {
        let factor = UIView.animationDurationFactor
        guard duration > 0 else {
            completion?(true)
            return
        }

        let springKind = coreListSpringKind(logicalDuration: duration)
        let animation = makeCoreListAnimation(from: from, to: to, keyPath: keyPath, curve: curve,
                                              springKind: springKind,
                                              logicalDuration: duration, durationFactor: factor,
                                              additive: additive)
        animation.isRemovedOnCompletion = removeOnCompletion
        if !delay.isZero {
            animation.beginTime = convertTime(CACurrentMediaTime(), from: nil) + delay * factor
            animation.fillMode = .both
        }
        animation.preferHighRefreshRate()
        if let completion {
            animation.setCoreListCompletion(completion)
        }
        self.add(animation, forKey: key ?? keyPath)
    }
}
