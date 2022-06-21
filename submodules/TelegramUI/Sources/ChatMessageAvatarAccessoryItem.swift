import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
import Display
import TelegramCore
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
    private let forwardInfo: MessageForwardInfo?
    private let emptyColor: UIColor
    private let controllerInteraction: ChatControllerInteraction
    
    private let day: Int32
    
    init(context: AccountContext, peerId: PeerId, peer: Peer?, messageReference: MessageReference?, messageTimestamp: Int32, forwardInfo: MessageForwardInfo?, emptyColor: UIColor, controllerInteraction: ChatControllerInteraction) {
        self.context = context
        self.peerId = peerId
        self.peer = peer
        self.messageReference = messageReference
        self.messageTimestamp = messageTimestamp
        self.forwardInfo = forwardInfo
        self.emptyColor = emptyColor
        self.controllerInteraction = controllerInteraction
        
        var t: time_t = time_t(messageTimestamp)
        var timeinfo: tm = tm()
        gmtime_r(&t, &timeinfo)
        
        self.day = timeinfo.tm_mday
    }
    
    func isEqualToItem(_ other: ListViewAccessoryItem) -> Bool {
        if case let other as ChatMessageAvatarAccessoryItem = other {
            if other.peerId != self.peerId {
                return false
            }
            if self.day != other.day {
                return false
            }
            
            var effectiveTimestamp = self.messageTimestamp
            if let forwardInfo = self.forwardInfo, forwardInfo.flags.contains(.isImported) {
                effectiveTimestamp = forwardInfo.date
            }
            
            var effectiveOtherTimestamp = other.messageTimestamp
            if let otherForwardInfo = other.forwardInfo, otherForwardInfo.flags.contains(.isImported) {
                effectiveOtherTimestamp = otherForwardInfo.date
            }
            
            if abs(effectiveTimestamp - effectiveOtherTimestamp) >= 10 * 60 {
                return false
            }
            if let forwardInfo = self.forwardInfo, let otherForwardInfo = other.forwardInfo, forwardInfo.flags.contains(.isImported), otherForwardInfo.flags.contains(.isImported) {
                if (forwardInfo.authorSignature != nil) == (otherForwardInfo.authorSignature != nil) && (forwardInfo.author != nil) == (otherForwardInfo.author != nil) {
                    if let authorSignature = forwardInfo.authorSignature, let otherAuthorSignature = otherForwardInfo.authorSignature {
                        if authorSignature != otherAuthorSignature {
                            return false
                        }
                    } else if let authorId = forwardInfo.author?.id, let otherAuthorId = otherForwardInfo.author?.id {
                        if authorId != otherAuthorId {
                            return false
                        }
                    }
                } else {
                    return false
                }
            } else if let forwardInfo = self.forwardInfo, forwardInfo.flags.contains(.isImported) {
                return false
            } else if let otherForwardInfo = other.forwardInfo, otherForwardInfo.flags.contains(.isImported) {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func node(synchronous: Bool) -> ListViewAccessoryItemNode {
        let node = ChatMessageAvatarAccessoryItemNode()
        node.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        if let forwardInfo = self.forwardInfo, forwardInfo.flags.contains(.isImported) {
            if let author = forwardInfo.author {
                node.setPeer(context: self.context, theme: self.context.sharedContext.currentPresentationData.with({ $0 }).theme, synchronousLoad: synchronous, peer: author, authorOfMessage: self.messageReference, emptyColor: self.emptyColor, controllerInteraction: self.controllerInteraction)
            } else if let authorSignature = forwardInfo.authorSignature, !authorSignature.isEmpty {
                let components = authorSignature.components(separatedBy: " ")
                if !components.isEmpty, !components[0].hasPrefix("+") {
                    var letters: [String] = []
                    
                    letters.append(String(components[0][components[0].startIndex]))
                    if components.count > 1 {
                        letters.append(String(components[1][components[1].startIndex]))
                    }
                    
                    node.setCustomLetters(context: self.context, theme: self.context.sharedContext.currentPresentationData.with({ $0 }).theme, synchronousLoad: synchronous, letters: letters, emptyColor: self.emptyColor, controllerInteraction: self.controllerInteraction)
                } else {
                    node.setCustomLetters(context: self.context, theme: self.context.sharedContext.currentPresentationData.with({ $0 }).theme, synchronousLoad: synchronous, letters: [], emptyColor: self.emptyColor, controllerInteraction: self.controllerInteraction)
                }
            } else {
                node.setCustomLetters(context: self.context, theme: self.context.sharedContext.currentPresentationData.with({ $0 }).theme, synchronousLoad: synchronous, letters: [], emptyColor: self.emptyColor, controllerInteraction: self.controllerInteraction)
            }
        } else if let peer = self.peer {
            node.setPeer(context: self.context, theme: self.context.sharedContext.currentPresentationData.with({ $0 }).theme, synchronousLoad: synchronous, peer: peer, authorOfMessage: self.messageReference, emptyColor: self.emptyColor, controllerInteraction: self.controllerInteraction)
        }
        return node
    }
}

final class ChatMessageAvatarAccessoryItemNode: ListViewAccessoryItemNode {
    var controllerInteraction: ChatControllerInteraction?
    var peer: Peer?
    var messageId: MessageId?
    
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
            controllerInteraction.openPeerContextMenu(peer, strongSelf.messageId, strongSelf.containerNode, strongSelf.containerNode.bounds, gesture)
        }
    }
    
    func setCustomLetters(context: AccountContext, theme: PresentationTheme, synchronousLoad: Bool, letters: [String], emptyColor: UIColor, controllerInteraction: ChatControllerInteraction) {
        self.controllerInteraction = controllerInteraction
        self.peer = nil
        
        self.contextActionIsEnabled = false
        
        self.avatarNode.setCustomLetters(letters, icon: !letters.isEmpty ? nil : .phone)
    }
    
    func setPeer(context: AccountContext, theme: PresentationTheme, synchronousLoad: Bool, peer: Peer, authorOfMessage: MessageReference?, emptyColor: UIColor, controllerInteraction: ChatControllerInteraction) {
        self.controllerInteraction = controllerInteraction
        self.peer = peer
        if let messageReference = authorOfMessage, case let .message(_, id, _, _, _) = messageReference.content {
            self.messageId = id
        }
        
        self.contextActionIsEnabled = peer.smallProfileImage != nil
        
        var overrideImage: AvatarNodeImageOverride?
        if peer.isDeleted {
            overrideImage = .deletedIcon
        }
        self.avatarNode.setPeer(context: context, theme: theme, peer: EnginePeer(peer), authorOfMessage: authorOfMessage, overrideImage: overrideImage, emptyColor: emptyColor, synchronousLoad: synchronousLoad, displayDimensions: CGSize(width: 38.0, height: 38.0))
    }
}
