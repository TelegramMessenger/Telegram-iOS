import Foundation
import UIKit
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
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode
}

class ItemListControllerSearchNode: ASDisplayNode {
    func activate() {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
    }
    
    func deactivate() {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
            self?.removeFromSupernode()
        })
    }
    
    func scrollToTop() {
    }
    
    func queryUpdated(_ query: String) {
    }
    
    func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    }
}

