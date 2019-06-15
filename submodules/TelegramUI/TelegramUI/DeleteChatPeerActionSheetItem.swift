import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData

enum DeleteChatPeerAction {
    case delete
    case clearHistory
}

final class DeleteChatPeerActionSheetItem: ActionSheetItem {
    let context: AccountContext
    let peer: Peer
    let chatPeer: Peer
    let action: DeleteChatPeerAction
    let strings: PresentationStrings
    
    init(context: AccountContext, peer: Peer, chatPeer: Peer, action: DeleteChatPeerAction, strings: PresentationStrings) {
        self.context = context
        self.peer = peer
        self.chatPeer = chatPeer
        self.action = action
        self.strings = strings
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return DeleteChatPeerActionSheetItemNode(theme: theme, strings: self.strings, context: self.context, peer: self.peer, chatPeer: self.chatPeer, action: self.action)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private let avatarFont = UIFont(name: ".SFCompactRounded-Semibold", size: 26.0)!

private final class DeleteChatPeerActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    
    private let avatarNode: AvatarNode
    private let textNode: ImmediateTextNode
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, context: AccountContext, peer: Peer, chatPeer: Peer, action: DeleteChatPeerAction) {
        self.theme = theme
        self.strings = strings
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        
        super.init(theme: theme)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.textNode)
        
        if chatPeer.id == context.account.peerId {
            self.avatarNode.setPeer(account: context.account, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: peer, overrideImage: .savedMessagesIcon)
        } else {
            var overrideImage: AvatarNodeImageOverride?
            if chatPeer.isDeleted {
                overrideImage = .deletedIcon
            }
            self.avatarNode.setPeer(account: context.account, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: peer, overrideImage: overrideImage)
        }
        
        let text: (String, [(Int, NSRange)])
        switch action {
            case .delete:
                if chatPeer.id == context.account.peerId {
                    text = (strings.ChatList_DeleteSavedMessagesConfirmation, [])
                } else if chatPeer is TelegramGroup || chatPeer is TelegramChannel {
                    text = strings.ChatList_LeaveGroupConfirmation(peer.displayTitle)
                } else if chatPeer is TelegramSecretChat {
                    text = strings.ChatList_DeleteSecretChatConfirmation(peer.displayTitle)
                } else {
                    text = strings.ChatList_DeleteChatConfirmation(peer.displayTitle)
                }
            case .clearHistory:
                text = strings.ChatList_ClearChatConfirmation(peer.displayTitle)
        }
        let attributedText = NSMutableAttributedString(attributedString: NSAttributedString(string: text.0, font: Font.regular(14.0), textColor: theme.primaryTextColor))
        for (_, range) in text.1 {
            attributedText.addAttribute(.font, value: Font.semibold(14.0), range: range)
        }
        
        self.textNode.attributedText = attributedText
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedSize.width - 20.0, height: .greatestFiniteMagnitude))
        
        let topInset: CGFloat = 16.0
        let avatarSize: CGFloat = 60.0
        let textSpacing: CGFloat = 12.0
        let bottomInset: CGFloat = 15.0
        
        self.avatarNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - avatarSize) / 2.0), y: topInset), size: CGSize(width: avatarSize, height: avatarSize))
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - textSize.width) / 2.0), y: topInset + avatarSize + textSpacing), size: textSize)
        
        return CGSize(width: constrainedSize.width, height: topInset + avatarSize + textSpacing + textSize.height + bottomInset)
    }
    
    override func layout() {
        super.layout()
    }
}
