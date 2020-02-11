import AsyncDisplayKit
import Display
import TelegramPresentationData

enum PeerInfoScreenLabeledValueTextColor {
    case primary
    case accent
}

enum PeerInfoScreenLabeledValueTextBehavior: Equatable {
    case singleLine
    case multiLine(maxLines: Int)
}

final class PeerInfoScreenLabeledValueItem: PeerInfoScreenItem {
    let id: AnyHashable
    let label: String
    let text: String
    let textColor: PeerInfoScreenLabeledValueTextColor
    let textBehavior: PeerInfoScreenLabeledValueTextBehavior
    let action: (() -> Void)?
    
    init(id: AnyHashable, label: String, text: String, textColor: PeerInfoScreenLabeledValueTextColor = .primary, textBehavior: PeerInfoScreenLabeledValueTextBehavior = .singleLine, action: (() -> Void)?) {
        self.id = id
        self.label = label
        self.text = text
        self.textColor = textColor
        self.textBehavior = textBehavior
        self.action = action
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenLabeledValueItemNode()
    }
}

private final class PeerInfoScreenLabeledValueItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let labelNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var item: PeerInfoScreenLabeledValueItem?
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        super.init()
        
        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }
        
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.textNode)
    }
    
    override func update(width: CGFloat, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenLabeledValueItem else {
            return 10.0
        }
        
        self.item = item
        
        self.selectionNode.pressed = item.action
        
        let sideInset: CGFloat = 16.0
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let textColorValue: UIColor
        switch item.textColor {
        case .primary:
            textColorValue = presentationData.theme.list.itemPrimaryTextColor
        case .accent:
            textColorValue = presentationData.theme.list.itemAccentColor
        }
        
        self.labelNode.attributedText = NSAttributedString(string: item.label, font: Font.regular(14.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
        
        switch item.textBehavior {
        case .singleLine:
            self.textNode.maximumNumberOfLines = 1
        case let .multiLine(maxLines):
            self.textNode.maximumNumberOfLines = maxLines
        }
        self.textNode.attributedText = NSAttributedString(string: item.text, font: Font.regular(17.0), textColor: textColorValue)
        
        let labelSize = self.labelNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        let labelFrame = CGRect(origin: CGPoint(x: sideInset, y: 11.0), size: labelSize)
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: labelFrame.maxY + 3.0), size: textSize)
        
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let height = labelSize.height + 3.0 + textSize.height + 22.0
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        return height
    }
}
