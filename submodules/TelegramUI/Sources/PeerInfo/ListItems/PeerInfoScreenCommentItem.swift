import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextFormat
import Markdown

final class PeerInfoScreenCommentItem: PeerInfoScreenItem {
    let id: AnyHashable
    let text: String
    
    init(id: AnyHashable, text: String) {
        self.id = id
        self.text = text
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenCommentItemNode()
    }
}

private final class PeerInfoScreenCommentItemNode: PeerInfoScreenItemNode {
    private let textNode: ImmediateTextNode
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenCommentItem?
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = .staticText
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.activateArea)
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenCommentItem else {
            return 10.0
        }
        
        self.item = item
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        let verticalInset: CGFloat = 7.0
        
        self.textNode.maximumNumberOfLines = 0
        
        let textFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
        let textColor = presentationData.theme.list.freeTextColor
        
        let attributedText = parseMarkdownIntoAttributedString(item.text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: textFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: presentationData.theme.list.itemAccentColor), linkAttribute: { contents in
            return (TelegramTextAttributes.URL, contents)
        }))
        
        self.textNode.attributedText = attributedText
        self.activateArea.accessibilityLabel = attributedText.string
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: textSize)
        
        let height = textSize.height + verticalInset * 2.0
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        self.activateArea.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        
        return height
    }
}
