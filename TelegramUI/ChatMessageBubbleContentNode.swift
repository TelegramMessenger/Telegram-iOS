import Foundation
import AsyncDisplayKit
import Display
import Postbox

struct ChatMessageBubbleContentProperties {
    let hidesSimpleAuthorHeader: Bool
    let headerSpacing: CGFloat
}

enum ChatMessageBubbleNoneMergeStatus {
    case Incoming
    case Outgoing
}

enum ChatMessageBubbleMergeStatus {
    case None(ChatMessageBubbleNoneMergeStatus)
    case Left
    case Right
}

enum ChatMessageBubbleRelativePosition {
    case None(ChatMessageBubbleMergeStatus)
    case Neighbour
}

struct ChatMessageBubbleContentPosition {
    let top: ChatMessageBubbleRelativePosition
    let bottom: ChatMessageBubbleRelativePosition
}

enum ChatMessageBubbleContentTapAction {
    case none
    case url(String)
    case textMention(String)
    case peerMention(PeerId, String)
    case botCommand(String)
    case hashtag(String?, String)
    case instantPage
    case holdToPreviewSecretMedia
    case call(PeerId)
    case ignore
}

class ChatMessageBubbleContentNode: ASDisplayNode {
    var properties: ChatMessageBubbleContentProperties {
        return ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0)
    }
    
    var controllerInteraction: ChatControllerInteraction?
    
    var visibility: ListViewItemNodeVisibility = .none
    
    required override init() {
        //super.init(layerBacked: false)
        super.init()
    }
    
    func asyncLayoutContent() -> (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (maxWidth: CGFloat, layout: (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        preconditionFailure()
    }
    
    func animateInsertion(_ currentTimestamp: Double, duration: Double) {
    }
    
    func animateAdded(_ currentTimestamp: Double, duration: Double) {
    }
    
    func animateRemoved(_ currentTimestamp: Double, duration: Double) {
    }
    
    func animateInsertionIntoBubble(_ duration: Double) {
    }
    
    func transitionNode(media: Media) -> ASDisplayNode? {
        return nil
    }
    
    func updateHiddenMedia(_ media: [Media]?) {
    }
    
    func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        return .none
    }
    
    func updateTouchesAtPoint(_ point: CGPoint?) {
    }
}
