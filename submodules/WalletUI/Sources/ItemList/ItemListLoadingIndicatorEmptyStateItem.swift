import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ActivityIndicator

final class ItemListLoadingIndicatorEmptyStateItem: ItemListControllerEmptyStateItem {
    let theme: WalletTheme
    
    init(theme: WalletTheme) {
        self.theme = theme
    }
    
    func isEqual(to: ItemListControllerEmptyStateItem) -> Bool {
        return to is ItemListLoadingIndicatorEmptyStateItem
    }
    
    func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode {
        if let current = current as? ItemListLoadingIndicatorEmptyStateItemNode {
            current.theme = self.theme
            return current
        } else {
            return ItemListLoadingIndicatorEmptyStateItemNode(theme: self.theme)
        }
    }
}

final class ItemListLoadingIndicatorEmptyStateItemNode: ItemListControllerEmptyStateItemNode {
    var theme: WalletTheme {
        didSet {
            self.indicator.type = .custom(self.theme.list.itemAccentColor, 40.0, 2.0, false)
        }
    }
    private let indicator: ActivityIndicator
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    init(theme: WalletTheme) {
        self.theme = theme
        self.indicator = ActivityIndicator(type: .custom(theme.list.itemAccentColor, 22.0, 2.0, false))
        
        super.init()
        
        self.addSubnode(self.indicator)
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar])
        insets.top += navigationBarHeight
        
        let size = CGSize(width: 22.0, height: 22.0)
        transition.updateFrame(node: self.indicator, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - size.width) / 2.0), y: insets.top + floor((layout.size.height - insets.top - insets.bottom - size.height) / 2.0)), size: size))
    }
}
