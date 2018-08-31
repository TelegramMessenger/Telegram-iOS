import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

struct ChatMessageInstantVideoItemLayoutResult {
    let contentSize: CGSize
    let overflowLeft: CGFloat
    let overflowRight: CGFloat
}

enum ChatMessageInstantVideoItemLayoutData {
    case unconstrained(width: CGFloat)
    case constrained(left: CGFloat, right: CGFloat)
}

private let textFont = Font.regular(11.0)

enum ChatMessageInteractiveInstantVideoNodeStatusType {
    case free
    case bubble
}

class ChatMessageInteractiveInstantVideoNode: ASDisplayNode {
    private var videoNode: UniversalVideoNode?
    
    private var statusNode: RadialStatusNode?
    private var playbackStatusNode: InstantVideoRadialStatusNode?
    private var videoFrame: CGRect?
    
    private var item: ChatMessageBubbleContentItem?
    var telegramFile: TelegramMediaFile?
    
    private let fetchDisposable = MetaDisposable()
    
    private var durationNode: ChatInstantVideoMessageDurationNode?
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    
    private let infoBackgroundNode: ASImageNode
    private let muteIconNode: ASImageNode
    
    private var status: FileMediaResourceStatus?
    private let playbackStatusDisposable = MetaDisposable()
    
    private var shouldAcquireVideoContext: Bool {
        if case .visible = self.visibility {
            return true
        } else {
            return false
        }
    }
    
    var visibility: ListViewItemNodeVisibility = .none {
        didSet {
            if self.visibility != oldValue {
                self.videoNode?.canAttachContent = self.shouldAcquireVideoContext
            }
        }
    }
    
    override init() {
        self.infoBackgroundNode = ASImageNode()
        self.infoBackgroundNode.isLayerBacked = true
        self.infoBackgroundNode.displayWithoutProcessing = true
        self.infoBackgroundNode.displaysAsynchronously = false
        
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        self.muteIconNode = ASImageNode()
        self.muteIconNode.isLayerBacked = true
        self.muteIconNode.displayWithoutProcessing = true
        self.muteIconNode.displaysAsynchronously = false
        
        super.init()
        
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
    }
    
    func asyncLayout() -> (_ item: ChatMessageBubbleContentItem, _ width: CGFloat, _ displaySize: CGSize, _ statusType: ChatMessageInteractiveInstantVideoNodeStatusType) -> (ChatMessageInstantVideoItemLayoutResult, (ChatMessageInstantVideoItemLayoutData, ContainedViewLayoutTransition) -> Void) {
        let previousFile = self.telegramFile
        
        let currentItem = self.item
        
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        
        return { item, width, displaySize, statusDisplayType in
            var updatedTheme: PresentationTheme?
            
            var updatedInfoBackgroundImage: UIImage?
            var updatedMuteIconImage: UIImage?
            if item.presentationData.theme !== currentItem?.presentationData.theme {
                updatedTheme = item.presentationData.theme
                updatedInfoBackgroundImage = PresentationResourcesChat.chatInstantMessageInfoBackgroundImage(item.presentationData.theme)
                updatedMuteIconImage = PresentationResourcesChat.chatInstantMessageMuteIconImage(item.presentationData.theme)
            }
            
            let instantVideoBackgroundImage: UIImage?
            switch statusDisplayType {
                case .free:
                    instantVideoBackgroundImage = PresentationResourcesChat.chatInstantVideoBackgroundImage(item.presentationData.theme)
                case .bubble:
                    instantVideoBackgroundImage = nil
            }
            
            let theme = item.presentationData.theme
            let isSecretMedia = item.message.containsSecretMedia
            
            let imageSize = displaySize
            
            var updatedFile: TelegramMediaFile?
            var updatedMedia = false
            for media in item.message.media {
                if let file = media as? TelegramMediaFile {
                    updatedFile = file
                    if let previousFile = previousFile {
                        updatedMedia = !previousFile.resource.isEqual(to: file.resource)
                    } else if previousFile == nil {
                        updatedMedia = true
                    }
                } else if let webPage = media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content, let file = content.file {
                    updatedFile = file
                    if let previousFile = previousFile {
                        updatedMedia = !previousFile.resource.isEqual(to: file.resource)
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
            
            let videoFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: imageSize)
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: videoFrame.size.width / 2.0), imageSize: videoFrame.size, boundingSize: videoFrame.size, intrinsicInsets: UIEdgeInsets())
            
            let statusType: ChatMessageDateAndStatusType
            if item.message.effectivelyIncoming(item.account.peerId) {
                switch statusDisplayType {
                    case .free:
                        statusType = .FreeIncoming
                    case .bubble:
                        statusType = .BubbleIncoming
                }
            } else {
                switch statusDisplayType {
                    case .free:
                        if item.message.flags.contains(.Failed) {
                            statusType = .FreeOutgoing(.Failed)
                        } else if item.message.flags.isSending {
                            statusType = .FreeOutgoing(.Sending)
                        } else {
                            statusType = .FreeOutgoing(.Sent(read: item.read))
                        }
                    case .bubble:
                        if item.message.flags.contains(.Failed) {
                            statusType = .BubbleOutgoing(.Failed)
                        } else if item.message.flags.isSending {
                            statusType = .BubbleOutgoing(.Sending)
                        } else {
                            statusType = .BubbleOutgoing(.Sent(read: item.read))
                        }
                }
            }
            
            let edited = false
            let sentViaBot = false
            let viewCount: Int? = nil
            /*for attribute in item.message.attributes {
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
            }*/
            
            let dateText = stringForMessageTimestampStatus(message: item.message, timeFormat: item.presentationData.timeFormat, strings: item.presentationData.strings, format: .minimal)
            
            let (dateAndStatusSize, dateAndStatusApply) = makeDateAndStatusLayout(item.presentationData.theme, item.presentationData.strings, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
            
            let result = ChatMessageInstantVideoItemLayoutResult(contentSize: imageSize, overflowLeft: 0.0, overflowRight: max(0.0, floor(videoFrame.midX) + 55.0 + dateAndStatusSize.width - videoFrame.width))
            
            return (result, { [weak self] layoutData, transition in
                if let strongSelf = self {
                    strongSelf.item = item
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
                    switch layoutData {
                        case let .unconstrained(width):
                            strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: min(floor(videoFrame.midX) + 55.0, width - dateAndStatusSize.width - 4.0), y: videoFrame.height - dateAndStatusSize.height), size: dateAndStatusSize)
                        case let .constrained(_, right):
                            strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: min(floor(videoFrame.midX) + 55.0, videoFrame.maxX + right - dateAndStatusSize.width - 4.0), y: videoFrame.maxY - dateAndStatusSize.height), size: dateAndStatusSize)
                    }
                    
                    if let telegramFile = updatedFile, updatedMedia {
                        let durationTextColor: UIColor
                        let durationFillColor: UIColor
                        switch statusDisplayType {
                            case .free:
                                durationTextColor = theme.chat.serviceMessage.serviceMessagePrimaryTextColor
                                durationFillColor = theme.chat.serviceMessage.serviceMessageFillColor
                            case .bubble:
                                durationFillColor = .clear
                                if item.message.effectivelyIncoming(item.account.peerId) {
                                    durationTextColor = theme.chat.bubble.incomingSecondaryTextColor
                                } else {
                                    durationTextColor = theme.chat.bubble.outgoingSecondaryTextColor
                                }
                        }
                        let durationNode: ChatInstantVideoMessageDurationNode
                        if let current = strongSelf.durationNode {
                            durationNode = current
                            current.updateTheme(textColor: durationTextColor, fillColor: durationFillColor)
                        } else {
                            durationNode = ChatInstantVideoMessageDurationNode(textColor: durationTextColor, fillColor: durationFillColor)
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
                        let videoNode = UniversalVideoNode(postbox: item.account.postbox, audioSession: item.account.telegramApplicationContext.mediaManager.audioSession, manager: item.account.telegramApplicationContext.mediaManager.universalVideoManager, decoration: ChatBubbleInstantVideoDecoration(diameter: displaySize.width + 2.0, backgroundImage: instantVideoBackgroundImage, tapped: {
                            if let strongSelf = self {
                                if let item = strongSelf.item {
                                    if strongSelf.infoBackgroundNode.alpha.isZero {
                                        item.account.telegramApplicationContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: .voice)
                                    } else {
                                        //let _ = item.controllerInteraction.openMessage(item.message)
                                    }
                                }
                            }
                        }), content: NativeVideoContent(id: .message(item.message.id, item.message.stableId, telegramFile.fileId), fileReference: .message(message: MessageReference(item.message), media: telegramFile), streamVideo: false, enableSound: false), priority: .embedded, autoplay: true)
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        if let statusNode = self.statusNode, statusNode.supernode != nil, !statusNode.isHidden, statusNode.frame.contains(point) {
            return self.view
        }
        if let videoNode = self.videoNode, videoNode.frame.contains(point) {
            return self.view
        }
        return super.hitTest(point, with: event)
    }
    
    private func progressPressed() {
        guard let item = self.item, let _ = self.telegramFile else {
            return
        }
        if let status = self.status {
            switch status {
            case let .fetchStatus(fetchStatus):
                switch fetchStatus {
                    case .Fetching:
                        if item.message.flags.isSending {
                            let messageId = item.message.id
                            let _ = item.account.postbox.transaction({ transaction -> Void in
                                deleteMessages(transaction: transaction, mediaBox: item.account.postbox.mediaBox, ids: [messageId])
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
    
    func videoContentNode(at point: CGPoint) -> ASDisplayNode? {
        if let videoFrame = self.videoFrame {
            if videoFrame.contains(point) {
                return self.videoNode
            }
        }
        return nil
    }

    static func asyncLayout(_ node: ChatMessageInteractiveInstantVideoNode?) -> (_ item: ChatMessageBubbleContentItem, _ width: CGFloat, _ displaySize: CGSize, _ statusType: ChatMessageInteractiveInstantVideoNodeStatusType) -> (ChatMessageInstantVideoItemLayoutResult, (ChatMessageInstantVideoItemLayoutData, ContainedViewLayoutTransition) -> ChatMessageInteractiveInstantVideoNode) {
        let makeLayout = node?.asyncLayout()
        return { item, width, displaySize, statusType in
            var createdNode: ChatMessageInteractiveInstantVideoNode?
            let sizeAndApplyLayout: (ChatMessageInstantVideoItemLayoutResult, (ChatMessageInstantVideoItemLayoutData, ContainedViewLayoutTransition) -> Void)
            if let makeLayout = makeLayout {
                sizeAndApplyLayout = makeLayout(item, width, displaySize, statusType)
            } else {
                let node = ChatMessageInteractiveInstantVideoNode()
                sizeAndApplyLayout = node.asyncLayout()(item, width, displaySize, statusType)
                createdNode = node
            }
            return (sizeAndApplyLayout.0, { [weak node] layoutData, transition in
                sizeAndApplyLayout.1(layoutData, transition)
                if let createdNode = createdNode {
                    return createdNode
                } else {
                    return node!
                }
            })
        }
    }
}

