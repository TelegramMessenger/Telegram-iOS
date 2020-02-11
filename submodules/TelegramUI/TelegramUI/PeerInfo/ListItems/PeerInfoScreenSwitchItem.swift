import AsyncDisplayKit
import Display
import TelegramPresentationData

final class PeerInfoScreenSwitchItem: PeerInfoScreenItem {
    let id: AnyHashable
    let text: String
    let value: Bool
    let toggled: ((Bool) -> Void)?
    
    init(id: AnyHashable, text: String, value: Bool, toggled: ((Bool) -> Void)?) {
        self.id = id
        self.text = text
        self.value = value
        self.toggled = toggled
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenSwitchItemNode()
    }
}

private final class PeerInfoScreenSwitchItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let textNode: ImmediateTextNode
    private let switchNode: SwitchNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var item: PeerInfoScreenSwitchItem?
    
    private var theme: PresentationTheme?
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.switchNode = SwitchNode()
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        super.init()
        
        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }
        
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.switchNode)
        
        self.switchNode.valueUpdated = { [weak self] value in
            self?.item?.toggled?(value)
        }
    }
    
    override func update(width: CGFloat, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenSwitchItem else {
            return 10.0
        }
        
        let firstTime = self.item == nil
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            
            self.switchNode.frameColor = presentationData.theme.list.itemSwitchColors.frameColor
            self.switchNode.contentColor = presentationData.theme.list.itemSwitchColors.contentColor
            self.switchNode.handleColor = presentationData.theme.list.itemSwitchColors.handleColor
        }
        
        self.item = item
        
        self.selectionNode.pressed = nil
        
        let sideInset: CGFloat = 16.0
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let textColorValue: UIColor = presentationData.theme.list.itemPrimaryTextColor
        
        self.textNode.maximumNumberOfLines = 1
        self.textNode.attributedText = NSAttributedString(string: item.text, font: Font.regular(17.0), textColor: textColorValue)
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0 - 56.0, height: .greatestFiniteMagnitude))
        
        let arrowInset: CGFloat = 18.0
        
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: 11.0), size: textSize)
        
        let height = textSize.height + 22.0
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        if let switchView = self.switchNode.view as? UISwitch {
            if self.switchNode.bounds.size.width.isZero {
                switchView.sizeToFit()
            }
            let switchSize = switchView.bounds.size
            
            self.switchNode.frame = CGRect(origin: CGPoint(x: width - switchSize.width - 15.0, y: floor((height - switchSize.height) / 2.0)), size: switchSize)
            if switchView.isOn != item.value {
                switchView.setOn(item.value, animated: !firstTime)
            }
        }
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        return height
    }
}
