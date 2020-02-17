import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import AccountContext

public enum DeleteChatPeerAction {
    case delete
    case clearHistory
    case clearCache
    case clearCacheSuggestion
}

private let avatarFont = avatarPlaceholderFont(size: 26.0)

public final class DeleteChatPeerActionSheetItem: ActionSheetItem {
    let context: AccountContext
    let peer: Peer
    let chatPeer: Peer
    let action: DeleteChatPeerAction
    let strings: PresentationStrings
    let nameDisplayOrder: PresentationPersonNameOrder
    
    public init(context: AccountContext, peer: Peer, chatPeer: Peer, action: DeleteChatPeerAction, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder) {
        self.context = context
        self.peer = peer
        self.chatPeer = chatPeer
        self.action = action
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return DeleteChatPeerActionSheetItemNode(theme: theme, strings: self.strings, nameOrder: self.nameDisplayOrder, context: self.context, peer: self.peer, chatPeer: self.chatPeer, action: self.action)
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class DeleteChatPeerActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    
    private let avatarNode: AvatarNode
    private let textNode: ImmediateTextNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, nameOrder: PresentationPersonNameOrder, context: AccountContext, peer: Peer, chatPeer: Peer, action: DeleteChatPeerAction) {
        self.theme = theme
        self.strings = strings
        
        let peerFont = Font.regular(floor(theme.baseFontSize * 14.0 / 17.0))
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isAccessibilityElement = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        self.textNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.accessibilityArea)
        
        if chatPeer.id == context.account.peerId {
            self.avatarNode.setPeer(context: context, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: peer, overrideImage: .savedMessagesIcon)
        } else {
            var overrideImage: AvatarNodeImageOverride?
            if chatPeer.isDeleted {
                overrideImage = .deletedIcon
            }
            self.avatarNode.setPeer(context: context, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: peer, overrideImage: overrideImage)
        }
        
        var attributedText: NSAttributedString?
        switch action {
        case .clearCache, .clearCacheSuggestion:
            switch action {
            case .clearCache:
                attributedText = NSAttributedString(string: strings.ClearCache_Description, font: peerFont, textColor: theme.primaryTextColor)
            case .clearCacheSuggestion:
                attributedText = NSAttributedString(string: strings.ClearCache_FreeSpaceDescription, font: peerFont, textColor: theme.primaryTextColor)
            default:
                break
            }
        default:
            var text: (String, [(Int, NSRange)])?
            switch action {
            case .delete:
                if chatPeer.id == context.account.peerId {
                    text = (strings.ChatList_DeleteSavedMessagesConfirmation, [])
                } else if let chatPeer = chatPeer as? TelegramGroup {
                    text = strings.ChatList_LeaveGroupConfirmation(chatPeer.title)
                } else if let chatPeer = chatPeer as? TelegramChannel {
                    text = strings.ChatList_LeaveGroupConfirmation(chatPeer.title)
                } else if chatPeer is TelegramSecretChat {
                    text = strings.ChatList_DeleteSecretChatConfirmation(peer.displayTitle(strings: strings, displayOrder: nameOrder))
                } else {
                    text = strings.ChatList_DeleteChatConfirmation(peer.displayTitle(strings: strings, displayOrder: nameOrder))
                }
            case .clearHistory:
                text = strings.ChatList_ClearChatConfirmation(peer.displayTitle(strings: strings, displayOrder: nameOrder))
            default:
                break
            }
            if let text = text {
                var formattedAttributedText = NSMutableAttributedString(attributedString: NSAttributedString(string: text.0, font: peerFont, textColor: theme.primaryTextColor))
                for (_, range) in text.1 {
                    formattedAttributedText.addAttribute(.font, value: peerFont, range: range)
                }
                attributedText = formattedAttributedText
            }
        }
        
        if let attributedText = attributedText {
            self.textNode.attributedText = attributedText
            
            self.accessibilityArea.accessibilityLabel = attributedText.string
            self.accessibilityArea.accessibilityTraits = .staticText
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedSize.width - 20.0, height: .greatestFiniteMagnitude))
        
        let topInset: CGFloat = 16.0
        let avatarSize: CGFloat = 60.0
        let textSpacing: CGFloat = 12.0
        let bottomInset: CGFloat = 15.0
        
        self.avatarNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - avatarSize) / 2.0), y: topInset), size: CGSize(width: avatarSize, height: avatarSize))
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - textSize.width) / 2.0), y: topInset + avatarSize + textSpacing), size: textSize)
        
        let size = CGSize(width: constrainedSize.width, height: topInset + avatarSize + textSpacing + textSize.height + bottomInset)
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
        
        return size
    }
    
    override func layout() {
        super.layout()
    }
}
