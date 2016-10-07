import UIKit

final class SystemContainedControllerTransitionCoordinator: NSObject, UIViewControllerTransitionCoordinator {
    public var isAnimated: Bool {
        return false
    }
    
    public var presentationStyle: UIModalPresentationStyle {
        return .fullScreen
    }
    
    public var initiallyInteractive: Bool {
        return false
    }
    
    public let isInterruptible: Bool = false
    
    public var isInteractive: Bool {
        return false
    }
    
    public var isCancelled: Bool {
        return false
    }
    
    public var transitionDuration: TimeInterval {
        return 0.6
    }
    
    public var percentComplete: CGFloat {
        return 0.0
    }
    
    public var completionVelocity: CGFloat {
        return 0.0
    }
    
    public var completionCurve: UIViewAnimationCurve {
        return .easeInOut
    }
    
    public func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? {
        return nil
    }
    
    public func view(forKey key: UITransitionContextViewKey) -> UIView? {
        return nil
    }
    
    public var containerView: UIView {
        return UIView()
    }
    
    public var targetTransform: CGAffineTransform {
        return CGAffineTransform.identity
    }
    
    public func animate(alongsideTransition animation: ((UIViewControllerTransitionCoordinatorContext) -> Swift.Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Swift.Void)? = nil) -> Bool {
        return false
    }
    
    public func animateAlongsideTransition(in view: UIView?, animation: ((UIViewControllerTransitionCoordinatorContext) -> Swift.Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Swift.Void)? = nil) -> Bool {
        return false
    }
    
    public func notifyWhenInteractionEnds(_ handler: @escaping (UIViewControllerTransitionCoordinatorContext) -> ()) {
        
    }
    
    public func notifyWhenInteractionChanges(_ handler: @escaping (UIViewControllerTransitionCoordinatorContext) -> ()) {
        
    }
}
