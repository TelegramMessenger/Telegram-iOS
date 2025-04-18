import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import Display
import AccountContext

final class ChatImportStatusPanel: ASDisplayNode {
    private let labelNode: TextNode
    private let backgroundNode: ASImageNode
    private let secondaryBackgroundNode: ASImageNode
    
    private var theme: PresentationTheme?
    
    override init() {
        self.labelNode = TextNode()
        self.backgroundNode = ASImageNode()
        self.secondaryBackgroundNode = ASImageNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.secondaryBackgroundNode)
        self.addSubnode(self.labelNode)
    }
    
    func update(context: AccountContext, progress: CGFloat, presentationData: ChatPresentationData, width: CGFloat) -> CGFloat {
        if self.theme !== presentationData.theme.theme {
            self.theme = presentationData.theme.theme
            
            let graphics = PresentationResourcesChat.principalGraphics(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, bubbleCorners: presentationData.chatBubbleCorners)
            self.backgroundNode.image = graphics.dateFloatingBackground
            self.secondaryBackgroundNode.image = graphics.dateFloatingBackground
        }
        
        let titleFont = Font.medium(min(18.0, floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0)))
        
        let text = presentationData.strings.Conversation_ImportProgress("\(Int(progress * 100.0))").string
        let attributedString = NSAttributedString(string: text, font: titleFont, textColor: bubbleVariableColor(variableColor: presentationData.theme.theme.chat.serviceMessage.dateTextColor, wallpaper: presentationData.theme.wallpaper))
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        let (labelLayout, apply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 320.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = apply()
        
        let chatDateSize: CGFloat = 20.0
        let chatDateInset: CGFloat = 6.0
        
        let labelSize = labelLayout.size
        let backgroundSize = CGSize(width: labelSize.width + chatDateInset * 2.0, height: chatDateSize)
        
        let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - backgroundSize.width) / 2.0), y: (34.0 - chatDateSize) / 2.0), size: backgroundSize)
        self.backgroundNode.frame = backgroundFrame
        self.secondaryBackgroundNode.frame = CGRect(origin: CGPoint(), size: backgroundFrame.size)
        self.labelNode.frame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + chatDateInset, y: backgroundFrame.origin.y + floorToScreenPixels((backgroundSize.height - labelSize.height) / 2.0)), size: labelSize)
        
        return 28.0
    }
}
