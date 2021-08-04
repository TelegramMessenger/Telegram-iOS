import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TelegramPresentationData
import AvatarNode
import AccountContext

public class VoiceChatPeerActionSheetItem: ActionSheetItem {
    public let context: AccountContext
    public let peer: Peer
    public let title: String
    public let subtitle: String
    public let action: () -> Void
    
    public init(context: AccountContext, peer: Peer, title: String, subtitle: String, action: @escaping () -> Void) {
        self.context = context
        self.peer = peer
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = VoiceChatPeerActionSheetItemNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? VoiceChatPeerActionSheetItemNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

private let avatarFont = avatarPlaceholderFont(size: 15.0)

public class VoiceChatPeerActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let defaultFont: UIFont
    
    private var item: VoiceChatPeerActionSheetItem?
    
    private let button: HighlightTrackingButton
    private let avatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        self.button = HighlightTrackingButton()
        self.button.isAccessibilityElement = false
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        self.avatarNode.isAccessibilityElement = false
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isAccessibilityElement = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
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
    
    func setItem(_ item: VoiceChatPeerActionSheetItem) {
        self.item = item
        
        let titleFont = Font.regular(floor(self.theme.baseFontSize ))
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: titleFont, textColor: self.theme.primaryTextColor)

        let subtitleFont = Font.regular(floor(self.theme.baseFontSize * 13.0 / 17.0))
        self.subtitleNode.attributedText = NSAttributedString(string: item.subtitle, font: subtitleFont, textColor: self.theme.secondaryTextColor)
        
        let theme = item.context.sharedContext.currentPresentationData.with { $0 }.theme
        self.avatarNode.setPeer(context: item.context, theme: theme, peer: EnginePeer(item.peer))
                
        self.accessibilityArea.accessibilityTraits = [.button]
        self.accessibilityArea.accessibilityLabel = item.title
        self.accessibilityArea.accessibilityValue = item.subtitle
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 57.0)
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        let avatarInset: CGFloat = 42.0
        let avatarSize: CGFloat = 36.0
        
        self.avatarNode.frame = CGRect(origin: CGPoint(x: size.width - avatarSize - 14.0, y: floor((size.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, size.width - avatarInset - 16.0 - 16.0 - 30.0), height: size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 9.0), size: titleSize)
        
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: max(1.0, size.width - avatarInset - 16.0 - 16.0 - 30.0), height: size.height))
        self.subtitleNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 32.0), size: subtitleSize)
        
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

