import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramUIPreferences
import TelegramPresentationData
import AccountContext
import ChatMessageBackground
import ChatControllerInteraction
import ChatHistoryEntry
import ChatMessageItemCommon
import SwiftSignalKit

public enum ChatMessageBubbleContentBackgroundHiding {
    case never
    case emptyWallpaper
    case always
}

public enum ChatMessageBubbleContentAlignment {
    case none
    case center
}

public struct ChatMessageBubbleContentProperties {
    public let hidesSimpleAuthorHeader: Bool
    public let headerSpacing: CGFloat
    public let hidesBackground: ChatMessageBubbleContentBackgroundHiding
    public let forceFullCorners: Bool
    public let forceAlignment: ChatMessageBubbleContentAlignment
    public let shareButtonOffset: CGPoint?
    public let hidesHeaders: Bool
    public let avatarOffset: CGFloat?
    public let isDetached: Bool
    
    public init(
        hidesSimpleAuthorHeader: Bool,
        headerSpacing: CGFloat,
        hidesBackground: ChatMessageBubbleContentBackgroundHiding,
        forceFullCorners: Bool,
        forceAlignment: ChatMessageBubbleContentAlignment,
        shareButtonOffset: CGPoint? = nil,
        hidesHeaders: Bool = false,
        avatarOffset: CGFloat? = nil,
        isDetached: Bool = false
    ) {
        self.hidesSimpleAuthorHeader = hidesSimpleAuthorHeader
        self.headerSpacing = headerSpacing
        self.hidesBackground = hidesBackground
        self.forceFullCorners = forceFullCorners
        self.forceAlignment = forceAlignment
        self.shareButtonOffset = shareButtonOffset
        self.hidesHeaders = hidesHeaders
        self.avatarOffset = avatarOffset
        self.isDetached = isDetached
    }
}

public enum ChatMessageBubbleNoneMergeStatus {
    case Incoming
    case Outgoing
    case None
}

public enum ChatMessageBubbleMergeStatus {
    case None(ChatMessageBubbleNoneMergeStatus)
    case Left
    case Right
    case Both
}

public enum ChatMessageBubbleRelativePosition {
    public enum NeighbourType {
        case media
        case header
        case footer
        case text
        case reactions
    }
    
    public enum NeighbourSpacing {
        case `default`
        case condensed
        case overlap(CGFloat)
    }
    
    case None(ChatMessageBubbleMergeStatus)
    case BubbleNeighbour
    case Neighbour(Bool, NeighbourType, NeighbourSpacing)
}

public enum ChatMessageBubbleContentMosaicNeighbor {
    case merged
    case mergedBubble
    case none(tail: Bool)
}

public struct ChatMessageBubbleContentMosaicPosition {
    public let topLeft: ChatMessageBubbleContentMosaicNeighbor
    public let topRight: ChatMessageBubbleContentMosaicNeighbor
    public let bottomLeft: ChatMessageBubbleContentMosaicNeighbor
    public let bottomRight: ChatMessageBubbleContentMosaicNeighbor
    
    public init(topLeft: ChatMessageBubbleContentMosaicNeighbor, topRight: ChatMessageBubbleContentMosaicNeighbor, bottomLeft: ChatMessageBubbleContentMosaicNeighbor, bottomRight: ChatMessageBubbleContentMosaicNeighbor) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
}

public enum ChatMessageBubbleContentPosition {
    case linear(top: ChatMessageBubbleRelativePosition, bottom: ChatMessageBubbleRelativePosition)
    case mosaic(position: ChatMessageBubbleContentMosaicPosition, wide: Bool)
}

public enum ChatMessageBubblePreparePosition {
    case linear(top: ChatMessageBubbleRelativePosition, bottom: ChatMessageBubbleRelativePosition)
    case mosaic(top: ChatMessageBubbleRelativePosition, bottom: ChatMessageBubbleRelativePosition, index: Int?)
}

public struct ChatMessageBubbleContentTapAction {
    public struct Url {
        public var url: String
        public var concealed: Bool
        public var allowInlineWebpageResolution: Bool
        
        public init(
            url: String,
            concealed: Bool,
            allowInlineWebpageResolution: Bool = false
        ) {
            self.url = url
            self.concealed = concealed
            self.allowInlineWebpageResolution = allowInlineWebpageResolution
        }
    }
    
    public enum Content {
        case none
        case url(Url)
        case phone(String)
        case textMention(String)
        case peerMention(peerId: PeerId, mention: String, openProfile: Bool)
        case botCommand(String)
        case hashtag(String?, String)
        case instantPage
        case wallpaper
        case theme
        case call(peerId: PeerId, isVideo: Bool)
        case openMessage
        case timecode(Double, String)
        case tooltip(String, ASDisplayNode?, CGRect?)
        case bankCard(String)
        case ignore
        case openPollResults(Data)
        case copy(String)
        case largeEmoji(String, String?, TelegramMediaFile)
        case customEmoji(TelegramMediaFile)
        case custom(() -> Void)
    }
    
    public var content: Content
    public var rects: [CGRect]?
    public var hasLongTapAction: Bool
    public var activate: (() -> Promise<Bool>?)?
    
    public init(content: Content, rects: [CGRect]? = nil, hasLongTapAction: Bool = true, activate: (() -> Promise<Bool>?)? = nil) {
        self.content = content
        self.rects = rects
        self.hasLongTapAction = hasLongTapAction
        self.activate = activate
    }
}

public final class ChatMessageBubbleContentItem {
    public let context: AccountContext
    public let controllerInteraction: ChatControllerInteraction
    public let message: Message
    public let topMessage: Message
    public let read: Bool
    public let chatLocation: ChatLocation
    public let presentationData: ChatPresentationData
    public let associatedData: ChatMessageItemAssociatedData
    public let attributes: ChatMessageEntryAttributes
    public let isItemPinned: Bool
    public let isItemEdited: Bool
    
    public init(context: AccountContext, controllerInteraction: ChatControllerInteraction, message: Message, topMessage: Message, read: Bool, chatLocation: ChatLocation, presentationData: ChatPresentationData, associatedData: ChatMessageItemAssociatedData, attributes: ChatMessageEntryAttributes, isItemPinned: Bool, isItemEdited: Bool) {
        self.context = context
        self.controllerInteraction = controllerInteraction
        self.message = message
        self.topMessage = topMessage
        self.read = read
        self.chatLocation = chatLocation
        self.presentationData = presentationData
        self.associatedData = associatedData
        self.attributes = attributes
        self.isItemPinned = isItemPinned
        self.isItemEdited = isItemEdited
    }
}

open class ChatMessageBubbleContentNode: ASDisplayNode {
    open var supportsMosaic: Bool {
        return false
    }
    
    open var index: Int?
    
    public weak var itemNode: ChatMessageItemNodeProtocol?
    public weak var bubbleBackgroundNode: ChatMessageBackground?
    public weak var bubbleBackdropNode: ChatMessageBubbleBackdrop?
    
    open var visibility: ListViewItemNodeVisibility = .none
    
    public var item: ChatMessageBubbleContentItem?
    
    public var updateIsTextSelectionActive: ((Bool) -> Void)?
    public var requestInlineUpdate: (() -> Void)?
    
    open var disablesClipping: Bool {
        return false
    }
    
    required public override init() {
        super.init()
    }
    
    open func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        preconditionFailure()
    }
    
    open func animateInsertion(_ currentTimestamp: Double, duration: Double) {
    }
    
    open func animateAdded(_ currentTimestamp: Double, duration: Double) {
    }
    
    open func animateRemoved(_ currentTimestamp: Double, duration: Double) {
    }
    
    open func animateInsertionIntoBubble(_ duration: Double) {
    }
    
    open func animateRemovalFromBubble(_ duration: Double, completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    open func transitionNode(messageId: MessageId, media: Media, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    open func updateHiddenMedia(_ media: [Media]?) -> Bool {
        return false
    }
    
    open func updateSearchTextHighlightState(text: String?, messages: [MessageIndex]?) {
    }
    
    open func updateAutomaticMediaDownloadSettings(_ settings: MediaAutoDownloadSettings) {
    }
        
    open func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        return nil
    }
    
    open func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    open func updateTouchesAtPoint(_ point: CGPoint?) {
    }
    
    open func updateHighlightedState(animated: Bool) -> Bool {
        return false
    }
    
    open func willUpdateIsExtractedToContextPreview(_ value: Bool) {
    }
    
    open func updateIsExtractedToContextPreview(_ value: Bool) {
    }

    open func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
    }

    open func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
    }

    open func applyAbsoluteOffsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
    }
    
    open func unreadMessageRangeUpdated() {
    }
    
    open func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        return nil
    }
    
    open func messageEffectTargetView() -> UIView? {
        return nil
    }
    
    open func targetForStoryTransition(id: StoryId) -> UIView? {
        return nil
    }
    
    open func getStatusNode() -> ASDisplayNode? {
        return nil
    }
}
