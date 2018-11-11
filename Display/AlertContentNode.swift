import Foundation
import AsyncDisplayKit

open class AlertContentNode: ASDisplayNode {
    open var dismissOnOutsideTap: Bool {
        return true
    }
    
    open func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        assertionFailure()
        
        return CGSize()
    }
}
