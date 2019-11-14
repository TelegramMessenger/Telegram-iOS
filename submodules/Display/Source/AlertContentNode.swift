import Foundation
import UIKit
import AsyncDisplayKit

open class AlertContentNode: ASDisplayNode {
    open var requestLayout: ((ContainedViewLayoutTransition) -> Void)?
    
    open var dismissOnOutsideTap: Bool {
        return true
    }
    
    open func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        assertionFailure()
        
        return CGSize()
    }
    
    open func updateTheme(_ theme: AlertControllerTheme) {
        
    }
}
