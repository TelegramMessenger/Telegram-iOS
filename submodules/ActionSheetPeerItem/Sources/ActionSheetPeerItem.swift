import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext

public class ActionSheetPeerItem: ActionSheetItem {
    public let context: AccountContext
    public let peer: EnginePeer
    public let theme: PresentationTheme
    public let title: String
    public let isSelected: Bool
    public let strings: PresentationStrings
    public let action: () -> Void
    
    public init(context: AccountContext, peer: EnginePeer, title: String, isSelected: Bool, strings: PresentationStrings, theme: PresentationTheme, action: @escaping () -> Void) {
        self.context = context
        self.peer = peer
        self.title = title
        self.isSelected = isSelected
        self.strings = strings
        self.theme = theme
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = ActionSheetPeerItemNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? ActionSheetPeerItemNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

private let avatarFont = avatarPlaceholderFont(size: 15.0)

public class ActionSheetPeerItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let defaultFont: UIFont
    
    private var item: ActionSheetPeerItem?
    
    private let button: HighlightTrackingButton
    private let avatarNode: AvatarNode
    private let label: ImmediateTextNode
    private let checkNode: ASImageNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        self.button = HighlightTrackingButton()
        self.button.isAccessibilityElement = false
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        self.avatarNode.isAccessibilityElement = false
        
        self.label = ImmediateTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.displaysAsynchronously = false
        self.label.maximumNumberOfLines = 1
        self.label.isAccessibilityElement = false
        
        self.checkNode = ASImageNode()
        self.checkNode.displaysAsynchronously = false
        self.checkNode.displayWithoutProcessing = true
        self.checkNode.image = generateItemListCheckIcon(color: theme.primaryTextColor)
        self.checkNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.label)
        self.addSubnode(self.checkNode)
        self.addSubnode(self.accessibilityArea)
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.backgroundColor = strongSelf.theme.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.backgroundNode.backgroundColor = strongSelf.theme.itemBackgroundColor
                    })
                }
            }
        }
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        
        self.accessibilityArea.activate = { [weak self] in
            self?.buttonPressed()
            return true
        }
    }
    
    func setItem(_ item: ActionSheetPeerItem) {
        self.item = item
        
        let defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        let textColor: UIColor = self.theme.primaryTextColor
        self.label.attributedText = NSAttributedString(string: item.title, font: defaultFont, textColor: textColor)
        
        self.avatarNode.setPeer(context: item.context, theme: item.theme, peer: item.peer)
        
        self.checkNode.isHidden = !item.isSelected
        
        var accessibilityTraits: UIAccessibilityTraits = [.button]
        if item.isSelected {
            accessibilityTraits.insert(.selected)
        }
        self.accessibilityArea.accessibilityTraits = accessibilityTraits
        self.accessibilityArea.accessibilityLabel = item.title
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 57.0)
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        let avatarInset: CGFloat = 42.0
        let avatarSize: CGFloat = 32.0
        
        self.avatarNode.frame = CGRect(origin: CGPoint(x: 16.0, y: floor((size.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
        
        let labelSize = self.label.updateLayout(CGSize(width: max(1.0, size.width - avatarInset - 16.0 - 16.0 - 30.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: 16.0 + avatarInset, y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        
        if let image = self.checkNode.image {
            self.checkNode.frame = CGRect(origin: CGPoint(x: size.width - image.size.width - 16.0, y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
        
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
    

    @objc private func buttonPressed() {
        if let item = self.item {
            item.action()
        }
    }
}

