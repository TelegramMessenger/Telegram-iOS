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
    case peerList
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
    private let maskNode: ASImageNode
    private let iconNode: ASImageNode
    private let textNode: ImmediateTextNode
    private let bottomSeparatorNode: ASDisplayNode
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenActionItem?
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init()
        
        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }
        
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
        self.addSubnode(self.maskNode)
        self.addSubnode(self.textNode)
        
        self.addSubnode(self.activateArea)
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenActionItem else {
            return 10.0
        }
        
        self.item = item
        
        self.selectionNode.pressed = item.action
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        var leftInset = (item.icon == nil ? sideInset : sideInset + 29.0 + 16.0)
        var iconInset = sideInset
        if case .peerList = item.alignment {
            leftInset += 5.0
            iconInset += 5.0
        }
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
        self.activateArea.accessibilityLabel = item.text
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - (leftInset + rightInset), height: .greatestFiniteMagnitude))
        
        let textFrame = CGRect(origin: CGPoint(x: item.alignment == .center ? floorToScreenPixels((width - textSize.width) / 2.0) : leftInset, y: 12.0), size: textSize)
        
        let height = textSize.height + 24.0
        
        if let icon = item.icon {
            if self.iconNode.supernode == nil {
                self.addSubnode(self.iconNode)
            }
            self.iconNode.image = generateTintedImage(image: icon, color: textColorValue)
            let iconFrame = CGRect(origin: CGPoint(x: iconInset, y: floorToScreenPixels((height - icon.size.height) / 2.0)), size: icon.size)
            transition.updateFrame(node: self.iconNode, frame: iconFrame)
        } else if self.iconNode.supernode != nil {
            self.iconNode.image = nil
            self.iconNode.removeFromSupernode()
        }
        
        if self.textNode.frame.width != textFrame.width {
            self.textNode.frame = textFrame
        } else {
            transition.updateFrame(node: self.textNode, frame: textFrame)
        }
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: height - UIScreenPixel), size: CGSize(width: width - separatorInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        self.activateArea.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        
        return height
    }
}
