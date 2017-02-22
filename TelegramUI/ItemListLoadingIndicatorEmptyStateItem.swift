import Foundation
import AsyncDisplayKit
import Display

final class ItemListLoadingIndicatorEmptyStateItem: ItemListControllerEmptyStateItem {
    func isEqual(to: ItemListControllerEmptyStateItem) -> Bool {
        return to is ItemListLoadingIndicatorEmptyStateItem
    }
    
    func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode {
        if let current = current as? ItemListLoadingIndicatorEmptyStateItemNode {
            return current
        } else {
            return ItemListLoadingIndicatorEmptyStateItemNode()
        }
    }
}

final class ItemListLoadingIndicatorEmptyStateItemNode: ItemListControllerEmptyStateItemNode {
    private var indicator: UIActivityIndicatorView?
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    override func didLoad() {
        super.didLoad()
        
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        self.indicator = indicator
        self.view.addSubview(indicator)
        if let layout = self.validLayout {
            self.updateLayout(layout: layout.0, navigationBarHeight: layout.1, transition: .immediate)
        }
        indicator.startAnimating()
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        if let indicator = self.indicator {
            self.validLayout = (layout, navigationBarHeight)
            var insets = layout.insets(options: [.statusBar])
            insets.top += navigationBarHeight
            
            let size = indicator.bounds.size
            indicator.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - size.width) / 2.0), y: insets.top + floor((layout.size.height - insets.top - insets.bottom - size.height) / 2.0)), size: size)
        }
    }
}
