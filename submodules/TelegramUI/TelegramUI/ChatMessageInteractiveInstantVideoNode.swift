import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import UniversalMediaPlayer
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import PhotoResources
import TelegramUniversalVideoContent

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
    private let secretVideoPlaceholderBackground: ASImageNode
    private let secretVideoPlaceholder: TransformImageNode
    
    private var statusNode: RadialStatusNode?
    private var playbackStatusNode: InstantVideoRadialStatusNode?
    private var videoFrame: CGRect?
    
    private var item: ChatMessageBubbleContentItem?
    private var automaticDownload: Bool?
    var media: TelegramMediaFile?
    private var secretProgressIcon: UIImage?
    
    private let fetchDisposable = MetaDisposable()
    
    private var durationNode: ChatInstantVideoMessageDurationNode?
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    
    private let infoBackgroundNode: ASImageNode
    private let muteIconNode: ASImageNode
    
    private var status: FileMediaResourceStatus?
    private var playerStatus: MediaPlayerStatus? {
        didSet {
            if self.playerStatus != oldValue {
                self.updateStatus()
            }
        }
    }
    private let playbackStatusDisposable = MetaDisposable()
    private let playerStatusDisposable = MetaDisposable()
    private let fetchedThumbnailDisposable = MetaDisposable()
    
    private var shouldAcquireVideoContext: Bool {
        if self.visibility {
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
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    func asyncLayout() -> (_ item: ChatMessageBubbleContentItem, _ width: CGFloat, _ displaySize: CGSize, _ statusType: ChatMessageInteractiveInstantVideoNodeStatusType, _ automaticDownload: Bool) -> (ChatMessageInstantVideoItemLayoutResult, (ChatMessageInstantVideoItemLayoutData, ContainedViewLayoutTransition) -> Void) {
        let previousFile = self.media
        
        let currentItem = self.item
        let previousAutomaticDownload = self.automaticDownload
        
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        
        return { item, width, displaySize, statusDisplayType, automaticDownload in
            var updatedTheme: ChatPresentationThemeData?
            
            var secretVideoPlaceholderBackgroundImage: UIImage?
            var updatedInfoBackgroundImage: UIImage?
            var updatedMuteIconImage: UIImage?
            if item.presentationData.theme != currentItem?.presentationData.theme {
                updatedTheme = item.presentationData.theme
                updatedInfoBackgroundImage = PresentationResourcesChat.chatInstantMessageInfoBackgroundImage(item.presentationData.theme.theme)
                updatedMuteIconImage = PresentationResourcesChat.chatInstantMessageMuteIconImage(item.presentationData.theme.theme)
            }
            
            let instantVideoBackgroundImage: UIImage?
            switch statusDisplayType {
                case .free:
                    instantVideoBackgroundImage = PresentationResourcesChat.chatInstantVideoBackgroundImage(item.presentationData.theme.theme, wallpaper: !item.presentationData.theme.wallpaper.isEmpty)
                case .bubble:
                    instantVideoBackgroundImage = nil
            }
            
            let theme = item.presentationData.theme
            let isSecretMedia = item.message.containsSecretMedia
            var secretProgressIcon: UIImage?
            if isSecretMedia {
                secretProgressIcon = PresentationResourcesChat.chatBubbleSecretMediaIcon(theme.theme)
                secretVideoPlaceholderBackgroundImage = PresentationResourcesChat.chatInstantVideoBackgroundImage(theme.theme, wallpaper: !theme.wallpaper.isEmpty)
            }
            
            let imageSize = displaySize
            
            let updatedMessageId = item.message.id != currentItem?.message.id
            
            var updatedFile: TelegramMediaFile?
            var updatedMedia = false
            for media in item.message.media {
                if let file = media as? TelegramMediaFile {
                    updatedFile = file
                    if let previousFile = previousFile {
                        updatedMedia = !previousFile.resource.id.isEqual(to: file.resource.id)
                    } else if previousFile == nil {
                        updatedMedia = true
                    }
                } else if let webPage = media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content, let file = content.file {
                    updatedFile = file
                    if let previousFile = previousFile {
                        updatedMedia = !previousFile.resource.id.isEqual(to: file.resource.id)
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
                        } else if item.message.flags.isSending && !item.message.isSentOrAcknowledged {
                            statusType = .BubbleOutgoing(.Sending)
                        } else {
                            statusType = .BubbleOutgoing(.Sent(read: item.read))
                        }
                }
            }
            
            var edited = false
            let sentViaBot = false
            var viewCount: Int? = nil
            for attribute in item.message.attributes {
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
            
            let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: .regular, reactionCount: dateReactionCount)
            
            let maxDateAndStatusWidth: CGFloat
            if case .bubble = statusDisplayType {
                maxDateAndStatusWidth = width
            } else {
                maxDateAndStatusWidth = width - videoFrame.midX - 85.0
            }
            let (dateAndStatusSize, dateAndStatusApply) = makeDateAndStatusLayout(item.context, item.presentationData, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: max(1.0, maxDateAndStatusWidth), height: CGFloat.greatestFiniteMagnitude), dateReactions)
            
            var contentSize = imageSize
            var dateAndStatusOverflow = false
            if case .bubble = statusDisplayType, videoFrame.maxX + dateAndStatusSize.width > width {
                contentSize.height += dateAndStatusSize.height + 2.0
                contentSize.width = max(contentSize.width, dateAndStatusSize.width)
                dateAndStatusOverflow = true
            }
            
            let result = ChatMessageInstantVideoItemLayoutResult(contentSize: contentSize, overflowLeft: 0.0, overflowRight: dateAndStatusOverflow ? 0.0 : (max(0.0, floor(videoFrame.midX) + 55.0 + dateAndStatusSize.width - videoFrame.width)))
            
            return (result, { [weak self] layoutData, transition in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.videoFrame = videoFrame
                    strongSelf.secretProgressIcon = secretProgressIcon
                    strongSelf.automaticDownload = automaticDownload
                    
                    if let updatedInfoBackgroundImage = updatedInfoBackgroundImage {
                        strongSelf.infoBackgroundNode.image = updatedInfoBackgroundImage
                    }
                    
                    if let updatedMuteIconImage = updatedMuteIconImage {
                        strongSelf.muteIconNode.image = updatedMuteIconImage
                    }
                    
                    if let secretVideoPlaceholderBackgroundImage = secretVideoPlaceholderBackgroundImage {
                        strongSelf.secretVideoPlaceholderBackground.image = secretVideoPlaceholderBackgroundImage
                    }
                    
                    strongSelf.media = updatedFile
                    
                    if let infoBackgroundImage = strongSelf.infoBackgroundNode.image, let muteImage = strongSelf.muteIconNode.image {
                        let infoWidth = muteImage.size.width
                        let infoBackgroundFrame = CGRect(origin: CGPoint(x: floor(videoFrame.minX + (videoFrame.size.width - infoWidth) / 2.0), y: videoFrame.maxY - infoBackgroundImage.size.height - 8.0), size: CGSize(width: infoWidth, height: infoBackgroundImage.size.height))
                        transition.updateFrame(node: strongSelf.infoBackgroundNode, frame: infoBackgroundFrame)
                        let muteIconFrame = CGRect(origin: CGPoint(x: infoBackgroundFrame.width - muteImage.size.width, y: 0.0), size: muteImage.size)
                        transition.updateFrame(node: strongSelf.muteIconNode, frame: muteIconFrame)
                    }
                    
                    if let updatedFile = updatedFile, updatedMedia {
                        if let resource = updatedFile.previewRepresentations.first?.resource {
                            strongSelf.fetchedThumbnailDisposable.set(fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, reference: FileMediaReference.message(message: MessageReference(item.message), media: updatedFile).resourceReference(resource)).start())
                        } else {
                            strongSelf.fetchedThumbnailDisposable.set(nil)
                        }
                    }
                    
                    dateAndStatusApply(false)
                    switch layoutData {
                        case let .unconstrained(width):
                            let dateAndStatusOrigin: CGPoint
                            if dateAndStatusOverflow {
                                dateAndStatusOrigin = CGPoint(x: videoFrame.minX - 4.0, y: videoFrame.maxY + 2.0)
                            } else {
                                dateAndStatusOrigin = CGPoint(x: min(floor(videoFrame.midX) + 55.0, width - dateAndStatusSize.width - 4.0), y: videoFrame.height - dateAndStatusSize.height)
                            }
                            strongSelf.dateAndStatusNode.frame = CGRect(origin: dateAndStatusOrigin, size: dateAndStatusSize)
                        case let .constrained(_, right):
                            strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: min(floor(videoFrame.midX) + 55.0, videoFrame.maxX + right - dateAndStatusSize.width - 4.0), y: videoFrame.maxY - dateAndStatusSize.height), size: dateAndStatusSize)
                    }
                    
                    var updatedPlayerStatusSignal: Signal<MediaPlayerStatus?, NoError>?
                    if let telegramFile = updatedFile {
                        if updatedMedia {
                            let durationTextColor: UIColor
                            let durationFillColor: UIColor
                            switch statusDisplayType {
                                case .free:
                                     let serviceColor = serviceMessageColorComponents(theme: theme.theme, wallpaper: theme.wallpaper)
                                    durationTextColor = serviceColor.primaryText
                                    durationFillColor = serviceColor.fill
                                case .bubble:
                                    durationFillColor = .clear
                                    if item.message.effectivelyIncoming(item.context.account.peerId) {
                                        durationTextColor = theme.theme.chat.message.incoming.secondaryTextColor
                                    } else {
                                        durationTextColor = theme.theme.chat.message.outgoing.secondaryTextColor
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
                            
                            let streamVideo = automaticDownload && isMediaStreamable(message: item.message, media: telegramFile) && telegramFile.id?.namespace != Namespaces.Media.LocalFile
                            if let videoNode = strongSelf.videoNode {
                                videoNode.layer.allowsGroupOpacity = true
                                videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.5, delay: 0.2, removeOnCompletion: false, completion: { [weak videoNode] _ in
                                    videoNode?.removeFromSupernode()
                                })
                            }
                            let mediaManager = item.context.sharedContext.mediaManager
                            let videoNode = UniversalVideoNode(postbox: item.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: ChatBubbleInstantVideoDecoration(diameter: displaySize.width + 2.0, backgroundImage: instantVideoBackgroundImage, tapped: {
                                if let strongSelf = self {
                                    if let item = strongSelf.item {
                                        if strongSelf.infoBackgroundNode.alpha.isZero {
                                            item.context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: .voice)
                                        } else {
                                            //let _ = item.controllerInteraction.openMessage(item.message)
                                        }
                                    }
                                }
                            }), content: NativeVideoContent(id: .message(item.message.stableId, telegramFile.fileId), fileReference: .message(message: MessageReference(item.message), media: telegramFile), streamVideo: streamVideo ? .conservative : .none, enableSound: false, fetchAutomatically: false), priority: .embedded, autoplay: true)
                            let previousVideoNode = strongSelf.videoNode
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
                                strongSelf.updateStatus()
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
                    
                    if let durationNode = strongSelf.durationNode {
                        durationNode.frame = CGRect(origin: CGPoint(x: videoFrame.midX - 56.0, y: videoFrame.maxY - 18.0), size: CGSize(width: 1.0, height: 1.0))
                        durationNode.isSeen = !notConsumed
                    }
                    
                    if let videoNode = strongSelf.videoNode {
                        videoNode.frame = videoFrame
                        videoNode.updateLayout(size: arguments.boundingSize, transition: .immediate)
                    }
                    strongSelf.secretVideoPlaceholderBackground.frame = videoFrame
                    
                    let placeholderFrame = videoFrame.insetBy(dx: 2.0, dy: 2.0)
                    strongSelf.secretVideoPlaceholder.frame = placeholderFrame
                    let makeSecretPlaceholderLayout = strongSelf.secretVideoPlaceholder.asyncLayout()
                    let arguments = TransformImageArguments(corners: ImageCorners(radius: placeholderFrame.size.width / 2.0), imageSize: placeholderFrame.size, boundingSize: placeholderFrame.size, intrinsicInsets: UIEdgeInsets())
                    let applySecretPlaceholder = makeSecretPlaceholderLayout(arguments)
                    applySecretPlaceholder()
                    
                    strongSelf.updateStatus()
                    
                    if let telegramFile = updatedFile, previousAutomaticDownload != automaticDownload, automaticDownload {
                        strongSelf.fetchDisposable.set(messageMediaFileInteractiveFetched(context: item.context, message: item.message, file: telegramFile, userInitiated: false).start())
                    }
                }
            })
        }
    }
    
    private func updateStatus() {
        guard let item = self.item, let status = self.status, let videoFrame = self.videoFrame else {
            return
        }
        let messageTheme = item.presentationData.theme.theme.chat.message
        
        let isSecretMedia = item.message.containsSecretMedia
        var secretBeginTimeAndTimeout: (Double, Double)?
        if isSecretMedia {
            for attribute in item.message.attributes {
                if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                    if let countdownBeginTime = attribute.countdownBeginTime {
                        secretBeginTimeAndTimeout = (Double(countdownBeginTime), Double(attribute.timeout))
                    }
                    break
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
        if let message = self.item?.message, let media = self.media, let size = media.size, (isMediaStreamable(message: message, media: media) || size <= 256 * 1024) && (self.automaticDownload ?? false) {
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
                statusNode.frame = CGRect(origin: CGPoint(x: videoFrame.origin.x + floor((videoFrame.size.width - 50.0) / 2.0), y: videoFrame.origin.y + floor((videoFrame.size.height - 50.0) / 2.0)), size: CGSize(width: 50.0, height: 50.0))
                self.statusNode = statusNode
                self.addSubnode(statusNode)
            }
        } else {
            if let statusNode = self.statusNode {
                statusNode.transitionToState(.none, completion: { [weak statusNode] in
                    statusNode?.removeFromSupernode()
                })
                self.statusNode = nil
            }
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
                                state = .progress(color: messageTheme.mediaOverlayControlColors.foregroundColor, lineWidth: nil, value: nil, cancelEnabled: true)
                            } else {
                                state = .none
                            }
                        } else {
                            let adjustedProgress = max(progress, 0.027)
                            state = .progress(color: messageTheme.mediaOverlayControlColors.foregroundColor, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true)
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
                    case .Remote:
                        state = .download(messageTheme.mediaOverlayControlColors.foregroundColor)
                }
            default:
                var isLocal = false
                if case .Local = status.fetchStatus {
                    isLocal = true
                }
                if (isBuffering ?? false) && !isLocal {
                    state = .progress(color: messageTheme.mediaOverlayControlColors.foregroundColor, lineWidth: nil, value: nil, cancelEnabled: true)
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
                playbackStatusNode = InstantVideoRadialStatusNode(color: UIColor(white: 1.0, alpha: 0.8))
                self.addSubnode(playbackStatusNode)
                self.playbackStatusNode = playbackStatusNode
            }
            playbackStatusNode.frame = videoFrame.insetBy(dx: 1.5, dy: 1.5)
            
            let status = messageFileMediaPlaybackStatus(context: item.context, file: file, message: item.message, isRecentActions: item.associatedData.isRecentActions)
            playbackStatusNode.status = status
            self.durationNode?.status = status
            |> map(Optional.init)
            
            self.videoNode?.isHidden = false
            self.secretVideoPlaceholderBackground.isHidden = true
            self.secretVideoPlaceholder.isHidden = true
        } else {
            if let playbackStatusNode = self.playbackStatusNode {
                self.playbackStatusNode = nil
                playbackStatusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak playbackStatusNode] _ in
                    playbackStatusNode?.removeFromSupernode()
                })
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
                            if let statusNode = self.statusNode, statusNode.supernode != nil, !statusNode.isHidden, statusNode.frame.contains(location) {
                                self.progressPressed()
                                return
                            }
                            
                            if let _ = self.item, let videoNode = self.videoNode, videoNode.frame.contains(location) {
                                self.activateVideoPlayback()
                                return
                            }
                            
                            self.item?.controllerInteraction.clickThroughMessage()
                        case .longTap, .doubleTap:
                            if let item = self.item, let videoNode = self.videoNode, videoNode.frame.contains(location) {
                                item.controllerInteraction.openMessageContextMenu(item.message, false, self, videoNode.frame, nil)
                            }
                        case .hold:
                            break
                    }
                }
            default:
                break
        }
    }
    
    private func activateVideoPlayback() {
        guard let item = self.item else {
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
                                let messageId = item.message.id
                                let _ = item.context.account.postbox.transaction({ transaction -> Void in
                                    deleteMessages(transaction: transaction, mediaBox: item.context.account.postbox.mediaBox, ids: [messageId])
                                }).start()
                            } else {
                                messageMediaFileCancelInteractiveFetch(context: item.context, messageId: item.message.id, file: file)
                            }
                        case .Remote:
                            self.videoNode?.fetchControl(.fetch)
                        case .Local:
                            self.activateVideoPlayback()
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

    static func asyncLayout(_ node: ChatMessageInteractiveInstantVideoNode?) -> (_ item: ChatMessageBubbleContentItem, _ width: CGFloat, _ displaySize: CGSize, _ statusType: ChatMessageInteractiveInstantVideoNodeStatusType, _ automaticDownload: Bool) -> (ChatMessageInstantVideoItemLayoutResult, (ChatMessageInstantVideoItemLayoutData, ContainedViewLayoutTransition) -> ChatMessageInteractiveInstantVideoNode) {
        let makeLayout = node?.asyncLayout()
        return { item, width, displaySize, statusType, automaticDownload in
            var createdNode: ChatMessageInteractiveInstantVideoNode?
            let sizeAndApplyLayout: (ChatMessageInstantVideoItemLayoutResult, (ChatMessageInstantVideoItemLayoutData, ContainedViewLayoutTransition) -> Void)
            if let makeLayout = makeLayout {
                sizeAndApplyLayout = makeLayout(item, width, displaySize, statusType, automaticDownload)
            } else {
                let node = ChatMessageInteractiveInstantVideoNode()
                sizeAndApplyLayout = node.asyncLayout()(item, width, displaySize, statusType, automaticDownload)
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
}

