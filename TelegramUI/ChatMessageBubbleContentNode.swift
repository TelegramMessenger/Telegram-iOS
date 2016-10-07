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

class ChatMessageBubbleContentNode: ASDisplayNode {
    var properties: ChatMessageBubbleContentProperties {
        return ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0)
    }
    
    var controllerInteraction: ChatControllerInteraction?
    
    required override init() {
        //super.init(layerBacked: false)
        super.init()
    }
    
    func asyncLayoutContent() -> (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        preconditionFailure()
    }
    
    func animateInsertion(_ currentTimestamp: Double, duration: Double) {
    }
    
    func animateAdded(_ currentTimestamp: Double, duration: Double) {
    }
    
    func animateInsertionIntoBubble(_ duration: Double) {
    }
    
    func transitionNode(media: Media) -> ASDisplayNode? {
        return nil
    }
    
    func updateHiddenMedia(_ media: [Media]?) {
    }
}
