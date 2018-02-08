import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

private struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
}

enum InteractiveMediaNodeSizeCalculation {
    case constrained(CGSize)
    case unconstrained
}

final class ChatMessageInteractiveMediaNode: ASTransformNode {
    private let imageNode: TransformImageNode
    private var videoNode: UniversalVideoNode?
    private var statusNode: RadialStatusNode?
    private var badgeNode: ChatMessageInteractiveMediaBadge?
    private var timeoutNode: RadialTimeoutNode?
    private var labelNode: ChatMessageInteractiveMediaLabelNode?
    private var tapRecognizer: UITapGestureRecognizer?
    
    private var account: Account?
    private var messageIdAndFlags: (MessageId, MessageFlags)?
    private var media: Media?
    private var themeAndStrings: (PresentationTheme, PresentationStrings)?
    
    private let statusDisposable = MetaDisposable()
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var fetchStatus: MediaResourceStatus?
    private let fetchDisposable = MetaDisposable()
    
    var visibility: ListViewItemNodeVisibility = .none {
        didSet {
            if let videoNode = self.videoNode {
                switch visibility {
                    case .visible:
                        if !videoNode.canAttachContent {
                            videoNode.canAttachContent = true
                            videoNode.play()
                        }
                    case .nearlyVisible, .none:
                        videoNode.canAttachContent = false
                }
            }
        }
    }
    
    var activateLocalContent: () -> Void = { }
    
    init() {
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        
        super.init(layerBacked: false)
        
        self.imageNode.displaysAsynchronously = false
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.imageTap(_:)))
        self.imageNode.view.addGestureRecognizer(tapRecognizer)
        self.tapRecognizer = tapRecognizer
    }
    
    @objc func progressPressed() {
        if let fetchStatus = self.fetchStatus {
            switch fetchStatus {
                case .Fetching:
                    if let account = self.account, let (messageId, flags) = self.messageIdAndFlags, flags.isSending {
                       let _ = account.postbox.modify({ modifier -> Void in
                            modifier.deleteMessages([messageId])
                        }).start()
                    }
                    if let cancel = self.fetchControls.with({ return $0?.cancel }) {
                        cancel()
                    }
                case .Remote:
                    if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                        fetch()
                    }
                case .Local:
                    break
            }
        }
    }
    
    @objc func imageTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let point = recognizer.location(in: self.imageNode.view)
            if let fetchStatus = self.fetchStatus, case .Local = fetchStatus {
                self.activateLocalContent()
            } else {
                if let (_, flags) = self.messageIdAndFlags, flags.isSending {
                    if let statusNode = self.statusNode, statusNode.frame.contains(point) {
                        self.progressPressed()
                    }
                } else {
                    self.progressPressed()
                }
            }
        }
    }
    
    func asyncLayout() -> (_ account: Account, _ theme: PresentationTheme, _ strings: PresentationStrings, _ message: Message, _ media: Media, _ automaticDownload: Bool, _ sizeCalculation: InteractiveMediaNodeSizeCalculation, _ layoutConstants: ChatMessageItemLayoutConstants) -> (CGSize, CGFloat, (CGSize, ImageCorners) -> (CGFloat, (CGFloat) -> (CGSize, (ContainedViewLayoutTransition) -> Void))) {
        let currentMessageIdAndFlags = self.messageIdAndFlags
        let currentMedia = self.media
        let imageLayout = self.imageNode.asyncLayout()
        
        let currentVideoNode = self.videoNode
        let hasCurrentVideoNode = currentVideoNode != nil
        
        let currentTheme = self.themeAndStrings?.0
        
        return { [weak self] account, theme, strings, message, media, automaticDownload, sizeCalculation, layoutConstants in
            var nativeSize: CGSize
            
            var updatedTheme: PresentationTheme?
            
            if theme !== currentTheme {
                updatedTheme = theme
            }
            
            let isSecretMedia = message.containsSecretMedia
            var secretBeginTimeAndTimeout: (Double, Double)?
            if isSecretMedia {
                for attribute in message.attributes {
                    if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                        if let countdownBeginTime = attribute.countdownBeginTime {
                            secretBeginTimeAndTimeout = (Double(countdownBeginTime), Double(attribute.timeout))
                        }
                        break
                    }
                }
            }
            
            var webpage: TelegramMediaWebpage?
            for m in message.media {
                if let m = m as? TelegramMediaWebpage {
                    webpage = m
                }
            }
            
            var isInlinePlayableVideo = false
            
            var unboundSize: CGSize
            if let image = media as? TelegramMediaImage, let dimensions = largestImageRepresentation(image.representations)?.dimensions {
                unboundSize = CGSize(width: floor(dimensions.width * 0.5), height: floor(dimensions.height * 0.5))
            } else if let file = media as? TelegramMediaFile, let dimensions = file.dimensions {
                unboundSize = CGSize(width: floor(dimensions.width * 0.5), height: floor(dimensions.height * 0.5))
                if file.isAnimated {
                    unboundSize = unboundSize.aspectFilled(CGSize(width: 480.0, height: 480.0))
                }
                isInlinePlayableVideo = file.isVideo && file.isAnimated
            } else if let image = media as? TelegramMediaWebFile, let dimensions = image.dimensions {
                unboundSize = CGSize(width: floor(dimensions.width * 0.5), height: floor(dimensions.height * 0.5))
            } else {
                unboundSize = CGSize(width: 54.0, height: 54.0)
            }
            
            switch sizeCalculation {
                case let .constrained(constrainedSize):
                    nativeSize = unboundSize.fitted(constrainedSize)
                case .unconstrained:
                    nativeSize = unboundSize
            }
            
            let maxWidth: CGFloat
            if isSecretMedia {
                maxWidth = 180.0
            } else {
                maxWidth = layoutConstants.image.maxDimensions.width
            }
            
            var secretProgressIcon: UIImage?
            if isSecretMedia {
                secretProgressIcon = PresentationResourcesChat.chatBubbleSecretMediaIcon(theme)
            }
            
            return (nativeSize, maxWidth, { constrainedSize, corners in
                var resultWidth: CGFloat
                
                switch sizeCalculation {
                    case .constrained:
                        if isSecretMedia {
                            resultWidth = maxWidth
                        } else {
                            let maxFittedSize = nativeSize.aspectFitted (layoutConstants.image.maxDimensions)
                            resultWidth = min(nativeSize.width, min(maxFittedSize.width, min(constrainedSize.width, layoutConstants.image.maxDimensions.width)))
                            
                            resultWidth = max(resultWidth, layoutConstants.image.minDimensions.width)
                        }
                    case .unconstrained:
                        resultWidth = constrainedSize.width
                }
                
                return (resultWidth, { boundingWidth in
                    var boundingSize: CGSize
                    let drawingSize: CGSize
                    
                    switch sizeCalculation {
                        case .constrained:
                            if isSecretMedia {
                                boundingSize = CGSize(width: maxWidth, height: maxWidth)
                                drawingSize = nativeSize.aspectFilled(boundingSize)
                            } else {
                                let fittedSize = nativeSize.fittedToWidthOrSmaller(boundingWidth)
                                boundingSize = CGSize(width: boundingWidth, height: fittedSize.height).cropped(CGSize(width: CGFloat.greatestFiniteMagnitude, height: layoutConstants.image.maxDimensions.height))
                                boundingSize.height = max(boundingSize.height, layoutConstants.image.minDimensions.height)
                                boundingSize.width = max(boundingSize.width, layoutConstants.image.minDimensions.width)
                                drawingSize = nativeSize.aspectFitted(boundingSize)
                            }
                        case .unconstrained:
                            boundingSize = constrainedSize
                            drawingSize = nativeSize.aspectFilled(boundingSize)
                    }
                    
                    var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                    var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
                    var updatedFetchControls: FetchControls?
                    
                    var mediaUpdated = false
                    if let currentMedia = currentMedia {
                        mediaUpdated = !media.isEqual(currentMedia)
                    } else {
                        mediaUpdated = true
                    }
                    
                    var statusUpdated = mediaUpdated
                    if currentMessageIdAndFlags?.0 != message.id || currentMessageIdAndFlags?.1 != message.flags {
                        statusUpdated = true
                    }
                    
                    var replaceVideoNode: Bool?
                    var updateVideoFile: TelegramMediaFile?
                    
                    if mediaUpdated {
                        if let image = media as? TelegramMediaImage {
                            if isSecretMedia {
                                updateImageSignal = chatSecretPhoto(account: account, photo: image)
                            } else {
                                updateImageSignal = chatMessagePhoto(postbox: account.postbox, photo: image)
                            }
                            
                            updatedFetchControls = FetchControls(fetch: {
                                if let strongSelf = self {
                                    strongSelf.fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photo: image).start())
                                }
                            }, cancel: {
                                chatMessagePhotoCancelInteractiveFetch(account: account, photo: image)
                            })
                        } else if let image = media as? TelegramMediaWebFile {
                            updateImageSignal = chatWebFileImage(account: account, file: image)
                            
                            updatedFetchControls = FetchControls(fetch: {
                                if let strongSelf = self {
                                    strongSelf.fetchDisposable.set(chatMessageWebFileInteractiveFetched(account: account, image: image).start())
                                }
                            }, cancel: {
                                chatMessageWebFileCancelInteractiveFetch(account: account, image: image)
                            })
                        } else if let file = media as? TelegramMediaFile {
                            if isSecretMedia {
                                updateImageSignal = chatSecretMessageVideo(account: account, video: file)
                            } else {
                                updateImageSignal = chatMessageVideo(postbox: account.postbox, video: file)
                            }
                            
                            if isInlinePlayableVideo {
                                updateVideoFile = file
                                if hasCurrentVideoNode {
                                } else {
                                    replaceVideoNode = true
                                }
                            } else {
                                if hasCurrentVideoNode {
                                    replaceVideoNode = false
                                }
                            }
                            
                            let messageId = message.id
                            updatedFetchControls = FetchControls(fetch: {
                                if let strongSelf = self {
                                   if file.isAnimated {
                                    strongSelf.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .image)).start())
                                   } else {
                                    strongSelf.fetchDisposable.set(messageMediaFileInteractiveFetched(account: account, messageId: messageId, file: file).start())
                                    }
                                }
                            }, cancel: {
                                if file.isAnimated {
                                    account.postbox.mediaBox.cancelInteractiveResourceFetch(file.resource)
                                } else {
                                    messageMediaFileCancelInteractiveFetch(account: account, messageId: messageId, file: file)
                                }
                            })
                        }
                    }
                    
                    if statusUpdated {
                        if let image = media as? TelegramMediaImage {
                            if message.flags.isSending {
                                updatedStatusSignal = combineLatest(chatMessagePhotoStatus(account: account, photo: image), account.pendingMessageManager.pendingMessageStatus(message.id))
                                    |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                                        if let pendingStatus = pendingStatus {
                                            var progress = pendingStatus.progress
                                            if pendingStatus.isRunning {
                                                progress = max(progress, 0.027)
                                            }
                                            return .Fetching(isActive: pendingStatus.isRunning, progress: progress)
                                        } else {
                                            return resourceStatus
                                        }
                                }
                            } else {
                                updatedStatusSignal = chatMessagePhotoStatus(account: account, photo: image)
                            }
                        } else if let file = media as? TelegramMediaFile {
                            updatedStatusSignal = combineLatest(messageMediaFileStatus(account: account, messageId: message.id, file: file), account.pendingMessageManager.pendingMessageStatus(message.id))
                                |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                                    if let pendingStatus = pendingStatus {
                                        var progress = pendingStatus.progress
                                        if pendingStatus.isRunning {
                                            progress = max(progress, 0.027)
                                        }
                                        return .Fetching(isActive: pendingStatus.isRunning, progress: progress)
                                    } else {
                                        return resourceStatus
                                    }
                            }
                        }
                    }
                    
                    let arguments = TransformImageArguments(corners: corners, imageSize: drawingSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), resizeMode: isInlinePlayableVideo ? .fill(.black) : .blurBackground)
                    
                    let imageFrame = CGRect(origin: CGPoint(x: -arguments.insets.left, y: -arguments.insets.top), size: arguments.drawingSize)
                    
                    let imageApply = imageLayout(arguments)
                    
                    let radialStatusSize: CGFloat
                    if case .unconstrained = sizeCalculation {
                        radialStatusSize = 32.0
                    } else {
                        radialStatusSize = 50.0
                    }
                    
                    return (boundingSize, { transition in
                        if let strongSelf = self {
                            strongSelf.account = account
                            strongSelf.messageIdAndFlags = (message.id, message.flags)
                            strongSelf.media = media
                            strongSelf.themeAndStrings = (theme, strings)
                            transition.updateFrame(node: strongSelf.imageNode, frame: imageFrame)
                            strongSelf.statusNode?.position = CGPoint(x: imageFrame.midX, y: imageFrame.midY)
                            strongSelf.timeoutNode?.position = CGPoint(x: imageFrame.midX, y: imageFrame.midY)
                            
                            if let replaceVideoNode = replaceVideoNode {
                                if let videoNode = strongSelf.videoNode {
                                    videoNode.canAttachContent = false
                                    videoNode.removeFromSupernode()
                                    strongSelf.videoNode = nil
                                }
                                
                                if replaceVideoNode, let updatedVideoFile = updateVideoFile {
                                    let videoNode = UniversalVideoNode(postbox: account.postbox, audioSession: account.telegramApplicationContext.mediaManager.audioSession, manager: account.telegramApplicationContext.mediaManager.universalVideoManager, decoration: ChatBubbleVideoDecoration(cornerRadius: 17.0, nativeSize: nativeSize), content: NativeVideoContent(id: .message(message.id, updatedVideoFile.fileId), file: updatedVideoFile, enableSound: false), priority: .embedded)
                                    videoNode.isUserInteractionEnabled = false
                                    
                                    strongSelf.videoNode = videoNode
                                    strongSelf.insertSubnode(videoNode, aboveSubnode: strongSelf.imageNode)
                                }
                            }
                            
                            if let videoNode = strongSelf.videoNode {
                                videoNode.updateLayout(size: arguments.drawingSize, transition: .immediate)
                                videoNode.frame = imageFrame
                                
                                if strongSelf.visibility == .visible {
                                    if !videoNode.canAttachContent {
                                        videoNode.canAttachContent = true
                                        videoNode.play()
                                    }
                                } else {
                                    videoNode.canAttachContent = false
                                }
                            }
                            
                            if let updateImageSignal = updateImageSignal {
                                strongSelf.imageNode.setSignal(updateImageSignal)
                            }
                            
                            if let secretBeginTimeAndTimeout = secretBeginTimeAndTimeout {
                                if strongSelf.timeoutNode == nil {
                                    let timeoutNode = RadialTimeoutNode(backgroundColor: theme.chat.bubble.mediaOverlayControlBackgroundColor, foregroundColor: theme.chat.bubble.mediaOverlayControlForegroundColor)
                                    timeoutNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: radialStatusSize, height: radialStatusSize))
                                    timeoutNode.position = strongSelf.imageNode.position
                                    strongSelf.timeoutNode = timeoutNode
                                    strongSelf.addSubnode(timeoutNode)
                                    timeoutNode.setTimeout(beginTimestamp: secretBeginTimeAndTimeout.0, timeout: secretBeginTimeAndTimeout.1)
                                } else if let updatedTheme = updatedTheme {
                                    strongSelf.timeoutNode?.updateTheme(backgroundColor: updatedTheme.chat.bubble.mediaOverlayControlBackgroundColor, foregroundColor: updatedTheme.chat.bubble.mediaOverlayControlForegroundColor)
                                }
                                
                                if let statusNode = strongSelf.statusNode {
                                    statusNode.transitionToState(.none, completion: { [weak statusNode] in
                                        statusNode?.removeFromSupernode()
                                    })
                                    strongSelf.statusNode = nil
                                }
                            } else if let timeoutNode = strongSelf.timeoutNode {
                                timeoutNode.removeFromSupernode()
                                strongSelf.timeoutNode = nil
                            }
                            
                            if let updatedStatusSignal = updatedStatusSignal {
                                strongSelf.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                                    displayLinkDispatcher.dispatch {
                                        if let strongSelf = strongSelf {
                                            strongSelf.fetchStatus = status
                                            
                                            var progressRequired = false
                                            if secretBeginTimeAndTimeout == nil {
                                                if case .Local = status {
                                                    if let file = media as? TelegramMediaFile, file.isVideo {
                                                        progressRequired = true
                                                    } else if isSecretMedia {
                                                        progressRequired = true
                                                    } else if let webpage = webpage, case let .Loaded(content) = webpage.content, content.embedUrl != nil {
                                                        progressRequired = true
                                                    }
                                                } else {
                                                    progressRequired = true
                                                }
                                            }
                                            
                                            if progressRequired {
                                                if strongSelf.statusNode == nil {
                                                    let statusNode = RadialStatusNode(backgroundNodeColor: theme.chat.bubble.mediaOverlayControlBackgroundColor)
                                                    statusNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: radialStatusSize, height: radialStatusSize))
                                                    statusNode.position = strongSelf.imageNode.position
                                                    strongSelf.statusNode = statusNode
                                                    strongSelf.addSubnode(statusNode)
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
                                            var badgeContent: ChatMessageInteractiveMediaBadgeContent?
                                            let bubbleTheme = theme.chat.bubble
                                            switch status {
                                                case let .Fetching(isActive, progress):
                                                    var adjustedProgress = progress
                                                    if isActive {
                                                        adjustedProgress = max(adjustedProgress, 0.027)
                                                    }
                                                    if let (_, flags) = strongSelf.messageIdAndFlags, flags.isSending && adjustedProgress.isEqual(to: 1.0), case .unconstrained = sizeCalculation {
                                                        state = .check(bubbleTheme.mediaOverlayControlForegroundColor)
                                                    } else {
                                                        state = .progress(color: bubbleTheme.mediaOverlayControlForegroundColor, value: CGFloat(adjustedProgress), cancelEnabled: true)
                                                    }
                                                    if case .constrained = sizeCalculation {
                                                        if let file = media as? TelegramMediaFile, !file.isAnimated {
                                                            if let size = file.size {
                                                                badgeContent = .text(backgroundColor: bubbleTheme.mediaDateAndStatusFillColor, foregroundColor: bubbleTheme.mediaDateAndStatusTextColor, shape: .round, text: "\(dataSizeString(Int(Float(size) * progress))) / \(dataSizeString(size))")
                                                            } else if let _ = file.duration {
                                                                badgeContent = .text(backgroundColor: bubbleTheme.mediaDateAndStatusFillColor, foregroundColor: bubbleTheme.mediaDateAndStatusTextColor, shape: .round, text: strings.Conversation_Processing)
                                                            }
                                                        }
                                                    }
                                                case .Local:
                                                    state = .none
                                                    if isSecretMedia && secretProgressIcon != nil {
                                                        state = .customIcon(secretProgressIcon!)
                                                    } else if let file = media as? TelegramMediaFile {
                                                        if !isInlinePlayableVideo && file.isVideo {
                                                            state = .play(bubbleTheme.mediaOverlayControlForegroundColor)
                                                        } else {
                                                            state = .none
                                                        }
                                                    } else if let webpage = webpage, case let .Loaded(content) = webpage.content, content.embedUrl != nil {
                                                        state = .play(bubbleTheme.mediaOverlayControlForegroundColor)
                                                    }
                                                    if case .constrained = sizeCalculation {
                                                        if let file = media as? TelegramMediaFile, let duration = file.duration, !file.isAnimated {
                                                            let durationString = String(format: "%d:%02d", duration / 60, duration % 60)
                                                            badgeContent = .text(backgroundColor: bubbleTheme.mediaDateAndStatusFillColor, foregroundColor: bubbleTheme.mediaDateAndStatusTextColor, shape: .round, text: durationString)
                                                        }
                                                    }
                                                case .Remote:
                                                    state = .download(bubbleTheme.mediaOverlayControlForegroundColor)
                                                    if case .constrained = sizeCalculation {
                                                        if let file = media as? TelegramMediaFile, let duration = file.duration, !file.isAnimated {
                                                            let durationString = String(format: "%d:%02d", duration / 60, duration % 60)
                                                            badgeContent = .text(backgroundColor: bubbleTheme.mediaDateAndStatusFillColor, foregroundColor: bubbleTheme.mediaDateAndStatusTextColor, shape: .round, text: durationString)
                                                        }
                                                    }
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
                                            if let badgeContent = badgeContent {
                                                if strongSelf.badgeNode == nil {
                                                    let badgeNode = ChatMessageInteractiveMediaBadge()
                                                    badgeNode.frame = CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: radialStatusSize, height: radialStatusSize))
                                                    strongSelf.badgeNode = badgeNode
                                                    strongSelf.addSubnode(badgeNode)
                                                }
                                                strongSelf.badgeNode?.content = badgeContent
                                            } else if let badgeNode = strongSelf.badgeNode {
                                                strongSelf.badgeNode = nil
                                                badgeNode.removeFromSupernode()
                                            }
                                        }
                                    }
                                }))
                            }
                            
                            if let updatedFetchControls = updatedFetchControls {
                                let _ = strongSelf.fetchControls.swap(updatedFetchControls)
                                if automaticDownload {
                                    if let image = media as? TelegramMediaImage {
                                        strongSelf.fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photo: image).start())
                                    } else if let image = media as? TelegramMediaWebFile {
                                        strongSelf.fetchDisposable.set(chatMessageWebFileInteractiveFetched(account: account, image: image).start())
                                    }
                                }
                            }
                            
                            imageApply()
                        }
                    })
                })
            })
        }
    }
    
    static func asyncLayout(_ node: ChatMessageInteractiveMediaNode?) -> (_ account: Account, _ theme: PresentationTheme, _ strings: PresentationStrings, _ message: Message, _ media: Media, _ automaticDownload: Bool, _ sizeCalcilation: InteractiveMediaNodeSizeCalculation, _ layoutConstants: ChatMessageItemLayoutConstants) -> (CGSize, CGFloat, (CGSize, ImageCorners) -> (CGFloat, (CGFloat) -> (CGSize, (ContainedViewLayoutTransition) -> ChatMessageInteractiveMediaNode))) {
        let currentAsyncLayout = node?.asyncLayout()
        
        return { account, theme, strings, message, media, automaticDownload, sizeCalculation, layoutConstants in
            var imageNode: ChatMessageInteractiveMediaNode
            var imageLayout: (_ account: Account, _ theme: PresentationTheme, _ strings: PresentationStrings, _ message: Message, _ media: Media, _ automaticDownload: Bool, _ sizeCalculation: InteractiveMediaNodeSizeCalculation, _ layoutConstants: ChatMessageItemLayoutConstants) -> (CGSize, CGFloat, (CGSize, ImageCorners) -> (CGFloat, (CGFloat) -> (CGSize, (ContainedViewLayoutTransition) -> Void)))
            
            if let node = node, let currentAsyncLayout = currentAsyncLayout {
                imageNode = node
                imageLayout = currentAsyncLayout
            } else {
                imageNode = ChatMessageInteractiveMediaNode()
                imageLayout = imageNode.asyncLayout()
            }
            
            let (unboundSize, initialWidth, continueLayout) = imageLayout(account, theme, strings, message, media, automaticDownload, sizeCalculation, layoutConstants)
            
            return (unboundSize, initialWidth, { constrainedSize, corners in
                let (finalWidth, finalLayout) = continueLayout(constrainedSize, corners)
                
                return (finalWidth, { boundingWidth in
                    let (finalSize, apply) = finalLayout(boundingWidth)
                    
                    return (finalSize, { transition in
                        apply(transition)
                        return imageNode
                    })
                })
            })
        }
    }
}

