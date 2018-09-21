import Foundation
import Postbox
import Display
import TelegramCore

private let avatarFont: UIFont = UIFont(name: ".SFCompactRounded-Semibold", size: 16.0)!

final class ChatMessageAvatarAccessoryItem: ListViewAccessoryItem {
    private let account: Account
    private let peerId: PeerId
    private let peer: Peer?
    private let messageReference: MessageReference?
    private let messageTimestamp: Int32
    
    init(account: Account, peerId: PeerId, peer: Peer?, messageReference: MessageReference?, messageTimestamp: Int32) {
        self.account = account
        self.peerId = peerId
        self.peer = peer
        self.messageReference = messageReference
        self.messageTimestamp = messageTimestamp
    }
    
    func isEqualToItem(_ other: ListViewAccessoryItem) -> Bool {
        if case let other as ChatMessageAvatarAccessoryItem = other {
            return other.peerId == self.peerId && abs(other.messageTimestamp - self.messageTimestamp) < 5 * 60
        }
        
        return false
    }
    
    func node() -> ListViewAccessoryItemNode {
        let node = ChatMessageAvatarAccessoryItemNode()
        node.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        if let peer = self.peer {
            node.setPeer(account: account, peer: peer, authorOfMessage: self.messageReference)
        }
        return node
    }
}

final class ChatMessageAvatarAccessoryItemNode: ListViewAccessoryItemNode {
    let avatarNode: AvatarNode
    
    override init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = true
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        
        super.init()
        
        self.isLayerBacked = true
        self.addSubnode(self.avatarNode)
    }
    
    func setPeer(account: Account, peer: Peer, authorOfMessage: MessageReference?) {
        self.avatarNode.setPeer(account: account, peer: peer, authorOfMessage: authorOfMessage)
    }
}
