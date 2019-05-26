import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AVFoundation
import CoreImage

private class AlphaFrameFilter: CIFilter {
    static var kernel: CIColorKernel? = {
        return CIColorKernel(source: """
kernel vec4 alphaFrame(__sample s, __sample m) {
  return vec4( s.rgb, m.r );
}
""")
    }()
    
    var inputImage: CIImage?
    var maskImage: CIImage?
    
    override var outputImage: CIImage? {
        let kernel = AlphaFrameFilter.kernel!
        guard let inputImage = inputImage, let maskImage = maskImage else {
            return nil
        }
        let args = [inputImage as AnyObject, maskImage as AnyObject]
        return kernel.apply(extent: inputImage.extent, arguments: args)
    }
}

private func createVideoComposition(for playerItem: AVPlayerItem) -> AVVideoComposition? {
    let videoSize = CGSize(width: playerItem.presentationSize.width, height: playerItem.presentationSize.height / 2.0)
    if #available(iOSApplicationExtension 9.0, *) {
        let composition = AVMutableVideoComposition(asset: playerItem.asset, applyingCIFiltersWithHandler: { request in
            let sourceRect = CGRect(origin: .zero, size: videoSize)
            let alphaRect = sourceRect.offsetBy(dx: 0, dy: sourceRect.height)
            let filter = AlphaFrameFilter()
            filter.inputImage = request.sourceImage.cropped(to: alphaRect)
                .transformed(by: CGAffineTransform(translationX: 0, y: -sourceRect.height))
            filter.maskImage = request.sourceImage.cropped(to: sourceRect)
            return request.finish(with: filter.outputImage!, context: nil)
        })
        composition.renderSize = videoSize
        return composition
    } else {
        return nil
    }
}

private final class StickerAnimationNode: ASDisplayNode {
    private var account: Account?
    private var fileReference: FileMediaReference?
    private let disposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    
    var playerLayer: AVPlayerLayer {
        return self.layer as! AVPlayerLayer
    }
    
    var started: () -> Void = {}
    
    var player: AVPlayer? {
        get {
            if self.isNodeLoaded {
                return self.playerLayer.player
            } else {
                return nil
            }
        }
        set {
            if let player = self.playerLayer.player {
                player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))
            }
            self.playerLayer.player = newValue
            if let newValue = newValue {
                newValue.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: [], context: nil)
            }
        }
    }
    
    private var playerItem: AVPlayerItem? = nil {
        willSet {
            self.playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        }
        didSet {
            self.playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: .new, context: nil)
            self.setupLooping()
        }
    }
    
    override init() {
        super.init()
        
        self.setLayerBlock({
            let layer = AVPlayerLayer()
            layer.isHidden = true
            if #available(iOSApplicationExtension 9.0, *) {
                layer.pixelBufferAttributes = [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
            }
            return layer
        })
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self.didPlayToEndTimeObsever as Any)
        self.player = nil
        self.playerItem = nil
        self.disposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    func setup(account: Account, fileReference: FileMediaReference) {
        self.disposable.set(chatMessageAnimationData(postbox: account.postbox, fileReference: fileReference, synchronousLoad: false).start(next: { [weak self] data in
            if let strongSelf = self, data.complete {
                let playerItem = AVPlayerItem(url: URL(fileURLWithPath: data.path))
                Queue.mainQueue().async {
                    strongSelf.player = AVPlayer(playerItem: playerItem)
                    strongSelf.playerItem = playerItem
                }
            }
        }))
        self.fetchDisposable.set(fetchedMediaResource(postbox: account.postbox, reference: fileReference.resourceReference(fileReference.media.resource)).start())
    }
    
    private func setupLooping() {
        guard let playerItem = self.playerItem, let player = self.player else {
            return
        }
        
        self.didPlayToEndTimeObsever = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: nil, using: { _ in
            player.seek(to: kCMTimeZero) { _ in
                player.play()
            }
        })
    }
    
    private var didPlayToEndTimeObsever: NSObjectProtocol? = nil {
        willSet(newObserver) {
            if let observer = self.didPlayToEndTimeObsever, self.didPlayToEndTimeObsever !== newObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let playerItem = object as? AVPlayerItem, playerItem === self.playerItem {
            if case .readyToPlay = playerItem.status, playerItem.videoComposition == nil {
                playerItem.videoComposition = createVideoComposition(for: playerItem)
                playerItem.seekingWaitsForVideoCompositionRendering = true
            }
            self.player?.play()
        } else if let player = object as? AVPlayer, player === self.player {
            if self.playerLayer.isHidden && player.rate > 0.0 {
                Queue.mainQueue().after(0.2) {
                    self.playerLayer.isHidden = false
                    self.started()
                }
            }
        } else {
            return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func play() {
        
    }
    
    func reset() {
        
    }
}

class ChatMessageAnimatedStickerItemNode: ChatMessageItemView {
    let imageNode: TransformImageNode
    private let animationNode: StickerAnimationNode
    
    private var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    private var swipeToReplyFeedback: HapticFeedback?
    
    private var selectionNode: ChatMessageSelectionNode?
    private var shareButtonNode: HighlightableButtonNode?
    
    var telegramFile: TelegramMediaFile?
    
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private var replyInfoNode: ChatMessageReplyInfoNode?
    private var replyBackgroundNode: ASImageNode?
    
    private var highlightedState: Bool = false
    
    private var currentSwipeToReplyTranslation: CGFloat = 0.0
    
    required init() {
        self.imageNode = TransformImageNode()
        self.animationNode = StickerAnimationNode()
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        super.init(layerBacked: false)
        
        self.animationNode.started = { [weak self] in
            self?.animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self?.imageNode.alpha = 0.0
            self?.imageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        }
        
        self.imageNode.displaysAsynchronously = false
        self.addSubnode(self.imageNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.dateAndStatusNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let shareButtonNode = strongSelf.shareButtonNode, shareButtonNode.frame.contains(point) {
                    return .fail
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
                return item.controllerInteraction.canSetupReply(item.message)
            }
            return false
        }
        self.view.addGestureRecognizer(replyRecognizer)
    }
    
    override func setupItem(_ item: ChatMessageItem) {
        super.setupItem(item)
        
        for media in item.message.media {
            if let telegramFile = media as? TelegramMediaFile {
                if self.telegramFile != telegramFile {

                    self.telegramFile = telegramFile
                    self.imageNode.setSignal(chatMessageSticker(account: item.context.account, file: telegramFile, small: false, thumbnail: true))
                    self.animationNode.setup(account: item.context.account, fileReference: .message(message: MessageReference(item.message), media: telegramFile))
                }
                break
            }
        }
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, Bool) -> Void) {
        let displaySize = CGSize(width: 162.0, height: 162.0)
        let telegramFile = self.telegramFile
        let layoutConstants = self.layoutConstants
        let imageLayout = self.imageNode.asyncLayout()
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentReplyBackgroundNode = self.replyBackgroundNode
        let currentShareButtonNode = self.shareButtonNode
        let currentItem = self.item
        
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom in
            let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            var imageSize: CGSize = CGSize(width: 162.0, height: 162.0)
            if let telegramFile = telegramFile {
                if let dimensions = telegramFile.dimensions {
                    imageSize = dimensions.aspectFitted(displaySize)
                } else if let thumbnailSize = telegramFile.previewRepresentations.first?.dimensions {
                    imageSize = thumbnailSize.aspectFitted(displaySize)
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
                            }
                        }
                    } else if incoming {
                        hasAvatar = true
                    }
                /*case .group:
                    hasAvatar = true*/
            }
            
            if hasAvatar {
                avatarInset = layoutConstants.avatarDiameter
            } else {
                avatarInset = 0.0
            }
            
            var needShareButton = false
            if item.message.id.peerId == item.context.account.peerId {
                for attribute in item.content.firstMessage.attributes {
                    if let _ = attribute as? SourceReferenceMessageAttribute {
                        needShareButton = true
                        break
                    }
                }
            } else if item.message.effectivelyIncoming(item.context.account.peerId) {
                if let peer = item.message.peers[item.message.id.peerId] {
                    if let channel = peer as? TelegramChannel {
                        if case .broadcast = channel.info {
                            needShareButton = true
                        }
                    }
                }
                if !needShareButton, let author = item.message.author as? TelegramUser, let _ = author.botInfo, !item.message.media.isEmpty {
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
            
            var layoutInsets = UIEdgeInsets(top: mergedTop.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            let displayLeftInset = params.leftInset + layoutConstants.bubble.edgeInset + avatarInset
            
            let imageInset: CGFloat = 10.0
            let innerImageSize = imageSize
            imageSize = CGSize(width: imageSize.width + imageInset * 2.0, height: imageSize.height + imageInset * 2.0)
            let imageFrame = CGRect(origin: CGPoint(x: 0.0 + (incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + avatarInset + layoutConstants.bubble.contentInsets.left) : (params.width - params.rightInset - imageSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left)), y: 0.0), size: CGSize(width: imageSize.width, height: imageSize.height))
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: innerImageSize, boundingSize: innerImageSize, intrinsicInsets: UIEdgeInsets(top: imageInset, left: imageInset, bottom: imageInset, right: imageInset))
            
            let imageApply = imageLayout(arguments)
            
            let statusType: ChatMessageDateAndStatusType
            if item.message.effectivelyIncoming(item.context.account.peerId) {
                statusType = .FreeIncoming
            } else {
                if item.message.flags.contains(.Failed) {
                    statusType = .FreeOutgoing(.Failed)
                } else if item.message.flags.isSending && !item.message.isSentOrAcknowledged {
                    statusType = .FreeOutgoing(.Sending)
                } else {
                    statusType = .FreeOutgoing(.Sent(read: item.read))
                }
            }
            
            let edited = false
            let sentViaBot = false
            var viewCount: Int? = nil
            for attribute in item.message.attributes {
                if let _ = attribute as? EditedMessageAttribute {
                    // edited = true
                } else if let attribute = attribute as? ViewCountMessageAttribute {
                    viewCount = attribute.count
                }// else if let _ = attribute as? InlineBotMessageAttribute {
                //    sentViaBot = true
                //  }
            }
            
            let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: .minimal)
            
            let (dateAndStatusSize, dateAndStatusApply) = makeDateAndStatusLayout(item.presentationData, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude))
            
            var replyInfoApply: (CGSize, () -> ChatMessageReplyInfoNode)?
            var updatedReplyBackgroundNode: ASImageNode?
            var replyBackgroundImage: UIImage?
            for attribute in item.message.attributes {
                if let replyAttribute = attribute as? ReplyMessageAttribute, let replyMessage = item.message.associatedMessages[replyAttribute.messageId] {
                    let availableWidth = max(60.0, params.width - params.leftInset - params.rightInset - imageSize.width - 20.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left)
                    replyInfoApply = makeReplyInfoLayout(item.presentationData, item.presentationData.strings, item.context, .standalone, replyMessage, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
                    
                    if let currentReplyBackgroundNode = currentReplyBackgroundNode {
                        updatedReplyBackgroundNode = currentReplyBackgroundNode
                    } else {
                        updatedReplyBackgroundNode = ASImageNode()
                    }
                    
                    let graphics = PresentationResourcesChat.additionalGraphics(item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
                    replyBackgroundImage = graphics.chatFreeformContentAdditionalInfoBackgroundImage
                    break
                }
            }
            
            var updatedShareButtonBackground: UIImage?
            
            var updatedShareButtonNode: HighlightableButtonNode?
            if needShareButton {
                if currentShareButtonNode != nil {
                    updatedShareButtonNode = currentShareButtonNode
                    if item.presentationData.theme !== currentItem?.presentationData.theme {
                        let graphics = PresentationResourcesChat.additionalGraphics(item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
                        if item.message.id.peerId == item.context.account.peerId {
                            updatedShareButtonBackground = graphics.chatBubbleNavigateButtonImage
                        } else {
                            updatedShareButtonBackground = graphics.chatBubbleShareButtonImage
                        }
                    }
                } else {
                    let buttonNode = HighlightableButtonNode()
                    let buttonIcon: UIImage?
                    let graphics = PresentationResourcesChat.additionalGraphics(item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
                    if item.message.id.peerId == item.context.account.peerId {
                        buttonIcon = graphics.chatBubbleNavigateButtonImage
                    } else {
                        buttonIcon = graphics.chatBubbleShareButtonImage
                    }
                    buttonNode.setBackgroundImage(buttonIcon, for: [.normal])
                    updatedShareButtonNode = buttonNode
                }
            }
            
            let contentHeight = max(imageSize.height, layoutConstants.image.minDimensions.height)
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: contentHeight), insets: layoutInsets), { [weak self] animation, _ in
                if let strongSelf = self {
                    let updatedImageFrame = imageFrame.offsetBy(dx: 0.0, dy: floor((contentHeight - imageSize.height) / 2.0))
                    
                    strongSelf.imageNode.frame = updatedImageFrame
                    strongSelf.animationNode.frame = updatedImageFrame.insetBy(dx: imageInset, dy: imageInset)
                    imageApply()
                    
                    if let updatedShareButtonNode = updatedShareButtonNode {
                        if updatedShareButtonNode !== strongSelf.shareButtonNode {
                            if let shareButtonNode = strongSelf.shareButtonNode {
                                shareButtonNode.removeFromSupernode()
                            }
                            strongSelf.shareButtonNode = updatedShareButtonNode
                            strongSelf.addSubnode(updatedShareButtonNode)
                            updatedShareButtonNode.addTarget(strongSelf, action: #selector(strongSelf.shareButtonPressed), forControlEvents: .touchUpInside)
                        }
                        if let updatedShareButtonBackground = updatedShareButtonBackground {
                            strongSelf.shareButtonNode?.setBackgroundImage(updatedShareButtonBackground, for: [.normal])
                        }
                    } else if let shareButtonNode = strongSelf.shareButtonNode {
                        shareButtonNode.removeFromSupernode()
                        strongSelf.shareButtonNode = nil
                    }
                    
                    if let shareButtonNode = strongSelf.shareButtonNode {
                        shareButtonNode.frame = CGRect(origin: CGPoint(x: updatedImageFrame.maxX + 8.0, y: updatedImageFrame.maxY - 30.0), size: CGSize(width: 29.0, height: 29.0))
                    }
                    
                    dateAndStatusApply(false)
                    strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: max(displayLeftInset, updatedImageFrame.maxX - dateAndStatusSize.width - 4.0), y: updatedImageFrame.maxY - dateAndStatusSize.height - 4.0), size: dateAndStatusSize)
                    
                    if let updatedReplyBackgroundNode = updatedReplyBackgroundNode {
                        if strongSelf.replyBackgroundNode == nil {
                            strongSelf.replyBackgroundNode = updatedReplyBackgroundNode
                            strongSelf.addSubnode(updatedReplyBackgroundNode)
                            updatedReplyBackgroundNode.image = replyBackgroundImage
                        } else {
                            strongSelf.replyBackgroundNode?.image = replyBackgroundImage
                        }
                    } else if let replyBackgroundNode = strongSelf.replyBackgroundNode {
                        replyBackgroundNode.removeFromSupernode()
                        strongSelf.replyBackgroundNode = nil
                    }
                    
                    if let (replyInfoSize, replyInfoApply) = replyInfoApply {
                        let replyInfoNode = replyInfoApply()
                        if strongSelf.replyInfoNode == nil {
                            strongSelf.replyInfoNode = replyInfoNode
                            strongSelf.addSubnode(replyInfoNode)
                        }
                        let replyInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 10.0) : (params.width - params.rightInset - replyInfoSize.width - layoutConstants.bubble.edgeInset - 10.0)), y: 8.0), size: replyInfoSize)
                        replyInfoNode.frame = replyInfoFrame
                        strongSelf.replyBackgroundNode?.frame = CGRect(origin: CGPoint(x: replyInfoFrame.minX - 4.0, y: replyInfoFrame.minY - 2.0), size: CGSize(width: replyInfoFrame.size.width + 8.0, height: replyInfoFrame.size.height + 5.0))
                    } else if let replyInfoNode = strongSelf.replyInfoNode {
                        replyInfoNode.removeFromSupernode()
                        strongSelf.replyInfoNode = nil
                    }
                }
            })
        }
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
                    if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(location) {
                        if let item = self.item, let author = item.content.firstMessage.author {
                            var openPeerId = item.effectiveAuthorId ?? author.id
                            var navigate: ChatControllerInteractionNavigateToPeer
                            
                            if item.content.firstMessage.id.peerId == item.context.account.peerId {
                                navigate = .chat(textInputState: nil, messageId: nil)
                            } else {
                                navigate = .info
                            }
                            
                            for attribute in item.content.firstMessage.attributes {
                                if let attribute = attribute as? SourceReferenceMessageAttribute {
                                    openPeerId = attribute.messageId.peerId
                                    navigate = .chat(textInputState: nil, messageId: attribute.messageId)
                                }
                            }
                            
                            if item.effectiveAuthorId?.namespace == Namespaces.Peer.Empty {
                                item.controllerInteraction.displayMessageTooltip(item.content.firstMessage.id,  item.presentationData.strings.Conversation_ForwardAuthorHiddenTooltip, self, avatarNode.frame)
                            } else {
                                if let channel = item.content.firstMessage.forwardInfo?.author as? TelegramChannel, channel.username == nil {
                                    if case .member = channel.participationStatus {
                                    } else {
                                        item.controllerInteraction.displayMessageTooltip(item.message.id, item.presentationData.strings.Conversation_PrivateChannelTooltip, self, avatarNode.frame)
                                        return
                                    }
                                }
                                item.controllerInteraction.openPeer(openPeerId, navigate, item.message)
                            }
                        }
                        return
                    }
                    
                    if let replyInfoNode = self.replyInfoNode, replyInfoNode.frame.contains(location) {
                        if let item = self.item {
                            for attribute in item.message.attributes {
                                if let attribute = attribute as? ReplyMessageAttribute {
                                    item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId)
                                    return
                                }
                            }
                        }
                    }
                    
                    if let item = self.item, self.imageNode.frame.contains(location) {
                        //self.animationNode.play()
                        //let _ = item.controllerInteraction.openMessage(item.message, .default)
                        return
                    }
                    
                    self.item?.controllerInteraction.clickThroughMessage()
                case .longTap, .doubleTap:
                    if let item = self.item, self.imageNode.frame.contains(location) {
                        item.controllerInteraction.openMessageContextMenu(item.message, false, self, self.imageNode.frame)
                    }
                case .hold:
                    break
                }
            }
        default:
            break
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
            (self.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
        case .changed:
            var translation = recognizer.translation(in: self.view)
            translation.x = max(-80.0, min(0.0, translation.x))
            var animateReplyNodeIn = false
            if (translation.x < -45.0) != (self.currentSwipeToReplyTranslation < -45.0) {
                if translation.x < -45.0, self.swipeToReplyNode == nil, let item = self.item {
                    self.swipeToReplyFeedback?.impact()
                    
                    let swipeToReplyNode = ChatMessageSwipeToReplyNode(fillColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.bubble.shareButtonFillColor, wallpaper: item.presentationData.theme.wallpaper), strokeColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.bubble.shareButtonStrokeColor, wallpaper: item.presentationData.theme.wallpaper), foregroundColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.bubble.shareButtonForegroundColor, wallpaper: item.presentationData.theme.wallpaper))
                    self.swipeToReplyNode = swipeToReplyNode
                    self.addSubnode(swipeToReplyNode)
                    animateReplyNodeIn = true
                }
            }
            self.currentSwipeToReplyTranslation = translation.x
            var bounds = self.bounds
            bounds.origin.x = -translation.x
            self.bounds = bounds
            
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
            self.layer.animateBounds(from: previousBounds, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
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
        
        return super.hitTest(point, with: event)
    }
    
    override func updateSelectionState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        if let selectionState = item.controllerInteraction.selectionState {
            var selected = false
            var incoming = true
            
            selected = selectionState.selectedIds.contains(item.message.id)
            incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: false)
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(theme: item.presentationData.theme.theme, toggle: { [weak self] value in
                    if let strongSelf = self, let item = strongSelf.item {
                        item.controllerInteraction.toggleMessagesSelection([item.message.id], value)
                    }
                })
                
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                self.addSubnode(selectionNode)
                self.selectionNode = selectionNode
                selectionNode.updateSelected(selected, animated: false)
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
                if animated {
                    selectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4)
                    
                    if !incoming {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: CGPoint(x: position.x - 42.0, y: position.y), to: position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                }
            }
        } else {
            if let selectionNode = self.selectionNode {
                self.selectionNode = nil
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DIdentity
                if animated {
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4, completion: { [weak selectionNode]_ in
                        selectionNode?.removeFromSupernode()
                    })
                    selectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                    if CGFloat(0.0).isLessThanOrEqualTo(selectionNode.frame.origin.x) {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: position, to: CGPoint(x: position.x - 42.0, y: position.y), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
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
                    self.imageNode.setOverlayColor(item.presentationData.theme.theme.chat.bubble.mediaHighlightOverlayColor, animated: false)
                } else {
                    self.imageNode.setOverlayColor(nil, animated: animated)
                }
            }
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}
