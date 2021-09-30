import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AccountContext

final class StatsEmptyStateItem: ItemListControllerEmptyStateItem {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        self.context = context
        self.theme = theme
        self.strings = strings
    }
    
    func isEqual(to: ItemListControllerEmptyStateItem) -> Bool {
        if let item = to as? StatsEmptyStateItem {
            return self.theme === item.theme && self.strings === item.strings
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode {
        if let current = current as? StatsEmptyStateItemNode {
            current.item = self
            return current
        } else {
            return StatsEmptyStateItemNode(item: self)
        }
    }
}

final class StatsEmptyStateItemNode: ItemListControllerEmptyStateItemNode {
    private var animationNode: AnimatedStickerNode
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var item: StatsEmptyStateItem {
        didSet {
            self.updateThemeAndStrings(theme: self.item.theme, strings: self.item.strings)
            if let (layout, navigationHeight) = self.validLayout {
                self.updateLayout(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
            }
        }
    }
    
    init(item: StatsEmptyStateItem) {
        self.item = item
        
        self.animationNode = AnimatedStickerNode()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "Charts"), width: 192, height: 192, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.updateThemeAndStrings(theme: self.item.theme, strings: self.item.strings)
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.titleNode.attributedText = NSAttributedString(string: strings.Stats_LoadingTitle, font: Font.bold(17.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: strings.Stats_LoadingText, font: Font.regular(14.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        var insets = layout.insets(options: [])
        insets.top += navigationBarHeight
        
        let imageSpacing: CGFloat = 20.0
        let textSpacing: CGFloat = 8.0
    
        let imageSize = CGSize(width: 96.0, height: 96.0)
        let imageHeight = layout.size.width < layout.size.height ? imageSize.height + imageSpacing : 0.0
        
        self.animationNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: -10.0), size: imageSize)
        self.animationNode.updateLayout(size: imageSize)
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - layout.intrinsicInsets.left - layout.intrinsicInsets.right - 50.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        let textSize = self.textNode.measure(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - layout.intrinsicInsets.left - layout.intrinsicInsets.right - 50.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        
        let totalHeight = imageHeight + titleSize.height + textSpacing + textSize.height
        let topOffset = insets.top + floor((layout.size.height - insets.top - insets.bottom - totalHeight) / 2.0)
        
        transition.updateAlpha(node: self.animationNode, alpha: imageHeight > 0.0 ? 1.0 : 0.0)
        transition.updateFrame(node: self.animationNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: topOffset), size: imageSize))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width - layout.safeInsets.left - layout.safeInsets.right - layout.intrinsicInsets.left - layout.intrinsicInsets.right) / 2.0), y: topOffset + imageHeight), size: titleSize))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width - layout.safeInsets.left - layout.safeInsets.right - layout.intrinsicInsets.left - layout.intrinsicInsets.right) / 2.0), y: self.titleNode.frame.maxY + textSpacing), size: textSize))
    }
}
