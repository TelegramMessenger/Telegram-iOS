import Foundation
import AsyncDisplayKit
import Display

final class AuthorizationSequenceSplashControllerNode: ASDisplayNode {
    override init() {
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = UIColor.white
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    }
}
