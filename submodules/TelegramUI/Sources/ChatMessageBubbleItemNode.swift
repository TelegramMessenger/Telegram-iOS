import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import AccountContext
import TemporaryCachedPeerDataManager
import LocalizedPeerData
import ContextUI
import TelegramUniversalVideoContent
import MosaicLayout
import TextSelectionNode
import PlatformRestrictionMatching
import Emoji
import ReactionSelectionNode
import PersistentStringHash
import GridMessageSelectionNode
import AppBundle
import Markdown

enum InternalBubbleTapAction {
    case action(() -> Void)
    case optionalAction(() -> Void)
    case openContextMenu(tapMessage: Message, selectAll: Bool, subFrame: CGRect)
}

private func contentNodeMessagesAndClassesForItem(_ item: ChatMessageItem) -> [(Message, AnyClass, ChatMessageEntryAttributes)] {
    var result: [(Message, AnyClass, ChatMessageEntryAttributes)] = []
    var skipText = false
    var messageWithCaptionToAdd: (Message, ChatMessageEntryAttributes)?
    var isUnsupportedMedia = false
    
    outer: for (message, itemAttributes) in item.content {
        for attribute in message.attributes {
            if let attribute = attribute as? RestrictedContentMessageAttribute, attribute.platformText(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) != nil {
                result.append((message, ChatMessageRestrictedBubbleContentNode.self, itemAttributes))
                break outer
            }
        }
        
        inner: for media in message.media {
            if let _ = media as? TelegramMediaImage {
                result.append((message, ChatMessageMediaBubbleContentNode.self, itemAttributes))
            } else if let file = media as? TelegramMediaFile {
                var isVideo = file.isVideo || (file.isAnimated && file.dimensions != nil)
                if isVideo {
                    result.append((message, ChatMessageMediaBubbleContentNode.self, itemAttributes))
                } else {
                    result.append((message, ChatMessageFileBubbleContentNode.self, itemAttributes))
                }
            } else if let action = media as? TelegramMediaAction {
                if case .phoneCall = action.action {
                    result.append((message, ChatMessageCallBubbleContentNode.self, itemAttributes))
                } else {
                    result.append((message, ChatMessageActionBubbleContentNode.self, itemAttributes))
                }
            } else if let _ = media as? TelegramMediaMap {
                result.append((message, ChatMessageMapBubbleContentNode.self, itemAttributes))
            } else if let _ = media as? TelegramMediaGame {
                skipText = true
                result.append((message, ChatMessageGameBubbleContentNode.self, itemAttributes))
                break inner
            } else if let _ = media as? TelegramMediaInvoice {
                skipText = true
                result.append((message, ChatMessageInvoiceBubbleContentNode.self, itemAttributes))
                break inner
            } else if let _ = media as? TelegramMediaContact {
                result.append((message, ChatMessageContactBubbleContentNode.self, itemAttributes))
            } else if let _ = media as? TelegramMediaExpiredContent {
                result.removeAll()
                result.append((message, ChatMessageActionBubbleContentNode.self, itemAttributes))
                return result
            } else if let _ = media as? TelegramMediaPoll {
                result.append((message, ChatMessagePollBubbleContentNode.self, itemAttributes))
            } else if let _ = media as? TelegramMediaUnsupported {
                isUnsupportedMedia = true
            }
        }
        
        var messageText = message.text
        if let updatingMedia = itemAttributes.updatingMedia {
            messageText = updatingMedia.text
        }
        
        if !messageText.isEmpty || isUnsupportedMedia {
            if !skipText {
                if case .group = item.content {
                    messageWithCaptionToAdd = (message, itemAttributes)
                    skipText = true
                } else {
                    result.append((message, ChatMessageTextBubbleContentNode.self, itemAttributes))
                }
            } else {
                if case .group = item.content {
                    messageWithCaptionToAdd = nil
                }
            }
        }
        
        inner: for media in message.media {
            if let webpage = media as? TelegramMediaWebpage {
                if case .Loaded = webpage.content {
                    result.append((message, ChatMessageWebpageBubbleContentNode.self, itemAttributes))
                }
                break inner
            }
        }
        
        if isUnsupportedMedia {
            result.append((message, ChatMessageUnsupportedBubbleContentNode.self, itemAttributes))
        }
    }
    
    if let (messageWithCaptionToAdd, itemAttributes) = messageWithCaptionToAdd {
        result.append((messageWithCaptionToAdd, ChatMessageTextBubbleContentNode.self, itemAttributes))
    }
    
    if let additionalContent = item.additionalContent {
        switch additionalContent {
            case let .eventLogPreviousMessage(previousMessage):
                result.append((previousMessage, ChatMessageEventLogPreviousMessageContentNode.self, ChatMessageEntryAttributes()))
            case let .eventLogPreviousDescription(previousMessage):
                result.append((previousMessage, ChatMessageEventLogPreviousDescriptionContentNode.self, ChatMessageEntryAttributes()))
            case let .eventLogPreviousLink(previousMessage):
                result.append((previousMessage, ChatMessageEventLogPreviousLinkContentNode.self, ChatMessageEntryAttributes()))
        }
    }
    
    return result
}

private let chatMessagePeerIdColors: [UIColor] = [
    UIColor(rgb: 0xfc5c51),
    UIColor(rgb: 0xfa790f),
    UIColor(rgb: 0x895dd5),
    UIColor(rgb: 0x0fb297),
    UIColor(rgb: 0x00c0c2),
    UIColor(rgb: 0x3ca5ec),
    UIColor(rgb: 0x3d72ed)
]

private enum ContentNodeOperation {
    case remove(index: Int)
    case insert(index: Int, node: ChatMessageBubbleContentNode)
}

class ChatMessageBubbleItemNode: ChatMessageItemView, ChatMessagePrevewItemNode {
    private let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let backgroundWallpaperNode: ChatMessageBubbleBackdrop
    private let backgroundNode: ChatMessageBackground
    private let shadowNode: ChatMessageShadowNode
    private var transitionClippingNode: ASDisplayNode?
    
    override var extractedBackgroundNode: ASDisplayNode? {
        return self.shadowNode
    }
    
    private var selectionNode: ChatMessageSelectionNode?
    private var deliveryFailedNode: ChatMessageDeliveryFailedNode?
    private var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    private var swipeToReplyFeedback: HapticFeedback?
    
    private var nameNode: TextNode?
    private var adminBadgeNode: TextNode?
    private var credibilityIconNode: ASImageNode?
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    var forwardInfoReferenceNode: ASDisplayNode? {
        return self.forwardInfoNode
    }
    private var replyInfoNode: ChatMessageReplyInfoNode?
    
    private(set) var contentNodes: [ChatMessageBubbleContentNode] = []
    private var mosaicStatusNode: ChatMessageDateAndStatusNode?
    private var actionButtonsNode: ChatMessageActionButtonsNode?
    
    private var shareButtonNode: HighlightableButtonNode?
    
    private let messageAccessibilityArea: AccessibilityAreaNode

    private var backgroundType: ChatMessageBackgroundType?
    private var highlightedState: Bool = false
    
    private var backgroundFrameTransition: (CGRect, CGRect)?
    
    private var currentSwipeToReplyTranslation: CGFloat = 0.0
    
    private var appliedItem: ChatMessageItem?
    private var appliedForwardInfo: (Peer?, String?)?
    
    private var tapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?
    private var reactionRecognizer: ReactionSwipeGestureRecognizer?
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            if self.visibility != oldValue {
                for contentNode in self.contentNodes {
                    contentNode.visibility = self.visibility
                }
            }
        }
    }
    
    required init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.backgroundWallpaperNode = ChatMessageBubbleBackdrop()
        
        self.backgroundNode = ChatMessageBackground()
        self.shadowNode = ChatMessageShadowNode()
        self.messageAccessibilityArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false)
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self else {
                return false
            }
            if !strongSelf.backgroundNode.frame.contains(location) {
                return false
            }
            if let action = strongSelf.gestureRecognized(gesture: .tap, location: location, recognizer: nil) {
                if case .action = action {
                    return false
                }
            }
            if let action = strongSelf.gestureRecognized(gesture: .longTap, location: location, recognizer: nil) {
                switch action {
                case .action, .optionalAction:
                    return false
                case .openContextMenu:
                    return true
                }
            }
            return true
        }
        
        self.containerNode.activated = { [weak self] gesture, location in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            
            if let action = strongSelf.gestureRecognized(gesture: .longTap, location: location, recognizer: nil) {
                switch action {
                case .action, .optionalAction:
                    break
                case let .openContextMenu(tapMessage, selectAll, subFrame):
                    item.controllerInteraction.openMessageContextMenu(tapMessage, selectAll, strongSelf, subFrame, gesture)
                }
            }
        }
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.backgroundWallpaperNode)
        self.contextSourceNode.contentNode.addSubnode(self.backgroundNode)
        self.addSubnode(self.messageAccessibilityArea)
        
        self.messageAccessibilityArea.activate = { [weak self] in
            guard let strongSelf = self, let accessibilityData = strongSelf.accessibilityData else {
                return false
            }
            if let singleUrl = accessibilityData.singleUrl {
                strongSelf.item?.controllerInteraction.openUrl(singleUrl, false, false, strongSelf.item?.content.firstMessage)
            }
            return false
        }
        
        self.messageAccessibilityArea.focused = { [weak self] in
            self?.accessibilityElementDidBecomeFocused()
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtractedToContextPreview, _ in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            for contentNode in strongSelf.contentNodes {
                contentNode.willUpdateIsExtractedToContextPreview(isExtractedToContextPreview)
            }
        }
        self.contextSourceNode.isExtractedToContextPreviewUpdated = { [weak self] isExtractedToContextPreview in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            strongSelf.backgroundWallpaperNode.setMaskMode(strongSelf.backgroundMaskMode, mediaBox: item.context.account.postbox.mediaBox)
            strongSelf.backgroundNode.setMaskMode(strongSelf.backgroundMaskMode)
            if !isExtractedToContextPreview, let (rect, size) = strongSelf.absoluteRect {
                strongSelf.updateAbsoluteRect(rect, within: size)
            }
            
            for contentNode in strongSelf.contentNodes {
                contentNode.updateIsExtractedToContextPreview(isExtractedToContextPreview)
            }
        }
        
        self.contextSourceNode.updateAbsoluteRect = { [weak self] rect, size in
            guard let strongSelf = self, strongSelf.contextSourceNode.isExtractedToContextPreview else {
                return
            }
            strongSelf.updateAbsoluteRectInternal(rect, within: size)
        }
        self.contextSourceNode.applyAbsoluteOffset = { [weak self] value, animationCurve, duration in
            guard let strongSelf = self, strongSelf.contextSourceNode.isExtractedToContextPreview else {
                return
            }
            strongSelf.applyAbsoluteOffsetInternal(value: value, animationCurve: animationCurve, duration: duration)
        }
        self.contextSourceNode.applyAbsoluteOffsetSpring = { [weak self] value, duration, damping in
            guard let strongSelf = self, strongSelf.contextSourceNode.isExtractedToContextPreview else {
                return
            }
            strongSelf.applyAbsoluteOffsetSpringInternal(value: value, duration: duration, damping: damping)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.shadowNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        if let subnodes = self.subnodes {
            for node in subnodes {
                if let contextNode = node as? ContextExtractedContentContainingNode {
                    if let contextSubnodes = contextNode.contentNode.subnodes {
                        inner: for contextSubnode in contextSubnodes {
                            if contextSubnode !== self.accessoryItemNode {
                                if contextSubnode == self.backgroundNode {
                                    if self.backgroundNode.hasImage && self.backgroundWallpaperNode.hasImage {
                                        continue inner
                                    }
                                }
                                contextSubnode.layer.allowsGroupOpacity = true
                                contextSubnode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak contextSubnode] _ in
                                    contextSubnode?.layer.allowsGroupOpacity = false
                                })
                            }
                        }
                    }
                } else if node !== self.accessoryItemNode {
                    node.layer.allowsGroupOpacity = true
                    node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak node] _ in
                        node?.layer.allowsGroupOpacity = false
                    })
                }
            }
        }
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.allowsGroupOpacity = true
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak self] _ in
            self?.allowsGroupOpacity = false
        })
        self.shadowNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
        self.layer.animateScale(from: 1.0, to: 0.1, duration: 0.15, removeOnCompletion: false)
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: self.bounds.width / 2.0 - self.backgroundNode.frame.midX, y: self.backgroundNode.frame.midY), duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.allowsGroupOpacity = true
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak self] _ in
            self?.allowsGroupOpacity = false
        })
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let shareButtonNode = strongSelf.shareButtonNode, shareButtonNode.frame.contains(point) {
                    return .fail
                }
                
                if let avatarNode = strongSelf.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(point) {
                    return .waitForSingleTap
                }
                
                if let nameNode = strongSelf.nameNode, nameNode.frame.contains(point) {
                    if let item = strongSelf.item {
                        for attribute in item.message.attributes {
                            if let _ = attribute as? InlineBotMessageAttribute {
                                return .waitForSingleTap
                            }
                        }
                    }
                }
                if let replyInfoNode = strongSelf.replyInfoNode, replyInfoNode.frame.contains(point) {
                    return .waitForSingleTap
                }
                if let forwardInfoNode = strongSelf.forwardInfoNode, forwardInfoNode.frame.contains(point) {
                    if forwardInfoNode.hasAction(at: strongSelf.view.convert(point, to: forwardInfoNode.view)) {
                        return .fail
                    } else {
                        return .waitForSingleTap
                    }
                }
                for contentNode in strongSelf.contentNodes {
                    let tapAction = contentNode.tapActionAtPoint(CGPoint(x: point.x - contentNode.frame.minX, y: point.y - contentNode.frame.minY), gesture: .tap, isEstimating: true)
                    switch tapAction {
                        case .none:
                            if let _ = strongSelf.item?.controllerInteraction.tapMessage {
                                return .waitForSingleTap
                            }
                            break
                        case .ignore:
                            return .fail
                        case .url, .peerMention, .textMention, .botCommand, .hashtag, .instantPage, .wallpaper, .theme, .call, .openMessage, .timecode, .bankCard, .tooltip, .openPollResults:
                            return .waitForSingleTap
                    }
                }
                if !strongSelf.backgroundNode.frame.contains(point) {
                    return .waitForSingleTap
                }
            }
            
            return .waitForDoubleTap
        }
        recognizer.longTap = { [weak self] point, recognizer in
            guard let strongSelf = self else {
                return
            }
            strongSelf.reactionRecognizer?.cancel()
            if let action = strongSelf.gestureRecognized(gesture: .longTap, location: point, recognizer: recognizer) {
                switch action {
                case let .action(f):
                    f()
                    recognizer.cancel()
                case let .optionalAction(f):
                    f()
                    recognizer.cancel()
                case .openContextMenu:
                    break
                }
            }
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                for contentNode in strongSelf.contentNodes {
                    var translatedPoint: CGPoint?
                    if let point = point, contentNode.frame.insetBy(dx: -4.0, dy: -4.0).contains(point) {
                        translatedPoint = CGPoint(x: point.x - contentNode.frame.minX, y: point.y - contentNode.frame.minY)
                    }
                    contentNode.updateTouchesAtPoint(translatedPoint)
                }
            }
        }
        self.tapRecognizer = recognizer
        self.view.addGestureRecognizer(recognizer)
        self.view.isExclusiveTouch = true
        
        if true {
            let replyRecognizer = ChatSwipeToReplyRecognizer(target: self, action: #selector(self.swipeToReplyGesture(_:)))
            replyRecognizer.shouldBegin = { [weak self] in
                if let strongSelf = self, let item = strongSelf.item {
                    if strongSelf.selectionNode != nil {
                        return false
                    }
                    for media in item.content.firstMessage.media {
                        if let _ = media as? TelegramMediaExpiredContent {
                            return false
                        }
                        else if let media = media as? TelegramMediaAction {
                            if case .phoneCall(_, _, _) = media.action {
                                
                            } else {
                                return false
                            }
                        }
                    }
                    return item.controllerInteraction.canSetupReply(item.message)
                }
                return false
            }
            self.view.addGestureRecognizer(replyRecognizer)
        } else {
            let reactionRecognizer = ReactionSwipeGestureRecognizer(target: nil, action: nil)
            self.reactionRecognizer = reactionRecognizer
            reactionRecognizer.availableReactions = { [weak self] in
                guard let strongSelf = self, let item = strongSelf.item, !item.presentationData.isPreview && !Namespaces.Message.allScheduled.contains(item.message.id.namespace) else {
                    return []
                }
                if strongSelf.selectionNode != nil {
                    return []
                }
                for media in item.content.firstMessage.media {
                    if let _ = media as? TelegramMediaExpiredContent {
                        return []
                    }
                    else if let media = media as? TelegramMediaAction {
                        if case .phoneCall = media.action {
                        } else {
                            return []
                        }
                    }
                }
                
                let reactions: [(String, String, String)] = [
                    ("😔", "Sad", "sad"),
                    ("😳", "Surprised", "surprised"),
                    ("😂", "Fun", "lol"),
                    ("👍", "Like", "thumbsup"),
                    ("❤", "Love", "heart"),
                ]
                
                var reactionItems: [ReactionGestureItem] = []
                for (value, text, name) in reactions.reversed() {
                    if let path = getAppBundle().path(forResource: name, ofType: "tgs") {
                        reactionItems.append(.reaction(value: value, text: text, path: path))
                    }
                }
                if item.controllerInteraction.canSetupReply(item.message) {
                    //reactionItems.append(.reply)
                }
                return reactionItems
            }
            reactionRecognizer.getReactionContainer = { [weak self] in
                return self?.item?.controllerInteraction.reactionContainerNode()
            }
            reactionRecognizer.getAnchorPoint = { [weak self] in
                guard let strongSelf = self else {
                    return nil
                }
                return CGPoint(x: strongSelf.backgroundNode.frame.maxX, y: strongSelf.backgroundNode.frame.minY)
            }
            reactionRecognizer.shouldElevateAnchorPoint = { [weak self] in
                guard let strongSelf = self, let item = strongSelf.item else {
                    return false
                }
                return item.controllerInteraction.canSetupReply(item.message)
            }
            reactionRecognizer.began = { [weak self] in
                guard let strongSelf = self, let item = strongSelf.item else {
                    return
                }
                item.controllerInteraction.cancelInteractiveKeyboardGestures()
            }
            reactionRecognizer.updateOffset = { [weak self] offset, animated in
                guard let strongSelf = self else {
                    return
                }
                var bounds = strongSelf.bounds
                bounds.origin.x = offset
                strongSelf.bounds = bounds
                
                var shadowBounds = strongSelf.shadowNode.bounds
                shadowBounds.origin.x = offset
                strongSelf.shadowNode.bounds = shadowBounds
                
                if animated {
                    strongSelf.layer.animateBoundsOriginXAdditive(from: -offset, to: 0.0, duration: 0.1, mediaTimingFunction: CAMediaTimingFunction(name: .easeOut))
                    strongSelf.shadowNode.layer.animateBoundsOriginXAdditive(from: -offset, to: 0.0, duration: 0.1, mediaTimingFunction: CAMediaTimingFunction(name: .easeOut))
                }
                if let swipeToReplyNode = strongSelf.swipeToReplyNode {
                    swipeToReplyNode.alpha = max(0.0, min(1.0, abs(offset / 40.0)))
                }
            }
            reactionRecognizer.activateReply = { [weak self] in
                guard let strongSelf = self, let item = strongSelf.item else {
                    return
                }
                var bounds = strongSelf.bounds
                let offset = bounds.origin.x
                bounds.origin.x = 0.0
                strongSelf.bounds = bounds
                
                var shadowBounds = strongSelf.shadowNode.bounds
                let shadowOffset = shadowBounds.origin.x
                shadowBounds.origin.x = 0.0
                strongSelf.shadowNode.bounds = shadowBounds
                
                if !offset.isZero {
                    strongSelf.layer.animateBoundsOriginXAdditive(from: offset, to: 0.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
                }
                if !shadowOffset.isZero {
                    strongSelf.shadowNode.layer.animateBoundsOriginXAdditive(from: shadowOffset, to: 0.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
                }
                if let swipeToReplyNode = strongSelf.swipeToReplyNode {
                    strongSelf.swipeToReplyNode = nil
                    swipeToReplyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak swipeToReplyNode] _ in
                        swipeToReplyNode?.removeFromSupernode()
                    })
                    swipeToReplyNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                }
                item.controllerInteraction.setupReply(item.message.id)
            }
            reactionRecognizer.displayReply = { [weak self] offset in
                guard let strongSelf = self, let item = strongSelf.item else {
                    return
                }
                if !item.controllerInteraction.canSetupReply(item.message) {
                    return
                }
                if strongSelf.swipeToReplyFeedback == nil {
                    strongSelf.swipeToReplyFeedback = HapticFeedback()
                }
                strongSelf.swipeToReplyFeedback?.tap()
                if strongSelf.swipeToReplyNode == nil {
                    let swipeToReplyNode = ChatMessageSwipeToReplyNode(fillColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonFillColor, wallpaper: item.presentationData.theme.wallpaper), strokeColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonStrokeColor, wallpaper: item.presentationData.theme.wallpaper), foregroundColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonForegroundColor, wallpaper: item.presentationData.theme.wallpaper))
                    strongSelf.swipeToReplyNode = swipeToReplyNode
                    strongSelf.insertSubnode(swipeToReplyNode, belowSubnode: strongSelf.messageAccessibilityArea)
                    swipeToReplyNode.frame = CGRect(origin: CGPoint(x: strongSelf.bounds.size.width, y: floor((strongSelf.contentSize.height - 33.0) / 2.0)), size: CGSize(width: 33.0, height: 33.0))
                    swipeToReplyNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                    swipeToReplyNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                }
            }
            reactionRecognizer.completed = { [weak self] reaction in
                guard let strongSelf = self else {
                    return
                }
                if let item = strongSelf.item, let reaction = reaction {
                    switch reaction {
                    case let .reaction(value, _, _):
                        var resolvedValue: String?
                        if let reactionsAttribute = mergedMessageReactions(attributes: item.message.attributes), reactionsAttribute.reactions.contains(where: { $0.value == value }) {
                            resolvedValue = nil
                        } else {
                            resolvedValue = value
                        }
                        strongSelf.awaitingAppliedReaction = (resolvedValue, {})
                        item.controllerInteraction.updateMessageReaction(item.message.id, resolvedValue)
                    case .reply:
                        strongSelf.reactionRecognizer?.complete(into: nil, hideTarget: false)
                        var bounds = strongSelf.bounds
                        let offset = bounds.origin.x
                        bounds.origin.x = 0.0
                        strongSelf.bounds = bounds
                        var shadowBounds = strongSelf.shadowNode.bounds
                        let shadowOffset = shadowBounds.origin.x
                        shadowBounds.origin.x = 0.0
                        strongSelf.shadowNode.bounds = shadowBounds
                        if !offset.isZero {
                            strongSelf.layer.animateBoundsOriginXAdditive(from: offset, to: 0.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
                        }
                        if !shadowOffset.isZero {
                            strongSelf.shadowNode.layer.animateBoundsOriginXAdditive(from: shadowOffset, to: 0.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
                        }
                        if let swipeToReplyNode = strongSelf.swipeToReplyNode {
                            strongSelf.swipeToReplyNode = nil
                            swipeToReplyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak swipeToReplyNode] _ in
                                swipeToReplyNode?.removeFromSupernode()
                            })
                            swipeToReplyNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                        }
                        item.controllerInteraction.setupReply(item.message.id)
                    }
                } else {
                    strongSelf.reactionRecognizer?.complete(into: nil, hideTarget: false)
                    var bounds = strongSelf.bounds
                    let offset = bounds.origin.x
                    bounds.origin.x = 0.0
                    strongSelf.bounds = bounds
                    var shadowBounds = strongSelf.shadowNode.bounds
                    let shadowOffset = shadowBounds.origin.x
                    shadowBounds.origin.x = 0.0
                    strongSelf.shadowNode.bounds = shadowBounds
                    if !offset.isZero {
                        strongSelf.layer.animateBoundsOriginXAdditive(from: offset, to: 0.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                    if !shadowOffset.isZero {
                        strongSelf.shadowNode.layer.animateBoundsOriginXAdditive(from: shadowOffset, to: 0.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                    if let swipeToReplyNode = strongSelf.swipeToReplyNode {
                        strongSelf.swipeToReplyNode = nil
                        swipeToReplyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak swipeToReplyNode] _ in
                            swipeToReplyNode?.removeFromSupernode()
                        })
                        swipeToReplyNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    }
                }
            }
            self.view.addGestureRecognizer(reactionRecognizer)
        }
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, Bool) -> Void) {
        var currentContentClassesPropertiesAndLayouts: [(Message, AnyClass, Bool, (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))))] = []
        for contentNode in self.contentNodes {
            if let message = contentNode.item?.message {
                currentContentClassesPropertiesAndLayouts.append((message, type(of: contentNode) as AnyClass, contentNode.supportsMosaic, contentNode.asyncLayoutContent()))
            } else {
                assertionFailure()
            }
        }
        
        let authorNameLayout = TextNode.asyncLayout(self.nameNode)
        let adminBadgeLayout = TextNode.asyncLayout(self.adminBadgeNode)
        let forwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        let replyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let actionButtonsLayout = ChatMessageActionButtonsNode.asyncLayout(self.actionButtonsNode)
        
        let mosaicStatusLayout = ChatMessageDateAndStatusNode.asyncLayout(self.mosaicStatusNode)
        
        let currentShareButtonNode = self.shareButtonNode
        
        let layoutConstants = self.layoutConstants
        
        let currentItem = self.appliedItem
        let currentForwardInfo = self.appliedForwardInfo
        
        let isSelected = self.selectionNode?.selected
        
        let weakSelf = Weak(self)
        
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom in
            let layoutConstants = chatMessageItemLayoutConstants(layoutConstants, params: params, presentationData: item.presentationData)
            return ChatMessageBubbleItemNode.beginLayout(selfReference: weakSelf, item, params, mergedTop, mergedBottom, dateHeaderAtBottom,
                currentContentClassesPropertiesAndLayouts: currentContentClassesPropertiesAndLayouts,
                authorNameLayout: authorNameLayout,
                adminBadgeLayout: adminBadgeLayout,
                forwardInfoLayout: forwardInfoLayout,
                replyInfoLayout: replyInfoLayout,
                actionButtonsLayout: actionButtonsLayout,
                mosaicStatusLayout: mosaicStatusLayout,
                currentShareButtonNode: currentShareButtonNode,
                layoutConstants: layoutConstants,
                currentItem: currentItem,
                currentForwardInfo: currentForwardInfo,
                isSelected: isSelected
            )
        }
    }
    
    private static func beginLayout(selfReference: Weak<ChatMessageBubbleItemNode>, _ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool,
        currentContentClassesPropertiesAndLayouts: [(Message, AnyClass, Bool, (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))))],
        authorNameLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode),
        adminBadgeLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode),
        forwardInfoLayout: (ChatPresentationData, PresentationStrings, ChatMessageForwardInfoType, Peer?, String?, String?, CGSize) -> (CGSize, (CGFloat) -> ChatMessageForwardInfoNode),
        replyInfoLayout: (ChatPresentationData, PresentationStrings, AccountContext, ChatMessageReplyInfoType, Message, CGSize) -> (CGSize, () -> ChatMessageReplyInfoNode),
        actionButtonsLayout: (AccountContext, ChatPresentationThemeData, PresentationChatBubbleCorners, PresentationStrings, ReplyMarkupMessageAttribute, Message, CGFloat) -> (minWidth: CGFloat, layout: (CGFloat) -> (CGSize, (Bool) -> ChatMessageActionButtonsNode)),
        mosaicStatusLayout: (AccountContext, ChatPresentationData, Bool, Int?, String, ChatMessageDateAndStatusType, CGSize, [MessageReaction]) -> (CGSize, (Bool) -> ChatMessageDateAndStatusNode),
        currentShareButtonNode: HighlightableButtonNode?,
        layoutConstants: ChatMessageItemLayoutConstants,
        currentItem: ChatMessageItem?,
        currentForwardInfo: (Peer?, String?)?,
        isSelected: Bool?
    ) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, Bool) -> Void) {
        let accessibilityData = ChatMessageAccessibilityData(item: item, isSelected: isSelected)
        
        let fontSize = floor(item.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
        let nameFont = Font.medium(fontSize)

        let inlineBotPrefixFont = Font.regular(fontSize)
        let inlineBotNameFont = nameFont
        
        let baseWidth = params.width - params.leftInset - params.rightInset
        
        let content = item.content
        let firstMessage = content.firstMessage
        let incoming = item.content.effectivelyIncoming(item.context.account.peerId)
        let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
        
        var sourceReference: SourceReferenceMessageAttribute?
        for attribute in item.content.firstMessage.attributes {
            if let attribute = attribute as? SourceReferenceMessageAttribute {
                sourceReference = attribute
                break
            }
        }
        
        var isCrosspostFromChannel = false
        if let _ = sourceReference {
            if firstMessage.id.peerId != item.context.account.peerId {
                isCrosspostFromChannel = true
            }
        }
        
        var effectiveAuthor: Peer?
        var ignoreForward = false
        var displayAuthorInfo: Bool
        
        let avatarInset: CGFloat
        var hasAvatar = false
        
        var allowFullWidth = false
        switch item.chatLocation {
            case let .peer(peerId):
                if item.message.id.peerId == item.context.account.peerId {
                    if let forwardInfo = item.content.firstMessage.forwardInfo {
                        ignoreForward = true
                        effectiveAuthor = forwardInfo.author
                        if effectiveAuthor == nil, let authorSignature = forwardInfo.authorSignature  {
                            effectiveAuthor = TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: Int32(clamping: authorSignature.persistentHashValue)), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: UserInfoFlags())
                        }
                    }
                    displayAuthorInfo = !mergedTop.merged && incoming && effectiveAuthor != nil
                } else if isCrosspostFromChannel, let sourceReference = sourceReference, let source = firstMessage.peers[sourceReference.messageId.peerId] {
                    if firstMessage.forwardInfo?.author?.id == source.id {
                        ignoreForward = true
                    }
                    effectiveAuthor = source
                    displayAuthorInfo = !mergedTop.merged && incoming && effectiveAuthor != nil
                } else {
                    effectiveAuthor = firstMessage.author
                    displayAuthorInfo = !mergedTop.merged && incoming && peerId.isGroupOrChannel && effectiveAuthor != nil
                    if let forwardInfo = firstMessage.forwardInfo, forwardInfo.psaType != nil {
                        displayAuthorInfo = false
                    }
                }
            
                if peerId != item.context.account.peerId {
                    if peerId.isGroupOrChannel && effectiveAuthor != nil {
                        var isBroadcastChannel = false
                        if let peer = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                            isBroadcastChannel = true
                            allowFullWidth = true
                        }
                        
                        if !isBroadcastChannel {
                            hasAvatar = item.content.firstMessage.effectivelyIncoming(item.context.account.peerId)
                        }
                    }
                } else if incoming {
                    hasAvatar = true
                }
        }
        
        if let forwardInfo = item.content.firstMessage.forwardInfo, forwardInfo.source == nil, forwardInfo.author?.id.namespace == Namespaces.Peer.CloudUser {
            for media in item.content.firstMessage.media {
                if let file = media as? TelegramMediaFile, file.isMusic {
                    ignoreForward = true
                    break
                }
            }
        }
        
        if hasAvatar {
            avatarInset = layoutConstants.avatarDiameter
        } else {
            avatarInset = 0.0
        }
        
        let isFailed = item.content.firstMessage.effectivelyFailed(timestamp: item.context.account.network.getApproximateRemoteTimestamp())
        
        var needShareButton = false
        if isFailed || Namespaces.Message.allScheduled.contains(item.message.id.namespace) {
            needShareButton = false
        } else if item.message.id.peerId == item.context.account.peerId {
            if let _ = sourceReference {
                needShareButton = true
            }
        } else if item.message.effectivelyIncoming(item.context.account.peerId) {
            if let _ = sourceReference {
                needShareButton = true
            }
            
            if let peer = item.message.peers[item.message.id.peerId] {
                if let channel = peer as? TelegramChannel {
                    if case .broadcast = channel.info {
                        needShareButton = true
                    }
                }
            }
            
            if let info = item.message.forwardInfo {
                if let author = info.author as? TelegramUser, let _ = author.botInfo, !item.message.media.isEmpty && !(item.message.media.first is TelegramMediaAction) {
                    needShareButton = true
                } else if let author = info.author as? TelegramChannel, case .broadcast = author.info {
                    needShareButton = true
                }
            }
            
            if !needShareButton, let author = item.message.author as? TelegramUser, let _ = author.botInfo, !item.message.media.isEmpty && !(item.message.media.first is TelegramMediaAction) {
                needShareButton = true
            }
            if !needShareButton {
                loop: for media in item.message.media {
                    if media is TelegramMediaGame || media is TelegramMediaInvoice {
                        needShareButton = true
                        break loop
                    } else if let media = media as? TelegramMediaWebpage, case .Loaded = media.content {
                        needShareButton = true
                        break loop
                    }
                }
            } else {
                loop: for media in item.message.media {
                    if media is TelegramMediaAction {
                        needShareButton = false
                        break loop
                    }
                }
            }
        }
        
        var tmpWidth: CGFloat
        if allowFullWidth {
            tmpWidth = baseWidth
            if needShareButton {
                tmpWidth -= 38.0
            }
        } else {
            tmpWidth = layoutConstants.bubble.maximumWidthFill.widthFor(baseWidth)
            if needShareButton && tmpWidth + 32.0 > baseWidth {
                tmpWidth = baseWidth - 32.0
            }
        }
        
        var deliveryFailedInset: CGFloat = 0.0
        if isFailed {
            deliveryFailedInset += 24.0
        }
        
        tmpWidth -= deliveryFailedInset
        
        let maximumContentWidth = floor(tmpWidth - layoutConstants.bubble.edgeInset - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - layoutConstants.bubble.contentInsets.right - avatarInset)
        
        var contentPropertiesAndPrepareLayouts: [(Message, Bool, ChatMessageEntryAttributes, (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))))] = []
        var addedContentNodes: [(Message, ChatMessageBubbleContentNode)]?
        
        let contentNodeMessagesAndClasses = contentNodeMessagesAndClassesForItem(item)
        for (contentNodeMessage, contentNodeClass, attributes) in contentNodeMessagesAndClasses {
            var found = false
            for (currentMessage, currentClass, supportsMosaic, currentLayout) in currentContentClassesPropertiesAndLayouts {
                if currentClass == contentNodeClass && currentMessage.stableId == contentNodeMessage.stableId {
                    contentPropertiesAndPrepareLayouts.append((contentNodeMessage, supportsMosaic, attributes, currentLayout))
                    found = true
                    break
                }
            }
            if !found {
                let contentNode = (contentNodeClass as! ChatMessageBubbleContentNode.Type).init()
                contentPropertiesAndPrepareLayouts.append((contentNodeMessage, contentNode.supportsMosaic, attributes, contentNode.asyncLayoutContent()))
                if addedContentNodes == nil {
                    addedContentNodes = []
                }
                addedContentNodes!.append((contentNodeMessage, contentNode))
            }
        }
        
        var authorNameString: String?
        var authorRank: CachedChannelAdminRank?
        var authorIsChannel: Bool = false
        switch content {
            case let .message(message, _, _, attributes):
                if let peer = message.peers[message.id.peerId] as? TelegramChannel {
                    if case .broadcast = peer.info {
                    } else {
                        if isCrosspostFromChannel, let sourceReference = sourceReference, let _ = firstMessage.peers[sourceReference.messageId.peerId] as? TelegramChannel {
                            authorIsChannel = true
                        }
                        authorRank = attributes.rank
                    }
                } else {
                    if isCrosspostFromChannel, let _ = firstMessage.forwardInfo?.source as? TelegramChannel {
                        authorIsChannel = true
                    }
                    authorRank = attributes.rank
                }
            case .group:
                break
        }
        var inlineBotNameString: String?
        var replyMessage: Message?
        var replyMarkup: ReplyMarkupMessageAttribute?
        var authorNameColor: UIColor?
        
        for attribute in firstMessage.attributes {
            if let attribute = attribute as? InlineBotMessageAttribute {
                if let peerId = attribute.peerId, let bot = firstMessage.peers[peerId] as? TelegramUser {
                    inlineBotNameString = bot.username
                } else {
                    inlineBotNameString = attribute.title
                }
            } else if let attribute = attribute as? ReplyMessageAttribute {
                replyMessage = firstMessage.associatedMessages[attribute.messageId]
            } else if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
                replyMarkup = attribute
            }
        }
        
        if let forwardInfo = firstMessage.forwardInfo, forwardInfo.psaType != nil {
            inlineBotNameString = nil
        }
        
        var contentPropertiesAndLayouts: [(CGSize?, ChatMessageBubbleContentProperties, ChatMessageBubblePreparePosition, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void)))] = []
        
        let topNodeMergeStatus: ChatMessageBubbleMergeStatus = mergedTop.merged ? (incoming ? .Left : .Right) : .None(incoming ? .Incoming : .Outgoing)
        let bottomNodeMergeStatus: ChatMessageBubbleMergeStatus = mergedBottom.merged ? (incoming ? .Left : .Right) : .None(incoming ? .Incoming : .Outgoing)
        
        var backgroundHiding: ChatMessageBubbleContentBackgroundHiding?
        var hasSolidWallpaper = false
        switch item.presentationData.theme.wallpaper {
        case .color, .gradient:
            hasSolidWallpaper = true
        default:
            break
        }
        var alignment: ChatMessageBubbleContentAlignment = .none
        
        var maximumNodeWidth = maximumContentWidth
        
        let contentNodeCount = contentPropertiesAndPrepareLayouts.count
        
        let read: Bool
        switch item.content {
            case let .message(_, value, _, _):
                read = value
            case let .group(messages):
                read = messages[0].1
        }
        
        var mosaicStartIndex: Int?
        var mosaicRange: Range<Int>?
        for i in 0 ..< contentPropertiesAndPrepareLayouts.count {
            if contentPropertiesAndPrepareLayouts[i].1 {
                if mosaicStartIndex == nil {
                    mosaicStartIndex = i
                }
            } else if let mosaicStartIndexValue = mosaicStartIndex {
                if mosaicStartIndexValue < i - 1 {
                    mosaicRange = mosaicStartIndexValue ..< i
                }
                mosaicStartIndex = nil
            }
        }
        if let mosaicStartIndex = mosaicStartIndex {
            if mosaicStartIndex < contentPropertiesAndPrepareLayouts.count - 1 {
                mosaicRange = mosaicStartIndex ..< contentPropertiesAndPrepareLayouts.count
            }
        }
        
        var index = 0
        for (message, _, attributes, prepareLayout) in contentPropertiesAndPrepareLayouts {
            let topPosition: ChatMessageBubbleRelativePosition
            let bottomPosition: ChatMessageBubbleRelativePosition
            
            topPosition = .Neighbour
            bottomPosition = .Neighbour
            
            let prepareContentPosition: ChatMessageBubblePreparePosition
            if let mosaicRange = mosaicRange, mosaicRange.contains(index) {
                prepareContentPosition = .mosaic(top: .None(.None(.Incoming)), bottom: index == (mosaicRange.upperBound - 1) ? bottomPosition : .None(.None(.Incoming)))
            } else {
                let refinedBottomPosition: ChatMessageBubbleRelativePosition
                if index == contentPropertiesAndPrepareLayouts.count - 1 {
                    refinedBottomPosition = .None(.Left)
                } else {
                    refinedBottomPosition = bottomPosition
                }
                prepareContentPosition = .linear(top: topPosition, bottom: refinedBottomPosition)
            }
            
            let contentItem = ChatMessageBubbleContentItem(context: item.context, controllerInteraction: item.controllerInteraction, message: message, read: read, presentationData: item.presentationData, associatedData: item.associatedData, attributes: attributes)
            
            var itemSelection: Bool?
            if case .mosaic = prepareContentPosition {
                switch content {
                    case .message:
                        break
                    case let .group(messages):
                        for (m, _, selection, _) in messages {
                            if m.id == message.id {
                                switch selection {
                                    case .none:
                                        break
                                    case let .selectable(selected):
                                        itemSelection = selected
                                }
                                break
                            }
                        }
                }
            }
            
            let (properties, unboundSize, maxNodeWidth, nodeLayout) = prepareLayout(contentItem, layoutConstants, prepareContentPosition, itemSelection, CGSize(width: maximumContentWidth, height: CGFloat.greatestFiniteMagnitude))
            maximumNodeWidth = min(maximumNodeWidth, maxNodeWidth)
            
            contentPropertiesAndLayouts.append((unboundSize, properties, prepareContentPosition, nodeLayout))
            
            switch properties.hidesBackground {
                case .never:
                    backgroundHiding = .never
                case .emptyWallpaper:
                    if backgroundHiding == nil {
                        backgroundHiding = properties.hidesBackground
                    }
                case .always:
                    backgroundHiding = .always
            }
            
            switch properties.forceAlignment {
                case .none:
                    break
                case .center:
                    alignment = .center
            }
            
            index += 1
        }
        
        var currentCredibilityIconImage: UIImage?
        
        var initialDisplayHeader = true
        if let backgroundHiding = backgroundHiding, case .always = backgroundHiding {
            initialDisplayHeader = false
        } else {
            if inlineBotNameString == nil && (ignoreForward || firstMessage.forwardInfo == nil) && replyMessage == nil {
                if let first = contentPropertiesAndLayouts.first, first.1.hidesSimpleAuthorHeader {
                    initialDisplayHeader = false
                }
            }
        }
        
        if initialDisplayHeader && displayAuthorInfo {
            if let peer = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                authorNameString = peer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                authorNameColor = chatMessagePeerIdColors[Int(peer.id.id % 7)]
            } else if let effectiveAuthor = effectiveAuthor {
                authorNameString = effectiveAuthor.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                authorNameColor = chatMessagePeerIdColors[Int(effectiveAuthor.id.id % 7)]
                
                var isScam = effectiveAuthor.isScam
                if case let .peer(peerId) = item.chatLocation, let authorPeerId = item.message.author?.id, authorPeerId == peerId {
                    isScam = false
                }
                currentCredibilityIconImage = isScam ? PresentationResourcesChatList.scamIcon(item.presentationData.theme.theme, type: incoming ? .regular : .outgoing) : nil
            }
            if let rawAuthorNameColor = authorNameColor {
                var dimColors = false
                switch item.presentationData.theme.theme.name {
                    case .builtin(.nightAccent), .builtin(.night):
                        dimColors = true
                    default:
                        break
                }
                if dimColors {
                    var hue: CGFloat = 0.0
                    var saturation: CGFloat = 0.0
                    var brightness: CGFloat = 0.0
                    rawAuthorNameColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
                    authorNameColor = UIColor(hue: hue, saturation: saturation * 0.7, brightness: min(1.0, brightness * 1.2), alpha: 1.0)
                }
            }
        }
        
        var displayHeader = false
        if initialDisplayHeader {
            if authorNameString != nil {
                displayHeader = true
            }
            if inlineBotNameString != nil {
                displayHeader = true
            }
            if firstMessage.forwardInfo != nil {
                displayHeader = true
            }
            if replyMessage != nil {
                displayHeader = true
            }
        }
        
        let firstNodeTopPosition: ChatMessageBubbleRelativePosition
        if displayHeader {
            firstNodeTopPosition = .Neighbour
        } else {
            firstNodeTopPosition = .None(topNodeMergeStatus)
        }
        let lastNodeTopPosition: ChatMessageBubbleRelativePosition = .None(bottomNodeMergeStatus)
        
        var calculatedGroupFramesAndSize: ([(CGRect, MosaicItemPosition)], CGSize)?
        var mosaicStatusSizeAndApply: (CGSize, (Bool) -> ChatMessageDateAndStatusNode)?
        
        if let mosaicRange = mosaicRange {
            let maxSize = layoutConstants.image.maxDimensions.fittedToWidthOrSmaller(maximumContentWidth - layoutConstants.image.bubbleInsets.left - layoutConstants.image.bubbleInsets.right)
            let (innerFramesAndPositions, innerSize) = chatMessageBubbleMosaicLayout(maxSize: maxSize, itemSizes: contentPropertiesAndLayouts[mosaicRange].map { $0.0 ?? CGSize(width: 256.0, height: 256.0) })
            
            let framesAndPositions = innerFramesAndPositions.map { ($0.0.offsetBy(dx: layoutConstants.image.bubbleInsets.left, dy: layoutConstants.image.bubbleInsets.top), $0.1) }
            
            let size = CGSize(width: innerSize.width + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right, height: innerSize.height + layoutConstants.image.bubbleInsets.top + layoutConstants.image.bubbleInsets.bottom)
            
            calculatedGroupFramesAndSize = (framesAndPositions, size)
            
            maximumNodeWidth = size.width
            
            if mosaicRange.upperBound == contentPropertiesAndLayouts.count {
                let message = item.content.firstMessage
                
                var edited = false
                if item.content.firstMessageAttributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                for attribute in message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    }
                }
                
                var dateReactions: [MessageReaction] = []
                var dateReactionCount = 0
                if let reactionsAttribute = mergedMessageReactions(attributes: item.message.attributes), !reactionsAttribute.reactions.isEmpty {
                    for reaction in reactionsAttribute.reactions {
                        if reaction.isSelected {
                            dateReactions.insert(reaction, at: 0)
                        } else {
                            dateReactions.append(reaction)
                        }
                        dateReactionCount += Int(reaction.count)
                    }
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, reactionCount: dateReactionCount)
                
                let statusType: ChatMessageDateAndStatusType
                if message.effectivelyIncoming(item.context.account.peerId) {
                    statusType = .ImageIncoming
                } else {
                    if isFailed {
                        statusType = .ImageOutgoing(.Failed)
                    } else if (message.flags.isSending && !message.isSentOrAcknowledged) || item.content.firstMessageAttributes.updatingMedia != nil {
                        statusType = .ImageOutgoing(.Sending)
                    } else {
                        statusType = .ImageOutgoing(.Sent(read: item.read))
                    }
                }
                
                mosaicStatusSizeAndApply = mosaicStatusLayout(item.context, item.presentationData, edited, viewCount, dateText, statusType, CGSize(width: 200.0, height: CGFloat.greatestFiniteMagnitude), dateReactions)
            }
        }
        
        var headerSize = CGSize()
        
        var nameNodeOriginY: CGFloat = 0.0
        var nameNodeSizeApply: (CGSize, () -> TextNode?) = (CGSize(), { nil })
        var adminNodeSizeApply: (CGSize, () -> TextNode?) = (CGSize(), { nil })
        
        var replyInfoOriginY: CGFloat = 0.0
        var replyInfoSizeApply: (CGSize, () -> ChatMessageReplyInfoNode?) = (CGSize(), { nil })
        
        var forwardInfoOriginY: CGFloat = 0.0
        var forwardInfoSizeApply: (CGSize, (CGFloat) -> ChatMessageForwardInfoNode?) = (CGSize(), { _ in nil })
        
        var forwardSource: Peer?
        var forwardAuthorSignature: String?
        
        if displayHeader {
            if authorNameString != nil || inlineBotNameString != nil {
                if headerSize.height.isZero {
                    headerSize.height += 5.0
                }
                
                let inlineBotNameColor = messageTheme.accentTextColor
                
                let attributedString: NSAttributedString
                var adminBadgeString: NSAttributedString?
                if let authorRank = authorRank {
                    let string: String
                    switch authorRank {
                        case .owner:
                            string = item.presentationData.strings.Conversation_Owner
                        case .admin:
                            string = item.presentationData.strings.Conversation_Admin
                        case let .custom(rank):
                            string = rank.trimmingEmojis
                    }
                    adminBadgeString = NSAttributedString(string: " \(string)", font: inlineBotPrefixFont, textColor: messageTheme.secondaryTextColor)
                } else if authorIsChannel {
                    adminBadgeString = NSAttributedString(string: " \(item.presentationData.strings.Channel_Status)", font: inlineBotPrefixFont, textColor: messageTheme.secondaryTextColor)
                }
                if let authorNameString = authorNameString, let authorNameColor = authorNameColor, let inlineBotNameString = inlineBotNameString {
                    let mutableString = NSMutableAttributedString(string: "\(authorNameString) ", attributes: [NSAttributedString.Key.font: nameFont, NSAttributedString.Key.foregroundColor: authorNameColor])
                    let bodyAttributes = MarkdownAttributeSet(font: nameFont, textColor: inlineBotNameColor)
                    let boldAttributes = MarkdownAttributeSet(font: inlineBotPrefixFont, textColor: inlineBotNameColor)
                    let botString = addAttributesToStringWithRanges(item.presentationData.strings.Conversation_MessageViaUser("@\(inlineBotNameString)"), body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    mutableString.append(botString)
                    attributedString = mutableString
                } else if let authorNameString = authorNameString, let authorNameColor = authorNameColor {
                    attributedString = NSAttributedString(string: authorNameString, font: nameFont, textColor: authorNameColor)
                } else if let inlineBotNameString = inlineBotNameString {
                    let bodyAttributes = MarkdownAttributeSet(font: inlineBotPrefixFont, textColor: inlineBotNameColor)
                    let boldAttributes = MarkdownAttributeSet(font: nameFont, textColor: inlineBotNameColor)
                    attributedString = addAttributesToStringWithRanges(item.presentationData.strings.Conversation_MessageViaUser("@\(inlineBotNameString)"), body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                } else {
                    attributedString = NSAttributedString(string: "", font: nameFont, textColor: inlineBotNameColor)
                }
                
                var credibilityIconWidth: CGFloat = 0.0
                if let credibilityIconImage = currentCredibilityIconImage {
                    credibilityIconWidth += credibilityIconImage.size.width + 4.0
                }
                let adminBadgeSizeAndApply = adminBadgeLayout(TextNodeLayoutArguments(attributedString: adminBadgeString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                adminNodeSizeApply = (adminBadgeSizeAndApply.0.size, {
                    return adminBadgeSizeAndApply.1()
                })
                
                let sizeAndApply = authorNameLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right - credibilityIconWidth - adminBadgeSizeAndApply.0.size.width), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                nameNodeSizeApply = (sizeAndApply.0.size, {
                    return sizeAndApply.1()
                })

                nameNodeOriginY = headerSize.height
                headerSize.width = max(headerSize.width, nameNodeSizeApply.0.width + adminBadgeSizeAndApply.0.size.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right + credibilityIconWidth)
                headerSize.height += nameNodeSizeApply.0.height
            }

            if !ignoreForward, let forwardInfo = firstMessage.forwardInfo {
                if headerSize.height.isZero {
                    headerSize.height += 5.0
                }
                
                let forwardPsaType: String? = forwardInfo.psaType
                
                if let source = forwardInfo.source {
                    forwardSource = source
                    if let authorSignature = forwardInfo.authorSignature {
                        forwardAuthorSignature = authorSignature
                    } else if let forwardInfoAuthor = forwardInfo.author, forwardInfoAuthor.id != source.id {
                        forwardAuthorSignature = forwardInfoAuthor.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    } else {
                        forwardAuthorSignature = nil
                    }
                } else {
                    if let currentForwardInfo = currentForwardInfo, forwardInfo.author == nil && currentForwardInfo.0 != nil {
                        forwardSource = nil
                        forwardAuthorSignature = currentForwardInfo.0?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    } else {
                        forwardSource = forwardInfo.author
                        forwardAuthorSignature = forwardInfo.authorSignature
                    }
                }
                let sizeAndApply = forwardInfoLayout(item.presentationData, item.presentationData.strings, .bubble(incoming: incoming), forwardSource, forwardAuthorSignature, forwardPsaType, CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right, height: CGFloat.greatestFiniteMagnitude))
                forwardInfoSizeApply = (sizeAndApply.0, { width in sizeAndApply.1(width) })
                
                forwardInfoOriginY = headerSize.height
                headerSize.width = max(headerSize.width, forwardInfoSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                headerSize.height += forwardInfoSizeApply.0.height
            }
            
            if let replyMessage = replyMessage {
                if headerSize.height.isZero {
                    headerSize.height += 6.0
                } else {
                    headerSize.height += 2.0
                }
                let sizeAndApply = replyInfoLayout(item.presentationData, item.presentationData.strings, item.context, .bubble(incoming: incoming), replyMessage, CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right, height: CGFloat.greatestFiniteMagnitude))
                replyInfoSizeApply = (sizeAndApply.0, { sizeAndApply.1() })
                
                replyInfoOriginY = headerSize.height
                headerSize.width = max(headerSize.width, replyInfoSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                headerSize.height += replyInfoSizeApply.0.height + 2.0
            }
            
            if !headerSize.height.isZero {
                headerSize.height -= 5.0
            }
        }
        
        let hideBackground: Bool
        if let backgroundHiding = backgroundHiding {
            switch backgroundHiding {
                case .never:
                    hideBackground = false
                case .emptyWallpaper:
                    hideBackground = hasSolidWallpaper && !displayHeader
                case .always:
                    hideBackground = true
            }
        } else {
            hideBackground = false
        }
        
        var removedContentNodeIndices: [Int]?
        findRemoved: for i in 0 ..< currentContentClassesPropertiesAndLayouts.count {
            let currentMessage = currentContentClassesPropertiesAndLayouts[i].0
            let currentClass: AnyClass = currentContentClassesPropertiesAndLayouts[i].1
            for (contentNodeMessage, contentNodeClass, _) in contentNodeMessagesAndClasses {
                if currentClass == contentNodeClass && currentMessage.stableId == contentNodeMessage.stableId {
                    continue findRemoved
                }
            }
            if removedContentNodeIndices == nil {
                removedContentNodeIndices = [i]
            } else {
                removedContentNodeIndices!.append(i)
            }
        }
        
        var contentNodePropertiesAndFinalize: [(ChatMessageBubbleContentProperties, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))] = []
        
        var maxContentWidth: CGFloat = headerSize.width
        
        var actionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animated: Bool) -> ChatMessageActionButtonsNode))?
        if let replyMarkup = replyMarkup {
            let (minWidth, buttonsLayout) = actionButtonsLayout(item.context, item.presentationData.theme, item.presentationData.chatBubbleCorners, item.presentationData.strings, replyMarkup, item.message, maximumNodeWidth)
            maxContentWidth = max(maxContentWidth, minWidth)
            actionButtonsFinalize = buttonsLayout
        }
        
        for i in 0 ..< contentPropertiesAndLayouts.count {
            let (_, contentNodeProperties, preparePosition, contentNodeLayout) = contentPropertiesAndLayouts[i]
            
            if let mosaicRange = mosaicRange, mosaicRange.contains(i), let (framesAndPositions, size) = calculatedGroupFramesAndSize {
                let mosaicIndex = i - mosaicRange.lowerBound
                
                let position = framesAndPositions[mosaicIndex].1
                
                let topLeft: ChatMessageBubbleContentMosaicNeighbor
                let topRight: ChatMessageBubbleContentMosaicNeighbor
                let bottomLeft: ChatMessageBubbleContentMosaicNeighbor
                let bottomRight: ChatMessageBubbleContentMosaicNeighbor
                
                switch firstNodeTopPosition {
                    case .Neighbour:
                        topLeft = .merged
                        topRight = .merged
                    case .BubbleNeighbour:
                        topLeft = .mergedBubble
                        topRight = .mergedBubble
                    case let .None(status):
                        if position.contains(.top) && position.contains(.left) {
                            switch status {
                            case .Left:
                                topLeft = .mergedBubble
                            case .Right:
                                topLeft = .none(tail: false)
                            case .None:
                                topLeft = .none(tail: false)
                            }
                        } else {
                            topLeft = .merged
                        }
                        
                        if position.contains(.top) && position.contains(.right) {
                            switch status {
                            case .Left:
                                topRight = .none(tail: false)
                            case .Right:
                                topRight = .mergedBubble
                            case .None:
                                topRight = .none(tail: false)
                            }
                        } else {
                            topRight = .merged
                        }
                }
                
                let lastMosaicBottomPosition: ChatMessageBubbleRelativePosition
                if mosaicRange.upperBound - 1 == contentNodeCount - 1 {
                    lastMosaicBottomPosition = lastNodeTopPosition
                } else {
                    lastMosaicBottomPosition = .Neighbour
                }
                
                if position.contains(.bottom), case .Neighbour = lastMosaicBottomPosition {
                    bottomLeft = .merged
                    bottomRight = .merged
                } else {
                    switch lastNodeTopPosition {
                        case .Neighbour:
                            bottomLeft = .merged
                            bottomRight = .merged
                        case .BubbleNeighbour:
                            bottomLeft = .mergedBubble
                            bottomRight = .mergedBubble
                        case let .None(status):
                            if position.contains(.bottom) && position.contains(.left) {
                                switch status {
                                case .Left:
                                    bottomLeft = .mergedBubble
                                case .Right:
                                    bottomLeft = .none(tail: false)
                                case let .None(tailStatus):
                                    if case .Incoming = tailStatus {
                                        bottomLeft = .none(tail: true)
                                    } else {
                                        bottomLeft = .none(tail: false)
                                    }
                                }
                            } else {
                                bottomLeft = .merged
                            }
                            
                            if position.contains(.bottom) && position.contains(.right) {
                                switch status {
                                case .Left:
                                    bottomRight = .none(tail: false)
                                case .Right:
                                    bottomRight = .mergedBubble
                                case let .None(tailStatus):
                                    if case .Outgoing = tailStatus {
                                        bottomRight = .none(tail: true)
                                    } else {
                                        bottomRight = .none(tail: false)
                                    }
                                }
                            } else {
                                bottomRight = .merged
                            }
                    }
                }
                
                let (_, contentNodeFinalize) = contentNodeLayout(framesAndPositions[mosaicIndex].0.size, .mosaic(position: ChatMessageBubbleContentMosaicPosition(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight), wide: position.isWide))
                
                contentNodePropertiesAndFinalize.append((contentNodeProperties, contentNodeFinalize))
                
                maxContentWidth = max(maxContentWidth, size.width)
            } else {
                let contentPosition: ChatMessageBubbleContentPosition
                switch preparePosition {
                    case .linear:
                        let topPosition: ChatMessageBubbleRelativePosition
                        let bottomPosition: ChatMessageBubbleRelativePosition

                        if i == 0 {
                            topPosition = firstNodeTopPosition
                        } else {
                            topPosition = .Neighbour
                        }
                        
                        if i == contentNodeCount - 1 {
                            bottomPosition = lastNodeTopPosition
                        } else {
                            bottomPosition = .Neighbour
                        }
                    
                        contentPosition = .linear(top: topPosition, bottom: bottomPosition)
                    case .mosaic:
                        assertionFailure()
                        contentPosition = .linear(top: .Neighbour, bottom: .Neighbour)
                }
                let (contentNodeWidth, contentNodeFinalize) = contentNodeLayout(CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude), contentPosition)
                #if DEBUG
                if contentNodeWidth > maximumNodeWidth {
                    print("contentNodeWidth \(contentNodeWidth) > \(maximumNodeWidth)")
                }
                #endif
                maxContentWidth = max(maxContentWidth, contentNodeWidth)
                
                contentNodePropertiesAndFinalize.append((contentNodeProperties, contentNodeFinalize))
            }
        }
        
        var contentSize = CGSize(width: maxContentWidth, height: 0.0)
        var contentNodeFramesPropertiesAndApply: [(CGRect, ChatMessageBubbleContentProperties, (ListViewItemUpdateAnimation, Bool) -> Void)] = []
        var contentNodesHeight: CGFloat = 0.0
        var mosaicStatusOrigin: CGPoint?
        for i in 0 ..< contentNodePropertiesAndFinalize.count {
            let (properties, finalize) = contentNodePropertiesAndFinalize[i]
            
            if let mosaicRange = mosaicRange, mosaicRange.contains(i), let (framesAndPositions, size) = calculatedGroupFramesAndSize {
                let mosaicIndex = i - mosaicRange.lowerBound
                
                if mosaicIndex == 0 {
                    if !headerSize.height.isZero {
                        contentNodesHeight += 7.0
                    }
                }
                
                let (_, apply) = finalize(maxContentWidth)
                let contentNodeFrame = framesAndPositions[mosaicIndex].0.offsetBy(dx: 0.0, dy: contentNodesHeight)
                contentNodeFramesPropertiesAndApply.append((contentNodeFrame, properties, apply))
                
                if mosaicIndex == mosaicRange.upperBound - 1 {
                    contentNodesHeight += size.height
                    
                    mosaicStatusOrigin = contentNodeFrame.bottomRight
                }
            } else {
                if i == 0 && !headerSize.height.isZero {
                    contentNodesHeight += properties.headerSpacing
                }
                
                let (size, apply) = finalize(maxContentWidth)
                contentNodeFramesPropertiesAndApply.append((CGRect(origin: CGPoint(x: 0.0, y: contentNodesHeight), size: size), properties, apply))
                
                contentNodesHeight += size.height
            }
        }
        contentSize.height += contentNodesHeight
        
        var actionButtonsSizeAndApply: (CGSize, (Bool) -> ChatMessageActionButtonsNode)?
        if let actionButtonsFinalize = actionButtonsFinalize {
            actionButtonsSizeAndApply = actionButtonsFinalize(maxContentWidth)
        }
        
        let minimalContentSize: CGSize
        if hideBackground {
            minimalContentSize = CGSize(width: 1.0, height: 1.0)
        } else {
            minimalContentSize = layoutConstants.bubble.minimumSize
        }
        let calculatedBubbleHeight = headerSize.height + contentSize.height + layoutConstants.bubble.contentInsets.top + layoutConstants.bubble.contentInsets.bottom
        let layoutBubbleSize = CGSize(width: max(contentSize.width, headerSize.width) + layoutConstants.bubble.contentInsets.left + layoutConstants.bubble.contentInsets.right, height: max(minimalContentSize.height, calculatedBubbleHeight))
        
        var contentVerticalOffset: CGFloat = 0.0
        if minimalContentSize.height > calculatedBubbleHeight + 2.0 {
            contentVerticalOffset = floorToScreenPixels((minimalContentSize.height - calculatedBubbleHeight) / 2.0)
        }
        
        let backgroundFrame: CGRect
        let contentOrigin: CGPoint
        let contentUpperRightCorner: CGPoint
        switch alignment {
            case .none:
                backgroundFrame = CGRect(origin: CGPoint(x: incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + avatarInset) : (params.width - params.rightInset - layoutBubbleSize.width - layoutConstants.bubble.edgeInset - deliveryFailedInset), y: 0.0), size: layoutBubbleSize)
                contentOrigin = CGPoint(x: backgroundFrame.origin.x + (incoming ? layoutConstants.bubble.contentInsets.left : layoutConstants.bubble.contentInsets.right), y: backgroundFrame.origin.y + layoutConstants.bubble.contentInsets.top + headerSize.height + contentVerticalOffset)
                contentUpperRightCorner = CGPoint(x: backgroundFrame.maxX - (incoming ? layoutConstants.bubble.contentInsets.right : layoutConstants.bubble.contentInsets.left), y: backgroundFrame.origin.y + layoutConstants.bubble.contentInsets.top + headerSize.height)
            case .center:
                let availableWidth = params.width - params.leftInset - params.rightInset
                backgroundFrame = CGRect(origin: CGPoint(x: params.leftInset + floor((availableWidth - layoutBubbleSize.width) / 2.0), y: 0.0), size: layoutBubbleSize)
                contentOrigin = CGPoint(x: backgroundFrame.minX + floor(layoutConstants.bubble.contentInsets.right + layoutConstants.bubble.contentInsets.left) / 2.0, y: backgroundFrame.minY + layoutConstants.bubble.contentInsets.top + headerSize.height + contentVerticalOffset)
                contentUpperRightCorner = CGPoint(x: backgroundFrame.maxX - (incoming ? layoutConstants.bubble.contentInsets.right : layoutConstants.bubble.contentInsets.left), y: backgroundFrame.origin.y + layoutConstants.bubble.contentInsets.top + headerSize.height)
        }
        
        let bubbleContentWidth = maxContentWidth - layoutConstants.bubble.edgeInset * 2.0 - (layoutConstants.bubble.contentInsets.right + layoutConstants.bubble.contentInsets.left)

        var layoutSize = CGSize(width: params.width, height: layoutBubbleSize.height)
        if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
            layoutSize.height += actionButtonsSizeAndApply.0.height
        }
        
        var layoutInsets = UIEdgeInsets(top: mergedTop.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
        if dateHeaderAtBottom {
            layoutInsets.top += layoutConstants.timestampHeaderHeight
        }
        
        var updatedShareButtonBackground: UIImage?
        
        var updatedShareButtonNode: HighlightableButtonNode?
        if needShareButton {
            if currentShareButtonNode != nil {
                updatedShareButtonNode = currentShareButtonNode
                if item.presentationData.theme !== currentItem?.presentationData.theme {
                    let graphics = PresentationResourcesChat.additionalGraphics(item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, bubbleCorners: item.presentationData.chatBubbleCorners)
                    if item.message.id.peerId == item.context.account.peerId {
                        updatedShareButtonBackground = graphics.chatBubbleNavigateButtonImage
                    } else {
                        updatedShareButtonBackground = graphics.chatBubbleShareButtonImage
                    }
                }
            } else {
                let buttonNode = HighlightableButtonNode()
                let buttonIcon: UIImage?
                let graphics = PresentationResourcesChat.additionalGraphics(item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, bubbleCorners: item.presentationData.chatBubbleCorners)
                if item.message.id.peerId == item.context.account.peerId {
                    buttonIcon = graphics.chatBubbleNavigateButtonImage
                } else {
                    buttonIcon = graphics.chatBubbleShareButtonImage
                }
                buttonNode.setBackgroundImage(buttonIcon, for: [.normal])
                updatedShareButtonNode = buttonNode
            }
        }
        
        let layout = ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets)
        
        let graphics = PresentationResourcesChat.principalGraphics(mediaBox: item.context.account.postbox.mediaBox, knockoutWallpaper: item.context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper, theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, bubbleCorners: item.presentationData.chatBubbleCorners)
        
        var updatedMergedTop = mergedBottom
        var updatedMergedBottom = mergedTop
        if mosaicRange == nil {
            if contentNodePropertiesAndFinalize.first?.0.forceFullCorners ?? false {
                updatedMergedTop = .semanticallyMerged
            }
            if headerSize.height.isZero && contentNodePropertiesAndFinalize.first?.0.forceFullCorners ?? false {
                updatedMergedBottom = .none
            }
            if actionButtonsSizeAndApply != nil {
                updatedMergedTop = .fullyMerged
            }
        }
        
        return (layout, { animation, synchronousLoads in
            return ChatMessageBubbleItemNode.applyLayout(selfReference: selfReference, animation, synchronousLoads,
                params: params,
                layout: layout,
                item: item,
                forwardSource: forwardSource,
                forwardAuthorSignature: forwardAuthorSignature,
                accessibilityData: accessibilityData,
                actionButtonsSizeAndApply: actionButtonsSizeAndApply,
                updatedMergedTop: updatedMergedTop,
                updatedMergedBottom: updatedMergedBottom,
                hideBackground: hideBackground,
                incoming: incoming,
                graphics: graphics,
                bubbleContentWidth: bubbleContentWidth,
                backgroundFrame: backgroundFrame,
                deliveryFailedInset: deliveryFailedInset,
                nameNodeSizeApply: nameNodeSizeApply,
                contentOrigin: contentOrigin,
                nameNodeOriginY: nameNodeOriginY,
                layoutConstants: layoutConstants,
                currentCredibilityIconImage: currentCredibilityIconImage,
                adminNodeSizeApply: adminNodeSizeApply,
                contentUpperRightCorner: contentUpperRightCorner,
                forwardInfoSizeApply: forwardInfoSizeApply,
                forwardInfoOriginY: forwardInfoOriginY,
                replyInfoSizeApply: replyInfoSizeApply,
                replyInfoOriginY: replyInfoOriginY,
                removedContentNodeIndices: removedContentNodeIndices,
                addedContentNodes: addedContentNodes,
                contentNodeMessagesAndClasses: contentNodeMessagesAndClasses,
                contentNodeFramesPropertiesAndApply: contentNodeFramesPropertiesAndApply,
                mosaicStatusOrigin: mosaicStatusOrigin,
                mosaicStatusSizeAndApply: mosaicStatusSizeAndApply,
                updatedShareButtonNode: updatedShareButtonNode,
                updatedShareButtonBackground: updatedShareButtonBackground
            )
        })
    }
    
    private static func applyLayout(selfReference: Weak<ChatMessageBubbleItemNode>, _ animation: ListViewItemUpdateAnimation, _ synchronousLoads: Bool,
        params: ListViewItemLayoutParams,
        layout: ListViewItemNodeLayout,
        item: ChatMessageItem,
        forwardSource: Peer?,
        forwardAuthorSignature: String?,
        accessibilityData: ChatMessageAccessibilityData,
        actionButtonsSizeAndApply: (CGSize, (Bool) -> ChatMessageActionButtonsNode)?,
        updatedMergedTop: ChatMessageMerge,
        updatedMergedBottom: ChatMessageMerge,
        hideBackground: Bool,
        incoming: Bool,
        graphics: PrincipalThemeEssentialGraphics,
        bubbleContentWidth: CGFloat,
        backgroundFrame: CGRect,
        deliveryFailedInset: CGFloat,
        nameNodeSizeApply: (CGSize, () -> TextNode?),
        contentOrigin: CGPoint,
        nameNodeOriginY: CGFloat,
        layoutConstants: ChatMessageItemLayoutConstants,
        currentCredibilityIconImage: UIImage?,
        adminNodeSizeApply: (CGSize, () -> TextNode?),
        contentUpperRightCorner: CGPoint,
        forwardInfoSizeApply: (CGSize, (CGFloat) -> ChatMessageForwardInfoNode?),
        forwardInfoOriginY: CGFloat,
        replyInfoSizeApply: (CGSize, () -> ChatMessageReplyInfoNode?),
        replyInfoOriginY: CGFloat,
        removedContentNodeIndices: [Int]?,
        addedContentNodes: [(Message, ChatMessageBubbleContentNode)]?,
        contentNodeMessagesAndClasses: [(Message, AnyClass, ChatMessageEntryAttributes)],
        contentNodeFramesPropertiesAndApply: [(CGRect, ChatMessageBubbleContentProperties, (ListViewItemUpdateAnimation, Bool) -> Void)],
        mosaicStatusOrigin: CGPoint?,
        mosaicStatusSizeAndApply: (CGSize, (Bool) -> ChatMessageDateAndStatusNode)?,
        updatedShareButtonNode: HighlightableButtonNode?,
        updatedShareButtonBackground: UIImage?
    ) -> Void {
        guard let strongSelf = selfReference.value else {
            return
        }
        let previousContextFrame = strongSelf.containerNode.frame
        strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
        strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
        strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
        
        strongSelf.appliedItem = item
        strongSelf.appliedForwardInfo = (forwardSource, forwardAuthorSignature)
        strongSelf.updateAccessibilityData(accessibilityData)
        
        var transition: ContainedViewLayoutTransition = .immediate
        if case let .System(duration) = animation {
            transition = .animated(duration: duration, curve: .spring)
        }
        
        var forceBackgroundSide = false
        if actionButtonsSizeAndApply != nil {
            forceBackgroundSide = true
        } else if case .semanticallyMerged = updatedMergedTop {
            forceBackgroundSide = true
        }
        let mergeType = ChatMessageBackgroundMergeType(top: updatedMergedTop == .fullyMerged, bottom: updatedMergedBottom == .fullyMerged, side: forceBackgroundSide)
        let backgroundType: ChatMessageBackgroundType
        if hideBackground {
            backgroundType = .none
        } else if !incoming {
            backgroundType = .outgoing(mergeType)
        } else {
            backgroundType = .incoming(mergeType)
        }
        let hasWallpaper = item.presentationData.theme.wallpaper.hasWallpaper
        strongSelf.backgroundNode.setType(type: backgroundType, highlighted: strongSelf.highlightedState, graphics: graphics, maskMode: strongSelf.backgroundMaskMode, hasWallpaper: hasWallpaper, transition: transition)
        strongSelf.backgroundWallpaperNode.setType(type: backgroundType, theme: item.presentationData.theme, mediaBox: item.context.account.postbox.mediaBox, essentialGraphics: graphics, maskMode: strongSelf.backgroundMaskMode)
        strongSelf.shadowNode.setType(type: backgroundType, hasWallpaper: hasWallpaper, graphics: graphics)
        
        strongSelf.backgroundType = backgroundType
        
        let isFailed = item.content.firstMessage.effectivelyFailed(timestamp: item.context.account.network.getApproximateRemoteTimestamp())
        if isFailed {
            let deliveryFailedNode: ChatMessageDeliveryFailedNode
            var isAppearing = false
            if let current = strongSelf.deliveryFailedNode {
                deliveryFailedNode = current
            } else {
                isAppearing = true
                deliveryFailedNode = ChatMessageDeliveryFailedNode(tapped: { [weak strongSelf] in
                    if let item = strongSelf?.item {
                    item.controllerInteraction.requestRedeliveryOfFailedMessages(item.content.firstMessage.id)
                    }
                })
                strongSelf.deliveryFailedNode = deliveryFailedNode
                strongSelf.insertSubnode(deliveryFailedNode, belowSubnode: strongSelf.messageAccessibilityArea)
            }
            let deliveryFailedSize = deliveryFailedNode.updateLayout(theme: item.presentationData.theme.theme)
            let deliveryFailedFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX + deliveryFailedInset - deliveryFailedSize.width, y: backgroundFrame.maxY - deliveryFailedSize.height), size: deliveryFailedSize)
            if isAppearing {
                deliveryFailedNode.frame = deliveryFailedFrame
                transition.animatePositionAdditive(node: deliveryFailedNode, offset: CGPoint(x: deliveryFailedInset, y: 0.0))
            } else {
                transition.updateFrame(node: deliveryFailedNode, frame: deliveryFailedFrame)
            }
        } else if let deliveryFailedNode = strongSelf.deliveryFailedNode {
            strongSelf.deliveryFailedNode = nil
            transition.updateAlpha(node: deliveryFailedNode, alpha: 0.0)
            transition.updateFrame(node: deliveryFailedNode, frame: deliveryFailedNode.frame.offsetBy(dx: 24.0, dy: 0.0), completion: { [weak deliveryFailedNode] _ in
                deliveryFailedNode?.removeFromSupernode()
            })
        }
        
        if let nameNode = nameNodeSizeApply.1() {
            strongSelf.nameNode = nameNode
            if nameNode.supernode == nil {
                if !nameNode.isNodeLoaded {
                    nameNode.isUserInteractionEnabled = false
                }
                strongSelf.contextSourceNode.contentNode.addSubnode(nameNode)
            }
            nameNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + nameNodeOriginY), size: nameNodeSizeApply.0)
            
            if let credibilityIconImage = currentCredibilityIconImage {
                let credibilityIconNode: ASImageNode
                if let node = strongSelf.credibilityIconNode {
                    credibilityIconNode = node
                } else {
                    credibilityIconNode = ASImageNode()
                    strongSelf.credibilityIconNode = credibilityIconNode
                    strongSelf.contextSourceNode.contentNode.addSubnode(credibilityIconNode)
                }
                credibilityIconNode.frame = CGRect(origin: CGPoint(x: nameNode.frame.maxX + 4.0, y: nameNode.frame.minY), size: credibilityIconImage.size)
                credibilityIconNode.image = credibilityIconImage
            } else {
                strongSelf.credibilityIconNode?.removeFromSupernode()
                strongSelf.credibilityIconNode = nil
            }
            
            if let adminBadgeNode = adminNodeSizeApply.1() {
                strongSelf.adminBadgeNode = adminBadgeNode
                let adminBadgeFrame = CGRect(origin: CGPoint(x: contentUpperRightCorner.x - layoutConstants.text.bubbleInsets.left - adminNodeSizeApply.0.width, y: layoutConstants.bubble.contentInsets.top + nameNodeOriginY), size: adminNodeSizeApply.0)
                if adminBadgeNode.supernode == nil {
                    if !adminBadgeNode.isNodeLoaded {
                        adminBadgeNode.isUserInteractionEnabled = false
                    }
                    strongSelf.contextSourceNode.contentNode.addSubnode(adminBadgeNode)
                    adminBadgeNode.frame = adminBadgeFrame
                } else {
                    let previousAdminBadgeFrame = adminBadgeNode.frame
                    adminBadgeNode.frame = adminBadgeFrame
                    transition.animatePositionAdditive(node: adminBadgeNode, offset: CGPoint(x: previousAdminBadgeFrame.maxX - adminBadgeFrame.maxX, y: 0.0))
                }
            } else {
                strongSelf.adminBadgeNode?.removeFromSupernode()
                strongSelf.adminBadgeNode = nil
            }
        } else {
            strongSelf.nameNode?.removeFromSupernode()
            strongSelf.nameNode = nil
            strongSelf.adminBadgeNode?.removeFromSupernode()
            strongSelf.adminBadgeNode = nil
        }
        
        if let forwardInfoNode = forwardInfoSizeApply.1(bubbleContentWidth) {
            strongSelf.forwardInfoNode = forwardInfoNode
            var animateFrame = true
            if forwardInfoNode.supernode == nil {
                strongSelf.contextSourceNode.contentNode.addSubnode(forwardInfoNode)
                animateFrame = false
                forwardInfoNode.openPsa = { [weak strongSelf] type, sourceNode in
                    guard let strongSelf = strongSelf, let item = strongSelf.item else {
                        return
                    }
                    item.controllerInteraction.displayPsa(type, sourceNode)
                }
            }
            let previousForwardInfoNodeFrame = forwardInfoNode.frame
            forwardInfoNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + forwardInfoOriginY), size: CGSize(width: bubbleContentWidth, height: forwardInfoSizeApply.0.height))
            if case let .System(duration) = animation {
                if animateFrame {
                    forwardInfoNode.layer.animateFrame(from: previousForwardInfoNodeFrame, to: forwardInfoNode.frame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
        } else {
            strongSelf.forwardInfoNode?.removeFromSupernode()
            strongSelf.forwardInfoNode = nil
        }
        
        if let replyInfoNode = replyInfoSizeApply.1() {
            strongSelf.replyInfoNode = replyInfoNode
            var animateFrame = true
            if replyInfoNode.supernode == nil {
                strongSelf.contextSourceNode.contentNode.addSubnode(replyInfoNode)
                animateFrame = false
            }
            let previousReplyInfoNodeFrame = replyInfoNode.frame
            replyInfoNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + replyInfoOriginY), size: replyInfoSizeApply.0)
            if case let .System(duration) = animation {
                if animateFrame {
                    replyInfoNode.layer.animateFrame(from: previousReplyInfoNodeFrame, to: replyInfoNode.frame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
        } else {
            strongSelf.replyInfoNode?.removeFromSupernode()
            strongSelf.replyInfoNode = nil
        }
        
        if removedContentNodeIndices?.count ?? 0 != 0 || addedContentNodes?.count ?? 0 != 0 {
            var updatedContentNodes = strongSelf.contentNodes
            
            if let removedContentNodeIndices = removedContentNodeIndices {
                for index in removedContentNodeIndices.reversed() {
                    if index >= 0 && index < updatedContentNodes.count {
                        let node = updatedContentNodes[index]
                        if animation.isAnimated {
                            node.animateRemovalFromBubble(0.2, completion: { [weak node] in
                                node?.removeFromSupernode()
                            })
                        } else {
                            node.removeFromSupernode()
                        }
                        let _ = updatedContentNodes.remove(at: index)
                    }
                }
            }
            
            if let addedContentNodes = addedContentNodes {
                for (_, contentNode) in addedContentNodes {
                    updatedContentNodes.append(contentNode)
                    strongSelf.contextSourceNode.contentNode.addSubnode(contentNode)
                    
                    contentNode.visibility = strongSelf.visibility
                    contentNode.updateIsTextSelectionActive = { [weak strongSelf] value in
                        strongSelf?.contextSourceNode.updateDistractionFreeMode?(value)
                    }
                    contentNode.updateIsExtractedToContextPreview(strongSelf.contextSourceNode.isExtractedToContextPreview)
                }
            }
            
            var sortedContentNodes: [ChatMessageBubbleContentNode] = []
            outer: for (message, nodeClass, _) in contentNodeMessagesAndClasses {
                if let addedContentNodes = addedContentNodes {
                    for (contentNodeMessage, contentNode) in addedContentNodes {
                        if type(of: contentNode) == nodeClass && contentNodeMessage.stableId == message.stableId {
                            sortedContentNodes.append(contentNode)
                            continue outer
                        }
                    }
                }
                for contentNode in updatedContentNodes {
                    if type(of: contentNode) == nodeClass && contentNode.item?.message.stableId == message.stableId {
                        sortedContentNodes.append(contentNode)
                        continue outer
                    }
                }
            }
            
            assert(sortedContentNodes.count == updatedContentNodes.count)
            
            strongSelf.contentNodes = sortedContentNodes
        }
        
        var contentNodeIndex = 0
        for (relativeFrame, _, apply) in contentNodeFramesPropertiesAndApply {
            apply(animation, synchronousLoads)
            
            if contentNodeIndex >= strongSelf.contentNodes.count {
                break
            }
            
            let contentNode = strongSelf.contentNodes[contentNodeIndex]
            let contentNodeFrame = relativeFrame.offsetBy(dx: contentOrigin.x, dy: contentOrigin.y)
            let previousContentNodeFrame = contentNode.frame
            contentNode.frame = contentNodeFrame
            
            if case let .System(duration) = animation {
                var animateFrame = false
                var animateAlpha = false
                if let addedContentNodes = addedContentNodes {
                    if !addedContentNodes.contains(where: { $0.1 === contentNode }) {
                        animateFrame = true
                    } else {
                        animateAlpha = true
                    }
                } else {
                    animateFrame = true
                }
                
                if animateFrame {
                    contentNode.layer.animateFrame(from: previousContentNodeFrame, to: contentNodeFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                } else if animateAlpha {
                    contentNode.animateInsertionIntoBubble(duration)
                    var previousAlignedContentNodeFrame = contentNodeFrame
                    previousAlignedContentNodeFrame.origin.x += backgroundFrame.size.width - strongSelf.backgroundNode.frame.size.width
                    contentNode.layer.animateFrame(from: previousAlignedContentNodeFrame, to: contentNodeFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
            contentNodeIndex += 1
        }
        
        if let mosaicStatusOrigin = mosaicStatusOrigin, let (size, apply) = mosaicStatusSizeAndApply {
            let mosaicStatusNode = apply(false)
            if mosaicStatusNode !== strongSelf.mosaicStatusNode {
                strongSelf.mosaicStatusNode?.removeFromSupernode()
                strongSelf.mosaicStatusNode = mosaicStatusNode
                strongSelf.contextSourceNode.contentNode.addSubnode(mosaicStatusNode)
            }
            let absoluteOrigin = mosaicStatusOrigin.offsetBy(dx: contentOrigin.x, dy: contentOrigin.y)
            mosaicStatusNode.frame = CGRect(origin: CGPoint(x: absoluteOrigin.x - layoutConstants.image.statusInsets.right - size.width, y: absoluteOrigin.y - layoutConstants.image.statusInsets.bottom - size.height), size: size)
        } else if let mosaicStatusNode = strongSelf.mosaicStatusNode {
            strongSelf.mosaicStatusNode = nil
            mosaicStatusNode.removeFromSupernode()
        }
        
        if let updatedShareButtonNode = updatedShareButtonNode {
            if updatedShareButtonNode !== strongSelf.shareButtonNode {
                if let shareButtonNode = strongSelf.shareButtonNode {
                    shareButtonNode.removeFromSupernode()
                }
                strongSelf.shareButtonNode = updatedShareButtonNode
                strongSelf.insertSubnode(updatedShareButtonNode, belowSubnode: strongSelf.messageAccessibilityArea)
                updatedShareButtonNode.addTarget(strongSelf, action: #selector(strongSelf.shareButtonPressed), forControlEvents: .touchUpInside)
            }
            if let updatedShareButtonBackground = updatedShareButtonBackground {
                strongSelf.shareButtonNode?.setBackgroundImage(updatedShareButtonBackground, for: [.normal])
            }
        } else if let shareButtonNode = strongSelf.shareButtonNode {
            shareButtonNode.removeFromSupernode()
            strongSelf.shareButtonNode = nil
        }
        
        if case .System = animation, !strongSelf.contextSourceNode.isExtractedToContextPreview {
            if !strongSelf.backgroundNode.frame.equalTo(backgroundFrame) {
                strongSelf.backgroundFrameTransition = (strongSelf.backgroundNode.frame, backgroundFrame)
                strongSelf.enableTransitionClippingNode()
            }
            if let shareButtonNode = strongSelf.shareButtonNode {
                let currentBackgroundFrame = strongSelf.backgroundNode.frame
                shareButtonNode.frame = CGRect(origin: CGPoint(x: currentBackgroundFrame.maxX + 8.0, y: currentBackgroundFrame.maxY - 30.0), size: CGSize(width: 29.0, height: 29.0))
            }
        } else {
            if let _ = strongSelf.backgroundFrameTransition {
                strongSelf.animateFrameTransition(1.0, backgroundFrame.size.height)
                strongSelf.backgroundFrameTransition = nil
            }
            strongSelf.messageAccessibilityArea.frame = backgroundFrame
            if let shareButtonNode = strongSelf.shareButtonNode {
                shareButtonNode.frame = CGRect(origin: CGPoint(x: backgroundFrame.maxX + 8.0, y: backgroundFrame.maxY - 30.0), size: CGSize(width: 29.0, height: 29.0))
            }
            strongSelf.disableTransitionClippingNode()
            
            if case .System = animation, strongSelf.contextSourceNode.isExtractedToContextPreview {
                transition.updateFrame(node: strongSelf.backgroundNode, frame: backgroundFrame)
                strongSelf.backgroundNode.updateLayout(size: backgroundFrame.size, transition: transition)
                strongSelf.backgroundWallpaperNode.updateFrame(backgroundFrame, transition: transition)
                strongSelf.shadowNode.updateLayout(backgroundFrame: backgroundFrame, transition: transition)
            } else {
                strongSelf.backgroundNode.frame = backgroundFrame
                strongSelf.backgroundNode.updateLayout(size: backgroundFrame.size, transition: .immediate)
                strongSelf.backgroundWallpaperNode.frame = backgroundFrame
                strongSelf.shadowNode.updateLayout(backgroundFrame: backgroundFrame, transition: .immediate)
            }
            if let (rect, size) = strongSelf.absoluteRect {
                strongSelf.updateAbsoluteRect(rect, within: size)
            }
        }
        let offset: CGFloat = params.leftInset + (incoming ? 42.0 : 0.0)
        let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: params.width, height: layout.contentSize.height))
        strongSelf.selectionNode?.frame = selectionFrame
        strongSelf.selectionNode?.updateLayout(size: selectionFrame.size)
        
        if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
            var animated = false
            if let _ = strongSelf.actionButtonsNode {
                if case .System = animation {
                    animated = true
                }
            }
            let actionButtonsNode = actionButtonsSizeAndApply.1(animated)
            let previousFrame = actionButtonsNode.frame
            let actionButtonsFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + (incoming ? layoutConstants.bubble.contentInsets.left : layoutConstants.bubble.contentInsets.right), y: backgroundFrame.maxY), size: actionButtonsSizeAndApply.0)
            actionButtonsNode.frame = actionButtonsFrame
            if actionButtonsNode !== strongSelf.actionButtonsNode {
                strongSelf.actionButtonsNode = actionButtonsNode
                actionButtonsNode.buttonPressed = { [weak strongSelf] button in
                    if let strongSelf = strongSelf {
                        strongSelf.performMessageButtonAction(button: button)
                    }
                }
                actionButtonsNode.buttonLongTapped = { [weak strongSelf] button in
                    if let strongSelf = strongSelf {
                        strongSelf.presentMessageButtonContextMenu(button: button)
                    }
                }
                strongSelf.insertSubnode(actionButtonsNode, belowSubnode: strongSelf.messageAccessibilityArea)
            } else {
                if case let .System(duration) = animation {
                    actionButtonsNode.layer.animateFrame(from: previousFrame, to: actionButtonsFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
        } else if let actionButtonsNode = strongSelf.actionButtonsNode {
            actionButtonsNode.removeFromSupernode()
            strongSelf.actionButtonsNode = nil
        }
        
        var incomingOffset: CGFloat = 0.0
        switch backgroundType {
        case .incoming:
            incomingOffset = 5.0
        default:
            break
        }
        
        let previousContextContentFrame = strongSelf.contextSourceNode.contentRect
        strongSelf.contextSourceNode.contentRect = backgroundFrame.offsetBy(dx: incomingOffset, dy: 0.0)
        strongSelf.containerNode.targetNodeForActivationProgressContentRect = strongSelf.contextSourceNode.contentRect
        
        if previousContextFrame.size != strongSelf.contextSourceNode.bounds.size || previousContextContentFrame != strongSelf.contextSourceNode.contentRect {
            strongSelf.contextSourceNode.layoutUpdated?(strongSelf.contextSourceNode.bounds.size)
        }
        
        strongSelf.updateSearchTextHighlightState()
        
        if let (awaitingAppliedReaction, f) = strongSelf.awaitingAppliedReaction {
            var bounds = strongSelf.bounds
            let offset = bounds.origin.x
            bounds.origin.x = 0.0
            strongSelf.bounds = bounds
            var shadowBounds = strongSelf.shadowNode.bounds
            let shadowOffset = shadowBounds.origin.x
            shadowBounds.origin.x = 0.0
            strongSelf.shadowNode.bounds = shadowBounds
            if !offset.isZero {
                strongSelf.layer.animateBoundsOriginXAdditive(from: offset, to: 0.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
            }
            if !shadowOffset.isZero {
                strongSelf.shadowNode.layer.animateBoundsOriginXAdditive(from: shadowOffset, to: 0.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
            }
            if let swipeToReplyNode = strongSelf.swipeToReplyNode {
                strongSelf.swipeToReplyNode = nil
                swipeToReplyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak swipeToReplyNode] _ in
                    swipeToReplyNode?.removeFromSupernode()
                })
                swipeToReplyNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            }
            
            strongSelf.awaitingAppliedReaction = nil
            var targetNode: ASDisplayNode?
            var hideTarget = false
            if let awaitingAppliedReaction = awaitingAppliedReaction {
                for contentNode in strongSelf.contentNodes {
                    if let (reactionNode, count) = contentNode.reactionTargetNode(value: awaitingAppliedReaction) {
                        targetNode = reactionNode
                        hideTarget = count == 1
                        break
                    }
                }
            }
            strongSelf.reactionRecognizer?.complete(into: targetNode, hideTarget: hideTarget)
            f()
        }
    }
    
    override func updateAccessibilityData(_ accessibilityData: ChatMessageAccessibilityData) {
        super.updateAccessibilityData(accessibilityData)
        
        self.messageAccessibilityArea.accessibilityLabel = accessibilityData.label
        self.messageAccessibilityArea.accessibilityValue = accessibilityData.value
        self.messageAccessibilityArea.accessibilityHint = accessibilityData.hint
        self.messageAccessibilityArea.accessibilityTraits = accessibilityData.traits
        if let customActions = accessibilityData.customActions {
            self.messageAccessibilityArea.accessibilityCustomActions = customActions.map({ action -> UIAccessibilityCustomAction in
                return ChatMessageAccessibilityCustomAction(name: action.name, target: self, selector: #selector(self.performLocalAccessibilityCustomAction(_:)), action: action.action)
            })
        } else {
            self.messageAccessibilityArea.accessibilityCustomActions = nil
        }
    }
    
    @objc private func performLocalAccessibilityCustomAction(_ action: UIAccessibilityCustomAction) {
        if let action = action as? ChatMessageAccessibilityCustomAction {
            switch action.action {
                case .reply:
                    if let item = self.item {
                        item.controllerInteraction.setupReply(item.message.id)
                    }
                case .options:
                    if let item = self.item {
                        var subFrame = self.backgroundNode.frame
                        if case .group = item.content {
                            for contentNode in self.contentNodes {
                                if contentNode.item?.message.stableId == item.message.stableId {
                                    subFrame = contentNode.frame.insetBy(dx: 0.0, dy: -4.0)
                                    break
                                }
                            }
                        }
                        item.controllerInteraction.openMessageContextMenu(item.message, false, self, subFrame, nil)
                    }
            }
        }
    }
    
    private func addContentNode(node: ChatMessageBubbleContentNode) {
        if let transitionClippingNode = self.transitionClippingNode {
            transitionClippingNode.addSubnode(node)
        } else {
            self.contextSourceNode.contentNode.addSubnode(node)
        }
    }
    
    private func enableTransitionClippingNode() {
        if self.transitionClippingNode == nil {
            let node = ASDisplayNode()
            node.clipsToBounds = true
            var backgroundFrame = self.backgroundNode.frame
            backgroundFrame = backgroundFrame.insetBy(dx: 0.0, dy: 1.0)
            node.frame = backgroundFrame
            node.bounds = CGRect(origin: CGPoint(x: backgroundFrame.origin.x, y: backgroundFrame.origin.y), size: backgroundFrame.size)
            if let forwardInfoNode = self.forwardInfoNode {
                node.addSubnode(forwardInfoNode)
            }
            if let replyInfoNode = self.replyInfoNode {
                node.addSubnode(replyInfoNode)
            }
            for contentNode in self.contentNodes {
                node.addSubnode(contentNode)
            }
            self.contextSourceNode.contentNode.addSubnode(node)
            self.transitionClippingNode = node
        }
    }
    
    private func disableTransitionClippingNode() {
        if let transitionClippingNode = self.transitionClippingNode {
            if let forwardInfoNode = self.forwardInfoNode {
                self.contextSourceNode.contentNode.addSubnode(forwardInfoNode)
            }
            if let replyInfoNode = self.replyInfoNode {
                self.contextSourceNode.contentNode.addSubnode(replyInfoNode)
            }
            for contentNode in self.contentNodes {
                self.contextSourceNode.contentNode.addSubnode(contentNode)
            }
            transitionClippingNode.removeFromSupernode()
            self.transitionClippingNode = nil
        }
    }
    
    override func shouldAnimateHorizontalFrameTransition() -> Bool {
        if let _ = self.backgroundFrameTransition {
            return true
        } else {
            return false
        }
    }
    
    override func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        if let backgroundFrameTransition = self.backgroundFrameTransition {
            let backgroundFrame = CGRect.interpolator()(backgroundFrameTransition.0, backgroundFrameTransition.1, progress) as! CGRect
            self.backgroundNode.frame = backgroundFrame
            self.backgroundNode.updateLayout(size: backgroundFrame.size, transition: .immediate)
            self.backgroundWallpaperNode.frame = backgroundFrame
            self.shadowNode.updateLayout(backgroundFrame: backgroundFrame, transition: .immediate)
            
            if let type = self.backgroundNode.type {
                var incomingOffset: CGFloat = 0.0
                switch type {
                case .incoming:
                    incomingOffset = 5.0
                default:
                    break
                }
                self.contextSourceNode.contentRect = backgroundFrame.offsetBy(dx: incomingOffset, dy: 0.0)
                self.containerNode.targetNodeForActivationProgressContentRect = self.contextSourceNode.contentRect
                if !self.contextSourceNode.isExtractedToContextPreview {
                    if let (rect, size) = self.absoluteRect {
                        self.updateAbsoluteRect(rect, within: size)
                    }
                }
            }
            self.messageAccessibilityArea.frame = backgroundFrame
            
            if let shareButtonNode = self.shareButtonNode {
                shareButtonNode.frame = CGRect(origin: CGPoint(x: backgroundFrame.maxX + 8.0, y: backgroundFrame.maxY - 30.0), size: CGSize(width: 29.0, height: 29.0))
            }
            
            if let transitionClippingNode = self.transitionClippingNode {
                var fixedBackgroundFrame = backgroundFrame
                fixedBackgroundFrame = fixedBackgroundFrame.insetBy(dx: 0.0, dy: self.backgroundNode.type == ChatMessageBackgroundType.none ? 0.0 : 1.0)
                
                transitionClippingNode.frame = fixedBackgroundFrame
                transitionClippingNode.bounds = CGRect(origin: CGPoint(x: fixedBackgroundFrame.origin.x, y: fixedBackgroundFrame.origin.y), size: fixedBackgroundFrame.size)
                
                if progress >= 1.0 - CGFloat.ulpOfOne {
                    self.disableTransitionClippingNode()
                }
            }
            
            if CGFloat(1.0).isLessThanOrEqualTo(progress) {
                self.backgroundFrameTransition = nil
            }
        }
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                if let action = self.gestureRecognized(gesture: gesture, location: location, recognizer: nil) {
                    if case .doubleTap = gesture {
                        self.containerNode.cancelGesture()
                    }
                    switch action {
                    case let .action(f):
                        f()
                    case let .optionalAction(f):
                        f()
                    case let .openContextMenu(tapMessage, selectAll, subFrame):
                        self.item?.controllerInteraction.openMessageContextMenu(tapMessage, selectAll, self, subFrame, nil)
                    }
                } else if case .tap = gesture {
                    self.item?.controllerInteraction.clickThroughMessage()
                }
            }
        default:
            break
        }
    }
    
    private func gestureRecognized(gesture: TapLongTapOrDoubleTapGesture, location: CGPoint, recognizer: TapLongTapOrDoubleTapGestureRecognizer?) -> InternalBubbleTapAction? {
        var mediaMessage: Message?
        var forceOpen = false
        if let item = self.item {
            for media in item.message.media {
                if let file = media as? TelegramMediaFile, file.duration != nil {
                    mediaMessage = item.message
                }
            }
            if mediaMessage == nil {
                for attribute in item.message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute {
                        if let replyMessage = item.message.associatedMessages[attribute.messageId] {
                            for media in replyMessage.media {
                                if let file = media as? TelegramMediaFile, file.duration != nil {
                                    mediaMessage = replyMessage
                                    forceOpen = true
                                    break
                                }
                                if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, webEmbedType(content: content).supportsSeeking {
                                    mediaMessage = replyMessage
                                    forceOpen = true
                                    break
                                }
                            }
                        }
                    }
                }
            }
            if mediaMessage == nil {
                mediaMessage = item.message
            }
        }
        
        switch gesture {
            case .tap:
                if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(location) {
                    return .action({
                        if let item = self.item, let author = item.content.firstMessage.author {
                            var openPeerId = item.effectiveAuthorId ?? author.id
                            var navigate: ChatControllerInteractionNavigateToPeer
                            
                            if item.content.firstMessage.id.peerId == item.context.account.peerId {
                                navigate = .chat(textInputState: nil, subject: nil)
                            } else {
                                navigate = .info
                            }
                            
                            for attribute in item.content.firstMessage.attributes {
                                if let attribute = attribute as? SourceReferenceMessageAttribute {
                                    openPeerId = attribute.messageId.peerId
                                    navigate = .chat(textInputState: nil, subject: .message(attribute.messageId))
                                }
                            }
                            
                            if item.effectiveAuthorId?.namespace == Namespaces.Peer.Empty {
                                item.controllerInteraction.displayMessageTooltip(item.content.firstMessage.id,  item.presentationData.strings.Conversation_ForwardAuthorHiddenTooltip, self, avatarNode.frame)
                            } else {
                                if item.message.id.peerId == item.context.account.peerId, let channel = item.content.firstMessage.forwardInfo?.author as? TelegramChannel, channel.username == nil {
                                    if case let .broadcast(info) = channel.info, info.flags.contains(.hasDiscussionGroup) {
                                    } else if case .member = channel.participationStatus {
                                    } else {
                                        item.controllerInteraction.displayMessageTooltip(item.message.id, item.presentationData.strings.Conversation_PrivateChannelTooltip, self, avatarNode.frame)
                                        return
                                    }
                                }
                                item.controllerInteraction.openPeer(openPeerId, navigate, item.message)
                            }
                        }
                    })
                }
                
                if let nameNode = self.nameNode, nameNode.frame.contains(location) {
                    if let item = self.item {
                        for attribute in item.message.attributes {
                            if let attribute = attribute as? InlineBotMessageAttribute {
                                var botAddressName: String?
                                if let peerId = attribute.peerId, let botPeer = item.message.peers[peerId], let addressName = botPeer.addressName {
                                    botAddressName = addressName
                                } else {
                                    botAddressName = attribute.title
                                }
                                
                                return .optionalAction({
                                    if let botAddressName = botAddressName {
                                        item.controllerInteraction.updateInputState { textInputState in
                                            return ChatTextInputState(inputText: NSAttributedString(string: "@" + botAddressName + " "))
                                        }
                                        item.controllerInteraction.updateInputMode { _ in
                                            return .text
                                        }
                                    }
                                })
                            }
                        }
                    }
                } else if let replyInfoNode = self.replyInfoNode, self.item?.controllerInteraction.tapMessage == nil, replyInfoNode.frame.contains(location) {
                    if let item = self.item {
                        for attribute in item.message.attributes {
                            if let attribute = attribute as? ReplyMessageAttribute {
                                return .optionalAction({
                                    item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId)
                                })
                            }
                        }
                    }
                }
                if let forwardInfoNode = self.forwardInfoNode, forwardInfoNode.frame.contains(location) {
                    if let item = self.item, let forwardInfo = item.message.forwardInfo {
                        let performAction: () -> Void = {
                            if let sourceMessageId = forwardInfo.sourceMessageId {
                                if let channel = forwardInfo.author as? TelegramChannel, channel.username == nil {
                                    if case let .broadcast(info) = channel.info, info.flags.contains(.hasDiscussionGroup) {
                                    } else if case .member = channel.participationStatus {
                                    } else {
                                        item.controllerInteraction.displayMessageTooltip(item.message.id, item.presentationData.strings.Conversation_PrivateChannelTooltip, forwardInfoNode, nil)
                                        return
                                    }
                                }
                                item.controllerInteraction.navigateToMessage(item.message.id, sourceMessageId)
                            } else if let id = forwardInfo.source?.id ?? forwardInfo.author?.id {
                                item.controllerInteraction.openPeer(id, .info, nil)
                            } else if let _ = forwardInfo.authorSignature {
                                item.controllerInteraction.displayMessageTooltip(item.message.id, item.presentationData.strings.Conversation_ForwardAuthorHiddenTooltip, forwardInfoNode, nil)
                            }
                        }
                        
                        if forwardInfoNode.hasAction(at: self.view.convert(location, to: forwardInfoNode.view)) {
                            return .action({})
                        } else {
                            return .optionalAction(performAction)
                        }
                    }
                }
                loop: for contentNode in self.contentNodes {
                    let tapAction = contentNode.tapActionAtPoint(CGPoint(x: location.x - contentNode.frame.minX, y: location.y - contentNode.frame.minY), gesture: gesture, isEstimating: false)
                    switch tapAction {
                    case .none:
                        if let item = self.item, self.backgroundNode.frame.contains(CGPoint(x: self.frame.width - location.x, y: location.y)), let tapMessage = self.item?.controllerInteraction.tapMessage {
                            return .action({
                                tapMessage(item.message)
                            })
                        }
                    case .ignore:
                        if let item = self.item, self.backgroundNode.frame.contains(CGPoint(x: self.frame.width - location.x, y: location.y)), let tapMessage = self.item?.controllerInteraction.tapMessage {
                            return .action({
                                tapMessage(item.message)
                            })
                        } else {
                            return .action({
                            })
                        }
                    case let .url(url, concealed):
                        return .action({
                            self.item?.controllerInteraction.openUrl(url, concealed, nil, self.item?.content.firstMessage)
                        })
                    case let .peerMention(peerId, _):
                        return .action({
                            self.item?.controllerInteraction.openPeer(peerId, .chat(textInputState: nil, subject: nil), nil)
                        })
                    case let .textMention(name):
                        return .action({
                            self.item?.controllerInteraction.openPeerMention(name)
                        })
                    case let .botCommand(command):
                        if let item = self.item {
                            return .action({
                                item.controllerInteraction.sendBotCommand(item.message.id, command)
                            })
                        }
                    case let .hashtag(peerName, hashtag):
                        return .action({
                            self.item?.controllerInteraction.openHashtag(peerName, hashtag)
                        })
                    case .instantPage:
                        if let item = self.item {
                            return .optionalAction({
                                item.controllerInteraction.openInstantPage(item.message, item.associatedData)
                            })
                        }
                    case .wallpaper:
                        if let item = self.item {
                            return .action({
                                item.controllerInteraction.openWallpaper(item.message)
                            })
                        }
                    case .theme:
                        if let item = self.item {
                            return .action({
                                item.controllerInteraction.openTheme(item.message)
                            })
                        }
                    case let .call(peerId):
                        return .optionalAction({
                            self.item?.controllerInteraction.callPeer(peerId)
                        })
                    case .openMessage:
                        if let item = self.item {
                            if let type = self.backgroundNode.type, case .none = type {
                                return .optionalAction({
                                    let _ = item.controllerInteraction.openMessage(item.message, .default)
                                })
                            } else {
                                return .action({
                                    let _ = item.controllerInteraction.openMessage(item.message, .default)
                                })
                            }
                        }
                    case let .timecode(timecode, _):
                        if let item = self.item, let mediaMessage = mediaMessage {
                            return .action({
                                item.controllerInteraction.seekToTimecode(mediaMessage, timecode, forceOpen)
                            })
                        }
                    case let .bankCard(number):
                        if let item = self.item {
                            return .action({
                                item.controllerInteraction.longTap(.bankCard(number), item.message)
                            })
                        }
                    case let .tooltip(text, node, rect):
                        if let item = self.item {
                            return .optionalAction({
                                let _ = item.controllerInteraction.displayMessageTooltip(item.message.id, text, node, rect)
                            })
                        }
                    case let .openPollResults(option):
                        if let item = self.item {
                            return .optionalAction({
                                item.controllerInteraction.openMessagePollResults(item.message.id, option)
                            })
                        }
                    }
                }
                return nil
            case .longTap, .doubleTap:
                if let item = self.item, self.backgroundNode.frame.contains(location) {
                    let message = item.message
                    
                    var tapMessage: Message? = item.content.firstMessage
                    var selectAll = true
                    loop: for contentNode in self.contentNodes {
                        if !contentNode.frame.contains(location) {
                            continue loop
                        } else if contentNode is ChatMessageMediaBubbleContentNode {
                            selectAll = false
                        }
                        tapMessage = contentNode.item?.message
                        let tapAction = contentNode.tapActionAtPoint(CGPoint(x: location.x - contentNode.frame.minX, y: location.y - contentNode.frame.minY), gesture: gesture, isEstimating: false)
                        switch tapAction {
                        case .none, .ignore:
                            break
                        case let .url(url, _):
                            return .action({
                                item.controllerInteraction.longTap(.url(url), message)
                            })
                        case let .peerMention(peerId, mention):
                            return .action({
                                item.controllerInteraction.longTap(.peerMention(peerId, mention), message)
                            })
                        case let .textMention(name):
                            return .action({
                                item.controllerInteraction.longTap(.mention(name), message)
                            })
                        case let .botCommand(command):
                            return .action({
                                item.controllerInteraction.longTap(.command(command), message)
                            })
                        case let .hashtag(_, hashtag):
                            return .action({
                                item.controllerInteraction.longTap(.hashtag(hashtag), message)
                            })
                        case .instantPage:
                            break
                        case .wallpaper:
                            break
                        case .theme:
                            break
                        case .call:
                            break
                        case .openMessage:
                            break
                        case let .timecode(timecode, text):
                            if let mediaMessage = mediaMessage {
                                return .action({
                                    item.controllerInteraction.longTap(.timecode(timecode, text), mediaMessage)
                                })
                            }
                        case let .bankCard(number):
                            return .action({
                                item.controllerInteraction.longTap(.bankCard(number), message)
                            })
                        case .tooltip:
                            break
                        case .openPollResults:
                            break
                        }
                    }
                    if let tapMessage = tapMessage {
                        var subFrame = self.backgroundNode.frame
                        if case .group = item.content {
                            for contentNode in self.contentNodes {
                                if contentNode.item?.message.stableId == tapMessage.stableId {
                                    subFrame = contentNode.frame.insetBy(dx: 0.0, dy: -4.0)
                                    break
                                }
                            }
                        }
                        return .openContextMenu(tapMessage: tapMessage, selectAll: selectAll, subFrame: subFrame)
                    }
                }
            default:
                break
        }
        return nil
    }
    
    private func traceSelectionNodes(parent: ASDisplayNode, point: CGPoint) -> ASDisplayNode? {
        if let parent = parent as? GridMessageSelectionNode, parent.bounds.contains(point) {
            return parent
        } else {
            if let parentSubnodes = parent.subnodes {
                for subnode in parentSubnodes {
                    let subnodeFrame = subnode.frame
                    if let result = traceSelectionNodes(parent: subnode, point: point.offsetBy(dx: -subnodeFrame.minX, dy: -subnodeFrame.minY)) {
                        return result
                    }
                }
            }
            return nil
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        
        if self.contextSourceNode.isExtractedToContextPreview {
            if let result = super.hitTest(point, with: event) as? TextSelectionNodeView {
                return result
            }
            return nil
        }
        
        if let shareButtonNode = self.shareButtonNode, shareButtonNode.frame.contains(point) {
            return shareButtonNode.view
        }
        
        if let selectionNode = self.selectionNode {
            if let result = self.traceSelectionNodes(parent: self, point: point.offsetBy(dx: -42.0, dy: 0.0)) {
                return result.view
            }
            
            var selectionNodeFrame = selectionNode.frame
            selectionNodeFrame.origin.x -= 42.0
            selectionNodeFrame.size.width += 42.0 * 2.0
            if selectionNodeFrame.contains(point) {
                return selectionNode.view
            } else {
                return nil
            }
        }
        
        if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(point) {
            return self.view
        }
        
        if !self.backgroundNode.frame.contains(point) {
            if self.actionButtonsNode == nil || !self.actionButtonsNode!.frame.contains(point) {
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    override func transitionNode(id: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        for contentNode in self.contentNodes {
            if let result = contentNode.transitionNode(messageId: id, media: media) {
                if self.contentNodes.count == 1 && self.contentNodes.first is ChatMessageMediaBubbleContentNode && self.nameNode == nil && self.adminBadgeNode == nil && self.forwardInfoNode == nil && self.replyInfoNode == nil {
                    return (result.0, result.1, { [weak self] in
                        guard let strongSelf = self, let resultView = result.2().0 else {
                            return (nil, nil)
                        }
                        if strongSelf.backgroundNode.supernode != nil, let backgroundView = strongSelf.backgroundNode.view.snapshotContentTree(unhide: true) {
                            let backgroundContainer = UIView()
                            
                            let backdropView = strongSelf.backgroundWallpaperNode.view.snapshotContentTree(unhide: true)
                            if let backdropView = backdropView {
                                let backdropFrame = strongSelf.backgroundWallpaperNode.layer.convert(strongSelf.backgroundWallpaperNode.bounds, to: strongSelf.backgroundNode.layer)
                                backdropView.frame = backdropFrame
                            }
                            
                            if let backdropView = backdropView {
                                backgroundContainer.addSubview(backdropView)
                            }
                            
                            backgroundContainer.addSubview(backgroundView)
                            
                            let backgroundFrame = strongSelf.backgroundNode.layer.convert(strongSelf.backgroundNode.bounds, to: result.0.layer)
                            backgroundView.frame = CGRect(origin: CGPoint(), size: backgroundFrame.size)
                            backgroundContainer.frame = backgroundFrame
                            let viewWithBackground = UIView()
                            viewWithBackground.addSubview(backgroundContainer)
                            viewWithBackground.frame = resultView.frame
                            resultView.frame = CGRect(origin: CGPoint(), size: resultView.frame.size)
                            viewWithBackground.addSubview(resultView)
                            return (viewWithBackground, backgroundContainer)
                        }
                        return (resultView, nil)
                    })
                }
                return result
            }
        }
        return nil
    }
    
    override func peekPreviewContent(at point: CGPoint) -> (Message, ChatMessagePeekPreviewContent)? {
        for contentNode in self.contentNodes {
            let frame = contentNode.frame
            if let result = contentNode.peekPreviewContent(at: point.offsetBy(dx: -frame.minX, dy: -frame.minY)) {
                return result
            }
        }
        return nil
    }
    
    override func updateHiddenMedia() {
        var hasHiddenMosaicStatus = false
        var hasHiddenBackground = false
        if let item = self.item {
            for contentNode in self.contentNodes {
                if let contentItem = contentNode.item {
                    if contentNode.updateHiddenMedia(item.controllerInteraction.hiddenMedia[contentItem.message.id]) {
                        if self.contentNodes.count == 1 && self.contentNodes.first is ChatMessageMediaBubbleContentNode && self.nameNode == nil && self.adminBadgeNode == nil && self.forwardInfoNode == nil && self.replyInfoNode == nil {
                            hasHiddenBackground = true
                        }
                        if let mosaicStatusNode = self.mosaicStatusNode, mosaicStatusNode.frame.intersects(contentNode.frame) {
                            hasHiddenMosaicStatus = true
                        }
                    }
                }
            }
        }
        
        if let mosaicStatusNode = self.mosaicStatusNode {
            if mosaicStatusNode.alpha.isZero != hasHiddenMosaicStatus {
                if hasHiddenMosaicStatus {
                    mosaicStatusNode.alpha = 0.0
                } else {
                    mosaicStatusNode.alpha = 1.0
                    mosaicStatusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.backgroundNode.isHidden = hasHiddenBackground
        self.backgroundWallpaperNode.isHidden = hasHiddenBackground
    }
    
    override func updateAutomaticMediaDownloadSettings() {
        if let item = self.item {
            for contentNode in self.contentNodes {
                contentNode.updateAutomaticMediaDownloadSettings(item.controllerInteraction.automaticMediaDownloadSettings)
            }
        }
    }
    
    override func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        for contentNode in self.contentNodes {
            if let playMediaWithSound = contentNode.playMediaWithSound() {
                return playMediaWithSound
            }
        }
        return nil
    }
    
    override func updateSelectionState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        let wasSelected = self.selectionNode?.selected
        
        var canHaveSelection = true
        switch item.content {
            case let .message(message, _, _, _):
                for media in message.media {
                    if let action = media as? TelegramMediaAction {
                        if case .phoneCall = action.action { } else {
                            canHaveSelection = false
                            break
                        }
                    }
                }
            default:
                break
        }
        
        if let selectionState = item.controllerInteraction.selectionState, canHaveSelection {
            var selected = false
            var incoming = true
            
            switch item.content {
                case let .message(message, _, _, _):
                    selected = selectionState.selectedIds.contains(message.id)
                case let .group(messages: messages):
                    var allSelected = !messages.isEmpty
                    for (message, _, _, _) in messages {
                        if !selectionState.selectedIds.contains(message.id) {
                            allSelected = false
                            break
                        }
                    }
                    selected = allSelected
            }
            
            incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: animated)
                let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentSize.width, height: self.contentSize.height))
                selectionNode.frame = selectionFrame
                selectionNode.updateLayout(size: selectionFrame.size)
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(wallpaper: item.presentationData.theme.wallpaper, theme: item.presentationData.theme.theme, toggle: { [weak self] value in
                    if let strongSelf = self, let item = strongSelf.item {
                        switch item.content {
                            case let .message(message, _, _, _):
                            item.controllerInteraction.toggleMessagesSelection([message.id], value)
                            case let .group(messages):
                                item.controllerInteraction.toggleMessagesSelection(messages.map { $0.0.id }, value)
                        }
                    }
                })
                
                let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentSize.width, height: self.contentSize.height))
                selectionNode.frame = selectionFrame
                selectionNode.updateLayout(size: selectionFrame.size)
                self.insertSubnode(selectionNode, belowSubnode: self.messageAccessibilityArea)
                self.selectionNode = selectionNode
                selectionNode.updateSelected(selected, animated: false)
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
                if animated {
                    selectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                    
                    if !incoming {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: CGPoint(x: position.x - 42.0, y: position.y), to: position, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                    }
                }
            }
        } else {
            if let selectionNode = self.selectionNode {
                self.selectionNode = nil
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DIdentity
                if animated {
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, completion: { [weak selectionNode]_ in
                        selectionNode?.removeFromSupernode()
                    })
                    selectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                    if CGFloat(0.0).isLessThanOrEqualTo(selectionNode.frame.origin.x) {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: position, to: CGPoint(x: position.x - 42.0, y: position.y), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false)
                    }
                } else {
                    selectionNode.removeFromSupernode()
                }
            }
        }
        
        let isSelected = self.selectionNode?.selected
        if wasSelected != isSelected {
            self.updateAccessibilityData(ChatMessageAccessibilityData(item: item, isSelected: isSelected))
        }
    }
    
    override func updateSearchTextHighlightState() {
        for contentNode in self.contentNodes {
            contentNode.updateSearchTextHighlightState(text: self.item?.controllerInteraction.searchTextHighightState?.0, messages: self.item?.controllerInteraction.searchTextHighightState?.1)
        }
    }
    
    override func updateHighlightedState(animated: Bool) {
        super.updateHighlightedState(animated: animated)
        
        guard let item = self.item, let _ = self.backgroundType else {
            return
        }
        
        var highlighted = false
        
        for contentNode in self.contentNodes {
            let _ = contentNode.updateHighlightedState(animated: animated)
        }
        
        if let highlightedState = item.controllerInteraction.highlightedState {
            for (message, _) in item.content {
                if highlightedState.messageStableId == message.stableId {
                    highlighted = true
                    break
                }
            }
        }
        
        if self.highlightedState != highlighted {
            self.highlightedState = highlighted
            if let backgroundType = self.backgroundType {
                let graphics = PresentationResourcesChat.principalGraphics(mediaBox: item.context.account.postbox.mediaBox, knockoutWallpaper: item.context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper, theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, bubbleCorners: item.presentationData.chatBubbleCorners)
                
                let hasWallpaper = item.presentationData.theme.wallpaper.hasWallpaper
                self.backgroundNode.setType(type: backgroundType, highlighted: highlighted, graphics: graphics, maskMode: self.contextSourceNode.isExtractedToContextPreview, hasWallpaper: hasWallpaper, transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
            }
        }
    }
    
    @objc func shareButtonPressed() {
        if let item = self.item {
            if item.content.firstMessage.id.peerId == item.context.account.peerId {
                for attribute in item.content.firstMessage.attributes {
                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                        item.controllerInteraction.navigateToMessage(item.content.firstMessage.id, attribute.messageId)
                        break
                    }
                }
            } else {
                item.controllerInteraction.openMessageShareMenu(item.message.id)
            }
        }
    }
    
    @objc func swipeToReplyGesture(_ recognizer: ChatSwipeToReplyRecognizer) {
        switch recognizer.state {
            case .began:
                self.currentSwipeToReplyTranslation = 0.0
                if self.swipeToReplyFeedback == nil {
                    self.swipeToReplyFeedback = HapticFeedback()
                    self.swipeToReplyFeedback?.prepareImpact()
                }
                self.item?.controllerInteraction.cancelInteractiveKeyboardGestures()
            case .changed:
                var translation = recognizer.translation(in: self.view)
                translation.x = max(-80.0, min(0.0, translation.x))
                var animateReplyNodeIn = false
                if (translation.x < -45.0) != (self.currentSwipeToReplyTranslation < -45.0) {
                    if translation.x < -45.0, self.swipeToReplyNode == nil, let item = self.item {
                        self.swipeToReplyFeedback?.impact()

                        let swipeToReplyNode = ChatMessageSwipeToReplyNode(fillColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonFillColor, wallpaper: item.presentationData.theme.wallpaper), strokeColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonStrokeColor, wallpaper: item.presentationData.theme.wallpaper), foregroundColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonForegroundColor, wallpaper: item.presentationData.theme.wallpaper))
                        self.swipeToReplyNode = swipeToReplyNode
                        self.insertSubnode(swipeToReplyNode, belowSubnode: self.messageAccessibilityArea)
                        animateReplyNodeIn = true
                    }
                }
                self.currentSwipeToReplyTranslation = translation.x
                var bounds = self.bounds
                bounds.origin.x = -translation.x
                self.bounds = bounds
                var shadowBounds = self.shadowNode.bounds
                shadowBounds.origin.x = -translation.x
                self.shadowNode.bounds = shadowBounds
            
                if let swipeToReplyNode = self.swipeToReplyNode {
                    swipeToReplyNode.frame = CGRect(origin: CGPoint(x: bounds.size.width, y: floor((self.contentSize.height - 33.0) / 2.0)), size: CGSize(width: 33.0, height: 33.0))
                    if animateReplyNodeIn {
                        swipeToReplyNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                        swipeToReplyNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                    } else {
                        swipeToReplyNode.alpha = min(1.0, abs(translation.x / 45.0))
                    }
                }
            case .cancelled, .ended:
                self.swipeToReplyFeedback = nil
                
                let translation = recognizer.translation(in: self.view)
                if case .ended = recognizer.state, translation.x < -45.0 {
                    if let item = self.item {
                        item.controllerInteraction.setupReply(item.message.id)
                    }
                }
                var bounds = self.bounds
                let previousBounds = bounds
                bounds.origin.x = 0.0
                self.bounds = bounds
                var shadowBounds = self.shadowNode.bounds
                let previousShadowBounds = shadowBounds
                shadowBounds.origin.x = 0.0
                self.shadowNode.bounds = shadowBounds
                self.layer.animateBounds(from: previousBounds, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.shadowNode.layer.animateBounds(from: previousShadowBounds, to: shadowBounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                if let swipeToReplyNode = self.swipeToReplyNode {
                    self.swipeToReplyNode = nil
                    swipeToReplyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak swipeToReplyNode] _ in
                        swipeToReplyNode?.removeFromSupernode()
                    })
                    swipeToReplyNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                }
            default:
                break
        }
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        if !self.contextSourceNode.isExtractedToContextPreview {
            var rect = rect
            rect.origin.y = containerSize.height - rect.maxY + self.insets.top
            self.updateAbsoluteRectInternal(rect, within: containerSize)
        }
    }
    
    private func updateAbsoluteRectInternal(_ rect: CGRect, within containerSize: CGSize) {
        let mappedRect = CGRect(origin: CGPoint(x: rect.minX + self.backgroundWallpaperNode.frame.minX, y: rect.minY + self.backgroundWallpaperNode.frame.minY), size: rect.size)
        self.backgroundWallpaperNode.update(rect: mappedRect, within: containerSize)
    }
    
    override func applyAbsoluteOffset(value: CGFloat, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if !self.contextSourceNode.isExtractedToContextPreview {
            self.applyAbsoluteOffsetInternal(value: -value, animationCurve: animationCurve, duration: duration)
        }
    }
    
    private func applyAbsoluteOffsetInternal(value: CGFloat, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        self.backgroundWallpaperNode.offset(value: value, animationCurve: animationCurve, duration: duration)
    }
    
    private func applyAbsoluteOffsetSpringInternal(value: CGFloat, duration: Double, damping: CGFloat) {
        self.backgroundWallpaperNode.offsetSpring(value: value, duration: duration, damping: damping)
    }
    
    override func getMessageContextSourceNode() -> ContextExtractedContentContainingNode? {
        return self.contextSourceNode
    }
    
    override func addAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        self.contextSourceNode.contentNode.addSubnode(accessoryItemNode)
    }
    
    override func targetReactionNode(value: String) -> (ASDisplayNode, Int)? {
        for contentNode in self.contentNodes {
            if let (reactionNode, count) = contentNode.reactionTargetNode(value: value) {
                return (reactionNode, count)
            }
        }
        return nil
    }
    
    private var backgroundMaskMode: Bool {
        let hasWallpaper = self.item?.presentationData.theme.wallpaper.hasWallpaper ?? false
        let isPreview = self.item?.presentationData.isPreview ?? false
        return self.contextSourceNode.isExtractedToContextPreview || hasWallpaper || isPreview
    }
    
    func animateQuizInvalidOptionSelected() {
        if let supernode = self.supernode, let subnodes = supernode.subnodes {
            for i in 0 ..< subnodes.count {
                if subnodes[i] === self {
                    break
                }
            }
        }
        
        let duration: Double = 0.5
        let minScale: CGFloat = -0.03
        let scaleAnimation0 = self.layer.makeAnimation(from: 0.0 as NSNumber, to: minScale as NSNumber, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: duration / 2.0, removeOnCompletion: false, additive: true, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            let scaleAnimation1 = strongSelf.layer.makeAnimation(from: minScale as NSNumber, to: 0.0 as NSNumber, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: duration / 2.0, additive: true)
            strongSelf.layer.add(scaleAnimation1, forKey: "quizInvalidScale")
        })
        self.layer.add(scaleAnimation0, forKey: "quizInvalidScale")
        
        let k = Float(UIView.animationDurationFactor())
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
        
        let count = 4
                
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        var values: [CGFloat] = []
        values.append(0.0)
        let rotationAmplitude: CGFloat = CGFloat.pi / 180.0 * 3.0
        for i in 0 ..< count {
            let sign: CGFloat = (i % 2 == 0) ? 1.0 : -1.0
            let amplitude: CGFloat = rotationAmplitude
            values.append(amplitude * sign)
        }
        values.append(0.0)
        animation.values = values.map { ($0 as NSNumber) as AnyObject }
        var keyTimes: [NSNumber] = []
        for i in 0 ..< values.count {
            if i == 0 {
                keyTimes.append(0.0)
            } else if i == values.count - 1 {
                keyTimes.append(1.0)
            } else {
                keyTimes.append((Double(i) / Double(values.count - 1)) as NSNumber)
            }
        }
        animation.keyTimes = keyTimes
        animation.speed = speed
        animation.duration = duration
        animation.isAdditive = true
        
        self.layer.add(animation, forKey: "quizInvalidRotation")
    }
    
    func updatePsaTooltipMessageState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        if let forwardInfoNode = self.forwardInfoNode {
            forwardInfoNode.updatePsaButtonDisplay(isVisible: item.controllerInteraction.currentPsaMessageWithTooltip != item.message.id, animated: animated)
        }
    }
}
