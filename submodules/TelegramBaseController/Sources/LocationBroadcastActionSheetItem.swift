import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TelegramPresentationData
import AccountContext
import LiveLocationTimerNode
import AvatarNode

public class LocationBroadcastActionSheetItem: ActionSheetItem {
    public let context: AccountContext
    public let peer: Peer
    public let title: String
    public let beginTimestamp: Double
    public let timeout: Double
    public let strings: PresentationStrings
    public let action: () -> Void
    
    public init(context: AccountContext, peer: Peer, title: String, beginTimestamp: Double, timeout: Double, strings: PresentationStrings, action: @escaping () -> Void) {
        self.context = context
        self.peer = peer
        self.title = title
        self.beginTimestamp = beginTimestamp
        self.timeout = timeout
        self.strings = strings
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = LocationBroadcastActionSheetItemNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? LocationBroadcastActionSheetItemNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

private let avatarFont = avatarPlaceholderFont(size: 15.0)

public class LocationBroadcastActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let defaultFont: UIFont
    
    private var item: LocationBroadcastActionSheetItem?
    
    private let button: HighlightTrackingButton
    private let avatarNode: AvatarNode
    private let label: ImmediateTextNode
    private let timerNode: ChatMessageLiveLocationTimerNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        self.defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        self.button = HighlightTrackingButton()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.label = ImmediateTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.displaysAsynchronously = false
        self.label.maximumNumberOfLines = 1
        
        self.timerNode = ChatMessageLiveLocationTimerNode()
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.label)
        self.addSubnode(self.timerNode)
        
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
    }
    
    func setItem(_ item: LocationBroadcastActionSheetItem) {
        self.item = item
        
        let defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        let textColor: UIColor = self.theme.primaryTextColor
        self.label.attributedText = NSAttributedString(string: item.title, font: defaultFont, textColor: textColor)
        
        self.avatarNode.setPeer(context: item.context, theme: (item.context.sharedContext.currentPresentationData.with { $0 }).theme, peer: EnginePeer(item.peer))
        
        self.timerNode.update(backgroundColor: self.theme.controlAccentColor.withAlphaComponent(0.4), foregroundColor: self.theme.controlAccentColor, textColor: self.theme.controlAccentColor, beginTimestamp: item.beginTimestamp, timeout: item.timeout, strings: item.strings)
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 57.0)
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        let avatarInset: CGFloat = 42.0
        let avatarSize: CGFloat = 32.0
        
        self.avatarNode.frame = CGRect(origin: CGPoint(x: 16.0, y: floor((size.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
        
        let labelSize = self.label.updateLayout(CGSize(width: max(1.0, size.width - avatarInset - 16.0 - 16.0 - 30.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: 16.0 + avatarInset, y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        
        let timerSize = CGSize(width: 28.0, height: 28.0)
        self.timerNode.frame = CGRect(origin: CGPoint(x: size.width - 16.0 - timerSize.width, y: floorToScreenPixels((size.height - timerSize.height) / 2.0)), size: timerSize)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
    
    @objc func buttonPressed() {
        if let item = self.item {
            item.action()
        }
    }
}

