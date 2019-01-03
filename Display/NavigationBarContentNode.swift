import Foundation
import AsyncDisplayKit

public enum NavigationBarContentMode {
    case replacement
    case expansion
}

open class NavigationBarContentNode: ASDisplayNode {
    open var requestContainerLayout: (ContainedViewLayoutTransition) -> Void = { _ in }
    
    open var height: CGFloat {
        return self.nominalHeight
    }
    
    open var nominalHeight: CGFloat {
        return 0.0
    }
    
    open var mode: NavigationBarContentMode {
        return .replacement
    }
}
