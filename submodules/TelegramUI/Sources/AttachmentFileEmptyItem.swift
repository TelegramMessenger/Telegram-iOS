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

final class AttachmentFileEmptyStateItem: ItemListControllerEmptyStateItem {
    enum Content: Equatable {
        case intro
        case bannedSendMedia(String)
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let content: Content
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, content: Content) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.content = content
    }
    
    func isEqual(to: ItemListControllerEmptyStateItem) -> Bool {
        if let item = to as? AttachmentFileEmptyStateItem {
            return self.theme === item.theme && self.strings === item.strings && self.content == item.content
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode {
        if let current = current as? AttachmentFileEmptyStateItemNode {
            current.item = self
            return current
        } else {
            return AttachmentFileEmptyStateItemNode(item: self)
        }
    }
}

final class AttachmentFileEmptyStateItemNode: ItemListControllerEmptyStateItemNode {
    private var animationNode: AnimatedStickerNode
    private let textNode: ASTextNode
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var item: AttachmentFileEmptyStateItem {
        didSet {
            self.updateThemeAndStrings(theme: self.item.theme, strings: self.item.strings)
            if let (layout, navigationHeight) = self.validLayout {
                self.updateLayout(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
            }
        }
    }
    
    init(item: AttachmentFileEmptyStateItem) {
        self.item = item
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "Files"), width: 320, height: 320, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.textNode)
        
        self.updateThemeAndStrings(theme: self.item.theme, strings: self.item.strings)
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        let text: String
        switch self.item.content {
            case .intro:
                text = strings.Attachment_FilesIntro
            case let .bannedSendMedia(banDescription):
                text = banDescription
        }
        self.textNode.attributedText = NSAttributedString(string: text.replacingOccurrences(of: "\n", with: " "), font: Font.regular(15.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        var insets = layout.insets(options: [])
        insets.top += navigationBarHeight

        let imageSpacing: CGFloat = 12.0
        
        var imageSize = CGSize(width: 144.0, height: 144.0)
        if layout.size.width == 320.0 {
            imageSize = CGSize(width: 112.0, height: 112.0)
        }
        
        let imageHeight = layout.size.width < layout.size.height ? imageSize.height + imageSpacing : 0.0
        if !imageHeight.isZero {
            if case .intro = self.item.content {
                insets.top -= 92.0
            } else {
                insets.top -= 160.0
            }
        }
        
        if layout.size.width == 320.0 {
            insets.top += 110.0
        }
         
        let textSize = self.textNode.measure(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 70.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        
        let totalHeight = imageHeight + textSize.height
        let topOffset = insets.top + floor((layout.size.height - insets.top - insets.bottom - totalHeight) / 2.0)
        
        transition.updateAlpha(node: self.animationNode, alpha: imageHeight > 0.0 ? 1.0 : 0.0)
        transition.updateFrame(node: self.animationNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: topOffset), size: imageSize))
        self.animationNode.updateLayout(size: imageSize)
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layout.size.width - textSize.width - layout.safeInsets.left - layout.safeInsets.right) / 2.0), y: topOffset + imageHeight), size: textSize))
    }
}
