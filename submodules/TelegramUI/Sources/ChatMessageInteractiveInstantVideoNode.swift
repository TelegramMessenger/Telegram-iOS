import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import UniversalMediaPlayer
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import PhotoResources
import TelegramUniversalVideoContent
import FileMediaResourceStatus
import HierarchyTrackingLayer
import ComponentFlow
import AudioTranscriptionButtonComponent
import UndoUI
import TelegramNotices

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
    private var hierarchyTrackingLayer: HierarchyTrackingLayer?
    private var trackingIsInHierarchy: Bool = false {
        didSet {
            if self.trackingIsInHierarchy != oldValue {
                Queue.mainQueue().justDispatch {
                    self.videoNode?.canAttachContent = self.shouldAcquireVideoContext
                }
            }
        }
    }
    
    var customIsHidden: Bool = false {
        didSet {
            if self.customIsHidden != oldValue {
                Queue.mainQueue().justDispatch {
                    self.videoNode?.canAttachContent = self.shouldAcquireVideoContext
                }
            }
        }
    }
    
    private var videoNode: UniversalVideoNode?
    private let secretVideoPlaceholderBackground: ASImageNode
    private let secretVideoPlaceholder: TransformImageNode
    
    var audioTranscriptionButton: ComponentHostView<Empty>?
    
    private var statusNode: RadialStatusNode?
    private var disappearingStatusNode: RadialStatusNode?
    private var playbackStatusNode: InstantVideoRadialStatusNode?
    private(set) var videoFrame: CGRect?
    private var imageScale: CGFloat = 1.0
    
    private var item: ChatMessageBubbleContentItem?
    private var automaticDownload: Bool?
    var media: TelegramMediaFile?
    private var secretProgressIcon: UIImage?
    
    private let fetchDisposable = MetaDisposable()

    private var durationBackgroundNode: NavigationBackgroundNode?
    private var durationNode: ChatInstantVideoMessageDurationNode?
    let dateAndStatusNode: ChatMessageDateAndStatusNode
    
    private let infoBackgroundNode: ASImageNode
    private let muteIconNode: ASImageNode
    
    private var status: FileMediaResourceStatus?
    private var playerStatus: MediaPlayerStatus? {
        didSet {
            if self.playerStatus != oldValue {
                self.updateStatus(animator: nil)
            }
        }
    }
    private let playbackStatusDisposable = MetaDisposable()
    private let playerStatusDisposable = MetaDisposable()
    private let fetchedThumbnailDisposable = MetaDisposable()
    
    private var shouldAcquireVideoContext: Bool {
        if self.visibility && self.trackingIsInHierarchy && !self.customIsHidden {
            return true
        } else {
            return false
        }
    }
    
    var visibility: Bool = false {
        didSet {
            if self.visibility != oldValue {
                self.videoNode?.canAttachContent = self.shouldAcquireVideoContext
            }
        }
    }
    
    var shouldOpen: () -> Bool = { return true }
    
    var updateTranscriptionExpanded: ((AudioTranscriptionButtonComponent.TranscriptionState) -> Void)?
    var updateTranscriptionText: ((TranscribedText?) -> Void)?
    
    var audioTranscriptionState: AudioTranscriptionButtonComponent.TranscriptionState = .collapsed
    var audioTranscriptionText: TranscribedText?
    private var transcribeDisposable: Disposable?
    var hasExpandedAudioTranscription: Bool {
        if case .expanded = audioTranscriptionState {
            return true
        } else {
            return false
        }
    }
    private var isWaitingForCollapse: Bool = false
    
    var requestUpdateLayout: (Bool) -> Void = { _ in }
    
    override init() {
        self.secretVideoPlaceholderBackground = ASImageNode()
        self.secretVideoPlaceholderBackground.isLayerBacked = true
        self.secretVideoPlaceholderBackground.displaysAsynchronously = false
        self.secretVideoPlaceholderBackground.displayWithoutProcessing = true
        self.secretVideoPlaceholder = TransformImageNode()
        
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
        self.playerStatusDisposable.dispose()
        self.fetchedThumbnailDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { point in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(recognizer)
        
        let hierarchyTrackingLayer = HierarchyTrackingLayer()
        hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.trackingIsInHierarchy = true
        }
        
        hierarchyTrackingLayer.didExitHierarchy = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.trackingIsInHierarchy = false
        }
        self.hierarchyTrackingLayer = hierarchyTrackingLayer
        self.layer.addSublayer(hierarchyTrackingLayer)
    }
    
    func asyncLayout() -> (_ item: ChatMessageBubbleContentItem, _ width: CGFloat, _ displaySize: CGSize, _ maximumDisplaySize: CGSize, _ scaleProgress: CGFloat, _ statusType: ChatMessageInteractiveInstantVideoNodeStatusType, _ automaticDownload: Bool) -> (ChatMessageInstantVideoItemLayoutResult, (ChatMessageInstantVideoItemLayoutData, ListViewItemUpdateAnimation) -> Void) {
        let previousFile = self.media
        
        let currentItem = self.item
        let previousAutomaticDownload = self.automaticDownload
        
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        
        let audioTranscriptionState = self.audioTranscriptionState
        let audioTranscriptionText = self.audioTranscriptionText
        
        return { item, width, displaySize, maximumDisplaySize, scaleProgress, statusDisplayType, automaticDownload in
            var secretVideoPlaceholderBackgroundImage: UIImage?
            var updatedInfoBackgroundImage: UIImage?
            var updatedMuteIconImage: UIImage?
            
            var updatedInstantVideoBackgroundImage: UIImage?
            let instantVideoBackgroundImage: UIImage?
            
            switch statusDisplayType {
                case .free:
                    instantVideoBackgroundImage = nil
                case .bubble:
                    instantVideoBackgroundImage = nil
            }
            
            if item.presentationData.theme != currentItem?.presentationData.theme {
                updatedInstantVideoBackgroundImage = instantVideoBackgroundImage
                updatedInfoBackgroundImage = PresentationResourcesChat.chatInstantMessageInfoBackgroundImage(item.presentationData.theme.theme)
                updatedMuteIconImage = PresentationResourcesChat.chatInstantMessageMuteIconImage(item.presentationData.theme.theme)
            }
            
            let theme = item.presentationData.theme
            let isSecretMedia = item.message.containsSecretMedia
            var secretProgressIcon: UIImage?
            if isSecretMedia {
                secretProgressIcon = PresentationResourcesChat.chatBubbleSecretMediaIcon(theme.theme)
                secretVideoPlaceholderBackgroundImage = PresentationResourcesChat.chatInstantVideoBackgroundImage(theme.theme, wallpaper: !theme.wallpaper.isEmpty)
            }
            
            let imageSize = maximumDisplaySize
            let imageScale = displaySize.width / maximumDisplaySize.width
            
            let updatedMessageId = item.message.id != currentItem?.message.id
            
            var updatedFile: TelegramMediaFile?
            var updatedMedia = false
            for media in item.message.media {
                if let file = media as? TelegramMediaFile {
                    updatedFile = file
                    if let previousFile = previousFile {
                        updatedMedia = previousFile.resource.id != file.resource.id
                    } else if previousFile == nil {
                        updatedMedia = true
                    }
                } else if let webPage = media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content, let file = content.file {
                    updatedFile = file
                    if let previousFile = previousFile {
                        updatedMedia = previousFile.resource.id != file.resource.id
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
            if item.message.id.namespace == Namespaces.Message.Local || item.message.id.namespace == Namespaces.Message.ScheduledLocal {
                notConsumed = true
            }
            
            var updatedPlaybackStatus: Signal<FileMediaResourceStatus, NoError>?
            if let updatedFile = updatedFile, updatedMedia || updatedMessageId {
                updatedPlaybackStatus = combineLatest(messageFileMediaResourceStatus(context: item.context, file: updatedFile, message: item.message, isRecentActions: item.associatedData.isRecentActions), item.context.account.pendingMessageManager.pendingMessageStatus(item.message.id) |> map { $0.0 })
                |> map { resourceStatus, pendingStatus -> FileMediaResourceStatus in
                    if let pendingStatus = pendingStatus {
                        var progress = pendingStatus.progress
                        if pendingStatus.isRunning {
                            progress = max(progress, 0.27)
                        }
                        return FileMediaResourceStatus(mediaStatus: .fetchStatus(.Fetching(isActive: pendingStatus.isRunning, progress: progress)), fetchStatus: resourceStatus.fetchStatus)
                    } else {
                        return resourceStatus
                    }
                }
            }
            
            let videoFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: imageSize)
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: videoFrame.size.width / 2.0), imageSize: videoFrame.size, boundingSize: videoFrame.size, intrinsicInsets: UIEdgeInsets())
            
            let statusType: ChatMessageDateAndStatusType
            if item.message.effectivelyIncoming(item.context.account.peerId) {
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
                        } else if item.message.flags.isSending && !item.message.isSentOrAcknowledged {
                            statusType = .FreeOutgoing(.Sending)
                        } else {
                            statusType = .FreeOutgoing(.Sent(read: item.read))
                        }
                    case .bubble:
                        if item.message.flags.contains(.Failed) {
                            statusType = .BubbleOutgoing(.Failed)
                        } else if (item.message.flags.isSending && !item.message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                            statusType = .BubbleOutgoing(.Sending)
                        } else {
                            statusType = .BubbleOutgoing(.Sent(read: item.read))
                        }
                }
            }
            
            var edited = false
            if item.attributes.updatingMedia != nil {
                edited = true
            }
            let sentViaBot = false
            var viewCount: Int? = nil
            var dateReplies = 0
            let dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeer: item.associatedData.accountPeer, message: item.message)
            for attribute in item.message.attributes {
                if let attribute = attribute as? EditedMessageAttribute {
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
            
            let maxDateAndStatusWidth: CGFloat
            if case .bubble = statusDisplayType {
                maxDateAndStatusWidth = width
            } else {
                maxDateAndStatusWidth = width - videoFrame.midX - 85.0
            }
            
            var isReplyThread = false
            if case .replyThread = item.chatLocation {
                isReplyThread = true
            }
            
            let statusSuggestedWidthAndContinue = makeDateAndStatusLayout(ChatMessageDateAndStatusNode.Arguments(
                context: item.context,
                presentationData: item.presentationData,
                edited: edited && !sentViaBot,
                impressionCount: viewCount,
                dateText: dateText,
                type: statusType,
                layoutInput: .standalone(reactionSettings: shouldDisplayInlineDateReactions(message: item.message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.StandaloneReactionSettings() : nil),
                constrainedSize: CGSize(width: max(1.0, maxDateAndStatusWidth), height: CGFloat.greatestFiniteMagnitude),
                availableReactions: item.associatedData.availableReactions,
                reactions: dateReactionsAndPeers.reactions,
                reactionPeers: dateReactionsAndPeers.peers,
                displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                replyCount: dateReplies,
                isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && !isReplyThread,
                hasAutoremove: item.message.isSelfExpiring,
                canViewReactionList: canViewMessageReactionList(message: item.message),
                animationCache: item.controllerInteraction.presentationContext.animationCache,
                animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
            ))
            
            let (dateAndStatusSize, dateAndStatusApply) = statusSuggestedWidthAndContinue.1(statusSuggestedWidthAndContinue.0)
            
            var displayVideoFrame = videoFrame
            displayVideoFrame.size.width *= imageScale
            displayVideoFrame.size.height *= imageScale
            
            var contentSize = displayVideoFrame.size
            var dateAndStatusOverflow = false
            if case .bubble = statusDisplayType, displayVideoFrame.maxX + dateAndStatusSize.width > width {
                contentSize.height += dateAndStatusSize.height + 2.0
                contentSize.width = max(contentSize.width, dateAndStatusSize.width)
                dateAndStatusOverflow = true
            }
            
            let result = ChatMessageInstantVideoItemLayoutResult(contentSize: contentSize, overflowLeft: 0.0, overflowRight: dateAndStatusOverflow ? 0.0 : (max(0.0, floorToScreenPixels(videoFrame.midX) + 55.0 + dateAndStatusSize.width - videoFrame.width)))
            
            var updatedAudioTranscriptionState: AudioTranscriptionButtonComponent.TranscriptionState?
            let transcribedText = transcribedText(message: item.message)
            
            switch audioTranscriptionState {
            case .inProgress:
                if transcribedText != nil {
                    updatedAudioTranscriptionState = .expanded
                }
            default:
                break
            }
            
            var updatedTranscriptionText: TranscribedText?
            if audioTranscriptionText != transcribedText {
                updatedTranscriptionText = transcribedText
            }
            
            let effectiveAudioTranscriptionState = updatedAudioTranscriptionState ?? audioTranscriptionState
            
            return (result, { [weak self] layoutData, animation in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.videoFrame = displayVideoFrame
                    strongSelf.secretProgressIcon = secretProgressIcon
                    strongSelf.automaticDownload = automaticDownload
                    
                    if let updatedAudioTranscriptionState = updatedAudioTranscriptionState {
                        strongSelf.audioTranscriptionState = updatedAudioTranscriptionState
                        strongSelf.updateTranscriptionExpanded?(strongSelf.audioTranscriptionState)
                    }
                    if let updatedTranscriptionText = updatedTranscriptionText {
                        strongSelf.audioTranscriptionText = updatedTranscriptionText
                        strongSelf.updateTranscriptionText?(strongSelf.audioTranscriptionText)
                    }
                    
                    if let updatedInfoBackgroundImage = updatedInfoBackgroundImage {
                        strongSelf.infoBackgroundNode.image = updatedInfoBackgroundImage
                    }
                    
                    if let updatedMuteIconImage = updatedMuteIconImage {
                        strongSelf.muteIconNode.image = updatedMuteIconImage
                    }
                    
                    if let secretVideoPlaceholderBackgroundImage = secretVideoPlaceholderBackgroundImage {
                        strongSelf.secretVideoPlaceholderBackground.image = secretVideoPlaceholderBackgroundImage
                    }
                    
                    if let updatedInstantVideoBackgroundImage = updatedInstantVideoBackgroundImage, let decoration = strongSelf.videoNode?.decoration as? ChatBubbleInstantVideoDecoration, let decorationBackgroundNode = decoration.backgroundNode as? ASImageNode {
                        decorationBackgroundNode.image = updatedInstantVideoBackgroundImage
                    }
                    
                    strongSelf.media = updatedFile
                    
                    if let infoBackgroundImage = strongSelf.infoBackgroundNode.image, let muteImage = strongSelf.muteIconNode.image {
                        let infoWidth = muteImage.size.width
                        let infoBackgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(displayVideoFrame.minX + (displayVideoFrame.size.width - infoWidth) / 2.0), y: displayVideoFrame.maxY - infoBackgroundImage.size.height - 8.0), size: CGSize(width: infoWidth, height: infoBackgroundImage.size.height))
                        animation.animator.updateFrame(layer: strongSelf.infoBackgroundNode.layer, frame: infoBackgroundFrame, completion: nil)
                        
                        let muteIconFrame = CGRect(origin: CGPoint(x: infoBackgroundFrame.width - muteImage.size.width, y: 0.0), size: muteImage.size)
                        strongSelf.muteIconNode.frame = muteIconFrame
                    }
                    
                    if let updatedFile = updatedFile, updatedMedia {
                        if let resource = updatedFile.previewRepresentations.first?.resource {
                            strongSelf.fetchedThumbnailDisposable.set(fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, reference: FileMediaReference.message(message: MessageReference(item.message), media: updatedFile).resourceReference(resource)).start())
                        } else {
                            strongSelf.fetchedThumbnailDisposable.set(nil)
                        }
                    }
                                                          
                    var durationBlurColor: (UIColor, Bool)?
                    let durationTextColor: UIColor
                    switch statusDisplayType {
                        case .free:
                             let serviceColor = serviceMessageColorComponents(theme: theme.theme, wallpaper: theme.wallpaper)
                            durationTextColor = serviceColor.primaryText
                            durationBlurColor = (selectDateFillStaticColor(theme: theme.theme, wallpaper: theme.wallpaper), dateFillNeedsBlur(theme: theme.theme, wallpaper: theme.wallpaper))
                        case .bubble:
                            durationBlurColor = nil
                            if item.message.effectivelyIncoming(item.context.account.peerId) {
                                durationTextColor = theme.theme.chat.message.incoming.secondaryTextColor
                            } else {
                                durationTextColor = theme.theme.chat.message.outgoing.secondaryTextColor
                            }
                    }
                    
                    var previousVideoNode: UniversalVideoNode?
                    var updatedPlayerStatusSignal: Signal<MediaPlayerStatus?, NoError>?
                    if let telegramFile = updatedFile {
                        if updatedMedia {
                            previousVideoNode = strongSelf.videoNode
                            if let durationBlurColor = durationBlurColor {
                                if let durationBackgroundNode = strongSelf.durationBackgroundNode {
                                    durationBackgroundNode.updateColor(color: durationBlurColor.0, enableBlur: durationBlurColor.1, transition: .immediate)
                                } else {
                                    let durationBackgroundNode = NavigationBackgroundNode(color: durationBlurColor.0, enableBlur: durationBlurColor.1)
                                    strongSelf.durationBackgroundNode = durationBackgroundNode
                                    strongSelf.addSubnode(durationBackgroundNode)
                                }
                            } else if let durationBackgroundNode = strongSelf.durationBackgroundNode {
                                strongSelf.durationBackgroundNode = nil
                                durationBackgroundNode.removeFromSupernode()
                            }

                            let durationNode: ChatInstantVideoMessageDurationNode
                            if let current = strongSelf.durationNode {
                                durationNode = current
                                current.updateTheme(textColor: durationTextColor)
                            } else {
                                durationNode = ChatInstantVideoMessageDurationNode(textColor: durationTextColor)
                                strongSelf.durationNode = durationNode
                                strongSelf.addSubnode(durationNode)
                                durationNode.sizeUpdated = { [weak strongSelf] size in
                                    guard let strongSelf = strongSelf else {
                                        return
                                    }
                                    if let durationBackgroundNode = strongSelf.durationBackgroundNode, let durationNode = strongSelf.durationNode {
                                        durationBackgroundNode.frame = CGRect(origin: CGPoint(x: durationNode.frame.maxX - size.width, y: durationNode.frame.minY), size: size)
                                        durationBackgroundNode.update(size: size, cornerRadius: size.height / 2.0, transition: .immediate)
                                    }
                                }
                            }
                            durationNode.defaultDuration = telegramFile.duration.flatMap(Double.init)
                            
                            let streamVideo = automaticDownload && isMediaStreamable(message: item.message, media: telegramFile) && telegramFile.id?.namespace != Namespaces.Media.LocalFile
                            if let videoNode = strongSelf.videoNode {
                                videoNode.layer.allowsGroupOpacity = true
                                videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.5, delay: 0.2, removeOnCompletion: false, completion: { [weak videoNode] _ in
                                    videoNode?.removeFromSupernode()
                                })
                            }
                            let mediaManager = item.context.sharedContext.mediaManager
                            let videoNode = UniversalVideoNode(postbox: item.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: ChatBubbleInstantVideoDecoration(inset: 2.0, backgroundImage: instantVideoBackgroundImage, tapped: {
                                if let strongSelf = self {
                                    if let item = strongSelf.item {
                                        if strongSelf.infoBackgroundNode.alpha.isZero {
                                            item.context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: .voice)
                                        }
                                    }
                                }
                            }), content: NativeVideoContent(id: .message(item.message.stableId, telegramFile.fileId), fileReference: .message(message: MessageReference(item.message), media: telegramFile), streamVideo: streamVideo ? .conservative : .none, enableSound: false, fetchAutomatically: false, captureProtected: item.message.isCopyProtected()), priority: .embedded, autoplay: true)
                            if let previousVideoNode = previousVideoNode {
                                videoNode.bounds = previousVideoNode.bounds
                                videoNode.position = previousVideoNode.position
                                videoNode.transform = previousVideoNode.transform
                            }
                            strongSelf.videoNode = videoNode
                            strongSelf.insertSubnode(videoNode, belowSubnode: previousVideoNode ?? strongSelf.dateAndStatusNode)
                            videoNode.canAttachContent = strongSelf.shouldAcquireVideoContext
                        
                            if isSecretMedia {
                                let updatedSecretPlaceholderSignal = chatSecretMessageVideo(account: item.context.account, videoReference: .message(message: MessageReference(item.message), media: telegramFile))
                                strongSelf.secretVideoPlaceholder.setSignal(updatedSecretPlaceholderSignal)
                                if strongSelf.secretVideoPlaceholder.supernode == nil {
                                    strongSelf.insertSubnode(strongSelf.secretVideoPlaceholderBackground, belowSubnode: videoNode)
                                    strongSelf.insertSubnode(strongSelf.secretVideoPlaceholder, belowSubnode: videoNode)
                                }
                            }
                            
                            updatedPlayerStatusSignal = videoNode.status
                            |> mapToSignal { status -> Signal<MediaPlayerStatus?, NoError> in
                                if let status = status, case .buffering = status.status {
                                    return .single(status) |> delay(0.75, queue: Queue.mainQueue())
                                } else {
                                    return .single(status)
                                }
                            }
                        }
                    }
                    
                    if let updatedPlaybackStatus = updatedPlaybackStatus {
                        strongSelf.playbackStatusDisposable.set((updatedPlaybackStatus
                        |> deliverOnMainQueue).start(next: { status in
                            if let strongSelf = self {
                                strongSelf.status = status
                                strongSelf.updateStatus(animator: nil)
                            }
                        }))
                    }
                    
                    if let updatedPlayerStatusSignal = updatedPlayerStatusSignal {
                        strongSelf.playerStatusDisposable.set((updatedPlayerStatusSignal
                        |> deliverOnMainQueue).start(next: { [weak self] status in
                            displayLinkDispatcher.dispatch {
                                if let strongSelf = self {
                                    strongSelf.playerStatus = status
                                }
                            }
                        }))
                    }
                    
                    let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                                 
                    var displayTranscribe: Bool
                    if item.message.id.peerId.namespace != Namespaces.Peer.SecretChat && statusDisplayType == .free {
                        if item.associatedData.isPremium {
                            displayTranscribe = true
                        } else if item.associatedData.alwaysDisplayTranscribeButton {
                            displayTranscribe = true
                        } else {
                            displayTranscribe = false
                        }
                    } else {
                        displayTranscribe = false
                    }
                    
                    if displayTranscribe, let durationBlurColor = durationBlurColor {
                        var added = false
                        let audioTranscriptionButton: ComponentHostView<Empty>
                        if let current = strongSelf.audioTranscriptionButton {
                            audioTranscriptionButton = current
                        } else {
                            audioTranscriptionButton = ComponentHostView<Empty>()
                            strongSelf.audioTranscriptionButton = audioTranscriptionButton
                            strongSelf.view.addSubview(audioTranscriptionButton)
                            added = true
                        }
                        let audioTranscriptionButtonSize = audioTranscriptionButton.update(
                            transition: animation.isAnimated ? .easeInOut(duration: 0.3) : .immediate,
                            component: AnyComponent(AudioTranscriptionButtonComponent(
                                theme: .freeform(durationBlurColor),
                                transcriptionState: effectiveAudioTranscriptionState,
                                pressed: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.transcribe()
                                }
                            )),
                            environment: {},
                            containerSize: CGSize(width: 30.0, height: 30.0)
                        )
                        
                        var audioTranscriptionButtonFrame: CGRect
                        if incoming {
                            audioTranscriptionButtonFrame = CGRect(origin: CGPoint(x: displayVideoFrame.maxX - 30.0, y: displayVideoFrame.maxY - 30.0), size: audioTranscriptionButtonSize)
                            if !scaleProgress.isZero {
                                audioTranscriptionButtonFrame.origin.x = displayVideoFrame.midX + 43.0
                            }
                        } else {
                            audioTranscriptionButtonFrame = CGRect(origin: CGPoint(x: displayVideoFrame.minX, y: displayVideoFrame.maxY - 30.0), size: audioTranscriptionButtonSize)
                            if !scaleProgress.isZero {
                                audioTranscriptionButtonFrame.origin.x = displayVideoFrame.midX - 74.0
                            }
                        }
                        
                        if animation.isAnimated && added {
                            audioTranscriptionButton.layer.frame = audioTranscriptionButtonFrame
                            audioTranscriptionButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        } else {
                            animation.animator.updateFrame(layer: audioTranscriptionButton.layer, frame: audioTranscriptionButtonFrame, completion: nil)
                        }
                        animation.animator.updateAlpha(layer: audioTranscriptionButton.layer, alpha: scaleProgress.isZero ? 1.0 : 0.0, completion: nil)
                        if !scaleProgress.isZero {
                            displayTranscribe = false
                        }
                    } else {
                        if let audioTranscriptionButton = strongSelf.audioTranscriptionButton {
                            strongSelf.audioTranscriptionButton = nil
                            audioTranscriptionButton.removeFromSuperview()
                        }
                    }
                    
                    if let durationNode = strongSelf.durationNode {
                        var durationFrame = CGRect(origin: CGPoint(x: displayVideoFrame.midX - 56.0 - 25.0 * scaleProgress, y: displayVideoFrame.maxY - 18.0), size: CGSize(width: 1.0, height: 1.0))
                        
                        durationNode.isSeen = !notConsumed
                        let size = durationNode.size
                        if let durationBackgroundNode = strongSelf.durationBackgroundNode, size.width > 1.0 {
                            durationBackgroundNode.update(size: size, cornerRadius: size.height / 2.0, transition: .immediate)

                            if !incoming, let audioTranscriptionButton = strongSelf.audioTranscriptionButton, displayTranscribe {
                                durationFrame.origin.x = audioTranscriptionButton.frame.minX - 7.0
                            }
                            animation.animator.updateFrame(layer: durationNode.layer, frame: durationFrame, completion: nil)
                            animation.animator.updateFrame(layer: durationBackgroundNode.layer, frame: CGRect(origin: CGPoint(x: durationNode.frame.maxX - size.width, y: durationNode.frame.minY), size: size), completion: nil)
                        } else {
                            animation.animator.updateFrame(layer: durationNode.layer, frame: durationFrame, completion: nil)
                        }
                    }
                    
                    dateAndStatusApply(animation)
                    switch layoutData {
                    case let .unconstrained(width):
                        var dateAndStatusOrigin: CGPoint
                        if dateAndStatusOverflow {
                            dateAndStatusOrigin = CGPoint(x: displayVideoFrame.minX - 4.0, y: displayVideoFrame.maxY + 2.0)
                        } else {
                            dateAndStatusOrigin = CGPoint(x: min(floorToScreenPixels(displayVideoFrame.midX) + 55.0 + 25.0 * scaleProgress, width - dateAndStatusSize.width - 4.0), y: displayVideoFrame.height - dateAndStatusSize.height)
                            if !incoming, let audioTranscriptionButton = strongSelf.audioTranscriptionButton, displayTranscribe {
                                dateAndStatusOrigin.x = audioTranscriptionButton.frame.maxX + 7.0
                            }
                        }
                        animation.animator.updateFrame(layer: strongSelf.dateAndStatusNode.layer, frame: CGRect(origin: dateAndStatusOrigin, size: dateAndStatusSize), completion: nil)
                    case let .constrained(_, right):
                        var dateAndStatusFrame = CGRect(origin: CGPoint(x: min(floorToScreenPixels(displayVideoFrame.midX) + 55.0 + 25.0 * scaleProgress, displayVideoFrame.maxX + right - dateAndStatusSize.width - 4.0), y: displayVideoFrame.maxY - dateAndStatusSize.height), size: dateAndStatusSize)
                        if incoming, let audioTranscriptionButton = strongSelf.audioTranscriptionButton, displayTranscribe {
                            dateAndStatusFrame.origin.x = audioTranscriptionButton.frame.maxX + 7.0
                        }
                        animation.animator.updateFrame(layer: strongSelf.dateAndStatusNode.layer, frame: dateAndStatusFrame, completion: nil)
                    }
                    
                    if let videoNode = strongSelf.videoNode {
                        videoNode.bounds = CGRect(origin: CGPoint(), size: videoFrame.size)
                        if strongSelf.imageScale != imageScale {
                            strongSelf.imageScale = imageScale
                            animation.animator.updateScale(layer: videoNode.layer, scale: imageScale, completion: nil)
                        }
                        animation.animator.updatePosition(layer: videoNode.layer, position: displayVideoFrame.center, completion: nil)
                        videoNode.updateLayout(size: arguments.boundingSize, transition: animation.transition)
                        
                        if let previousVideoNode = previousVideoNode {
                            animation.animator.updateScale(layer: previousVideoNode.layer, scale: imageScale, completion: nil)
                            animation.animator.updatePosition(layer: previousVideoNode.layer, position: displayVideoFrame.center, completion: nil)
                        }
                    }
                    animation.animator.updateFrame(layer: strongSelf.secretVideoPlaceholderBackground.layer, frame: displayVideoFrame, completion: nil)
                    
                    let placeholderFrame = videoFrame.insetBy(dx: 2.0, dy: 2.0)
                    strongSelf.secretVideoPlaceholder.bounds = CGRect(origin: CGPoint(), size: videoFrame.size)
                    animation.animator.updateScale(layer: strongSelf.secretVideoPlaceholder.layer, scale: imageScale, completion: nil)
                    animation.animator.updatePosition(layer: strongSelf.secretVideoPlaceholder.layer, position: displayVideoFrame.center, completion: nil)
                    
                    let makeSecretPlaceholderLayout = strongSelf.secretVideoPlaceholder.asyncLayout()
                    let arguments = TransformImageArguments(corners: ImageCorners(radius: placeholderFrame.size.width / 2.0), imageSize: placeholderFrame.size, boundingSize: placeholderFrame.size, intrinsicInsets: UIEdgeInsets())
                    let applySecretPlaceholder = makeSecretPlaceholderLayout(arguments)
                    applySecretPlaceholder()
                    
                    strongSelf.updateStatus(animator: animation.animator)
                    
                    if let telegramFile = updatedFile, previousAutomaticDownload != automaticDownload, automaticDownload {
                        strongSelf.fetchDisposable.set(messageMediaFileInteractiveFetched(context: item.context, message: item.message, file: telegramFile, userInitiated: false).start())
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
                }
            })
        }
    }
    
    private func updateStatus(animator: ControlledTransitionAnimator? = nil) {
        guard let item = self.item, let status = self.status, let videoFrame = self.videoFrame else {
            return
        }
        let messageTheme = item.presentationData.theme.theme.chat.message
        
        let isSecretMedia = item.message.containsSecretMedia
        var secretBeginTimeAndTimeout: (Double, Double)?
        if isSecretMedia {
            if let attribute = item.message.autoclearAttribute {
                if let countdownBeginTime = attribute.countdownBeginTime {
                    secretBeginTimeAndTimeout = (Double(countdownBeginTime), Double(attribute.timeout))
                }
            } else if let attribute = item.message.autoremoveAttribute {
                if let countdownBeginTime = attribute.countdownBeginTime {
                    secretBeginTimeAndTimeout = (Double(countdownBeginTime), Double(attribute.timeout))
                }
            }
        }
        
        var selectedMedia: TelegramMediaFile?
        for media in item.message.media {
            if let file = media as? TelegramMediaFile {
                selectedMedia = file
            } else if let webPage = media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content, let file = content.file {
                selectedMedia = file
            }
        }
        
        guard let file = selectedMedia else {
            return
        }
        
        let displayMute: Bool
        switch status.mediaStatus {
            case let .fetchStatus(fetchStatus):
                switch fetchStatus {
                    case .Local:
                        displayMute = true
                    default:
                        displayMute = self.automaticDownload ?? false
                }
            case .playbackStatus:
                displayMute = false
        }
        if displayMute != (!self.infoBackgroundNode.alpha.isZero) {
            if displayMute {
                self.infoBackgroundNode.alpha = 1.0
                self.infoBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                self.infoBackgroundNode.layer.animateScale(from: 0.4, to: 1.0, duration: 0.15)
            } else {
                self.infoBackgroundNode.alpha = 0.0
                self.infoBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                self.infoBackgroundNode.layer.animateScale(from: 1.0, to: 0.4, duration: 0.15)
            }
        }
        
        var isBuffering: Bool?
        if let message = self.item?.message, let media = self.media, isMediaStreamable(message: message, media: media) && (self.automaticDownload ?? false) {
            if let playerStatus = self.playerStatus, case .buffering = playerStatus.status {
                isBuffering = true
            } else {
                isBuffering = false
            }
        }
        
        var progressRequired = false
        if case let .fetchStatus(fetchStatus) = status.mediaStatus {
            if case .Local = fetchStatus {
                if file.isVideo {
                    progressRequired = true
                } else if isSecretMedia {
                    progressRequired = true
                }
            } else {
                progressRequired = true
            }
        } else if isBuffering ?? false {
            progressRequired = true
        }
        
        if progressRequired {
            if self.statusNode == nil {
                let statusNode = RadialStatusNode(backgroundNodeColor: item.presentationData.theme.theme.chat.message.mediaOverlayControlColors.fillColor)
                self.isUserInteractionEnabled = false
                self.statusNode = statusNode
                self.addSubnode(statusNode)
            }
        } else {
            if let statusNode = self.statusNode {
                self.disappearingStatusNode = statusNode
                statusNode.transitionToState(.none, completion: { [weak statusNode, weak self] in
                    statusNode?.removeFromSupernode()
                    if self?.disappearingStatusNode === statusNode {
                        self?.disappearingStatusNode = nil
                    }
                })
                self.statusNode = nil
            }
        }
        
        let statusFrame = CGRect(origin: CGPoint(x: videoFrame.origin.x + floorToScreenPixels((videoFrame.size.width - 50.0) / 2.0), y: videoFrame.origin.y + floorToScreenPixels((videoFrame.size.height - 50.0) / 2.0)), size: CGSize(width: 50.0, height: 50.0))
        if let animator = animator {
            if let statusNode = self.statusNode {
                animator.updateFrame(layer: statusNode.layer, frame: statusFrame, completion: nil)
            }
            if let disappearingStatusNode = self.disappearingStatusNode {
                animator.updateFrame(layer: disappearingStatusNode.layer, frame: statusFrame, completion: nil)
            }
        } else {
            self.statusNode?.frame = statusFrame
            self.disappearingStatusNode?.frame = statusFrame
        }
        
        var state: RadialStatusNodeState
        switch status.mediaStatus {
            case var .fetchStatus(fetchStatus):
                if item.message.forwardInfo != nil {
                    fetchStatus = status.fetchStatus
                }
                
                switch fetchStatus {
                    case let .Fetching(_, progress):
                        if let isBuffering = isBuffering {
                            if isBuffering {
                                state = .progress(color: messageTheme.mediaOverlayControlColors.foregroundColor, lineWidth: nil, value: nil, cancelEnabled: true, animateRotation: true)
                            } else {
                                state = .none
                            }
                        } else {
                            let adjustedProgress = max(progress, 0.027)
                            state = .progress(color: messageTheme.mediaOverlayControlColors.foregroundColor, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true, animateRotation: true)
                        }
                    case .Local:
                        if isSecretMedia && self.secretProgressIcon != nil {
                            if let (beginTime, timeout) = secretBeginTimeAndTimeout {
                                state = .secretTimeout(color: messageTheme.mediaOverlayControlColors.foregroundColor, icon: secretProgressIcon, beginTime: beginTime, timeout: timeout, sparks: true)
                            } else {
                                state = .customIcon(secretProgressIcon!)
                            }
                        } else {
                            state = .none
                        }
                    case .Remote, .Paused:
                        state = .download(messageTheme.mediaOverlayControlColors.foregroundColor)
                }
            default:
                var isLocal = false
                if case .Local = status.fetchStatus {
                    isLocal = true
                }
                if (isBuffering ?? false) && !isLocal {
                    state = .progress(color: messageTheme.mediaOverlayControlColors.foregroundColor, lineWidth: nil, value: nil, cancelEnabled: true, animateRotation: true)
                } else {
                    state = .none
                }
        }
        if let statusNode = self.statusNode {
            if state == .none {
                self.statusNode = nil
            }
            statusNode.transitionToState(state, completion: { [weak statusNode] in
                if state == .none {
                    statusNode?.removeFromSupernode()
                }
            })
        }
        
        if case .playbackStatus = status.mediaStatus {
            let playbackStatusNode: InstantVideoRadialStatusNode
            if let current = self.playbackStatusNode {
                playbackStatusNode = current
            } else {
                playbackStatusNode = InstantVideoRadialStatusNode(color: UIColor(white: 1.0, alpha: 0.6), hasSeek: true)
                playbackStatusNode.seekTo = { [weak self] position, play in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.seekTo(position)
                    if play {
                        strongSelf.play()
                    }
                }
                self.addSubnode(playbackStatusNode)
                
                if let audioTranscriptionButton = self.audioTranscriptionButton {
                    audioTranscriptionButton.superview?.bringSubviewToFront(audioTranscriptionButton)
                }
                
                self.playbackStatusNode = playbackStatusNode
            }
            playbackStatusNode.frame = videoFrame.insetBy(dx: 1.5, dy: 1.5)
            
            let status = messageFileMediaPlaybackStatus(context: item.context, file: file, message: item.message, isRecentActions: item.associatedData.isRecentActions, isGlobalSearch: false, isDownloadList: false)
            playbackStatusNode.status = status
            self.durationNode?.status = status
            |> map(Optional.init)
            
            self.videoNode?.isHidden = false
            self.secretVideoPlaceholderBackground.isHidden = true
            self.secretVideoPlaceholder.isHidden = true
        } else {
            if let playbackStatusNode = self.playbackStatusNode {
                self.playbackStatusNode = nil
                playbackStatusNode.removeFromSupernode()
            }
            
            self.durationNode?.status = .single(nil)
            self.videoNode?.isHidden = isSecretMedia
            self.secretVideoPlaceholderBackground.isHidden = !isSecretMedia
            self.secretVideoPlaceholder.isHidden = !isSecretMedia
        }
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if let audioTranscriptionButton = self.audioTranscriptionButton, !audioTranscriptionButton.isHidden, audioTranscriptionButton.frame.contains(location) {
                                self.transcribe()
                                return
                            }
                        
                            if let statusNode = self.statusNode, statusNode.supernode != nil, !statusNode.isHidden, statusNode.frame.contains(location) {
                                self.progressPressed()
                                return
                            }
                            
                            if let _ = self.item, let videoNode = self.videoNode, videoNode.frame.contains(location) {
                                self.activateVideoPlayback()
                                return
                            }
                            
                            self.item?.controllerInteraction.clickThroughMessage()
                        case .longTap, .doubleTap, .secondaryTap:
                            break
                        case .hold:
                            break
                    }
                }
            default:
                break
        }
    }
    
    private func activateVideoPlayback() {
        guard let item = self.item, self.shouldOpen() else {
            return
        }
        if self.infoBackgroundNode.alpha.isZero {
            if let status = self.status, case let .fetchStatus(fetchStatus) = status.mediaStatus, case .Remote = fetchStatus {
                item.context.sharedContext.mediaManager.playlistControl(.playback(.pause), type: .voice)
                self.videoNode?.fetchControl(.fetch)
            } else {
                item.context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: .voice)
            }
        } else {
            let _ = item.controllerInteraction.openMessage(item.message, .default)
        }
        
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        if let audioTranscriptionButton = self.audioTranscriptionButton, !audioTranscriptionButton.isHidden, audioTranscriptionButton.frame.contains(point) {
            return audioTranscriptionButton
        }
        if let playbackNode = self.playbackStatusNode, !self.isPlaying, !playbackNode.frame.insetBy(dx: 0.2 * playbackNode.frame.width, dy: 0.2 * playbackNode.frame.height).contains(point) {
            let distanceFromCenter = point.distanceTo(playbackNode.position)
            if distanceFromCenter < 0.2 * playbackNode.frame.width {
                return self.view
            } else {
                return playbackNode.view
            }
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
        guard let item = self.item, let file = self.media else {
            return
        }
        if let status = self.status {
            switch status.mediaStatus {
                case let .fetchStatus(fetchStatus):
                    switch fetchStatus {
                        case .Fetching:
                            if item.message.flags.isSending {
                                let _ = item.context.engine.messages.deleteMessagesInteractively(messageIds: [item.message.id], type: .forEveryone).start()
                            } else {
                                messageMediaFileCancelInteractiveFetch(context: item.context, messageId: item.message.id, file: file)
                            }
                        case .Remote, .Paused:
                            if let file = self.media {
                                self.fetchDisposable.set(messageMediaFileInteractiveFetched(context: item.context, message: item.message, file: file, userInitiated: true).start())
                            }
                        case .Local:
                            self.activateVideoPlayback()
                    }
                default:
                    break
            }
        }
    }
    
    override func accessibilityActivate() -> Bool {
        self.progressPressed()
        return true
    }
    
    func videoContentNode(at point: CGPoint) -> ASDisplayNode? {
        if let videoFrame = self.videoFrame {
            if videoFrame.contains(point) {
                return self.videoNode
            }
        }
        return nil
    }

    static func asyncLayout(_ node: ChatMessageInteractiveInstantVideoNode?) -> (_ item: ChatMessageBubbleContentItem, _ width: CGFloat, _ displaySize: CGSize, _ maximumDisplaySize: CGSize, _ scaleProgress: CGFloat, _ statusType: ChatMessageInteractiveInstantVideoNodeStatusType, _ automaticDownload: Bool) -> (ChatMessageInstantVideoItemLayoutResult, (ChatMessageInstantVideoItemLayoutData, ListViewItemUpdateAnimation) -> ChatMessageInteractiveInstantVideoNode) {
        let makeLayout = node?.asyncLayout()
        return { item, width, displaySize, maximumDisplaySize, scaleProgress, statusType, automaticDownload in
            var createdNode: ChatMessageInteractiveInstantVideoNode?
            let sizeAndApplyLayout: (ChatMessageInstantVideoItemLayoutResult, (ChatMessageInstantVideoItemLayoutData, ListViewItemUpdateAnimation) -> Void)
            if let makeLayout = makeLayout {
                sizeAndApplyLayout = makeLayout(item, width, displaySize, maximumDisplaySize, scaleProgress, statusType, automaticDownload)
            } else {
                let node = ChatMessageInteractiveInstantVideoNode()
                sizeAndApplyLayout = node.asyncLayout()(item, width, displaySize, maximumDisplaySize, scaleProgress, statusType, automaticDownload)
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
    
    var isPlaying: Bool {
        if let status = self.status, case let .playbackStatus(playbackStatus) = status.mediaStatus, case .playing = playbackStatus {
            return true
        } else {
            return false
        }
    }

    func seekTo(_ position: Double) {
        if let duration = self.playbackStatusNode?.duration {
            self.videoNode?.seek(position * duration)
        }
    }
    
    func play() {
        self.videoNode?.play()
    }
    
    func pause() {
        self.videoNode?.pause()
    }
    
    func playMediaWithSound() -> (action: (Double?) -> Void, soundEnabled: Bool, isVideoMessage: Bool, isUnread: Bool, badgeNode: ASDisplayNode?)? {
        if let item = self.item {
            var isUnconsumed = false
            for attribute in item.message.attributes {
                if let attribute = attribute as? ConsumableContentMessageAttribute {
                    if !attribute.consumed {
                        isUnconsumed = true
                    }
                    break
                }
            }
            
            return ({ _ in
                if !self.infoBackgroundNode.alpha.isZero {
                    let _ = (item.context.sharedContext.mediaManager.globalMediaPlayerState
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { playlistStateAndType in
                        var canPlay = true
                        if let (_, state, _) = playlistStateAndType {
                            switch state {
                                case let .state(state):
                                    if case .playing = state.status.status {
                                        canPlay = false
                                    }
                                case .loading:
                                    break
                            }
                        }
                        if canPlay {
                            let _ = item.controllerInteraction.openMessage(item.message, .default)
                        }
                    })
                }
            }, false, true, isUnconsumed, nil)
        } else {
            return nil
        }
    }

    private var animatedFadeIn = false
    func animateFromSnapshot(snapshotView: UIView, transition: CombinedTransition) {
        guard let videoFrame = self.videoFrame else {
            return
        }

        let scale = videoFrame.height / snapshotView.frame.height
        snapshotView.transform = CGAffineTransform(scaleX: scale, y: scale)
        snapshotView.center = CGPoint(x: videoFrame.midX, y: videoFrame.midY)

        self.view.addSubview(snapshotView)

        transition.horizontal.updateAlpha(layer: snapshotView.layer, alpha: 0.0, completion: { [weak snapshotView] _ in
            snapshotView?.removeFromSuperview()
        })

        transition.horizontal.animateTransformScale(node: self, from: 1.0 / scale)

        if !self.animatedFadeIn {
            self.animatedFadeIn = true
            self.dateAndStatusNode.layer.animateAlpha(from: 0.0, to: self.dateAndStatusNode.alpha, duration: 0.15, delay: 0.18)
            if let durationNode = self.durationNode {
                durationNode.layer.animateAlpha(from: 0.0, to: durationNode.alpha, duration: 0.15, delay: 0.18)
            }
        }
    }
    
    private func transcribe() {
        guard let item = self.item, self.statusNode == nil else {
            return
        }
                
        guard item.associatedData.isPremium else {
            let presentationData = item.context.sharedContext.currentPresentationData.with { $0 }
            let tipController = UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_voiceToText", scale: 0.065, colors: [:], title: nil, text: presentationData.strings.Message_AudioTranscription_SubscribeToPremium, customUndoText: presentationData.strings.Message_AudioTranscription_SubscribeToPremiumAction), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { action in
                if case .undo = action {
                    let introController = item.context.sharedContext.makePremiumIntroController(context: item.context, source: .settings)
                    item.controllerInteraction.navigationController()?.pushViewController(introController, animated: true)
                    
                    let _ = ApplicationSpecificNotice.incrementAudioTranscriptionSuggestion(accountManager: item.context.sharedContext.accountManager).start()
                }
                return false })
            item.controllerInteraction.presentControllerInCurrent(tipController, nil)
            return
        }
        
        var shouldBeginTranscription = false
        var shouldExpandNow = false
        
        if case .expanded = self.audioTranscriptionState {
            shouldExpandNow = true
        } else {
            if let result = transcribedText(message: item.message) {
                shouldExpandNow = true
                
                if case let .success(_, isPending) = result {
                    shouldBeginTranscription = isPending
                } else {
                    shouldBeginTranscription = true
                }
            } else {
                shouldBeginTranscription = true
            }
        }
        
        if shouldBeginTranscription {
            if self.transcribeDisposable == nil {
                self.audioTranscriptionState = .inProgress
                self.requestUpdateLayout(true)
                
                self.transcribeDisposable = (item.context.engine.messages.transcribeAudio(messageId: item.message.id)
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.transcribeDisposable = nil
                })
            }
        }
        
        if shouldExpandNow {
            switch self.audioTranscriptionState {
            case .expanded:
                self.audioTranscriptionState = .collapsed
                self.isWaitingForCollapse = true
                self.requestUpdateLayout(true)
            case .collapsed:
                self.audioTranscriptionState = .inProgress
                self.requestUpdateLayout(true)
            default:
                break
            }
        }
        
        self.updateTranscriptionExpanded?(self.audioTranscriptionState)
    }
    
    func animateTo(_ node: ChatMessageInteractiveFileNode, animator: ControlledTransitionAnimator) {
        let duration: Double = 0.2
        
        node.alpha = 1.0
        node.isHidden = false
        
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
        
        node.waveformView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.1)
        
        if let videoNode = self.videoNode, let targetNode = node.statusNode, let videoSnapshotView = videoNode.view.snapshotView(afterScreenUpdates: false) {
            videoSnapshotView.frame = videoNode.bounds
            videoNode.view.insertSubview(videoSnapshotView, at: 1)
            videoSnapshotView.alpha = 0.0
            videoSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, completion: { [weak videoSnapshotView] _ in
                videoSnapshotView?.removeFromSuperview()
            })
            
            let targetFrame = targetNode.view.convert(targetNode.bounds, to: self.view)
            animator.animatePosition(layer: videoNode.layer, from: videoNode.position, to: targetFrame.center, completion: { _ in
                self.isHidden = true
                self.customIsHidden = true
            })
            let targetScale = targetNode.frame.width / videoNode.bounds.width
            animator.animateScale(layer: videoNode.layer, from: self.imageScale, to: targetScale, completion: nil)
            
            animator.animatePosition(layer: self.infoBackgroundNode.layer, from: self.infoBackgroundNode.position, to: targetFrame.center.offsetBy(dx: 0.0, dy: 19.0), completion: nil)
            animator.animateScale(layer: self.infoBackgroundNode.layer, from: 1.0, to: targetScale / self.imageScale, completion: nil)
            self.infoBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
            
            if let playbackStatusNode = self.playbackStatusNode {
                animator.animatePosition(layer: playbackStatusNode.layer, from: playbackStatusNode.position, to: targetFrame.center, completion: nil)
                animator.animateScale(layer: playbackStatusNode.layer, from: 1.0, to: targetScale / self.imageScale, completion: nil)
                playbackStatusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
            }
            
            let sourceFrame = self.view.convert(videoNode.frame, to: node.view)
            animator.animatePosition(layer: targetNode.layer, from: sourceFrame.center, to: targetNode.position, completion: nil)
            let sourceScale = (videoNode.bounds.width * self.imageScale) / targetNode.frame.width
            animator.animateScale(layer: targetNode.layer, from: sourceScale, to: 1.0, completion: nil)
            targetNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
            
            let verticalDelta = (videoNode.position.y - targetFrame.center.y) * 2.0
            animator.animatePosition(layer: node.textNode.layer, from: node.textNode.position.offsetBy(dx: 0.0, dy: verticalDelta), to: node.textNode.position, completion: nil)
            node.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        }
        
        if let audioTranscriptionButton = self.audioTranscriptionButton, let targetAudioTranscriptionButton = node.audioTranscriptionButton {
            let sourceFrame = audioTranscriptionButton.convert(audioTranscriptionButton.bounds, to: node.view)
            
            animator.animatePosition(layer: targetAudioTranscriptionButton.layer, from: sourceFrame.center, to: targetAudioTranscriptionButton.center, completion: nil)
            targetAudioTranscriptionButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
            
            let targetFrame = targetAudioTranscriptionButton.convert(targetAudioTranscriptionButton.bounds, to: self.view)
            animator.animatePosition(layer: audioTranscriptionButton.layer, from: audioTranscriptionButton.center, to: targetFrame.center, completion: nil)
            audioTranscriptionButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
        }
        
        let sourceDateFrame = self.dateAndStatusNode.view.convert(self.dateAndStatusNode.view.bounds, to: node.view)
        let targetDateFrame = node.dateAndStatusNode.view.convert(node.dateAndStatusNode.view.bounds, to: self.view)
                        
        animator.animatePosition(layer: self.dateAndStatusNode.layer, from: self.dateAndStatusNode.position, to: CGPoint(x: targetDateFrame.maxX - self.dateAndStatusNode.frame.width / 2.0 + 2.0, y: targetDateFrame.midY - 7.0), completion: nil)
        animator.animatePosition(layer: node.dateAndStatusNode.layer, from: CGPoint(x: sourceDateFrame.maxX - node.dateAndStatusNode.frame.width / 2.0, y: sourceDateFrame.midY + 7.0), to: node.dateAndStatusNode.position, completion: nil)
        
        self.dateAndStatusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
        node.dateAndStatusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration - 0.05, delay: 0.05)
        
        if let durationNode = self.durationNode, let durationBackgroundNode = self.durationBackgroundNode {
            let sourceDurationFrame = durationNode.view.convert(durationNode.view.bounds, to: node.view)
            let targetDurationFrame = node.fetchingTextNode.view.convert(node.fetchingTextNode.view.bounds, to: self.view)
            
            let delta = CGPoint(x: targetDurationFrame.center.x - durationNode.position.x, y: targetDurationFrame.center.y - durationNode.position.y)
            animator.animatePosition(layer: durationNode.layer, from: durationNode.position, to: targetDurationFrame.center, completion: nil)
            animator.animatePosition(layer: durationBackgroundNode.layer, from: durationBackgroundNode.position, to: durationBackgroundNode.position.offsetBy(dx: delta.x, dy: delta.y), completion: nil)
            animator.animatePosition(layer: node.fetchingTextNode.layer, from: sourceDurationFrame.center, to: node.fetchingTextNode.position, completion: nil)
            
            durationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
            self.durationBackgroundNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
            
            node.fetchingTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration - 0.05, delay: 0.05)
        }
    }
    
    func animateFrom(_ node: ChatMessageInteractiveFileNode, animator: ControlledTransitionAnimator) {
        let duration: Double = 0.2
        
        self.alpha = 1.0
        self.isHidden = false
        
        node.alpha = 0.0
        node.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, completion: { _ in
            node.isHidden = true
        })
        node.waveformView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
                
        if let videoNode = self.videoNode, let sourceNode = node.statusNode {
            videoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        
            let sourceFrame = sourceNode.view.convert(sourceNode.bounds, to: self.view)
            animator.animatePosition(layer: videoNode.layer, from: sourceFrame.center, to: videoNode.position, completion: nil)
            let sourceScale = sourceNode.frame.width / videoNode.bounds.width
            animator.animateScale(layer: videoNode.layer, from: sourceScale, to: self.imageScale, completion: nil)
            
            animator.animatePosition(layer: self.infoBackgroundNode.layer, from: sourceFrame.center.offsetBy(dx: 0.0, dy: 19.0), to: self.infoBackgroundNode.position, completion: nil)
            animator.animateScale(layer: self.infoBackgroundNode.layer, from: sourceScale / self.imageScale, to: 1.0, completion: nil)
            self.infoBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
            
            if let playbackStatusNode = self.playbackStatusNode {
                animator.animatePosition(layer: playbackStatusNode.layer, from: sourceFrame.center, to: playbackStatusNode.position, completion: nil)
                animator.animateScale(layer: playbackStatusNode.layer, from: sourceScale / self.imageScale, to: 1.0, completion: nil)
                playbackStatusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
            }
            
            let targetFrame = self.view.convert(videoNode.frame, to: node.view)
            animator.animatePosition(layer: sourceNode.layer, from: sourceNode.position, to: targetFrame.center, completion: nil)
            let targetScale = (videoNode.bounds.width * self.imageScale) / sourceNode.frame.width
            animator.animateScale(layer: sourceNode.layer, from: 1.0, to: targetScale, completion: nil)
            sourceNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
            
            let verticalDelta = (videoNode.position.y - sourceFrame.center.y) * 2.0
            animator.animatePosition(layer: node.textNode.layer, from: node.textNode.position, to: node.textNode.position.offsetBy(dx: 0.0, dy: verticalDelta), completion: nil)
            node.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
        }
                
        if let audioTranscriptionButton = self.audioTranscriptionButton, let sourceAudioTranscriptionButton = node.audioTranscriptionButton {
            audioTranscriptionButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
            
            let targetFrame = audioTranscriptionButton.convert(audioTranscriptionButton.bounds, to: node.view)
            animator.animatePosition(layer: sourceAudioTranscriptionButton.layer, from: sourceAudioTranscriptionButton.center, to: targetFrame.center, completion: nil)
            sourceAudioTranscriptionButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
            
            let sourceFrame = sourceAudioTranscriptionButton.convert(sourceAudioTranscriptionButton.bounds, to: self.view)
            animator.animatePosition(layer: audioTranscriptionButton.layer, from: sourceFrame.center, to: audioTranscriptionButton.center, completion: nil)
        }
        
        let sourceDateFrame = node.dateAndStatusNode.view.convert(node.dateAndStatusNode.view.bounds, to: self.view)
        let targetDateFrame = self.dateAndStatusNode.view.convert(self.dateAndStatusNode.view.bounds, to: node.view)
        
        animator.animatePosition(layer: self.dateAndStatusNode.layer, from: CGPoint(x: sourceDateFrame.maxX - self.dateAndStatusNode.frame.width / 2.0 + 2.0, y: sourceDateFrame.midY - 7.0), to: self.dateAndStatusNode.position, completion: nil)
        animator.animatePosition(layer: node.dateAndStatusNode.layer, from: node.dateAndStatusNode.position, to: CGPoint(x: targetDateFrame.maxX - node.dateAndStatusNode.frame.width / 2.0, y: targetDateFrame.midY + 7.0), completion: nil)
        
        self.dateAndStatusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        node.dateAndStatusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
                
        if let durationNode = self.durationNode, let durationBackgroundNode = self.durationBackgroundNode {
            let sourceDurationFrame = node.fetchingTextNode.view.convert(node.fetchingTextNode.view.bounds, to: self.view)
            let targetDurationFrame = durationNode.view.convert(durationNode.view.bounds, to: node.view)
            
            let delta = CGPoint(x: sourceDurationFrame.center.x - durationNode.position.x, y: sourceDurationFrame.center.y - durationNode.position.y)
            animator.animatePosition(layer: durationNode.layer, from: sourceDurationFrame.center, to: durationNode.position, completion: nil)
            animator.animatePosition(layer: durationBackgroundNode.layer, from: durationBackgroundNode.position.offsetBy(dx: delta.x, dy: delta.y), to: durationBackgroundNode.position, completion: nil)
            animator.animatePosition(layer: node.fetchingTextNode.layer, from: node.fetchingTextNode.position, to: targetDurationFrame.center, completion: nil)
            
            durationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
            self.durationBackgroundNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration - 0.05, delay: 0.05)
            
            node.fetchingTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
        }
        
        self.customIsHidden = false
    }
}
