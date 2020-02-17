import AsyncDisplayKit
import Display
import TelegramPresentationData

final class PeerInfoScreenDisclosureItem: PeerInfoScreenItem {
    let id: AnyHashable
    let label: String
    let text: String
    let action: (() -> Void)?
    
    init(id: AnyHashable, label: String, text: String, action: (() -> Void)?) {
        self.id = id
        self.label = label
        self.text = text
        self.action = action
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenDisclosureItemNode()
    }
}

private final class PeerInfoScreenDisclosureItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let labelNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let arrowNode: ASImageNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var item: PeerInfoScreenDisclosureItem?
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.isUserInteractionEnabled = false
        
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
        self.addSubnode(self.arrowNode)
    }
    
    override func update(width: CGFloat, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenDisclosureItem else {
            return 10.0
        }
        
        self.item = item
        
        self.selectionNode.pressed = item.action
        
        let sideInset: CGFloat = 16.0
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let textColorValue: UIColor = presentationData.theme.list.itemPrimaryTextColor
        let labelColorValue: UIColor = presentationData.theme.list.itemSecondaryTextColor
        
        self.labelNode.attributedText = NSAttributedString(string: item.label, font: Font.regular(17.0), textColor: labelColorValue)
        
        self.textNode.maximumNumberOfLines = 1
        self.textNode.attributedText = NSAttributedString(string: item.text, font: Font.regular(17.0), textColor: textColorValue)
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        let labelSize = self.labelNode.updateLayout(CGSize(width: width - textSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        let arrowInset: CGFloat = 18.0
        
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: 11.0), size: textSize)
        let labelFrame = CGRect(origin: CGPoint(x: width - sideInset - arrowInset - labelSize.width, y: 11.0), size: labelSize)
        
        let height = textSize.height + 22.0
        
        if let arrowImage = PresentationResourcesItemList.disclosureArrowImage(presentationData.theme) {
            self.arrowNode.image = arrowImage
            let arrowFrame = CGRect(origin: CGPoint(x: width - 7.0 - arrowImage.size.width, y: floorToScreenPixels((height - arrowImage.size.height) / 2.0)), size: arrowImage.size)
            transition.updateFrame(node: self.arrowNode, frame: arrowFrame)
        }
        
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        return height
    }
}
