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

final class ChatMessageInteractiveMediaNode: ASTransformNode {
    private let imageNode: TransformImageNode
    private var videoNode: ManagedVideoNode?
    private var statusNode: RadialStatusNode?
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
                        if videoNode.supernode == nil {
                            self.insertSubnode(videoNode, aboveSubnode: self.imageNode)
                        }
                    case .nearlyVisible, .none:
                        if videoNode.supernode != nil {
                            videoNode.removeFromSupernode()
                        }
                }
            }
        }
    }
    
    var activateLocalContent: () -> Void = { }
    
    init() {
        self.imageNode = TransformImageNode()
        
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
    
    func asyncLayout() -> (_ account: Account, _ theme: PresentationTheme, _ strings: PresentationStrings, _ message: Message, _ media: Media, _ corners: ImageCorners, _ automaticDownload: Bool, _ constrainedSize: CGSize, _ layoutConstants: ChatMessageItemLayoutConstants) -> (CGFloat, ImageCorners, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void))) {
        let currentMessageIdAndFlags = self.messageIdAndFlags
        let currentMedia = self.media
        let imageLayout = self.imageNode.asyncLayout()
        
        let currentVideoNode = self.videoNode
        let hasCurrentVideoNode = currentVideoNode != nil
        
        let currentTheme = self.themeAndStrings?.0
        
        return { [weak self] account, theme, strings, message, media, corners, automaticDownload, constrainedSize, layoutConstants in
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
            
            var isInlinePlayableVideo = false
            
            if let image = media as? TelegramMediaImage, let dimensions = largestImageRepresentation(image.representations)?.dimensions {
                nativeSize = CGSize(width: floor(dimensions.width * 0.5), height: floor(dimensions.height * 0.5)).fitted(constrainedSize)
            } else if let file = media as? TelegramMediaFile, let dimensions = file.dimensions {
                nativeSize = CGSize(width: floor(dimensions.width * 0.5), height: floor(dimensions.height * 0.5)).fitted(constrainedSize)
                if file.isAnimated {
                    nativeSize = nativeSize.aspectFilled(CGSize(width: 480.0, height: 480.0))
                }
                isInlinePlayableVideo = file.isVideo && file.isAnimated
            } else if let image = media as? TelegramMediaWebFile, let dimensions = image.dimensions {
                nativeSize = CGSize(width: floor(dimensions.width * 0.5), height: floor(dimensions.height * 0.5)).fitted(constrainedSize)
            } else {
                nativeSize = CGSize(width: 54.0, height: 54.0)
            }
            
            var updatedCorners = corners
            if isInlinePlayableVideo {
                updatedCorners = updatedCorners.withRemovedTails()
                let radius = max(updatedCorners.bottomLeft.radius, updatedCorners.bottomRight.radius)
                updatedCorners = ImageCorners(radius: radius)
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
            
            return (maxWidth, updatedCorners, { constrainedSize in
                let resultWidth: CGFloat
                
                if isSecretMedia {
                    resultWidth = maxWidth
                } else {
                    //resultWidth = min(maxWidth, nativeSize.width)
                    resultWidth = min(constrainedSize.width, nativeSize.aspectFitted(layoutConstants.image.maxDimensions).width)
                }
                
                return (resultWidth, { boundingWidth in
                    let drawingSize: CGSize
                    let boundingSize: CGSize
                    
                    if isSecretMedia {
                        boundingSize = CGSize(width: maxWidth, height: maxWidth)
                        drawingSize = nativeSize.aspectFilled(boundingSize)
                    } else {
                        let fittedSize = nativeSize.fittedToWidthOrSmaller(boundingWidth)
                        boundingSize = CGSize(width: boundingWidth, height: fittedSize.height).cropped(CGSize(width: CGFloat.greatestFiniteMagnitude, height: layoutConstants.image.maxDimensions.height))
                        drawingSize = nativeSize.fitted(boundingSize)
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
                    
                    var updatedVideoNode: ManagedVideoNode?
                    var replaceVideoNode = false
                    var updateVideoFile: TelegramMediaFile?
                    
                    if mediaUpdated {
                        if let image = media as? TelegramMediaImage {
                            if isSecretMedia {
                                updateImageSignal = chatSecretPhoto(account: account, photo: image)
                            } else {
                                updateImageSignal = chatMessagePhoto(account: account, photo: image)
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
                                updateImageSignal = chatMessageVideo(account: account, video: file)
                            }
                            
                            if isInlinePlayableVideo {
                                updateVideoFile = file
                                if hasCurrentVideoNode {
                                } else {
                                    let videoNode = ManagedVideoNode()
                                    videoNode.isUserInteractionEnabled = false
                                    updatedVideoNode = videoNode
                                    replaceVideoNode = true
                                }
                            } else {
                                if hasCurrentVideoNode {
                                    replaceVideoNode = true
                                }
                            }
                            
                            updatedFetchControls = FetchControls(fetch: {
                                if let strongSelf = self {
                                    strongSelf.fetchDisposable.set(chatMessageFileInteractiveFetched(account: account, file: file).start())
                                }
                            }, cancel: {
                                    chatMessageFileCancelInteractiveFetch(account: account, file: file)
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
                                            return .Fetching(progress: progress)
                                        } else {
                                            return resourceStatus
                                        }
                                }
                            } else {
                                updatedStatusSignal = chatMessagePhotoStatus(account: account, photo: image)
                            }
                        } else if let file = media as? TelegramMediaFile {
                            updatedStatusSignal = combineLatest(chatMessageFileStatus(account: account, file: file), account.pendingMessageManager.pendingMessageStatus(message.id))
                                |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                                    if let pendingStatus = pendingStatus {
                                        var progress = pendingStatus.progress
                                        if pendingStatus.isRunning {
                                            progress = max(progress, 0.027)
                                        }
                                        return .Fetching(progress: progress)
                                    } else {
                                        return resourceStatus
                                    }
                            }
                        }
                    }
                    
                    let arguments = TransformImageArguments(corners: updatedCorners, imageSize: drawingSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets())
                    
                    let imageFrame = CGRect(origin: CGPoint(x: -arguments.insets.left, y: -arguments.insets.top), size: arguments.drawingSize)
                    
                    let imageApply = imageLayout(arguments)
                    
                    return (boundingSize, {
                        if let strongSelf = self {
                            strongSelf.account = account
                            strongSelf.messageIdAndFlags = (message.id, message.flags)
                            strongSelf.media = media
                            strongSelf.themeAndStrings = (theme, strings)
                            strongSelf.imageNode.frame = imageFrame
                            strongSelf.statusNode?.position = CGPoint(x: imageFrame.midX, y: imageFrame.midY)
                            strongSelf.timeoutNode?.position = CGPoint(x: imageFrame.midX, y: imageFrame.midY)
                            
                            if replaceVideoNode {
                                if let videoNode = strongSelf.videoNode {
                                    videoNode.clearContext()
                                    videoNode.removeFromSupernode()
                                    strongSelf.videoNode = nil
                                }
                                
                                if let updatedVideoNode = updatedVideoNode {
                                    strongSelf.videoNode = updatedVideoNode
                                    if strongSelf.visibility == .visible {
                                        strongSelf.insertSubnode(updatedVideoNode, aboveSubnode: strongSelf.imageNode)
                                    }
                                }
                            }
                            
                            if let videoNode = strongSelf.videoNode {
                                if let updateVideoFile = updateVideoFile {
                                    if let applicationContext = account.applicationContext as? TelegramApplicationContext {
                                        videoNode.acquireContext(account: account, mediaManager: applicationContext.mediaManager, id: PeerMessageManagedMediaId(messageId: message.id), resource: updateVideoFile.resource, priority: 1)
                                    }
                                }
                                
                                videoNode.transformArguments = arguments
                                videoNode.frame = imageFrame
                            }
                            
                            if let updateImageSignal = updateImageSignal {
                                strongSelf.imageNode.setSignal(account: account, signal: updateImageSignal)
                            }
                            
                            if let secretBeginTimeAndTimeout = secretBeginTimeAndTimeout {
                                if strongSelf.timeoutNode == nil {
                                    let timeoutNode = RadialTimeoutNode(backgroundColor: theme.chat.bubble.mediaOverlayControlBackgroundColor, foregroundColor: theme.chat.bubble.mediaOverlayControlForegroundColor)
                                    timeoutNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 50.0, height: 50.0))
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
                                                    }
                                                } else {
                                                    progressRequired = true
                                                }
                                            }
                                            
                                            if progressRequired {
                                                if strongSelf.statusNode == nil {
                                                    let statusNode = RadialStatusNode(backgroundNodeColor: theme.chat.bubble.mediaOverlayControlBackgroundColor)
                                                    statusNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 50.0, height: 50.0))
                                                    statusNode.position = strongSelf.imageNode.position
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
                                                case let .Fetching(progress):
                                                    state = .progress(color: bubbleTheme.mediaOverlayControlForegroundColor, value: CGFloat(progress), cancelEnabled: true)
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
                                                    }
                                                case .Remote:
                                                    state = .download(bubbleTheme.mediaOverlayControlForegroundColor)
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
    
    static func asyncLayout(_ node: ChatMessageInteractiveMediaNode?) -> (_ account: Account, _ theme: PresentationTheme, _ strings: PresentationStrings, _ message: Message, _ media: Media, _ corners: ImageCorners, _ automaticDownload: Bool, _ constrainedSize: CGSize, _ layoutConstants: ChatMessageItemLayoutConstants) -> (CGFloat, ImageCorners, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageInteractiveMediaNode))) {
        let currentAsyncLayout = node?.asyncLayout()
        
        return { account, theme, strings, message, media, corners, automaticDownload, constrainedSize, layoutConstants in
            var imageNode: ChatMessageInteractiveMediaNode
            var imageLayout: (_ account: Account, _ theme: PresentationTheme, _ strings: PresentationStrings, _ message: Message, _ media: Media, _ corners: ImageCorners, _ automaticDownload: Bool, _ constrainedSize: CGSize, _ layoutConstants: ChatMessageItemLayoutConstants) -> (CGFloat, ImageCorners, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void)))
            
            if let node = node, let currentAsyncLayout = currentAsyncLayout {
                imageNode = node
                imageLayout = currentAsyncLayout
            } else {
                imageNode = ChatMessageInteractiveMediaNode()
                imageLayout = imageNode.asyncLayout()
            }
            
            let (initialWidth, corners, continueLayout) = imageLayout(account, theme, strings, message, media, corners, automaticDownload, constrainedSize, layoutConstants)
            
            return (initialWidth, corners, { constrainedSize in
                let (finalWidth, finalLayout) = continueLayout(constrainedSize)
                
                return (finalWidth, { boundingWidth in
                    let (finalSize, apply) = finalLayout(boundingWidth)
                    
                    return (finalSize, {
                        apply()
                        return imageNode
                    })
                })
            })
        }
    }
}

