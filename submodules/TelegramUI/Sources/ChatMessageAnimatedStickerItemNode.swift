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
import LottieMeshSwift
import ChatPresentationInterfaceState

private let nameFont = Font.medium(14.0)
private let inlineBotPrefixFont = Font.regular(14.0)
private let inlineBotNameFont = nameFont

protocol GenericAnimatedStickerNode: ASDisplayNode {
    func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool)

    var currentFrameIndex: Int { get }
    func setFrameIndex(_ frameIndex: Int)
}

extension DefaultAnimatedStickerNodeImpl: GenericAnimatedStickerNode {
    func setFrameIndex(_ frameIndex: Int) {
        self.stop()
        self.play(fromIndex: frameIndex)
    }
}

extension SlotMachineAnimationNode: GenericAnimatedStickerNode {
    var currentFrameIndex: Int {
        return 0
    }

    func setFrameIndex(_ frameIndex: Int) {
    }
}

class ChatMessageShareButton: HighlightableButtonNode {
    private let backgroundNode: NavigationBackgroundNode
    private let iconNode: ASImageNode
    private var iconOffset = CGPoint()
    
    private var theme: PresentationTheme?
    private var isReplies: Bool = false
    
    private var textNode: ImmediateTextNode?
    
    init() {
        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        self.iconNode = ASImageNode()
        
        super.init(pointerStyle: nil)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(presentationData: ChatPresentationData, chatLocation: ChatLocation, subject: ChatControllerSubject?, message: Message, account: Account, disableComments: Bool = false) -> CGSize {
        var isReplies = false
        var replyCount = 0
        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyThreadMessageAttribute {
                    replyCount = Int(attribute.count)
                    isReplies = true
                    break
                }
            }
        }
        if case let .replyThread(replyThreadMessage) = chatLocation, replyThreadMessage.effectiveTopId == message.id {
            replyCount = 0
            isReplies = false
        }
        if disableComments {
            replyCount = 0
            isReplies = false
        }
        
        if self.theme !== presentationData.theme.theme || self.isReplies != isReplies {
            self.theme = presentationData.theme.theme
            self.isReplies = isReplies

            var updatedIconImage: UIImage?
            var updatedIconOffset = CGPoint()
            if case .pinnedMessages = subject {
                updatedIconImage = PresentationResourcesChat.chatFreeNavigateButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
            } else if isReplies {
                updatedIconImage = PresentationResourcesChat.chatFreeCommentButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
            } else if message.id.peerId.isRepliesOrSavedMessages(accountPeerId: account.peerId) {
                updatedIconImage = PresentationResourcesChat.chatFreeNavigateButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                updatedIconOffset = CGPoint(x: UIScreenPixel, y: 1.0)
            } else {
                updatedIconImage = PresentationResourcesChat.chatFreeShareButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
            }
            self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), enableBlur: dateFillNeedsBlur(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), transition: .immediate)
            self.iconNode.image = updatedIconImage
            self.iconOffset = updatedIconOffset
        }
        var size = CGSize(width: 30.0, height: 30.0)
        var offsetIcon = false
        if isReplies, replyCount > 0 {
            offsetIcon = true
            
            let textNode: ImmediateTextNode
            if let current = self.textNode {
                textNode = current
            } else {
                textNode = ImmediateTextNode()
                self.textNode = textNode
                self.addSubnode(textNode)
            }
            
            let textColor = bubbleVariableColor(variableColor: presentationData.theme.theme.chat.message.shareButtonForegroundColor, wallpaper: presentationData.theme.wallpaper)
            
            let countString: String
            if replyCount >= 1000 * 1000 {
                countString = "\(replyCount / 1000_000)M"
            } else if replyCount >= 1000 {
                countString = "\(replyCount / 1000)K"
            } else {
                countString = "\(replyCount)"
            }
            
            textNode.attributedText = NSAttributedString(string: countString, font: Font.regular(11.0), textColor: textColor)
            let textSize = textNode.updateLayout(CGSize(width: 100.0, height: 100.0))
            size.height += textSize.height - 1.0
            textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: size.height - textSize.height - 4.0), size: textSize)
        } else if let textNode = self.textNode {
            self.textNode = nil
            textNode.removeFromSupernode()
        }
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: min(self.backgroundNode.bounds.width, self.backgroundNode.bounds.height) / 2.0, transition: .immediate)
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0) + self.iconOffset.x, y: floor((size.width - image.size.width) / 2.0) - (offsetIcon ? 1.0 : 0.0) + self.iconOffset.y), size: image.size)
        }
        return size
    }
}

class ChatMessageAnimatedStickerItemNode: ChatMessageItemView {
    let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    let imageNode: TransformImageNode
    private var enableSynchronousImageApply: Bool = false
    private var backgroundNode: WallpaperBubbleBackgroundNode?
    private(set) var placeholderNode: StickerShimmerEffectNode
    private(set) var animationNode: GenericAnimatedStickerNode?
    private var animationSize: CGSize?
    private var didSetUpAnimationNode = false
    private var isPlaying = false
    
    private var additionalAnimationNodes: [ChatMessageTransitionNode.DecorationItemNode] = []
    private var overlayMeshAnimationNode: ChatMessageTransitionNode.DecorationItemNode?
    private var enqueuedAdditionalAnimations: [(Int, Double)] = []
    private var additionalAnimationsCommitTimer: SwiftSignalKit.Timer?
  
    private var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    private var swipeToReplyFeedback: HapticFeedback?
    
    private var selectionNode: ChatMessageSelectionNode?
    private var deliveryFailedNode: ChatMessageDeliveryFailedNode?
    private var shareButtonNode: ChatMessageShareButton?
    
    var telegramFile: TelegramMediaFile?
    var emojiFile: TelegramMediaFile?
    var telegramDice: TelegramMediaDice?
    private let disposable = MetaDisposable()
    private let disposables = DisposableSet()

    private var viaBotNode: TextNode?
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private var replyInfoNode: ChatMessageReplyInfoNode?
    private var replyBackgroundNode: NavigationBackgroundNode?
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    
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
    
    private var currentSwipeAction: ChatControllerInteractionSwipeAction?
    
    private var wasPending: Bool = false
    private var didChangeFromPendingToSent: Bool = false
    
    required init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.imageNode = TransformImageNode()
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode.isUserInteractionEnabled = false
        
        self.messageAccessibilityArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false)
        
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
                case let .openContextMenu(tapMessage, selectAll, subFrame):
                    item.controllerInteraction.openMessageContextMenu(tapMessage, selectAll, strongSelf, subFrame, gesture)
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
    
    required init?(coder aDecoder: NSCoder) {
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
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let shareButtonNode = strongSelf.shareButtonNode, shareButtonNode.frame.contains(point) {
                    return .fail
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
        self.view.addGestureRecognizer(recognizer)
        
        let replyRecognizer = ChatSwipeToReplyRecognizer(target: self, action: #selector(self.swipeToReplyGesture(_:)))
        replyRecognizer.shouldBegin = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                if strongSelf.selectionNode != nil {
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
        self.view.addGestureRecognizer(replyRecognizer)
    }
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = oldValue != .none
            let isVisible = self.visibility != .none
            
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
            }
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                self.updateVisibility()
                self.haptic?.enabled = self.visibilityStatus
            }
        }
    }
    
    private var setupTimestamp: Double?
    private func setupNode(item: ChatMessageItem) {
        guard self.animationNode == nil else {
            return
        }
        
        if let telegramDice = self.telegramDice {
            if telegramDice.emoji == "🎰" {
                let animationNode = SlotMachineAnimationNode(account: item.context.account)
                if !item.message.effectivelyIncoming(item.context.account.peerId) {
                    animationNode.success = { [weak self] onlyHaptic in
                        if let strongSelf = self, let item = strongSelf.item {
                            item.controllerInteraction.animateDiceSuccess(onlyHaptic)
                        }
                    }
                }
                self.animationNode = animationNode
            } else {
                let animationNode = ManagedDiceAnimationNode(context: item.context, emoji: telegramDice.emoji.strippedEmoji)
                if !item.message.effectivelyIncoming(item.context.account.peerId) {
                    animationNode.success = { [weak self] in
                        if let strongSelf = self, let item = strongSelf.item {
                            item.controllerInteraction.animateDiceSuccess(false)
                        }
                    }
                }
                self.animationNode = animationNode
            }
        } else {
            let animationNode = DefaultAnimatedStickerNodeImpl(useMetalCache: item.context.sharedContext.immediateExperimentalUISettings.acceleratedStickers)
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
                        if let _ = strongSelf.emojiFile {
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
    
    override func setupItem(_ item: ChatMessageItem, synchronousLoad: Bool) {
        super.setupItem(item, synchronousLoad: synchronousLoad)
        
        if item.message.id.namespace == Namespaces.Message.Local {
            self.wasPending = true
        }
        if self.wasPending && item.message.id.namespace != Namespaces.Message.Local {
            self.didChangeFromPendingToSent = true
        }
                
        for media in item.message.media {
            if let telegramFile = media as? TelegramMediaFile {
                if self.telegramFile?.id != telegramFile.id {
                    self.telegramFile = telegramFile
                    let dimensions = telegramFile.dimensions ?? PixelDimensions(width: 512, height: 512)
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: item.context.account.postbox, file: telegramFile, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0)), thumbnail: false, synchronousLoad: synchronousLoad), attemptSynchronously: synchronousLoad)
                    self.updateVisibility()
                    self.disposable.set(freeMediaFileInteractiveFetched(account: item.context.account, fileReference: .message(message: MessageReference(item.message), media: telegramFile)).start())
                    
                    if telegramFile.isPremiumSticker {
                        if let effect = telegramFile.videoThumbnails.first {
                            self.disposables.add(freeMediaFileResourceInteractiveFetched(account: item.context.account, fileReference: .message(message: MessageReference(item.message), media: telegramFile), resource: effect.resource) .start())
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
            
            emojiFile = item.associatedData.animatedEmojiStickers[emoji]?.first?.file
            if emojiFile == nil {
                emojiFile = item.associatedData.animatedEmojiStickers[emoji.strippedEmoji]?.first?.file
            }
            
            if self.emojiFile?.id != emojiFile?.id {
                self.emojiFile = emojiFile
                if let emojiFile = emojiFile {
                    let dimensions = emojiFile.dimensions ?? PixelDimensions(width: 512, height: 512)
                    var fitzModifier: EmojiFitzModifier?
                    if let fitz = fitz {
                        fitzModifier = EmojiFitzModifier(emoji: fitz)
                    }
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: item.context.account.postbox, file: emojiFile, small: false, size: dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0)), fitzModifier: fitzModifier, thumbnail: false, synchronousLoad: synchronousLoad), attemptSynchronously: synchronousLoad)
                    self.disposable.set(freeMediaFileInteractiveFetched(account: item.context.account, fileReference: .standalone(media: emojiFile)).start())
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
                if let items = item.associatedData.additionalAnimatedEmojiStickers[textEmoji] {
                    animationItems = items
                } else if let items = item.associatedData.additionalAnimatedEmojiStickers[additionalTextEmoji] {
                    animationItems = items
                }
                
                if let animationItems = animationItems {
                    for (_, animationItem) in animationItems {
                        self.disposables.add(freeMediaFileInteractiveFetched(account: item.context.account, fileReference: .standalone(media: animationItem.file)).start())
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
            if !item.controllerInteraction.stickerSettings.loopAnimatedStickers {
                playbackMode = .once
            }
        } else if let emojiFile = self.emojiFile {
            isEmoji = true
            file = emojiFile
            //if alreadySeen && emojiFile.resource is LocalFileReferenceMediaResource {
                playbackMode = .still(.end)
            //} else {
            //    playbackMode = .once
            //}
            let (_, fitz) = item.message.text.basicEmoji
            if let fitz = fitz {
                fitzModifier = EmojiFitzModifier(emoji: fitz)
            }
        }
        
        let isPlaying = self.visibilityStatus && !self.forceStopAnimations
        if let animationNode = self.animationNode as? AnimatedStickerNode {
            if !isPlaying {
                for decorationNode in self.additionalAnimationNodes {
                    if let transitionNode = item.controllerInteraction.getMessageTransitionNode() {
                        decorationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak decorationNode] _ in
                            if let decorationNode = decorationNode {
                                transitionNode.remove(decorationNode: decorationNode)
                            }
                        })
                    }
                }
                self.additionalAnimationNodes.removeAll()

                if let overlayMeshAnimationNode = self.overlayMeshAnimationNode {
                    self.overlayMeshAnimationNode = nil
                    if let transitionNode = item.controllerInteraction.getMessageTransitionNode() {
                        transitionNode.remove(decorationNode: overlayMeshAnimationNode)
                    }
                }
            }
            
            if self.isPlaying != isPlaying {
                self.isPlaying = isPlaying
                
                if isPlaying && self.setupTimestamp == nil {
                    self.setupTimestamp = CACurrentMediaTime()
                }
                animationNode.visibility = isPlaying
                
                /*if self.didSetUpAnimationNode && alreadySeen {
                    if let emojiFile = self.emojiFile, emojiFile.resource is LocalFileReferenceMediaResource {
                    } else {
                        animationNode.seekTo(.start)
                    }
                }*/
                
                if self.isPlaying && !self.didSetUpAnimationNode {
                    self.didSetUpAnimationNode = true

                    if let file = file {
                        let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                        let fittedSize = isEmoji ? dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0)) : dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0))
                        
                        let pathPrefix = item.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                        let mode: AnimatedStickerMode = .direct(cachePathPrefix: pathPrefix)
                        self.animationSize = fittedSize
                        animationNode.setup(source: AnimatedStickerResourceSource(account: item.context.account, resource: file.resource, fitzModifier: fitzModifier, isVideo: file.isVideoSticker), width: Int(fittedSize.width), height: Int(fittedSize.height), playbackMode: playbackMode, mode: mode)
                    }
                }
            }
        }
        
        if isPlaying, let animationNode = self.animationNode as? AnimatedStickerNode {
            var alreadySeen = true
            if isEmoji {
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
                if let file = file, file.isPremiumSticker {
                    Queue.mainQueue().after(0.1) {
                        self.playPremiumStickerAnimation()
                    }
                } else if isEmoji {
                    animationNode.seekTo(.start)
                    animationNode.playOnce()
                }
            }
        }
    }
    
    override func updateStickerSettings(forceStopAnimations: Bool) {
        self.forceStopAnimations = forceStopAnimations
        self.updateVisibility()
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        if !self.contextSourceNode.isExtractedToContextPreview {
            var rect = rect
            rect.origin.y = containerSize.height - rect.maxY + self.insets.top

            self.placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + self.placeholderNode.frame.minX, y: rect.minY + self.placeholderNode.frame.minY), size: self.placeholderNode.frame.size), within: containerSize)
            
            if let backgroundNode = self.backgroundNode {
                backgroundNode.update(rect: CGRect(origin: CGPoint(x: rect.minX + self.placeholderNode.frame.minX, y: rect.minY + self.placeholderNode.frame.minY), size: self.placeholderNode.frame.size), within: containerSize, transition: .immediate)
            }
            
            if let reactionButtonsNode = self.reactionButtonsNode {
                var reactionButtonsNodeFrame = reactionButtonsNode.frame
                reactionButtonsNodeFrame.origin.x += rect.minX
                reactionButtonsNodeFrame.origin.y += rect.minY
                
                reactionButtonsNode.update(rect: rect, within: containerSize, transition: .immediate)
            }
        }
    }
    
    override func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
        
        if let reactionButtonsNode = self.reactionButtonsNode {
            reactionButtonsNode.offset(value: value, animationCurve: animationCurve, duration: duration)
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
                        item.controllerInteraction.openMessageContextMenu(item.message, false, self, self.imageNode.frame, nil)
                    }
            }
        }
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) {
        var displaySize = CGSize(width: 180.0, height: 180.0)
        let telegramFile = self.telegramFile
        let emojiFile = self.emojiFile
        let telegramDice = self.telegramDice
        let layoutConstants = self.layoutConstants
        let imageLayout = self.imageNode.asyncLayout()
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        let actionButtonsLayout = ChatMessageActionButtonsNode.asyncLayout(self.actionButtonsNode)
        let reactionButtonsLayout = ChatMessageReactionButtonsNode.asyncLayout(self.reactionButtonsNode)
        
        let makeForwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        
        let viaBotLayout = TextNode.asyncLayout(self.viaBotNode)
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentShareButtonNode = self.shareButtonNode
        let currentForwardInfo = self.appliedForwardInfo
        
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom in
            let accessibilityData = ChatMessageAccessibilityData(item: item, isSelected: nil)
            let layoutConstants = chatMessageItemLayoutConstants(layoutConstants, params: params, presentationData: item.presentationData)
            let incoming = item.content.effectivelyIncoming(item.context.account.peerId, associatedData: item.associatedData)
                        
            var imageSize: CGSize = CGSize(width: 200.0, height: 200.0)
            var imageVerticalInset: CGFloat = 0.0
            var imageHorizontalOffset: CGFloat = 0.0
            if !(telegramFile?.videoThumbnails.isEmpty ?? true) {
                displaySize = CGSize(width: 240.0, height: 240.0)
                imageVerticalInset = -20.0
                imageHorizontalOffset = 12.0
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
                if let dimensions = emojiFile.dimensions {
                    imageSize = CGSize(width: displaySize.width * CGFloat(dimensions.width) / 512.0, height: displaySize.height * CGFloat(dimensions.height) / 512.0)
                } else if let thumbnailSize = emojiFile.previewRepresentations.first?.dimensions {
                    imageSize = thumbnailSize.cgSize.aspectFitted(displaySize)
                }
            }
            
            let avatarInset: CGFloat
            var hasAvatar = false
            
            switch item.chatLocation {
            case let .peer(peerId):
                if peerId != item.context.account.peerId {
                    if peerId.isGroupOrChannel && item.message.author != nil {
                        var isBroadcastChannel = false
                        if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                            isBroadcastChannel = true
                        }
                        
                        if !isBroadcastChannel {
                            hasAvatar = true
                        } else if case .feed = item.chatLocation {
                            hasAvatar = true
                        }
                    }
                } else if incoming {
                    hasAvatar = true
                }
            case let .replyThread(replyThreadMessage):
                if replyThreadMessage.messageId.peerId != item.context.account.peerId {
                    if replyThreadMessage.messageId.peerId.isGroupOrChannel && item.message.author != nil {
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
            case .feed:
                hasAvatar = true
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
            } else if isFailed || Namespaces.Message.allScheduled.contains(item.message.id.namespace) {
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
                    needsShareButton = false
                }
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
            
            let imageInset: CGFloat = 10.0
            var innerImageSize = imageSize
            imageSize = CGSize(width: imageSize.width + imageInset * 2.0, height: imageSize.height + imageInset * 2.0)
            let imageFrame = CGRect(origin: CGPoint(x: 0.0 + (incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + avatarInset + layoutConstants.bubble.contentInsets.left) : (params.width - params.rightInset - imageSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - deliveryFailedInset - imageHorizontalOffset)), y: imageVerticalInset), size: CGSize(width: imageSize.width, height: imageSize.height))
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
            let dateReactionsAndPeers = mergedMessageReactionsAndPeers(message: item.message)
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
            
            let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: .regular)
            
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
                layoutInput: .standalone(reactionSettings: shouldDisplayInlineDateReactions(message: item.message) ? ChatMessageDateAndStatusNode.StandaloneReactionSettings() : nil),
                constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude),
                availableReactions: item.associatedData.availableReactions,
                reactions: dateReactionsAndPeers.reactions,
                reactionPeers: dateReactionsAndPeers.peers,
                replyCount: dateReplies,
                isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && !isReplyThread,
                hasAutoremove: item.message.isSelfExpiring,
                canViewReactionList: canViewMessageReactionList(message: item.message)
            ))
            
            let (dateAndStatusSize, dateAndStatusApply) = statusSuggestedWidthAndContinue.1(statusSuggestedWidthAndContinue.0)
            
            var viaBotApply: (TextNodeLayout, () -> TextNode)?
            var replyInfoApply: (CGSize, () -> ChatMessageReplyInfoNode)?
            var needsReplyBackground = false
            var replyMarkup: ReplyMarkupMessageAttribute?
            
            let availableContentWidth = max(60.0, params.width - params.leftInset - params.rightInset - max(imageSize.width, 160.0) - 20.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left)
            
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
            
            for attribute in item.message.attributes {
                if let attribute = attribute as? InlineBotMessageAttribute {
                    var inlineBotNameString: String?
                    if let peerId = attribute.peerId, let bot = item.message.peers[peerId] as? TelegramUser {
                        inlineBotNameString = bot.username
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
                if let replyAttribute = attribute as? ReplyMessageAttribute, let replyMessage = item.message.associatedMessages[replyAttribute.messageId] {
                    if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.messageId == replyAttribute.messageId {
                    } else {
                        replyInfoApply = makeReplyInfoLayout(item.presentationData, item.presentationData.strings, item.context, .standalone, replyMessage, item.message, CGSize(width: availableContentWidth, height: CGFloat.greatestFiniteMagnitude))
                    }
                } else if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
                    replyMarkup = attribute
                }
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
            
            let contentHeight = max(imageSize.height + imageVerticalInset * 2.0, layoutConstants.image.minDimensions.height)
            
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
                forwardInfoSizeApply = makeForwardInfoLayout(item.presentationData, item.presentationData.strings, .standalone, forwardSource, forwardAuthorSignature, forwardPsaType, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
            }
            
            if replyInfoApply != nil || viaBotApply != nil || forwardInfoSizeApply != nil {
                needsReplyBackground = true
            }
            
            var maxContentWidth = imageSize.width
            var actionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animation: ListViewItemUpdateAnimation) -> ChatMessageActionButtonsNode))?
            if let replyMarkup = replyMarkup {
                let (minWidth, buttonsLayout) = actionButtonsLayout(item.context, item.presentationData.theme, item.presentationData.chatBubbleCorners, item.presentationData.strings, replyMarkup, item.message, maxContentWidth)
                maxContentWidth = max(maxContentWidth, minWidth)
                actionButtonsFinalize = buttonsLayout
            }
            
            var actionButtonsSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageActionButtonsNode)?
            if let actionButtonsFinalize = actionButtonsFinalize {
                actionButtonsSizeAndApply = actionButtonsFinalize(maxContentWidth)
            }
            
            let reactions: ReactionsMessageAttribute
            if shouldDisplayInlineDateReactions(message: item.message) {
                reactions = ReactionsMessageAttribute(canViewList: false, reactions: [], recentPeers: [])
            } else {
                reactions = mergedMessageReactions(attributes: item.message.attributes) ?? ReactionsMessageAttribute(canViewList: false, reactions: [], recentPeers: [])
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
                    reactions: reactions,
                    message: item.message,
                    isIncoming: item.message.effectivelyIncoming(item.context.account.peerId),
                    constrainedWidth: maxReactionsWidth
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
            
            return (ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets), { [weak self] animation, _, _ in
                if let strongSelf = self {
                    strongSelf.appliedForwardInfo = (forwardSource, forwardAuthorSignature)
                    strongSelf.updateAccessibilityData(accessibilityData)
                    
                    strongSelf.messageAccessibilityArea.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    
                    var transition: ContainedViewLayoutTransition = .immediate
                    if case let .System(duration, _) = animation {
                        if let subject = item.associatedData.subject, case .forwardedMessages = subject {
                            transition = .animated(duration: duration, curve: .linear)
                        } else {
                            transition = .animated(duration: duration, curve: .spring)
                        }
                    }
                    
                    let updatedImageFrame = imageFrame.offsetBy(dx: 0.0, dy: floor((contentHeight - imageSize.height) / 2.0))
                    var updatedContentFrame = updatedImageFrame
                    if isEmoji {
                        updatedContentFrame = updatedContentFrame.insetBy(dx: -imageInset, dy: -imageInset)
                    }
                    
                    strongSelf.imageNode.frame = updatedContentFrame
                    
                    let animationNodeFrame = updatedContentFrame.insetBy(dx: imageInset, dy: imageInset)

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
                        
                        let foregroundColor = bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.stickerPlaceholderColor, wallpaper: item.presentationData.theme.wallpaper)
                        let shimmeringColor = bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.stickerPlaceholderShimmerColor, wallpaper: item.presentationData.theme.wallpaper)
                        strongSelf.placeholderNode.update(backgroundColor: nil, foregroundColor: foregroundColor, shimmeringColor: shimmeringColor, data: immediateThumbnailData, size: animationNodeFrame.size, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0))
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
                    
                    strongSelf.contextSourceNode.contentRect = strongSelf.imageNode.frame
                    strongSelf.containerNode.targetNodeForActivationProgressContentRect = strongSelf.contextSourceNode.contentRect
                    
                    if let updatedShareButtonNode = updatedShareButtonNode {
                        if updatedShareButtonNode !== strongSelf.shareButtonNode {
                            if let shareButtonNode = strongSelf.shareButtonNode {
                                shareButtonNode.removeFromSupernode()
                            }
                            strongSelf.shareButtonNode = updatedShareButtonNode
                            strongSelf.addSubnode(updatedShareButtonNode)
                            updatedShareButtonNode.addTarget(strongSelf, action: #selector(strongSelf.shareButtonPressed), forControlEvents: .touchUpInside)
                        }
                        let buttonSize = updatedShareButtonNode.update(presentationData: item.presentationData, chatLocation: item.chatLocation, subject: item.associatedData.subject, message: item.message, account: item.context.account)
                        updatedShareButtonNode.frame = CGRect(origin: CGPoint(x: updatedImageFrame.maxX + 8.0, y: updatedImageFrame.maxY - buttonSize.height - 4.0), size: buttonSize)
                    } else if let shareButtonNode = strongSelf.shareButtonNode {
                        shareButtonNode.removeFromSupernode()
                        strongSelf.shareButtonNode = nil
                    }
                    
                    let dateAndStatusFrame = CGRect(origin: CGPoint(x: max(displayLeftInset, updatedImageFrame.maxX - dateAndStatusSize.width - 4.0), y: updatedImageFrame.maxY - dateAndStatusSize.height - 4.0), size: dateAndStatusSize)
                    animation.animator.updateFrame(layer: strongSelf.dateAndStatusNode.layer, frame: dateAndStatusFrame, completion: nil)
                    dateAndStatusApply(animation)

                    if needsReplyBackground {
                        if let replyBackgroundNode = strongSelf.replyBackgroundNode {
                            replyBackgroundNode.updateColor(color: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), transition: .immediate)
                        } else {
                            let replyBackgroundNode = NavigationBackgroundNode(color: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper))
                            strongSelf.replyBackgroundNode = replyBackgroundNode
                            strongSelf.contextSourceNode.contentNode.addSubnode(replyBackgroundNode)
                        }
                    } else if let replyBackgroundNode = strongSelf.replyBackgroundNode {
                        strongSelf.replyBackgroundNode = nil
                        replyBackgroundNode.removeFromSupernode()
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
                    
                    if let (replyInfoSize, replyInfoApply) = replyInfoApply {
                        let replyInfoNode = replyInfoApply()
                        if strongSelf.replyInfoNode == nil {
                            strongSelf.replyInfoNode = replyInfoNode
                            strongSelf.contextSourceNode.contentNode.addSubnode(replyInfoNode)
                        }
                        let replyInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 11.0) : (params.width - params.rightInset - messageInfoSize.width - layoutConstants.bubble.edgeInset - 9.0)), y: 8.0 + messageInfoSize.height), size: replyInfoSize)
                        replyInfoNode.frame = replyInfoFrame
                        
                        messageInfoSize = CGSize(width: max(messageInfoSize.width, replyInfoSize.width), height: messageInfoSize.height + replyInfoSize.height)
                    } else if let replyInfoNode = strongSelf.replyInfoNode {
                        replyInfoNode.removeFromSupernode()
                        strongSelf.replyInfoNode = nil
                    }
                    
                    
                    if let replyBackgroundNode = strongSelf.replyBackgroundNode {
                        replyBackgroundNode.frame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 10.0) : (params.width - params.rightInset - messageInfoSize.width - layoutConstants.bubble.edgeInset - 10.0)) - 4.0, y: 6.0), size: CGSize(width: messageInfoSize.width + 8.0, height: messageInfoSize.height + 5.0))
                        
                        let cornerRadius = replyBackgroundNode.frame.height <= 22.0 ? replyBackgroundNode.frame.height / 2.0 : 8.0
                        replyBackgroundNode.update(size: replyBackgroundNode.bounds.size, cornerRadius: cornerRadius, transition: .immediate)
                    }
                    
                    let panelsAlpha: CGFloat = item.controllerInteraction.selectionState == nil ? 1.0 : 0.0
                    strongSelf.replyInfoNode?.alpha = panelsAlpha
                    strongSelf.viaBotNode?.alpha = panelsAlpha
                    strongSelf.forwardInfoNode?.alpha = panelsAlpha
                    strongSelf.replyBackgroundNode?.alpha = panelsAlpha
                    
                    if isFailed {
                        let deliveryFailedNode: ChatMessageDeliveryFailedNode
                        var isAppearing = false
                        if let current = strongSelf.deliveryFailedNode {
                            deliveryFailedNode = current
                        } else {
                            isAppearing = true
                            deliveryFailedNode = ChatMessageDeliveryFailedNode(tapped: {
                                if let item = self?.item {
                                    item.controllerInteraction.requestRedeliveryOfFailedMessages(item.content.firstMessage.id)
                                }
                            })
                            strongSelf.deliveryFailedNode = deliveryFailedNode
                            strongSelf.addSubnode(deliveryFailedNode)
                        }
                        let deliveryFailedSize = deliveryFailedNode.updateLayout(theme: item.presentationData.theme.theme)
                        let deliveryFailedFrame = CGRect(origin: CGPoint(x: imageFrame.maxX + deliveryFailedInset - deliveryFailedSize.width, y: imageFrame.maxY - deliveryFailedSize.height - imageInset + imageVerticalInset), size: deliveryFailedSize)
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
                        let actionButtonsFrame = CGRect(origin: CGPoint(x: imageFrame.minX, y: imageFrame.maxY + imageVerticalInset), size: actionButtonsSizeAndApply.0)
                        actionButtonsNode.frame = actionButtonsFrame
                        if actionButtonsNode !== strongSelf.actionButtonsNode {
                            strongSelf.actionButtonsNode = actionButtonsNode
                            actionButtonsNode.buttonPressed = { button in
                                if let strongSelf = self {
                                    strongSelf.performMessageButtonAction(button: button)
                                }
                            }
                            actionButtonsNode.buttonLongTapped = { button in
                                if let strongSelf = self {
                                    strongSelf.presentMessageButtonContextMenu(button: button)
                                }
                            }
                            strongSelf.addSubnode(actionButtonsNode)
                        } else {
                            if case let .System(duration, _) = animation {
                                actionButtonsNode.layer.animateFrame(from: previousFrame, to: actionButtonsFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                    } else if let actionButtonsNode = strongSelf.actionButtonsNode {
                        actionButtonsNode.removeFromSupernode()
                        strongSelf.actionButtonsNode = nil
                    }
                    
                    if let reactionButtonsSizeAndApply = reactionButtonsSizeAndApply {
                        let reactionButtonsNode = reactionButtonsSizeAndApply.1(animation)
                        var reactionButtonsFrame = CGRect(origin: CGPoint(x: imageFrame.minX, y: imageFrame.maxY + imageVerticalInset), size: reactionButtonsSizeAndApply.0)
                        if !incoming {
                            reactionButtonsFrame.origin.x = imageFrame.maxX - reactionButtonsSizeAndApply.0.width
                        }
                        if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                            reactionButtonsFrame.origin.y += 4.0 + actionButtonsSizeAndApply.0.height
                        }
                        if reactionButtonsNode !== strongSelf.reactionButtonsNode {
                            strongSelf.reactionButtonsNode = reactionButtonsNode
                            reactionButtonsNode.reactionSelected = { value in
                                guard let strongSelf = self, let item = strongSelf.item else {
                                    return
                                }
                                item.controllerInteraction.updateMessageReaction(item.message, .reaction(value))
                            }
                            reactionButtonsNode.openReactionPreview = { gesture, sourceView, value in
                                guard let strongSelf = self, let item = strongSelf.item else {
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
                            guard let strongSelf = self else {
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
                }
            })
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
                        f()
                    case let .optionalAction(f):
                        f()
                    case let .openContextMenu(tapMessage, selectAll, subFrame):
                        if canAddMessageReactions(message: item.message) {
                            item.controllerInteraction.updateMessageReaction(item.message, .default)
                        } else {
                            item.controllerInteraction.openMessageContextMenu(tapMessage, selectAll, self, subFrame, nil)
                        }
                    }
                } else if case .tap = gesture {
                    item.controllerInteraction.clickThroughMessage()
                } else if case .doubleTap = gesture {
                    if canAddMessageReactions(message: item.message) {
                        item.controllerInteraction.updateMessageReaction(item.message, .default)
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
        guard let item = self.item, let file = self.emojiFile, !self.enqueuedAdditionalAnimations.isEmpty else {
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
    
    func playEmojiInteraction(_ interaction: EmojiInteraction) {
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
    
    func playAdditionalEmojiAnimation(index: Int) {
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
        
        self.playEffectAnimation(resource: file.resource)
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
    
    func playEffectAnimation(resource: MediaResource, isStickerEffect: Bool = false) {
        guard let item = self.item else {
            return
        }
        guard let transitionNode = item.controllerInteraction.getMessageTransitionNode() else {
            return
        }
        
        let source = AnimatedStickerResourceSource(account: item.context.account, resource: resource, fitzModifier: nil)
        guard let animationSize = self.animationSize, let animationNode = self.animationNode else {
            return
        }
        if self.additionalAnimationNodes.count >= 4 {
            return
        }
        if let animationNode = animationNode as? AnimatedStickerNode {
            let _ = animationNode.playIfNeeded()
        }
        
        let incomingMessage = item.message.effectivelyIncoming(item.context.account.peerId)

        if #available(iOS 13.0, *), !"".isEmpty, item.context.sharedContext.immediateExperimentalUISettings.acceleratedStickers, let meshAnimation = item.context.meshAnimationCache.get(resource: resource) {
            var overlayMeshAnimationNode: ChatMessageTransitionNode.DecorationItemNode?
            if let current = self.overlayMeshAnimationNode {
                overlayMeshAnimationNode = current
            } else {
                if let animationView = MeshRenderer() {
                    let animationFrame = animationNode.frame.insetBy(dx: -animationNode.frame.width, dy: -animationNode.frame.height)
                        .offsetBy(dx: incomingMessage ? animationNode.frame.width - 10.0 : -animationNode.frame.width + 10.0, dy: 0.0)
                    animationView.frame = animationFrame

                    animationView.allAnimationsCompleted = { [weak transitionNode, weak animationView, weak self] in
                        guard let strongSelf = self, let animationView = animationView else {
                            return
                        }
                        guard let overlayMeshAnimationNode = strongSelf.overlayMeshAnimationNode else {
                            return
                        }
                        if overlayMeshAnimationNode.contentView !== animationView {
                            return
                        }
                        strongSelf.overlayMeshAnimationNode = nil
                        transitionNode?.remove(decorationNode: overlayMeshAnimationNode)
                    }

                    overlayMeshAnimationNode = transitionNode.add(decorationView: animationView, itemNode: self)
                    self.overlayMeshAnimationNode = overlayMeshAnimationNode
                }
            }
            if let meshRenderer = overlayMeshAnimationNode?.contentView as? MeshRenderer {
                meshRenderer.add(mesh: meshAnimation, offset: CGPoint(x: CGFloat.random(in: -30.0 ... 30.0), y: CGFloat.random(in: -30.0 ... 30.0)))
            }
        } else {
            let pathPrefix = item.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(resource.id)
            let additionalAnimationNode = DefaultAnimatedStickerNodeImpl()
            additionalAnimationNode.setup(source: source, width: Int(animationSize.width * 1.6), height: Int(animationSize.height * 1.6), playbackMode: .once, mode: .direct(cachePathPrefix: pathPrefix))
            var animationFrame: CGRect
            if isStickerEffect {
                let scale: CGFloat = 0.245
                animationFrame = animationNode.frame.offsetBy(dx: incomingMessage ? animationNode.frame.width * scale - 21.0 : -animationNode.frame.width * scale + 21.0, dy: -1.0).insetBy(dx: -animationNode.frame.width * scale, dy: -animationNode.frame.height * scale)
            } else {
                animationFrame = animationNode.frame.insetBy(dx: -animationNode.frame.width, dy: -animationNode.frame.height)
                    .offsetBy(dx: incomingMessage ? animationNode.frame.width - 10.0 : -animationNode.frame.width + 10.0, dy: 0.0)
                animationFrame = animationFrame.offsetBy(dx: CGFloat.random(in: -30.0 ... 30.0), dy: CGFloat.random(in: -30.0 ... 30.0))
            }
            
            additionalAnimationNode.frame = animationFrame
            if incomingMessage {
                additionalAnimationNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            }

            let decorationNode = transitionNode.add(decorationView: additionalAnimationNode.view, itemNode: self)
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

            additionalAnimationNode.play()
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
                                item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId)
                            })
                        }
                    }
                }
            }
            
            if let item = self.item, self.imageNode.frame.contains(location) {
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
                            let _ = item.controllerInteraction.openMessage(item.message, .default)
                        })
                    }
                } else if let dice = self.telegramDice {
                    return .optionalAction({
                        item.controllerInteraction.displayDiceTooltip(dice)
                    })
                } else if let _ = self.emojiFile {
                    if let animationNode = self.animationNode as? AnimatedStickerNode, let _ = recognizer {
                        var shouldPlay = false
                        if !animationNode.isPlaying {
                            shouldPlay = true
                        }
                        
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
                                }
                                
                                if shouldPlay {
                                    let _ = (appConfiguration
                                    |> deliverOnMainQueue).start(next: { [weak self, weak animationNode] appConfiguration in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        let emojiSounds = AnimatedEmojiSoundsConfiguration.with(appConfiguration: appConfiguration, account: item.context.account)
                                        var hasSound = false
                                        for (emoji, file) in emojiSounds.sounds {
                                            if emoji.strippedEmoji == textEmoji.strippedEmoji {
                                                hasSound = true
                                                let mediaManager = item.context.sharedContext.mediaManager
                                                let mediaPlayer = MediaPlayer(audioSessionManager: mediaManager.audioSession, postbox: item.context.account.postbox, resourceReference: .standalone(resource: file.resource), streamable: .none, video: false, preferSoftwareDecoding: false, enableSound: true, fetchAutomatically: true, ambient: true)
                                                mediaPlayer.togglePlayPause()
                                                mediaPlayer.actionAtEnd = .action({ [weak self] in
                                                    self?.mediaPlayer = nil
                                                })
                                                strongSelf.mediaPlayer = mediaPlayer
                                                
                                                strongSelf.mediaStatusDisposable.set((mediaPlayer.status
                                                |> deliverOnMainQueue).start(next: { [weak self, weak animationNode] status in
                                                    if let strongSelf = self {
                                                        if let haptic = haptic, !haptic.active {
                                                            haptic.start(time: 0.0)
                                                        }
                                                        
                                                        switch status.status {
                                                            case .playing:
                                                                animationNode?.play(firstFrame: false, fromIndex: nil)
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
                                            animationNode?.play(firstFrame: false, fromIndex: nil)
                                        }
                                    })
                                }
                            })
                        }
                    }
                }
            }
            return nil
        case .longTap, .doubleTap:
            if let item = self.item, self.imageNode.frame.contains(location) {
                return .openContextMenu(tapMessage: item.message, selectAll: false, subFrame: self.imageNode.frame)
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
                        item.controllerInteraction.navigateToMessage(item.content.firstMessage.id, attribute.messageId)
                        break
                    }
                }
            } else {
                item.controllerInteraction.openMessageShareMenu(item.message.id)
            }
        }
    }
    
    @objc private func swipeToReplyGesture(_ recognizer: ChatSwipeToReplyRecognizer) {
        switch recognizer.state {
        case .began:
            self.currentSwipeToReplyTranslation = 0.0
            if self.swipeToReplyFeedback == nil {
                self.swipeToReplyFeedback = HapticFeedback()
                self.swipeToReplyFeedback?.prepareImpact()
            }
            (self.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
        case .changed:
            var translation = recognizer.translation(in: self.view)
            translation.x = max(-80.0, min(0.0, translation.x))
            var animateReplyNodeIn = false
            if (translation.x < -45.0) != (self.currentSwipeToReplyTranslation < -45.0) {
                if translation.x < -45.0, self.swipeToReplyNode == nil, let item = self.item {
                    self.swipeToReplyFeedback?.impact()
                    
                    let swipeToReplyNode = ChatMessageSwipeToReplyNode(fillColor: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), foregroundColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonForegroundColor, wallpaper: item.presentationData.theme.wallpaper), action: ChatMessageSwipeToReplyNode.Action(self.currentSwipeAction))
                    self.swipeToReplyNode = swipeToReplyNode
                    self.addSubnode(swipeToReplyNode)
                    animateReplyNodeIn = true
                }
            }
            self.currentSwipeToReplyTranslation = translation.x
            var bounds = self.bounds
            bounds.origin.x = -translation.x
            self.bounds = bounds

            self.updateAttachedAvatarNodeOffset(offset: translation.x, transition: .immediate)
            
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let shareButtonNode = self.shareButtonNode, shareButtonNode.frame.contains(point) {
            return shareButtonNode.view
        }
        
        if let reactionButtonsNode = self.reactionButtonsNode {
            if let result = reactionButtonsNode.hitTest(self.view.convert(point, to: reactionButtonsNode.view), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    override func updateSelectionState(animated: Bool) {
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
        if let replyBackgroundNode = self.replyBackgroundNode {
            transition.updateAlpha(node: replyBackgroundNode, alpha: panelsAlpha)
        }
        
        if let selectionState = item.controllerInteraction.selectionState {
            let selected = selectionState.selectedIds.contains(item.message.id)
            let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: false)
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
    
    override func updateHighlightedState(animated: Bool) {
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

    override func cancelInsertionAnimations() {
        self.layer.removeAllAnimations()
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
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
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func getMessageContextSourceNode(stableId: UInt32?) -> ContextExtractedContentContainingNode? {
        return self.contextSourceNode
    }
    
    override func addAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        self.contextSourceNode.contentNode.addSubnode(accessoryItemNode)
    }

    func animateContentFromTextInputField(textInput: ChatMessageTransitionNode.Source.TextInput, transition: CombinedTransition) {
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

    func animateContentFromStickerGridItem(stickerSource: ChatMessageTransitionNode.Sticker, transition: CombinedTransition) {
        guard let _ = self.item else {
            return
        }

        let localSourceContentFrame = CGRect(
            origin: CGPoint(
                x: self.imageNode.frame.minX + self.imageNode.frame.size.width / 2.0 - stickerSource.imageNode.frame.size.width / 2.0,
                y: self.imageNode.frame.minY + self.imageNode.frame.size.height / 2.0 - stickerSource.imageNode.frame.size.height / 2.0
            ),
            size: stickerSource.imageNode.frame.size
        )

        var snapshotView: UIView?
        if let animationNode = stickerSource.animationNode {
            snapshotView = animationNode.view.snapshotContentTree()
        } else {
            snapshotView = stickerSource.imageNode.view.snapshotContentTree()
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

        let sourceScale: CGFloat = stickerSource.imageNode.frame.height / self.imageNode.frame.height

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

        stickerSource.imageNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
        stickerSource.imageNode.layer.animateAlpha(from: 0.0, to: stickerSource.imageNode.alpha, duration: 0.4)

        if let placeholderNode = stickerSource.placeholderNode {
            placeholderNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            placeholderNode.layer.animateAlpha(from: 0.0, to: placeholderNode.alpha, duration: 0.4)
        }
    }

    func animateReplyPanel(sourceReplyPanel: ChatMessageTransitionNode.ReplyPanel, transition: CombinedTransition) {
        if let replyInfoNode = self.replyInfoNode {
            let localRect = self.contextSourceNode.contentNode.view.convert(sourceReplyPanel.relativeSourceRect, to: replyInfoNode.view)

            let offset = replyInfoNode.animateFromInputPanel(sourceReplyPanel: sourceReplyPanel, localRect: localRect, transition: transition)
            if let replyBackgroundNode = self.replyBackgroundNode {
                transition.animatePositionAdditive(layer: replyBackgroundNode.layer, offset: offset)
                replyBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
            }
        }
    }
    
    override func openMessageContextMenu() {
        guard let item = self.item else {
            return
        }
        item.controllerInteraction.openMessageContextMenu(item.message, false, self, self.imageNode.frame, nil)
    }
    
    override func targetReactionView(value: String) -> UIView? {
        if let result = self.reactionButtonsNode?.reactionTargetView(value: value) {
            return result
        }
        if !self.dateAndStatusNode.isHidden {
            return self.dateAndStatusNode.reactionView(value: value)
        }
        return nil
    }
    
    override func unreadMessageRangeUpdated() {
        self.updateVisibility()
    }
}

struct AnimatedEmojiSoundsConfiguration {
    static var defaultValue: AnimatedEmojiSoundsConfiguration {
        return AnimatedEmojiSoundsConfiguration(sounds: [:])
    }
    
    public let sounds: [String: TelegramMediaFile]
    
    fileprivate init(sounds: [String: TelegramMediaFile]) {
        self.sounds = sounds
    }
    
    static func with(appConfiguration: AppConfiguration, account: Account) -> AnimatedEmojiSoundsConfiguration {
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
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: nil, attributes: [])
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
