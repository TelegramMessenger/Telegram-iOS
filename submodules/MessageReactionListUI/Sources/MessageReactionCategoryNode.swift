import Foundation
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramCore
import SyncCore

final class MessageReactionCategoryNode: ASDisplayNode {
    let category: MessageReactionListCategory
    private let action: () -> Void
    
    private let buttonNode: HighlightableButtonNode
    private let highlightedBackgroundNode: ASImageNode
    private let iconNode: ASImageNode
    private let emojiNode: ImmediateTextNode
    private let countNode: ImmediateTextNode
    
    var isSelected = false {
        didSet {
            self.highlightedBackgroundNode.alpha = self.isSelected ? 1.0 : 0.0
        }
    }
    
    init(theme: PresentationTheme, category: MessageReactionListCategory, count: Int, action: @escaping () -> Void) {
        self.category = category
        self.action = action
        
        self.buttonNode = HighlightableButtonNode()
        
        self.highlightedBackgroundNode = ASImageNode()
        self.highlightedBackgroundNode.displaysAsynchronously = false
        self.highlightedBackgroundNode.displayWithoutProcessing = true
        self.highlightedBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: UIColor(rgb: 0xe6e6e8))
        self.highlightedBackgroundNode.alpha = 1.0
        
        self.iconNode = ASImageNode()
        
        self.emojiNode = ImmediateTextNode()
        self.emojiNode.displaysAsynchronously = false
        let emojiText: String
        switch category {
        case .all:
            emojiText = ""
            self.iconNode.image = PresentationResourcesChat.chatInputTextFieldTimerImage(theme)
        case let .reaction(value):
            emojiText = value
        }
        self.emojiNode.attributedText = NSAttributedString(string: emojiText, font: Font.regular(18.0), textColor: .black)
        
        self.countNode = ImmediateTextNode()
        self.countNode.displaysAsynchronously = false
        self.countNode.attributedText = NSAttributedString(string: "\(count)", font: Font.regular(16.0), textColor: .black)
        
        super.init()
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.emojiNode)
        self.addSubnode(self.countNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateLayout() -> CGSize {
        let sideInset: CGFloat = 6.0
        let spacing: CGFloat = 2.0
        let emojiSize = self.emojiNode.updateLayout(CGSize(width: 100.0, height: 100.0))
        let iconSize = self.iconNode.image?.size ?? CGSize()
        let countSize = self.countNode.updateLayout(CGSize(width: 100.0, height: 100.0))
        
        let height: CGFloat = 60.0
        let backgroundHeight: CGFloat = 36.0
        
        self.emojiNode.frame = CGRect(origin: CGPoint(x: sideInset, y: floor((height - emojiSize.height) / 2.0)), size: emojiSize)
        self.iconNode.frame = CGRect(origin: CGPoint(x: sideInset, y: floor((height - iconSize.height) / 2.0)), size: iconSize)
        
        let iconFrame: CGRect
        if self.iconNode.image != nil {
            iconFrame = self.iconNode.frame
        } else {
            iconFrame = self.emojiNode.frame
        }
        
        self.countNode.frame = CGRect(origin: CGPoint(x: iconFrame.maxX + spacing, y: floor((height - countSize.height) / 2.0)), size: countSize)
        let contentWidth = sideInset * 2.0 + spacing + iconFrame.width + countSize.width
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((height - backgroundHeight) / 2.0)), size: CGSize(width: contentWidth, height: backgroundHeight))
        
        let size = CGSize(width: contentWidth, height: height)
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        return size
    }
    
    @objc private func buttonPressed() {
        self.action()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.buttonNode.frame.contains(point) {
            return self.buttonNode.view
        }
        return nil
    }
}
