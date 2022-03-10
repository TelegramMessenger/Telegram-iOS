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

final class InviteRequestsEmptyStateItem: ItemListControllerEmptyStateItem {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let isGroup: Bool
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, isGroup: Bool) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.isGroup = isGroup
    }
    
    func isEqual(to: ItemListControllerEmptyStateItem) -> Bool {
        if let item = to as? InviteRequestsEmptyStateItem {
            return self.theme === item.theme && self.strings === item.strings && self.isGroup == item.isGroup
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode {
        if let current = current as? InviteRequestsEmptyStateItemNode {
            current.item = self
            return current
        } else {
            return InviteRequestsEmptyStateItemNode(item: self)
        }
    }
}

final class InviteRequestsEmptyStateItemNode: ItemListControllerEmptyStateItemNode {
    private var animationNode: AnimatedStickerNode
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var item: InviteRequestsEmptyStateItem {
        didSet {
            self.updateThemeAndStrings(theme: self.item.theme, strings: self.item.strings)
            if let (layout, navigationHeight) = self.validLayout {
                self.updateLayout(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
            }
        }
    }
    
    init(item: InviteRequestsEmptyStateItem) {
        self.item = item
        
        self.animationNode = AnimatedStickerNode()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "TwoFactorSetupRememberSuccess"), width: 192, height: 192, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.updateThemeAndStrings(theme: self.item.theme, strings: self.item.strings)
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.titleNode.attributedText = NSAttributedString(string: strings.MemberRequests_NoRequests, font: Font.bold(17.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: self.item.isGroup ? strings.MemberRequests_NoRequestsDescriptionGroup : strings.MemberRequests_NoRequestsDescriptionChannel, font: Font.regular(14.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        var insets = layout.insets(options: [])
        insets.top += navigationBarHeight
        
        let imageSpacing: CGFloat = 10.0
        let textSpacing: CGFloat = 8.0
    
        let imageSize = CGSize(width: 112.0, height: 112.0)
        let imageHeight = layout.size.width < layout.size.height ? imageSize.height + imageSpacing : 0.0
        
        self.animationNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: -10.0), size: imageSize)
        self.animationNode.updateLayout(size: imageSize)
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - layout.intrinsicInsets.left - layout.intrinsicInsets.right - 50.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        let textSize = self.textNode.measure(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - layout.intrinsicInsets.left - layout.intrinsicInsets.right - 50.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        
        let totalHeight = imageHeight + titleSize.height + textSpacing + textSize.height
        let topOffset = insets.top + floor((layout.size.height - insets.top - insets.bottom - totalHeight) / 2.0)
        
        transition.updateAlpha(node: self.animationNode, alpha: imageHeight > 0.0 ? 1.0 : 0.0)
        transition.updateFrame(node: self.animationNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: topOffset), size: imageSize))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + layout.intrinsicInsets.left + floor((layout.size.width - titleSize.width - layout.safeInsets.left - layout.safeInsets.right - layout.intrinsicInsets.left - layout.intrinsicInsets.right) / 2.0), y: topOffset + imageHeight), size: titleSize))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + layout.intrinsicInsets.left + floor((layout.size.width - textSize.width - layout.safeInsets.left - layout.safeInsets.right - layout.intrinsicInsets.left - layout.intrinsicInsets.right) / 2.0), y: self.titleNode.frame.maxY + textSpacing), size: textSize))
    }
}
