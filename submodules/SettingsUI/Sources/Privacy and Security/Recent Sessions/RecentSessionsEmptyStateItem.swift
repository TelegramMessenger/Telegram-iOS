import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AppBundle

final class RecentSessionsEmptyStateItem: ItemListControllerEmptyStateItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
    }
    
    func isEqual(to: ItemListControllerEmptyStateItem) -> Bool {
        if let item = to as? RecentSessionsEmptyStateItem {
            return self.theme === item.theme && self.strings === item.strings
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode {
        if let current = current as? RecentSessionsEmptyStateItemNode {
            current.item = self
            return current
        } else {
            return RecentSessionsEmptyStateItemNode(item: self)
        }
    }
}

final class RecentSessionsEmptyStateItemNode: ItemListControllerEmptyStateItemNode {
    private let imageNode: ASImageNode
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var item: RecentSessionsEmptyStateItem {
        didSet {
            self.updateThemeAndStrings(theme: self.item.theme, strings: self.item.strings)
            if let (layout, navigationHeight) = self.validLayout {
                self.updateLayout(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
            }
        }
    }
    
    init(item: RecentSessionsEmptyStateItem) {
        self.item = item
        
        self.imageNode = ASImageNode()
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.updateThemeAndStrings(theme: self.item.theme, strings: self.item.strings)
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.imageNode.image = generateTintedImage(image: UIImage(bundleImageName: "Settings/RecentSessionsPlaceholder"), color: theme.list.freeTextColor)
        self.titleNode.attributedText = NSAttributedString(string: strings.AuthSessions_EmptyTitle, font: Font.bold(17.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: strings.AuthSessions_EmptyText, font: Font.regular(14.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        var insets = layout.insets(options: [])
        insets.top += navigationBarHeight + 270.0
        
        let imageSpacing: CGFloat = 8.0
        let textSpacing: CGFloat = 8.0
        
        let imageSize = self.imageNode.image?.size ?? CGSize()
        let imageHeight = layout.size.width < layout.size.height ? imageSize.height + imageSpacing : 0.0
        
        var textVisible = true
        if layout.size.width == 320 {
            textVisible = false
        }
                
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - layout.intrinsicInsets.left - layout.intrinsicInsets.right - 50.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        let textSize = self.textNode.measure(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - layout.intrinsicInsets.left - layout.intrinsicInsets.right - 50.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        
        var totalHeight = imageHeight + titleSize.height
        if textVisible {
            totalHeight += textSpacing + textSize.height
        }
        let topOffset = insets.top + floor((layout.size.height - insets.top - insets.bottom - totalHeight) / 2.0)
        
        var visible = true
        if case .compact = layout.metrics.widthClass, layout.size.width > layout.size.height {
            visible = false
        }

        transition.updateAlpha(node: self.imageNode, alpha: visible ? 1.0 : 0.0)
        transition.updateAlpha(node: self.titleNode, alpha: visible ? 1.0 : 0.0)
        transition.updateAlpha(node: self.textNode, alpha: visible && textVisible ? 1.0 : 0.0)
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: topOffset), size: imageSize))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: topOffset + imageHeight), size: titleSize))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: self.titleNode.frame.maxY + textSpacing), size: textSize))
    }
}
