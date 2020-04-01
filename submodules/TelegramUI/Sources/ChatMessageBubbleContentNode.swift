import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramUIPreferences
import AccountContext

enum ChatMessageBubbleContentBackgroundHiding {
    case never
    case emptyWallpaper
    case always
}

enum ChatMessageBubbleContentAlignment {
    case none
    case center
}

struct ChatMessageBubbleContentProperties {
    let hidesSimpleAuthorHeader: Bool
    let headerSpacing: CGFloat
    let hidesBackground: ChatMessageBubbleContentBackgroundHiding
    let forceFullCorners: Bool
    let forceAlignment: ChatMessageBubbleContentAlignment
}

enum ChatMessageBubbleNoneMergeStatus {
    case Incoming
    case Outgoing
    case None
}

enum ChatMessageBubbleMergeStatus {
    case None(ChatMessageBubbleNoneMergeStatus)
    case Left
    case Right
}

enum ChatMessageBubbleRelativePosition {
    case None(ChatMessageBubbleMergeStatus)
    case BubbleNeighbour
    case Neighbour
}

enum ChatMessageBubbleContentMosaicNeighbor {
    case merged
    case mergedBubble
    case none(tail: Bool)
}

struct ChatMessageBubbleContentMosaicPosition {
    let topLeft: ChatMessageBubbleContentMosaicNeighbor
    let topRight: ChatMessageBubbleContentMosaicNeighbor
    let bottomLeft: ChatMessageBubbleContentMosaicNeighbor
    let bottomRight: ChatMessageBubbleContentMosaicNeighbor
}

enum ChatMessageBubbleContentPosition {
    case linear(top: ChatMessageBubbleRelativePosition, bottom: ChatMessageBubbleRelativePosition)
    case mosaic(position: ChatMessageBubbleContentMosaicPosition, wide: Bool)
}

enum ChatMessageBubblePreparePosition {
    case linear(top: ChatMessageBubbleRelativePosition, bottom: ChatMessageBubbleRelativePosition)
    case mosaic(top: ChatMessageBubbleRelativePosition, bottom: ChatMessageBubbleRelativePosition)
}

enum ChatMessageBubbleContentTapAction {
    case none
    case url(url: String, concealed: Bool)
    case textMention(String)
    case peerMention(PeerId, String)
    case botCommand(String)
    case hashtag(String?, String)
    case instantPage
    case wallpaper
    case theme
    case call(PeerId)
    case openMessage
    case timecode(Double, String)
    case tooltip(String, ASDisplayNode?, CGRect?)
    case bankCard(String)
    case ignore
    case openPollResults(Data)
}

final class ChatMessageBubbleContentItem {
    let context: AccountContext
    let controllerInteraction: ChatControllerInteraction
    let message: Message
    let read: Bool
    let presentationData: ChatPresentationData
    let associatedData: ChatMessageItemAssociatedData
    let attributes: ChatMessageEntryAttributes
    
    init(context: AccountContext, controllerInteraction: ChatControllerInteraction, message: Message, read: Bool, presentationData: ChatPresentationData, associatedData: ChatMessageItemAssociatedData, attributes: ChatMessageEntryAttributes) {
        self.context = context
        self.controllerInteraction = controllerInteraction
        self.message = message
        self.read = read
        self.presentationData = presentationData
        self.associatedData = associatedData
        self.attributes = attributes
    }
}

class ChatMessageBubbleContentNode: ASDisplayNode {
    var supportsMosaic: Bool {
        return false
    }
    
    var visibility: ListViewItemNodeVisibility = .none
    
    var item: ChatMessageBubbleContentItem?
    
    var updateIsTextSelectionActive: ((Bool) -> Void)?
    
    required override init() {
        super.init()
    }
    
    func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
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
    
    func animateRemovalFromBubble(_ duration: Double, completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func transitionNode(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func peekPreviewContent(at point: CGPoint) -> (Message, ChatMessagePeekPreviewContent)? {
        return nil
    }
    
    func updateHiddenMedia(_ media: [Media]?) -> Bool {
        return false
    }
    
    func updateSearchTextHighlightState(text: String?, messages: [MessageIndex]?) {
    }
    
    func updateAutomaticMediaDownloadSettings(_ settings: MediaAutoDownloadSettings) {
    }
        
    func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        return nil
    }
    
    func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        return .none
    }
    
    func updateTouchesAtPoint(_ point: CGPoint?) {
    }
    
    func updateHighlightedState(animated: Bool) -> Bool {
        return false
    }
    
    func willUpdateIsExtractedToContextPreview(_ value: Bool) {    
    }
    
    func updateIsExtractedToContextPreview(_ value: Bool) {
    }
    
    func reactionTargetNode(value: String) -> (ASDisplayNode, Int)? {
        return nil
    }
}
