import AsyncDisplayKit
import Display
import TelegramPresentationData

enum PeerInfoScreenActionColor {
    case accent
    case destructive
}

enum PeerInfoScreenActionAligmnent {
    case natural
    case center
}

final class PeerInfoScreenActionItem: PeerInfoScreenItem {
    let id: AnyHashable
    let text: String
    let color: PeerInfoScreenActionColor
    let icon: UIImage?
    let alignment: PeerInfoScreenActionAligmnent
    let action: (() -> Void)?
    
    init(id: AnyHashable, text: String, color: PeerInfoScreenActionColor = .accent, icon: UIImage? = nil, alignment: PeerInfoScreenActionAligmnent = .natural, action: (() -> Void)?) {
        self.id = id
        self.text = text
        self.color = color
        self.icon = icon
        self.alignment = alignment
        self.action = action
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenActionItemNode()
    }
}

private final class PeerInfoScreenActionItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let iconNode: ASImageNode
    private let textNode: ImmediateTextNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var item: PeerInfoScreenActionItem?
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        
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
        self.addSubnode(self.textNode)
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenActionItem else {
            return 10.0
        }
        
        self.item = item
        
        self.selectionNode.pressed = item.action
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        let leftInset = (item.icon == nil ? sideInset : sideInset + 29.0 + 16.0)
        let rightInset = sideInset
        let separatorInset = item.icon == nil ? sideInset : leftInset - 1.0
        let titleFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let textColorValue: UIColor
        switch item.color {
        case .accent:
            textColorValue = presentationData.theme.list.itemAccentColor
        case .destructive:
            textColorValue = presentationData.theme.list.itemDestructiveColor
        }
        
        self.textNode.maximumNumberOfLines = 1
        self.textNode.attributedText = NSAttributedString(string: item.text, font: titleFont, textColor: textColorValue)
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - (leftInset + rightInset), height: .greatestFiniteMagnitude))
        
        let textFrame = CGRect(origin: CGPoint(x: item.alignment == .center ? floorToScreenPixels((width - textSize.width) / 2.0) : leftInset, y: 12.0), size: textSize)
        
        let height = textSize.height + 24.0
        
        if let icon = item.icon {
            if self.iconNode.supernode == nil {
                self.addSubnode(self.iconNode)
            }
            self.iconNode.image = generateTintedImage(image: icon, color: textColorValue)
            let iconFrame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((height - icon.size.height) / 2.0)), size: icon.size)
            transition.updateFrame(node: self.iconNode, frame: iconFrame)
        } else if self.iconNode.supernode != nil {
            self.iconNode.image = nil
            self.iconNode.removeFromSupernode()
        }
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: height - UIScreenPixel), size: CGSize(width: width - separatorInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        return height
    }
}
