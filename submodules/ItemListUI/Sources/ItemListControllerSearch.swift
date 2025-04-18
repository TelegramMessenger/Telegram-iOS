import Foundation
import UIKit
import AsyncDisplayKit
import Display

public protocol ItemListControllerSearchNavigationContentNode {
    func activate()
    func deactivate()
    
    func setQueryUpdated(_ f: @escaping (String) -> Void)
}

public protocol ItemListControllerSearch {
    func isEqual(to: ItemListControllerSearch) -> Bool
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode
}

open class ItemListControllerSearchNode: ASDisplayNode {
    open func activate() {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
    }
    
    open func deactivate() {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
            self?.removeFromSupernode()
        })
    }
    
    open func scrollToTop() {
    }
    
    open func queryUpdated(_ query: String) {
    }
    
    open func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    }
}

