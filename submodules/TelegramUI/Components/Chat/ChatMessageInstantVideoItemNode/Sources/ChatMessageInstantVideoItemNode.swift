import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import AccountContext
import LocalizedPeerData
import ContextUI
import Markdown
import ChatControllerInteraction
import ChatMessageForwardInfoNode
import ChatMessageDateAndStatusNode
import ChatMessageItemCommon
import ChatMessageBubbleContentNode
import ChatMessageReplyInfoNode
import ChatMessageInteractiveInstantVideoNode
import ChatMessageItem
import ChatMessageItemView
import ChatMessageSwipeToReplyNode
import ChatMessageSelectionNode
import ChatMessageDeliveryFailedNode
import ChatMessageShareButton
import ChatMessageActionButtonsNode
import ChatSwipeToReplyRecognizer
import ChatMessageReactionsFooterContentNode

private let nameFont = Font.medium(14.0)

private let inlineBotPrefixFont = Font.regular(14.0)
private let inlineBotNameFont = nameFont

public class ChatMessageInstantVideoItemNode: ChatMessageItemView, ASGestureRecognizerDelegate {
    public let contextSourceNode: ContextExtractedContentContainingNode
    public let containerNode: ContextControllerSourceNode
    public let interactiveVideoNode: ChatMessageInteractiveInstantVideoNode
    
    public var selectionNode: ChatMessageSelectionNode?
    public var deliveryFailedNode: ChatMessageDeliveryFailedNode?
    public var shareButtonNode: ChatMessageShareButton?
    
    public var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    public var swipeToReplyFeedback: HapticFeedback?
    
    public var appliedParams: ListViewItemLayoutParams?
    public var appliedItem: ChatMessageItem?
    public var appliedForwardInfo: (Peer?, String?)?
    public var appliedHasAvatar = false
    public var appliedCurrentlyPlaying: Bool?
    public var appliedAutomaticDownload = false
    public var avatarOffset: CGFloat?
    
    public var animatingHeight: Bool {
        return self.apparentHeightTransition != nil
    }

    public var viaBotNode: TextNode?
    public var replyInfoNode: ChatMessageReplyInfoNode?
    public var replyBackgroundNode: NavigationBackgroundNode?
    public var forwardInfoNode: ChatMessageForwardInfoNode?
    
    public var actionButtonsNode: ChatMessageActionButtonsNode?
    public var reactionButtonsNode: ChatMessageReactionButtonsNode?
    
    public let messageAccessibilityArea: AccessibilityAreaNode
    
    public var currentSwipeToReplyTranslation: CGFloat = 0.0
    
    public var recognizer: TapLongTapOrDoubleTapGestureRecognizer?
    
    private var replyRecognizer: ChatSwipeToReplyRecognizer?
    public var currentSwipeAction: ChatControllerInteractionSwipeAction?
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = oldValue != .none
            let isVisible = self.visibility != .none
            
            if wasVisible != isVisible {
                self.interactiveVideoNode.visibility = isVisible
                self.replyInfoNode?.visibility = isVisible
            }
        }
    }
    
    fileprivate var wasPlaying = false
    
    required public init(rotated: Bool) {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.interactiveVideoNode = ChatMessageInteractiveInstantVideoNode()
        self.messageAccessibilityArea = AccessibilityAreaNode()
        
        super.init(rotated: rotated)
        
        self.interactiveVideoNode.shouldOpen = { [weak self] in
            if let strongSelf = self {
                if let item = strongSelf.item, (item.message.id.namespace == Namespaces.Message.Local || item.message.id.namespace == Namespaces.Message.ScheduledLocal || item.message.id.namespace == Namespaces.Message.QuickReplyLocal) {
                    return false
                }
                return !strongSelf.animatingHeight
            } else {
                return false
            }
        }
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self else {
                return false
            }
            if !strongSelf.interactiveVideoNode.frame.contains(location) {
                return false
            }
            if (strongSelf.appliedCurrentlyPlaying ?? false) && !strongSelf.interactiveVideoNode.isPlaying {
                return strongSelf.interactiveVideoNode.frame.insetBy(dx: 0.15 * strongSelf.interactiveVideoNode.frame.width, dy: 0.15 * strongSelf.interactiveVideoNode.frame.height).contains(location)
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
                    strongSelf.recognizer?.cancel()
                    item.controllerInteraction.openMessageContextMenu(openContextMenu.tapMessage, openContextMenu.selectAll, strongSelf, openContextMenu.subFrame, gesture, nil)
                    if (strongSelf.appliedCurrentlyPlaying ?? false) && strongSelf.interactiveVideoNode.isPlaying {
                        strongSelf.wasPlaying = true
                        strongSelf.interactiveVideoNode.pause()
                    }
                }
            }
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] extracted, _ in
            guard let strongSelf = self, let _ = strongSelf.item else {
                return
            }
            if !extracted && strongSelf.wasPlaying {
                strongSelf.wasPlaying = false
                strongSelf.interactiveVideoNode.play()
            }
        }
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        self.contextSourceNode.contentNode.addSubnode(self.interactiveVideoNode)
        self.addSubnode(self.messageAccessibilityArea)
        
        self.messageAccessibilityArea.activate = { [weak self] in
            guard let strongSelf = self, let _ = strongSelf.accessibilityData else {
                return false
            }
            
            return strongSelf.interactiveVideoNode.accessibilityActivate()
        }
        
        self.messageAccessibilityArea.focused = { [weak self] in
            self?.accessibilityElementDidBecomeFocused()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        self.recognizer = recognizer
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let shareButtonNode = strongSelf.shareButtonNode, shareButtonNode.frame.contains(point) {
                    return .fail
                } else if let forwardInfoNode = strongSelf.forwardInfoNode, forwardInfoNode.frame.contains(point) {
                    if forwardInfoNode.hasAction(at: strongSelf.view.convert(point, to: forwardInfoNode.view)) {
                        return .fail
                    }
                }
                
                if let reactionButtonsNode = strongSelf.reactionButtonsNode {
                    if let _ = reactionButtonsNode.hitTest(strongSelf.view.convert(point, to: reactionButtonsNode.view), with: nil) {
                        return .fail
                    }
                }
            }
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(recognizer)
        
        let replyRecognizer = ChatSwipeToReplyRecognizer(target: self, action: #selector(self.swipeToReplyGesture(_:)))
        replyRecognizer.shouldBegin = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                if strongSelf.selectionNode != nil {
                    return false
                }
                if (strongSelf.appliedCurrentlyPlaying ?? false) && !strongSelf.interactiveVideoNode.isPlaying {
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
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
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
                        item.controllerInteraction.openMessageContextMenu(item.message, false, self, self.interactiveVideoNode.frame, nil, nil)
                    }
            }
        }
    }
    
    override public func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: ChatMessageHeaderSpec) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) {
        let layoutConstants = self.layoutConstants
        
        let makeVideoLayout = self.interactiveVideoNode.asyncLayout()
        
        let viaBotLayout = TextNode.asyncLayout(self.viaBotNode)
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentReplyBackgroundNode = self.replyBackgroundNode
        let currentShareButtonNode = self.shareButtonNode
        
        let makeForwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        
        let actionButtonsLayout = ChatMessageActionButtonsNode.asyncLayout(self.actionButtonsNode)
        let reactionButtonsLayout = ChatMessageReactionButtonsNode.asyncLayout(self.reactionButtonsNode)
        
        let currentItem = self.appliedItem
        let currentForwardInfo = self.appliedForwardInfo
        let currentPlaying = self.appliedCurrentlyPlaying
        
        func continueAsyncLayout(_ weakSelf: Weak<ChatMessageInstantVideoItemNode>, _ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: ChatMessageHeaderSpec) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) {
            let accessibilityData = ChatMessageAccessibilityData(item: item, isSelected: nil)
            
            let layoutConstants = chatMessageItemLayoutConstants(layoutConstants, params: params, presentationData: item.presentationData)
            let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            
            let avatarInset: CGFloat
            var hasAvatar = false
            
            let messagePeerId = item.chatLocation.peerId ?? item.content.firstMessage.id.peerId
            
            do {
                if messagePeerId != item.context.account.peerId {
                    if messagePeerId.isGroupOrChannel && item.message.author != nil {
                        var isBroadcastChannel = false
                        if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                            isBroadcastChannel = true
                        }
                        
                        if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.isChannelPost, replyThreadMessage.effectiveTopId == item.message.id {
                            isBroadcastChannel = true
                        }
                        
                        if !isBroadcastChannel {
                            hasAvatar = true
                        } else if case .customChatContents = item.chatLocation {
                            hasAvatar = false
                        }
                    }
                } else if incoming {
                    hasAvatar = true
                }
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
            }
            else if item.message.id.peerId == item.context.account.peerId {
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
                    needsShareButton = false
                }
            }
            
            if let subject = item.associatedData.subject, case .messageOptions = subject {
                needsShareButton = false
            }
            
            var layoutInsets = layoutConstants.instantVideo.insets
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
            
            var isPlaying = false
            let normalDisplaySize = layoutConstants.instantVideo.dimensions
            var displaySize = normalDisplaySize
            let maximumDisplaySize = CGSize(width: min(404, params.width - 20.0), height: min(404, params.width - 20.0))
            var effectiveAvatarInset = avatarInset
            if item.associatedData.currentlyPlayingMessageId == item.message.index {
                isPlaying = true
                displaySize = maximumDisplaySize
                effectiveAvatarInset = 0.0
            }
            
            var automaticDownload = true
            for media in item.message.media {
                if let file = media as? TelegramMediaFile {
                    automaticDownload = shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, authorPeerId: item.message.author?.id, contactsPeerIds: item.associatedData.contactsPeerIds, media: file)
                }
            }
            
            var isReplyThread = false
            if case .replyThread = item.chatLocation {
                isReplyThread = true
            }
            
            let (videoLayout, videoApply) = makeVideoLayout(ChatMessageBubbleContentItem(context: item.context, controllerInteraction: item.controllerInteraction, message: item.message, topMessage: item.content.firstMessage, content: item.content, read: item.read, chatLocation: item.chatLocation, presentationData: item.presentationData, associatedData: item.associatedData, attributes: item.content.firstMessageAttributes, isItemPinned: item.message.tags.contains(.pinned) && !isReplyThread, isItemEdited: false), params.width - params.leftInset - params.rightInset - avatarInset, displaySize, maximumDisplaySize, isPlaying ? 1.0 : 0.0, .free, automaticDownload, 0.0)
            
            let videoFrame = CGRect(origin: CGPoint(x: (incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + effectiveAvatarInset + layoutConstants.bubble.contentInsets.left) : (params.width - params.rightInset - videoLayout.contentSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - deliveryFailedInset)), y: 0.0), size: videoLayout.contentSize)
            
            var viaBotApply: (TextNodeLayout, () -> TextNode)?
            var replyInfoApply: (CGSize, (CGSize, Bool, ListViewItemUpdateAnimation) -> ChatMessageReplyInfoNode)?
            var updatedReplyBackgroundNode: NavigationBackgroundNode?
            var replyMarkup: ReplyMarkupMessageAttribute?
            
            let availableWidth = max(60.0, params.width - params.leftInset - params.rightInset - normalDisplaySize.width - 20.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left)
            
            var ignoreForward = false
            var ignoreSource = false
            
            if let forwardInfo = item.message.forwardInfo {
                if !item.message.id.peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? SourceReferenceMessageAttribute {
                            if attribute.messageId.peerId == forwardInfo.author?.id {
                                ignoreForward = true
                            } else {
                                ignoreSource = true
                            }
                            break
                        }
                    }
                } else {
                    ignoreForward = true
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
                        
                        ignoreForward = true
                    }
                }
                
                if !ignoreSource, !item.message.id.peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
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
                } else if let _ = attribute as? InlineBotMessageAttribute {
                } else if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
                    replyMarkup = attribute
                }
            }
            
            if replyMessage != nil || replyForward != nil || replyStory != nil {
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
                    constrainedSize: CGSize(width: max(0, availableWidth), height: CGFloat.greatestFiniteMagnitude),
                    animationCache: item.controllerInteraction.presentationContext.animationCache,
                    animationRenderer: item.controllerInteraction.presentationContext.animationRenderer,
                    associatedData: item.associatedData
                ))
            }
                        
            var updatedShareButtonNode: ChatMessageShareButton?
            if needsShareButton {
                if currentShareButtonNode != nil {
                    updatedShareButtonNode = currentShareButtonNode
                } else {
                    let buttonNode = ChatMessageShareButton()
                    updatedShareButtonNode = buttonNode
                }
            }
            
            let availableContentWidth = params.width - params.leftInset - params.rightInset - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left
            
            var forwardSource: Peer?
            var forwardAuthorSignature: String?
            
            var forwardInfoSizeApply: (CGSize, (CGFloat) -> ChatMessageForwardInfoNode)?
            
            if !ignoreForward, let forwardInfo = item.message.forwardInfo {
                let forwardPsaType = forwardInfo.psaType
                
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
                let availableWidth = max(60.0, availableContentWidth - normalDisplaySize.width + 6.0)
                forwardInfoSizeApply = makeForwardInfoLayout(item.context, item.presentationData, item.presentationData.strings, .standalone, forwardSource, forwardAuthorSignature, forwardPsaType, nil, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
            }
            
            if replyInfoApply != nil || viaBotApply != nil || forwardInfoSizeApply != nil {
                if let currentReplyBackgroundNode = currentReplyBackgroundNode {
                    updatedReplyBackgroundNode = currentReplyBackgroundNode
                } else {
                    updatedReplyBackgroundNode = NavigationBackgroundNode(color: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: item.controllerInteraction.enableFullTranslucency && dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper))
                }
                
                updatedReplyBackgroundNode?.updateColor(color: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: item.controllerInteraction.enableFullTranslucency && dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), transition: .immediate)
            }
            
            var maxContentWidth = normalDisplaySize.width
            var actionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animation: ListViewItemUpdateAnimation) -> ChatMessageActionButtonsNode))?
            if let replyMarkup = replyMarkup {
                let (minWidth, buttonsLayout) = actionButtonsLayout(item.context, item.presentationData.theme, item.presentationData.chatBubbleCorners, item.presentationData.strings, item.controllerInteraction.presentationContext.backgroundNode, replyMarkup, [:], item.message, maxContentWidth)
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
                let totalInset = params.leftInset + layoutConstants.bubble.edgeInset * 2.0 + avatarInset + layoutConstants.bubble.contentInsets.left + params.rightInset + layoutConstants.bubble.contentInsets.right
                
                let maxReactionsWidth = params.width - totalInset - 8.0
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
            
            var layoutSize = CGSize(width: params.width, height: videoLayout.contentSize.height)
            if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                layoutSize.height += actionButtonsSizeAndApply.0.height
            }
            if let reactionButtonsSizeAndApply = reactionButtonsSizeAndApply {
                layoutSize.height += 6.0 + reactionButtonsSizeAndApply.0.height
            }
            
            func finishAsyncLayout(_ animation: ListViewItemUpdateAnimation, _ synchronousLoads: Bool) {
                if let strongSelf = weakSelf.value {
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.messageAccessibilityArea.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    
                    strongSelf.appliedParams = params
                    strongSelf.appliedItem = item
                    strongSelf.appliedHasAvatar = hasAvatar
                    strongSelf.appliedForwardInfo = (forwardSource, forwardAuthorSignature)
                    strongSelf.appliedCurrentlyPlaying = isPlaying
                    strongSelf.appliedAutomaticDownload = automaticDownload
                    
                    strongSelf.replyRecognizer?.allowBothDirections = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
                    strongSelf.view.disablesInteractiveTransitionGestureRecognizer = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
                    
                    strongSelf.updateAccessibilityData(accessibilityData)
                                        
                    let videoLayoutData: ChatMessageInstantVideoItemLayoutData
                    if incoming {
                        videoLayoutData = .constrained(left: 0.0, right: max(0.0, availableContentWidth - videoFrame.width))
                    } else {
                        videoLayoutData = .constrained(left: max(0.0, availableContentWidth - videoFrame.width), right: 0.0)
                    }
                    
                    let animating = (currentItem != nil && currentPlaying != isPlaying) || strongSelf.animatingHeight
                    if !animating {
                        strongSelf.interactiveVideoNode.frame = videoFrame
                        videoApply(videoLayoutData, animation)
                    }
                    
                    if currentPlaying != isPlaying {
                        if isPlaying {
                            strongSelf.avatarOffset = -100.0
                        } else {
                            strongSelf.avatarOffset = nil
                        }
                        strongSelf.updateSelectionState(animated: true)
                        strongSelf.updateAttachedAvatarNodeOffset(offset: strongSelf.avatarOffset ?? 0.0, transition: .animated(duration: 0.3, curve: .easeInOut))
                    }
                    
                    strongSelf.interactiveVideoNode.view.disablesInteractiveTransitionGestureRecognizer = isPlaying
                    
                    strongSelf.contextSourceNode.contentRect = videoFrame
                    strongSelf.containerNode.targetNodeForActivationProgressContentRect = strongSelf.contextSourceNode.contentRect
                    
                    if !animating {
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
                            }
                            let buttonSize = updatedShareButtonNode.update(presentationData: item.presentationData, controllerInteraction: item.controllerInteraction, chatLocation: item.chatLocation, subject: item.associatedData.subject, message: item.message, account: item.context.account)
                            updatedShareButtonNode.frame = CGRect(origin: CGPoint(x: min(params.width - buttonSize.width - 8.0, videoFrame.maxX - 7.0), y: videoFrame.maxY - 24.0 - buttonSize.height), size: buttonSize)
                        } else if let shareButtonNode = strongSelf.shareButtonNode {
                            shareButtonNode.removeFromSupernode()
                            strongSelf.shareButtonNode = nil
                        }
                        
                        if let updatedReplyBackgroundNode = updatedReplyBackgroundNode {
                            if strongSelf.replyBackgroundNode == nil {
                                strongSelf.replyBackgroundNode = updatedReplyBackgroundNode
                                strongSelf.contextSourceNode.contentNode.addSubnode(updatedReplyBackgroundNode)
                            }
                        } else if let replyBackgroundNode = strongSelf.replyBackgroundNode {
                            replyBackgroundNode.removeFromSupernode()
                            strongSelf.replyBackgroundNode = nil
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
                        
                        if let (viaBotLayout, viaBotApply) = viaBotApply, forwardInfoSizeApply == nil {
                            let viaBotNode = viaBotApply()
                            if strongSelf.viaBotNode == nil {
                                strongSelf.viaBotNode = viaBotNode
                                strongSelf.contextSourceNode.contentNode.addSubnode(viaBotNode)
                            }
                            let viaBotFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 11.0) : (params.width - params.rightInset - messageInfoSize.width - layoutConstants.bubble.edgeInset - 9.0)), y: 8.0), size: viaBotLayout.size)
                            viaBotNode.frame = viaBotFrame
                            
                            messageInfoSize = CGSize(width: messageInfoSize.width, height: viaBotLayout.size.height)
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
                            let forwardInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 12.0) : (params.width - params.rightInset - messageInfoSize.width - layoutConstants.bubble.edgeInset - 8.0)), y: 8.0 + messageInfoSize.height), size: forwardInfoSize)
                            forwardInfoNode.frame = forwardInfoFrame
                            
                            messageInfoSize = CGSize(width: messageInfoSize.width, height: messageInfoSize.height + forwardInfoSize.height - 1.0)
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
                        
                        var replyBackgroundFrame: CGRect?
                        if let (replyInfoSize, replyInfoApply) = replyInfoApply {
                            let replyInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 11.0) : (params.width - params.rightInset - messageInfoSize.width - layoutConstants.bubble.edgeInset - 9.0)), y: 8.0 + messageInfoSize.height), size: replyInfoSize)
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
                        
                        if let replyBackgroundNode = strongSelf.replyBackgroundNode, let replyBackgroundFrame {
                            replyBackgroundNode.frame = replyBackgroundFrame
                            
                            let cornerRadius = 4.0
                            replyBackgroundNode.update(size: replyBackgroundNode.bounds.size, cornerRadius: cornerRadius, transition: .immediate)
                        }
                        
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
                            let deliveryFailedFrame = CGRect(origin: CGPoint(x: videoFrame.maxX + deliveryFailedInset - deliveryFailedSize.width, y: videoFrame.maxY - deliveryFailedSize.height), size: deliveryFailedSize)
                            if isAppearing {
                                deliveryFailedNode.frame = deliveryFailedFrame
                                animation.transition.animatePositionAdditive(node: deliveryFailedNode, offset: CGPoint(x: deliveryFailedInset, y: 0.0))
                            } else {
                                animation.animator.updateFrame(layer: deliveryFailedNode.layer, frame: deliveryFailedFrame, completion: nil)
                            }
                        } else if let deliveryFailedNode = strongSelf.deliveryFailedNode {
                            strongSelf.deliveryFailedNode = nil
                            animation.animator.updateAlpha(layer: deliveryFailedNode.layer, alpha: 0.0, completion: nil)
                            animation.animator.updateFrame(layer: deliveryFailedNode.layer, frame: deliveryFailedNode.frame.offsetBy(dx: 24.0, dy: 0.0), completion: { [weak deliveryFailedNode] _ in
                                deliveryFailedNode?.removeFromSupernode()
                            })
                        }
                                                
                        if let reactionButtonsSizeAndApply = reactionButtonsSizeAndApply {
                            let reactionButtonsNode = reactionButtonsSizeAndApply.1(animation)
                            var reactionButtonsFrame = CGRect(origin: CGPoint(x: videoFrame.minX, y: videoFrame.maxY + 6.0), size: reactionButtonsSizeAndApply.0)
                            if !incoming {
                                reactionButtonsFrame.origin.x = videoFrame.maxX - reactionButtonsSizeAndApply.0.width
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
                                if let (rect, containerSize) = strongSelf.absoluteRect {
                                    var rect = rect
                                    rect.origin.y = containerSize.height - rect.maxY + strongSelf.insets.top
                                    
                                    var reactionButtonsNodeFrame = reactionButtonsFrame
                                    reactionButtonsNodeFrame.origin.x += rect.minX
                                    reactionButtonsNodeFrame.origin.y += rect.minY
                                    
                                    reactionButtonsNode.update(rect: rect, within: containerSize, transition: .immediate)
                                }
                                strongSelf.addSubnode(reactionButtonsNode)
                                if animation.isAnimated {
                                    reactionButtonsNode.animateIn(animation: animation)
                                }
                            } else {
                                animation.animator.updateFrame(layer: reactionButtonsNode.layer, frame: reactionButtonsFrame, completion: nil)
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
                        
                        if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                            let actionButtonsNode = actionButtonsSizeAndApply.1(animation)
                            let previousFrame = actionButtonsNode.frame
                            let actionButtonsFrame = CGRect(origin: CGPoint(x: videoFrame.minX, y: videoFrame.maxY), size: actionButtonsSizeAndApply.0)
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
                    }
                    
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                    if let replyBackgroundNode = strongSelf.replyBackgroundNode {
                        transition.updateAlpha(node: replyBackgroundNode, alpha: isPlaying ? 0.0 : 1.0)
                    }
                    if let forwardInfoNode = strongSelf.forwardInfoNode {
                        transition.updateAlpha(node: forwardInfoNode, alpha: isPlaying ? 0.0 : 1.0)
                    }
                    if let replyInfoNode = strongSelf.replyInfoNode {
                        transition.updateAlpha(node: replyInfoNode, alpha: isPlaying ? 0.0 : 1.0)
                    }
                    
                    if let (_, f) = strongSelf.awaitingAppliedReaction {
                        strongSelf.awaitingAppliedReaction = nil
                        
                        f()
                    }
                }
            }
            
            return (ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets), { animation, _, synchronousLoads in
                finishAsyncLayout(animation, synchronousLoads)
            })
        }
        
        let weakSelf = Weak(self)
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) in
            continueAsyncLayout(weakSelf, item, params, mergedTop, mergedBottom, dateHeaderAtBottom)
        }
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                if let action = self.gestureRecognized(gesture: gesture, location: location, recognizer: nil) {
                    if case .doubleTap = gesture {
                        self.containerNode.cancelGesture()
                    }
                    switch action {
                    case let .action(f):
                        f.action()
                    case let .optionalAction(f):
                        f()
                    case .openContextMenu:
                        break
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
            if let replyInfoNode = self.replyInfoNode, replyInfoNode.frame.contains(location) {
                if let item = self.item {
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute {
                            return .optionalAction({
                                item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId, NavigateToMessageParams(timestamp: nil, quote: attribute.isQuote ? attribute.quote.flatMap { quote in NavigateToMessageParams.Quote(string: quote.text, offset: quote.offset) } : nil))
                            })
                        } else if let attribute = attribute as? QuotedReplyMessageAttribute {
                            return .action(InternalBubbleTapAction.Action {
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
            return nil
        case .longTap, .doubleTap, .secondaryTap:
            if let item = self.item, self.interactiveVideoNode.frame.contains(location) {
                return .openContextMenu(InternalBubbleTapAction.OpenContextMenu(tapMessage: item.message, selectAll: false, subFrame: self.interactiveVideoNode.frame))
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
                func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                    let bandedOffset = offset - bandingStart
                    if offset < bandingStart {
                        return offset
                    }
                    let range: CGFloat = 100.0
                    let coefficient: CGFloat = 0.4
                    return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
                }
            
                var translation = recognizer.translation(in: self.view)
                if translation.x < 0.0 {
                    translation.x = max(-80.0, min(0.0, -rubberBandingOffset(offset: abs(translation.x), bandingStart: swipeOffset)))
                } else {
                    if recognizer.allowBothDirections {
                        translation.x = -max(-80.0, min(0.0, -rubberBandingOffset(offset: abs(translation.x), bandingStart: swipeOffset)))
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
        if !self.bounds.contains(point) {
            return nil
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
        
        if let selectionState = item.controllerInteraction.selectionState {
            var selected = false
            var incoming = true
            
            selected = selectionState.selectedIds.contains(item.message.id)
            incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            
            let offset: CGFloat = incoming || (self.appliedCurrentlyPlaying ?? false) ? 42.0 : 0.0
            
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

    public func animateFromLoadingPlaceholder(delay: Double, transition: ContainedViewLayoutTransition) {
        guard let item = self.item else {
            return
        }
        
        let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
        transition.animatePositionAdditive(node: self, offset: CGPoint(x: incoming ? 30.0 : -30.0, y: -30.0), delay: delay)
        transition.animateTransformScale(node: self, from: CGPoint(x: 0.85, y: 0.85), delay: delay)
    }
    
    public func animateFromSnapshot(snapshotView: UIView, transition: CombinedTransition) {
        snapshotView.frame = self.interactiveVideoNode.view.convert(snapshotView.frame, from: self.contextSourceNode.contentNode.view)
        self.interactiveVideoNode.animateFromSnapshot(snapshotView: snapshotView, transition: transition)
    }

    override public func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        return self.interactiveVideoNode.playMediaWithSound()
    }
    
    override public func getMessageContextSourceNode(stableId: UInt32?) -> ContextExtractedContentContainingNode? {
        return self.contextSourceNode
    }
    
    override public func addAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        self.contextSourceNode.contentNode.addSubnode(accessoryItemNode)
    }
        
    override public func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        guard let item = self.appliedItem, let params = self.appliedParams, progress > 0.0, let (initialHeight, targetHeight) = self.apparentHeightTransition, !targetHeight.isZero && !initialHeight.isZero else {
            return
        }
        
        let layoutConstants = chatMessageItemLayoutConstants(self.layoutConstants, params: params, presentationData: item.presentationData)
        let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
        
        var isReplyThread = false
        if case .replyThread = item.chatLocation {
            isReplyThread = true
        }
        
        var isPlaying = false
        var displaySize = layoutConstants.instantVideo.dimensions
        let maximumDisplaySize = CGSize(width: min(404, params.width - 20.0), height: min(404, params.width - 20.0))
        if item.associatedData.currentlyPlayingMessageId == item.message.index {
            isPlaying = true
        }
        
        let avatarInset: CGFloat
        if self.appliedHasAvatar {
            avatarInset = layoutConstants.avatarDiameter
        } else {
            avatarInset = 0.0
        }
        
        let isFailed = item.content.firstMessage.effectivelyFailed(timestamp: item.context.account.network.getApproximateRemoteTimestamp())
        var deliveryFailedInset: CGFloat = 0.0
        if isFailed {
            deliveryFailedInset += 24.0
        }
        
        let makeVideoLayout = self.interactiveVideoNode.asyncLayout()
        
        let initialSize: CGSize
        let targetSize: CGSize
        let animationProgress: CGFloat = (currentValue - initialHeight) / (targetHeight - initialHeight)
        let scaleProgress: CGFloat
        var effectiveAvatarInset = avatarInset
        if abs(targetHeight - initialHeight) > 80.0 {
            if currentValue < targetHeight {
                initialSize = displaySize
                targetSize = maximumDisplaySize
                scaleProgress = animationProgress
            } else if currentValue > targetHeight {
                initialSize = maximumDisplaySize
                targetSize = displaySize
                scaleProgress = 1.0 - animationProgress
            } else {
                initialSize = isPlaying ? maximumDisplaySize : displaySize
                targetSize = initialSize
                scaleProgress = isPlaying ? 1.0 : 0.0
            }
        } else {
            initialSize = isPlaying ? maximumDisplaySize : displaySize
            targetSize = initialSize
            scaleProgress = isPlaying ? 1.0 : 0.0
        }
        effectiveAvatarInset *= (1.0 - scaleProgress)
        displaySize = CGSize(width: initialSize.width + (targetSize.width - initialSize.width) * animationProgress, height: initialSize.height + (targetSize.height - initialSize.height) * animationProgress)
        
        let (videoLayout, videoApply) = makeVideoLayout(ChatMessageBubbleContentItem(context: item.context, controllerInteraction: item.controllerInteraction, message: item.message, topMessage: item.message, content: item.content, read: item.read, chatLocation: item.chatLocation, presentationData: item.presentationData, associatedData: item.associatedData, attributes: item.content.firstMessageAttributes, isItemPinned: item.message.tags.contains(.pinned) && !isReplyThread, isItemEdited: false), params.width - params.leftInset - params.rightInset - avatarInset, displaySize, maximumDisplaySize, scaleProgress, .free, self.appliedAutomaticDownload, 0.0)
        
        let availableContentWidth = params.width - params.leftInset - params.rightInset - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left
        let videoFrame = CGRect(origin: CGPoint(x: (incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + effectiveAvatarInset + layoutConstants.bubble.contentInsets.left) : (params.width - params.rightInset - videoLayout.contentSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - deliveryFailedInset)), y: 0.0), size: videoLayout.contentSize)
        self.interactiveVideoNode.frame = videoFrame
        
        let videoLayoutData: ChatMessageInstantVideoItemLayoutData
        if incoming {
            videoLayoutData = .constrained(left: 0.0, right: max(0.0, availableContentWidth - videoFrame.width))
        } else {
            videoLayoutData = .constrained(left: max(0.0, availableContentWidth - videoFrame.width), right: 0.0)
        }
        videoApply(videoLayoutData, .None)
        
        if let shareButtonNode = self.shareButtonNode {
            let buttonSize = shareButtonNode.frame.size
            shareButtonNode.frame = CGRect(origin: CGPoint(x: min(params.width - buttonSize.width - 8.0, videoFrame.maxX - 7.0), y: videoFrame.maxY - 24.0 - buttonSize.height), size: buttonSize)
        }
        
//        if let viaBotNode = self.viaBotNode {
//            let viaBotLayout = viaBotNode.frame
//            let viaBotFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 10.0) : (params.width - params.rightInset - viaBotLayout.size.width - layoutConstants.bubble.edgeInset - 10.0)), y: 8.0), size: viaBotLayout.size)
//            viaBotNode.frame = viaBotFrame
//            self.replyBackgroundNode?.frame = CGRect(origin: CGPoint(x: viaBotFrame.minX - 4.0, y: viaBotFrame.minY - 2.0), size: CGSize(width: viaBotFrame.size.width + 8.0, height: viaBotFrame.size.height + 5.0))
//        }
//        
//        if let replyInfoNode = self.replyInfoNode {
//            var viaBotSize = CGSize()
//            if let viaBotNode = self.viaBotNode {
//                viaBotSize = viaBotNode.frame.size
//            }
//            let replyInfoSize = replyInfoNode.frame.size
//            let replyInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 10.0) : (params.width - params.rightInset - max(replyInfoSize.width, viaBotSize.width) - layoutConstants.bubble.edgeInset - 10.0)), y: 8.0 + viaBotSize.height), size: replyInfoSize)
//            if let viaBotNode = self.viaBotNode {
//                if replyInfoFrame.minX < viaBotNode.frame.minX {
//                    viaBotNode.frame = viaBotNode.frame.offsetBy(dx: replyInfoFrame.minX - viaBotNode.frame.minX, dy: 0.0)
//                }
//            }
//            replyInfoNode.frame = replyInfoFrame
//            self.replyBackgroundNode?.frame = CGRect(origin: CGPoint(x: replyInfoFrame.minX - 4.0, y: replyInfoFrame.minY - viaBotSize.height - 2.0), size: CGSize(width: max(replyInfoFrame.size.width, viaBotSize.width) + 8.0, height: replyInfoFrame.size.height + viaBotSize.height + 5.0))
//        }
        
        if let deliveryFailedNode = self.deliveryFailedNode {
            let deliveryFailedSize = deliveryFailedNode.frame.size
            let deliveryFailedFrame = CGRect(origin: CGPoint(x: videoFrame.maxX + deliveryFailedInset - deliveryFailedSize.width, y: videoFrame.maxY - deliveryFailedSize.height), size: deliveryFailedSize)
            deliveryFailedNode.frame = deliveryFailedFrame
        }
        
//        if let forwardInfoNode = self.forwardInfoNode {
//            let forwardInfoSize = forwardInfoNode.frame.size
//            let forwardInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 12.0) : (params.width - params.rightInset - forwardInfoSize.width - layoutConstants.bubble.edgeInset - 12.0)), y: 8.0), size: forwardInfoSize)
//            forwardInfoNode.frame = forwardInfoFrame
//        }
        
        if let actionButtonsNode = self.actionButtonsNode {
            let actionButtonsSize = actionButtonsNode.frame.size
            let actionButtonsFrame = CGRect(origin: CGPoint(x: videoFrame.minX, y: videoFrame.maxY), size: actionButtonsSize)
            actionButtonsNode.frame = actionButtonsFrame
        }
        
        if let reactionButtonsNode = self.reactionButtonsNode {
            let reactionButtonsSize = reactionButtonsNode.frame.size
            var reactionButtonsFrame = CGRect(origin: CGPoint(x: videoFrame.minX, y: videoFrame.maxY + 6.0), size: reactionButtonsSize)
            if !incoming {
                reactionButtonsFrame.origin.x = videoFrame.maxX - reactionButtonsSize.width
            }
            if let actionButtonsNode = self.actionButtonsNode {
                let actionButtonsSize = actionButtonsNode.frame.size
                reactionButtonsFrame.origin.y += 4.0 + actionButtonsSize.height
            }
            reactionButtonsNode.frame = reactionButtonsFrame
        }
    }
    
    override public func openMessageContextMenu() {
        guard let item = self.item else {
            return
        }
        item.controllerInteraction.openMessageContextMenu(item.message, false, self, self.interactiveVideoNode.frame, nil, nil)
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        var rect = rect
        rect.origin.y = containerSize.height - rect.maxY + self.insets.top
            
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
    }
    
    override public func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if let reactionButtonsNode = self.reactionButtonsNode {
            reactionButtonsNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
    }
        
    override public func targetReactionView(value: MessageReaction.Reaction) -> UIView? {
        if let result = self.reactionButtonsNode?.reactionTargetView(value: value) {
            return result
        }
        if !self.interactiveVideoNode.dateAndStatusNode.isHidden {
            return self.interactiveVideoNode.dateAndStatusNode.reactionView(value: value)
        }
        return nil
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
    
    override public func contentFrame() -> CGRect {
        return self.interactiveVideoNode.frame
    }
}
