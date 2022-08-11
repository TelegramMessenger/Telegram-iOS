import UIKit

@available(iOS 10.0, *)
class PopupPresentAnimation: NSObject {
    
    //  MARK: - Logic
    
    private let animationDuration: TimeInterval
    private let minimumScale: CGFloat = 0.01
    
    //  MARK: - Lifecycle
    
    init(animationDuration: TimeInterval) {
        self.animationDuration = animationDuration
    }
    
    //  MARK: - Private Functions
    
    private func animator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        let to = transitionContext.view(forKey: .to)!
        to.transform = CGAffineTransform(scaleX: minimumScale, y: minimumScale)
        let animator = UIViewPropertyAnimator(duration: animationDuration, curve: .easeOut) {
            to.transform = .identity
        }
        
        animator.addCompletion { (position) in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
        return animator
    }
}

@available(iOS 10.0, *)
extension PopupPresentAnimation: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animationDuration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let animator = animator(using: transitionContext)
        animator.startAnimation()
    }
}
