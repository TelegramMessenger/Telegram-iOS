import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
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
    private let controllerInteraction: ChatControllerInteraction
    
    private let day: Int32
    
    init(context: AccountContext, peerId: PeerId, peer: Peer?, messageReference: MessageReference?, messageTimestamp: Int32, emptyColor: UIColor, controllerInteraction: ChatControllerInteraction) {
        self.context = context
        self.peerId = peerId
        self.peer = peer
        self.messageReference = messageReference
        self.messageTimestamp = messageTimestamp
        self.emptyColor = emptyColor
        self.controllerInteraction = controllerInteraction
        
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
            node.setPeer(context: self.context, theme: self.context.sharedContext.currentPresentationData.with({ $0 }).theme, synchronousLoad: synchronous, peer: peer, authorOfMessage: self.messageReference, emptyColor: self.emptyColor, controllerInteraction: self.controllerInteraction)
        }
        return node
    }
}

final class ChatMessageAvatarAccessoryItemNode: ListViewAccessoryItemNode {
    var controllerInteraction: ChatControllerInteraction?
    var peer: Peer?
    
    let containerNode: ContextControllerSourceNode
    let avatarNode: AvatarNode
    
    var contextActionIsEnabled: Bool = true {
        didSet {
            if self.contextActionIsEnabled != oldValue {
                self.containerNode.isGestureEnabled = self.contextActionIsEnabled
            }
        }
    }
    
    override init() {
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        self.avatarNode.frame = self.containerNode.bounds
        self.avatarNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.isLayerBacked = false
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction, let peer = strongSelf.peer else {
                return
            }
            strongSelf.controllerInteraction?.openPeerContextMenu(peer, strongSelf.containerNode, strongSelf.containerNode.bounds, gesture)
        }
    }
    
    func setPeer(context: AccountContext, theme: PresentationTheme, synchronousLoad:Bool, peer: Peer, authorOfMessage: MessageReference?, emptyColor: UIColor, controllerInteraction: ChatControllerInteraction) {
        self.controllerInteraction = controllerInteraction
        self.peer = peer
        
        self.contextActionIsEnabled = peer.smallProfileImage != nil
        
        var overrideImage: AvatarNodeImageOverride?
        if peer.isDeleted {
            overrideImage = .deletedIcon
        }
        self.avatarNode.setPeer(context: context, theme: theme, peer: peer, authorOfMessage: authorOfMessage, overrideImage: overrideImage, emptyColor: emptyColor, synchronousLoad: synchronousLoad, displayDimensions: CGSize(width: 38.0, height: 38.0))
    }
}
