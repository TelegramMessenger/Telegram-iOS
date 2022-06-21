import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode

public final class ReportPeerHeaderActionSheetItem: ActionSheetItem {
    let context: AccountContext
    let text: String
    
    public init(context: AccountContext, text: String) {
        self.context = context
        self.text = text
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ReportPeerHeaderActionSheetItemNode(theme: theme, context: self.context, text: self.text)
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class ReportPeerHeaderActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let animationNode: AnimatedStickerNode
    private let textNode: ImmediateTextNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    init(theme: ActionSheetControllerTheme, context: AccountContext, text: String) {
        self.theme = theme
        
        let textFont = Font.regular(floor(theme.baseFontSize * 13.0 / 17.0))
        
        self.animationNode = AnimatedStickerNode()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "Cop"), width: 192, height: 192, playbackMode: .count(2), mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        self.textNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.hasSeparator = false
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.accessibilityArea)
       
        let attributedText = NSAttributedString(string: text, font: textFont, textColor: theme.primaryTextColor)
        self.textNode.attributedText = attributedText
            
        self.accessibilityArea.accessibilityLabel = attributedText.string
        self.accessibilityArea.accessibilityTraits = .staticText
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedSize.width - 120.0, height: .greatestFiniteMagnitude))
        
        let topInset: CGFloat = 26.0
        let textSpacing: CGFloat = 17.0
        let bottomInset: CGFloat = 15.0
        
        let iconSize = CGSize(width: 96.0, height: 96.0)
        self.animationNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - iconSize.width) / 2.0), y: topInset), size: iconSize)
        self.animationNode.updateLayout(size: iconSize)
        
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - textSize.width) / 2.0), y: topInset + iconSize.height + textSpacing), size: textSize)
        
        let size = CGSize(width: constrainedSize.width, height: topInset + iconSize.height + textSpacing + textSize.height + bottomInset)
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
               
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
