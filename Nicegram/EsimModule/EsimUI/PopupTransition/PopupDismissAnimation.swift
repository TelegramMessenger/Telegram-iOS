import UIKit

@available(iOS 10.0, *)
class PopupDismissAnimation: NSObject {
    
    //  MARK: - Logic
    
    private let animationDuration: TimeInterval
    private let minimumScale: CGFloat = 0.01
    
    //  MARK: - Lifecycle
    
    init(animationDuration: TimeInterval) {
        self.animationDuration = animationDuration
    }
    
    //  MARK: - Private Functions
    
    private func animator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        let from = transitionContext.view(forKey: .from)!
        let animator = UIViewPropertyAnimator(duration: animationDuration, curve: .easeOut) {
            from.transform = CGAffineTransform(scaleX: self.minimumScale, y: self.minimumScale)
        }
        
        animator.addCompletion { (position) in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
        return animator
    }
}

@available(iOS 10.0, *)
extension PopupDismissAnimation: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animationDuration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let animator = animator(using: transitionContext)
        animator.startAnimation()
    }
}
