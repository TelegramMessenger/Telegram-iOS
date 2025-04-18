import Foundation
import UIKit
import AsyncDisplayKit
import Display

public protocol ItemListControllerEmptyStateItem {
    func isEqual(to: ItemListControllerEmptyStateItem) -> Bool
    func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode
}

open class ItemListControllerEmptyStateItemNode: ASDisplayNode {
    open func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    }
}
