import Foundation
import UIKit
import AsyncDisplayKit
import Display

protocol ItemListControllerEmptyStateItem {
    func isEqual(to: ItemListControllerEmptyStateItem) -> Bool
    func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode
}

class ItemListControllerEmptyStateItemNode: ASDisplayNode {
    func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    }
}
