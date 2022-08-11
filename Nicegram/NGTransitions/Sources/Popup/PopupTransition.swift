import UIKit

public class PopupTransition: NSObject {
    
    //  MARK: - Logic
    
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    
    private let blurStyle: UIBlurEffect.Style
    
    private let transitionDuration: TimeInterval
    
    //  MARK: - Lifecycle
    
    public init(horizontalPadding: CGFloat = 16, verticalPadding: CGFloat = 16, blurStyle: UIBlurEffect.Style, transitionDuration: TimeInterval = 0.2) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.blurStyle = blurStyle
        self.transitionDuration = transitionDuration
    }
}

@available(iOS 10.0, *)
extension PopupTransition: UIViewControllerTransitioningDelegate {
    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return PopupPresentationController(presentedViewController: presented, presenting: presenting, horizontalPadding: horizontalPadding, verticalPadding: verticalPadding, blurStyle: blurStyle)
    }
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PopupPresentAnimation(animationDuration: transitionDuration)
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PopupDismissAnimation(animationDuration: transitionDuration)
    }
}
