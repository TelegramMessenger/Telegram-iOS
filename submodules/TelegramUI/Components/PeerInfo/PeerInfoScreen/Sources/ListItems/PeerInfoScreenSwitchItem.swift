import AsyncDisplayKit
import Display
import TelegramPresentationData
import AppBundle

final class PeerInfoScreenSwitchItem: PeerInfoScreenItem {
    let id: AnyHashable
    let text: String
    let value: Bool
    let icon: UIImage?
    let isLocked: Bool
    let toggled: ((Bool) -> Void)?
    
    init(id: AnyHashable, text: String, value: Bool, icon: UIImage? = nil, isLocked: Bool = false, toggled: ((Bool) -> Void)?) {
        self.id = id
        self.text = text
        self.value = value
        self.icon = icon
        self.isLocked = isLocked
        self.toggled = toggled
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenSwitchItemNode()
    }
}

private final class PeerInfoScreenSwitchItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    private let iconNode: ASImageNode
    private let textNode: ImmediateTextNode
    private let switchNode: SwitchNode
    private var lockedIconNode: ASImageNode?
    private let bottomSeparatorNode: ASDisplayNode
    private var lockedButtonNode: HighlightableButtonNode?
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenSwitchItem?
    
    private var theme: PresentationTheme?
    
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
        
        self.switchNode = SwitchNode()
        
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
        self.addSubnode(self.switchNode)
        self.addSubnode(self.activateArea)
        
        self.switchNode.valueUpdated = { [weak self] value in
            self?.item?.toggled?(value)
        }
        
        self.activateArea.activate = { [weak self] in
            guard let strongSelf = self, let item = strongSelf.item else {
                return false
            }
            let value = !strongSelf.switchNode.isOn
            item.toggled?(value)
            return true
        }
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenSwitchItem else {
            return 10.0
        }
        
        let firstTime = self.item == nil
        
        var updateLockedIconImage = false
        if item.isLocked {
            let lockedIconNode: ASImageNode
            if let current = self.lockedIconNode {
                lockedIconNode = current
            } else {
                updateLockedIconImage = true
                lockedIconNode = ASImageNode()
                self.lockedIconNode = lockedIconNode
                self.insertSubnode(lockedIconNode, aboveSubnode: self.switchNode)
            }
            
        } else if let lockedIconNode = self.lockedIconNode {
            self.lockedIconNode = nil
            lockedIconNode.removeFromSupernode()
        }
        
        if item.isLocked {
            self.switchNode.isUserInteractionEnabled = false
            if self.lockedButtonNode == nil {
                let lockedButtonNode = HighlightableButtonNode()
                self.lockedButtonNode = lockedButtonNode
                self.insertSubnode(lockedButtonNode, aboveSubnode: self.switchNode)
                lockedButtonNode.addTarget(self, action: #selector(self.lockedButtonPressed), forControlEvents: .touchUpInside)
            }
        } else {
            if let lockedButtonNode = self.lockedButtonNode {
                self.lockedButtonNode = nil
                lockedButtonNode.removeFromSupernode()
            }
            self.switchNode.isUserInteractionEnabled = true
        }
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            
            self.switchNode.frameColor = presentationData.theme.list.itemSwitchColors.frameColor
            self.switchNode.contentColor = presentationData.theme.list.itemSwitchColors.contentColor
            self.switchNode.handleColor = presentationData.theme.list.itemSwitchColors.handleColor
            
            updateLockedIconImage = true
        }
        
        if updateLockedIconImage, let lockedIconNode = self.lockedIconNode, let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/TextLockIcon"), color: presentationData.theme.list.itemSecondaryTextColor) {
            lockedIconNode.image = image
        }
        
        self.item = item
        
        self.selectionNode.pressed = nil
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        let leftInset = (item.icon == nil ? sideInset : sideInset + 29.0 + 16.0)
        let rightInset: CGFloat = 56.0 + safeAreaInsets.right
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let textColorValue: UIColor = presentationData.theme.list.itemPrimaryTextColor
        
        self.textNode.maximumNumberOfLines = 1
        self.textNode.attributedText = NSAttributedString(string: item.text, font: Font.regular(17.0), textColor: textColorValue)
        
        self.activateArea.accessibilityLabel = item.text
        self.activateArea.accessibilityValue = item.value ? presentationData.strings.VoiceOver_Common_On : presentationData.strings.VoiceOver_Common_Off
        self.activateArea.accessibilityHint = presentationData.strings.VoiceOver_Common_SwitchHint
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - rightInset, height: .greatestFiniteMagnitude))
        let textFrame = CGRect(origin: CGPoint(x: leftInset, y: 12.0), size: textSize)
        
        let height = textSize.height + 24.0
        
        if let icon = item.icon {
            if self.iconNode.supernode == nil {
                self.addSubnode(self.iconNode)
            }
            self.iconNode.image = icon
            let iconFrame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((height - icon.size.height) / 2.0)), size: icon.size)
            transition.updateFrame(node: self.iconNode, frame: iconFrame)
        } else if self.iconNode.supernode != nil {
            self.iconNode.image = nil
            self.iconNode.removeFromSupernode()
        }
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        if let switchView = self.switchNode.view as? UISwitch {
            if self.switchNode.bounds.size.width.isZero {
                switchView.sizeToFit()
            }
            let switchSize = switchView.bounds.size
            
            let switchFrame = CGRect(origin: CGPoint(x: width - switchSize.width - 15.0 - safeInsets.right, y: floor((height - switchSize.height) / 2.0)), size: switchSize)
            self.switchNode.frame = switchFrame
            if switchView.isOn != item.value {
                switchView.setOn(item.value, animated: !firstTime)
            }
            
            self.lockedButtonNode?.frame = switchFrame
            
            if let lockedIconNode = self.lockedIconNode, let icon = lockedIconNode.image {
                lockedIconNode.frame = CGRect(origin: CGPoint(x: switchFrame.minX + 10.0 + UIScreenPixel, y: switchFrame.minY + 9.0), size: icon.size)
            }
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
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        self.activateArea.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        
        return height
    }
    
    @objc private func lockedButtonPressed() {
        self.item?.toggled?(self.switchNode.isOn)
    }
}
