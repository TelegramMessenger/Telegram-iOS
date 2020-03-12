import Foundation
import UIKit
import Postbox
import Display
import TelegramCore
import SyncCore
import TelegramPresentationData
import AvatarNode
import AccountContext

private let avatarFont = avatarPlaceholderFont(size: 16.0)

final class ChatMessageAvatarAccessoryItem: ListViewAccessoryItem {
    private let context: AccountContext
    private let peerId: PeerId
    private let peer: Peer?
    private let messageReference: MessageReference?
    private let messageTimestamp: Int32
    private let emptyColor: UIColor
    
    private let day: Int32
    
    init(context: AccountContext, peerId: PeerId, peer: Peer?, messageReference: MessageReference?, messageTimestamp: Int32, emptyColor: UIColor) {
        self.context = context
        self.peerId = peerId
        self.peer = peer
        self.messageReference = messageReference
        self.messageTimestamp = messageTimestamp
        self.emptyColor = emptyColor
        
        var t: time_t = time_t(messageTimestamp)
        var timeinfo: tm = tm()
        gmtime_r(&t, &timeinfo)
        
        self.day = timeinfo.tm_mday
    }
    
    func isEqualToItem(_ other: ListViewAccessoryItem) -> Bool {
        if case let other as ChatMessageAvatarAccessoryItem = other {
            return other.peerId == self.peerId && self.day == other.day && abs(other.messageTimestamp - self.messageTimestamp) < 10 * 60
        }
        
        return false
    }
    
    func node(synchronous: Bool) -> ListViewAccessoryItemNode {
        let node = ChatMessageAvatarAccessoryItemNode()
        node.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        if let peer = self.peer {
            node.setPeer(context: self.context, theme: self.context.sharedContext.currentPresentationData.with({ $0 }).theme, synchronousLoad: synchronous, peer: peer, authorOfMessage: self.messageReference, emptyColor: self.emptyColor)
        }
        return node
    }
}

final class ChatMessageAvatarAccessoryItemNode: ListViewAccessoryItemNode {
    let avatarNode: AvatarNode
    
    override init() {
        let isLayerBacked = !smartInvertColorsEnabled()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = isLayerBacked
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        
        super.init()
        
        self.isLayerBacked = isLayerBacked
        self.addSubnode(self.avatarNode)
    }
    
    func setPeer(context: AccountContext, theme: PresentationTheme, synchronousLoad:Bool, peer: Peer, authorOfMessage: MessageReference?, emptyColor: UIColor) {
        var overrideImage: AvatarNodeImageOverride?
        if peer.isDeleted {
            overrideImage = .deletedIcon
        }
        self.avatarNode.setPeer(context: context, theme: theme, peer: peer, authorOfMessage: authorOfMessage, overrideImage: overrideImage, emptyColor: emptyColor, synchronousLoad: synchronousLoad, displayDimensions: CGSize(width: 38.0, height: 38.0))
    }
}
