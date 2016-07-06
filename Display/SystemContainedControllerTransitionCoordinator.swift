import UIKit

final class SystemContainedControllerTransitionCoordinator:NSObject, UIViewControllerTransitionCoordinator {
    public func isAnimated() -> Bool {
        return false
    }
    
    public func presentationStyle() -> UIModalPresentationStyle {
        return .fullScreen
    }
    
    public func initiallyInteractive() -> Bool {
        return false
    }
    
    public let isInterruptible: Bool = false
    
    public func isInteractive() -> Bool {
        return false
    }
    
    public func isCancelled() -> Bool {
        return false
    }
    
    public func transitionDuration() -> TimeInterval {
        return 0.6
    }
    
    public func percentComplete() -> CGFloat {
        return 0.0
    }
    
    public func completionVelocity() -> CGFloat {
        return 0.0
    }
    
    public func completionCurve() -> UIViewAnimationCurve {
        return .easeInOut
    }
    
    public func viewController(forKey key: String) -> UIViewController? {
        return nil
    }
    
    public func view(forKey key: String) -> UIView? {
        return nil
    }
    
    public func containerView() -> UIView {
        return UIView()
    }
    
    public func targetTransform() -> CGAffineTransform {
        return CGAffineTransform.identity
    }
    
    public func animate(alongsideTransition animation: ((UIViewControllerTransitionCoordinatorContext) -> Swift.Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Swift.Void)? = nil) -> Bool {
        return false
    }
    
    public func animateAlongsideTransition(in view: UIView?, animation: ((UIViewControllerTransitionCoordinatorContext) -> Swift.Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Swift.Void)? = nil) -> Bool {
        return false
    }
    
    public func notifyWhenInteractionEnds(_ handler: (UIViewControllerTransitionCoordinatorContext) -> ()) {
        
    }
    
    public func notifyWhenInteractionChanges(_ handler: (UIViewControllerTransitionCoordinatorContext) -> ()) {
        
    }
}
