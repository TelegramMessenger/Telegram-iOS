import Foundation
import AsyncDisplayKit
import Display

final class AuthorizationSequenceSplashControllerNode: ASDisplayNode {
    init(theme: AuthorizationTheme) {
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = theme.backgroundColor
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    }
}
