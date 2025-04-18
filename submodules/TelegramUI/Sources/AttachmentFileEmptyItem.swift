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
import SolidRoundedButtonNode

final class AttachmentFileEmptyStateItem: ItemListControllerEmptyStateItem {
    enum Content: Equatable {
        case intro
        case bannedSendMedia(text: String, canBoost: Bool)
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
    private let buttonNode: SolidRoundedButtonNode
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
        
        let name: String
        let playbackMode: AnimatedStickerPlaybackMode
        switch item.content {
        case .intro:
            name = "Files"
            playbackMode = .loop
        case .bannedSendMedia:
            name = "Banned"
            playbackMode = .once
        }
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: name), width: 320, height: 320, playbackMode: playbackMode, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), height: 50.0, cornerRadius: 11.0, gloss: true)
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.textNode)
        
        self.updateThemeAndStrings(theme: self.item.theme, strings: self.item.strings)
        
        if case .bannedSendMedia(_, true) = item.content {
            self.addSubnode(self.buttonNode)
        }
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        let text: String
        switch self.item.content {
            case .intro:
                text = strings.Attachment_FilesIntro
            case let .bannedSendMedia(banDescription, _):
                text = banDescription
        }
        self.textNode.attributedText = NSAttributedString(string: text.replacingOccurrences(of: "\n", with: " "), font: Font.regular(15.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        self.buttonNode.title = strings.Attachment_OpenSettings
        self.buttonNode.updateTheme(SolidRoundedButtonTheme(theme: theme))
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
      
        var imageSize = CGSize(width: 144.0, height: 144.0)
        var insets = layout.insets(options: [])
        if layout.size.width == 320.0 {
            insets.top += -60.0
            imageSize = CGSize(width: 112.0, height: 112.0)
        } else {
            insets.top += -160.0
        }
        
        let imageSpacing: CGFloat = 12.0
        let textSpacing: CGFloat = 12.0
        let buttonSpacing: CGFloat = 15.0
        let bottomSpacing: CGFloat = 33.0
        
        let imageHeight = layout.size.width < layout.size.height ? imageSize.height + imageSpacing : 0.0
        
        let buttonWidth: CGFloat = 248.0
        let buttonHeight = self.buttonNode.updateLayout(width: buttonWidth, transition: transition)
        
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 40.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        
        let totalHeight = imageHeight + textSpacing + textSize.height + buttonSpacing + buttonHeight + bottomSpacing
        let topOffset = insets.top + floor((layout.size.height - insets.top - insets.bottom - totalHeight) / 2.0)
        
        transition.updateAlpha(node: self.animationNode, alpha: imageHeight > 0.0 ? 1.0 : 0.0)
        transition.updateFrame(node: self.animationNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: topOffset), size: imageSize))
        self.animationNode.updateLayout(size: imageSize)
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layout.size.width - textSize.width - layout.safeInsets.left - layout.safeInsets.right) / 2.0), y: topOffset + imageHeight + textSpacing), size: textSize))
        
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layout.size.width - buttonWidth - layout.safeInsets.left - layout.safeInsets.right) / 2.0), y: self.textNode.frame.maxY + buttonSpacing), size: CGSize(width: buttonWidth, height: buttonHeight)))
    }
}
