import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatMessageInstantVideoItemNode: ChatMessageItemView {
    private var videoNode: UniversalVideoNode?
    
    private var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    private var swipeToReplyFeedback: HapticFeedback?
    
    private var statusNode: RadialStatusNode?
    private var playbackStatusNode: InstantVideoRadialStatusNode?
    private var videoFrame: CGRect?
    
    private var selectionNode: ChatMessageSelectionNode?
    
    private var appliedItem: ChatMessageItem?
    var telegramFile: TelegramMediaFile?
    
    private let fetchDisposable = MetaDisposable()
    
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    private var forwardBackgroundNode: ASImageNode?
    
    private var replyInfoNode: ChatMessageReplyInfoNode?
    private var replyBackgroundNode: ASImageNode?
    
    private var durationNode: ChatInstantVideoMessageDurationNode?
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    
    private let infoBackgroundNode: ASImageNode
    private let muteIconNode: ASImageNode
    
    private var status: FileMediaResourceStatus?
    private let playbackStatusDisposable = MetaDisposable()
    
    private var currentSwipeToReplyTranslation: CGFloat = 0.0
    
    private var shouldAcquireVideoContext: Bool {
        if case .visible = self.visibility {
            return true
        } else {
            return false
        }
    }
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            if self.visibility != oldValue {
                self.videoNode?.canAttachContent = self.shouldAcquireVideoContext
                //self.hostedVideoNode?.setShouldAcquireContext(self.shouldAcquireVideoContext)
            }
        }
    }
    
    required init() {
        self.infoBackgroundNode = ASImageNode()
        self.infoBackgroundNode.isLayerBacked = true
        self.infoBackgroundNode.displayWithoutProcessing = true
        self.infoBackgroundNode.displaysAsynchronously = false
        
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        self.muteIconNode = ASImageNode()
        self.muteIconNode.isLayerBacked = true
        self.muteIconNode.displayWithoutProcessing = true
        self.muteIconNode.displaysAsynchronously = false
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.dateAndStatusNode)
        self.addSubnode(self.infoBackgroundNode)
        self.infoBackgroundNode.addSubnode(self.muteIconNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.playbackStatusDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
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
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let displaySize = CGSize(width: 212.0, height: 212.0)
        let previousFile = self.telegramFile
        let layoutConstants = self.layoutConstants
        
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentReplyBackgroundNode = self.replyBackgroundNode
        
        let makeForwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        let currentForwardBackgroundNode = self.forwardBackgroundNode
        
        let currentItem = self.appliedItem
        
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom in
            var updatedTheme: PresentationTheme?
            
            var updatedInfoBackgroundImage: UIImage?
            var updatedMuteIconImage: UIImage?
            if item.presentationData.theme !== currentItem?.presentationData.theme {
                updatedTheme = item.presentationData.theme
                updatedInfoBackgroundImage = PresentationResourcesChat.chatInstantMessageInfoBackgroundImage(item.presentationData.theme)
                updatedMuteIconImage = PresentationResourcesChat.chatInstantMessageMuteIconImage(item.presentationData.theme)
            }
            
            let instantVideoBackgroundImage = PresentationResourcesChat.chatInstantVideoBackgroundImage(item.presentationData.theme)
            
            let theme = item.presentationData.theme
            let isSecretMedia = item.message.containsSecretMedia
            
            let incoming = item.message.effectivelyIncoming(item.account.peerId)
            let imageSize = displaySize
            
            var updatedFile: TelegramMediaFile?
            var updatedMedia = false
            for media in item.message.media {
                if let file = media as? TelegramMediaFile {
                    updatedFile = file
                    if let previousFile = previousFile {
                        updatedMedia = !previousFile.isEqual(file)
                    } else if previousFile == nil {
                        updatedMedia = true
                    }
                }
            }
            
            var notConsumed = false
            for attribute in item.message.attributes {
                if let attribute = attribute as? ConsumableContentMessageAttribute {
                    if !attribute.consumed {
                        notConsumed = true
                    }
                    break
                }
            }
            
            var updatedPlaybackStatus: Signal<FileMediaResourceStatus, NoError>?
            if let updatedFile = updatedFile, updatedMedia {
                updatedPlaybackStatus = combineLatest(messageFileMediaResourceStatus(account: item.account, file: updatedFile, message: item.message), item.account.pendingMessageManager.pendingMessageStatus(item.message.id))
                    |> map { resourceStatus, pendingStatus -> FileMediaResourceStatus in
                        if let pendingStatus = pendingStatus {
                            var progress = pendingStatus.progress
                            if pendingStatus.isRunning {
                                progress = max(progress, 0.27)
                            }
                            return .fetchStatus(.Fetching(isActive: pendingStatus.isRunning, progress: progress))
                        } else {
                            return resourceStatus
                        }
                    }
            }
            
            let avatarInset: CGFloat
            var hasAvatar = false
            
            switch item.chatLocation {
                case let .peer(peerId):
                    if peerId.isGroupOrChannel && item.message.author != nil {
                        var isBroadcastChannel = false
                        if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                            isBroadcastChannel = true
                        }
                        
                        if !isBroadcastChannel {
                            hasAvatar = true
                        }
                    }
                case .group:
                    hasAvatar = true
            }
            
            if hasAvatar {
                avatarInset = layoutConstants.avatarDiameter
            } else {
                avatarInset = 0.0
            }
            
            var layoutInsets = layoutConstants.instantVideo.insets
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            let videoFrame = CGRect(origin: CGPoint(x: (incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + avatarInset + layoutConstants.bubble.contentInsets.left) : (params.width - params.rightInset - imageSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left)), y: 0.0), size: imageSize)
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: videoFrame.size.width / 2.0), imageSize: videoFrame.size, boundingSize: videoFrame.size, intrinsicInsets: UIEdgeInsets())
            
            var replyInfoApply: (CGSize, () -> ChatMessageReplyInfoNode)?
            var updatedReplyBackgroundNode: ASImageNode?
            var replyBackgroundImage: UIImage?
            for attribute in item.message.attributes {
                if let replyAttribute = attribute as? ReplyMessageAttribute, let replyMessage = item.message.associatedMessages[replyAttribute.messageId] {
                    let availableWidth = max(60.0, params.width - params.leftInset - params.rightInset - imageSize.width - 20.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left)
                    replyInfoApply = makeReplyInfoLayout(item.presentationData.theme, item.presentationData.strings, item.account, .standalone, replyMessage, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
                    
                    if let currentReplyBackgroundNode = currentReplyBackgroundNode {
                        updatedReplyBackgroundNode = currentReplyBackgroundNode
                    } else {
                        updatedReplyBackgroundNode = ASImageNode()
                    }
                    replyBackgroundImage = PresentationResourcesChat.chatServiceBubbleFillImage(item.presentationData.theme)
                    break
                }
            }
            
            var forwardInfoSizeApply: (CGSize, () -> ChatMessageForwardInfoNode)?
            var updatedForwardBackgroundNode: ASImageNode?
            var forwardBackgroundImage: UIImage?
            if let forwardInfo = item.message.forwardInfo {
                let forwardSource: Peer
                let forwardAuthorSignature: String?
                
                if let source = forwardInfo.source {
                    forwardSource = source
                    if let authorSignature = forwardInfo.authorSignature {
                        forwardAuthorSignature = authorSignature
                    } else if forwardInfo.author.id != source.id {
                        forwardAuthorSignature = forwardInfo.author.displayTitle
                    } else {
                        forwardAuthorSignature = nil
                    }
                } else {
                    forwardSource = forwardInfo.author
                    forwardAuthorSignature = nil
                }
                let availableWidth = max(60.0, params.width - params.leftInset - params.rightInset - imageSize.width + 6.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left)
                forwardInfoSizeApply = makeForwardInfoLayout(item.presentationData.theme, item.presentationData.strings, .standalone, forwardSource, forwardAuthorSignature, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
                
                if let currentForwardBackgroundNode = currentForwardBackgroundNode {
                    updatedForwardBackgroundNode = currentForwardBackgroundNode
                } else {
                    updatedForwardBackgroundNode = ASImageNode()
                }
                
                forwardBackgroundImage = PresentationResourcesChat.chatServiceBubbleFillImage(item.presentationData.theme)
            }
            
            let statusType: ChatMessageDateAndStatusType
            if item.message.effectivelyIncoming(item.account.peerId) {
                statusType = .FreeIncoming
            } else {
                if item.message.flags.contains(.Failed) {
                    statusType = .FreeOutgoing(.Failed)
                } else if item.message.flags.isSending {
                    statusType = .FreeOutgoing(.Sending)
                } else {
                    statusType = .FreeOutgoing(.Sent(read: item.read))
                }
            }
            
            var edited = false
            var sentViaBot = false
            var viewCount: Int?
            for attribute in item.message.attributes {
                if let _ = attribute as? EditedMessageAttribute {
                    edited = true
                } else if let attribute = attribute as? ViewCountMessageAttribute {
                    viewCount = attribute.count
                } else if let _ = attribute as? InlineBotMessageAttribute {
                    sentViaBot = true
                }
            }
            if let author = item.message.author as? TelegramUser, author.botInfo != nil {
                sentViaBot = true
            }
            
            let dateText = stringForMessageTimestampStatus(message: item.message, timeFormat: item.presentationData.timeFormat, strings: item.presentationData.strings)
            
            let (dateAndStatusSize, dateAndStatusApply) = makeDateAndStatusLayout(item.presentationData.theme, item.presentationData.strings, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude))
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: imageSize.height), insets: layoutInsets), { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.appliedItem = item
                    strongSelf.videoFrame = videoFrame
                    
                    if let updatedInfoBackgroundImage = updatedInfoBackgroundImage {
                        strongSelf.infoBackgroundNode.image = updatedInfoBackgroundImage
                    }
                    
                    if let updatedMuteIconImage = updatedMuteIconImage {
                        strongSelf.muteIconNode.image = updatedMuteIconImage
                    }
                    
                    strongSelf.telegramFile = updatedFile
                    
                    if let infoBackgroundImage = strongSelf.infoBackgroundNode.image, let muteImage = strongSelf.muteIconNode.image {
                        let infoWidth = muteImage.size.width
                        let transition: ContainedViewLayoutTransition
                        if animation.isAnimated {
                            transition = .animated(duration: 0.2, curve: .spring)
                        } else {
                            transition = .immediate
                        }
                        let infoBackgroundFrame = CGRect(origin: CGPoint(x: floor(videoFrame.minX + (videoFrame.size.width - infoWidth) / 2.0), y: videoFrame.maxY - infoBackgroundImage.size.height - 8.0), size: CGSize(width: infoWidth, height: infoBackgroundImage.size.height))
                        transition.updateFrame(node: strongSelf.infoBackgroundNode, frame: infoBackgroundFrame)
                        let muteIconFrame = CGRect(origin: CGPoint(x: infoBackgroundFrame.width - muteImage.size.width, y: 0.0), size: muteImage.size)
                        transition.updateFrame(node: strongSelf.muteIconNode, frame: muteIconFrame)
                    }
                    
                    if let updatedPlaybackStatus = updatedPlaybackStatus {
                        strongSelf.playbackStatusDisposable.set((updatedPlaybackStatus |> deliverOnMainQueue).start(next: { status in
                            if let strongSelf = self, let videoFrame = strongSelf.videoFrame {
                                strongSelf.status = status
                                
                                let displayMute: Bool
                                switch status {
                                    case let .fetchStatus(fetchStatus):
                                        switch fetchStatus {
                                            case .Local:
                                                displayMute = true
                                            default:
                                                displayMute = false
                                        }
                                    case .playbackStatus:
                                        displayMute = false
                                }
                                if displayMute != (!strongSelf.infoBackgroundNode.alpha.isZero) {
                                    if displayMute {
                                        strongSelf.infoBackgroundNode.alpha = 1.0
                                        strongSelf.infoBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                        strongSelf.infoBackgroundNode.layer.animateScale(from: 0.4, to: 1.0, duration: 0.15)
                                    } else {
                                        strongSelf.infoBackgroundNode.alpha = 0.0
                                        strongSelf.infoBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                                        strongSelf.infoBackgroundNode.layer.animateScale(from: 1.0, to: 0.4, duration: 0.15)
                                    }
                                }
                                
                                var progressRequired = false
                                if case let .fetchStatus(fetchStatus) = status {
                                    if case .Local = fetchStatus {
                                        if let file = updatedFile, file.isVideo {
                                            progressRequired = true
                                        } else if isSecretMedia {
                                            progressRequired = true
                                        }
                                    } else {
                                        progressRequired = true
                                    }
                                }
                                
                                if progressRequired {
                                    if strongSelf.statusNode == nil {
                                        let statusNode = RadialStatusNode(backgroundNodeColor: theme.chat.bubble.mediaOverlayControlBackgroundColor)
                                        statusNode.isUserInteractionEnabled = false
                                        statusNode.frame = CGRect(origin: CGPoint(x: videoFrame.origin.x + floor((videoFrame.size.width - 50.0) / 2.0), y: videoFrame.origin.y + floor((videoFrame.size.height - 50.0) / 2.0)), size: CGSize(width: 50.0, height: 50.0))
                                        strongSelf.statusNode = statusNode
                                        strongSelf.addSubnode(statusNode)
                                    } else if let _ = updatedTheme {
                                        
                                        //strongSelf.progressNode?.updateTheme(RadialProgressTheme(backgroundColor: theme.chat.bubble.mediaOverlayControlBackgroundColor, foregroundColor: theme.chat.bubble.mediaOverlayControlForegroundColor, icon: nil))
                                    }
                                } else {
                                    if let statusNode = strongSelf.statusNode {
                                        statusNode.transitionToState(.none, completion: { [weak statusNode] in
                                            statusNode?.removeFromSupernode()
                                        })
                                        strongSelf.statusNode = nil
                                    }
                                }
                                
                                var state: RadialStatusNodeState
                                let bubbleTheme = theme.chat.bubble
                                switch status {
                                    case let .fetchStatus(fetchStatus):
                                        switch fetchStatus {
                                            case let .Fetching(isActive, progress):
                                                var adjustedProgress = progress
                                                if isActive {
                                                    adjustedProgress = max(adjustedProgress, 0.027)
                                                }
                                                state = .progress(color: bubbleTheme.mediaOverlayControlForegroundColor, value: CGFloat(adjustedProgress), cancelEnabled: true)
                                            case .Local:
                                                state = .none
                                                /*if isSecretMedia && secretProgressIcon != nil {
                                                    state = .customIcon(secretProgressIcon!)
                                                } else */
                                            case .Remote:
                                                state = .download(bubbleTheme.mediaOverlayControlForegroundColor)
                                        }
                                    default:
                                        state = .none
                                        break
                                }
                                if let statusNode = strongSelf.statusNode {
                                    if state == .none {
                                        strongSelf.statusNode = nil
                                    }
                                    statusNode.transitionToState(state, completion: { [weak statusNode] in
                                        if state == .none {
                                            statusNode?.removeFromSupernode()
                                        }
                                    })
                                }
                                
                                if case .playbackStatus = status {
                                    let playbackStatusNode: InstantVideoRadialStatusNode
                                    if let current = strongSelf.playbackStatusNode {
                                        playbackStatusNode = current
                                    } else {
                                        playbackStatusNode = InstantVideoRadialStatusNode(color: UIColor(white: 1.0, alpha: 0.8))
                                        strongSelf.addSubnode(playbackStatusNode)
                                        strongSelf.playbackStatusNode = playbackStatusNode
                                    }
                                    playbackStatusNode.frame = videoFrame.insetBy(dx: 1.5, dy: 1.5)
                                    if let updatedFile = updatedFile {
                                        let status = messageFileMediaPlaybackStatus(account: item.account, file: updatedFile, message: item.message)
                                        playbackStatusNode.status = status
                                        strongSelf.durationNode?.status = status |> map(Optional.init)
                                    }
                                } else {
                                    if let playbackStatusNode = strongSelf.playbackStatusNode {
                                        strongSelf.playbackStatusNode = nil
                                        playbackStatusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak playbackStatusNode] _ in
                                            playbackStatusNode?.removeFromSupernode()
                                        })
                                    }
                                    
                                    strongSelf.durationNode?.status = .single(nil)
                                }
                            }
                        }))
                    }
                    
                    dateAndStatusApply(false)
                    strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: min(floor(videoFrame.midX) + 55.0, params.width - params.rightInset - dateAndStatusSize.width - 4.0), y: videoFrame.maxY - dateAndStatusSize.height), size: dateAndStatusSize)
                    
                    if let telegramFile = updatedFile, updatedMedia {
                        let durationNode: ChatInstantVideoMessageDurationNode
                        if let current = strongSelf.durationNode {
                            durationNode = current
                        } else {
                            durationNode = ChatInstantVideoMessageDurationNode(textColor: theme.chat.serviceMessage.serviceMessagePrimaryTextColor, fillColor: theme.chat.serviceMessage.serviceMessageFillColor)
                            strongSelf.durationNode = durationNode
                            strongSelf.addSubnode(durationNode)
                        }
                        durationNode.defaultDuration = telegramFile.duration.flatMap(Double.init)
                        
                        if let videoNode = strongSelf.videoNode {
                            videoNode.layer.allowsGroupOpacity = true
                            videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.5, delay: 0.2, removeOnCompletion: false, completion: { [weak videoNode] _ in
                                videoNode?.removeFromSupernode()
                            })
                        }
                        let videoNode = UniversalVideoNode(postbox: item.account.postbox, audioSession: item.account.telegramApplicationContext.mediaManager.audioSession, manager: item.account.telegramApplicationContext.mediaManager.universalVideoManager, decoration: ChatBubbleInstantVideoDecoration(diameter: 214.0, backgroundImage: instantVideoBackgroundImage, tapped: {
                            if let strongSelf = self {
                                if let item = strongSelf.item {
                                    if strongSelf.infoBackgroundNode.alpha.isZero {
                                        item.account.telegramApplicationContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: .voice)
                                    } else {
                                        let _ = item.controllerInteraction.openMessage(item.message)
                                    }
                                }
                            }
                        }), content: NativeVideoContent(id: .message(item.message.id, item.message.stableId, telegramFile.fileId), file: telegramFile, streamVideo: false, enableSound: false), priority: .embedded, autoplay: true)
                        let previousVideoNode = strongSelf.videoNode
                        strongSelf.videoNode = videoNode
                        strongSelf.insertSubnode(videoNode, belowSubnode: previousVideoNode ?? strongSelf.dateAndStatusNode)
                        videoNode.canAttachContent = strongSelf.shouldAcquireVideoContext
                    }
                    
                    if let durationNode = strongSelf.durationNode {
                        durationNode.frame = CGRect(origin: CGPoint(x: videoFrame.midX - 56.0, y: videoFrame.maxY - 18.0), size: CGSize(width: 1.0, height: 1.0))
                        durationNode.isSeen = !notConsumed
                    }
                    
                    if let videoNode = strongSelf.videoNode {
                        videoNode.frame = videoFrame
                        videoNode.updateLayout(size: arguments.boundingSize, transition: .immediate)
                    }
                    
                    if let updatedReplyBackgroundNode = updatedReplyBackgroundNode {
                        if strongSelf.replyBackgroundNode == nil {
                            strongSelf.replyBackgroundNode = updatedReplyBackgroundNode
                            strongSelf.addSubnode(updatedReplyBackgroundNode)
                            updatedReplyBackgroundNode.image = replyBackgroundImage
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
                        let replyInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 10.0) : (params.width - params.rightInset - replyInfoSize.width - layoutConstants.bubble.edgeInset - 10.0)), y: imageSize.height - replyInfoSize.height - 8.0), size: replyInfoSize)
                        replyInfoNode.frame = replyInfoFrame
                        strongSelf.replyBackgroundNode?.frame = CGRect(origin: CGPoint(x: replyInfoFrame.minX - 4.0, y: replyInfoFrame.minY - 2.0), size: CGSize(width: replyInfoFrame.size.width + 8.0, height: replyInfoFrame.size.height + 5.0))
                    } else if let replyInfoNode = strongSelf.replyInfoNode {
                        replyInfoNode.removeFromSupernode()
                        strongSelf.replyInfoNode = nil
                    }
                    
                    if let updatedForwardBackgroundNode = updatedForwardBackgroundNode {
                        if strongSelf.forwardBackgroundNode == nil {
                            strongSelf.forwardBackgroundNode = updatedForwardBackgroundNode
                            strongSelf.addSubnode(updatedForwardBackgroundNode)
                            updatedForwardBackgroundNode.image = forwardBackgroundImage
                        }
                    } else if let forwardBackgroundNode = strongSelf.forwardBackgroundNode {
                        forwardBackgroundNode.removeFromSupernode()
                        strongSelf.forwardBackgroundNode = nil
                    }
                    
                    if let (forwardInfoSize, forwardInfoApply) = forwardInfoSizeApply {
                        let forwardInfoNode = forwardInfoApply()
                        if strongSelf.forwardInfoNode == nil {
                            strongSelf.forwardInfoNode = forwardInfoNode
                            strongSelf.addSubnode(forwardInfoNode)
                        }
                        let forwardInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 12.0) : (params.width - params.rightInset - forwardInfoSize.width - layoutConstants.bubble.edgeInset - 12.0)), y: 8.0), size: forwardInfoSize)
                        forwardInfoNode.frame = forwardInfoFrame
                        strongSelf.forwardBackgroundNode?.frame = CGRect(origin: CGPoint(x: forwardInfoFrame.minX - 6.0, y: forwardInfoFrame.minY - 2.0), size: CGSize(width: forwardInfoFrame.size.width + 10.0, height: forwardInfoFrame.size.height + 4.0))
                    } else if let forwardInfoNode = strongSelf.forwardInfoNode {
                        forwardInfoNode.removeFromSupernode()
                        strongSelf.forwardInfoNode = nil
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
                            if let item = self.item, let author = item.message.author {
                                item.controllerInteraction.openPeer(author.id, .info, item.message)
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
                        
                        if let forwardInfoNode = self.forwardInfoNode, forwardInfoNode.frame.contains(location) {
                            if let item = self.item, let forwardInfo = item.message.forwardInfo {
                                if let sourceMessageId = forwardInfo.sourceMessageId {
                                    item.controllerInteraction.navigateToMessage(item.message.id, sourceMessageId)
                                } else {
                                    item.controllerInteraction.openPeer(forwardInfo.source?.id ?? forwardInfo.author.id, .chat(textInputState: nil, messageId: nil), nil)
                                }
                                return
                            }
                        }
                        
                        if let statusNode = self.statusNode, statusNode.supernode != nil, !statusNode.isHidden, statusNode.frame.contains(location) {
                            self.progressPressed()
                            return
                        }
                        
                        if let item = self.item, let videoNode = self.videoNode, videoNode.frame.contains(location) {
                            if self.infoBackgroundNode.alpha.isZero {
                                item.account.telegramApplicationContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: .voice)
                            } else {
                                let _ = item.controllerInteraction.openMessage(item.message)
                            }
                            return
                        }
                        
                        self.item?.controllerInteraction.clickThroughMessage()
                    case .longTap, .doubleTap:
                        if let item = self.item, let videoNode = self.videoNode, videoNode.frame.contains(location) {
                            item.controllerInteraction.openMessageContextMenu(item.message, self, videoNode.frame)
                        }
                    case .hold:
                        break
                }
            }
        default:
            break
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
            let translation = recognizer.translation(in: self.view)
            var animateReplyNodeIn = false
            if (translation.x < -45.0) != (self.currentSwipeToReplyTranslation < -45.0) {
                if translation.x < -45.0, self.swipeToReplyNode == nil, let item = self.item {
                    self.swipeToReplyFeedback?.impact()
                    
                    let swipeToReplyNode = ChatMessageSwipeToReplyNode(fillColor: item.presentationData.theme.chat.bubble.shareButtonFillColor, strokeColor: item.presentationData.theme.chat.bubble.shareButtonStrokeColor, foregroundColor: item.presentationData.theme.chat.bubble.shareButtonForegroundColor)
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
        if !self.bounds.contains(point) {
            return nil
        }
        if let statusNode = self.statusNode, statusNode.supernode != nil, !statusNode.isHidden, statusNode.frame.contains(point) {
            return self.view
        }
        return super.hitTest(point, with: event)
    }
    
    private func progressPressed() {
        guard let item = self.item, let file = self.telegramFile else {
            return
        }
        if let status = self.status {
            switch status {
                case let .fetchStatus(fetchStatus):
                    switch fetchStatus {
                        case .Fetching:
                            if item.message.flags.isSending {
                                let messageId = item.message.id
                                let _ = item.account.postbox.modify({ modifier -> Void in
                                    modifier.deleteMessages([messageId])
                                }).start()
                            } else {
                                self.videoNode?.fetchControl(.cancel)
                            }
                        case .Remote:
                            self.videoNode?.fetchControl(.fetch)
                        case .Local:
                            break
                    }
                default:
                    break
            }
        }
    }
    
    override func updateSelectionState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        if let selectionState = item.controllerInteraction.selectionState {
            var selected = false
            var incoming = true
            
            selected = selectionState.selectedIds.contains(item.message.id)
            incoming = item.message.effectivelyIncoming(item.account.peerId)
            
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: false)
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(theme: item.presentationData.theme, toggle: { [weak self] value in
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
