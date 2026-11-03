import QuartzCore

/// Per-animation completion, copied from Display's `CALayerAnimationDelegate`
/// (`CAAnimationUtils.swift:4`).
///
/// This replaces `CATransaction.setCompletionBlock`, which fires for the whole transaction rather
/// than for the animation you attached it to. Every CoreList completion site adds exactly one
/// animation and wants exactly that animation's completion, so the delegate is both more precise and
/// one less reason to open a transaction.
///
/// `finished` is passed through rather than swallowed: an animation removed or replaced mid-flight
/// reports `false`, which is what lets a generation-guarded completion tell "my animation ended"
/// from "my animation was superseded".
final class CoreListAnimationDelegate: NSObject, CAAnimationDelegate {
    private let keyPath: String?
    private var completion: ((Bool) -> Void)?

    init(animation: CAAnimation, completion: ((Bool) -> Void)?) {
        if let animation = animation as? CABasicAnimation {
            self.keyPath = animation.keyPath
        } else {
            self.keyPath = nil
        }
        self.completion = completion
        super.init()
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let anim = anim as? CABasicAnimation {
            if anim.keyPath != self.keyPath {
                return
            }
        }
        if let completion = self.completion {
            completion(flag)
            self.completion = nil
        }
    }
}

extension CAAnimation {
    /// Attaches `completion` to this animation. The delegate is retained by the animation, and the
    /// animation by the layer, so no further ownership is needed.
    func setCoreListCompletion(_ completion: @escaping (Bool) -> Void) {
        self.delegate = CoreListAnimationDelegate(animation: self, completion: completion)
    }
}
