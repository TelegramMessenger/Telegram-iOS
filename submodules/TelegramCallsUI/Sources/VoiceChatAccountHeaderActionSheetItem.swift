import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AnimatedStickerNode
import AppBundle

public final class VoiceChatAccountHeaderActionSheetItem: ActionSheetItem {
    let title: String
    let text: String
    
    public init(context: AccountContext, title: String, text: String) {
        self.title = title
        self.text = text
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return VoiceChatAccountHeaderActionSheetItemNode(theme: theme, title: self.title, text: self.text)
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class VoiceChatAccountHeaderActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let iconBackgroundNode: ASImageNode
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    init(theme: ActionSheetControllerTheme, title: String, text: String) {
        self.theme = theme
        
        let titleFont = Font.medium(floor(theme.baseFontSize * 13.0 / 17.0))
        let textFont = Font.regular(floor(theme.baseFontSize * 13.0 / 17.0))
        
        self.iconBackgroundNode = ASImageNode()
        self.iconBackgroundNode.displaysAsynchronously = false
        self.iconBackgroundNode.displayWithoutProcessing = true
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        self.titleNode.isAccessibilityElement = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        self.textNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.hasSeparator = false
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.accessibilityArea)
       
        self.titleNode.attributedText = NSAttributedString(string: title, font: titleFont, textColor: theme.primaryTextColor)
        self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: theme.secondaryTextColor)
            
        self.accessibilityArea.accessibilityLabel = text
        self.accessibilityArea.accessibilityTraits = .staticText
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let titleSize = self.titleNode.updateLayout(CGSize(width: constrainedSize.width - 120.0, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedSize.width - 120.0, height: .greatestFiniteMagnitude))
        
        let topInset: CGFloat = 26.0
        let textSpacing: CGFloat = 17.0
        let bottomInset: CGFloat = 15.0
        
        let iconSize = CGSize(width: 72.0, height: 72.0)
        let iconFrame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - iconSize.width) / 2.0), y: topInset), size: iconSize)
        self.iconBackgroundNode.frame = iconFrame
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: iconFrame.minX + floorToScreenPixels((iconSize.width - image.size.width) / 2.0), y: iconFrame.minY + floorToScreenPixels((iconSize.height - image.size.height) / 2.0)), size: image.size)
        }
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - titleSize.width) / 2.0), y: topInset + iconSize.height + textSpacing), size: titleSize)
        
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - textSize.width) / 2.0), y: topInset + iconSize.height + textSpacing + titleSize.height), size: textSize)
        
        let size = CGSize(width: constrainedSize.width, height: topInset + iconSize.height + textSpacing + titleSize.height + textSize.height + bottomInset)
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
               
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
