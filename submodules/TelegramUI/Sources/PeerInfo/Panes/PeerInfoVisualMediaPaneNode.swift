import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import RadialStatusNode
import TelegramStringFormatting
import GridMessageSelectionNode
import UniversalMediaPlayer
import ListMessageItem
import ChatMessageInteractiveMediaBadge
import SparseItemGrid
import ShimmerEffect
import QuartzCore
import DirectMediaImageCache
import ComponentFlow

private final class FrameSequenceThumbnailNode: ASDisplayNode {
    private let context: AccountContext
    private let file: FileMediaReference
    private let imageNode: ASImageNode
    
    private var isPlaying: Bool = false
    private var isPlayingInternal: Bool = false
    
    private var frames: [Int: UIImage] = [:]
    
    private var frameTimes: [Double] = []
    private var sources: [UniversalSoftwareVideoSource] = []
    private var disposables: [Int: Disposable] = [:]
    
    private var currentFrameIndex: Int = 0
    private var timer: SwiftSignalKit.Timer?
    
    init(
        context: AccountContext,
        file: FileMediaReference
    ) {
        self.context = context
        self.file = file
        
        self.imageNode = ASImageNode()
        self.imageNode.isUserInteractionEnabled = false
        self.imageNode.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        
        if let duration = file.media.duration {
            let frameCount = 5
            let frameInterval: Double = Double(duration) / Double(frameCount)
            for i in 0 ..< frameCount {
                self.frameTimes.append(Double(i) * frameInterval)
            }
        }
        
        super.init()
        
        self.addSubnode(self.imageNode)
        
        for i in 0 ..< self.frameTimes.count {
            let framePts = self.frameTimes[i]
            let index = i
            
            let source = UniversalSoftwareVideoSource(
                mediaBox: self.context.account.postbox.mediaBox,
                fileReference: self.file,
                automaticallyFetchHeader: true
            )
            self.sources.append(source)
            self.disposables[index] = (source.takeFrame(at: framePts)
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                if case let .image(image) = result {
                    if let image = image {
                        strongSelf.frames[index] = image
                    }
                }
            })
        }
    }
    
    deinit {
        for (_, disposable) in self.disposables {
            disposable.dispose()
        }
        self.timer?.invalidate()
    }
    
    func updateIsPlaying(_ isPlaying: Bool) {
        if self.isPlaying == isPlaying {
            return
        }
        self.isPlaying = isPlaying
    }
    
    func updateLayout(size: CGSize) {
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    func tick() {
        let isPlayingInternal = self.isPlaying && self.frames.count == self.frameTimes.count
        if isPlayingInternal {
            self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frames.count
            
            if self.currentFrameIndex < self.frames.count {
                self.imageNode.image = self.frames[self.currentFrameIndex]
            }
        }
    }
}

private let mediaBadgeBackgroundColor = UIColor(white: 0.0, alpha: 0.6)
private let mediaBadgeTextColor = UIColor.white

private final class VisualMediaItemInteraction {
    let openMessage: (Message) -> Void
    let openMessageContextActions: (Message, ASDisplayNode, CGRect, ContextGesture?) -> Void
    let toggleSelection: (MessageId, Bool) -> Void
    
    var hiddenMedia: [MessageId: [Media]] = [:]
    var selectedMessageIds: Set<MessageId>?
    
    init(
        openMessage: @escaping (Message) -> Void,
        openMessageContextActions: @escaping (Message, ASDisplayNode, CGRect, ContextGesture?) -> Void,
        toggleSelection: @escaping (MessageId, Bool) -> Void
    ) {
        self.openMessage = openMessage
        self.openMessageContextActions = openMessageContextActions
        self.toggleSelection = toggleSelection
    }
}

/*private final class VisualMediaItemNode: ASDisplayNode {
    private let context: AccountContext
    private let interaction: VisualMediaItemInteraction
    
    private var videoLayerFrameManager: SoftwareVideoLayerFrameManager?
    private var sampleBufferLayer: SampleBufferLayer?
    private var displayLink: ConstantDisplayLinkAnimator?
    private var displayLinkTimestamp: Double = 0.0
    
    private var frameSequenceThumbnailNode: FrameSequenceThumbnailNode?
    
    private let containerNode: ContextControllerSourceNode

    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private let imageNode: TransformImageNode
    private var statusNode: RadialStatusNode
    private let mediaBadgeNode: ChatMessageInteractiveMediaBadge
    private var selectionNode: GridMessageSelectionNode?
    
    private let fetchStatusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private var resourceStatus: MediaResourceStatus?
    
    private var item: (VisualMediaItem, Media?, CGSize, CGSize?)?
    private var theme: PresentationTheme?
    
    private var hasVisibility: Bool = false
    
    init(context: AccountContext, interaction: VisualMediaItemInteraction) {
        self.context = context
        self.interaction = interaction
        
        self.containerNode = ContextControllerSourceNode()
        self.imageNode = TransformImageNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        let progressDiameter: CGFloat = 40.0
        self.statusNode.frame = CGRect(x: 0.0, y: 0.0, width: progressDiameter, height: progressDiameter)
        self.statusNode.isUserInteractionEnabled = false
        
        self.mediaBadgeNode = ChatMessageInteractiveMediaBadge()
        self.mediaBadgeNode.frame = CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: 50.0, height: 50.0))

        let shimmerNode = ShimmerEffectNode()
        self.placeholderNode = shimmerNode
        
        super.init()
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.mediaBadgeNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let message = item.0.message else {
                return
            }
            strongSelf.interaction.openMessageContextActions(message, strongSelf.containerNode, strongSelf.containerNode.bounds, gesture)
        }
    }
    
    deinit {
        self.fetchStatusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.imageNode.view.addGestureRecognizer(recognizer)
        
        self.mediaBadgeNode.pressed = { [weak self] in
            self?.progressPressed()
        }
    }

    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    @objc func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                if case .tap = gesture {
                    if let (item, _, _, _) = self.item, let message = item.message {
                        var media: Media?
                        for value in message.media {
                            if let image = value as? TelegramMediaImage {
                                media = image
                                break
                            } else if let file = value as? TelegramMediaFile {
                                media = file
                                break
                            }
                        }
                        
                        if let media = media {
                            if let file = media as? TelegramMediaFile {
                                if isMediaStreamable(message: message, media: file) {
                                    self.interaction.openMessage(message)
                                } else {
                                    self.progressPressed()
                                }
                            } else {
                                self.interaction.openMessage(message)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func progressPressed() {
        guard let message = self.item?.0.message else {
            return
        }
        
        var media: Media?
        for value in message.media {
            if let image = value as? TelegramMediaImage {
                media = image
                break
            } else if let file = value as? TelegramMediaFile {
                media = file
                break
            }
        }
        
        if let resourceStatus = self.resourceStatus, let file = media as? TelegramMediaFile {
            switch resourceStatus {
            case .Fetching:
                messageMediaFileCancelInteractiveFetch(context: self.context, messageId: message.id, file: file)
            case .Local:
                self.interaction.openMessage(message)
            case .Remote:
                self.fetchDisposable.set(messageMediaFileInteractiveFetched(context: self.context, message: message, file: file, userInitiated: true).start())
            }
        }
    }
    
    func cancelPreviewGesture() {
        self.containerNode.cancelGesture()
    }
    
    func update(size: CGSize, item: VisualMediaItem?, theme: PresentationTheme, synchronousLoad: Bool) {
        if item === self.item?.0 && size == self.item?.2 {
            return
        }
        self.theme = theme
        var media: Media?
        if let item = item, let message = item.message {
            for value in message.media {
                if let image = value as? TelegramMediaImage {
                    media = image
                    break
                } else if let file = value as? TelegramMediaFile {
                    media = file
                    break
                }
            }
        }

        if let shimmerNode = self.placeholderNode {
            shimmerNode.frame = CGRect(origin: CGPoint(), size: size)
            if let (rect, size) = self.absoluteLocation {
                shimmerNode.updateAbsoluteRect(rect, within: size)
            }

            var shapes: [ShimmerEffectNode.Shape] = []
            shapes.append(.rect(rect: CGRect(origin: CGPoint(), size: size)))

            shimmerNode.update(backgroundColor: theme.list.itemBlocksBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: size)
        }
        
        if let item = item, let message = item.message, let file = media as? TelegramMediaFile, file.isAnimated {
            if self.videoLayerFrameManager == nil {
                let sampleBufferLayer: SampleBufferLayer
                if let current = self.sampleBufferLayer {
                    sampleBufferLayer = current
                } else {
                    sampleBufferLayer = takeSampleBufferLayer()
                    self.sampleBufferLayer = sampleBufferLayer
                    self.imageNode.layer.addSublayer(sampleBufferLayer.layer)
                }
                
                self.videoLayerFrameManager = SoftwareVideoLayerFrameManager(account: self.context.account, fileReference: FileMediaReference.message(message: MessageReference(message), media: file), layerHolder: sampleBufferLayer)
                self.videoLayerFrameManager?.start()
            }
        } else {
            if let sampleBufferLayer = self.sampleBufferLayer {
                sampleBufferLayer.layer.removeFromSuperlayer()
                self.sampleBufferLayer = nil
            }
            self.videoLayerFrameManager = nil
        }
        
        if let item = item, let message = item.message, let media = media, (self.item?.1 == nil || !media.isEqual(to: self.item!.1!)) {
            var mediaDimensions: CGSize?
            if let image = media as? TelegramMediaImage, let largestSize = largestImageRepresentation(image.representations)?.dimensions {
                mediaDimensions = largestSize.cgSize

                if let placeholderNode = self.placeholderNode, placeholderNode.supernode == nil {
                    self.containerNode.insertSubnode(placeholderNode, at: 0)
                }
                self.imageNode.imageUpdated = { [weak self] image in
                    guard let strongSelf = self else {
                        return
                    }
                    if image != nil {
                        strongSelf.placeholderNode?.removeFromSupernode()
                    }
                }
               
                self.imageNode.setSignal(mediaGridMessagePhoto(account: context.account, photoReference: .message(message: MessageReference(message), media: image), fullRepresentationSize: CGSize(width: 300.0, height: 300.0), synchronousLoad: synchronousLoad), attemptSynchronously: synchronousLoad, dispatchOnDisplayLink: true)
                
                self.fetchStatusDisposable.set(nil)
                self.statusNode.transitionToState(.none, completion: { [weak self] in
                    self?.statusNode.isHidden = true
                })
                self.mediaBadgeNode.isHidden = true
                self.resourceStatus = nil
            } else if let file = media as? TelegramMediaFile, file.isVideo {
                if let placeholderNode = self.placeholderNode, placeholderNode.supernode == nil {
                    self.containerNode.insertSubnode(placeholderNode, at: 0)
                }
                self.imageNode.imageUpdated = { [weak self] image in
                    guard let strongSelf = self else {
                        return
                    }
                    if image != nil {
                        strongSelf.placeholderNode?.removeFromSupernode()
                    }
                }

                mediaDimensions = file.dimensions?.cgSize
                self.imageNode.setSignal(mediaGridMessageVideo(postbox: context.account.postbox, videoReference: .message(message: MessageReference(message), media: file), synchronousLoad: synchronousLoad, autoFetchFullSizeThumbnail: true), attemptSynchronously: synchronousLoad)
                
                self.mediaBadgeNode.isHidden = file.isAnimated
                
                self.resourceStatus = nil
                
                self.item = (item, media, size, mediaDimensions)
                
                self.fetchStatusDisposable.set((messageMediaFileStatus(context: context, messageId: message.id, file: file)
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self, let (item, _, _, _) = strongSelf.item, let message = item.message {
                        strongSelf.resourceStatus = status
                        
                        let isStreamable = isMediaStreamable(message: message, media: file)
                        
                        var statusState: RadialStatusNodeState = .none
                        if isStreamable || file.isAnimated {
                            statusState = .none
                        } else {
                            switch status {
                            case let .Fetching(_, progress):
                                let adjustedProgress = max(progress, 0.027)
                                statusState = .progress(color: .white, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true, animateRotation: true)
                            case .Local:
                                statusState = .none
                            case .Remote:
                                statusState = .download(.white)
                            }
                        }
                        
                        switch statusState {
                        case .none:
                            break
                        default:
                            strongSelf.statusNode.isHidden = false
                        }
                        
                        strongSelf.statusNode.transitionToState(statusState, animated: true, completion: {
                            if let strongSelf = self {
                                if case .none = statusState {
                                    strongSelf.statusNode.isHidden = true
                                }
                            }
                        })
                        
                        if let duration = file.duration {
                            let durationString = stringForDuration(duration)
                            
                            var badgeContent: ChatMessageInteractiveMediaBadgeContent?
                            var mediaDownloadState: ChatMessageInteractiveMediaDownloadState?
                            
                            if isStreamable {
                                switch status {
                                    case let .Fetching(_, progress):
                                        let progressString = String(format: "%d%%", Int(progress * 100.0))
                                        badgeContent = .text(inset: 12.0, backgroundColor: mediaBadgeBackgroundColor, foregroundColor: mediaBadgeTextColor, text: NSAttributedString(string: progressString))
                                        mediaDownloadState = .compactFetching(progress: 0.0)
                                    case .Local:
                                        badgeContent = .text(inset: 0.0, backgroundColor: mediaBadgeBackgroundColor, foregroundColor: mediaBadgeTextColor, text: NSAttributedString(string: durationString))
                                    case .Remote:
                                        badgeContent = .text(inset: 12.0, backgroundColor: mediaBadgeBackgroundColor, foregroundColor: mediaBadgeTextColor, text: NSAttributedString(string: durationString))
                                        mediaDownloadState = .compactRemote
                                }
                            } else {
                                badgeContent = .text(inset: 0.0, backgroundColor: mediaBadgeBackgroundColor, foregroundColor: mediaBadgeTextColor, text: NSAttributedString(string: durationString))
                            }
                            
                            strongSelf.mediaBadgeNode.update(theme: nil, content: badgeContent, mediaDownloadState: mediaDownloadState, alignment: .right, animated: false, badgeAnimated: false)
                        }
                    }
                }))
                if self.statusNode.supernode == nil {
                    self.imageNode.addSubnode(self.statusNode)
                }
            } else {
                self.mediaBadgeNode.isHidden = true
            }
            self.item = (item, media, size, mediaDimensions)
            
            self.updateHiddenMedia()
        } else {
            if let placeholderNode = self.placeholderNode, placeholderNode.supernode == nil {
                self.containerNode.insertSubnode(placeholderNode, at: 0)
            }
        }
        
        let progressDiameter: CGFloat = 40.0
        self.statusNode.frame = CGRect(origin: CGPoint(x: floor((size.width - progressDiameter) / 2.0), y: floor((size.height - progressDiameter) / 2.0)), size: CGSize(width: progressDiameter, height: progressDiameter))
        
        self.mediaBadgeNode.frame = CGRect(origin: CGPoint(x: size.width - 3.0, y: size.height - 18.0 - 3.0), size: CGSize(width: 50.0, height: 50.0))
        
        self.selectionNode?.frame = CGRect(origin: CGPoint(), size: size)
        
        if let (item, media, _, mediaDimensions) = self.item {
            self.item = (item, media, size, mediaDimensions)
            
            let imageFrame = CGRect(origin: CGPoint(), size: size)
            
            self.containerNode.frame = imageFrame
            self.imageNode.frame = imageFrame
            if let sampleBufferLayer = self.sampleBufferLayer {
                sampleBufferLayer.layer.frame = imageFrame
            }
            
            if let mediaDimensions = mediaDimensions {
                let imageSize = mediaDimensions.aspectFilled(imageFrame.size)
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets(), emptyColor: theme.list.mediaPlaceholderColor))()
            }
            
            self.updateSelectionState(animated: false)
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        self.hasVisibility = isVisible
        if let _ = self.videoLayerFrameManager {
            let displayLink: ConstantDisplayLinkAnimator
            if let current = self.displayLink {
                displayLink = current
            } else {
                displayLink = ConstantDisplayLinkAnimator { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.videoLayerFrameManager?.tick(timestamp: strongSelf.displayLinkTimestamp)
                    strongSelf.displayLinkTimestamp += 1.0 / 30.0
                }
                displayLink.frameInterval = 2
                self.displayLink = displayLink
            }
        }
        self.displayLink?.isPaused = !self.hasVisibility || self.isHidden
        
        /*if isVisible {
            if let item = self.item?.0, let file = self.item?.1 as? TelegramMediaFile, !file.isAnimated {
                if self.frameSequenceThumbnailNode == nil {
                    let frameSequenceThumbnailNode = FrameSequenceThumbnailNode(context: context, file: .message(message: MessageReference(item.message), media: file))
                    self.frameSequenceThumbnailNode = frameSequenceThumbnailNode
                    self.imageNode.addSubnode(frameSequenceThumbnailNode)
                }
                if let frameSequenceThumbnailNode = self.frameSequenceThumbnailNode {
                    let size = self.bounds.size
                    frameSequenceThumbnailNode.frame = CGRect(origin: CGPoint(), size: size)
                    frameSequenceThumbnailNode.updateLayout(size: size)
                }
            } else {
                if let frameSequenceThumbnailNode = self.frameSequenceThumbnailNode {
                    self.frameSequenceThumbnailNode = nil
                    frameSequenceThumbnailNode.removeFromSupernode()
                }
            }
        } else {
            if let frameSequenceThumbnailNode = self.frameSequenceThumbnailNode {
                self.frameSequenceThumbnailNode = nil
                frameSequenceThumbnailNode.removeFromSupernode()
            }
        }*/
        
        self.frameSequenceThumbnailNode?.updateIsPlaying(isVisible)
    }
    
    func tick() {
        self.frameSequenceThumbnailNode?.tick()
    }
    
    func updateSelectionState(animated: Bool) {
        if let (item, _, _, _) = self.item, let message = item.message, let theme = self.theme {
            self.containerNode.isGestureEnabled = self.interaction.selectedMessageIds == nil
            
            if let selectedIds = self.interaction.selectedMessageIds {
                let selected = selectedIds.contains(message.id)
                
                if let selectionNode = self.selectionNode {
                    selectionNode.updateSelected(selected, animated: animated)
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                } else {
                    let selectionNode = GridMessageSelectionNode(theme: theme, toggle: { [weak self] value in
                        if let strongSelf = self, let messageId = strongSelf.item?.0.message?.id {
                            var toggledValue = true
                            if let selectedMessageIds = strongSelf.interaction.selectedMessageIds, selectedMessageIds.contains(messageId) {
                                toggledValue = false
                            }
                            strongSelf.interaction.toggleSelection(messageId, toggledValue)
                        }
                    })
                    
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                    self.containerNode.addSubnode(selectionNode)
                    self.selectionNode = selectionNode
                    selectionNode.updateSelected(selected, animated: false)
                    if animated {
                        selectionNode.animateIn()
                    }
                }
            } else {
                if let selectionNode = self.selectionNode {
                    self.selectionNode = nil
                    if animated {
                        selectionNode.animateOut { [weak selectionNode] in
                            selectionNode?.removeFromSupernode()
                        }
                    } else {
                        selectionNode.removeFromSupernode()
                    }
                }
            }
        }
    }
    
    func transitionNode() -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        let imageNode = self.imageNode
        return (self.imageNode, self.imageNode.bounds, { [weak self, weak imageNode] in
            var statusNodeHidden = false
            var accessoryHidden = false
            if let strongSelf = self {
                statusNodeHidden = strongSelf.statusNode.isHidden
                accessoryHidden = strongSelf.mediaBadgeNode.isHidden
                strongSelf.statusNode.isHidden = true
                strongSelf.mediaBadgeNode.isHidden = true
            }
            let view = imageNode?.view.snapshotView(afterScreenUpdates: false)
            if let strongSelf = self {
                strongSelf.statusNode.isHidden = statusNodeHidden
                strongSelf.mediaBadgeNode.isHidden = accessoryHidden
            }
            return (view, nil)
        })
    }
    
    func updateHiddenMedia() {
        if let (item, _, _, _) = self.item {
            if let _ = self.interaction.hiddenMedia[item.id] {
                self.isHidden = true
            } else {
                self.isHidden = false
            }
        } else {
            self.isHidden = false
        }
        self.displayLink?.isPaused = !self.hasVisibility || self.isHidden
    }
}
*/

private final class VisualMediaHoleAnchor: SparseItemGrid.HoleAnchor {
    let messageId: MessageId
    override var id: AnyHashable {
        return AnyHashable(self.messageId)
    }

    let indexValue: Int
    override var index: Int {
        return self.indexValue
    }

    let timestamp: Int32
    override var tag: Int32 {
        return self.timestamp
    }

    init(index: Int, messageId: MessageId, timestamp: Int32) {
        self.indexValue = index
        self.messageId = messageId
        self.timestamp = timestamp
    }
}

private final class VisualMediaItem: SparseItemGrid.Item {
    let indexValue: Int
    override var index: Int {
        return self.indexValue
    }
    let timestamp: Int32
    let message: Message?
    let isLocal: Bool

    enum StableId: Hashable {
        case message(UInt32)
        case placeholder(MessageId)
        case hole(UInt32)
    }

    var stableId: StableId {
        if let message = self.message {
            return .message(message.stableId)
        } else {
            preconditionFailure()
            //return .placeholder(self.id)
        }
    }

    override var id: AnyHashable {
        return AnyHashable(self.stableId)
    }

    override var tag: Int32 {
        return self.timestamp
    }
    
    init(index: Int, message: Message, isLocal: Bool) {
        self.indexValue = index
        self.message = message
        self.timestamp = message.timestamp
        self.isLocal = isLocal
    }
}

private final class NullActionClass: NSObject, CAAction {
    @objc func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

private let nullAction = NullActionClass()

private final class ItemLayer: CALayer, SparseItemGridLayer {
    var item: VisualMediaItem?
    var shimmerLayer: SparseItemGrid.ShimmerLayer?
    var disposable: Disposable?

    override init() {
        super.init()

        self.contentsGravity = .resize
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable?.dispose()
    }

    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }

    func bind(item: VisualMediaItem) {
        self.item = item

        /*if self.contents == nil, let message = item.message {
            self.backgroundColor = UIColor(rgb: UInt32(clamping: UInt(bitPattern: String("\(message.id)").hashValue) & 0xffffffff)).cgColor
        }*/

        self.updateShimmerLayer()
    }

    func updateShimmerLayer() {
        if self.contents == nil {
            if self.shimmerLayer == nil {
                let shimmerLayer = SparseItemGrid.ShimmerLayer()
                self.shimmerLayer = shimmerLayer
                shimmerLayer.frame = self.bounds
                self.addSublayer(shimmerLayer)
            }
        } else if let shimmerLayer = self.shimmerLayer {
            self.shimmerLayer = nil
            shimmerLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak shimmerLayer] _ in
                shimmerLayer?.removeFromSuperlayer()
            })
        }
    }

    func unbind() {
        self.item = nil
    }

    func update(size: CGSize) {
        if let shimmerLayer = self.shimmerLayer {
            shimmerLayer.frame = CGRect(origin: CGPoint(), size: size)
        }
        /*var dimensions: CGSize?

        if let item = self.item, let message = item.message {
            for media in message.media {
                if let image = media as? TelegramMediaImage, let representation = image.representations.last {
                    dimensions = representation.dimensions.cgSize
                } else if let file = media as? TelegramMediaFile {
                    dimensions = file.dimensions?.cgSize ?? CGSize(width: 640.0, height: 480.0)
                }
            }
        }

        if let dimensions = dimensions {
            let scaledSize = dimensions.aspectFilled(size)
            let scaledRect = CGRect(origin: CGPoint(x: (size.width - scaledSize.width) / 2.0, y: (size.height - scaledSize.height) / 2.0), size: scaledSize)
            self.contentsRect = CGRect(origin: CGPoint(x: scaledRect.minX / size.width, y: scaledRect.minY / size.height), size: CGSize(width: scaledRect.width / size.width, height: scaledRect.height / size.height))
        } else {
            self.contentsRect = CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0))
        }*/
    }
}

private final class SparseItemGridBindingImpl: SparseItemGridBinding {
    private let context: AccountContext
    private let directMediaImageCache: DirectMediaImageCache
    private let strings: PresentationStrings

    var loadHoleImpl: ((SparseItemGrid.HoleAnchor, SparseItemGrid.HoleLocation) -> Signal<Never, NoError>)?
    var onTapImpl: ((VisualMediaItem) -> Void)?
    var onTagTapImpl: (() -> Void)?
    var didScrollImpl: (() -> Void)?

    init(context: AccountContext, directMediaImageCache: DirectMediaImageCache) {
        self.context = context
        self.directMediaImageCache = directMediaImageCache
        self.strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
    }

    func createLayer() -> SparseItemGridLayer {
        return ItemLayer()
    }

    func bindLayers(items: [SparseItemGrid.Item], layers: [SparseItemGridLayer]) {
        for i in 0 ..< items.count {
            guard let item = items[i] as? VisualMediaItem, let layer = layers[i] as? ItemLayer else {
                continue
            }
            if layer.bounds.isEmpty {
                continue
            }

            let imageWidthSpec: Int
            if layer.bounds.width <= 50 {
                imageWidthSpec = 64
            } else if layer.bounds.width <= 100 {
                imageWidthSpec = 150
            } else if layer.bounds.width <= 140 {
                imageWidthSpec = 200
            } else {
                imageWidthSpec = 280
            }

            if let message = item.message {
                var selectedMedia: Media?
                for media in message.media {
                    if let image = media as? TelegramMediaImage {
                        selectedMedia = image
                        break
                    } else if let file = media as? TelegramMediaFile {
                        selectedMedia = file
                        break
                    }
                }
                if let selectedMedia = selectedMedia {
                    if let result = directMediaImageCache.getImage(message: message, media: selectedMedia, width: imageWidthSpec) {
                        layer.contents = result.image?.cgImage
                        if let loadSignal = result.loadSignal {
                            layer.disposable = (loadSignal
                            |> deliverOnMainQueue).start(next: { [weak layer] image in
                                guard let layer = layer else {
                                    return
                                }
                                layer.contents = image?.cgImage
                                layer.updateShimmerLayer()
                            })
                        }
                    }
                }
            }

            layer.bind(item: item)
        }
    }

    func unbindLayer(layer: SparseItemGridLayer) {
        guard let layer = layer as? ItemLayer else {
            return
        }
        layer.unbind()
    }

    func scrollerTextForTag(tag: Int32) -> String? {
        let (year, month) = listMessageDateHeaderInfo(timestamp: tag)
        return stringForMonth(strings: self.strings, month: month, ofYear: year)
    }

    func loadHole(anchor: SparseItemGrid.HoleAnchor, at location: SparseItemGrid.HoleLocation) -> Signal<Never, NoError> {
        if let loadHoleImpl = self.loadHoleImpl {
            return loadHoleImpl(anchor, location)
        } else {
            return .never()
        }
    }

    func onTap(item: SparseItemGrid.Item) {
        guard let item = item as? VisualMediaItem else {
            return
        }
        self.onTapImpl?(item)
    }

    func onTagTap() {
        self.onTagTapImpl?()
    }

    func didScroll() {
        self.didScrollImpl?()
    }
}

/*private struct VisualMediaItemCollection {
    var items: [VisualMediaItem]
    var totalCount: Int

    func item(at index: Int) -> VisualMediaItem? {
        func binarySearch<A, T: Comparable>(_ inputArr: [A], extract: (A) -> T, searchItem: T) -> Int? {
            var lowerIndex = 0
            var upperIndex = inputArr.count - 1

            if lowerIndex > upperIndex {
                return nil
            }

            while true {
                let currentIndex = (lowerIndex + upperIndex) / 2
                let value = extract(inputArr[currentIndex])

                if value == searchItem {
                    return currentIndex
                } else if lowerIndex > upperIndex {
                    return nil
                } else {
                    if (value > searchItem) {
                        upperIndex = currentIndex - 1
                    } else {
                        lowerIndex = currentIndex + 1
                    }
                }
            }
        }

        if let itemIndex = binarySearch(self.items, extract: \.index, searchItem: index) {
            return self.items[itemIndex]
        }
        return nil
    }

    func closestHole(at index: Int) -> (anchor: MessageId, direction: SparseMessageList.LoadHoleDirection)? {
        var minDistance: Int?
        for i in 0 ..< self.items.count {
            if self.items[i].isLocal {
                continue
            }
            if let minDistanceValue = minDistance {
                if abs(self.items[i].index - index) < abs(self.items[minDistanceValue].index - index) {
                    minDistance = i
                }
            } else {
                minDistance = i
            }
        }
        if let minDistance = minDistance {
            let distance = index - self.items[minDistance].index
            if abs(distance) <= 2 {
                return (self.items[minDistance].id, .around)
            } else if distance < 0 {
                return (self.items[minDistance].id, .earlier)
            } else {
                return (self.items[minDistance].id, .later)
            }
        }
        return nil
    }

    func closestItem(at index: Int) -> VisualMediaItem? {
        if let item = self.item(at: index) {
            return item
        }
        var minDistance: Int?
        for i in 0 ..< self.items.count {
            if self.items[i].isLocal {
                continue
            }
            if let minDistanceValue = minDistance {
                if abs(self.items[i].index - index) < abs(self.items[minDistanceValue].index - index) {
                    minDistance = i
                }
            } else {
                minDistance = i
            }
        }
        if let minDistance = minDistance {
            return self.items[minDistance]
        } else {
            return nil
        }
    }
}*/

private func tagMaskForType(_ type: PeerInfoVisualMediaPaneNode.ContentType) -> MessageTags {
    switch type {
    case .photoOrVideo:
        return .photoOrVideo
    case .photo:
        return .photo
    case .video:
        return .video
    case .gifs:
        return .gif
    }
}

/*private enum ItemsLayout {
    final class Grid {
        let containerWidth: CGFloat
        let itemCount: Int
        let itemSpacing: CGFloat
        let itemsInRow: Int
        let itemSize: CGFloat
        let rowCount: Int
        let contentHeight: CGFloat
        
        init(containerWidth: CGFloat, zoomLevel: PeerInfoVisualMediaPaneNode.ZoomLevel, itemCount: Int, bottomInset: CGFloat) {
            self.containerWidth = containerWidth
            self.itemCount = itemCount
            self.itemSpacing = 1.0
            let minItemsInRow: Int
            let maxItemsInRow: Int
            switch zoomLevel {
            case .level2:
                minItemsInRow = 2
                maxItemsInRow = 4
            case .level3:
                minItemsInRow = 3
                maxItemsInRow = 6
            case .level4:
                minItemsInRow = 4
                maxItemsInRow = 8
            case .level5:
                minItemsInRow = 5
                maxItemsInRow = 10
            }
            self.itemsInRow = max(minItemsInRow, min(maxItemsInRow, Int(containerWidth / 140.0)))
            self.itemSize = floor(containerWidth / CGFloat(itemsInRow))
            
            self.rowCount = itemCount / self.itemsInRow + (itemCount % self.itemsInRow == 0 ? 0 : 1)
            
            self.contentHeight = CGFloat(self.rowCount + 1) * self.itemSpacing + CGFloat(rowCount) * itemSize + bottomInset
        }
        
        func visibleRange(rect: CGRect) -> (Int, Int) {
            var minVisibleRow = Int(floor((rect.minY - self.itemSpacing) / (self.itemSize + self.itemSpacing)))
            minVisibleRow = max(0, minVisibleRow)
            var maxVisibleRow = Int(ceil((rect.maxY - self.itemSpacing) / (self.itemSize + itemSpacing)))
            maxVisibleRow = min(self.rowCount - 1, maxVisibleRow)
            
            let minVisibleIndex = minVisibleRow * itemsInRow
            let maxVisibleIndex = min(self.itemCount - 1, (maxVisibleRow + 1) * itemsInRow - 1)
            
            return (minVisibleIndex, maxVisibleIndex)
        }
        
        func frame(forItemAt index: Int, sideInset: CGFloat) -> CGRect {
            let rowIndex = index / Int(self.itemsInRow)
            let columnIndex = index % Int(self.itemsInRow)
            let itemOrigin = CGPoint(x: sideInset + CGFloat(columnIndex) * (self.itemSize + self.itemSpacing), y: self.itemSpacing + CGFloat(rowIndex) * (self.itemSize + self.itemSpacing))
            return CGRect(origin: itemOrigin, size: CGSize(width: columnIndex == self.itemsInRow ? (self.containerWidth - itemOrigin.x) : self.itemSize, height: self.itemSize))
        }
    }
    
    case grid(Grid)
    
    var contentHeight: CGFloat {
        switch self {
        case let .grid(grid):
            return grid.contentHeight
        }
    }
    
    func visibleRange(rect: CGRect) -> (Int, Int) {
        switch self {
        case let .grid(grid):
            return grid.visibleRange(rect: rect)
        }
    }
    
    func frame(forItemAt index: Int, sideInset: CGFloat) -> CGRect {
        switch self {
        case let .grid(grid):
            return grid.frame(forItemAt: index, sideInset: sideInset)
        }
    }
}*/

final class PeerInfoVisualMediaPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate {
    enum ContentType {
        case photoOrVideo
        case photo
        case video
        case gifs
    }

    struct ZoomLevel {
        fileprivate var value: SparseItemGrid.ZoomLevel

        init(_ value: SparseItemGrid.ZoomLevel) {
            self.value = value
        }
    }
    
    private let context: AccountContext
    private let peerId: PeerId
    private let chatControllerInteraction: ChatControllerInteraction
    private(set) var contentType: ContentType
    private var contentTypePromise: ValuePromise<ContentType>
    
    weak var parentController: ViewController?

    private let scrollingArea: SparseItemGridScrollingArea
    //private let scrollNode: ASScrollNode
    private let itemGrid: SparseItemGrid
    private let itemGridBinding: SparseItemGridBindingImpl
    private let directMediaImageCache: DirectMediaImageCache
    private var items: SparseItemGrid.Items?

    private var isDeceleratingAfterTracking = false
    
    private var _itemInteraction: VisualMediaItemInteraction?
    private var itemInteraction: VisualMediaItemInteraction {
        return self._itemInteraction!
    }
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    private let statusPromise = Promise<PeerInfoStatusData?>(nil)
    var status: Signal<PeerInfoStatusData?, NoError> {
        self.statusPromise.get()
    }
        
    private let listDisposable = MetaDisposable()
    private var hiddenMediaDisposable: Disposable?
    //private var mediaItems = VisualMediaItemCollection(items: [], totalCount: 0)
    //private var itemsLayout: ItemsLayout?
    //private var visibleMediaItems: [VisualMediaItem.StableId: VisualMediaItemNode] = [:]
    
    private var numberOfItemsToRequest: Int = 50
    //private var currentView: MessageHistoryView?
    private var isRequestingView: Bool = false
    private var isFirstHistoryView: Bool = true
    
    private var decelerationAnimator: ConstantDisplayLinkAnimator?
    
    private var animationTimer: SwiftSignalKit.Timer?

    private var listSource: SparseMessageList
    private var requestedPlaceholderIds = Set<MessageId>()

    var openCurrentDate: (() -> Void)?
    var paneDidScroll: (() -> Void)?
    
    init(context: AccountContext, chatControllerInteraction: ChatControllerInteraction, peerId: PeerId, contentType: ContentType) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        self.contentType = contentType
        self.contentTypePromise = ValuePromise<ContentType>(contentType)

        self.scrollingArea = SparseItemGridScrollingArea()
        //self.scrollNode = ASScrollNode()
        self.itemGrid = SparseItemGrid()
        self.directMediaImageCache = DirectMediaImageCache(account: context.account)
        self.itemGridBinding = SparseItemGridBindingImpl(context: context, directMediaImageCache: self.directMediaImageCache)

        self.listSource = self.context.engine.messages.sparseMessageList(peerId: self.peerId, tag: tagMaskForType(self.contentType))
        
        super.init()

        self.itemGridBinding.loadHoleImpl = { [weak self] hole, location in
            guard let strongSelf = self else {
                return .never()
            }
            return strongSelf.loadHole(anchor: hole, at: location)
        }

        self.itemGridBinding.onTapImpl = { [weak self] item in
            guard let strongSelf = self else {
                return
            }
            guard let message = item.message else {
                return
            }
            let _ = strongSelf.chatControllerInteraction.openMessage(message, .default)
        }

        self.itemGridBinding.onTagTapImpl = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openCurrentDate?()
        }

        self.itemGridBinding.didScrollImpl = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.paneDidScroll?()
        }

        /*self.scrollingArea.beginScrolling = { [weak self] in
            guard let strongSelf = self else {
                return nil
            }
            return strongSelf.scrollNode.view
        }

        self.scrollingArea.openCurrentDate = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openCurrentDate?()
        }*/
        
        self._itemInteraction = VisualMediaItemInteraction(
            openMessage: { [weak self] message in
                let _ = self?.chatControllerInteraction.openMessage(message, .default)
            },
            openMessageContextActions: { [weak self] message, sourceNode, sourceRect, gesture in
                self?.chatControllerInteraction.openMessageContextActions(message, sourceNode, sourceRect, gesture)
            },
            toggleSelection: { [weak self] id, value in
                self?.chatControllerInteraction.toggleMessagesSelection([id], value)
            }
        )
        self.itemInteraction.selectedMessageIds = chatControllerInteraction.selectionState.flatMap { $0.selectedIds }
        
        /*self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delegate = self
        
        self.addSubnode(self.scrollNode)
        self.addSubnode(self.scrollingArea)*/

        self.addSubnode(self.itemGrid)
        
        self.requestHistoryAroundVisiblePosition(synchronous: false, reloadAtTop: false)
        
        self.hiddenMediaDisposable = context.sharedContext.mediaManager.galleryHiddenMediaManager.hiddenIds().start(next: { [weak self] ids in
            guard let strongSelf = self else {
                return
            }
            var hiddenMedia: [MessageId: [Media]] = [:]
            for id in ids {
                if case let .chat(accountId, messageId, media) = id, accountId == strongSelf.context.account.id {
                    hiddenMedia[messageId] = [media]
                }
            }
            strongSelf.itemInteraction.hiddenMedia = hiddenMedia
            strongSelf.updateHiddenMedia()
        })
        
        /*let animationTimer = SwiftSignalKit.Timer(timeout: 0.3, repeat: true, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            for (_, itemNode) in strongSelf.visibleMediaItems {
                itemNode.tick()
            }
        }, queue: .mainQueue())
        self.animationTimer = animationTimer
        animationTimer.start()*/

        self.statusPromise.set((self.contentTypePromise.get()
        |> distinctUntilChanged
        |> mapToSignal { contentType -> Signal<(ContentType, [MessageTags: Int32]), NoError> in
            var summaries: [MessageTags] = []
            switch contentType {
            case .photoOrVideo:
                summaries.append(.photo)
                summaries.append(.video)
            case .photo:
                summaries.append(.photo)
            case .video:
                summaries.append(.video)
            case .gifs:
                summaries.append(.gif)
            }
            return context.account.postbox.combinedView(keys: summaries.map { tag in
                return PostboxViewKey.historyTagSummaryView(tag: tag, peerId: peerId, namespace: Namespaces.Message.Cloud)
            })
            |> map { views -> (ContentType, [MessageTags: Int32]) in
                switch contentType {
                case .photoOrVideo:
                    summaries.append(.photo)
                    summaries.append(.video)
                case .photo:
                    summaries.append(.photo)
                case .video:
                    summaries.append(.video)
                case .gifs:
                    summaries.append(.gif)
                }
                var result: [MessageTags: Int32] = [:]
                for tag in summaries {
                    if let view = views.views[PostboxViewKey.historyTagSummaryView(tag: tag, peerId: peerId, namespace: Namespaces.Message.Cloud)] as? MessageHistoryTagSummaryView {
                        result[tag] = view.count ?? 0
                    } else {
                        result[tag] = 0
                    }
                }
                return (contentType, result)
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.0 != rhs.0 {
                return false
            }
            if lhs.1 != rhs.1 {
                return false
            }
            return true
        })
        |> map { contentType, dict -> PeerInfoStatusData? in
            switch contentType {
            case .photoOrVideo:
                let photoCount: Int32 = dict[.photo] ?? 0
                let videoCount: Int32 = dict[.video] ?? 0

                //TODO:localize
                if photoCount != 0 && videoCount != 0 {
                    return PeerInfoStatusData(text: "\(photoCount) photos, \(videoCount) videos", isActivity: false)
                } else if photoCount != 0 {
                    return PeerInfoStatusData(text: "\(photoCount) photos", isActivity: false)
                } else if videoCount != 0 {
                    return PeerInfoStatusData(text: "\(photoCount) videos", isActivity: false)
                } else {
                    return nil
                }
            case .photo:
                let photoCount: Int32 = dict[.photo] ?? 0

                //TODO:localize
                if photoCount != 0 {
                    return PeerInfoStatusData(text: "\(photoCount) photos", isActivity: false)
                } else {
                    return nil
                }
            case .video:
                let videoCount: Int32 = dict[.video] ?? 0

                //TODO:localize
                if videoCount != 0 {
                    return PeerInfoStatusData(text: "\(videoCount) videos", isActivity: false)
                } else {
                    return nil
                }
            case .gifs:
                let gifCount: Int32 = dict[.gif] ?? 0

                //TODO:localize
                if gifCount != 0 {
                    return PeerInfoStatusData(text: "\(gifCount) gifs", isActivity: false)
                } else {
                    return nil
                }
            }
        }))
    }
    
    deinit {
        self.listDisposable.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.animationTimer?.invalidate()
    }

    func loadHole(anchor: SparseItemGrid.HoleAnchor, at location: SparseItemGrid.HoleLocation) -> Signal<Never, NoError> {
        guard let anchor = anchor as? VisualMediaHoleAnchor else {
            return .never()
        }
        let mappedDirection: SparseMessageList.LoadHoleDirection
        switch location {
        case .around:
            mappedDirection = .around
        case .toLower:
            mappedDirection = .later
        case .toUpper:
            mappedDirection = .earlier
        }
        let listSource = self.listSource
        return Signal { subscriber in
            listSource.loadHole(anchor: anchor.messageId, direction: mappedDirection, completion: {
                subscriber.putCompletion()
            })

            return EmptyDisposable
        }
    }

    func updateContentType(contentType: ContentType) {
        if self.contentType == contentType {
            return
        }
        self.contentType = contentType
        self.contentTypePromise.set(contentType)

        self.listSource = self.context.engine.messages.sparseMessageList(peerId: self.peerId, tag: tagMaskForType(self.contentType))
        self.isRequestingView = false
        self.requestHistoryAroundVisiblePosition(synchronous: true, reloadAtTop: true)
    }

    func updateZoomLevel(level: ZoomLevel) {
        self.itemGrid.setZoomLevel(level: level.value)

        /*if let (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData) = self.currentParams {

            var currentTopVisibleItemFrame: CGRect?
            if let itemsLayout = self.itemsLayout {
                let headerItemMinY = self.scrollNode.view.bounds.minY + 1.0
                let (minVisibleIndex, maxVisibleIndex) = itemsLayout.visibleRange(rect: self.scrollNode.view.bounds)

                if minVisibleIndex <= maxVisibleIndex {
                    for i in minVisibleIndex ... maxVisibleIndex {
                        let itemFrame = itemsLayout.frame(forItemAt: i, sideInset: sideInset)

                        if currentTopVisibleItemFrame == nil && itemFrame.maxY > headerItemMinY {
                            currentTopVisibleItemFrame = self.scrollNode.view.convert(itemFrame, to: self.view)
                            break
                        }
                    }
                }
            }

            self.itemsLayout = nil

            let copyView = self.scrollNode.view.snapshotView(afterScreenUpdates: false)

            self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expandProgress, presentationData: presentationData, synchronous: false, transition: .immediate)

            var updatedTopVisibleItemFrame: CGRect?
            if let itemsLayout = self.itemsLayout {
                let headerItemMinY = self.scrollNode.view.bounds.minY + 1.0
                let (updatedMinVisibleIndex, updatedMaxVisibleIndex) = itemsLayout.visibleRange(rect: self.scrollNode.view.bounds)

                if updatedMinVisibleIndex <= updatedMaxVisibleIndex {
                    for i in updatedMinVisibleIndex ... updatedMaxVisibleIndex {
                        let itemFrame = itemsLayout.frame(forItemAt: i, sideInset: sideInset)

                        if updatedTopVisibleItemFrame == nil && itemFrame.maxY > headerItemMinY {
                            updatedTopVisibleItemFrame = self.scrollNode.view.convert(itemFrame, to: self.view)
                            break
                        }
                    }
                }
            }

            if let copyView = copyView, let currentTopVisibleItemFrame = currentTopVisibleItemFrame, let updatedTopVisibleItemFrame = updatedTopVisibleItemFrame {
                self.view.addSubview(copyView)
                copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak copyView] _ in
                    copyView?.removeFromSuperview()
                })

                let additionalOffset = CGPoint(x: updatedTopVisibleItemFrame.minX - currentTopVisibleItemFrame.minX, y: updatedTopVisibleItemFrame.minY - currentTopVisibleItemFrame.minY)
                self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: self.scrollNode.view.contentOffset.y + additionalOffset.y), animated: false)

                let widthFactor = updatedTopVisibleItemFrame.width / currentTopVisibleItemFrame.width
                copyView.layer.animateScale(from: 1.0, to: widthFactor, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in })
                let copyOffset = CGPoint(x: -self.scrollNode.bounds.width * (1.0 - widthFactor) * 0.5, y: -self.scrollNode.bounds.height * (1.0 - widthFactor) * 0.5)//.offsetBy(dx: additionalOffset.x, dy: additionalOffset.y)
                copyView.layer.animatePosition(from: CGPoint(), to: copyOffset, duration: 0.2, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)

                self.scrollNode.layer.animateScale(from: 1.0 / widthFactor, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: true)
                let originalOffset = CGPoint(x: -self.scrollNode.bounds.width * (1.0 - 1.0 / widthFactor) * 0.5, y: -self.scrollNode.bounds.height * (1.0 - 1.0 / widthFactor) * 0.5)//.offsetBy(dx: additionalOffset.x, dy: additionalOffset.y)
                self.scrollNode.layer.animatePosition(from: originalOffset, to: CGPoint(), duration: 0.2, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: true, additive: true)
            }
        }*/
    }
    
    func ensureMessageIsVisible(id: MessageId) {
        /*let activeRect = self.scrollNode.bounds
        for item in self.mediaItems.items {
            if let message = item.message, message.id == id {
                if let itemNode = self.visibleMediaItems[item.stableId] {
                    if !activeRect.contains(itemNode.frame) {
                        let targetContentOffset = CGPoint(x: 0.0, y: max(-self.scrollNode.view.contentInset.top, itemNode.frame.minY - (self.scrollNode.frame.height - itemNode.frame.height) / 2.0))
                        self.scrollNode.view.setContentOffset(targetContentOffset, animated: false)
                    }
                }
                break
            }
        }*/
    }
    
    private func requestHistoryAroundVisiblePosition(synchronous: Bool, reloadAtTop: Bool) {
        if self.isRequestingView {
            return
        }
        self.isRequestingView = true
        var firstTime = true
        self.listDisposable.set((self.listSource.state
        |> deliverOnMainQueue).start(next: { [weak self] list in
            guard let strongSelf = self else {
                return
            }
            let currentSynchronous = synchronous && firstTime
            let currentReloadAtTop = reloadAtTop && firstTime
            firstTime = false
            strongSelf.updateHistory(list: list, synchronous: currentSynchronous, reloadAtTop: currentReloadAtTop)
            strongSelf.isRequestingView = false
        }))
    }
    
    private func updateHistory(list: SparseMessageList.State, synchronous: Bool, reloadAtTop: Bool) {
        var mappedItems: [SparseItemGrid.Item] = []
        var mappeHoles: [SparseItemGrid.HoleAnchor] = []
        for item in list.items {
            switch item.content {
            case let .message(message, isLocal):
                mappedItems.append(VisualMediaItem(index: item.index, message: message, isLocal: isLocal))
            case let .placeholder(id, timestamp):
                mappeHoles.append(VisualMediaHoleAnchor(index: item.index, messageId: id, timestamp: timestamp))
            }
        }

        self.items = SparseItemGrid.Items(
            items: mappedItems,
            holeAnchors: mappeHoles,
            count: list.totalCount,
            itemBinding: self.itemGridBinding
        )

        if let (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData) = self.currentParams {
            self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expandProgress, presentationData: presentationData, synchronous: false, transition: .immediate)
        }

        /*self.mediaItems = VisualMediaItemCollection(items: [], totalCount: list.totalCount)
        for item in list.items {
            switch item.content {
            case let .message(message, isLocal):
                self.mediaItems.items.append(VisualMediaItem(index: item.index, message: message, isLocal: isLocal))
            case let .placeholder(id, timestamp):
                self.mediaItems.items.append(VisualMediaItem(index: item.index, id: id, timestamp: timestamp))
            }
        }
        self.itemsLayout = nil

        let wasFirstHistoryView = self.isFirstHistoryView
        self.isFirstHistoryView = false

        if let (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData) = self.currentParams {
            if synchronous {
                if let copyView = self.scrollNode.view.snapshotView(afterScreenUpdates: false) {
                    copyView.backgroundColor = self.context.sharedContext.currentPresentationData.with({ $0 }).theme.list.plainBackgroundColor
                    self.view.addSubview(copyView)
                    copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak copyView] _ in
                        copyView?.removeFromSuperview()
                    })
                }
            }
            self.ignoreScrolling = true
            if reloadAtTop {
                self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
            }
            self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expandProgress, presentationData: presentationData, synchronous: wasFirstHistoryView || synchronous, transition: .immediate)
            self.ignoreScrolling = false
        }*/

        if !self.didSetReady {
            self.didSetReady = true
            self.ready.set(.single(true))
        }
    }
    
    func scrollToTop() -> Bool {
        /*if self.scrollNode.view.contentOffset.y > 0.0 {
            self.scrollNode.view.setContentOffset(CGPoint(), animated: true)
            return true
        } else {
            return false
        }*/
        return false
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        guard let items = self.items else {
            return nil
        }
        for item in items.items {
            guard let item = item as? VisualMediaItem else {
                continue
            }
            if let message = item.message, message.id == id {
                return item.message
            }
        }
        return nil
    }
    
    func updateHiddenMedia() {
        self.itemGrid.forEachVisibleItem { itemLayer in
            guard let itemLayer = itemLayer as? ItemLayer else {
                return
            }
            if let item = itemLayer.item, let message = item.message {
                if self.itemInteraction.hiddenMedia[message.id] != nil {
                    itemLayer.isHidden = true
                } else {
                    itemLayer.isHidden = false
                }
            } else {
                itemLayer.isHidden = false
            }
        }
    }
    
    func transferVelocity(_ velocity: CGFloat) {
        /*if velocity > 0.0 {
            self.decelerationAnimator?.isPaused = true
            let startTime = CACurrentMediaTime()
            var currentOffset = self.scrollNode.view.contentOffset
            let decelerationRate: CGFloat = 0.998
            self.scrollViewDidEndDragging(self.scrollNode.view, willDecelerate: true)
            self.decelerationAnimator = ConstantDisplayLinkAnimator(update: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let t = CACurrentMediaTime() - startTime
                var currentVelocity = velocity * 15.0 * CGFloat(pow(Double(decelerationRate), 1000.0 * t))
                currentOffset.y += currentVelocity
                let maxOffset = strongSelf.scrollNode.view.contentSize.height - strongSelf.scrollNode.bounds.height
                if currentOffset.y >= maxOffset {
                    currentOffset.y = maxOffset
                    currentVelocity = 0.0
                }
                if currentOffset.y < 0.0 {
                    currentOffset.y = 0.0
                    currentVelocity = 0.0
                }
                
                var didEnd = false
                if abs(currentVelocity) < 0.1 {
                    strongSelf.decelerationAnimator?.isPaused = true
                    strongSelf.decelerationAnimator = nil
                    didEnd = true
                }
                var contentOffset = strongSelf.scrollNode.view.contentOffset
                contentOffset.y = floorToScreenPixels(currentOffset.y)
                strongSelf.scrollNode.view.setContentOffset(contentOffset, animated: false)
                strongSelf.scrollViewDidScroll(strongSelf.scrollNode.view)
                if didEnd {
                    strongSelf.scrollViewDidEndDecelerating(strongSelf.scrollNode.view)
                }
            })
            self.decelerationAnimator?.isPaused = false
        }*/
    }
    
    func cancelPreviewGestures() {
        /*for (_, itemNode) in self.visibleMediaItems {
            itemNode.cancelPreviewGesture()
        }*/
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        var foundItemLayer: SparseItemGridLayer?
        self.itemGrid.forEachVisibleItem { itemLayer in
            guard let itemLayer = itemLayer as? ItemLayer else {
                return
            }
            if let item = itemLayer.item, let message = item.message, message.id == messageId {
                foundItemLayer = itemLayer
            }
        }
        if let itemLayer = foundItemLayer {
            let itemFrame = self.view.convert(self.itemGrid.frameForItem(layer: itemLayer), from: self.itemGrid.view)
            let proxyNode = ASDisplayNode()
            proxyNode.frame = itemFrame
            proxyNode.contents = itemLayer.contents
            proxyNode.isHidden = true
            self.addSubnode(proxyNode)

            let escapeNotification = EscapeNotification {
                proxyNode.removeFromSupernode()
            }

            return (proxyNode, proxyNode.bounds, {
                let view = UIView()
                view.frame = proxyNode.frame
                view.layer.contents = proxyNode.layer.contents
                escapeNotification.keep()
                return (view, nil)
            })
        }
        return nil
    }
    
    func addToTransitionSurface(view: UIView) {
        self.itemGrid.addToTransitionSurface(view: view)
    }
    
    func updateSelectedMessages(animated: Bool) {
        /*self.itemInteraction.selectedMessageIds = self.chatControllerInteraction.selectionState.flatMap { $0.selectedIds }
        for (_, itemNode) in self.visibleMediaItems {
            itemNode.updateSelectionState(animated: animated)
        }*/
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        //let previousParams = self.currentParams
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)

        transition.updateFrame(node: self.itemGrid, frame: CGRect(origin: CGPoint(), size: size))
        if let items = self.items {
            self.itemGrid.update(size: size, insets: UIEdgeInsets(top: 0.0, left: sideInset, bottom: bottomInset, right: sideInset), scrollIndicatorInsets: UIEdgeInsets(top: 0.0, left: sideInset, bottom: bottomInset, right: sideInset), lockScrollingAtTop: isScrollingLockedAtTop, items: items)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    }

    private var previousDidScrollTimestamp: Double = 0.0
    private var ignoreScrolling: Bool = false
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.ignoreScrolling {
            return
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    }

    private func updateScrollingArea(transition: ContainedViewLayoutTransition) {
    }

    func currentTopTimestamp() -> Int32? {
        var timestamp: Int32?
        self.itemGrid.forEachVisibleItem { itemLayer in
            if timestamp != nil {
                return
            }
            guard let itemLayer = itemLayer as? ItemLayer else {
                return
            }
            if let item = itemLayer.item, let message = item.message {
                if let timestampValue = timestamp {
                    timestamp = max(timestampValue, message.timestamp)
                } else {
                    timestamp = message.timestamp
                }
            }
        }
        return timestamp
    }

    func scrollToTimestamp(timestamp: Int32) {
        if let items = self.items, !items.items.isEmpty {
            var previousIndex: Int?
            for item in items.items {
                guard let item = item as? VisualMediaItem, let message = item.message else {
                    continue
                }
                if message.timestamp <= timestamp {
                    break
                }
                previousIndex = item.index
            }
            if previousIndex == nil {
                previousIndex = (items.items[0] as? VisualMediaItem)?.index
            }
            if let index = previousIndex {
                self.itemGrid.scrollToItem(at: index)
            }
        }
        /*guard let currentParams = self.currentParams else {
            return
        }
        guard let itemsLayout = self.itemsLayout else {
            return
        }
        for item in self.mediaItems.items {
            if item.timestamp <= timestamp {
                let frame = itemsLayout.frame(forItemAt: item.index, sideInset: currentParams.sideInset)
                self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: frame.minY), animated: false)

                break
            }
        }*/
    }
    
    /*private func updateVisibleItems(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, theme: PresentationTheme, strings: PresentationStrings, synchronousLoad: Bool) {
        guard let itemsLayout = self.itemsLayout else {
            return
        }
        
        let activeRect = self.scrollNode.view.bounds
        let visibleRect = activeRect.insetBy(dx: 0.0, dy: -400.0)

        let (minActuallyVisibleIndex, maxActuallyVisibleIndex) = itemsLayout.visibleRange(rect: activeRect)
        let (minVisibleIndex, maxVisibleIndex) = itemsLayout.visibleRange(rect: visibleRect)

        var requestHole: (anchor: MessageId, direction: SparseMessageList.LoadHoleDirection)?
        
        var validIds = Set<VisualMediaItem.StableId>()
        if minVisibleIndex <= maxVisibleIndex {
            for itemIndex in minVisibleIndex ... maxVisibleIndex {
                let maybeItem = self.mediaItems.item(at: itemIndex)
                var findHole = false
                if let item = maybeItem {
                    if item.message == nil {
                        findHole = true
                    }
                } else {
                    findHole = true
                }
                if findHole {
                    if let hole = self.mediaItems.closestHole(at: itemIndex) {
                        if requestHole == nil {
                            requestHole = hole
                        }
                    }
                }

                let stableId: VisualMediaItem.StableId
                if let item = maybeItem {
                    stableId = item.stableId
                } else {
                    stableId = .hole(UInt32(itemIndex))
                }

                validIds.insert(stableId)
                
                let itemFrame = itemsLayout.frame(forItemAt: itemIndex, sideInset: sideInset)
                
                let itemNode: VisualMediaItemNode
                if let current = self.visibleMediaItems[stableId] {
                    itemNode = current
                } else {
                    itemNode = VisualMediaItemNode(context: self.context, interaction: self.itemInteraction)
                    self.visibleMediaItems[stableId] = itemNode
                    self.scrollNode.addSubnode(itemNode)
                }
                itemNode.frame = itemFrame
                itemNode.updateAbsoluteRect(itemFrame.offsetBy(dx: 0.0, dy: -activeRect.origin.y), within: activeRect.size)

                var itemSynchronousLoad = false
                if itemIndex >= minActuallyVisibleIndex && itemIndex <= maxActuallyVisibleIndex {
                    itemSynchronousLoad = synchronousLoad
                }
                itemNode.update(size: itemFrame.size, item: maybeItem, theme: theme, synchronousLoad: itemSynchronousLoad)
                itemNode.updateIsVisible(itemFrame.intersects(activeRect))
            }
        }
        var removeKeys: [VisualMediaItem.StableId] = []
        for (id, _) in self.visibleMediaItems {
            if !validIds.contains(id) {
                removeKeys.append(id)
            }
        }
        for id in removeKeys {
            if let itemNode = self.visibleMediaItems.removeValue(forKey: id) {
                itemNode.removeFromSupernode()
            }
        }
        
        if let requestHole = requestHole {
            self.listSource.loadHole(anchor: requestHole.anchor, direction: requestHole.direction)
        }
    }*/
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        /*if self.decelerationAnimator != nil {
            self.decelerationAnimator?.isPaused = true
            self.decelerationAnimator = nil
            
            return self.scrollNode.view
        }*/
        return result
    }

    func availableZoomLevels() -> (decrement: ZoomLevel?, increment: ZoomLevel?) {
        let levels = self.itemGrid.availableZoomLevels()
        return (levels.decrement.flatMap(ZoomLevel.init), levels.increment.flatMap(ZoomLevel.init))
    }
}
