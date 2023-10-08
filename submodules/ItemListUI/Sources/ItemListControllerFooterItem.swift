import Foundation
import UIKit
import AsyncDisplayKit
import Display

public protocol ItemListControllerFooterItem {
    func isEqual(to: ItemListControllerFooterItem) -> Bool
    func node(current: ItemListControllerFooterItemNode?) -> ItemListControllerFooterItemNode
}

open class ItemListControllerFooterItemNode: ASDisplayNode {
    open func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        return 0.0
    }
    
    open func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        
    }
}


public protocol ItemListControllerHeaderItem {
    func isEqual(to: ItemListControllerHeaderItem) -> Bool
    func node(current: ItemListControllerHeaderItemNode?) -> ItemListControllerHeaderItemNode
}

open class ItemListControllerHeaderItemNode: ASDisplayNode {
    open func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        return 0.0
    }
    
    open func updateContentOffset(_ contentOffset: CGFloat, transition: ContainedViewLayoutTransition) {
        
    }
}
