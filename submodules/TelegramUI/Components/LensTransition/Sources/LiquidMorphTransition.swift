import UIKit
import LensTransitionRuntime

@available(iOS 26.0, *)
public final class LiquidMorphTransition {
    public init() {}

    public static func sourceVisibilityAssertion(for view: UIView) -> AnyObject? {
        return LTTransitionDriver.visibilityAssertion(for: view) as AnyObject?
    }

    public static var isSupported: Bool {
        return LTTransitionDriver.isSupported()
    }

    public static func sourcePreview(for view: UIView, parameters: UIPreviewParameters, usePresentationTransform: Bool = false) -> UITargetedPreview? {
        guard view.superview != nil, view.window != nil else { return nil }
        // UIKit accounts for an off-center visiblePath and the source transform.
        let preview = UITargetedPreview(view: view, parameters: parameters)
        guard usePresentationTransform else { return preview }
        let transform = view.layer.presentation()?.affineTransform() ?? view.transform
        let target = UIPreviewTarget(container: preview.target.container, center: preview.target.center, transform: transform)
        return preview.retargetedPreview(with: target)
    }

    private var animation: LTTransitionDriver?
    private var generation = 0
    public private(set) var isAnimating = false

    /// A second transition is rejected while one runs, unless `interruptingCurrent` is set:
    /// then it starts at once and UIKit hands it the running morph (the driver passes the
    /// in-flight coordinator as `previousAnimation`). The interrupted transition's completion
    /// still fires, typically together with the new one's, but only the newest transition
    /// clears `isAnimating`.
    @discardableResult
    public func animate(from: UITargetedPreview, to: UITargetedPreview, attachment: CGPoint, in container: UIView, sourceIdentity: UIView? = nil, interruptingCurrent: Bool = false, alongsideAnimations: (() -> Void)? = nil, completion: @escaping () -> Void) -> Bool {
        assert(Thread.isMainThread)
        guard !isAnimating || interruptingCurrent, Self.isSupported, container.window != nil,
              from.target.container.window != nil, to.target.container.window != nil,
              from.view.window != nil, to.view.window != nil,
              from.size.width > 0, from.size.height > 0, to.size.width > 0, to.size.height > 0,
              from.size.width.isFinite, from.size.height.isFinite, to.size.width.isFinite, to.size.height.isFinite,
              attachment.x.isFinite, attachment.y.isFinite else { return false }
        let pivot = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        pivot.layer.cornerRadius = 5
        pivot.overrideUserInterfaceStyle = container.traitCollection.userInterfaceStyle
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        let through = UITargetedPreview(view: pivot, parameters: parameters, target: UIPreviewTarget(container: container, center: attachment))
        guard let animation = LTTransitionDriver(source: from, destination: to, pivot: through, container: container, sourceIdentity: sourceIdentity, alongside: alongsideAnimations) else { return false }
        isAnimating = true
        self.animation = animation
        generation += 1
        let transitionGeneration = generation
        let frameRateClaim = LiquidMorphFrameRateBoost.shared.claim(screen: container.window?.windowScene?.screen)
        let finished = { [self] in
            frameRateClaim.end()
            // UIKit calls our completion before its own cleanup. Hand views back only
            // after that cleanup, keeping the coordinator alive through the callback.
            DispatchQueue.main.async { [self, animation] in
                withExtendedLifetime(animation) {
                    if self.generation == transitionGeneration {
                        self.animation = nil
                        self.isAnimating = false
                    }
                    completion()
                }
            }
        }
        animation.start(completion: finished)
        return true
    }
}

/// Holds the display at 120 Hz while any morph moves, on screens that support it.
///
/// UIKit ticks the morph from its in-process animation manager, not with Core Animation
/// animations, and that manager's display link requests a 48-120 Hz range rather than a fixed
/// rate. On a 120 Hz iPhone the morph visibly ran slower than Telegram's own animations until
/// the rate was pinned (checked on device). CoreList pins its scroll flights the same way
/// (`PhysicsScrollEngine.maxRefreshRange`), after measuring that a range with a low floor let
/// the system throttle to about 80 Hz.
@available(iOS 26.0, *)
private final class LiquidMorphFrameRateBoost {
    /// One morph's hold on the boost. It ends once: at the morph's completion or after
    /// `maximumDuration`, whichever comes first, so a completion UIKit never delivers cannot keep
    /// the display at 120 Hz.
    final class Claim {
        private var isEnded = false

        fileprivate init() {
        }

        func end() {
            assert(Thread.isMainThread)
            if self.isEnded {
                return
            }
            self.isEnded = true
            LiquidMorphFrameRateBoost.shared.release()
        }
    }

    private final class Target: NSObject {
        @objc func tick() {
        }
    }

    /// UIKit reports a morph complete only once every spring has settled, about 1.3 s after an
    /// opening starts and 1.6 s after a close (iOS 27 simulator). The visible motion ends sooner:
    /// recorded at about 0.75 s for an opening and 0.7 s for a close, after which frames differ only
    /// by anti-aliasing noise. One second covers the motion with margin.
    private static let maximumDuration: Double = 1.0

    static let shared = LiquidMorphFrameRateBoost()

    private var displayLink: CADisplayLink?
    private var count = 0

    func claim(screen: UIScreen?) -> Claim {
        assert(Thread.isMainThread)
        self.count += 1
        if self.displayLink == nil, let screen, screen.maximumFramesPerSecond >= 120 {
            let displayLink = CADisplayLink(target: Target(), selector: #selector(Target.tick))
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 120.0, maximum: 120.0, preferred: 120.0)
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }
        let claim = Claim()
        // Holds the claim strongly, so the deadline fires even if the morph is torn down without
        // completing.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maximumDuration) {
            claim.end()
        }
        return claim
    }

    private func release() {
        assert(Thread.isMainThread)
        self.count -= 1
        if self.count == 0, let displayLink = self.displayLink {
            self.displayLink = nil
            displayLink.invalidate()
        }
    }
}
