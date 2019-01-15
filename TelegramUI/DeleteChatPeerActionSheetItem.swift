import Foundation
import Display
import Postbox
import TelegramCore

final class DeleteChatPeerActionSheetItem: ActionSheetItem {
    let account: Account
    let peer: Peer
    let chatPeer: Peer
    let strings: PresentationStrings
    
    init(account: Account, peer: Peer, chatPeer: Peer, strings: PresentationStrings) {
        self.account = account
        self.peer = peer
        self.chatPeer = chatPeer
        self.strings = strings
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return DeleteChatPeerActionSheetItemNode(theme: theme, strings: self.strings, account: self.account, peer: self.peer, chatPeer: self.chatPeer)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private let avatarFont: UIFont = UIFont(name: ".SFCompactRounded-Semibold", size: 26.0)!

private final class DeleteChatPeerActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    
    private let avatarNode: AvatarNode
    private let textNode: ImmediateTextNode
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, account: Account, peer: Peer, chatPeer: Peer) {
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
        
        self.avatarNode.setPeer(account: account, peer: peer)
        
        let text: (String, [(Int, NSRange)])
        if chatPeer is TelegramGroup || chatPeer is TelegramChannel {
            text = strings.ChatList_LeaveGroupConfirmation(peer.displayTitle)
        } else if chatPeer is TelegramSecretChat {
            text = strings.ChatList_DeleteSecretChatConfirmation(peer.displayTitle)
        } else {
            text = strings.ChatList_DeleteChatConfirmation(peer.displayTitle)
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
