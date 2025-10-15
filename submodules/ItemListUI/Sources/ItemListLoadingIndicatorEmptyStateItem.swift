import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ActivityIndicator

public final class ItemListLoadingIndicatorEmptyStateItem: ItemListControllerEmptyStateItem {
    let theme: PresentationTheme
    
    public init(theme: PresentationTheme) {
        self.theme = theme
    }
    
    public func isEqual(to: ItemListControllerEmptyStateItem) -> Bool {
        return to is ItemListLoadingIndicatorEmptyStateItem
    }
    
    public func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode {
        if let current = current as? ItemListLoadingIndicatorEmptyStateItemNode {
            current.theme = self.theme
            return current
        } else {
            return ItemListLoadingIndicatorEmptyStateItemNode(theme: self.theme)
        }
    }
}

public final class ItemListLoadingIndicatorEmptyStateItemNode: ItemListControllerEmptyStateItemNode {
    public var theme: PresentationTheme {
        didSet {
            self.indicator.type = .custom(self.theme.list.itemAccentColor, 40.0, 2.0, false)
        }
    }
    private let indicator: ActivityIndicator
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    public init(theme: PresentationTheme) {
        self.theme = theme
        self.indicator = ActivityIndicator(type: .custom(theme.list.itemAccentColor, 22.0, 2.0, false))
        
        super.init()
        
        self.addSubnode(self.indicator)
    }
    
    override public func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar])
        insets.top += navigationBarHeight
        
        let size = CGSize(width: 22.0, height: 22.0)
        transition.updateFrame(node: self.indicator, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - size.width) / 2.0), y: insets.top + floor((layout.size.height - insets.top - insets.bottom - size.height) / 2.0)), size: size))
    }
}
