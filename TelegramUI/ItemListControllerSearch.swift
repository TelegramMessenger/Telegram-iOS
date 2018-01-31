import Foundation
import AsyncDisplayKit
import Display

protocol ItemListControllerSearchNavigationContentNode {
    func activate()
    func deactivate()
    
    func setQueryUpdated(_ f: @escaping (String) -> Void)
}

protocol ItemListControllerSearch {
    func isEqual(to: ItemListControllerSearch) -> Bool
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode
    func node(current: ItemListControllerSearchNode?) -> ItemListControllerSearchNode
}

class ItemListControllerSearchNode: ASDisplayNode {
    func queryUpdated(_ query: String) {
        
    }
    
    func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
    }
}

