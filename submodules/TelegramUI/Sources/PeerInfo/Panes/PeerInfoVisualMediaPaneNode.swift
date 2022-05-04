import AsyncDisplayKit
import AVFoundation
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
import TelegramNotices
import TelegramUIPreferences
import CheckNode
import AppBundle

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

    let localMonthTimestamp: Int32
    override var tag: Int32 {
        return self.localMonthTimestamp
    }

    init(index: Int, messageId: MessageId, localMonthTimestamp: Int32) {
        self.indexValue = index
        self.messageId = messageId
        self.localMonthTimestamp = localMonthTimestamp
    }
}

private final class VisualMediaItem: SparseItemGrid.Item {
    let indexValue: Int
    override var index: Int {
        return self.indexValue
    }
    let localMonthTimestamp: Int32
    let message: Message

    override var id: AnyHashable {
        return AnyHashable(self.message.stableId)
    }

    override var tag: Int32 {
        return self.localMonthTimestamp
    }

    override var holeAnchor: SparseItemGrid.HoleAnchor {
        return VisualMediaHoleAnchor(index: self.index, messageId: self.message.id, localMonthTimestamp: self.localMonthTimestamp)
    }
    
    init(index: Int, message: Message, localMonthTimestamp: Int32) {
        self.indexValue = index
        self.message = message
        self.localMonthTimestamp = localMonthTimestamp
    }
}

private struct Month: Equatable {
    var packedValue: Int32

    init(packedValue: Int32) {
        self.packedValue = packedValue
    }

    init(localTimestamp: Int32) {
        var time: time_t = time_t(localTimestamp)
        var timeinfo: tm = tm()
        gmtime_r(&time, &timeinfo)

        let year = UInt32(timeinfo.tm_year)
        let month = UInt32(timeinfo.tm_mon)

        self.packedValue = Int32(bitPattern: year | (month << 16))
    }

    var year: Int32 {
        return Int32(bitPattern: (UInt32(bitPattern: self.packedValue) >> 0) & 0xffff)
    }

    var month: Int32 {
        return Int32(bitPattern: (UInt32(bitPattern: self.packedValue) >> 16) & 0xffff)
    }
}

private let durationFont = Font.regular(12.0)
private let minDurationImage: UIImage = {
    let image = generateImage(CGSize(width: 20.0, height: 20.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(white: 0.0, alpha: 0.5).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        if let image = UIImage(bundleImageName: "Chat/GridPlayIcon") {
            UIGraphicsPushContext(context)
            image.draw(in: CGRect(origin: CGPoint(x: (size.width - image.size.width) / 2.0, y: (size.height - image.size.height) / 2.0), size: image.size))
            UIGraphicsPopContext()
        }
    })
    return image!
}()

private final class DurationLayer: CALayer {
    override init() {
        super.init()

        self.contentsGravity = .topRight
        self.contentsScale = UIScreenScale
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }

    func update(duration: Int32, isMin: Bool) {
        if isMin {
            self.contents = minDurationImage.cgImage
        } else {
            let string = NSAttributedString(string: stringForDuration(duration), font: durationFont, textColor: .white)
            let bounds = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
            let textSize = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
            let sideInset: CGFloat = 6.0
            let verticalInset: CGFloat = 2.0
            let image = generateImage(CGSize(width: textSize.width + sideInset * 2.0, height: textSize.height + verticalInset * 2.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))

                context.setFillColor(UIColor(white: 0.0, alpha: 0.5).cgColor)
                context.setBlendMode(.copy)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                context.fill(CGRect(origin: CGPoint(x: size.height / 2.0, y: 0.0), size: CGSize(width: size.width - size.height, height: size.height)))

                context.setBlendMode(.normal)
                UIGraphicsPushContext(context)
                string.draw(in: bounds.offsetBy(dx: sideInset, dy: verticalInset))
                UIGraphicsPopContext()
            })
            self.contents = image?.cgImage
        }
    }
}

private protocol ItemLayer: SparseItemGridLayer {
    var item: VisualMediaItem? { get set }
    var durationLayer: DurationLayer? { get set }
    var minFactor: CGFloat { get set }
    var selectionLayer: GridMessageSelectionLayer? { get set }
    var disposable: Disposable? { get set }

    var hasContents: Bool { get set }
    
    func updateDuration(duration: Int32?, isMin: Bool, minFactor: CGFloat)
    func updateSelection(theme: CheckNodeTheme, isSelected: Bool?, animated: Bool)
    
    func bind(item: VisualMediaItem)
    func unbind()
}

private final class GenericItemLayer: CALayer, ItemLayer {
    var item: VisualMediaItem?
    var durationLayer: DurationLayer?
    var minFactor: CGFloat = 1.0
    var selectionLayer: GridMessageSelectionLayer?
    var disposable: Disposable?

    var hasContents: Bool = false

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
    
    func getContents() -> Any? {
        return self.contents
    }
    
    func setContents(_ contents: Any?) {
        if let image = contents as? UIImage {
            self.contents = image.cgImage
        }
    }

    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }

    func bind(item: VisualMediaItem) {
        self.item = item
    }

    func updateDuration(duration: Int32?, isMin: Bool, minFactor: CGFloat) {
        self.minFactor = minFactor

        if let duration = duration {
            if let durationLayer = self.durationLayer {
                durationLayer.update(duration: duration, isMin: isMin)
            } else {
                let durationLayer = DurationLayer()
                durationLayer.update(duration: duration, isMin: isMin)
                self.addSublayer(durationLayer)
                durationLayer.frame = CGRect(origin: CGPoint(x: self.bounds.width - 3.0, y: self.bounds.height - 3.0), size: CGSize())
                durationLayer.transform = CATransform3DMakeScale(minFactor, minFactor, 1.0)
                self.durationLayer = durationLayer
            }
        } else if let durationLayer = self.durationLayer {
            self.durationLayer = nil
            durationLayer.removeFromSuperlayer()
        }
    }

    func updateSelection(theme: CheckNodeTheme, isSelected: Bool?, animated: Bool) {
        if let isSelected = isSelected {
            if let selectionLayer = self.selectionLayer {
                selectionLayer.updateSelected(isSelected, animated: animated)
            } else {
                let selectionLayer = GridMessageSelectionLayer(theme: theme)
                selectionLayer.updateSelected(isSelected, animated: false)
                self.selectionLayer = selectionLayer
                self.addSublayer(selectionLayer)
                if !self.bounds.isEmpty {
                    selectionLayer.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                    selectionLayer.updateLayout(size: self.bounds.size)
                    if animated {
                        selectionLayer.animateIn()
                    }
                }
            }
        } else if let selectionLayer = self.selectionLayer {
            self.selectionLayer = nil
            if animated {
                selectionLayer.animateOut { [weak selectionLayer] in
                    selectionLayer?.removeFromSuperlayer()
                }
            } else {
                selectionLayer.removeFromSuperlayer()
            }
        }
    }

    func unbind() {
        self.item = nil
    }

    func needsShimmer() -> Bool {
        return !self.hasContents
    }

    func update(size: CGSize) {
        /*if let durationLayer = self.durationLayer {
            durationLayer.frame = CGRect(origin: CGPoint(x: size.width - 3.0, y: size.height - 3.0), size: CGSize())
        }*/
    }
}

private final class CaptureProtectedItemLayer: AVSampleBufferDisplayLayer, ItemLayer {
    var item: VisualMediaItem?
    var durationLayer: DurationLayer?
    var minFactor: CGFloat = 1.0
    var selectionLayer: GridMessageSelectionLayer?
    var disposable: Disposable?

    var hasContents: Bool = false

    override init() {
        super.init()
        
        self.contentsGravity = .resize
        if #available(iOS 13.0, *) {
            self.preventsCapture = true
            self.preventsDisplaySleepDuringVideoPlayback = false
        }
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
    
    private var layerContents: Any?
    func getContents() -> Any? {
        return self.layerContents
    }
    
    func setContents(_ contents: Any?) {
        self.layerContents = contents
        
        if let image = contents as? UIImage {
            self.layerContents = image.cgImage
            if let cmSampleBuffer = image.cmSampleBuffer {
                self.enqueue(cmSampleBuffer)
            }
        }
    }

    func bind(item: VisualMediaItem) {
        self.item = item
    }
    
    func updateDuration(duration: Int32?, isMin: Bool, minFactor: CGFloat) {
        self.minFactor = minFactor

        if let duration = duration {
            if let durationLayer = self.durationLayer {
                durationLayer.update(duration: duration, isMin: isMin)
            } else {
                let durationLayer = DurationLayer()
                durationLayer.update(duration: duration, isMin: isMin)
                self.addSublayer(durationLayer)
                durationLayer.frame = CGRect(origin: CGPoint(x: self.bounds.width - 3.0, y: self.bounds.height - 3.0), size: CGSize())
                durationLayer.transform = CATransform3DMakeScale(minFactor, minFactor, 1.0)
                self.durationLayer = durationLayer
            }
        } else if let durationLayer = self.durationLayer {
            self.durationLayer = nil
            durationLayer.removeFromSuperlayer()
        }
    }

    func updateSelection(theme: CheckNodeTheme, isSelected: Bool?, animated: Bool) {
        if let isSelected = isSelected {
            if let selectionLayer = self.selectionLayer {
                selectionLayer.updateSelected(isSelected, animated: animated)
            } else {
                let selectionLayer = GridMessageSelectionLayer(theme: theme)
                selectionLayer.updateSelected(isSelected, animated: false)
                self.selectionLayer = selectionLayer
                self.addSublayer(selectionLayer)
                if !self.bounds.isEmpty {
                    selectionLayer.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                    selectionLayer.updateLayout(size: self.bounds.size)
                    if animated {
                        selectionLayer.animateIn()
                    }
                }
            }
        } else if let selectionLayer = self.selectionLayer {
            self.selectionLayer = nil
            if animated {
                selectionLayer.animateOut { [weak selectionLayer] in
                    selectionLayer?.removeFromSuperlayer()
                }
            } else {
                selectionLayer.removeFromSuperlayer()
            }
        }
    }

    func unbind() {
        self.item = nil
    }

    func needsShimmer() -> Bool {
        return !self.hasContents
    }

    func update(size: CGSize) {
        /*if let durationLayer = self.durationLayer {
            durationLayer.frame = CGRect(origin: CGPoint(x: size.width - 3.0, y: size.height - 3.0), size: CGSize())
        }*/
    }
}

private final class ItemView: UIView, SparseItemGridView {
    var item: VisualMediaItem?
    var disposable: Disposable?

    var messageItem: ListMessageItem?
    var messageItemNode: ListViewItemNode?
    var interaction: ListMessageItemInteraction?
    let buttonNode: HighlightTrackingButtonNode

    override init(frame: CGRect) {
        self.buttonNode = HighlightTrackingButtonNode()

        super.init(frame: frame)

        self.addSubnode(self.buttonNode)
        self.buttonNode.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)

        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            strongSelf.messageItemNode?.setHighlighted(highlighted, at: CGPoint(), animated: !highlighted)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable?.dispose()
    }

    @objc func pressed() {
        guard let itemNode = self.messageItemNode else {
            return
        }

        if let item = self.item, let messageItem = self.messageItem, let itemNode = itemNode as? ListMessageFileItemNode {
            if case let .selectable(selected) = messageItem.selection {
                self.interaction?.toggleMessagesSelection([item.message.id], !selected)
            } else {
                itemNode.activateMedia()
            }
        }
    }

    func bind(
        item: VisualMediaItem,
        presentationData: ChatPresentationData,
        context: AccountContext,
        chatLocation: ChatLocation,
        interaction: ListMessageItemInteraction,
        isSelected: Bool?,
        size: CGSize,
        insets: UIEdgeInsets
    ) {
        self.item = item
        self.interaction = interaction

        let messageItem = ListMessageItem(
            presentationData: presentationData,
            context: context,
            chatLocation: chatLocation,
            interaction: interaction,
            message: item.message,
            selection: isSelected.flatMap { isSelected in
                return .selectable(selected: isSelected)
            } ?? .none,
            displayHeader: false
        )
        self.messageItem = messageItem

        let messageItemNode: ListViewItemNode
        if let current = self.messageItemNode {
            messageItemNode = current
            messageItem.updateNode(async: { f in f() }, node: { return current }, params: ListViewItemLayoutParams(width: size.width, leftInset: insets.left, rightInset: insets.right, availableHeight: 0.0), previousItem: nil, nextItem: nil, animation: .System(duration: 0.2, transition: ControlledTransition(duration: 0.2, curve: .spring, interactive: false)), completion: { layout, apply in
                current.contentSize = layout.contentSize
                current.insets = layout.insets

                apply(ListViewItemApply(isOnScreen: true))
            })
        } else {
            var itemNode: ListViewItemNode?
            messageItem.nodeConfiguredForParams(async: { f in f() }, params: ListViewItemLayoutParams(width: size.width, leftInset: insets.left, rightInset: insets.right, availableHeight: 0.0), synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { node, apply in
                itemNode = node
                apply().1(ListViewItemApply(isOnScreen: true))
            })
            messageItemNode = itemNode!
            self.messageItemNode = messageItemNode
            self.buttonNode.addSubnode(messageItemNode)
        }

        messageItemNode.frame = CGRect(origin: CGPoint(), size: size)
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    func unbind() {
        self.item = nil
    }

    func needsShimmer() -> Bool {
        return false
    }

    func update(size: CGSize, insets: UIEdgeInsets) {
        if let messageItem = self.messageItem, let messageItemNode = self.messageItemNode {
            messageItem.updateNode(async: { f in f() }, node: { return messageItemNode }, params: ListViewItemLayoutParams(width: size.width, leftInset: insets.left, rightInset: insets.right, availableHeight: 0.0), previousItem: nil, nextItem: nil, animation: .System(duration: 0.2, transition: ControlledTransition(duration: 0.2, curve: .spring, interactive: false)), completion: { layout, apply in
                messageItemNode.contentSize = layout.contentSize
                messageItemNode.insets = layout.insets

                apply(ListViewItemApply(isOnScreen: true))
            })
            
            messageItemNode.frame = CGRect(origin: CGPoint(), size: size)
            self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        }
    }
}

protocol ListShimmerLayerImageProvider: AnyObject {
    func getListShimmerImage(height: CGFloat) -> UIImage
    func getSeparatorColor() -> UIColor
}

private final class ListShimmerLayer: CALayer, SparseItemGridShimmerLayer {
    final class OverlayLayer: CALayer {
        override func action(forKey event: String) -> CAAction? {
            return nullAction
        }
    }

    let imageProvider: ListShimmerLayerImageProvider
    let shimmerOverlay: OverlayLayer
    let separatorLayer: OverlayLayer

    private var validHeight: CGFloat?

    init(imageProvider: ListShimmerLayerImageProvider) {
        self.imageProvider = imageProvider
        self.shimmerOverlay = OverlayLayer()
        self.separatorLayer = OverlayLayer()

        super.init()

        self.addSublayer(self.shimmerOverlay)
        self.addSublayer(self.separatorLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }

    func update(size: CGSize) {
        if self.validHeight != size.height {
            self.validHeight = size.height
            ASDisplayNodeSetResizableContents(self.shimmerOverlay, self.imageProvider.getListShimmerImage(height: size.height))
            self.separatorLayer.backgroundColor = self.imageProvider.getSeparatorColor().cgColor
        }
        self.shimmerOverlay.frame = CGRect(origin: CGPoint(), size: size)
        self.separatorLayer.frame = CGRect(origin: CGPoint(x: 65.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width - 65.0, height: UIScreenPixel))
    }
}

private final class SparseItemGridBindingImpl: SparseItemGridBinding, ListShimmerLayerImageProvider {
    let context: AccountContext
    let chatLocation: ChatLocation
    let directMediaImageCache: DirectMediaImageCache
    let captureProtected: Bool
    var strings: PresentationStrings
    let useListItems: Bool
    let listItemInteraction: ListMessageItemInteraction
    let chatControllerInteraction: ChatControllerInteraction
    var chatPresentationData: ChatPresentationData
    var checkNodeTheme: CheckNodeTheme

    var loadHoleImpl: ((SparseItemGrid.HoleAnchor, SparseItemGrid.HoleLocation) -> Signal<Never, NoError>)?
    var onTapImpl: ((VisualMediaItem) -> Void)?
    var onTagTapImpl: (() -> Void)?
    var didScrollImpl: (() -> Void)?
    var coveringInsetOffsetUpdatedImpl: ((ContainedViewLayoutTransition) -> Void)?
    var onBeginFastScrollingImpl: (() -> Void)?
    var getShimmerColorsImpl: (() -> SparseItemGrid.ShimmerColors)?
    var updateShimmerLayersImpl: ((SparseItemGridDisplayItem) -> Void)?

    private var shimmerImages: [CGFloat: UIImage] = [:]

    init(context: AccountContext, chatLocation: ChatLocation, useListItems: Bool, listItemInteraction: ListMessageItemInteraction, chatControllerInteraction: ChatControllerInteraction, directMediaImageCache: DirectMediaImageCache, captureProtected: Bool) {
        self.context = context
        self.chatLocation = chatLocation
        self.useListItems = useListItems
        self.listItemInteraction = listItemInteraction
        self.chatControllerInteraction = chatControllerInteraction
        self.directMediaImageCache = directMediaImageCache
        self.captureProtected = false //captureProtected

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.strings = presentationData.strings

        let themeData = ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper)
        self.chatPresentationData = ChatPresentationData(theme: themeData, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners, animatedEmojiScale: 1.0)

        self.checkNodeTheme = CheckNodeTheme(theme: presentationData.theme, style: .overlay, hasInset: true)
    }

    func updatePresentationData(presentationData: PresentationData) {
        self.strings = presentationData.strings

        let themeData = ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper)
        self.chatPresentationData = ChatPresentationData(theme: themeData, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners, animatedEmojiScale: 1.0)

        self.checkNodeTheme = CheckNodeTheme(theme: presentationData.theme, style: .overlay, hasInset: true)
    }

    func getListShimmerImage(height: CGFloat) -> UIImage {
        if let image = self.shimmerImages[height] {
            return image
        } else {
            let fakeFile = TelegramMediaFile(
                fileId: MediaId(namespace: 0, id: 1),
                partialReference: nil,
                resource: EmptyMediaResource(),
                previewRepresentations: [],
                videoThumbnails: [],
                immediateThumbnailData: nil,
                mimeType: "image/jpeg",
                size: nil,
                attributes: [.FileName(fileName: "file")]
            )
            let fakeMessage = Message(
                stableId: 1,
                stableVersion: 1,
                id: MessageId(peerId: PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(1)), namespace: 0, id: 1),
                globallyUniqueId: nil,
                groupingKey: nil,
                groupInfo: nil,
                threadId: nil,
                timestamp: 1, flags: [],
                tags: [],
                globalTags: [],
                localTags: [],
                forwardInfo: nil,
                author: nil,
                text: "",
                attributes: [],
                media: [fakeFile],
                peers: SimpleDictionary<PeerId, Peer>(),
                associatedMessages: SimpleDictionary<MessageId, Message>(),
                associatedMessageIds: []
            )
            let messageItem = ListMessageItem(
                presentationData: self.chatPresentationData,
                context: self.context,
                chatLocation: self.chatLocation,
                interaction: self.listItemInteraction,
                message: fakeMessage,
                selection: .none,
                displayHeader: false
            )

            var itemNode: ListViewItemNode?
            messageItem.nodeConfiguredForParams(async: { f in f() }, params: ListViewItemLayoutParams(width: 400.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 0.0), synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { node, apply in
                itemNode = node
                apply().1(ListViewItemApply(isOnScreen: true))
            })

            guard let fileItemNode = itemNode as? ListMessageFileItemNode else {
                return UIImage()
            }

            let image = generateImage(CGSize(width: 320.0, height: height), rotatedContext: { size, context in
                UIGraphicsPushContext(context)

                context.setFillColor(self.chatPresentationData.theme.theme.list.plainBackgroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))

                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)

                func fillRoundedRect(rect: CGRect, radius: CGFloat) {
                    UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight, .bottomLeft, .bottomRight], cornerRadii: CGSize(width: radius, height: radius)).fill()
                }

                let lineHeight: CGFloat = 8.0
                let titleOrigin = CGPoint(x: fileItemNode.titleNode.frame.minX, y: fileItemNode.titleNode.frame.midY)
                let dateOrigin = CGPoint(x: fileItemNode.descriptionNode.frame.minX, y: fileItemNode.descriptionNode.frame.midY)

                fillRoundedRect(rect: CGRect(origin: CGPoint(x: titleOrigin.x, y: titleOrigin.y - lineHeight / 2.0), size: CGSize(width: 160.0, height: lineHeight)), radius: lineHeight / 2.0)
                fillRoundedRect(rect: CGRect(origin: CGPoint(x: dateOrigin.x, y: dateOrigin.y - lineHeight / 2.0), size: CGSize(width: 220.0, height: lineHeight)), radius: lineHeight / 2.0)

                fillRoundedRect(rect: fileItemNode.extensionIconNode.frame, radius: 6.0)

                UIGraphicsPopContext()
            })!.stretchableImage(withLeftCapWidth: 299, topCapHeight: 0)
            self.shimmerImages[height] = image
            return image
        }
    }

    func getSeparatorColor() -> UIColor {
        return self.chatPresentationData.theme.theme.list.itemPlainSeparatorColor
    }

    func createLayer() -> SparseItemGridLayer? {
        if self.useListItems {
            return nil
        }
        if self.captureProtected {
            return CaptureProtectedItemLayer()
        } else {
            return GenericItemLayer()
        }
    }

    func createView() -> SparseItemGridView? {
        if !self.useListItems {
            return nil
        }
        return ItemView()
    }

    func createShimmerLayer() -> SparseItemGridShimmerLayer? {
        if self.useListItems {
            let layer = ListShimmerLayer(imageProvider: self)
            return layer
        }
        return nil
    }

    private static let widthSpecs: ([Int], [Int]) = {
        let list: [(Int, Int)] = [
            (50, 64),
            (100, 150),
            (140, 200),
            (Int.max, 280)
        ]
        return (list.map(\.0), list.map(\.1))
    }()

    func bindLayers(items: [SparseItemGrid.Item], layers: [SparseItemGridDisplayItem], size: CGSize, insets: UIEdgeInsets, synchronous: SparseItemGrid.Synchronous) {
        for i in 0 ..< items.count {
            guard let item = items[i] as? VisualMediaItem else {
                continue
            }

            let displayItem = layers[i]

            if self.useListItems {
                guard let view = displayItem.view as? ItemView else {
                    continue
                }
                view.bind(
                    item: item,
                    presentationData: chatPresentationData,
                    context: self.context,
                    chatLocation: self.chatLocation,
                    interaction: self.listItemInteraction,
                    isSelected: self.chatControllerInteraction.selectionState?.selectedIds.contains(item.message.id),
                    size: CGSize(width: size.width, height: view.bounds.height),
                    insets: insets
                )
            } else {
                guard let layer = displayItem.layer as? ItemLayer else {
                    continue
                }
                if layer.bounds.isEmpty {
                    continue
                }

                var imageWidthSpec: Int = SparseItemGridBindingImpl.widthSpecs.1[0]
                for i in 0 ..< SparseItemGridBindingImpl.widthSpecs.0.count {
                    if Int(layer.bounds.width) <= SparseItemGridBindingImpl.widthSpecs.0[i] {
                        imageWidthSpec = SparseItemGridBindingImpl.widthSpecs.1[i]
                        break
                    }
                }

                let message = item.message

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
                    if let result = directMediaImageCache.getImage(message: message, media: selectedMedia, width: imageWidthSpec, possibleWidths: SparseItemGridBindingImpl.widthSpecs.1, synchronous: synchronous == .full) {
                        if let image = result.image {
                            layer.setContents(image)
                            switch synchronous {
                            case .none:
                                layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak self, weak layer, weak displayItem] _ in
                                    layer?.hasContents = true
                                    if let displayItem = displayItem {
                                        self?.updateShimmerLayersImpl?(displayItem)
                                    }
                                })
                            default:
                                layer.hasContents = true
                            }
                        }
                        if let loadSignal = result.loadSignal {
                            layer.disposable?.dispose()
                            let startTimestamp = CFAbsoluteTimeGetCurrent()
                            layer.disposable = (loadSignal
                            |> deliverOnMainQueue).start(next: { [weak self, weak layer, weak displayItem] image in
                                guard let layer = layer else {
                                    return
                                }
                                let deltaTime = CFAbsoluteTimeGetCurrent() - startTimestamp
                                let synchronousValue: Bool
                                switch synchronous {
                                case .none, .full:
                                    synchronousValue = false
                                case .semi:
                                    synchronousValue = deltaTime < 0.1
                                }

                                if let contents = layer.getContents(), !synchronousValue {
                                    let copyLayer = GenericItemLayer()
                                    copyLayer.contents = contents
                                    copyLayer.contentsRect = layer.contentsRect
                                    copyLayer.frame = layer.bounds
                                    if let durationLayer = layer.durationLayer {
                                        layer.insertSublayer(copyLayer, below: durationLayer)
                                    } else {
                                        layer.addSublayer(copyLayer)
                                    }
                                    copyLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak copyLayer] _ in
                                        copyLayer?.removeFromSuperlayer()
                                    })

                                    layer.setContents(image)
                                    layer.hasContents = true
                                    if let displayItem = displayItem {
                                        self?.updateShimmerLayersImpl?(displayItem)
                                    }
                                } else {
                                    layer.setContents(image)

                                    if !synchronousValue {
                                        layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak layer] _ in
                                            layer?.hasContents = true
                                            if let displayItem = displayItem {
                                                self?.updateShimmerLayersImpl?(displayItem)
                                            }
                                        })
                                    } else {
                                        layer.hasContents = true
                                        if let displayItem = displayItem {
                                            self?.updateShimmerLayersImpl?(displayItem)
                                        }
                                    }
                                }
                            })
                        }
                    }

                    var duration: Int32?
                    var isMin: Bool = false
                    if let file = selectedMedia as? TelegramMediaFile, !file.isAnimated {
                        duration = file.duration
                        isMin = layer.bounds.width < 80.0
                    }
                    layer.updateDuration(duration: duration, isMin: isMin, minFactor: min(1.0, layer.bounds.height / 74.0))
                }

                if let selectionState = self.chatControllerInteraction.selectionState {
                    layer.updateSelection(theme: self.checkNodeTheme, isSelected: selectionState.selectedIds.contains(message.id), animated: false)
                } else {
                    layer.updateSelection(theme: self.checkNodeTheme, isSelected: nil, animated: false)
                }

                layer.bind(item: item)
            }
        }
    }

    func unbindLayer(layer: SparseItemGridLayer) {
        guard let layer = layer as? ItemLayer else {
            return
        }
        layer.unbind()
    }

    func scrollerTextForTag(tag: Int32) -> String? {
        let month = Month(packedValue: tag)
        return stringForMonth(strings: self.strings, month: month.month, ofYear: month.year)
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

    func coveringInsetOffsetUpdated(transition: ContainedViewLayoutTransition) {
        self.coveringInsetOffsetUpdatedImpl?(transition)
    }

    func onBeginFastScrolling() {
        self.onBeginFastScrollingImpl?()
    }

    func getShimmerColors() -> SparseItemGrid.ShimmerColors {
        if let getShimmerColorsImpl = self.getShimmerColorsImpl {
            return getShimmerColorsImpl()
        } else {
            return SparseItemGrid.ShimmerColors(background: 0xffffff, foreground: 0xffffff)
        }
    }
}

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
    case .files:
        return .file
    case .voiceAndVideoMessages:
        return .voiceOrInstantVideo
    case .music:
        return .music
    }
}

final class PeerInfoVisualMediaPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate {
    enum ContentType {
        case photoOrVideo
        case photo
        case video
        case gifs
        case files
        case voiceAndVideoMessages
        case music
    }

    struct ZoomLevel {
        fileprivate var value: SparseItemGrid.ZoomLevel

        init(_ value: SparseItemGrid.ZoomLevel) {
            self.value = value
        }

        var rawValue: Int32 {
            return Int32(self.value.rawValue)
        }

        public init(rawValue: Int32) {
            self.value = SparseItemGrid.ZoomLevel(rawValue: Int(rawValue))
        }
    }
    
    private let context: AccountContext
    private let peerId: PeerId
    private let chatControllerInteraction: ChatControllerInteraction
    private(set) var contentType: ContentType
    private var contentTypePromise: ValuePromise<ContentType>
    
    weak var parentController: ViewController?

    private let contextGestureContainerNode: ContextControllerSourceNode
    private let itemGrid: SparseItemGrid
    private let itemGridBinding: SparseItemGridBindingImpl
    private let directMediaImageCache: DirectMediaImageCache
    private var items: SparseItemGrid.Items?
    private var didUpdateItemsOnce: Bool = false

    private var isDeceleratingAfterTracking = false
    
    private var _itemInteraction: VisualMediaItemInteraction?
    private var itemInteraction: VisualMediaItemInteraction {
        return self._itemInteraction!
    }
    
    private var currentParams: (size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    private let statusPromise = Promise<PeerInfoStatusData?>(nil)
    var status: Signal<PeerInfoStatusData?, NoError> {
        self.statusPromise.get()
    }

    var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    var tabBarOffset: CGFloat {
        return self.itemGrid.coveringInsetOffset
    }
        
    private let listDisposable = MetaDisposable()
    private var hiddenMediaDisposable: Disposable?
    
    private var numberOfItemsToRequest: Int = 50
    private var isRequestingView: Bool = false
    private var isFirstHistoryView: Bool = true
    
    private var decelerationAnimator: ConstantDisplayLinkAnimator?
    
    private var animationTimer: SwiftSignalKit.Timer?

    private(set) var calendarSource: SparseMessageCalendar?
    private var listSource: SparseMessageList

    var openCurrentDate: (() -> Void)?
    var paneDidScroll: (() -> Void)?

    private let stateTag: MessageTags
    private var storedStateDisposable: Disposable?

    private weak var currentGestureItem: SparseItemGridDisplayItem?

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, chatControllerInteraction: ChatControllerInteraction, peerId: PeerId, contentType: ContentType, captureProtected: Bool) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        self.contentType = contentType
        self.contentTypePromise = ValuePromise<ContentType>(contentType)
        self.stateTag = tagMaskForType(contentType)

        self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

        self.contextGestureContainerNode = ContextControllerSourceNode()
        self.itemGrid = SparseItemGrid(theme: self.presentationData.theme)
        self.directMediaImageCache = DirectMediaImageCache(account: context.account)

        let useListItems: Bool
        switch contentType {
        case .files, .voiceAndVideoMessages, .music:
            useListItems = true
        default:
            useListItems = false
        }

        let listItemInteraction = ListMessageItemInteraction(
            openMessage: { message, mode in
                return chatControllerInteraction.openMessage(message, mode)
            },
            openMessageContextMenu: { message, bool, node, rect, gesture in
                chatControllerInteraction.openMessageContextMenu(message, bool, node, rect, gesture)
            },
            toggleMessagesSelection: { messageId, selected in
                chatControllerInteraction.toggleMessagesSelection(messageId, selected)
            },
            openUrl: { url, param1, param2, message in
                chatControllerInteraction.openUrl(url, param1, param2, message)
            },
            openInstantPage: { message, data in
                chatControllerInteraction.openInstantPage(message, data)
            },
            longTap: { action, message in
                chatControllerInteraction.longTap(action, message)
            },
            getHiddenMedia: {
                return chatControllerInteraction.hiddenMedia
            }
        )

        self.itemGridBinding = SparseItemGridBindingImpl(
            context: context,
            chatLocation: .peer(id: peerId),
            useListItems: useListItems,
            listItemInteraction: listItemInteraction,
            chatControllerInteraction: chatControllerInteraction,
            directMediaImageCache: self.directMediaImageCache,
            captureProtected: captureProtected
        )

        self.listSource = self.context.engine.messages.sparseMessageList(peerId: self.peerId, tag: tagMaskForType(self.contentType))
        switch contentType {
        case .photoOrVideo, .photo, .video:
            self.calendarSource = self.context.engine.messages.sparseMessageCalendar(peerId: self.peerId, tag: tagMaskForType(self.contentType))
        default:
            self.calendarSource = nil
        }
        
        super.init()

        let _ = (ApplicationSpecificNotice.getSharedMediaScrollingTooltip(accountManager: context.sharedContext.accountManager)
        |> deliverOnMainQueue).start(next: { [weak self] count in
            guard let strongSelf = self else {
                return
            }
            if count < 1 {
                strongSelf.itemGrid.updateScrollingAreaTooltip(tooltip: SparseItemGridScrollingArea.DisplayTooltip(animation: "anim_infotip", text: strongSelf.itemGridBinding.chatPresentationData.strings.SharedMedia_FastScrollTooltip, completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = ApplicationSpecificNotice.incrementSharedMediaScrollingTooltip(accountManager: strongSelf.context.sharedContext.accountManager, count: 1).start()
                }))
            }
        })

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
            if let selectionState = strongSelf.chatControllerInteraction.selectionState {
                var toggledValue = true
                if selectionState.selectedIds.contains(item.message.id) {
                    toggledValue = false
                }
                strongSelf.chatControllerInteraction.toggleMessagesSelection([item.message.id], toggledValue)
            } else {
                let _ = strongSelf.chatControllerInteraction.openMessage(item.message, .default)
            }
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

            strongSelf.cancelPreviewGestures()
        }

        self.itemGridBinding.coveringInsetOffsetUpdatedImpl = { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.tabBarOffsetUpdated?(transition)
        }

        var processedOnBeginFastScrolling = false
        self.itemGridBinding.onBeginFastScrollingImpl = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if processedOnBeginFastScrolling {
                return
            }
            processedOnBeginFastScrolling = true

            let _ = (ApplicationSpecificNotice.getSharedMediaFastScrollingTooltip(accountManager: strongSelf.context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { count in
                guard let strongSelf = self else {
                    return
                }
                if count < 1 {
                    let _ = ApplicationSpecificNotice.incrementSharedMediaFastScrollingTooltip(accountManager: strongSelf.context.sharedContext.accountManager).start()

                    var currentNode: ASDisplayNode = strongSelf
                    var result: PeerInfoScreenNode?
                    while true {
                        if let currentNode = currentNode as? PeerInfoScreenNode {
                            result = currentNode
                            break
                        } else if let supernode = currentNode.supernode {
                            currentNode = supernode
                        } else {
                            break
                        }
                    }
                    if let result = result {
                        result.displaySharedMediaFastScrollingTooltip()
                    }
                }
            })
        }

        self.itemGridBinding.getShimmerColorsImpl = { [weak self] in
            guard let strongSelf = self, let presentationData = strongSelf.currentParams?.presentationData else {
                return SparseItemGrid.ShimmerColors(background: 0xffffff, foreground: 0xffffff)
            }

            let backgroundColor = presentationData.theme.list.mediaPlaceholderColor
            let foregroundColor = presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.6)

            return SparseItemGrid.ShimmerColors(background: backgroundColor.argb, foreground: foregroundColor.argb)
        }

        self.itemGridBinding.updateShimmerLayersImpl = { [weak self] layer in
            self?.itemGrid.updateShimmerLayers(item: layer)
        }

        self.itemGrid.cancelExternalContentGestures = { [weak self] in
            self?.contextGestureContainerNode.cancelGesture()
        }

        self.itemGrid.zoomLevelUpdated = { [weak self] zoomLevel in
            guard let strongSelf = self else {
                return
            }
            let _ = updateVisualMediaStoredState(postbox: strongSelf.context.account.postbox, peerId: strongSelf.peerId, messageTag: strongSelf.stateTag, state: VisualMediaStoredState(zoomLevel: Int32(zoomLevel.rawValue))).start()
        }
        
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

        self.contextGestureContainerNode.isGestureEnabled = !useListItems
        self.contextGestureContainerNode.addSubnode(self.itemGrid)
        self.addSubnode(self.contextGestureContainerNode)

        self.contextGestureContainerNode.shouldBegin = { [weak self] point in
            guard let strongSelf = self else {
                return false
            }
            guard let item = strongSelf.itemGrid.item(at: point) else {
                return false
            }

            if let result = strongSelf.view.hitTest(point, with: nil) {
                if result.asyncdisplaykit_node is SparseItemGridScrollingArea {
                    return false
                }
            }

            strongSelf.currentGestureItem = item

            return true
        }

        self.contextGestureContainerNode.customActivationProgress = { [weak self] progress, update in
            guard let strongSelf = self, let currentGestureItem = strongSelf.currentGestureItem else {
                return
            }
            guard let itemLayer = currentGestureItem.layer else {
                return
            }

            let targetContentRect = CGRect(origin: CGPoint(), size: itemLayer.bounds.size)

            let scaleSide = itemLayer.bounds.width
            let minScale: CGFloat = max(0.7, (scaleSide - 15.0) / scaleSide)
            let currentScale = 1.0 * (1.0 - progress) + minScale * progress

            let originalCenterOffsetX: CGFloat = itemLayer.bounds.width / 2.0 - targetContentRect.midX
            let scaledCenterOffsetX: CGFloat = originalCenterOffsetX * currentScale

            let originalCenterOffsetY: CGFloat = itemLayer.bounds.height / 2.0 - targetContentRect.midY
            let scaledCenterOffsetY: CGFloat = originalCenterOffsetY * currentScale

            let scaleMidX: CGFloat = scaledCenterOffsetX - originalCenterOffsetX
            let scaleMidY: CGFloat = scaledCenterOffsetY - originalCenterOffsetY

            switch update {
            case .update:
                let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                itemLayer.transform = sublayerTransform
            case .begin:
                let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                itemLayer.transform = sublayerTransform
            case .ended:
                let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                let previousTransform = itemLayer.transform
                itemLayer.transform = sublayerTransform

                itemLayer.animate(from: NSValue(caTransform3D: previousTransform), to: NSValue(caTransform3D: sublayerTransform), keyPath: "transform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
            }
        }

        self.contextGestureContainerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let currentGestureItem = strongSelf.currentGestureItem else {
                return
            }
            strongSelf.currentGestureItem = nil

            guard let itemLayer = currentGestureItem.layer as? ItemLayer else {
                return
            }
            guard let message = itemLayer.item?.message else {
                return
            }
            let rect = strongSelf.itemGrid.frameForItem(layer: itemLayer)

            strongSelf.chatControllerInteraction.openMessageContextActions(message, strongSelf, rect, gesture)

            strongSelf.itemGrid.cancelGestures()
        }

        self.storedStateDisposable = (visualMediaStoredState(postbox: context.account.postbox, peerId: peerId, messageTag: self.stateTag)
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if let value = value {
                strongSelf.updateZoomLevel(level: ZoomLevel(rawValue: value.zoomLevel))
            }
            strongSelf.requestHistoryAroundVisiblePosition(synchronous: false, reloadAtTop: false)
        })
        
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

            if let items = strongSelf.items {
                for item in items.items {
                    if let item = item as? VisualMediaItem {
                        if hiddenMedia[item.message.id] != nil {
                            strongSelf.itemGrid.ensureItemVisible(index: item.index)
                            break
                        }
                    }
                }
            }

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
            case .files:
                summaries.append(.file)
            case .voiceAndVideoMessages:
                summaries.append(.voiceOrInstantVideo)
            case .music:
                summaries.append(.music)
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
                case .files:
                    summaries.append(.file)
                case .voiceAndVideoMessages:
                    summaries.append(.voiceOrInstantVideo)
                case .music:
                    summaries.append(.music)
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
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }

            switch contentType {
            case .photoOrVideo:
                let photoCount: Int32 = dict[.photo] ?? 0
                let videoCount: Int32 = dict[.video] ?? 0

                if photoCount != 0 && videoCount != 0 {
                    return PeerInfoStatusData(text: "\(presentationData.strings.SharedMedia_PhotoCount(Int32(photoCount))), \(presentationData.strings.SharedMedia_VideoCount(Int32(videoCount)))", isActivity: false, key: .media)
                } else if photoCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_PhotoCount(Int32(photoCount)), isActivity: false, key: .media)
                } else if videoCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_VideoCount(Int32(videoCount)), isActivity: false, key: .media)
                } else {
                    return nil
                }
            case .photo:
                let photoCount: Int32 = dict[.photo] ?? 0

                if photoCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_PhotoCount(Int32(photoCount)), isActivity: false, key: .media)
                } else {
                    return nil
                }
            case .video:
                let videoCount: Int32 = dict[.video] ?? 0

                if videoCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_VideoCount(Int32(videoCount)), isActivity: false, key: .media)
                } else {
                    return nil
                }
            case .gifs:
                let gifCount: Int32 = dict[.gif] ?? 0

                if gifCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_GifCount(Int32(gifCount)), isActivity: false, key: .gifs)
                } else {
                    return nil
                }
            case .files:
                let fileCount: Int32 = dict[.file] ?? 0

                if fileCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_FileCount(Int32(fileCount)), isActivity: false, key: .files)
                } else {
                    return nil
                }
            case .voiceAndVideoMessages:
                let itemCount: Int32 = dict[.voiceOrInstantVideo] ?? 0

                if itemCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_VoiceMessageCount(Int32(itemCount)), isActivity: false, key: .voice)
                } else {
                    return nil
                }
            case .music:
                let itemCount: Int32 = dict[.music] ?? 0

                if itemCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_MusicCount(Int32(itemCount)), isActivity: false, key: .music)
                } else {
                    return nil
                }
            }
        }))

        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self, let (size, topInset, sideInset, bottomInset, _, _, _, _) = strongSelf.currentParams  else {
                return
            }
            strongSelf.itemGridBinding.updatePresentationData(presentationData: presentationData)

            strongSelf.itemGrid.updatePresentationData(theme: presentationData.theme)

            strongSelf.itemGrid.forEachVisibleItem { item in
                guard let strongSelf = self, let itemView = item.view as? ItemView else {
                    return
                }
                if let item = itemView.item {
                    itemView.bind(
                        item: item,
                        presentationData: strongSelf.itemGridBinding.chatPresentationData,
                        context: strongSelf.itemGridBinding.context,
                        chatLocation: strongSelf.itemGridBinding.chatLocation,
                        interaction: strongSelf.itemGridBinding.listItemInteraction,
                        isSelected: strongSelf.chatControllerInteraction.selectionState?.selectedIds.contains(item.message.id),
                        size: CGSize(width: size.width, height: itemView.bounds.height),
                        insets: UIEdgeInsets(top: topInset, left: sideInset, bottom: bottomInset, right: sideInset)
                    )
                }
            }
        })
    }
    
    deinit {
        self.listDisposable.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.animationTimer?.invalidate()
        self.presentationDataDisposable?.dispose()
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

        self.itemGrid.hideScrollingArea()

        self.listSource = self.context.engine.messages.sparseMessageList(peerId: self.peerId, tag: tagMaskForType(self.contentType))
        self.isRequestingView = false
        self.requestHistoryAroundVisiblePosition(synchronous: true, reloadAtTop: true)
    }

    func updateZoomLevel(level: ZoomLevel) {
        self.itemGrid.setZoomLevel(level: level.value)

        let _ = updateVisualMediaStoredState(postbox: self.context.account.postbox, peerId: self.peerId, messageTag: self.stateTag, state: VisualMediaStoredState(zoomLevel: level.rawValue)).start()
    }
    
    func ensureMessageIsVisible(id: MessageId) {
    }
    
    private func requestHistoryAroundVisiblePosition(synchronous: Bool, reloadAtTop: Bool) {
        if self.isRequestingView {
            return
        }
        self.isRequestingView = true
        var firstTime = true
        let queue = Queue()

        self.listDisposable.set((self.listSource.state
        |> deliverOn(queue)).start(next: { [weak self] list in
            let timezoneOffset = Int32(TimeZone.current.secondsFromGMT())

            var mappedItems: [SparseItemGrid.Item] = []
            var mappedHoles: [SparseItemGrid.HoleAnchor] = []
            for item in list.items {
                switch item.content {
                case let .message(message, isLocal):
                    mappedItems.append(VisualMediaItem(index: item.index, message: message, localMonthTimestamp: Month(localTimestamp: message.timestamp + timezoneOffset).packedValue))
                    if !isLocal {
                        mappedHoles.append(VisualMediaHoleAnchor(index: item.index, messageId: message.id, localMonthTimestamp: Month(localTimestamp: message.timestamp + timezoneOffset).packedValue))
                    }
                case let .placeholder(id, timestamp):
                    mappedHoles.append(VisualMediaHoleAnchor(index: item.index, messageId: id, localMonthTimestamp: Month(localTimestamp: timestamp + timezoneOffset).packedValue))
                }
            }

            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }

                let items = SparseItemGrid.Items(
                    items: mappedItems,
                    holeAnchors: mappedHoles,
                    count: list.totalCount,
                    itemBinding: strongSelf.itemGridBinding
                )

                let currentSynchronous = synchronous && firstTime
                let currentReloadAtTop = reloadAtTop && firstTime
                firstTime = false
                strongSelf.updateHistory(items: items, synchronous: currentSynchronous, reloadAtTop: currentReloadAtTop)
                strongSelf.isRequestingView = false
            }
        }))
    }
    
    private func updateHistory(items: SparseItemGrid.Items, synchronous: Bool, reloadAtTop: Bool) {
        self.items = items

        if let (size, topInset, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData) = self.currentParams {
            var gridSnapshot: UIView?
            if reloadAtTop {
                gridSnapshot = self.itemGrid.view.snapshotView(afterScreenUpdates: false)
            }
            self.update(size: size, topInset: topInset, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expandProgress, presentationData: presentationData, synchronous: false, transition: .immediate)
            if let gridSnapshot = gridSnapshot {
                self.view.addSubview(gridSnapshot)
                gridSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak gridSnapshot] _ in
                    gridSnapshot?.removeFromSuperview()
                })
            }
        }

        if !self.didSetReady {
            self.didSetReady = true
            self.ready.set(.single(true))
        }
    }
    
    func scrollToTop() -> Bool {
        return self.itemGrid.scrollToTop()
    }

    func hitTestResultForScrolling() -> UIView? {
        return self.itemGrid.hitTestResultForScrolling()
    }

    func brieflyDisableTouchActions() {
        self.itemGrid.brieflyDisableTouchActions()
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        guard let items = self.items else {
            return nil
        }
        for item in items.items {
            guard let item = item as? VisualMediaItem else {
                continue
            }
            if item.message.id == id {
                return item.message
            }
        }
        return nil
    }
    
    func updateHiddenMedia() {
        self.itemGrid.forEachVisibleItem { item in
            guard let itemLayer = item.layer as? ItemLayer else {
                return
            }
            if let item = itemLayer.item {
                if self.itemInteraction.hiddenMedia[item.message.id] != nil {
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
        self.itemGrid.transferVelocity(velocity)
    }
    
    func cancelPreviewGestures() {
        self.itemGrid.forEachVisibleItem { item in
            guard let itemView = item.view as? ItemView else {
                return
            }
            if let messageItemNode = itemView.messageItemNode as? ListMessageFileItemNode {
                messageItemNode.cancelPreviewGesture()
            }
        }
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        var foundItemLayer: SparseItemGridLayer?
        self.itemGrid.forEachVisibleItem { item in
            guard let itemLayer = item.layer as? ItemLayer else {
                return
            }
            if let item = itemLayer.item, item.message.id == messageId {
                foundItemLayer = itemLayer
            }
        }
        if let itemLayer = foundItemLayer {
            let itemFrame = self.view.convert(self.itemGrid.frameForItem(layer: itemLayer), from: self.itemGrid.view)
            let proxyNode = ASDisplayNode()
            proxyNode.frame = itemFrame
            if let contents = itemLayer.getContents() {
                if let image = contents as? UIImage {
                    proxyNode.contents = image.cgImage
                } else {
                    proxyNode.contents = contents
                }
            }
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
        switch self.contentType {
        case .files, .music, .voiceAndVideoMessages:
            self.itemGrid.forEachVisibleItem { item in
                guard let itemView = item.view as? ItemView, let (size, topInset, sideInset, bottomInset, _, _, _, _) = self.currentParams else {
                    return
                }
                if let item = itemView.item {
                    itemView.bind(
                        item: item,
                        presentationData: self.itemGridBinding.chatPresentationData,
                        context: self.itemGridBinding.context,
                        chatLocation: self.itemGridBinding.chatLocation,
                        interaction: self.itemGridBinding.listItemInteraction,
                        isSelected: self.chatControllerInteraction.selectionState?.selectedIds.contains(item.message.id),
                        size: CGSize(width: size.width, height: itemView.bounds.height),
                        insets: UIEdgeInsets(top: topInset, left: sideInset, bottom: bottomInset, right: sideInset)
                    )
                }
            }
        case .photo, .video, .photoOrVideo, .gifs:
            self.itemGrid.forEachVisibleItem { item in
                guard let itemLayer = item.layer as? ItemLayer, let item = itemLayer.item else {
                    return
                }
                itemLayer.updateSelection(theme: self.itemGridBinding.checkNodeTheme, isSelected: self.chatControllerInteraction.selectionState?.selectedIds.contains(item.message.id), animated: animated)
            }

            self.itemGrid.pinchEnabled = self.chatControllerInteraction.selectionState == nil
        }
    }
    
    func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, topInset, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)

        transition.updateFrame(node: self.contextGestureContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))

        transition.updateFrame(node: self.itemGrid, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        if let items = self.items {
            let wasFirstTime = !self.didUpdateItemsOnce
            self.didUpdateItemsOnce = true
            let fixedItemHeight: CGFloat?
            var isList = false
            switch self.contentType {
            case .files, .music, .voiceAndVideoMessages:
                let fakeFile = TelegramMediaFile(
                    fileId: MediaId(namespace: 0, id: 1),
                    partialReference: nil,
                    resource: EmptyMediaResource(),
                    previewRepresentations: [],
                    videoThumbnails: [],
                    immediateThumbnailData: nil,
                    mimeType: "image/jpeg",
                    size: nil,
                    attributes: [.FileName(fileName: "file")]
                )
                let fakeMessage = Message(
                    stableId: 1,
                    stableVersion: 1,
                    id: MessageId(peerId: PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(1)), namespace: 0, id: 1),
                    globallyUniqueId: nil,
                    groupingKey: nil,
                    groupInfo: nil,
                    threadId: nil,
                    timestamp: 1, flags: [],
                    tags: [],
                    globalTags: [],
                    localTags: [],
                    forwardInfo: nil,
                    author: nil,
                    text: "",
                    attributes: [],
                    media: [fakeFile],
                    peers: SimpleDictionary<PeerId, Peer>(),
                    associatedMessages: SimpleDictionary<MessageId, Message>(),
                    associatedMessageIds: []
                )
                let messageItem = ListMessageItem(
                    presentationData: self.itemGridBinding.chatPresentationData,
                    context: self.itemGridBinding.context,
                    chatLocation: self.itemGridBinding.chatLocation,
                    interaction: self.itemGridBinding.listItemInteraction,
                    message: fakeMessage,
                    selection: .none,
                    displayHeader: false
                )

                var itemNode: ListViewItemNode?
                messageItem.nodeConfiguredForParams(async: { f in f() }, params: ListViewItemLayoutParams(width: size.width, leftInset: 0.0, rightInset: 0.0, availableHeight: 0.0), synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })

                if let itemNode = itemNode {
                    fixedItemHeight = itemNode.contentSize.height
                } else {
                    preconditionFailure()
                }
                isList = true
            default:
                fixedItemHeight = nil
            }
         
            self.itemGrid.update(size: size, insets: UIEdgeInsets(top: topInset, left: sideInset, bottom:  bottomInset, right: sideInset), useSideInsets: !isList, scrollIndicatorInsets: UIEdgeInsets(top: 0.0, left: sideInset, bottom: bottomInset, right: sideInset), lockScrollingAtTop: isScrollingLockedAtTop, fixedItemHeight: fixedItemHeight, items: items, theme: self.itemGridBinding.chatPresentationData.theme.theme, synchronous: wasFirstTime ? .full : .none)
        }
    }

    func currentTopTimestamp() -> Int32? {
        var timestamp: Int32?
        self.itemGrid.forEachVisibleItem { item in
            guard let itemLayer = item.layer as? ItemLayer else {
                return
            }
            if let item = itemLayer.item {
                if let timestampValue = timestamp {
                    timestamp = max(timestampValue, item.message.timestamp)
                } else {
                    timestamp = item.message.timestamp
                }
            }
        }
        return timestamp
    }

    func scrollToTimestamp(timestamp: Int32) {
        if let items = self.items, !items.items.isEmpty {
            var previousIndex: Int?
            for item in items.items {
                guard let item = item as? VisualMediaItem else {
                    continue
                }
                if item.message.timestamp <= timestamp {
                    break
                }
                previousIndex = item.index
            }
            if previousIndex == nil {
                previousIndex = (items.items[0] as? VisualMediaItem)?.index
            }
            if let index = previousIndex {
                self.itemGrid.scrollToItem(at: index)

                if let item = self.itemGrid.item(at: index) {
                    if let layer = item.layer as? ItemLayer {
                        Queue.mainQueue().after(0.1, { [weak layer] in
                            guard let layer = layer else {
                                return
                            }

                            let overlayLayer = ListShimmerLayer.OverlayLayer()
                            overlayLayer.backgroundColor = UIColor(white: 1.0, alpha: 0.6).cgColor
                            overlayLayer.frame = layer.bounds
                            layer.addSublayer(overlayLayer)
                            overlayLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.8, delay: 0.3, removeOnCompletion: false, completion: { [weak overlayLayer] _ in
                                overlayLayer?.removeFromSuperlayer()
                            })
                        })
                    }
                }
            }
        }
    }

    func scrollToItem(index: Int) {
        guard let _ = self.items else {
            return
        }
        self.itemGrid.scrollToItem(at: index)
    }
    
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

final class VisualMediaStoredState: Codable {
    let zoomLevel: Int32

    public init(zoomLevel: Int32) {
        self.zoomLevel = zoomLevel
    }
}

func visualMediaStoredState(postbox: Postbox, peerId: PeerId, messageTag: MessageTags) -> Signal<VisualMediaStoredState?, NoError> {
    return postbox.transaction { transaction -> VisualMediaStoredState? in
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setUInt32(8, value: messageTag.rawValue)
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.visualMediaStoredState, key: key))?.get(VisualMediaStoredState.self) {
            return entry
        } else {
            return nil
        }
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 25, highWaterItemCount: 50)

func updateVisualMediaStoredState(postbox: Postbox, peerId: PeerId, messageTag: MessageTags, state: VisualMediaStoredState?) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setUInt32(8, value: messageTag.rawValue)

        let id = ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.visualMediaStoredState, key: key)
        if let state = state, let entry = CodableEntry(state) {
            transaction.putItemCacheEntry(id: id, entry: entry, collectionSpec: collectionSpec)
        } else {
            transaction.removeItemCacheEntry(id: id)
        }
    }
}
