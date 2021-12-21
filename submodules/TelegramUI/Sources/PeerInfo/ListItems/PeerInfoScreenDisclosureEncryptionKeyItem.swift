import AsyncDisplayKit
import Display
import TelegramPresentationData
import EncryptionKeyVisualization
import TelegramCore

final class PeerInfoScreenDisclosureEncryptionKeyItem: PeerInfoScreenItem {
    let id: AnyHashable
    let text: String
    let fingerprint: SecretChatKeyFingerprint
    let action: (() -> Void)?
    
    init(id: AnyHashable, text: String, fingerprint: SecretChatKeyFingerprint, action: (() -> Void)?) {
        self.id = id
        self.text = text
        self.fingerprint = fingerprint
        self.action = action
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenDisclosureEncryptionKeyItemNode()
    }
}

private final class PeerInfoScreenDisclosureEncryptionKeyItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let textNode: ImmediateTextNode
    private let keyNode: ASImageNode
    private let arrowNode: ASImageNode
    private let bottomSeparatorNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var item: PeerInfoScreenDisclosureEncryptionKeyItem?
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.keyNode = ASImageNode()
        self.keyNode.displaysAsynchronously = false
        self.keyNode.displayWithoutProcessing = true
        self.keyNode.isUserInteractionEnabled = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        super.init()
        
        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }
        
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.keyNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.maskNode)
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenDisclosureEncryptionKeyItem else {
            return 10.0
        }
        
        if self.item?.fingerprint != item.fingerprint {
            self.keyNode.image = secretChatKeyImage(item.fingerprint, size: CGSize(width: 24.0, height: 24.0))
        }
        
        self.item = item
        
        self.selectionNode.pressed = item.action
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.textNode.maximumNumberOfLines = 1
        self.textNode.attributedText = NSAttributedString(string: item.text, font: Font.regular(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0 - 44.0, height: .greatestFiniteMagnitude))
        
        let arrowInset: CGFloat = 18.0
        
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: 12.0), size: textSize)
        
        let height = textSize.height + 24.0
        
        if let arrowImage = PresentationResourcesItemList.disclosureArrowImage(presentationData.theme) {
            self.arrowNode.image = arrowImage
            let arrowFrame = CGRect(origin: CGPoint(x: width - 7.0 - arrowImage.size.width, y: floorToScreenPixels((height - arrowImage.size.height) / 2.0)), size: arrowImage.size)
            transition.updateFrame(node: self.arrowNode, frame: arrowFrame)
        }
        
        if let image = self.keyNode.image {
            self.keyNode.frame = CGRect(origin: CGPoint(x: width - sideInset - arrowInset - image.size.width, y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        return height
    }
}
