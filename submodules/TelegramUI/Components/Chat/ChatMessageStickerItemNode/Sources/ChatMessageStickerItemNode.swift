import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TextFormat
import AccountContext
import StickerResources
import ContextUI
import Markdown
import ShimmerEffect
import WallpaperBackgroundNode
import ChatControllerInteraction
import ChatMessageForwardInfoNode
import ChatMessageDateAndStatusNode
import ChatMessageItemCommon
import ChatMessageReplyInfoNode
import ChatMessageItem
import ChatMessageItemView
import ChatMessageSwipeToReplyNode
import ChatMessageSelectionNode
import ChatMessageDeliveryFailedNode
import ChatMessageShareButton
import ChatMessageThreadInfoNode
import ChatMessageActionButtonsNode
import ChatMessageReactionsFooterContentNode
import ChatSwipeToReplyRecognizer
import ChatMessageSuggestedPostInfoNode

private let nameFont = Font.medium(14.0)
private let inlineBotPrefixFont = Font.regular(14.0)
private let inlineBotNameFont = nameFont

public class ChatMessageStickerItemNode: ChatMessageItemView {
    public let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    public let imageNode: TransformImageNode
    private var backgroundNode: WallpaperBubbleBackgroundNode?
    private var placeholderNode: StickerShimmerEffectNode
    public var textNode: TextNode?
    
    private var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    private var swipeToReplyFeedback: HapticFeedback?
    
    private var selectionNode: ChatMessageSelectionNode?
    private var deliveryFailedNode: ChatMessageDeliveryFailedNode?
    private var shareButtonNode: ChatMessageShareButton?

    public var telegramFile: TelegramMediaFile?
    private let fetchDisposable = MetaDisposable()
    
    private var suggestedPostInfoNode: ChatMessageSuggestedPostInfoNode?
    
    private var viaBotNode: TextNode?
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private var threadInfoNode: ChatMessageThreadInfoNode?
    private var replyInfoNode: ChatMessageReplyInfoNode?
    private var replyBackgroundContent: WallpaperBubbleBackgroundNode?
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    private var forwardBackgroundContent: WallpaperBubbleBackgroundNode?
    private var forwardBackgroundMaskNode: LinkHighlightingNode?
    
    private var actionButtonsNode: ChatMessageActionButtonsNode?
    private var reactionButtonsNode: ChatMessageReactionButtonsNode?
    
    private let messageAccessibilityArea: AccessibilityAreaNode
    
    private var highlightedState: Bool = false
    
    private var currentSwipeToReplyTranslation: CGFloat = 0.0
    
    private var replyRecognizer: ChatSwipeToReplyRecognizer?
    private var currentSwipeAction: ChatControllerInteractionSwipeAction?
    
    private var appliedForwardInfo: (Peer?, String?)?

    private var enableSynchronousImageApply: Bool = false
    
    private var wasPending: Bool = false
    private var didChangeFromPendingToSent: Bool = false
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = oldValue != .none
            let isVisible = self.visibility != .none
            
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
            }
        }
    }
    
    private var visibilityStatus: Bool? {
        didSet {
            if self.visibilityStatus != oldValue {
                self.threadInfoNode?.visibility = self.visibilityStatus == true
                self.replyInfoNode?.visibility = self.visibilityStatus == true
                
                self.updateVisibility()
            }
        }
    }
    
    private var forceStopAnimations: Bool = false
    
    required public init(rotated: Bool) {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.imageNode = TransformImageNode()
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        self.messageAccessibilityArea = AccessibilityAreaNode()
        
        super.init(rotated: rotated)
        
        var firstTime = true
        self.imageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                if firstTime && !strongSelf.placeholderNode.isEmpty {
                    if strongSelf.enableSynchronousImageApply {
                        strongSelf.removePlaceholder(animated: false)
                    } else {
                        strongSelf.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak self] _ in
                            self?.removePlaceholder(animated: false)
                        })
                    }
                } else {
                    strongSelf.removePlaceholder(animated: true)
                }
                firstTime = false
            }
        }
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self else {
                return false
            }
            if !strongSelf.imageNode.frame.contains(location) {
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
                case let .openContextMenu(openContextMenu):
                    item.controllerInteraction.openMessageContextMenu(openContextMenu.tapMessage, openContextMenu.selectAll, strongSelf, openContextMenu.subFrame, gesture, nil)
                }
            }
        }
        
        self.imageNode.displaysAsynchronously = false
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        self.contextSourceNode.contentNode.addSubnode(self.placeholderNode)
        self.contextSourceNode.contentNode.addSubnode(self.imageNode)
        self.contextSourceNode.contentNode.addSubnode(self.dateAndStatusNode)
        self.addSubnode(self.messageAccessibilityArea)
        
        self.messageAccessibilityArea.focused = { [weak self] in
            self?.accessibilityElementDidBecomeFocused()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    private func removePlaceholder(animated: Bool) {
        if !animated {
            self.placeholderNode.removeFromSupernode()
        } else {
            self.placeholderNode.alpha = 0.0
            self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.placeholderNode.removeFromSupernode()
            })
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let shareButtonNode = strongSelf.shareButtonNode, shareButtonNode.frame.contains(point) {
                    return .fail
                }
                if let threadInfoNode = strongSelf.threadInfoNode, threadInfoNode.frame.contains(point) {
                    if let _ = threadInfoNode.hitTest(strongSelf.view.convert(point, to: threadInfoNode.view), with: nil) {
                        return .fail
                    }
                }
                if let reactionButtonsNode = strongSelf.reactionButtonsNode {
                    if let _ = reactionButtonsNode.hitTest(strongSelf.view.convert(point, to: reactionButtonsNode.view), with: nil) {
                        return .fail
                    }
                }
                
                if let item = strongSelf.item, item.presentationData.largeEmoji && messageIsEligibleForLargeEmoji(item.message) {
                    if strongSelf.imageNode.frame.contains(point) {
                        return .waitForDoubleTap
                    }
                }
            }
            return .waitForDoubleTap
        }
        recognizer.longTap = { [weak self] point, recognizer in
            guard let strongSelf = self else {
                return
            }

            if let action = strongSelf.gestureRecognized(gesture: .longTap, location: point, recognizer: recognizer) {
                switch action {
                case let .action(f):
                    f.action()
                    recognizer.cancel()
                case let .optionalAction(f):
                    f()
                    recognizer.cancel()
                case .openContextMenu:
                    break
                }
            }
        }
        self.view.addGestureRecognizer(recognizer)
        
        let replyRecognizer = ChatSwipeToReplyRecognizer(target: self, action: #selector(self.swipeToReplyGesture(_:)))
        replyRecognizer.shouldBegin = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                if strongSelf.selectionNode != nil {
                    return false
                }
                
                if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.isChannelPost, replyThreadMessage.peerId != item.content.firstMessage.id.peerId {
                    return false
                }
                
                let action = item.controllerInteraction.canSetupReply(item.message)
                strongSelf.currentSwipeAction = action
                if case .none = action {
                    return false
                } else {
                    return true
                }
            }
            return false
        }
        if let item = self.item {
            let _ = item
            replyRecognizer.allowBothDirections = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
            self.view.disablesInteractiveTransitionGestureRecognizer = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
        }
        self.replyRecognizer = replyRecognizer
        self.view.addGestureRecognizer(replyRecognizer)
    }
    
    override public func setupItem(_ item: ChatMessageItem, synchronousLoad: Bool) {
        super.setupItem(item, synchronousLoad: synchronousLoad)
        
        if item.message.id.namespace == Namespaces.Message.Local || item.message.id.namespace == Namespaces.Message.ScheduledLocal || item.message.id.namespace == Namespaces.Message.QuickReplyLocal {
            self.wasPending = true
        }
        if self.wasPending && (item.message.id.namespace != Namespaces.Message.Local && item.message.id.namespace != Namespaces.Message.ScheduledLocal && item.message.id.namespace != Namespaces.Message.QuickReplyLocal) {
            self.didChangeFromPendingToSent = true
        }
        
        self.replyRecognizer?.allowBothDirections = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
        if self.isNodeLoaded {
            self.view.disablesInteractiveTransitionGestureRecognizer = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
        }
        
        for media in item.message.media {
            if let telegramFile = media as? TelegramMediaFile {
                if self.telegramFile != telegramFile {
                    let signal = chatMessageSticker(account: item.context.account, userLocation: .peer(item.message.id.peerId), file: telegramFile, small: false, onlyFullSize: self.telegramFile != nil, synchronousLoad: synchronousLoad)
                    self.telegramFile = telegramFile
                    self.imageNode.setSignal(signal, attemptSynchronously: synchronousLoad)
                    self.fetchDisposable.set(freeMediaFileInteractiveFetched(account: item.context.account, userLocation: .peer(item.message.id.peerId), fileReference: .message(message: MessageReference(item.message), media: telegramFile)).startStrict())
                }
                
                break
            }
        }
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        if !self.contextSourceNode.isExtractedToContextPreview {
            var rect = rect
            rect.origin.y = containerSize.height - rect.maxY + self.insets.top

            self.placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + placeholderNode.frame.minX, y: rect.minY + placeholderNode.frame.minY), size: placeholderNode.frame.size), within: containerSize)
            
            if let backgroundNode = self.backgroundNode {
                backgroundNode.update(rect: CGRect(origin: CGPoint(x: rect.minX + self.placeholderNode.frame.minX, y: rect.minY + self.placeholderNode.frame.minY), size: self.placeholderNode.frame.size), within: containerSize, transition: .immediate)
            }
            
            if let threadInfoNode = self.threadInfoNode {
                var threadInfoNodeFrame = threadInfoNode.frame
                threadInfoNodeFrame.origin.x += rect.minX
                threadInfoNodeFrame.origin.y += rect.minY
                
                threadInfoNode.updateAbsoluteRect(threadInfoNodeFrame, within: containerSize)
            }
            
            if let shareButtonNode = self.shareButtonNode {
                var shareButtonNodeFrame = shareButtonNode.frame
                shareButtonNodeFrame.origin.x += rect.minX
                shareButtonNodeFrame.origin.y += rect.minY
                
                shareButtonNode.updateAbsoluteRect(shareButtonNodeFrame, within: containerSize)
            }
            
            if let actionButtonsNode = self.actionButtonsNode {
                var actionButtonsNodeFrame = actionButtonsNode.frame
                actionButtonsNodeFrame.origin.x += rect.minX
                actionButtonsNodeFrame.origin.y += rect.minY
                
                actionButtonsNode.updateAbsoluteRect(actionButtonsNodeFrame, within: containerSize)
            }
            
            if let reactionButtonsNode = self.reactionButtonsNode {
                var reactionButtonsNodeFrame = reactionButtonsNode.frame
                reactionButtonsNodeFrame.origin.x += rect.minX
                reactionButtonsNodeFrame.origin.y += rect.minY
                
                reactionButtonsNode.update(rect: rect, within: containerSize, transition: .immediate)
            }
            
            if let replyBackgroundContent = self.replyBackgroundContent {
                var replyBackgroundContentFrame = replyBackgroundContent.frame
                replyBackgroundContentFrame.origin.x += rect.minX
                replyBackgroundContentFrame.origin.y += rect.minY
                
                replyBackgroundContent.update(rect: rect, within: containerSize, transition: .immediate)
            }
            
            if let forwardBackgroundContent = self.forwardBackgroundContent {
                var forwardBackgroundContentFrame = forwardBackgroundContent.frame
                forwardBackgroundContentFrame.origin.x += rect.minX
                forwardBackgroundContentFrame.origin.y += rect.minY
                
                forwardBackgroundContent.update(rect: rect, within: containerSize, transition: .immediate)
            }
        }
    }
    
    override public func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
        
        if let reactionButtonsNode = self.reactionButtonsNode {
            reactionButtonsNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
    }
    
    override public func updateAccessibilityData(_ accessibilityData: ChatMessageAccessibilityData) {
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
                        item.controllerInteraction.openMessageContextMenu(item.message, false, self, self.imageNode.frame, nil, nil)
                    }
            }
        }
    }
    
    override public func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: ChatMessageHeaderSpec) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) {
        let displaySize = CGSize(width: 184.0, height: 184.0)
        let telegramFile = self.telegramFile
        let layoutConstants = self.layoutConstants
        let imageLayout = self.imageNode.asyncLayout()
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        let actionButtonsLayout = ChatMessageActionButtonsNode.asyncLayout(self.actionButtonsNode)
        let reactionButtonsLayout = ChatMessageReactionButtonsNode.asyncLayout(self.reactionButtonsNode)
        let textLayout = TextNode.asyncLayout(self.textNode)
        
        let makeForwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        
        let viaBotLayout = TextNode.asyncLayout(self.viaBotNode)
        //let makeThreadInfoLayout = ChatMessageThreadInfoNode.asyncLayout(self.threadInfoNode)
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentShareButtonNode = self.shareButtonNode
        let currentForwardInfo = self.appliedForwardInfo
        
        let makeSuggestedPostInfoNodeLayout: ChatMessageSuggestedPostInfoNode.AsyncLayout = ChatMessageSuggestedPostInfoNode.asyncLayout(self.suggestedPostInfoNode)
        
        func continueAsyncLayout(_ weakSelf: Weak<ChatMessageStickerItemNode>, _ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: ChatMessageHeaderSpec) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) {
            let accessibilityData = ChatMessageAccessibilityData(item: item, isSelected: nil)
            
            let layoutConstants = chatMessageItemLayoutConstants(layoutConstants, params: params, presentationData: item.presentationData)
            let incoming = item.content.effectivelyIncoming(item.context.account.peerId, associatedData: item.associatedData)
            var imageSize: CGSize = CGSize(width: 100.0, height: 100.0)
            if let telegramFile = telegramFile {
                if let dimensions = telegramFile.dimensions {
                    imageSize = dimensions.cgSize.aspectFitted(displaySize)
                } else if let thumbnailSize = telegramFile.previewRepresentations.first?.dimensions {
                    imageSize = thumbnailSize.cgSize.aspectFitted(displaySize)
                }
            }
            
            var textLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            var isEmoji = false
            if item.presentationData.largeEmoji && messageIsEligibleForLargeEmoji(item.message) {
                let attributedText = NSAttributedString(string: item.message.text, font: item.presentationData.messageEmojiFont, textColor: .black)
                textLayoutAndApply = textLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width, height: 90.0), alignment: .natural))
                
                imageSize = CGSize(width: textLayoutAndApply!.0.size.width, height: textLayoutAndApply!.0.size.height)
                isEmoji = true
            }
            
            let avatarInset: CGFloat
            var hasAvatar = false
            
            switch item.chatLocation {
            case let .peer(peerId):
                if !peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
                    if peerId.isGroupOrChannel && item.message.author != nil {
                        if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case let .broadcast(info) = peer.info {
                            if info.flags.contains(.messagesShouldHaveProfiles) {
                                hasAvatar = incoming
                            }
                        } else {
                            hasAvatar = true
                        }
                        
                        if case .customChatContents = item.chatLocation {
                            hasAvatar = false
                        }
                    }
                } else if incoming {
                    hasAvatar = true
                }
            case let .replyThread(replyThreadMessage):
                if replyThreadMessage.peerId != item.context.account.peerId {
                    if replyThreadMessage.peerId.isGroupOrChannel && item.message.author != nil {
                        var isBroadcastChannel = false
                        var isMonoforum = false
                        if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel {
                            if case .broadcast = peer.info {
                                isBroadcastChannel = true
                            }
                            isMonoforum = peer.isMonoForum
                        }
                        
                        if replyThreadMessage.isChannelPost, replyThreadMessage.effectiveTopId == item.message.id {
                            isBroadcastChannel = true
                        }
                        
                        if !isBroadcastChannel && !isMonoforum {
                            hasAvatar = true
                        }
                    }
                } else if incoming {
                    hasAvatar = true
                }
            case .customChatContents:
                hasAvatar = false
            }
            
            if hasAvatar {
                avatarInset = layoutConstants.avatarDiameter
            } else {
                avatarInset = 0.0
            }
            
            let isFailed = item.content.firstMessage.effectivelyFailed(timestamp: item.context.account.network.getApproximateRemoteTimestamp())
            
            var needsShareButton = false
            if case .pinnedMessages = item.associatedData.subject {
                needsShareButton = true
            } else if isFailed || Namespaces.Message.allNonRegular.contains(item.message.id.namespace) {
                needsShareButton = false
            } else if item.message.id.peerId == item.context.account.peerId {
                for attribute in item.content.firstMessage.attributes {
                    if let _ = attribute as? SourceReferenceMessageAttribute {
                        needsShareButton = true
                        break
                    }
                }
            } else if item.message.effectivelyIncoming(item.context.account.peerId) {
                if let peer = item.message.peers[item.message.id.peerId] {
                    if let channel = peer as? TelegramChannel {
                        if case .broadcast = channel.info {
                            needsShareButton = true
                        }
                    }
                }
                if !needsShareButton, let author = item.message.author as? TelegramUser, let _ = author.botInfo, !item.message.media.isEmpty {
                    needsShareButton = true
                }
                if !needsShareButton {
                    loop: for media in item.message.media {
                        if media is TelegramMediaGame || media is TelegramMediaInvoice {
                            needsShareButton = true
                            break loop
                        } else if let media = media as? TelegramMediaWebpage, case .Loaded = media.content {
                            needsShareButton = true
                            break loop
                        }
                    }
                } else {
                    loop: for media in item.message.media {
                        if media is TelegramMediaAction {
                            needsShareButton = false
                            break loop
                        }
                    }
                }
                
                if item.associatedData.isCopyProtectionEnabled || item.message.isCopyProtected() {
                    if hasCommentButton(item: item) {
                    } else {
                        needsShareButton = false
                    }
                }
            }
            
            if let subject = item.associatedData.subject, case .messageOptions = subject {
                needsShareButton = false
            }
            
            var layoutInsets = UIEdgeInsets(top: mergedTop.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
            if dateHeaderAtBottom.hasDate && dateHeaderAtBottom.hasTopic {
                layoutInsets.top += layoutConstants.timestampDateAndTopicHeaderHeight
            } else {
                if dateHeaderAtBottom.hasDate {
                    layoutInsets.top += layoutConstants.timestampHeaderHeight
                }
                if dateHeaderAtBottom.hasTopic {
                    layoutInsets.top += layoutConstants.timestampHeaderHeight
                }
            }
            
            var deliveryFailedInset: CGFloat = 0.0
            if isFailed {
                deliveryFailedInset += 24.0
            }
            
            let displayLeftInset = params.leftInset + layoutConstants.bubble.edgeInset + avatarInset
            
            let innerImageInset: CGFloat = 10.0
            let innerImageSize = CGSize(width: imageSize.width + innerImageInset * 2.0, height: imageSize.height + innerImageInset * 2.0)
            var imageFrame = CGRect(origin: CGPoint(x: 0.0 + (incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + avatarInset + layoutConstants.bubble.contentInsets.left) : (params.width - params.rightInset - innerImageSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - deliveryFailedInset)), y: -innerImageInset), size: innerImageSize)
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(top: innerImageInset, left: innerImageInset, bottom: innerImageInset, right: innerImageInset))
            
            let imageApply = imageLayout(arguments)
            
            let statusType: ChatMessageDateAndStatusType
            if item.message.effectivelyIncoming(item.context.account.peerId) {
                statusType = .FreeIncoming
            } else {
                if isFailed {
                    statusType = .FreeOutgoing(.Failed)
                } else if item.message.flags.isSending && !item.message.isSentOrAcknowledged {
                    statusType = .FreeOutgoing(.Sending)
                } else {
                    statusType = .FreeOutgoing(.Sent(read: item.read))
                }
            }
            
            var edited = false
            var viewCount: Int? = nil
            var dateReplies = 0
            var starsCount: Int64?
            var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: item.message)
            if item.message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                dateReactionsAndPeers = ([], [])
            }
            for attribute in item.message.attributes {
                if let attribute = attribute as? EditedMessageAttribute, isEmoji {
                    edited = !attribute.isHidden
                } else if let attribute = attribute as? ViewCountMessageAttribute {
                    viewCount = attribute.count
                } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                    if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                        dateReplies = Int(attribute.count)
                    }
                } else if let attribute = attribute as? PaidStarsMessageAttribute, item.message.id.peerId.namespace == Namespaces.Peer.CloudChannel {
                    starsCount = attribute.stars.value
                }
            }
            
            let dateFormat: MessageTimestampStatusFormat
            if item.presentationData.isPreview {
                dateFormat = .full
            } else {
                dateFormat = .regular
            }
            let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: dateFormat, associatedData: item.associatedData)
            
            var isReplyThread = false
            if case .replyThread = item.chatLocation {
                isReplyThread = true
            }
            
            let statusSuggestedWidthAndContinue = makeDateAndStatusLayout(ChatMessageDateAndStatusNode.Arguments(
                context: item.context,
                presentationData: item.presentationData,
                edited: edited,
                impressionCount: viewCount,
                dateText: dateText,
                type: statusType,
                layoutInput: .standalone(reactionSettings: shouldDisplayInlineDateReactions(message: item.message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.StandaloneReactionSettings() : nil),
                constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude),
                availableReactions: item.associatedData.availableReactions,
                savedMessageTags: item.associatedData.savedMessageTags,
                reactions: dateReactionsAndPeers.reactions,
                reactionPeers: dateReactionsAndPeers.peers,
                displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                areReactionsTags: item.message.areReactionsTags(accountPeerId: item.context.account.peerId),
                messageEffect: item.message.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects),
                replyCount: dateReplies,
                starsCount: starsCount,
                isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && !isReplyThread,
                hasAutoremove: item.message.isSelfExpiring,
                canViewReactionList: canViewMessageReactionList(message: item.message),
                animationCache: item.controllerInteraction.presentationContext.animationCache,
                animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
            ))
            
            let (dateAndStatusSize, dateAndStatusApply) = statusSuggestedWidthAndContinue.1(statusSuggestedWidthAndContinue.0)
            
            var viaBotApply: (TextNodeLayout, () -> TextNode)?
            let threadInfoApply: (CGSize, (Bool) -> ChatMessageThreadInfoNode)? = nil
            var replyInfoApply: (CGSize, (CGSize, Bool, ListViewItemUpdateAnimation) -> ChatMessageReplyInfoNode)?
            var replyMarkup: ReplyMarkupMessageAttribute?
            
            var availableWidth = min(200.0, max(60.0, params.width - params.leftInset - params.rightInset - max(imageSize.width, 160.0) - 20.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left))
            availableWidth -= 20.0
            if isEmoji {
                availableWidth -= 24.0
            }
            
            var ignoreForward = false
            if let forwardInfo = item.message.forwardInfo {
                if item.message.id.peerId != item.context.account.peerId {
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? SourceReferenceMessageAttribute {
                            if attribute.messageId.peerId == forwardInfo.author?.id {
                                ignoreForward = true
                            }
                            break
                        }
                    }
                }
            }
            
            var replyMessage: Message?
            var replyForward: QuotedReplyMessageAttribute?
            var replyQuote: (quote: EngineMessageReplyQuote, isQuote: Bool)?
            var replyStory: StoryId?
            for attribute in item.message.attributes {
                if let attribute = attribute as? InlineBotMessageAttribute {
                    var inlineBotNameString: String?
                    if let peerId = attribute.peerId, let bot = item.message.peers[peerId] as? TelegramUser {
                        inlineBotNameString = bot.addressName
                    } else {
                        inlineBotNameString = attribute.title
                    }
                    
                    if let inlineBotNameString = inlineBotNameString {
                        let inlineBotNameColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                        
                        let bodyAttributes = MarkdownAttributeSet(font: nameFont, textColor: inlineBotNameColor)
                        let boldAttributes = MarkdownAttributeSet(font: inlineBotPrefixFont, textColor: inlineBotNameColor)
                        let botString = addAttributesToStringWithRanges(item.presentationData.strings.Conversation_MessageViaUser("@\(inlineBotNameString)")._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                        
                        viaBotApply = viaBotLayout(TextNodeLayoutArguments(attributedString: botString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, availableWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                    }
                }
                
              
                if let replyAttribute = attribute as? ReplyMessageAttribute {
                    if case let .replyThread(replyThreadMessage) = item.chatLocation, Int32(clamping: replyThreadMessage.threadId) == replyAttribute.messageId.id {
                    } else {
                        replyMessage = item.message.associatedMessages[replyAttribute.messageId]
                    }
                    replyQuote = replyAttribute.quote.flatMap { ($0, replyAttribute.isQuote) }
                } else if let attribute = attribute as? QuotedReplyMessageAttribute {
                    replyForward = attribute
                } else if let attribute = attribute as? ReplyStoryAttribute {
                    replyStory = attribute.storyId
                } else if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
                    replyMarkup = attribute
                }
            }
            
            var hasReply = replyMessage != nil || replyForward != nil || replyStory != nil
            if case let .peer(peerId) = item.chatLocation, (peerId == replyMessage?.id.peerId || item.message.threadId == 1), let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, channel.isForumOrMonoForum, item.message.associatedThreadInfo != nil {
                if let threadId = item.message.threadId, let replyMessage = replyMessage, Int64(replyMessage.id.id) == threadId {
                    hasReply = false
                }
                    
                /*threadInfoApply = makeThreadInfoLayout(ChatMessageThreadInfoNode.Arguments(
                    presentationData: item.presentationData,
                    strings: item.presentationData.strings,
                    context: item.context,
                    controllerInteraction: item.controllerInteraction,
                    type: .standalone,
                    peer: nil,
                    threadId: item.message.threadId ?? 1,
                    parentMessage: item.message,
                    constrainedSize: CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude),
                    animationCache: item.controllerInteraction.presentationContext.animationCache,
                    animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                ))*/
            }
            
            if hasReply, (replyMessage != nil || replyForward != nil || replyStory != nil) {
                replyInfoApply = makeReplyInfoLayout(ChatMessageReplyInfoNode.Arguments(
                    presentationData: item.presentationData,
                    strings: item.presentationData.strings,
                    context: item.context,
                    type: .standalone,
                    message: replyMessage,
                    replyForward: replyForward,
                    quote: replyQuote,
                    story: replyStory,
                    parentMessage: item.message,
                    constrainedSize: CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude),
                    animationCache: item.controllerInteraction.presentationContext.animationCache,
                    animationRenderer: item.controllerInteraction.presentationContext.animationRenderer,
                    associatedData: item.associatedData
                ))
            }
            
            if item.message.id.peerId != item.context.account.peerId && !item.message.id.peerId.isReplies {
                for attribute in item.message.attributes {
                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                        if let sourcePeer = item.message.peers[attribute.messageId.peerId] {
                            let inlineBotNameColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                            
                            let nameString = NSAttributedString(string: EnginePeer(sourcePeer).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder), font: inlineBotPrefixFont, textColor: inlineBotNameColor)
                            viaBotApply = viaBotLayout(TextNodeLayoutArguments(attributedString: nameString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, availableWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                        }
                    }
                }
            }

            var updatedShareButtonNode: ChatMessageShareButton?
            if needsShareButton {
                if let currentShareButtonNode = currentShareButtonNode {
                    updatedShareButtonNode = currentShareButtonNode
                } else {
                    let buttonNode = ChatMessageShareButton()
                    updatedShareButtonNode = buttonNode
                }
            }
            
            let contentHeight = max(imageSize.height, layoutConstants.image.minDimensions.height)
            
            var forwardSource: Peer?
            var forwardAuthorSignature: String?
            var forwardPsaType: String?
            
            var forwardInfoSizeApply: (CGSize, (CGFloat) -> ChatMessageForwardInfoNode)?
            
            if !ignoreForward, let forwardInfo = item.message.forwardInfo {
                forwardPsaType = forwardInfo.psaType
                
                if let source = forwardInfo.source {
                    forwardSource = source
                    if let authorSignature = forwardInfo.authorSignature {
                        forwardAuthorSignature = authorSignature
                    } else if let forwardInfoAuthor = forwardInfo.author, forwardInfoAuthor.id != source.id {
                        forwardAuthorSignature = EnginePeer(forwardInfoAuthor).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    } else {
                        forwardAuthorSignature = nil
                    }
                } else {
                    if let currentForwardInfo = currentForwardInfo, forwardInfo.author == nil && currentForwardInfo.0 != nil {
                        forwardSource = nil
                        forwardAuthorSignature = currentForwardInfo.0.flatMap(EnginePeer.init)?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    } else {
                        forwardSource = forwardInfo.author
                        forwardAuthorSignature = forwardInfo.authorSignature
                    }
                }
                let availableForwardWidth = max(60.0, availableWidth + 6.0)
                forwardInfoSizeApply = makeForwardInfoLayout(item.context, item.presentationData, item.presentationData.strings, .standalone, forwardSource, forwardAuthorSignature, forwardPsaType, nil, CGSize(width: availableForwardWidth, height: CGFloat.greatestFiniteMagnitude))
            }
            
            var needsReplyBackground = false
            if replyInfoApply != nil {
                needsReplyBackground = true
            }
            
            var needsForwardBackground = false
            if viaBotApply != nil || forwardInfoSizeApply != nil {
                needsForwardBackground = true
            }
            
            let baseWidth = params.width - params.leftInset - params.rightInset
            
            var maxContentWidth = imageSize.width
            var actionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animation: ListViewItemUpdateAnimation) -> ChatMessageActionButtonsNode))?
            if let replyMarkup = replyMarkup {
                let (minWidth, buttonsLayout) = actionButtonsLayout(item.context, item.presentationData.theme, item.presentationData.chatBubbleCorners, item.presentationData.strings, item.controllerInteraction.presentationContext.backgroundNode, replyMarkup, [:], item.message, baseWidth)
                maxContentWidth = max(maxContentWidth, minWidth)
                actionButtonsFinalize = buttonsLayout
            } else if incoming, let attribute = item.message.attributes.first(where: { $0 is SuggestedPostMessageAttribute }) as? SuggestedPostMessageAttribute, attribute.state == nil {
                var canApprove = true
                if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, peer.isMonoForum, let linkedMonoforumId = peer.linkedMonoforumId, let mainChannel = item.message.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect), !mainChannel.hasPermission(.sendSomething) {
                    canApprove = false
                }
                
                var buttonDeclineValue: UInt8 = 0
                let buttonDecline = MemoryBuffer(data: Data(bytes: &buttonDeclineValue, count: 1))
                var buttonApproveValue: UInt8 = 1
                let buttonApprove = MemoryBuffer(data: Data(bytes: &buttonApproveValue, count: 1))
                var buttonSuggestChangesValue: UInt8 = 2
                let buttonSuggestChanges = MemoryBuffer(data: Data(bytes: &buttonSuggestChangesValue, count: 1))
                
                let customInfos: [MemoryBuffer: ChatMessageActionButtonsNode.CustomInfo] = [
                    buttonDecline: ChatMessageActionButtonsNode.CustomInfo(
                        isEnabled: true,
                        icon: .suggestedPostReject
                    ),
                    buttonApprove: ChatMessageActionButtonsNode.CustomInfo(
                        isEnabled: canApprove,
                        icon: .suggestedPostApprove
                    ),
                    buttonSuggestChanges: ChatMessageActionButtonsNode.CustomInfo(
                        isEnabled: canApprove,
                        icon: .suggestedPostEdit
                    )
                ]
                
                let (minWidth, buttonsLayout) = actionButtonsLayout(
                    item.context,
                    item.presentationData.theme,
                    item.presentationData.chatBubbleCorners,
                    item.presentationData.strings,
                    item.controllerInteraction.presentationContext.backgroundNode,
                    ReplyMarkupMessageAttribute(
                        rows: [
                            ReplyMarkupRow(buttons: [
                                ReplyMarkupButton(title: item.presentationData.strings.Chat_PostApproval_Message_ActionReject, titleWhenForwarded: nil, action: .callback(requiresPassword: false, data: buttonDecline)),
                                ReplyMarkupButton(title: item.presentationData.strings.Chat_PostApproval_Message_ActionApprove, titleWhenForwarded: nil, action: .callback(requiresPassword: false, data: buttonApprove))
                            ]),
                            ReplyMarkupRow(buttons: [
                                ReplyMarkupButton(title: item.presentationData.strings.Chat_PostApproval_Message_ActionSuggestChanges, titleWhenForwarded: nil, action: .callback(requiresPassword: false, data: buttonSuggestChanges))
                            ])
                        ],
                        flags: [],
                        placeholder: nil
                ), customInfos, item.message, baseWidth)
                maxContentWidth = max(maxContentWidth, minWidth)
                actionButtonsFinalize = buttonsLayout
            }
            
            var actionButtonsSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageActionButtonsNode)?
            if let actionButtonsFinalize = actionButtonsFinalize {
                actionButtonsSizeAndApply = actionButtonsFinalize(maxContentWidth)
            }
            
            let reactions: ReactionsMessageAttribute
            if shouldDisplayInlineDateReactions(message: item.message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) {
                reactions = ReactionsMessageAttribute(canViewList: false, isTags: false, reactions: [], recentPeers: [], topPeers: [])
            } else {
                reactions = mergedMessageReactions(attributes: item.message.attributes, isTags: item.message.areReactionsTags(accountPeerId: item.context.account.peerId)) ?? ReactionsMessageAttribute(canViewList: false, isTags: false, reactions: [], recentPeers: [], topPeers: [])
            }
            
            var reactionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animation: ListViewItemUpdateAnimation) -> ChatMessageReactionButtonsNode))?
            if !reactions.reactions.isEmpty {
                let totalInset = params.leftInset + layoutConstants.bubble.edgeInset * 2.0 + avatarInset + layoutConstants.bubble.contentInsets.left * 2.0 + params.rightInset
                
                let maxReactionsWidth = params.width - totalInset
                let (minWidth, buttonsLayout) = reactionButtonsLayout(ChatMessageReactionButtonsNode.Arguments(
                    context: item.context,
                    presentationData: item.presentationData,
                    presentationContext: item.controllerInteraction.presentationContext,
                    availableReactions: item.associatedData.availableReactions,
                    savedMessageTags: item.associatedData.savedMessageTags,
                    reactions: reactions,
                    message: item.message,
                    associatedData: item.associatedData,
                    accountPeer: item.associatedData.accountPeer,
                    isIncoming: item.message.effectivelyIncoming(item.context.account.peerId),
                    constrainedWidth: maxReactionsWidth,
                    centerAligned: false
                ))
                maxContentWidth = max(maxContentWidth, minWidth)
                reactionButtonsFinalize = buttonsLayout
            }
            
            var reactionButtonsSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageReactionButtonsNode)?
            if let reactionButtonsFinalize = reactionButtonsFinalize {
                reactionButtonsSizeAndApply = reactionButtonsFinalize(maxContentWidth)
            }
            
            var layoutSize = CGSize(width: params.width, height: contentHeight)
            if isEmoji && !incoming {
                layoutSize.height += dateAndStatusSize.height
            }
            if let reactionButtonsSizeAndApply = reactionButtonsSizeAndApply {
                layoutSize.height += reactionButtonsSizeAndApply.0.height + 2.0
            }
            if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                layoutSize.height += actionButtonsSizeAndApply.0.height
            }
            
            var suggestedPostInfoNodeLayout: (CGSize, () -> ChatMessageSuggestedPostInfoNode)?
            for attribute in item.message.attributes {
                if let _ = attribute as? SuggestedPostMessageAttribute {
                    let suggestedPostInfoNodeLayoutValue = makeSuggestedPostInfoNodeLayout(item, baseWidth)
                    suggestedPostInfoNodeLayout = suggestedPostInfoNodeLayoutValue
                }
            }
            
            var additionalTopHeight: CGFloat = 0.0
            if let suggestedPostInfoNodeLayout {
                additionalTopHeight += 4.0 + suggestedPostInfoNodeLayout.0.height + 8.0
            }
            layoutSize.height += additionalTopHeight
            imageFrame.origin.y += additionalTopHeight
            
            var updatedImageFrame = imageFrame.offsetBy(dx: 0.0, dy: floor((contentHeight - imageSize.height) / 2.0))
            
            var dateOffset = CGPoint(x: dateAndStatusSize.width + 4.0, y: dateAndStatusSize.height + 16.0)
            if isEmoji {
                if incoming {
                    dateOffset.x = 12.0
                } else {
                    dateOffset.y = 12.0
                }
            }
            var dateAndStatusFrame = CGRect(origin: CGPoint(x: min(layoutSize.width - dateAndStatusSize.width - 14.0, max(displayLeftInset, updatedImageFrame.maxX - dateOffset.x)), y: updatedImageFrame.maxY - dateOffset.y), size: dateAndStatusSize)
            
            let baseShareButtonSize = CGSize(width: 30.0, height: 60.0)
            var baseShareButtonFrame = CGRect(origin: CGPoint(x: !incoming ? updatedImageFrame.minX - baseShareButtonSize.width - 6.0 : updatedImageFrame.maxX + 6.0, y: updatedImageFrame.maxY - 10.0 - baseShareButtonSize.height - 4.0), size: baseShareButtonSize)
            if isEmoji && incoming {
                baseShareButtonFrame.origin.x = dateAndStatusFrame.maxX + 8.0
            }
            
            var headersOffset: CGFloat = additionalTopHeight
            if let (threadInfoSize, _) = threadInfoApply {
                headersOffset += threadInfoSize.height + 10.0
            }
            
            var viaBotFrame: CGRect?
            if let (viaBotLayout, _) = viaBotApply {
                viaBotFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 15.0) : (params.width - params.rightInset - viaBotLayout.size.width - layoutConstants.bubble.edgeInset - 14.0)), y: headersOffset + 8.0), size: viaBotLayout.size)
            }
            
            var replyInfoFrame: CGRect?
            if let (replyInfoSize, _) = replyInfoApply {
                var viaBotSize = CGSize()
                if let viaBotFrame = viaBotFrame {
                    viaBotSize = viaBotFrame.size
                }
                let replyInfoFrameValue = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 10.0) : (params.width - params.rightInset - max(replyInfoSize.width, viaBotSize.width) - layoutConstants.bubble.edgeInset - 10.0)), y: headersOffset + 8.0 + viaBotSize.height), size: replyInfoSize)
                replyInfoFrame = replyInfoFrameValue
                if let viaBotFrameValue = viaBotFrame {
                    if replyInfoFrameValue.minX < replyInfoFrameValue.minX {
                        viaBotFrame = viaBotFrameValue.offsetBy(dx: replyInfoFrameValue.minX - viaBotFrameValue.minX, dy: 0.0)
                    }
                }
            }
            
            var replyBackgroundFrame: CGRect?
            if let replyInfoFrame = replyInfoFrame {
                var viaBotSize = CGSize()
                if let viaBotFrame = viaBotFrame {
                    viaBotSize = viaBotFrame.size
                }
                
                replyBackgroundFrame = CGRect(origin: CGPoint(x: replyInfoFrame.minX - 4.0, y: headersOffset + replyInfoFrame.minY - viaBotSize.height - 2.0), size: CGSize(width: max(replyInfoFrame.size.width, viaBotSize.width) + 8.0, height: replyInfoFrame.size.height + viaBotSize.height + 5.0))
            }
            
            if let replyBackgroundFrameValue = replyBackgroundFrame {
                if replyBackgroundFrameValue.insetBy(dx: -2.0, dy: -2.0).intersects(baseShareButtonFrame) {
                    let offset: CGFloat = 25.0
                    
                    layoutSize.height += offset
                    updatedImageFrame.origin.y += offset
                    dateAndStatusFrame.origin.y += offset
                    baseShareButtonFrame.origin.y += offset
                }
            }
            
            func finishAsyncLayout(_ animation: ListViewItemUpdateAnimation, _ synchronousLoads: Bool) {
                if let strongSelf = weakSelf.value {
                    var transition: ContainedViewLayoutTransition = .immediate
                    if case let .System(duration, _) = animation {
                        transition = .animated(duration: duration, curve: .spring)
                    }
                    
                    strongSelf.appliedForwardInfo = (forwardSource, forwardAuthorSignature)
                    strongSelf.updateAccessibilityData(accessibilityData)
                    
                    strongSelf.updateAttachedDateHeader(hasDate: dateHeaderAtBottom.hasDate, hasPeer: dateHeaderAtBottom.hasTopic)
                    
                    transition.updateFrame(node: strongSelf.imageNode, frame: updatedImageFrame)
                    strongSelf.enableSynchronousImageApply = true
                    imageApply()
                    strongSelf.enableSynchronousImageApply = false
                    
                    if let immediateThumbnailData = telegramFile?.immediateThumbnailData {
                        if strongSelf.backgroundNode == nil {
                            if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                strongSelf.backgroundNode = backgroundNode
                                strongSelf.placeholderNode.addBackdropNode(backgroundNode)
                                
                                if let (rect, size) = strongSelf.absoluteRect {
                                    strongSelf.updateAbsoluteRect(rect, within: size)
                                }
                            }
                        }
                        
                        let foregroundColor: UIColor = .clear//bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.stickerPlaceholderColor, wallpaper: item.presentationData.theme.wallpaper)
                        let shimmeringColor = bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.stickerPlaceholderShimmerColor, wallpaper: item.presentationData.theme.wallpaper)
                        
                        let placeholderFrame = updatedImageFrame.insetBy(dx: innerImageInset, dy: innerImageInset)
                        strongSelf.placeholderNode.update(backgroundColor: nil, foregroundColor: foregroundColor, shimmeringColor: shimmeringColor, data: immediateThumbnailData, size: placeholderFrame.size, enableEffect: item.context.sharedContext.energyUsageSettings.fullTranslucency)
                        animation.animator.updateFrame(layer: strongSelf.placeholderNode.layer, frame: placeholderFrame, completion: nil)
                    }
                    
                    if let (suggestedPostInfoSize, suggestedPostInfoApply) = suggestedPostInfoNodeLayout {
                        let suggestedPostInfoNode = suggestedPostInfoApply()
                        if suggestedPostInfoNode !== strongSelf.suggestedPostInfoNode {
                            strongSelf.suggestedPostInfoNode?.removeFromSupernode()
                            strongSelf.suggestedPostInfoNode = suggestedPostInfoNode
                            strongSelf.addSubnode(suggestedPostInfoNode)
                        }
                        let suggestedPostInfoFrame = CGRect(origin: CGPoint(x: floor((params.width - suggestedPostInfoSize.width) * 0.5), y: 4.0), size: suggestedPostInfoSize)
                        suggestedPostInfoNode.frame = suggestedPostInfoFrame
                    } else if let suggestedPostInfoNode = strongSelf.suggestedPostInfoNode {
                        strongSelf.suggestedPostInfoNode = nil
                        suggestedPostInfoNode.removeFromSupernode()
                    }
                    
                    strongSelf.messageAccessibilityArea.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.contextSourceNode.contentRect = strongSelf.imageNode.frame
                    strongSelf.containerNode.targetNodeForActivationProgressContentRect = strongSelf.contextSourceNode.contentRect
                    
                    animation.animator.updateFrame(layer: strongSelf.dateAndStatusNode.layer, frame: dateAndStatusFrame, completion: nil)
                    dateAndStatusApply(animation)
                    if case .customChatContents = item.associatedData.subject {
                        strongSelf.dateAndStatusNode.isHidden = true
                    }
                    
                    if let updatedShareButtonNode = updatedShareButtonNode {
                        if updatedShareButtonNode !== strongSelf.shareButtonNode {
                            if let shareButtonNode = strongSelf.shareButtonNode {
                                shareButtonNode.removeFromSupernode()
                            }
                            strongSelf.shareButtonNode = updatedShareButtonNode
                            strongSelf.addSubnode(updatedShareButtonNode)
                            updatedShareButtonNode.pressed = { [weak strongSelf] in
                                strongSelf?.shareButtonPressed()
                            }
                            updatedShareButtonNode.longPressAction = { [weak strongSelf] node, gesture in
                                strongSelf?.openQuickShare(node: node, gesture: gesture)
                            }
                        }
                        let buttonSize = updatedShareButtonNode.update(presentationData: item.presentationData, controllerInteraction: item.controllerInteraction, chatLocation: item.chatLocation, subject: item.associatedData.subject, message: item.message, account: item.context.account)
                        let shareButtonFrame = CGRect(origin: CGPoint(x: baseShareButtonFrame.minX, y: baseShareButtonFrame.maxY - buttonSize.height), size: buttonSize)
                        transition.updateFrame(node: updatedShareButtonNode, frame: shareButtonFrame)
                    } else if let shareButtonNode = strongSelf.shareButtonNode {
                        shareButtonNode.removeFromSupernode()
                        strongSelf.shareButtonNode = nil
                    }
                    
                    if needsReplyBackground {
                        if strongSelf.replyBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                            backgroundContent.clipsToBounds = true
                            strongSelf.replyBackgroundContent = backgroundContent
                            strongSelf.contextSourceNode.contentNode.insertSubnode(backgroundContent, at: 0)
                        }
                    } else {
                        if let replyBackgroundContent = strongSelf.replyBackgroundContent {
                            replyBackgroundContent.removeFromSupernode()
                            strongSelf.replyBackgroundContent = nil
                        }
                    }
                    
                    if needsForwardBackground {
                        if strongSelf.forwardBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                            backgroundContent.clipsToBounds = true
                            strongSelf.forwardBackgroundContent = backgroundContent
                            strongSelf.contextSourceNode.contentNode.insertSubnode(backgroundContent, at: 0)
                        }
                    } else {
                        if let forwardBackgroundContent = strongSelf.forwardBackgroundContent {
                            forwardBackgroundContent.removeFromSupernode()
                            strongSelf.forwardBackgroundContent = nil
                        }
                    }
                    
                    var headersOffset: CGFloat = additionalTopHeight
                    if let (threadInfoSize, threadInfoApply) = threadInfoApply {
                        let threadInfoNode = threadInfoApply(synchronousLoads)
                        if strongSelf.threadInfoNode == nil {
                            strongSelf.threadInfoNode = threadInfoNode
                            strongSelf.contextSourceNode.contentNode.addSubnode(threadInfoNode)
                        }
                        let threadInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 6.0) : (params.width - params.rightInset - threadInfoSize.width - layoutConstants.bubble.edgeInset - 8.0)), y: 8.0), size: threadInfoSize)
                        animation.animator.updateFrame(layer: threadInfoNode.layer, frame: threadInfoFrame, completion: nil)
                        
                        headersOffset += threadInfoSize.height + 10.0
                    } else if let replyInfoNode = strongSelf.replyInfoNode {
                        replyInfoNode.removeFromSupernode()
                        strongSelf.replyInfoNode = nil
                    }
                    
                    var messageInfoSize = CGSize()
                    if let (viaBotLayout, _) = viaBotApply, forwardInfoSizeApply == nil {
                        messageInfoSize = CGSize(width: viaBotLayout.size.width + 1.0, height: 0.0)
                    }
                    if let (forwardInfoSize, _) = forwardInfoSizeApply {
                        messageInfoSize = CGSize(width: max(messageInfoSize.width, forwardInfoSize.width + 2.0), height: 0.0)
                    }
                    if let (replyInfoSize, _) = replyInfoApply {
                        messageInfoSize = CGSize(width: max(messageInfoSize.width, replyInfoSize.width), height: 0.0)
                    }
                    
                    var forwardAreaFrame: CGRect?
                    if let (viaBotLayout, viaBotApply) = viaBotApply, forwardInfoSizeApply == nil {
                        let viaBotNode = viaBotApply()
                        if strongSelf.viaBotNode == nil {
                            strongSelf.viaBotNode = viaBotNode
                            strongSelf.contextSourceNode.contentNode.addSubnode(viaBotNode)
                        }
                        let viaBotFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 11.0 + 5.0) : (params.width - params.rightInset - messageInfoSize.width - layoutConstants.bubble.edgeInset - 9.0 - 5.0)), y: headersOffset + 8.0), size: viaBotLayout.size)
                        
                        viaBotNode.frame = viaBotFrame
                        
                        messageInfoSize = CGSize(width: messageInfoSize.width, height: viaBotLayout.size.height)
                        
                        if let forwardAreaFrameValue = forwardAreaFrame {
                            forwardAreaFrame = forwardAreaFrameValue.union(viaBotFrame)
                        } else {
                            forwardAreaFrame = viaBotFrame
                        }
                    } else if let viaBotNode = strongSelf.viaBotNode {
                        viaBotNode.removeFromSupernode()
                        strongSelf.viaBotNode = nil
                    }
                        
                    if let (forwardInfoSize, forwardInfoApply) = forwardInfoSizeApply {
                        let forwardInfoNode = forwardInfoApply(forwardInfoSize.width)
                        if strongSelf.forwardInfoNode == nil {
                            strongSelf.forwardInfoNode = forwardInfoNode
                            strongSelf.contextSourceNode.contentNode.addSubnode(forwardInfoNode)
                            
                            if animation.isAnimated {
                                forwardInfoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        }
                        let forwardInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 12.0 + 5.0) : (params.width - params.rightInset - messageInfoSize.width - layoutConstants.bubble.edgeInset - 8.0 - 5.0)), y: headersOffset + 8.0 + messageInfoSize.height), size: forwardInfoSize)
                        animation.animator.updateFrame(layer: forwardInfoNode.layer, frame: forwardInfoFrame, completion: nil)
                        
                        messageInfoSize = CGSize(width: messageInfoSize.width, height: messageInfoSize.height + forwardInfoSize.height + 8.0)
                        
                        if let forwardAreaFrameValue = forwardAreaFrame {
                            forwardAreaFrame = forwardAreaFrameValue.union(forwardInfoFrame)
                        } else {
                            forwardAreaFrame = forwardInfoFrame
                        }
                    } else if let forwardInfoNode = strongSelf.forwardInfoNode {
                        if animation.isAnimated {
                            if let forwardInfoNode = strongSelf.forwardInfoNode {
                                strongSelf.forwardInfoNode = nil
                                forwardInfoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak forwardInfoNode] _ in
                                    forwardInfoNode?.removeFromSupernode()
                                })
                            }
                        } else {
                            forwardInfoNode.removeFromSupernode()
                            strongSelf.forwardInfoNode = nil
                        }
                    }
                    
                    var forwardBackgroundFrame: CGRect?
                    if let forwardAreaFrame {
                        var forwardBackgroundFrameValue = forwardAreaFrame.insetBy(dx: -6.0, dy: -3.0)
                        forwardBackgroundFrameValue.size.height += 2.0
                        forwardBackgroundFrame = forwardBackgroundFrameValue
                    }
                    
                    var replyBackgroundFrame: CGRect?
                    if let (replyInfoSize, replyInfoApply) = replyInfoApply {
                        if headersOffset != 0.0 {
                            headersOffset += 6.0
                        }
                        
                        let replyInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 11.0) : (params.width - params.rightInset - replyInfoSize.width - layoutConstants.bubble.edgeInset - 9.0)), y: headersOffset + 8.0 + messageInfoSize.height), size: replyInfoSize)
                        replyBackgroundFrame = replyInfoFrame
                        
                        let replyInfoNode = replyInfoApply(replyInfoFrame.size, synchronousLoads, animation)
                        if strongSelf.replyInfoNode == nil {
                            strongSelf.replyInfoNode = replyInfoNode
                            strongSelf.contextSourceNode.contentNode.addSubnode(replyInfoNode)
                        }
                        replyInfoNode.frame = replyInfoFrame
                        
                        messageInfoSize = CGSize(width: max(messageInfoSize.width, replyInfoSize.width), height: messageInfoSize.height + replyInfoSize.height)
                    } else if let replyInfoNode = strongSelf.replyInfoNode {
                        replyInfoNode.removeFromSupernode()
                        strongSelf.replyInfoNode = nil
                    }
                    
                    if let backgroundContent = strongSelf.replyBackgroundContent, let replyBackgroundFrame {
                        backgroundContent.cornerRadius = 4.0
                        backgroundContent.frame = replyBackgroundFrame
                        if let (rect, containerSize) = strongSelf.absoluteRect {
                            var backgroundFrame = backgroundContent.frame
                            backgroundFrame.origin.x += rect.minX
                            backgroundFrame.origin.y += rect.minY
                            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
                        }
                    }
                    
                    if let backgroundContent = strongSelf.forwardBackgroundContent, let forwardBackgroundFrame {
                        let forwardBackgroundMaskNode: LinkHighlightingNode
                        if let current = strongSelf.forwardBackgroundMaskNode {
                            forwardBackgroundMaskNode = current
                        } else {
                            forwardBackgroundMaskNode = LinkHighlightingNode(color: .black)
                            forwardBackgroundMaskNode.inset = 4.0
                            forwardBackgroundMaskNode.outerRadius = 12.0
                            strongSelf.forwardBackgroundMaskNode = forwardBackgroundMaskNode
                            backgroundContent.view.mask = forwardBackgroundMaskNode.view
                        }
                        
                        backgroundContent.frame = forwardBackgroundFrame
                        if let (rect, containerSize) = strongSelf.absoluteRect {
                            var backgroundFrame = backgroundContent.frame
                            backgroundFrame.origin.x += rect.minX
                            backgroundFrame.origin.y += rect.minY
                            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
                        }
                        
                        if let forwardInfoNode = strongSelf.forwardInfoNode {
                            forwardBackgroundMaskNode.frame = backgroundContent.bounds.offsetBy(dx: forwardInfoNode.frame.minX - backgroundContent.frame.minX, dy: forwardInfoNode.frame.minY - backgroundContent.frame.minY)
                            var backgroundRects = forwardInfoNode.getBoundingRects()
                            for i in 0 ..< backgroundRects.count {
                                backgroundRects[i].origin.x -= 2.0
                                backgroundRects[i].size.width += 4.0
                            }
                            for i in 0 ..< backgroundRects.count {
                                if i != 0 {
                                    if abs(backgroundRects[i - 1].maxX - backgroundRects[i].maxX) < 16.0 {
                                        let maxMaxX = max(backgroundRects[i - 1].maxX, backgroundRects[i].maxX)
                                        backgroundRects[i - 1].size.width = max(0.0, maxMaxX - backgroundRects[i - 1].origin.x)
                                        backgroundRects[i].size.width = max(0.0, maxMaxX - backgroundRects[i].origin.x)
                                    }
                                }
                            }
                            forwardBackgroundMaskNode.updateRects(backgroundRects)
                        }
                    } else if let forwardBackgroundMaskNode = strongSelf.forwardBackgroundMaskNode {
                        strongSelf.forwardBackgroundMaskNode = nil
                        forwardBackgroundMaskNode.view.removeFromSuperview()
                    }
                                        
                    let panelsAlpha: CGFloat = item.controllerInteraction.selectionState == nil ? 1.0 : 0.0
                    strongSelf.threadInfoNode?.alpha = panelsAlpha
                    strongSelf.replyInfoNode?.alpha = panelsAlpha
                    strongSelf.viaBotNode?.alpha = panelsAlpha
                    strongSelf.forwardInfoNode?.alpha = panelsAlpha
                    strongSelf.replyBackgroundContent?.alpha = panelsAlpha
                    strongSelf.forwardBackgroundContent?.alpha = panelsAlpha
                    
                    if isFailed {
                        let deliveryFailedNode: ChatMessageDeliveryFailedNode
                        var isAppearing = false
                        if let current = strongSelf.deliveryFailedNode {
                            deliveryFailedNode = current
                        } else {
                            isAppearing = true
                            deliveryFailedNode = ChatMessageDeliveryFailedNode(tapped: {
                                if let strongSelf = weakSelf.value, let item = strongSelf.item {
                                    item.controllerInteraction.requestRedeliveryOfFailedMessages(item.content.firstMessage.id)
                                }
                            })
                            strongSelf.deliveryFailedNode = deliveryFailedNode
                            strongSelf.addSubnode(deliveryFailedNode)
                        }
                        let deliveryFailedSize = deliveryFailedNode.updateLayout(theme: item.presentationData.theme.theme)
                        let deliveryFailedFrame = CGRect(origin: CGPoint(x: imageFrame.maxX + deliveryFailedInset - deliveryFailedSize.width, y: imageFrame.maxY - deliveryFailedSize.height - innerImageInset), size: deliveryFailedSize)
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
                                                            
                    if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                        let actionButtonsNode = actionButtonsSizeAndApply.1(animation)
                        let previousFrame = actionButtonsNode.frame
                        let actionButtonsFrame = CGRect(origin: CGPoint(x: imageFrame.minX, y: imageFrame.maxY - 10.0), size: actionButtonsSizeAndApply.0)
                        actionButtonsNode.frame = actionButtonsFrame
                        if actionButtonsNode !== strongSelf.actionButtonsNode {
                            strongSelf.actionButtonsNode = actionButtonsNode
                            actionButtonsNode.buttonPressed = { button, progress in
                                if let strongSelf = weakSelf.value {
                                    strongSelf.performMessageButtonAction(button: button, progress: progress)
                                }
                            }
                            actionButtonsNode.buttonLongTapped = { button in
                                if let strongSelf = weakSelf.value {
                                    strongSelf.presentMessageButtonContextMenu(button: button)
                                }
                            }
                            strongSelf.addSubnode(actionButtonsNode)
                            
                            if animation.isAnimated {
                                actionButtonsNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        } else {
                            if case let .System(duration, _) = animation {
                                actionButtonsNode.layer.animateFrame(from: previousFrame, to: actionButtonsFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                    } else if let actionButtonsNode = strongSelf.actionButtonsNode {
                        strongSelf.actionButtonsNode = nil
                        if animation.isAnimated {
                            actionButtonsNode.layer.animateAlpha(from: actionButtonsNode.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                actionButtonsNode.removeFromSupernode()
                            })
                        } else {
                            actionButtonsNode.removeFromSupernode()
                        }
                    }
                    
                    if let reactionButtonsSizeAndApply = reactionButtonsSizeAndApply {
                        let reactionButtonsNode = reactionButtonsSizeAndApply.1(animation)
                        var reactionButtonsFrame = CGRect(origin: CGPoint(x: imageFrame.minX, y: dateAndStatusFrame.maxY + 6.0), size: reactionButtonsSizeAndApply.0)
                        if !incoming {
                            reactionButtonsFrame.origin.x = imageFrame.maxX - innerImageInset - reactionButtonsSizeAndApply.0.width
                        }
                        if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                            reactionButtonsFrame.origin.y += 4.0 + actionButtonsSizeAndApply.0.height
                        }
                        if reactionButtonsNode !== strongSelf.reactionButtonsNode {
                            strongSelf.reactionButtonsNode = reactionButtonsNode
                            reactionButtonsNode.reactionSelected = { value, sourceView in
                                guard let strongSelf = weakSelf.value, let item = strongSelf.item else {
                                    return
                                }
                                item.controllerInteraction.updateMessageReaction(item.message, .reaction(value), false, sourceView)
                            }
                            reactionButtonsNode.openReactionPreview = { gesture, sourceNode, value in
                                guard let strongSelf = weakSelf.value, let item = strongSelf.item else {
                                    gesture?.cancel()
                                    return
                                }
                                
                                item.controllerInteraction.openMessageReactionContextMenu(item.message, sourceNode, gesture, value)
                            }
                            reactionButtonsNode.frame = reactionButtonsFrame
                            strongSelf.addSubnode(reactionButtonsNode)
                            if animation.isAnimated {
                                reactionButtonsNode.animateIn(animation: animation)
                            }
                            
                            if let (rect, containerSize) = strongSelf.absoluteRect {
                                var rect = rect
                                rect.origin.y = containerSize.height - rect.maxY + strongSelf.insets.top
                                
                                var reactionButtonsNodeFrame = reactionButtonsFrame
                                reactionButtonsNodeFrame.origin.x += rect.minX
                                reactionButtonsNodeFrame.origin.y += rect.minY
                                
                                reactionButtonsNode.update(rect: rect, within: containerSize, transition: .immediate)
                            }
                        } else {
                            animation.animator.updateFrame(layer: reactionButtonsNode.layer, frame: reactionButtonsFrame, completion: nil)
                            
                            if let (rect, containerSize) = strongSelf.absoluteRect {
                                var rect = rect
                                rect.origin.y = containerSize.height - rect.maxY + strongSelf.insets.top
                                
                                var reactionButtonsNodeFrame = reactionButtonsFrame
                                reactionButtonsNodeFrame.origin.x += rect.minX
                                reactionButtonsNodeFrame.origin.y += rect.minY
                                
                                reactionButtonsNode.update(rect: rect, within: containerSize, transition: animation.transition)
                            }
                        }
                    } else if let reactionButtonsNode = strongSelf.reactionButtonsNode {
                        strongSelf.reactionButtonsNode = nil
                        if animation.isAnimated {
                            reactionButtonsNode.animateOut(animation: animation, completion: { [weak reactionButtonsNode] in
                                reactionButtonsNode?.removeFromSupernode()
                            })
                        } else {
                            reactionButtonsNode.removeFromSupernode()
                        }
                    }
                    
                    if let forwardInfo = item.message.forwardInfo, forwardInfo.flags.contains(.isImported) {
                        strongSelf.dateAndStatusNode.pressed = {
                            guard let strongSelf = weakSelf.value else {
                                return
                            }
                            item.controllerInteraction.displayImportedMessageTooltip(strongSelf.dateAndStatusNode)
                        }
                    } else {
                        strongSelf.dateAndStatusNode.pressed = nil
                    }
                    
                    if let (_, f) = strongSelf.awaitingAppliedReaction {
                        strongSelf.awaitingAppliedReaction = nil
                        
                        f()
                    }
                    
                    strongSelf.updateVisibility()
                }
            }
            
            return (ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets), { animation, _, synchronousLoads in
                finishAsyncLayout(animation, synchronousLoads)
            })
        }
        
        let weakSelf = Weak(self)
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) in
            return continueAsyncLayout(weakSelf, item, params, mergedTop, mergedBottom, dateHeaderAtBottom)
        }
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                if case .doubleTap = gesture {
                    self.containerNode.cancelGesture()
                }
                if let item = self.item, let action = self.gestureRecognized(gesture: gesture, location: location, recognizer: nil) {
                    if case .doubleTap = gesture {
                        self.containerNode.cancelGesture()
                    }
                    switch action {
                    case let .action(f):
                        f.action()
                    case let .optionalAction(f):
                        f()
                    case let .openContextMenu(openContextMenu):
                        if canAddMessageReactions(message: item.message) {
                            item.controllerInteraction.updateMessageReaction(openContextMenu.tapMessage, .default, false, nil)
                        } else {
                            item.controllerInteraction.openMessageContextMenu(openContextMenu.tapMessage, openContextMenu.selectAll, self, openContextMenu.subFrame, nil, nil)
                        }
                    }
                } else if case .tap = gesture {
                    self.item?.controllerInteraction.clickThroughMessage(self.view, location)
                }
            }
        default:
            break
        }
    }
    
    private func gestureRecognized(gesture: TapLongTapOrDoubleTapGesture, location: CGPoint, recognizer: TapLongTapOrDoubleTapGestureRecognizer?) -> InternalBubbleTapAction? {
        switch gesture {
            case .tap:                
                if let viaBotNode = self.viaBotNode, viaBotNode.frame.contains(location) {
                    if let item = self.item {
                        for attribute in item.message.attributes {
                            if let attribute = attribute as? InlineBotMessageAttribute {
                                var botAddressName: String?
                                if let peerId = attribute.peerId, let botPeer = item.message.peers[peerId], let addressName = botPeer.addressName {
                                    botAddressName = addressName
                                } else {
                                    botAddressName = attribute.title
                                }
                                
                                if let botAddressName = botAddressName {
                                    return .optionalAction({
                                        item.controllerInteraction.updateInputState { textInputState in
                                            return ChatTextInputState(inputText: NSAttributedString(string: "@" + botAddressName + " "))
                                        }
                                        item.controllerInteraction.updateInputMode { _ in
                                            return .text
                                        }
                                    })
                                }
                            }
                        }
                    }
                }
                
                if let replyInfoNode = self.replyInfoNode, replyInfoNode.frame.contains(location) {
                    if let item = self.item {
                        for attribute in item.message.attributes {
                            if let attribute = attribute as? ReplyMessageAttribute {
                                return .optionalAction({
                                    item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId, NavigateToMessageParams(timestamp: nil, quote: attribute.isQuote ? attribute.quote.flatMap { quote in NavigateToMessageParams.Quote(string: quote.text, offset: quote.offset) } : nil))
                                })
                            } else if let attribute = attribute as? ReplyStoryAttribute {
                                return .optionalAction({
                                    item.controllerInteraction.navigateToStory(item.message, attribute.storyId)
                                })
                            } else if let attribute = attribute as? QuotedReplyMessageAttribute {
                                return .optionalAction({
                                    item.controllerInteraction.attemptedNavigationToPrivateQuote(attribute.peerId.flatMap { item.message.peers[$0] })
                                })
                            }
                        }
                    }
                }
                
                if let forwardInfoNode = self.forwardInfoNode, forwardInfoNode.frame.contains(location) {
                    if let item = self.item, let forwardInfo = item.message.forwardInfo {
                        let performAction: () -> Void = {
                            if let sourceMessageId = forwardInfo.sourceMessageId {
                                if !item.message.id.peerId.isReplies, let channel = forwardInfo.author as? TelegramChannel, channel.addressName == nil {
                                    if case let .broadcast(info) = channel.info, info.flags.contains(.hasDiscussionGroup) {
                                    } else if case .member = channel.participationStatus {
                                    } else {
                                        item.controllerInteraction.displayMessageTooltip(item.message.id, item.presentationData.strings.Conversation_PrivateChannelTooltip, false, forwardInfoNode, nil)
                                        return
                                    }
                                }
                                item.controllerInteraction.navigateToMessage(item.message.id, sourceMessageId, NavigateToMessageParams(timestamp: nil, quote: nil))
                            } else if let peer = forwardInfo.source ?? forwardInfo.author {
                                item.controllerInteraction.openPeer(EnginePeer(peer), peer is TelegramUser ? .info(nil) : .chat(textInputState: nil, subject: nil, peekData: nil), nil, .default)
                            } else if let _ = forwardInfo.authorSignature {
                                item.controllerInteraction.displayMessageTooltip(item.message.id, item.presentationData.strings.Conversation_ForwardAuthorHiddenTooltip, false, forwardInfoNode, nil)
                            }
                        }
                        
                        if forwardInfoNode.hasAction(at: self.view.convert(location, to: forwardInfoNode.view)) {
                            return .action(InternalBubbleTapAction.Action {})
                        } else {
                            return .optionalAction(performAction)
                        }
                    }
                }
            
                if let item = self.item, self.imageNode.frame.contains(location) {
                    return .optionalAction({
                        let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
                    })
                }
            
                return nil
            case .longTap, .doubleTap, .secondaryTap:
                if let item = self.item, self.imageNode.frame.contains(location) {
                    return .openContextMenu(InternalBubbleTapAction.OpenContextMenu(tapMessage: item.message, selectAll: false, subFrame: self.imageNode.frame))
                }
            case .hold:
                break
        }
        return nil
    }
    
    @objc private func shareButtonPressed() {
        if let item = self.item {
            if case .pinnedMessages = item.associatedData.subject {
                item.controllerInteraction.navigateToMessageStandalone(item.content.firstMessage.id)
                return
            }
            
            if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                for attribute in item.message.attributes {
                    if let _ = attribute as? ReplyThreadMessageAttribute {
                        item.controllerInteraction.openMessageReplies(item.message.id, true, false)
                        return
                    }
                }
            }
            
            if item.content.firstMessage.id.peerId.isReplies {
                item.controllerInteraction.openReplyThreadOriginalMessage(item.content.firstMessage)
            } else if item.content.firstMessage.id.peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
                for attribute in item.content.firstMessage.attributes {
                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                        item.controllerInteraction.navigateToMessage(item.content.firstMessage.id, attribute.messageId, NavigateToMessageParams(timestamp: nil, quote: nil))
                        break
                    }
                }
            } else {
                item.controllerInteraction.openMessageShareMenu(item.message.id)
            }
        }
    }
    
    private func openQuickShare(node: ASDisplayNode, gesture: ContextGesture) {
        if let item = self.item {
            item.controllerInteraction.displayQuickShare(item.message.id, node, gesture)
        }
    }
    
    private var playedSwipeToReplyHaptic = false
    @objc private func swipeToReplyGesture(_ recognizer: ChatSwipeToReplyRecognizer) {
        var offset: CGFloat = 0.0
        var leftOffset: CGFloat = 0.0
        var swipeOffset: CGFloat = 45.0
        if let item = self.item, item.content.effectivelyIncoming(item.context.account.peerId, associatedData: item.associatedData) {
            offset = -24.0
            leftOffset = -10.0
        } else {
            offset = 10.0
            leftOffset = -10.0
            swipeOffset = 60.0
        }
        
        switch recognizer.state {
            case .began:
                self.playedSwipeToReplyHaptic = false
                self.currentSwipeToReplyTranslation = 0.0
                if self.swipeToReplyFeedback == nil {
                    self.swipeToReplyFeedback = HapticFeedback()
                    self.swipeToReplyFeedback?.prepareImpact()
                }
                self.item?.controllerInteraction.cancelInteractiveKeyboardGestures()
            case .changed:
                var translation = recognizer.translation(in: self.view)
                func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                    let bandedOffset = offset - bandingStart
                    if offset < bandingStart {
                        return offset
                    }
                    let range: CGFloat = 100.0
                    let coefficient: CGFloat = 0.4
                    return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
                }
            
                if translation.x < 0.0 {
                    translation.x = max(-180.0, min(0.0, -rubberBandingOffset(offset: abs(translation.x), bandingStart: swipeOffset)))
                } else {
                    if recognizer.allowBothDirections {
                        translation.x = -max(-180.0, min(0.0, -rubberBandingOffset(offset: abs(translation.x), bandingStart: swipeOffset)))
                    } else {
                        translation.x = 0.0
                    }
                }
            
                if let item = self.item, self.swipeToReplyNode == nil {
                    let swipeToReplyNode = ChatMessageSwipeToReplyNode(fillColor: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: item.controllerInteraction.enableFullTranslucency && dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), foregroundColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonForegroundColor, wallpaper: item.presentationData.theme.wallpaper), backgroundNode: item.controllerInteraction.presentationContext.backgroundNode, action: ChatMessageSwipeToReplyNode.Action(self.currentSwipeAction))
                    self.swipeToReplyNode = swipeToReplyNode
                    self.insertSubnode(swipeToReplyNode, at: 0)
                }
            
                self.currentSwipeToReplyTranslation = translation.x
                var bounds = self.bounds
                bounds.origin.x = -translation.x
                self.bounds = bounds

                self.updateAttachedAvatarNodeOffset(offset: translation.x, transition: .immediate)
            
                if let swipeToReplyNode = self.swipeToReplyNode {
                    swipeToReplyNode.bounds = CGRect(origin: .zero, size: CGSize(width: 33.0, height: 33.0))
                    if translation.x < 0.0 {
                        swipeToReplyNode.bounds = CGRect(origin: .zero, size: CGSize(width: 33.0, height: 33.0))
                        swipeToReplyNode.position = CGPoint(x: bounds.size.width + offset + 33.0 * 0.5, y: self.contentSize.height / 2.0)
                    } else {
                        swipeToReplyNode.bounds = CGRect(origin: .zero, size: CGSize(width: 33.0, height: 33.0))
                        swipeToReplyNode.position = CGPoint(x: leftOffset - 33.0 * 0.5, y: self.contentSize.height / 2.0)
                    }
                    
                    if let (rect, containerSize) = self.absoluteRect {
                        let mappedRect = CGRect(origin: CGPoint(x: rect.minX + swipeToReplyNode.frame.minX, y: rect.minY + swipeToReplyNode.frame.minY), size: swipeToReplyNode.frame.size)
                        swipeToReplyNode.updateAbsoluteRect(mappedRect, within: containerSize)
                    }
                    
                    let progress = abs(translation.x) / swipeOffset
                    swipeToReplyNode.updateProgress(progress)
                    
                    if progress > 1.0 - .ulpOfOne && !self.playedSwipeToReplyHaptic {
                        self.playedSwipeToReplyHaptic = true
                        self.swipeToReplyFeedback?.impact(.heavy)
                    }
                }
            case .cancelled, .ended:
                self.swipeToReplyFeedback = nil
                
                let translation = recognizer.translation(in: self.view)
                let gestureRecognized: Bool
                if recognizer.allowBothDirections {
                    gestureRecognized = abs(translation.x) > swipeOffset
                } else {
                    gestureRecognized = translation.x < -swipeOffset
                }
                if case .ended = recognizer.state, gestureRecognized {
                    if let item = self.item {
                        if let currentSwipeAction = currentSwipeAction {
                            switch currentSwipeAction {
                            case .none:
                                break
                            case .reply:
                                item.controllerInteraction.setupReply(item.message.id)
                            }
                        }
                    }
                }
                var bounds = self.bounds
                let previousBounds = bounds
                bounds.origin.x = 0.0
                self.bounds = bounds
                self.layer.animateBounds(from: previousBounds, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)

                self.updateAttachedAvatarNodeOffset(offset: 0.0, transition: .animated(duration: 0.3, curve: .spring))

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
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let shareButtonNode = self.shareButtonNode, shareButtonNode.frame.contains(point) {
            return shareButtonNode.view.hitTest(self.view.convert(point, to: shareButtonNode.view), with: event)
        }
        if let threadInfoNode = self.threadInfoNode, let result = threadInfoNode.hitTest(self.view.convert(point, to: threadInfoNode.view), with: event) {
            return result
        }
        if let reactionButtonsNode = self.reactionButtonsNode {
            if let result = reactionButtonsNode.hitTest(self.view.convert(point, to: reactionButtonsNode.view), with: event) {
                return result
            }
        }
        return super.hitTest(point, with: event)
    }
    
    override public func updateSelectionState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.effectiveTopId == item.message.id {
            return
        }
        
        let incoming = item.content.effectivelyIncoming(item.context.account.peerId, associatedData: item.associatedData)
        var isEmoji = false
        if let item = self.item, item.presentationData.largeEmoji && messageIsEligibleForLargeEmoji(item.message) {
            isEmoji = true
        }

        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
        let panelsAlpha: CGFloat = item.controllerInteraction.selectionState == nil ? 1.0 : 0.0
        if let replyInfoNode = self.replyInfoNode {
            transition.updateAlpha(node: replyInfoNode, alpha: panelsAlpha)
        }
        if let viaBotNode = self.viaBotNode {
            transition.updateAlpha(node: viaBotNode, alpha: panelsAlpha)
        }
        if let forwardInfoNode = self.forwardInfoNode {
            transition.updateAlpha(node: forwardInfoNode, alpha: panelsAlpha)
        }
        if let replyBackgroundContent = self.replyBackgroundContent {
            transition.updateAlpha(node: replyBackgroundContent, alpha: panelsAlpha)
        }
        if let forwardBackgroundContent = self.forwardBackgroundContent {
            transition.updateAlpha(node: forwardBackgroundContent, alpha: panelsAlpha)
        }
        
        if let selectionState = item.controllerInteraction.selectionState {
            let selected = selectionState.selectedIds.contains(item.message.id)

            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                selectionNode.frame = selectionFrame
                selectionNode.updateLayout(size: selectionFrame.size, leftInset: self.safeInsets.left)
                selectionNode.updateSelected(selected, animated: animated)
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(wallpaper: item.presentationData.theme.wallpaper, theme: item.presentationData.theme.theme, toggle: { [weak self] value in
                    if let strongSelf = self, let item = strongSelf.item {
                        item.controllerInteraction.toggleMessagesSelection([item.message.id], value)
                    }
                })
                let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                selectionNode.frame = selectionFrame
                selectionNode.updateLayout(size: selectionFrame.size, leftInset: self.safeInsets.left)
                self.addSubnode(selectionNode)
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
            
            if let replyInfoNode = self.replyInfoNode, isEmoji && !incoming {
                let alpha: CGFloat = 0.0
                let previousAlpha = replyInfoNode.alpha
                replyInfoNode.alpha = alpha
                self.replyBackgroundContent?.alpha = alpha
                if animated {
                    replyInfoNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: 0.3)
                    self.replyBackgroundContent?.layer.animateAlpha(from: previousAlpha, to: alpha, duration: 0.3)
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
            
            if let replyInfoNode = self.replyInfoNode, isEmoji && !incoming {
                let alpha: CGFloat = 1.0
                let previousAlpha = replyInfoNode.alpha
                replyInfoNode.alpha = alpha
                self.replyBackgroundContent?.alpha = alpha
                if animated {
                    replyInfoNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: 0.3)
                    self.replyBackgroundContent?.layer.animateAlpha(from: previousAlpha, to: alpha, duration: 0.3)
                }
            }
        }
    }
    
    override public func updateHighlightedState(animated: Bool) {
        super.updateHighlightedState(animated: animated)
        
        if let item = self.item {
            var highlighted = false
            if let highlightedState = item.controllerInteraction.highlightedState {
                if highlightedState.messageStableId == item.message.stableId {
                    highlighted = true
                }
            }
            
            if self.highlightedState != highlighted {
                self.highlightedState = highlighted
                
                if highlighted {
                    self.imageNode.setOverlayColor(item.presentationData.theme.theme.chat.message.mediaHighlightOverlayColor, animated: false)
                } else {
                    self.imageNode.setOverlayColor(nil, animated: animated)
                }
            }
        }
    }

    override public func cancelInsertionAnimations() {
        self.layer.removeAllAnimations()
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        super.animateInsertion(currentTimestamp, duration: duration, options: options)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func getMessageContextSourceNode(stableId: UInt32?) -> ContextExtractedContentContainingNode? {
        return self.contextSourceNode
    }
    
    override public func addAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        self.contextSourceNode.contentNode.addSubnode(accessoryItemNode)
    }
    
    public final class AnimationTransitionTextInput {
        public let backgroundView: UIView
        public let contentView: UIView
        public let sourceRect: CGRect
        public let scrollOffset: CGFloat

        public init(backgroundView: UIView, contentView: UIView, sourceRect: CGRect, scrollOffset: CGFloat) {
            self.backgroundView = backgroundView
            self.contentView = contentView
            self.sourceRect = sourceRect
            self.scrollOffset = scrollOffset
        }
    }

    public func animateContentFromTextInputField(textInput: AnimationTransitionTextInput, transition: CombinedTransition) {
        guard let _ = self.item else {
            return
        }

        let localSourceContentFrame = self.contextSourceNode.contentNode.view.convert(textInput.contentView.frame.offsetBy(dx: self.contextSourceNode.contentRect.minX, dy: self.contextSourceNode.contentRect.minY), to: self.contextSourceNode.contentNode.view)
        textInput.contentView.frame = localSourceContentFrame

        self.contextSourceNode.contentNode.view.addSubview(textInput.contentView)

        let sourceCenter = CGPoint(
            x: localSourceContentFrame.minX + 11.2,
            y: localSourceContentFrame.midY - 1.8
        )
        let localSourceCenter = CGPoint(
            x: sourceCenter.x - localSourceContentFrame.minX,
            y: sourceCenter.y - localSourceContentFrame.minY
        )
        let localSourceOffset = CGPoint(
            x: localSourceCenter.x - localSourceContentFrame.width / 2.0,
            y: localSourceCenter.y - localSourceContentFrame.height / 2.0
        )

        let sourceScale: CGFloat = 28.0 / self.imageNode.frame.height

        let offset = CGPoint(
            x: sourceCenter.x - self.imageNode.frame.midX,
            y: sourceCenter.y - self.imageNode.frame.midY
        )

        transition.animatePositionAdditive(layer: self.imageNode.layer, offset: offset)
        transition.horizontal.animateTransformScale(node: self.imageNode, from: sourceScale)
        transition.animatePositionAdditive(layer: self.placeholderNode.layer, offset: offset)
        transition.horizontal.animateTransformScale(node: self.placeholderNode, from: sourceScale)

        let inverseScale = 1.0 / sourceScale

        transition.animatePositionAdditive(layer: textInput.contentView.layer, offset: CGPoint(), to: CGPoint(
            x: -offset.x - localSourceOffset.x * (inverseScale - 1.0),
            y: -offset.y - localSourceOffset.y * (inverseScale - 1.0)
        ), removeOnCompletion: false)
        transition.horizontal.updateTransformScale(layer: textInput.contentView.layer, scale: 1.0 / sourceScale)

        textInput.contentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
            textInput.contentView.removeFromSuperview()
        })

        self.imageNode.layer.animateAlpha(from: 0.0, to: self.imageNode.alpha, duration: 0.1)
        self.placeholderNode.layer.animateAlpha(from: 0.0, to: self.placeholderNode.alpha, duration: 0.1)

        self.dateAndStatusNode.layer.animateAlpha(from: 0.0, to: self.dateAndStatusNode.alpha, duration: 0.15, delay: 0.16)
    }
    
    public final class AnimationTransitionSticker {
        public let imageNode: TransformImageNode?
        public let animationNode: ASDisplayNode?
        public let placeholderNode: ASDisplayNode?
        public let imageLayer: CALayer?
        public let relativeSourceRect: CGRect
        
        var sourceFrame: CGRect {
            if let imageNode = self.imageNode {
                return imageNode.frame
            } else if let imageLayer = self.imageLayer {
                return imageLayer.bounds
            } else {
                return CGRect(origin: CGPoint(), size: relativeSourceRect.size)
            }
        }
        
        var sourceLayer: CALayer? {
            if let imageNode = self.imageNode {
                return imageNode.layer
            } else if let imageLayer = self.imageLayer {
                return imageLayer
            } else {
                return nil
            }
        }
        
        func snapshotContentTree() -> UIView? {
            if let animationNode = self.animationNode {
                return animationNode.view.snapshotContentTree()
            } else if let imageNode = self.imageNode {
                return imageNode.view.snapshotContentTree()
            } else if let sourceLayer = self.imageLayer {
                return sourceLayer.snapshotContentTreeAsView()
            } else {
                return nil
            }
        }
        
        public init(imageNode: TransformImageNode?, animationNode: ASDisplayNode?, placeholderNode: ASDisplayNode?, imageLayer: CALayer?, relativeSourceRect: CGRect) {
            self.imageNode = imageNode
            self.animationNode = animationNode
            self.placeholderNode = placeholderNode
            self.imageLayer = imageLayer
            self.relativeSourceRect = relativeSourceRect
        }
    }

    public func animateContentFromStickerGridItem(stickerSource: AnimationTransitionSticker, transition: CombinedTransition) {
        guard let _ = self.item else {
            return
        }

        let localSourceContentFrame = CGRect(
            origin: CGPoint(
                x: self.imageNode.frame.minX + self.imageNode.frame.size.width / 2.0 - stickerSource.sourceFrame.size.width / 2.0,
                y: self.imageNode.frame.minY + self.imageNode.frame.size.height / 2.0 - stickerSource.sourceFrame.size.height / 2.0
            ),
            size: stickerSource.sourceFrame.size
        )

        var snapshotView: UIView?
        if let animationNode = stickerSource.animationNode {
            snapshotView = animationNode.view.snapshotContentTree()
        } else {
            snapshotView = stickerSource.snapshotContentTree()
        }
        snapshotView?.frame = localSourceContentFrame

        if let snapshotView = snapshotView {
            self.contextSourceNode.contentNode.view.addSubview(snapshotView)
        }

        let sourceCenter = CGPoint(
            x: localSourceContentFrame.midX,
            y: localSourceContentFrame.midY
        )
        let localSourceCenter = CGPoint(
            x: sourceCenter.x - localSourceContentFrame.minX,
            y: sourceCenter.y - localSourceContentFrame.minY
        )
        let localSourceOffset = CGPoint(
            x: localSourceCenter.x - localSourceContentFrame.width / 2.0,
            y: localSourceCenter.y - localSourceContentFrame.height / 2.0
        )

        let sourceScale: CGFloat = stickerSource.sourceFrame.height / self.imageNode.frame.height

        let offset = CGPoint(
            x: sourceCenter.x - self.imageNode.frame.midX,
            y: sourceCenter.y - self.imageNode.frame.midY
        )

        transition.animatePositionAdditive(layer: self.imageNode.layer, offset: offset)
        transition.horizontal.animateTransformScale(node: self.imageNode, from: sourceScale)
        transition.animatePositionAdditive(layer: self.placeholderNode.layer, offset: offset)
        transition.horizontal.animateTransformScale(node: self.placeholderNode, from: sourceScale)

        let inverseScale = 1.0 / sourceScale

        if let snapshotView = snapshotView {
            transition.animatePositionAdditive(layer: snapshotView.layer, offset: CGPoint(), to: CGPoint(
                x: -offset.x - localSourceOffset.x * (inverseScale - 1.0),
                y: -offset.y - localSourceOffset.y * (inverseScale - 1.0)
            ), removeOnCompletion: false)
            transition.horizontal.updateTransformScale(layer: snapshotView.layer, scale: 1.0 / sourceScale)

            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.06, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })

            self.imageNode.layer.animateAlpha(from: 0.0, to: self.imageNode.alpha, duration: 0.03)
            self.placeholderNode.layer.animateAlpha(from: 0.0, to: self.placeholderNode.alpha, duration: 0.03)
        }

        self.dateAndStatusNode.layer.animateAlpha(from: 0.0, to: self.dateAndStatusNode.alpha, duration: 0.15, delay: 0.16)

        if let animationNode = stickerSource.animationNode {
            animationNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            animationNode.layer.animateAlpha(from: 0.0, to: animationNode.alpha, duration: 0.4)
        }

        if let sourceLayer = stickerSource.sourceLayer {
            sourceLayer.animateScale(from: 0.1, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            sourceLayer.animateAlpha(from: 0.0, to: CGFloat(sourceLayer.opacity), duration: 0.4)
        }

        if let placeholderNode = stickerSource.placeholderNode {
            placeholderNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            placeholderNode.layer.animateAlpha(from: 0.0, to: placeholderNode.alpha, duration: 0.4)
        }
    }
    
    public final class AnimationTransitionReplyPanel {
        public let titleNode: ASDisplayNode
        public let textNode: ASDisplayNode
        public let lineNode: ASDisplayNode
        public let imageNode: ASDisplayNode
        public let relativeSourceRect: CGRect
        public let relativeTargetRect: CGRect

        public init(titleNode: ASDisplayNode, textNode: ASDisplayNode, lineNode: ASDisplayNode, imageNode: ASDisplayNode, relativeSourceRect: CGRect, relativeTargetRect: CGRect) {
            self.titleNode = titleNode
            self.textNode = textNode
            self.lineNode = lineNode
            self.imageNode = imageNode
            self.relativeSourceRect = relativeSourceRect
            self.relativeTargetRect = relativeTargetRect
        }
    }

    public func animateReplyPanel(sourceReplyPanel: AnimationTransitionReplyPanel, transition: CombinedTransition) {
        if let replyInfoNode = self.replyInfoNode {
            let localRect = self.contextSourceNode.contentNode.view.convert(sourceReplyPanel.relativeSourceRect, to: replyInfoNode.view)
            let mappedPanel = ChatMessageReplyInfoNode.TransitionReplyPanel(
                titleNode: sourceReplyPanel.titleNode,
                textNode: sourceReplyPanel.textNode,
                lineNode: sourceReplyPanel.lineNode,
                imageNode: sourceReplyPanel.imageNode,
                relativeSourceRect: sourceReplyPanel.relativeSourceRect,
                relativeTargetRect: sourceReplyPanel.relativeTargetRect
            )

            let offset = replyInfoNode.animateFromInputPanel(sourceReplyPanel: mappedPanel, localRect: localRect, transition: transition)
            if let replyBackgroundContent = self.replyBackgroundContent {
                transition.animatePositionAdditive(layer: replyBackgroundContent.layer, offset: offset)
                replyBackgroundContent.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
            }
            if let forwardBackgroundContent = self.forwardBackgroundContent {
                transition.animatePositionAdditive(layer: forwardBackgroundContent.layer, offset: offset)
                forwardBackgroundContent.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
            }
        }
    }
    
    public func animateFromLoadingPlaceholder(delay: Double, transition: ContainedViewLayoutTransition) {
        guard let item = self.item else {
            return
        }
        
        let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
        transition.animatePositionAdditive(node: self, offset: CGPoint(x: incoming ? 30.0 : -30.0, y: -30.0), delay: delay)
        transition.animateTransformScale(node: self, from: CGPoint(x: 0.85, y: 0.85), delay: delay)
    }
    
    override public func openMessageContextMenu() {
        guard let item = self.item else {
            return
        }
        item.controllerInteraction.openMessageContextMenu(item.message, false, self, self.imageNode.frame, nil, nil)
    }
    
    override public func targetForStoryTransition(id: StoryId) -> UIView? {
        guard let item = self.item else {
            return nil
        }
        for attribute in item.message.attributes {
            if let attribute = attribute as? ReplyStoryAttribute {
                if attribute.storyId == id {
                    if let replyInfoNode = self.replyInfoNode {
                        return replyInfoNode.mediaTransitionView()
                    }
                }
            }
        }
        return nil
    }
    
    override public func targetReactionView(value: MessageReaction.Reaction) -> UIView? {
        if let result = self.reactionButtonsNode?.reactionTargetView(value: value) {
            return result
        }
        if !self.dateAndStatusNode.isHidden {
            return self.dateAndStatusNode.reactionView(value: value)
        }
        return nil
    }
    
    override public func contentFrame() -> CGRect {
        return self.imageNode.frame
    }
    
    override public func makeContentSnapshot() -> (UIImage, CGRect)? {
        UIGraphicsBeginImageContextWithOptions(self.imageNode.view.bounds.size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()!
        
        context.translateBy(x: -self.imageNode.frame.minX, y: -self.imageNode.frame.minY)
        self.contextSourceNode.contentNode.view.layer.render(in: context)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let image else {
            return nil
        }
        
        return (image, self.imageNode.frame)
    }
    
    private func updateVisibility() {
        guard let item = self.item else {
            return
        }
        
        var isPlaying = true
        if case .visible = self.visibility {
        } else {
            isPlaying = false
        }
        if !item.controllerInteraction.canReadHistory {
            isPlaying = false
        }
        if self.forceStopAnimations {
            isPlaying = false
        }
        
        if !isPlaying {
            self.removeEffectAnimations()
        }
        
        if isPlaying {
            var alreadySeen = true
            if item.message.flags.contains(.Incoming) {
                if let unreadRange = item.controllerInteraction.unreadMessageRange[UnreadMessageRangeKey(peerId: item.message.id.peerId, namespace: item.message.id.namespace)] {
                    if unreadRange.contains(item.message.id.id) {
                        if !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
                            alreadySeen = false
                        }
                    }
                }
            } else {
                if self.didChangeFromPendingToSent {
                    if !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
                        alreadySeen = false
                    }
                }
            }
            
            if !alreadySeen {
                item.controllerInteraction.seenOneTimeAnimatedMedia.insert(item.message.id)
                
                self.playMessageEffect(force: false)
            }
        }
    }
    
    override public func updateStickerSettings(forceStopAnimations: Bool) {
        self.forceStopAnimations = forceStopAnimations
        self.updateVisibility()
    }
    
    override public func messageEffectTargetView() -> UIView? {
        if let result = self.dateAndStatusNode.messageEffectTargetView() {
            return result
        }
        
        return nil
    }
}
