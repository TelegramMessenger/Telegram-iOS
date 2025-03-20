import Foundation
import UIKit
import AVFoundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import CoreImage
import TelegramPresentationData
import Compression
import TextFormat
import AccountContext
import MediaResources
import StickerResources
import ContextUI
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import Emoji
import Markdown
import ManagedAnimationNode
import SlotMachineAnimationNode
import UniversalMediaPlayer
import ShimmerEffect
import WallpaperBackgroundNode
import LocalMediaResources
import AppBundle
import ChatPresentationInterfaceState
import TextNodeWithEntities
import ChatControllerInteraction
import ChatMessageForwardInfoNode
import ChatMessageDateAndStatusNode
import ChatMessageItemCommon
import ChatMessageBubbleContentNode
import ChatMessageReplyInfoNode
import ChatMessageItem
import ChatMessageItemView
import ChatMessageSwipeToReplyNode
import ChatMessageSelectionNode
import ChatMessageDeliveryFailedNode
import ChatMessageShareButton
import ChatMessageThreadInfoNode
import ChatMessageActionButtonsNode
import ChatSwipeToReplyRecognizer
import ChatMessageReactionsFooterContentNode
import ManagedDiceAnimationNode
import MessageHaptics
import ChatMessageTransitionNode

private let nameFont = Font.medium(14.0)
private let inlineBotPrefixFont = Font.regular(14.0)
private let inlineBotNameFont = nameFont

public protocol GenericAnimatedStickerNode: ASDisplayNode {
    func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool)

    var currentFrameIndex: Int { get }
    func setFrameIndex(_ frameIndex: Int)
}

extension DefaultAnimatedStickerNodeImpl: GenericAnimatedStickerNode {
    public func setFrameIndex(_ frameIndex: Int) {
        self.stop()
        self.play(fromIndex: frameIndex)
    }
}

extension SlotMachineAnimationNode: GenericAnimatedStickerNode {
    public var currentFrameIndex: Int {
        return 0
    }

    public func setFrameIndex(_ frameIndex: Int) {
    }
}

extension ManagedDiceAnimationNode: GenericAnimatedStickerNode {
}

public class ChatMessageAnimatedStickerItemNode: ChatMessageItemView {
    public let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    public let imageNode: TransformImageNode
    private var enableSynchronousImageApply: Bool = false
    private var backgroundNode: WallpaperBubbleBackgroundNode?
    public private(set) var placeholderNode: StickerShimmerEffectNode
    public private(set) var animationNode: GenericAnimatedStickerNode?
    private var animationSize: CGSize?
    private var didSetUpAnimationNode = false
    private var isPlaying = false
    
    private let textNode: TextNodeWithEntities
    
    private var additionalAnimationNodes: [ChatMessageTransitionNode.DecorationItemNode] = []
    private var enqueuedAdditionalAnimations: [(Int, Double)] = []
    private var additionalAnimationsCommitTimer: SwiftSignalKit.Timer?
  
    private var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    private var swipeToReplyFeedback: HapticFeedback?
    
    private var selectionNode: ChatMessageSelectionNode?
    private var deliveryFailedNode: ChatMessageDeliveryFailedNode?
    private var shareButtonNode: ChatMessageShareButton?
    
    public var telegramFile: TelegramMediaFile?
    public var emojiFile: TelegramMediaFile?
    public var telegramDice: TelegramMediaDice?
    public var emojiString: String?
    private let disposable = MetaDisposable()
    private let disposables = DisposableSet()

    private var viaBotNode: TextNode?
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private var threadInfoNode: ChatMessageThreadInfoNode?
    private var replyInfoNode: ChatMessageReplyInfoNode?
    private var replyBackgroundContent: WallpaperBubbleBackgroundNode?
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    private var forwardBackgroundContent: WallpaperBubbleBackgroundNode?
    
    private var actionButtonsNode: ChatMessageActionButtonsNode?
    private var reactionButtonsNode: ChatMessageReactionButtonsNode?
    
    private let messageAccessibilityArea: AccessibilityAreaNode
    
    private var highlightedState: Bool = false
    
    private var forceStopAnimations = false
    
    private var hapticFeedback: HapticFeedback?
    private var haptic: EmojiHaptic?
    private var mediaPlayer: MediaPlayer?
    private let mediaStatusDisposable = MetaDisposable()
    
    private var currentSwipeToReplyTranslation: CGFloat = 0.0
    
    private var appliedForwardInfo: (Peer?, String?)?
    
    private var replyRecognizer: ChatSwipeToReplyRecognizer?
    private var currentSwipeAction: ChatControllerInteractionSwipeAction?
    
    private var wasPending: Bool = false
    private var didChangeFromPendingToSent: Bool = false
    
    private var fetchEffectDisposable: Disposable?
    
    required public init(rotated: Bool) {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.imageNode = TransformImageNode()
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode.isUserInteractionEnabled = false
        
        self.messageAccessibilityArea = AccessibilityAreaNode()
        
        self.textNode = TextNodeWithEntities()
        self.textNode.textNode.displaysAsynchronously = false
        self.textNode.textNode.isUserInteractionEnabled = false
        
        super.init(rotated: rotated)
        
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
                        strongSelf.imageNode.alpha = 0.0
                    }
                } else {
                    if strongSelf.setupTimestamp == nil {
                        strongSelf.removePlaceholder(animated: true)
                    }
                }
                firstTime = false
            }
        }
                
        self.imageNode.displaysAsynchronously = false
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        self.contextSourceNode.contentNode.addSubnode(self.imageNode)
        self.contextSourceNode.contentNode.addSubnode(self.placeholderNode)
        self.contextSourceNode.contentNode.addSubnode(self.dateAndStatusNode)
        self.addSubnode(self.messageAccessibilityArea)
        
        self.messageAccessibilityArea.focused = { [weak self] in
            self?.accessibilityElementDidBecomeFocused()
        }
    }
    
    deinit {
        self.disposable.dispose()
        self.disposables.dispose()
        self.mediaStatusDisposable.set(nil)
        self.additionalAnimationsCommitTimer?.invalidate()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func removePlaceholder(animated: Bool) {
        self.placeholderNode.alpha = 0.0
        if !animated {
            self.placeholderNode.removeFromSupernode()
        } else {
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
                
                if strongSelf.telegramFile == nil {
                    if let animationNode = strongSelf.animationNode, animationNode.frame.contains(point) {
                        return .waitForSingleTap
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
        if let item = self.item {
            let _ = item
            replyRecognizer.allowBothDirections = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
            self.view.disablesInteractiveTransitionGestureRecognizer = false
        }
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
        self.replyRecognizer = replyRecognizer
        self.view.addGestureRecognizer(replyRecognizer)
    }
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = oldValue != .none
            let isVisible = self.visibility != .none
            
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
            }
            
            if oldValue != self.visibility {
                self.updateVisibility()
            }
        }
    }
    
    private var visibilityStatus: Bool? {
        didSet {
            if self.visibilityStatus != oldValue {
                self.updateVisibility()
                self.haptic?.enabled = self.visibilityStatus == true
                
                self.threadInfoNode?.visibility = self.visibilityStatus == true
                self.replyInfoNode?.visibility = self.visibilityStatus == true
            }
        }
    }
    
    private var setupTimestamp: Double?
    private func setupNode(item: ChatMessageItem) {
        self.replyRecognizer?.allowBothDirections = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
        if self.isNodeLoaded {
            self.view.disablesInteractiveTransitionGestureRecognizer = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
        }
        
        guard self.animationNode == nil else {
            return
        }
        
        if let telegramDice = self.telegramDice {
            if telegramDice.emoji == "🎰" {
                let animationNode = SlotMachineAnimationNode(account: item.context.account)
                if !item.message.effectivelyIncoming(item.context.account.peerId) {
                    animationNode.success = { [weak self] onlyHaptic in
                        if let strongSelf = self, let item = strongSelf.item {
                            item.controllerInteraction.animateDiceSuccess(true, !onlyHaptic)
                        }
                    }
                }
                self.animationNode = animationNode
            } else {
                let animationNode = ManagedDiceAnimationNode(context: item.context, emoji: telegramDice.emoji.strippedEmoji)
                if !item.message.effectivelyIncoming(item.context.account.peerId) {
                    animationNode.success = { [weak self] in
                        if let strongSelf = self, let item = strongSelf.item {
                            item.controllerInteraction.animateDiceSuccess(true, true)
                        }
                    }
                }
                self.animationNode = animationNode
            }
        } else {
            let animationNode = DefaultAnimatedStickerNodeImpl(useMetalCache: false)
            animationNode.started = { [weak self] in
                if let strongSelf = self {
                    strongSelf.imageNode.alpha = 0.0
                    if !strongSelf.enableSynchronousImageApply {
                        let current = CACurrentMediaTime()
                        if let setupTimestamp = strongSelf.setupTimestamp, current - setupTimestamp > 0.3 {
                            if !strongSelf.placeholderNode.alpha.isZero {
                                strongSelf.animationNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                strongSelf.removePlaceholder(animated: true)
                            }
                        } else {
                            strongSelf.removePlaceholder(animated: false)
                        }
                    }
                    
                    if let item = strongSelf.item {
                        if let file = strongSelf.emojiFile, !file.isCustomEmoji {
                            item.controllerInteraction.seenOneTimeAnimatedMedia.insert(item.message.id)
                        }
                    }
                }
            }
            self.animationNode = animationNode
        }
        
        if let animationNode = self.animationNode {
            self.contextSourceNode.contentNode.insertSubnode(animationNode, aboveSubnode: self.placeholderNode)
        }
    }
    
    override public func setupItem(_ item: ChatMessageItem, synchronousLoad: Bool) {
        super.setupItem(item, synchronousLoad: synchronousLoad)
        
        if item.message.id.namespace == Namespaces.Message.Local || item.message.id.namespace == Namespaces.Message.ScheduledLocal || item.message.id.namespace == Namespaces.Message.QuickReplyLocal {
            self.wasPending = true
        }
        if self.wasPending && (item.message.id.namespace != Namespaces.Message.Local && item.message.id.namespace != Namespaces.Message.ScheduledLocal && item.message.id.namespace != Namespaces.Message.QuickReplyLocal) {
            self.didChangeFromPendingToSent = true
        }
                
        for media in item.message.media {
            if let telegramFile = media as? TelegramMediaFile {
                if self.telegramFile?.id != telegramFile.id {
                    self.telegramFile = telegramFile
                    let dimensions = telegramFile.dimensions ?? PixelDimensions(width: 512, height: 512)
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: item.context.account.postbox, userLocation: .peer(item.message.id.peerId), file: telegramFile, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0)), thumbnail: false, synchronousLoad: synchronousLoad), attemptSynchronously: synchronousLoad)
                    self.updateVisibility()
                    self.disposable.set(freeMediaFileInteractiveFetched(account: item.context.account, userLocation: .peer(item.message.id.peerId), fileReference: .message(message: MessageReference(item.message), media: telegramFile)).startStrict())
                    
                    if telegramFile.isPremiumSticker {
                        if let effect = telegramFile.videoThumbnails.first {
                            self.disposables.add(freeMediaFileResourceInteractiveFetched(account: item.context.account, userLocation: .peer(item.message.id.peerId), fileReference: .message(message: MessageReference(item.message), media: telegramFile), resource: effect.resource).startStrict())
                        }
                    }
                }
                break
            } else if let telegramDice = media as? TelegramMediaDice {
                self.telegramDice = telegramDice
            }
        }
        
        self.setupNode(item: item)
        
        if let telegramDice = self.telegramDice, let diceNode = self.animationNode as? SlotMachineAnimationNode {
            if let value = telegramDice.value {
                diceNode.setState(value == 0 ? .rolling : .value(value, true))
            } else {
                diceNode.setState(.rolling)
            }
        } else if let telegramDice = self.telegramDice, let diceNode = self.animationNode as? ManagedDiceAnimationNode {
            if let value = telegramDice.value {
                diceNode.setState(value == 0 ? .rolling : .value(value, true))
            } else {
                diceNode.setState(.rolling)
            }
        } else if self.telegramFile == nil && self.telegramDice == nil {
            let (emoji, fitz) = item.message.text.basicEmoji
            
            var emojiFile: TelegramMediaFile?
            var emojiString: String?
            if messageIsEligibleForLargeCustomEmoji(item.message) || messageIsEligibleForLargeEmoji(item.message) {
                emojiString = item.message.text
            }
            
            if emojiFile == nil {
                emojiFile = item.associatedData.animatedEmojiStickers[emoji]?.first?.file._parse()
            }
            if emojiFile == nil {
                emojiFile = item.associatedData.animatedEmojiStickers[emoji.strippedEmoji]?.first?.file._parse()
            }
            
            if item.message.text.count == 1, (item.message.textEntitiesAttribute?.entities ?? []).isEmpty && emojiFile != nil {
                emojiString = nil
            } else if emojiString != nil {
                emojiFile = nil
            }
                        
            if self.emojiString != emojiString {
                self.emojiString = emojiString
            } else if self.emojiFile?.id != emojiFile?.id {
                if self.emojiFile != nil {
                    self.didSetUpAnimationNode = false
                    item.controllerInteraction.seenOneTimeAnimatedMedia.remove(item.message.id)
                    
                    self.animationNode?.removeFromSupernode()
                    self.animationNode = nil
                    
                    self.contextSourceNode.contentNode.insertSubnode(self.placeholderNode, aboveSubnode: self.imageNode)
                    
                    self.setupNode(item: item)
                }
                self.emojiFile = emojiFile
                if let emojiFile = emojiFile {
                    var dimensions = emojiFile.dimensions ?? PixelDimensions(width: 512, height: 512)
                    if emojiFile.isCustomEmoji {
                        dimensions = PixelDimensions(dimensions.cgSize.aspectFitted(CGSize(width: 512.0, height: 512.0)))
                    }
                    var fitzModifier: EmojiFitzModifier?
                    if let fitz = fitz {
                        fitzModifier = EmojiFitzModifier(emoji: fitz)
                    }
                    
                    let fillSize = emojiFile.isCustomEmoji ? CGSize(width: 512.0, height: 512.0) : CGSize(width: 384.0, height: 384.0)
                    
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: item.context.account.postbox, userLocation: .peer(item.message.id.peerId), file: emojiFile, small: false, size: dimensions.cgSize.aspectFilled(fillSize), fitzModifier: fitzModifier, thumbnail: false, synchronousLoad: synchronousLoad), attemptSynchronously: synchronousLoad)
                    self.disposable.set(freeMediaFileInteractiveFetched(account: item.context.account, userLocation: .peer(item.message.id.peerId), fileReference: .standalone(media: emojiFile)).startStrict())
                }
                
                let textEmoji = item.message.text.strippedEmoji
                var additionalTextEmoji = textEmoji
                let (basicEmoji, fitz) = item.message.text.basicEmoji
                if ["💛", "💙", "💚", "💜", "🧡", "🖤", "🤎", "🤍"].contains(textEmoji) {
                    additionalTextEmoji = "❤️".strippedEmoji
                } else if fitz != nil {
                    additionalTextEmoji = basicEmoji
                }
                
                var animationItems: [Int: StickerPackItem]?
                if let emojiFile = emojiFile, emojiFile.isCustomEmoji {
                } else {
                    if let items = item.associatedData.additionalAnimatedEmojiStickers[textEmoji] {
                        animationItems = items
                    } else if let items = item.associatedData.additionalAnimatedEmojiStickers[additionalTextEmoji] {
                        animationItems = items
                    }
                }
                
                if let animationItems = animationItems {
                    for (_, animationItem) in animationItems {
                        self.disposables.add(freeMediaFileInteractiveFetched(account: item.context.account, userLocation: .peer(item.message.id.peerId), fileReference: .standalone(media: animationItem.file._parse())).startStrict())
                    }
                }
            }
        }
        
        self.updateVisibility()
    }
    
    private func updateVisibility() {
        guard let item = self.item else {
            return
        }
        
        var file: TelegramMediaFile?
        var playbackMode: AnimatedStickerPlaybackMode = .loop
        var isEmoji = false
        var fitzModifier: EmojiFitzModifier?
        
        if let telegramFile = self.telegramFile {
            file = telegramFile
            if !item.context.sharedContext.energyUsageSettings.loopStickers {
                playbackMode = .once
            }
        } else if let emojiFile = self.emojiFile {
            file = emojiFile
            
            if emojiFile.isCustomEmoji {
                playbackMode = .loop
            } else {
                isEmoji = true
                playbackMode = .still(.end)
                
                let (_, fitz) = item.message.text.basicEmoji
                if let fitz = fitz {
                    fitzModifier = EmojiFitzModifier(emoji: fitz)
                }
            }
        }
        
        let isPlaying = self.visibilityStatus == true && !self.forceStopAnimations
        
        var effectiveVisibility = self.visibility
        if !isPlaying {
            effectiveVisibility = .none
        }
        
        switch effectiveVisibility {
        case .none:
            self.textNode.visibilityRect = nil
        case let .visible(_, subRect):
            var subRect = subRect
            subRect.origin.x = 0.0
            subRect.size.width = 10000.0
            self.textNode.visibilityRect = subRect
        }
        
        var canPlayEffects = isPlaying
        if !item.controllerInteraction.canReadHistory {
            canPlayEffects = false
        }
        
        if !canPlayEffects {
            self.removeAdditionalAnimations()
            self.removeEffectAnimations()
        }
        
        if let animationNode = self.animationNode as? AnimatedStickerNode {
            if self.isPlaying != isPlaying || (isPlaying && !self.didSetUpAnimationNode) {
                self.isPlaying = isPlaying
                
                if isPlaying && self.setupTimestamp == nil {
                    self.setupTimestamp = CACurrentMediaTime()
                }
                animationNode.visibility = isPlaying
                
                if self.isPlaying && !self.didSetUpAnimationNode {
                    self.didSetUpAnimationNode = true

                    if let file = file {
                        var dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                        if file.isCustomEmoji {
                            dimensions = PixelDimensions(dimensions.cgSize.aspectFitted(CGSize(width: 512.0, height: 512.0)))
                        }
                        let fittedSize = isEmoji ? dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0)) : dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0))
                        
                        let pathPrefix = item.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                        let mode: AnimatedStickerMode = .direct(cachePathPrefix: pathPrefix)
                        self.animationSize = fittedSize
                        animationNode.setup(source: AnimatedStickerResourceSource(account: item.context.account, resource: file.resource, fitzModifier: fitzModifier, isVideo: file.mimeType == "video/webm"), width: Int(fittedSize.width), height: Int(fittedSize.height), playbackMode: playbackMode, mode: mode)
                    }
                }
            }
        }
        
        if canPlayEffects, let animationNode = self.animationNode as? AnimatedStickerNode {
            var effectAlreadySeen = true
            if item.message.flags.contains(.Incoming) {
                if let unreadRange = item.controllerInteraction.unreadMessageRange[UnreadMessageRangeKey(peerId: item.message.id.peerId, namespace: item.message.id.namespace)] {
                    if unreadRange.contains(item.message.id.id) {
                        if !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
                            effectAlreadySeen = false
                        }
                    }
                }
            } else {
                if self.didChangeFromPendingToSent {
                    if !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
                        effectAlreadySeen = false
                    }
                }
            }
            
            var alreadySeen = true
            if isEmoji && self.emojiString == nil {
                if !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
                    alreadySeen = false
                }
            } else if item.message.flags.contains(.Incoming) {
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
                if let emojiString = self.emojiString, emojiString.count == 1 {
                    if item.message.id.peerId.namespace == Namespaces.Peer.CloudUser {
                        self.playAdditionalEmojiAnimation(index: 1)
                    }
                } else if let file = file, file.isPremiumSticker {
                    Queue.mainQueue().after(0.1) {
                        self.playPremiumStickerAnimation()
                    }
                } else if isEmoji {
                    animationNode.seekTo(.start)
                    animationNode.playOnce()
                }
            }
            
            if !effectAlreadySeen {
                self.playMessageEffect(force: false)
            }
        }
    }
    
    override public func updateStickerSettings(forceStopAnimations: Bool) {
        self.forceStopAnimations = forceStopAnimations
        self.updateVisibility()
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        if !self.contextSourceNode.isExtractedToContextPreview {
            var rect = rect
            rect.origin.y = containerSize.height - rect.maxY + self.insets.top

            self.placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + self.placeholderNode.frame.minX, y: rect.minY + self.placeholderNode.frame.minY), size: self.placeholderNode.frame.size), within: containerSize)
            
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
        
    override public func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) {
        var displaySize = CGSize(width: 180.0, height: 180.0)
        let telegramFile = self.telegramFile
        let emojiFile = self.emojiFile
        let telegramDice = self.telegramDice
        let emojiString = self.emojiString
        let layoutConstants = self.layoutConstants
        let imageLayout = self.imageNode.asyncLayout()
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        let actionButtonsLayout = ChatMessageActionButtonsNode.asyncLayout(self.actionButtonsNode)
        let reactionButtonsLayout = ChatMessageReactionButtonsNode.asyncLayout(self.reactionButtonsNode)
        
        let makeForwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        
        let viaBotLayout = TextNode.asyncLayout(self.viaBotNode)
        let makeThreadInfoLayout = ChatMessageThreadInfoNode.asyncLayout(self.threadInfoNode)
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentShareButtonNode = self.shareButtonNode
        let currentForwardInfo = self.appliedForwardInfo
        
        let textLayout = TextNodeWithEntities.asyncLayout(self.textNode)
        
        func continueAsyncLayout(_ weakSelf: Weak<ChatMessageAnimatedStickerItemNode>, _ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) {
            let accessibilityData = ChatMessageAccessibilityData(item: item, isSelected: nil)
            let layoutConstants = chatMessageItemLayoutConstants(layoutConstants, params: params, presentationData: item.presentationData)
            let incoming = item.content.effectivelyIncoming(item.context.account.peerId, associatedData: item.associatedData)
                        
            var imageSize: CGSize = CGSize(width: 200.0, height: 200.0)
            var imageVerticalInset: CGFloat = 0.0
            var imageTopPadding: CGFloat = 0.0
            var imageBottomPadding: CGFloat = 0.0
            var imageHorizontalOffset: CGFloat = 0.0
            if !(telegramFile?.videoThumbnails.isEmpty ?? true) {
                displaySize = CGSize(width: 240.0, height: 240.0)
                imageVerticalInset = -20.0
                imageHorizontalOffset = 12.0
            }
            
            var textLayoutAndApply: (TextNodeLayout, (TextNodeWithEntities.Arguments) -> TextNodeWithEntities)?
            var imageInset: CGFloat = 10.0
            
            let avatarInset: CGFloat
            var hasAvatar = false
            
            switch item.chatLocation {
            case let .peer(peerId):
                if peerId != item.context.account.peerId {
                    if peerId.isGroupOrChannel && item.message.author != nil {
                        if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case let .broadcast(info) = peer.info {
                            if info.flags.contains(.messagesShouldHaveProfiles) {
                                hasAvatar = incoming
                            }
                        } else {
                            hasAvatar = true
                        }
                    }
                } else if incoming {
                    hasAvatar = true
                }
            case let .replyThread(replyThreadMessage):
                if replyThreadMessage.peerId != item.context.account.peerId {
                    if replyThreadMessage.peerId.isGroupOrChannel && item.message.author != nil {
                        var isBroadcastChannel = false
                        if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                            isBroadcastChannel = true
                        }
                        
                        if replyThreadMessage.isChannelPost, replyThreadMessage.effectiveTopId == item.message.id {
                            isBroadcastChannel = true
                        }
                        
                        if !isBroadcastChannel {
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
            } else if item.message.id.peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
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
            
            var isEmoji = false
            if let _ = telegramDice {
                imageSize = displaySize
            } else if let telegramFile = telegramFile {
                if let dimensions = telegramFile.dimensions {
                    imageSize = dimensions.cgSize.aspectFitted(displaySize)
                } else if let thumbnailSize = telegramFile.previewRepresentations.first?.dimensions {
                    imageSize = thumbnailSize.cgSize.aspectFitted(displaySize)
                } else {
                    imageSize = displaySize
                }
            } else if let emojiFile = emojiFile {
                isEmoji = true
                
                let displaySize = CGSize(width: floor(displaySize.width * item.presentationData.animatedEmojiScale), height: floor(displaySize.height * item.presentationData.animatedEmojiScale))

                if var dimensions = emojiFile.dimensions {
                    if emojiFile.isCustomEmoji {
                        dimensions = PixelDimensions(dimensions.cgSize.aspectFitted(CGSize(width: 512.0, height: 512.0)))
                    }
                    imageSize = CGSize(width: displaySize.width * CGFloat(dimensions.width) / 512.0, height: displaySize.height * CGFloat(dimensions.height) / 512.0)
                } else if let thumbnailSize = emojiFile.previewRepresentations.first?.dimensions {
                    imageSize = thumbnailSize.cgSize.aspectFitted(displaySize)
                }
            } else if let _ = emojiString {
                imageVerticalInset = 0.0
                imageTopPadding = 16.0
                imageBottomPadding = 20.0

                let baseWidth = params.width
                var tmpWidth = layoutConstants.bubble.maximumWidthFill.widthFor(baseWidth)
                if needsShareButton && tmpWidth + 32.0 > baseWidth {
                    tmpWidth = baseWidth - 32.0
                }
                
                var deliveryFailedInset: CGFloat = 0.0
                if isFailed {
                    deliveryFailedInset += 24.0
                }
                
                if item.message.forwardInfo != nil || item.message.attributes.first(where: { $0 is ReplyMessageAttribute }) != nil {
                    tmpWidth -= 45.0
                }
                
                tmpWidth -= deliveryFailedInset
                
                let maximumContentWidth = floor(tmpWidth - layoutConstants.bubble.edgeInset - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - layoutConstants.bubble.contentInsets.right - avatarInset)

                let font = Font.regular(fontSizeForEmojiString(item.message.text))
                let textColor = item.presentationData.theme.theme.list.itemPrimaryTextColor
                let attributedText = stringWithAppliedEntities(item.message.text, entities: item.message.textEntitiesAttribute?.entities ?? [], baseColor: textColor, linkColor: textColor, baseFont: font, linkFont: font, boldFont: font, italicFont: font, boldItalicFont: font, fixedFont: font, blockQuoteFont: font, message: item.message, adjustQuoteFontSize: true)
                textLayoutAndApply = textLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maximumContentWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural))
                
                imageSize = CGSize(width: textLayoutAndApply!.0.size.width, height: textLayoutAndApply!.0.size.height)
                isEmoji = true
                
                imageInset = 0.0
            }
                        
            var layoutInsets = UIEdgeInsets(top: mergedTop.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            var deliveryFailedInset: CGFloat = 0.0
            if isFailed {
                deliveryFailedInset += 24.0
            }
            
            let displayLeftInset = params.leftInset + layoutConstants.bubble.edgeInset + avatarInset
            
            
            var innerImageSize = imageSize
            imageSize = CGSize(width: imageSize.width + imageInset * 2.0, height: imageSize.height + imageInset * 2.0)
            let imageFrame = CGRect(origin: CGPoint(x: 0.0 + (incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + avatarInset + layoutConstants.bubble.contentInsets.left) : (params.width - params.rightInset - imageSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - deliveryFailedInset - imageHorizontalOffset)), y: imageVerticalInset + imageTopPadding), size: CGSize(width: imageSize.width, height: imageSize.height))
            if isEmoji {
                innerImageSize = imageSize
            }
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: innerImageSize, boundingSize: innerImageSize, intrinsicInsets: UIEdgeInsets(top: imageInset, left: imageInset, bottom: imageInset, right: imageInset))
            
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
                }
            }
            
            let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: .regular, associatedData: item.associatedData)
            
            var isReplyThread = false
            if case .replyThread = item.chatLocation {
                isReplyThread = true
            }
            
            let messageEffect = item.message.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects)
            
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
                messageEffect: messageEffect,
                replyCount: dateReplies,
                isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && !isReplyThread,
                hasAutoremove: item.message.isSelfExpiring,
                canViewReactionList: canViewMessageReactionList(message: item.message),
                animationCache: item.controllerInteraction.presentationContext.animationCache,
                animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
            ))
            
            let (dateAndStatusSize, dateAndStatusApply) = statusSuggestedWidthAndContinue.1(statusSuggestedWidthAndContinue.0)
            
            var viaBotApply: (TextNodeLayout, () -> TextNode)?
            var threadInfoApply: (CGSize, (Bool) -> ChatMessageThreadInfoNode)?
            var replyInfoApply: (CGSize, (CGSize, Bool, ListViewItemUpdateAnimation) -> ChatMessageReplyInfoNode)?
            var replyMarkup: ReplyMarkupMessageAttribute?
            
            var availableContentWidth = min(200.0, max(60.0, params.width - params.leftInset - params.rightInset - max(imageSize.width, 160.0) - 20.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left))
            availableContentWidth -= 20.0
            
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
                        
                        viaBotApply = viaBotLayout(TextNodeLayoutArguments(attributedString: botString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, availableContentWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                    }
                }
                                
                if let replyAttribute = attribute as? ReplyMessageAttribute {
                    if case let .replyThread(replyThreadMessage) = item.chatLocation, Int32(clamping: replyThreadMessage.threadId) == replyAttribute.messageId.id {
                    } else {
                        replyMessage = item.message.associatedMessages[replyAttribute.messageId]
                    }
                    replyQuote = replyAttribute.quote.flatMap { ($0, replyAttribute.isQuote) }
                } else if let quoteReplyAttribute = attribute as? QuotedReplyMessageAttribute {
                    replyForward = quoteReplyAttribute
                } else if let attribute = attribute as? ReplyStoryAttribute {
                    replyStory = attribute.storyId
                } else if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
                    replyMarkup = attribute
                }
            }
            
            var hasReply = replyMessage != nil || replyForward != nil || replyStory != nil
            if case let .peer(peerId) = item.chatLocation, (peerId == replyMessage?.id.peerId || item.message.threadId == 1), let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, channel.flags.contains(.isForum), item.message.associatedThreadInfo != nil {
                if let threadId = item.message.threadId, let replyMessage = replyMessage, Int64(replyMessage.id.id) == threadId {
                    hasReply = false
                }
                    
                threadInfoApply = makeThreadInfoLayout(ChatMessageThreadInfoNode.Arguments(
                    presentationData: item.presentationData,
                    strings: item.presentationData.strings,
                    context: item.context,
                    controllerInteraction: item.controllerInteraction,
                    type: .standalone,
                    peer: nil,
                    threadId: item.message.threadId ?? 1,
                    parentMessage: item.message,
                    constrainedSize: CGSize(width: availableContentWidth, height: CGFloat.greatestFiniteMagnitude),
                    animationCache: item.controllerInteraction.presentationContext.animationCache,
                    animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                ))
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
                    constrainedSize: CGSize(width: availableContentWidth, height: CGFloat.greatestFiniteMagnitude),
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
                            viaBotApply = viaBotLayout(TextNodeLayoutArguments(attributedString: nameString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, availableContentWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
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
            
            let contentHeight: CGFloat
            if let _ = emojiString {
                contentHeight = imageSize.height + imageVerticalInset * 2.0 + imageTopPadding + imageBottomPadding
            } else {
                contentHeight = max(imageSize.height + imageVerticalInset * 2.0, layoutConstants.image.minDimensions.height)
            }
            
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
                let availableWidth = max(60.0, availableContentWidth + 6.0)
                forwardInfoSizeApply = makeForwardInfoLayout(item.context, item.presentationData, item.presentationData.strings, .standalone, forwardSource, forwardAuthorSignature, forwardPsaType, nil, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
            }
            
            var needsReplyBackground = false
            if replyInfoApply != nil {
                needsReplyBackground = true
            }
            
            var needsForwardBackground = false
            if viaBotApply != nil || forwardInfoSizeApply != nil {
                needsForwardBackground = true
            }
            
            var maxContentWidth = imageSize.width
            var actionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animation: ListViewItemUpdateAnimation) -> ChatMessageActionButtonsNode))?
            if let replyMarkup = replyMarkup {
                let (minWidth, buttonsLayout) = actionButtonsLayout(item.context, item.presentationData.theme, item.presentationData.chatBubbleCorners, item.presentationData.strings, item.controllerInteraction.presentationContext.backgroundNode, replyMarkup, item.message, maxContentWidth)
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
            if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                layoutSize.height += actionButtonsSizeAndApply.0.height
            }
            if let reactionButtonsSizeAndApply = reactionButtonsSizeAndApply {
                layoutSize.height += 4.0 + reactionButtonsSizeAndApply.0.height
            }
            
            var headersOffset: CGFloat = 0.0
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
            let _ = replyBackgroundFrame
            
            /*if let replyBackgroundFrameValue = replyBackgroundFrame {
                if replyBackgroundFrameValue.insetBy(dx: -2.0, dy: -2.0).intersects(baseShareButtonFrame) {
                    let offset: CGFloat = 25.0
                    
                    layoutSize.height += offset
                    updatedImageFrame.origin.y += offset
                    dateAndStatusFrame.origin.y += offset
                    baseShareButtonFrame.origin.y += offset
                }
            }*/
            
            func finishLayout(_ animation: ListViewItemUpdateAnimation, _ apply: ListViewItemApply, _ synchronousLoads: Bool) {
                if let strongSelf = weakSelf.value {
                    strongSelf.appliedForwardInfo = (forwardSource, forwardAuthorSignature)
                    strongSelf.updateAccessibilityData(accessibilityData)
                    
                    strongSelf.messageAccessibilityArea.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    
                    var transition: ContainedViewLayoutTransition = .immediate
                    if case let .System(duration, _) = animation {
                        if let subject = item.associatedData.subject, case .messageOptions = subject {
                            transition = .animated(duration: duration, curve: .linear)
                        } else {
                            transition = .animated(duration: duration, curve: .spring)
                        }
                    }
                    
                    var updatedImageFrame: CGRect
                    var contextContentFrame: CGRect
                    if let _ = emojiString {
                        updatedImageFrame = imageFrame
                        contextContentFrame = updatedImageFrame.inset(by: UIEdgeInsets(top: 0.0, left: 0.0, bottom: -imageBottomPadding, right: 0.0))
                    } else {
                        updatedImageFrame = imageFrame.offsetBy(dx: 0.0, dy: floor((contentHeight - imageSize.height) / 2.0))
                        contextContentFrame = updatedImageFrame
                    }
                    var updatedContentFrame = updatedImageFrame
                    if isEmoji && emojiString == nil {
                        updatedContentFrame = updatedContentFrame.insetBy(dx: -imageInset, dy: -imageInset)
                        contextContentFrame = updatedContentFrame
                    }
                    
                    if let (_, textApply) = textLayoutAndApply {
                        let placeholderColor = bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.stickerPlaceholderColor, wallpaper: item.presentationData.theme.wallpaper)
                        let _ = textApply(TextNodeWithEntities.Arguments(context: item.context, cache: item.controllerInteraction.presentationContext.animationCache, renderer: item.controllerInteraction.presentationContext.animationRenderer, placeholderColor: placeholderColor, attemptSynchronous: synchronousLoads))
                        
                        if strongSelf.textNode.textNode.supernode == nil {
                            strongSelf.contextSourceNode.contentNode.insertSubnode(strongSelf.textNode.textNode, aboveSubnode: strongSelf.imageNode)
                        }

                        strongSelf.textNode.textNode.frame = imageFrame
                    }
                    
                    strongSelf.imageNode.frame = updatedContentFrame
                    
                    strongSelf.contextSourceNode.contentRect = contextContentFrame
                    strongSelf.containerNode.targetNodeForActivationProgressContentRect = strongSelf.contextSourceNode.contentRect
                    
                    var animationNodeFrame = updatedContentFrame.insetBy(dx: imageInset, dy: imageInset)
                    if let telegramFile, telegramFile.isPremiumSticker {
                        animationNodeFrame = animationNodeFrame.offsetBy(dx: 0.0, dy: 20.0)
                    }
                    
                    var file: TelegramMediaFile?
                    if let emojiFile = emojiFile {
                        file = emojiFile
                    } else if let telegramFile = telegramFile {
                        file = telegramFile
                    }
                    
                    if let file = file, let immediateThumbnailData = file.immediateThumbnailData {
                        if strongSelf.backgroundNode == nil {
                            if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                strongSelf.backgroundNode = backgroundNode
                                strongSelf.placeholderNode.addBackdropNode(backgroundNode)
                                
                                if let (rect, size) = strongSelf.absoluteRect {
                                    strongSelf.updateAbsoluteRect(rect, within: size)
                                }
                            }
                        }
                        
                        let foregroundColor: UIColor = .clear// = bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.stickerPlaceholderColor, wallpaper: item.presentationData.theme.wallpaper)
                        let shimmeringColor = bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.stickerPlaceholderShimmerColor, wallpaper: item.presentationData.theme.wallpaper)
                        strongSelf.placeholderNode.update(backgroundColor: nil, foregroundColor: foregroundColor, shimmeringColor: shimmeringColor, data: immediateThumbnailData, size: animationNodeFrame.size, enableEffect: item.context.sharedContext.energyUsageSettings.fullTranslucency, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0))
                        strongSelf.placeholderNode.frame = animationNodeFrame
                    }
                    
                    if strongSelf.animationNode?.supernode === strongSelf.contextSourceNode.contentNode {
                        strongSelf.animationNode?.frame = animationNodeFrame
                        if let animationNode = strongSelf.animationNode as? AnimatedStickerNode {
                            animationNode.updateLayout(size: updatedContentFrame.insetBy(dx: imageInset, dy: imageInset).size)
                            
                            if let file = file, file.isPremiumSticker && incoming {
                                let mirroredTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                                strongSelf.imageNode.transform = mirroredTransform
                                animationNode.transform = mirroredTransform
                                strongSelf.placeholderNode.transform = mirroredTransform
                            }
                        }
                    }

                    strongSelf.enableSynchronousImageApply = true
                    imageApply()
                    strongSelf.enableSynchronousImageApply = false
                                        
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
                        updatedShareButtonNode.frame = CGRect(origin: CGPoint(x: !incoming ? updatedImageFrame.minX - buttonSize.width - 6.0 : updatedImageFrame.maxX + 8.0, y: updatedImageFrame.maxY - buttonSize.height - 4.0 + imageBottomPadding), size: buttonSize)
                    } else if let shareButtonNode = strongSelf.shareButtonNode {
                        shareButtonNode.removeFromSupernode()
                        strongSelf.shareButtonNode = nil
                    }
                    
                    let dateAndStatusFrame = CGRect(origin: CGPoint(x: max(displayLeftInset, updatedImageFrame.maxX - dateAndStatusSize.width - 4.0), y: updatedImageFrame.maxY - dateAndStatusSize.height - 4.0 + imageBottomPadding), size: dateAndStatusSize)
                    animation.animator.updateFrame(layer: strongSelf.dateAndStatusNode.layer, frame: dateAndStatusFrame, completion: nil)
                    dateAndStatusApply(animation)
                    if case .customChatContents = item.associatedData.subject {
                        strongSelf.dateAndStatusNode.isHidden = true
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
                    
                    var headersOffset: CGFloat = 0.0
                    if let (threadInfoSize, threadInfoApply) = threadInfoApply {
                        let threadInfoNode = threadInfoApply(synchronousLoads)
                        if strongSelf.threadInfoNode == nil {
                            strongSelf.threadInfoNode = threadInfoNode
                            strongSelf.contextSourceNode.contentNode.addSubnode(threadInfoNode)
                        }
                        let threadInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 6.0) : (params.width - params.rightInset - threadInfoSize.width - layoutConstants.bubble.edgeInset - 8.0)), y: 8.0), size: threadInfoSize)
                        threadInfoNode.frame = threadInfoFrame
                        
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
                        forwardInfoNode.frame = forwardInfoFrame
                        
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
                        forwardBackgroundFrame = forwardAreaFrame.insetBy(dx: -6.0, dy: -3.0)
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
                        backgroundContent.cornerRadius = 4.0
                        backgroundContent.frame = forwardBackgroundFrame
                        if let (rect, containerSize) = strongSelf.absoluteRect {
                            var backgroundFrame = backgroundContent.frame
                            backgroundFrame.origin.x += rect.minX
                            backgroundFrame.origin.y += rect.minY
                            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
                        }
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
                        let deliveryFailedFrame = CGRect(origin: CGPoint(x: imageFrame.maxX + deliveryFailedInset - deliveryFailedSize.width, y: imageFrame.maxY - deliveryFailedSize.height - imageInset + imageVerticalInset + imageBottomPadding), size: deliveryFailedSize)
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
                        let actionButtonsFrame = CGRect(origin: CGPoint(x: imageFrame.minX, y: imageFrame.maxY + imageVerticalInset + imageBottomPadding), size: actionButtonsSizeAndApply.0)
                        actionButtonsNode.frame = actionButtonsFrame
                        if actionButtonsNode !== strongSelf.actionButtonsNode {
                            strongSelf.actionButtonsNode = actionButtonsNode
                            actionButtonsNode.buttonPressed = { button in
                                if let strongSelf = weakSelf.value {
                                    strongSelf.performMessageButtonAction(button: button)
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
                        var reactionButtonsFrame = CGRect(origin: CGPoint(x: imageFrame.minX, y: imageFrame.maxY + imageVerticalInset + imageBottomPadding), size: reactionButtonsSizeAndApply.0)
                        if !incoming {
                            reactionButtonsFrame.origin.x = imageFrame.maxX - reactionButtonsSizeAndApply.0.width
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
                            reactionButtonsNode.openReactionPreview = { gesture, sourceView, value in
                                guard let strongSelf = weakSelf.value, let item = strongSelf.item else {
                                    gesture?.cancel()
                                    return
                                }
                                
                                item.controllerInteraction.openMessageReactionContextMenu(item.message, sourceView, gesture, value)
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
                    } else if messageEffect != nil {
                        strongSelf.dateAndStatusNode.pressed = {
                            guard let strongSelf = weakSelf.value, let item = strongSelf.item else {
                                return
                            }
                            item.controllerInteraction.playMessageEffect(item.message)
                        }
                    } else {
                        strongSelf.dateAndStatusNode.pressed = nil
                    }
                    
                    if let (_, f) = strongSelf.awaitingAppliedReaction {
                        strongSelf.awaitingAppliedReaction = nil
                        
                        f()
                    }
                }
            }
            return (ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets), { (animation: ListViewItemUpdateAnimation, apply: ListViewItemApply, synchronousLoads: Bool) -> Void in
                finishLayout(animation, apply, synchronousLoads)
            })
        }
        
        let weakSelf = Weak(self)
        return { (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) in
            return continueAsyncLayout(weakSelf, item, params, mergedTop, mergedBottom, dateHeaderAtBottom)
        }
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let item = self.item, let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                if let action = self.gestureRecognized(gesture: gesture, location: location, recognizer: recognizer) {
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
                            item.controllerInteraction.updateMessageReaction(item.message, .default, false, nil)
                        } else {
                            item.controllerInteraction.openMessageContextMenu(openContextMenu.tapMessage, openContextMenu.selectAll, self, openContextMenu.subFrame, nil, nil)
                        }
                    }
                } else if case .tap = gesture {
                    item.controllerInteraction.clickThroughMessage(self.view, location)
                } else if case .doubleTap = gesture {
                    if canAddMessageReactions(message: item.message) {
                        item.controllerInteraction.updateMessageReaction(item.message, .default, false, nil)
                    }
                }
            }
        default:
            break
        }
    }
    
    private func startAdditionalAnimationsCommitTimer() {
        guard self.additionalAnimationsCommitTimer == nil else {
            return
        }
        let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
            self?.commitEnqueuedAnimations()
            self?.additionalAnimationsCommitTimer?.invalidate()
            self?.additionalAnimationsCommitTimer = nil
        }, queue: Queue.mainQueue())
        self.additionalAnimationsCommitTimer = timer
        timer.start()
    }
    
    private func commitEnqueuedAnimations() {
        guard let item = self.item,  !self.enqueuedAdditionalAnimations.isEmpty else {
            return
        }
                
        var emojiFile = self.emojiFile
        if emojiFile == nil {
            emojiFile = item.message.associatedMedia.first?.value as? TelegramMediaFile
        }
        
        guard let file = emojiFile else {
            return
        }
        
        let enqueuedAnimations = self.enqueuedAdditionalAnimations
        self.enqueuedAdditionalAnimations.removeAll()
        
        guard let startTimestamp = enqueuedAnimations.first?.1 else {
            return
        }
        
        var animations: [EmojiInteraction.Animation] = []
        for (index, timestamp) in enqueuedAnimations {
            animations.append(EmojiInteraction.Animation(index: index, timeOffset: Float(max(0.0, timestamp - startTimestamp))))
        }
        item.controllerInteraction.commitEmojiInteraction(item.message.id, item.message.text.strippedEmoji, EmojiInteraction(animations: animations), file)
    }
    
    public func playEmojiInteraction(_ interaction: EmojiInteraction) {
        guard interaction.animations.count <= 7 else {
            return
        }
        
        var hapticFeedback: HapticFeedback
        if let current = self.hapticFeedback {
            hapticFeedback = current
        } else {
            hapticFeedback = HapticFeedback()
            self.hapticFeedback = hapticFeedback
        }
        
        var playHaptic = true
        if let existingHaptic = self.haptic, existingHaptic.active {
            playHaptic = false
        }
        hapticFeedback.prepareImpact(.light)
        hapticFeedback.prepareImpact(.medium)
                
        var index = 0
        for animation in interaction.animations {
            if animation.timeOffset > 0.0 {
                Queue.mainQueue().after(Double(animation.timeOffset)) {
                    self.playAdditionalEmojiAnimation(index: animation.index)
                    if playHaptic {
                        let style: ImpactHapticFeedbackStyle
                        if index == 1 {
                            style = .medium
                        } else {
                            style = [.light, .medium].randomElement() ?? .medium
                        }
                        hapticFeedback.impact(style)
                    }
                    index += 1
                }
            } else {
                self.playAdditionalEmojiAnimation(index: animation.index)
                if playHaptic {
                    hapticFeedback.impact(interaction.animations.count > 1 ? .light : .medium)
                }
                index += 1
            }
        }
    }
    
    public func playAdditionalEmojiAnimation(index: Int) {
        guard let item = self.item else {
            return
        }
        
        let textEmoji = item.message.text.strippedEmoji
        var additionalTextEmoji = textEmoji
        let (basicEmoji, fitz) = item.message.text.basicEmoji
        if ["💛", "💙", "💚", "💜", "🧡", "🖤", "🤎", "🤍"].contains(textEmoji) {
            additionalTextEmoji = "❤️".strippedEmoji
        } else if fitz != nil {
            additionalTextEmoji = basicEmoji
        }
        
        guard let animationItems = item.associatedData.additionalAnimatedEmojiStickers[additionalTextEmoji], index < 10, let file = animationItems[index]?.file else {
            return
        }
        
        self.playEffectAnimation(resource: file._parse().resource)
    }
    
    private var playedPremiumStickerAnimation = false
    func playPremiumStickerAnimation() {
        guard !self.playedPremiumStickerAnimation, let item = self.item, let file = self.telegramFile, file.isPremiumSticker, let effect = file.videoThumbnails.first else {
            return
        }
        self.playedPremiumStickerAnimation = true
        if item.message.attributes.contains(where: { attribute in
            if attribute is NonPremiumMessageAttribute {
                return true
            } else {
                return false
            }
        }) {
            return
        }
        self.playEffectAnimation(resource: effect.resource, isStickerEffect: true)
    }
    
    public func playEffectAnimation(resource: MediaResource, isStickerEffect: Bool = false) {
        guard let item = self.item else {
            return
        }
        guard let transitionNode = item.controllerInteraction.getMessageTransitionNode() as? ChatMessageTransitionNode else {
            return
        }
        
        let source = AnimatedStickerResourceSource(account: item.context.account, resource: resource, fitzModifier: nil)
        
        let animationSize: CGSize?
        let animationNodeFrame: CGRect?
        if let size = self.animationSize, let node = self.animationNode {
            animationSize = size
            animationNodeFrame = node.frame
        } else if let _ = self.emojiString {
            animationSize = CGSize(width: 384.0, height: 384.0)
            animationNodeFrame = self.textNode.textNode.frame
        } else {
            animationSize = nil
            animationNodeFrame = nil
        }
        
        guard let animationSize = animationSize, let animationNodeFrame = animationNodeFrame else {
            return
        }
        if self.additionalAnimationNodes.count >= 4 {
            return
        }
        if let animationNode = animationNode as? AnimatedStickerNode {
            let _ = animationNode.playIfNeeded()
        }
        
        let incomingMessage = item.message.effectivelyIncoming(item.context.account.peerId)

        do {
            let pathPrefix = item.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(resource.id)
            let additionalAnimationNode = DefaultAnimatedStickerNodeImpl()
            additionalAnimationNode.setup(source: source, width: Int(animationSize.width * 1.6), height: Int(animationSize.height * 1.6), playbackMode: .once, mode: .direct(cachePathPrefix: pathPrefix))
            var animationFrame: CGRect
            if isStickerEffect {
                let scale: CGFloat = 0.245
                animationFrame = animationNodeFrame.offsetBy(dx: incomingMessage ? animationNodeFrame.width * scale - 21.0 : -animationNodeFrame.width * scale + 21.0, dy: -1.0).insetBy(dx: -animationNodeFrame.width * scale, dy: -animationNodeFrame.height * scale)
            } else {
                animationFrame = animationNodeFrame.insetBy(dx: -animationNodeFrame.width, dy: -animationNodeFrame.height)
                    .offsetBy(dx: incomingMessage ? animationNodeFrame.width - 10.0 : -animationNodeFrame.width + 10.0, dy: 0.0)
                animationFrame = animationFrame.offsetBy(dx: CGFloat.random(in: -30.0 ... 30.0), dy: CGFloat.random(in: -30.0 ... 30.0))
            }
                        
            animationFrame = animationFrame.offsetBy(dx: 0.0, dy: self.insets.top)
            additionalAnimationNode.frame = animationFrame
            if incomingMessage {
                additionalAnimationNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            }

            let decorationNode = transitionNode.add(decorationView: additionalAnimationNode.view, itemNode: self, aboveEverything: true)
            additionalAnimationNode.completed = { [weak self, weak decorationNode, weak transitionNode] _ in
                guard let decorationNode = decorationNode else {
                    return
                }
                self?.additionalAnimationNodes.removeAll(where: { $0 === decorationNode })
                transitionNode?.remove(decorationNode: decorationNode)
            }
            additionalAnimationNode.isPlayingChanged = { [weak self, weak decorationNode, weak transitionNode] isPlaying in
                if !isPlaying {
                    guard let decorationNode = decorationNode else {
                        return
                    }
                    self?.additionalAnimationNodes.removeAll(where: { $0 === decorationNode })
                    transitionNode?.remove(decorationNode: decorationNode)
                }
            }

            self.additionalAnimationNodes.append(decorationNode)

            additionalAnimationNode.visibility = true
        }
    }
    
    private func removeAdditionalAnimations() {
        for decorationNode in self.additionalAnimationNodes {
            if let additionalAnimationNode = decorationNode.contentView.asyncdisplaykit_node as? AnimatedStickerNode {
                additionalAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak additionalAnimationNode] _ in
                    additionalAnimationNode?.visibility = false
                })
            }
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
             
            if let item = self.item, let emojiString = self.emojiString, emojiString.emojis.count > 1 {
                if let (_, attributes) = self.textNode.textNode.attributesAtPoint(self.view.convert(location, to: self.textNode.textNode.view)) {
                   for (_, attribute) in attributes {
                       if let attribute = attribute as? ChatTextInputTextCustomEmojiAttribute, let file = attribute.file {
                           return .optionalAction({
                               item.controllerInteraction.displayEmojiPackTooltip(file, item.message)
                           })
                       }
                   }
               }
            } else if let item = self.item, self.imageNode.frame.contains(location) {
                let emojiTapAction: (Bool) -> InternalBubbleTapAction? = { shouldPlay in
                    let beatingHearts: [UInt32] = [0x2764, 0x1F90E, 0x1F9E1, 0x1F499, 0x1F49A, 0x1F49C, 0x1F49B, 0x1F5A4, 0x1F90D]
                    let heart = 0x2764
                    let peach = 0x1F351
                    let coffin = 0x26B0
                    
                    let appConfiguration = item.context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
                    |> take(1)
                    |> map { view in
                        return view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
                    }
                    
                    let text = item.message.text
                    if var firstScalar = text.unicodeScalars.first {
                        var textEmoji = text.strippedEmoji
                        var additionalTextEmoji = textEmoji
                        if beatingHearts.contains(firstScalar.value) {
                            textEmoji = "❤️"
                            firstScalar = UnicodeScalar(heart)!
                        }
                        
                        let (basicEmoji, fitz) = text.basicEmoji
                        if ["💛", "💙", "💚", "💜", "🧡", "🖤", "🤎", "🤍", "❤️"].contains(textEmoji) {
                            additionalTextEmoji = "❤️".strippedEmoji
                        } else if fitz != nil {
                            additionalTextEmoji = basicEmoji
                        }
                        
                        let syncAnimations = item.message.id.peerId.namespace == Namespaces.Peer.CloudUser
                    
                        return .optionalAction({
                            var haptic: EmojiHaptic?
                            if let current = self.haptic {
                                haptic = current
                            } else {
                                if firstScalar.value == heart {
                                    haptic = HeartbeatHaptic()
                                } else if firstScalar.value == coffin {
                                    haptic = CoffinHaptic()
                                } else if firstScalar.value == peach {
                                    haptic = PeachHaptic()
                                }
                                haptic?.enabled = true
                                self.haptic = haptic
                            }
                            
                            if syncAnimations, let animationItems = item.associatedData.additionalAnimatedEmojiStickers[additionalTextEmoji] {
                                let playHaptic = haptic == nil
                                
                                var hapticFeedback: HapticFeedback
                                if let current = self.hapticFeedback {
                                    hapticFeedback = current
                                } else {
                                    hapticFeedback = HapticFeedback()
                                    self.hapticFeedback = hapticFeedback
                                }
                                
                                if syncAnimations {
                                    self.startAdditionalAnimationsCommitTimer()
                                }
                                
                                let timestamp = CACurrentMediaTime()
                                let previousAnimation = self.enqueuedAdditionalAnimations.last
                                
                                var availableAnimations = animationItems
                                var delay: Double = 0.0
                                if availableAnimations.count > 1, let (previousIndex, _) = previousAnimation {
                                    availableAnimations.removeValue(forKey: previousIndex)
                                }
                                if let (_, previousTimestamp) = previousAnimation {
                                    delay = min(0.15, max(0.0, previousTimestamp + 0.15 - timestamp))
                                }
                                if let index = availableAnimations.randomElement()?.0 {
                                    if delay > 0.0 {
                                        Queue.mainQueue().after(delay) {
                                            if playHaptic {
                                                if previousAnimation == nil {
                                                    hapticFeedback.impact(.light)
                                                } else {
                                                    let style: ImpactHapticFeedbackStyle
                                                    if self.enqueuedAdditionalAnimations.count == 1 {
                                                        style = .medium
                                                    } else {
                                                        style = [.light, .medium].randomElement() ?? .medium
                                                    }
                                                    hapticFeedback.impact(style)
                                                }
                                            }
                                            
                                            if syncAnimations {
                                                self.enqueuedAdditionalAnimations.append((index, timestamp + delay))
                                            }
                                            self.playAdditionalEmojiAnimation(index: index)
                                            
                                            if syncAnimations, self.additionalAnimationsCommitTimer == nil {
                                                self.startAdditionalAnimationsCommitTimer()
                                            }
                                        }
                                    } else {
                                        if playHaptic {
                                            if previousAnimation == nil {
                                                hapticFeedback.impact(.light)
                                            } else {
                                                let style: ImpactHapticFeedbackStyle
                                                if self.enqueuedAdditionalAnimations.count == 1 {
                                                    style = .medium
                                                } else {
                                                    style = [.light, .medium].randomElement() ?? .medium
                                                }
                                                hapticFeedback.impact(style)
                                            }
                                        }
                                        
                                        if syncAnimations {
                                            self.enqueuedAdditionalAnimations.append((index, timestamp))
                                        }
                                        self.playAdditionalEmojiAnimation(index: index)
                                    }
                                }
                            } else if let emojiString = self.emojiString, emojiString.count == 1 {
                                let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
                            }
                            
                            if shouldPlay {
                                let _ = (appConfiguration
                                |> deliverOnMainQueue).startStandalone(next: { [weak self] appConfiguration in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    let emojiSounds = AnimatedEmojiSoundsConfiguration.with(appConfiguration: appConfiguration, account: item.context.account)
                                    var hasSound = false
                                    for (emoji, file) in emojiSounds.sounds {
                                        if emoji.strippedEmoji == textEmoji.strippedEmoji {
                                            hasSound = true
                                            let mediaManager = item.context.sharedContext.mediaManager
                                            let mediaPlayer = MediaPlayer(audioSessionManager: mediaManager.audioSession, postbox: item.context.account.postbox, userLocation: .peer(item.message.id.peerId), userContentType: .other, resourceReference: .standalone(resource: file.resource), streamable: .none, video: false, preferSoftwareDecoding: false, enableSound: true, fetchAutomatically: true, ambient: true)
                                            mediaPlayer.togglePlayPause()
                                            mediaPlayer.actionAtEnd = .action({ [weak self] in
                                                self?.mediaPlayer = nil
                                            })
                                            strongSelf.mediaPlayer = mediaPlayer
                                            
                                            strongSelf.mediaStatusDisposable.set((mediaPlayer.status
                                            |> deliverOnMainQueue).startStrict(next: { [weak self] status in
                                                if let strongSelf = self {
                                                    if let haptic = haptic, !haptic.active {
                                                        haptic.start(time: 0.0)
                                                    }
                                                    
                                                    switch status.status {
                                                        case .playing:
                                                            if let animationNode = strongSelf.animationNode as? AnimatedStickerNode {
                                                                animationNode.play(firstFrame: false, fromIndex: nil)
                                                            }
                                                            strongSelf.mediaStatusDisposable.set(nil)
                                                        default:
                                                            break
                                                    }
                                                }
                                            }))
                                            return
                                        }
                                    }
                                    if !hasSound {
                                        if let haptic = haptic, !haptic.active {
                                            haptic.start(time: 0.0)
                                        }
                                        if let animationNode = strongSelf.animationNode as? AnimatedStickerNode {
                                            animationNode.play(firstFrame: false, fromIndex: nil)
                                        }
                                    }
                                })
                            }
                        })
                    }
                    return nil
                }
                
                if let emojiString = self.emojiString, emojiString.count == 1 {
                    return emojiTapAction(false)
                }
                if let file = self.telegramFile {
                    let noPremium = item.message.attributes.contains(where: { attribute in
                        if attribute is NonPremiumMessageAttribute {
                            return true
                        } else {
                            return false
                        }
                    })
                    
                    if file.isPremiumSticker && !noPremium {
                        return .optionalAction({
                            if self.additionalAnimationNodes.isEmpty {
                                self.playedPremiumStickerAnimation = false
                                self.playPremiumStickerAnimation()
                            } else {
                                item.controllerInteraction.displayPremiumStickerTooltip(file, item.message)
                            }
                        })
                    } else {
                        return .optionalAction({
                            let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
                        })
                    }
                } else if let dice = self.telegramDice {
                    return .optionalAction({
                        item.controllerInteraction.displayDiceTooltip(dice)
                    })
                } else if let emojiFile = self.emojiFile {
                    if let animationNode = self.animationNode as? AnimatedStickerNode, let _ = recognizer {
                        var shouldPlay = false
                        if !animationNode.isPlaying && !emojiFile.isCustomEmoji {
                            shouldPlay = true
                        }
                        if let result = emojiTapAction(shouldPlay) {
                            return result
                        }
                    }
                }
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
            let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: animated)
                let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                selectionNode.frame = selectionFrame
                selectionNode.updateLayout(size: selectionFrame.size, leftInset: self.safeInsets.left)
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
                    self.animationNode?.setOverlayColor(item.presentationData.theme.theme.chat.message.mediaHighlightOverlayColor, replace: false, animated: false)
                } else {
                    self.imageNode.setOverlayColor(nil, animated: animated)
                    self.animationNode?.setOverlayColor(nil, replace: false, animated: false)
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
        
        if let telegramDice = self.telegramDice, let item = self.item, item.message.effectivelyIncoming(item.context.account.peerId) {
            if let value = telegramDice.value, value != 0 {
                if let diceNode = self.animationNode as? ManagedDiceAnimationNode {
                    diceNode.setState(.rolling)
                    diceNode.setState(.value(value, false))
                } else if let diceNode = self.animationNode as? SlotMachineAnimationNode {
                    diceNode.setState(.rolling)
                    diceNode.setState(.value(value, false))
                }
            }
        }
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
        if let animationNode = self.animationNode {
            transition.animatePositionAdditive(layer: animationNode.layer, offset: offset)
            transition.horizontal.animateTransformScale(node: animationNode, from: sourceScale)
        }
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
        if let animationNode = self.animationNode {
            animationNode.layer.animateAlpha(from: 0.0, to: animationNode.alpha, duration: 0.1)
        }
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

        let snapshotView: UIView? = stickerSource.snapshotContentTree()
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
        if let animationNode = self.animationNode {
            transition.animatePositionAdditive(layer: animationNode.layer, offset: offset)
            transition.horizontal.animateTransformScale(node: animationNode, from: sourceScale)
        }
        transition.animatePositionAdditive(layer: self.placeholderNode.layer, offset: offset)
        transition.horizontal.animateTransformScale(node: self.placeholderNode, from: sourceScale)

        let inverseScale = 1.0 / sourceScale

        if let snapshotView = snapshotView {
            transition.animatePositionAdditive(layer: snapshotView.layer, offset: CGPoint(), to: CGPoint(
                x: -offset.x - localSourceOffset.x * (inverseScale - 1.0),
                y: -offset.y - localSourceOffset.y * (inverseScale - 1.0)
            ), removeOnCompletion: false)
            transition.horizontal.updateTransformScale(layer: snapshotView.layer, scale: 1.0 / sourceScale)

            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })

            self.imageNode.layer.animateAlpha(from: 0.0, to: self.imageNode.alpha, duration: 0.05)
            if let animationNode = self.animationNode {
                animationNode.layer.animateAlpha(from: 0.0, to: animationNode.alpha, duration: 0.05)
            }
            self.placeholderNode.layer.animateAlpha(from: 0.0, to: self.placeholderNode.alpha, duration: 0.05)
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
    
    override public func targetReactionView(value: MessageReaction.Reaction) -> UIView? {
        if let result = self.reactionButtonsNode?.reactionTargetView(value: value) {
            return result
        }
        if !self.dateAndStatusNode.isHidden {
            return self.dateAndStatusNode.reactionView(value: value)
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
    
    override public func unreadMessageRangeUpdated() {
        self.updateVisibility()
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
    
    override public func messageEffectTargetView() -> UIView? {
        if let result = self.dateAndStatusNode.messageEffectTargetView() {
            return result
        }
        
        return nil
    }
}

public struct AnimatedEmojiSoundsConfiguration {
    public static var defaultValue: AnimatedEmojiSoundsConfiguration {
        return AnimatedEmojiSoundsConfiguration(sounds: [:])
    }
    
    public let sounds: [String: TelegramMediaFile]
    
    fileprivate init(sounds: [String: TelegramMediaFile]) {
        self.sounds = sounds
    }
    
    public static func with(appConfiguration: AppConfiguration, account: Account) -> AnimatedEmojiSoundsConfiguration {
        if let data = appConfiguration.data, let values = data["emojies_sounds"] as? [String: Any] {
            var sounds: [String: TelegramMediaFile] = [:]
            for (key, value) in values {
                if let dict = value as? [String: String], var fileReferenceString = dict["file_reference_base64"] {
                    fileReferenceString = fileReferenceString.replacingOccurrences(of: "-", with: "+")
                    fileReferenceString = fileReferenceString.replacingOccurrences(of: "_", with: "/")
                    while fileReferenceString.count % 4 != 0 {
                        fileReferenceString.append("=")
                    }
                    
                    if let idString = dict["id"], let id = Int64(idString), let accessHashString = dict["access_hash"], let accessHash = Int64(accessHashString), let fileReference = Data(base64Encoded: fileReferenceString) {
                        let resource = CloudDocumentMediaResource(datacenterId: 1, fileId: id, accessHash: accessHash, size: nil, fileReference: fileReference, fileName: nil)
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: nil, attributes: [], alternativeRepresentations: [])
                        sounds[key] = file
                    }
                }
            }
            return AnimatedEmojiSoundsConfiguration(sounds: sounds)
        } else {
            return .defaultValue
        }
    }
}

private func fontSizeForEmojiString(_ string: String) -> CGFloat {
    let lines = string.components(separatedBy: "\n")
    
    var maxLineLength = 0
    for line in lines {
        maxLineLength = max(maxLineLength, line.replacingOccurrences(of: " ", with: "").count)
    }
    
    let linesCount = lines.count
    
    let length = max(maxLineLength, linesCount)
    
    let basicSize: CGFloat = 94.0
    let multiplier: CGFloat
    switch length {
        case 1:
            multiplier = 1.0
        case 2:
            multiplier = 0.84
        case 3:
            multiplier = 0.69
        case 4:
            multiplier = 0.53
        case 5:
            multiplier = 0.46
        case 6:
            multiplier = 0.38
        case 7:
            multiplier = 0.32
        case 8:
            multiplier = 0.27
        case 9:
            multiplier = 0.24
        default:
            multiplier = 0.21
    }
    return floor(basicSize * multiplier)
}
