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
import UniversalMediaPlayer
import ListMessageItem
import ChatMessageInteractiveMediaBadge
import GridMessageSelectionNode

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

private final class VisualMediaItemNode: ASDisplayNode {
    private let context: AccountContext
    private let interaction: VisualMediaItemInteraction
    
    private var displayLink: ConstantDisplayLinkAnimator?
    private var displayLinkTimestamp: Double = 0.0
    
    private let containerNode: ContextControllerSourceNode
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
        
        super.init()
                
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.mediaBadgeNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            if let message = item.0.message {
                strongSelf.interaction.openMessageContextActions(message, strongSelf.containerNode, strongSelf.containerNode.bounds, gesture)
            }
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
    
    @objc func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        guard let message = self.item?.0.message else {
            return
        }
        if case .ended = recognizer.state {
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                if case .tap = gesture {
                    if let _ = self.item {
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
            case .Remote, .Paused:
                self.fetchDisposable.set(messageMediaFileInteractiveFetched(context: self.context, message: message, file: file, userInitiated: true).start())
            }
        }
    }
    
    func cancelPreviewGesture() {
        self.containerNode.cancelGesture()
    }
    
    func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
    }
    
    func update(size: CGSize, item: VisualMediaItem, theme: PresentationTheme, synchronousLoad: Bool) {
        if item === self.item?.0 && size == self.item?.2 {
            return
        }
        self.theme = theme
        var media: Media?
        if let message = item.message {
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
        
        if let media = media, (self.item?.1 == nil || !media.isEqual(to: self.item!.1!)), let message = item.message {
            var mediaDimensions: CGSize?
            if let image = media as? TelegramMediaImage, let largestSize = largestImageRepresentation(image.representations)?.dimensions {
                mediaDimensions = largestSize.cgSize
               
                self.imageNode.setSignal(mediaGridMessagePhoto(account: context.account, photoReference: .message(message: MessageReference(message), media: image), fullRepresentationSize: CGSize(width: 300.0, height: 300.0), synchronousLoad: synchronousLoad), attemptSynchronously: synchronousLoad, dispatchOnDisplayLink: true)
                
                self.fetchStatusDisposable.set(nil)
                self.statusNode.transitionToState(.none, completion: { [weak self] in
                    self?.statusNode.isHidden = true
                })
                self.mediaBadgeNode.isHidden = true
                self.resourceStatus = nil
            } else if let file = media as? TelegramMediaFile, file.isVideo {
                mediaDimensions = file.dimensions?.cgSize
                self.imageNode.setSignal(mediaGridMessageVideo(postbox: context.account.postbox, videoReference: .message(message: MessageReference(message), media: file), synchronousLoad: synchronousLoad, autoFetchFullSizeThumbnail: true), attemptSynchronously: synchronousLoad)
                
                self.mediaBadgeNode.isHidden = file.isAnimated
                
                self.resourceStatus = nil
                
                self.item = (item, media, size, mediaDimensions)
                
                self.fetchStatusDisposable.set((messageMediaFileStatus(context: context, messageId: message.id, file: file)
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self, let _ = strongSelf.item {
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
                            case .Remote, .Paused:
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
                                    case .Remote, .Paused:
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
            
            let progressDiameter: CGFloat = 40.0
            self.statusNode.frame = CGRect(origin: CGPoint(x: floor((size.width - progressDiameter) / 2.0), y: floor((size.height - progressDiameter) / 2.0)), size: CGSize(width: progressDiameter, height: progressDiameter))
            
            self.mediaBadgeNode.frame = CGRect(origin: CGPoint(x: size.width - 3.0, y: size.height - 18.0 - 3.0), size: CGSize(width: 50.0, height: 50.0))
            
            self.selectionNode?.frame = CGRect(origin: CGPoint(), size: size)
            
            self.updateHiddenMedia()
        }
        
        let imageFrame = CGRect(origin: CGPoint(), size: size)
        
        if let (item, media, _, mediaDimensions) = self.item {
            self.item = (item, media, size, mediaDimensions)
            
            self.containerNode.frame = imageFrame
            self.imageNode.frame = imageFrame
            
            if let mediaDimensions = mediaDimensions {
                let imageSize = mediaDimensions.aspectFilled(imageFrame.size)
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets(), emptyColor: theme.list.mediaPlaceholderColor))()
            }
            
            self.updateSelectionState(animated: false)
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        self.hasVisibility = isVisible
        self.displayLink?.isPaused = !self.hasVisibility || self.isHidden
    }
    
    func updateSelectionState(animated: Bool) {
        if let (item, _, _, _) = self.item, let theme = self.theme, let message = item.message {
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
        if let (item, _, _, _) = self.item, let message = item.message {
            if let _ = self.interaction.hiddenMedia[message.id] {
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

private final class VisualMediaItem {
    let index: UInt32?
    let message: Message?
    let dimensions: CGSize
    let aspectRatio: CGFloat
    
    init(message: Message, index: UInt32?) {
        self.index = index
        self.message = message
        
        var aspectRatio: CGFloat = 1.0
        var dimensions = CGSize(width: 100.0, height: 100.0)
        for media in message.media {
            if let file = media as? TelegramMediaFile {
                if let dimensionsValue = file.dimensions, dimensions.height > 1 {
                    dimensions = dimensionsValue.cgSize
                    aspectRatio = CGFloat(dimensionsValue.width) / CGFloat(dimensionsValue.height)
                }
            }
        }
        self.aspectRatio = aspectRatio
        self.dimensions = dimensions
    }
    
    var stableId: UInt32 {
        if let index = self.index {
            return index
        } else if let message = self.message {
            return message.stableId
        } else {
            return 0
        }
    }
}

private final class FloatingHeaderNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let labelNode: ImmediateTextNode
    
    private var currentParams: (constrainedWidth: CGFloat, year: Int32, month: Int32, theme: PresentationTheme)?
    private var currentSize: CGSize?
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
    }
    
    func update(constrainedWidth: CGFloat, year: Int32, month: Int32, theme: PresentationTheme, strings: PresentationStrings) -> CGSize {
        if let currentParams = self.currentParams, let currentSize = self.currentSize {
            if currentParams.constrainedWidth == constrainedWidth &&
               currentParams.year == year &&
               currentParams.month == month &&
               currentParams.theme === theme {
                return currentSize
            }
        }
        
        if self.currentParams?.theme !== theme {
            self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 27.0, color: mediaBadgeBackgroundColor)
        }
        
        self.currentParams = (constrainedWidth, year, month, theme)
        
        self.labelNode.attributedText = NSAttributedString(string: stringForMonth(strings: strings, month: month, ofYear: year), font: Font.regular(14.0), textColor: .white)
        let labelSize = self.labelNode.updateLayout(CGSize(width: constrainedWidth, height: .greatestFiniteMagnitude))
        
        let sideInset: CGFloat = 10.0
        self.labelNode.frame = CGRect(origin: CGPoint(x: sideInset, y: floor((27.0 - labelSize.height) / 2.0)), size: labelSize)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: labelSize.width + sideInset * 2.0, height: 27.0))
        
        let size = CGSize(width: labelSize.width + sideInset * 2.0, height: 27.0)
        return size
    }
}

private enum ItemsLayout {
    final class Grid {
        let containerWidth: CGFloat
        let itemCount: Int
        let itemSpacing: CGFloat
        let itemsInRow: Int
        let itemSize: CGFloat
        let rowCount: Int
        let contentHeight: CGFloat
        
        init(containerWidth: CGFloat, itemCount: Int, bottomInset: CGFloat) {
            self.containerWidth = containerWidth
            self.itemCount = itemCount
            self.itemSpacing = 1.0
            self.itemsInRow = max(3, min(6, Int(containerWidth / 140.0)))
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
    
    final class Balanced {
        let frames: [CGRect]
        let contentHeight: CGFloat
        
        init(containerWidth: CGFloat, items: [VisualMediaItem], bottomInset: CGFloat) {
            self.frames = calculateItemFrames(items: items, containerWidth: containerWidth)
            if let last = self.frames.last {
                self.contentHeight = last.maxY + bottomInset
            } else {
                self.contentHeight = bottomInset
            }
        }
        
        func visibleRange(rect: CGRect) -> (Int, Int) {
            for i in 0 ..< self.frames.count {
                if self.frames[i].maxY >= rect.minY {
                    for j in i ..< self.frames.count {
                        if self.frames[j].minY >= rect.maxY {
                            return (i, j - 1)
                        }
                    }
                    return (i, self.frames.count - 1)
                }
            }
            return (0, -1)
        }
        
        func frame(forItemAt index: Int, sideInset: CGFloat) -> CGRect {
            if index >= 0 && index < self.frames.count {
                return self.frames[index]
            } else {
                assertionFailure()
                return CGRect(origin: CGPoint(), size: CGSize(width: 100.0, height: 100.0))
            }
        }
    }
    
    case grid(Grid)
    case balanced(Balanced)
    
    var contentHeight: CGFloat {
        switch self {
        case let .grid(grid):
            return grid.contentHeight
        case let .balanced(balanced):
            return balanced.contentHeight
        }
    }
    
    func visibleRange(rect: CGRect) -> (Int, Int) {
        switch self {
        case let .grid(grid):
            return grid.visibleRange(rect: rect)
        case let .balanced(balanced):
            return balanced.visibleRange(rect: rect)
        }
    }
    
    func frame(forItemAt index: Int, sideInset: CGFloat) -> CGRect {
        switch self {
        case let .grid(grid):
            return grid.frame(forItemAt: index, sideInset: sideInset)
        case let .balanced(balanced):
            return balanced.frame(forItemAt: index, sideInset: sideInset)
        }
    }
}

final class ChatListSearchMediaNode: ASDisplayNode, UIScrollViewDelegate {
    enum ContentType {
        case photoOrVideo
        case gifs
    }
    
    private let context: AccountContext
    private let contentType: ContentType
    
    private let scrollNode: ASScrollNode
    private let floatingHeaderNode: FloatingHeaderNode
    private var flashHeaderDelayTimer: Foundation.Timer?
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
        
    private let listDisposable = MetaDisposable()
    private var hiddenMediaDisposable: Disposable?
    private var mediaItems: [VisualMediaItem] = []
    private var itemsLayout: ItemsLayout?
    private var visibleMediaItems: [UInt32: VisualMediaItemNode] = [:]
    private var initialized = false
    
    private var decelerationAnimator: ConstantDisplayLinkAnimator?
    
    private var animationTimer: SwiftSignalKit.Timer?
    
    public var beganInteractiveDragging: (() -> Void)?
    public var loadMore: (() -> Void)?
    
    init(context: AccountContext, contentType: ContentType, openMessage: @escaping (Message, ChatControllerInteractionOpenMessageMode) -> Void, messageContextAction: @escaping (Message, ASDisplayNode?, CGRect?, UIGestureRecognizer?) -> Void, toggleMessageSelection: @escaping (MessageId, Bool) -> Void) {
        self.context = context
        self.contentType = contentType
        
        self.scrollNode = ASScrollNode()
        self.floatingHeaderNode = FloatingHeaderNode()
        self.floatingHeaderNode.alpha = 0.0
                
        super.init()
        
        self._itemInteraction = VisualMediaItemInteraction(
            openMessage: { message in
                let _ = openMessage(message, .default)
            },
            openMessageContextActions: { message, sourceNode, sourceRect, gesture in
                messageContextAction(message, sourceNode, sourceRect, gesture)
            },
            toggleSelection: { id, value in
                toggleMessageSelection(id, value)
            }
        )
        
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        self.scrollNode.view.showsVerticalScrollIndicator = true
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delegate = self
        
        self.addSubnode(self.scrollNode)
        self.addSubnode(self.floatingHeaderNode)
        
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
            for (_, itemNode) in strongSelf.visibleMediaItems {
                itemNode.updateHiddenMedia()
            }
        })
    }
    
    deinit {
        self.listDisposable.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.animationTimer?.invalidate()
    }
    
    func updateHistory(entries: [ChatListSearchEntry]?, totalCount: Int32, updateType: ViewUpdateType) {
        switch updateType {
        case .FillHole:
            break
        default:
            self.mediaItems.removeAll()
            
            var index: UInt32 = 0
            if let entries = entries {   
                for entry in entries {
                    if case let .message(message, _, _, _, _, _, _, _, _, _, _) = entry {
                        self.mediaItems.append(VisualMediaItem(message: message._asMessage(), index: nil))
                    }
                    index += 1
                }
            }
            self.itemsLayout = nil
            
            self.initialized = true
            
            if let (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData) = self.currentParams {
                self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expandProgress, presentationData: presentationData, synchronous: true, transition: .immediate)
                if !self.didSetReady {
                    self.didSetReady = true
                    self.ready.set(.single(true))
                }
            }
        }
    }
    
    func scrollToTop() -> Bool {
        if self.scrollNode.view.contentOffset.y > 0.0 {
            self.scrollNode.view.setContentOffset(CGPoint(), animated: true)
            return true
        } else {
            return false
        }
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        for item in self.mediaItems {
            if item.message?.id == id {
                return item.message
            }
        }
        return nil
    }
    
    func updateHiddenMedia() {
        for (_, itemNode) in self.visibleMediaItems {
            itemNode.updateHiddenMedia()
        }
    }
        
    func cancelPreviewGestures() {
        for (_, itemNode) in self.visibleMediaItems {
            itemNode.cancelPreviewGesture()
        }
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        for item in self.mediaItems {
            if let message = item.message, message.id == messageId {
                if let itemNode = self.visibleMediaItems[message.stableId] {
                    return itemNode.transitionNode()
                }
                break
            }
        }
        return nil
    }
    
    func addToTransitionSurface(view: UIView) {
        self.scrollNode.view.addSubview(view)
    }
    
    var selectedMessageIds: Set<MessageId>? {
        didSet {
            self.itemInteraction.selectedMessageIds = self.selectedMessageIds
        }
    }
    
    func updateSelectedMessages(animated: Bool) {
        for (_, itemNode) in self.visibleMediaItems {
            itemNode.updateSelectionState(animated: animated)
        }
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        let previousParams = self.currentParams
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)
                
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        
        let availableWidth = size.width - sideInset * 2.0
        
        let itemsLayout: ItemsLayout
        if let current = self.itemsLayout, previousParams?.size.width == size.width {
            itemsLayout = current
        } else {
            switch self.contentType {
            case .photoOrVideo, .gifs:
                itemsLayout = .grid(ItemsLayout.Grid(containerWidth: availableWidth, itemCount: self.mediaItems.count, bottomInset: bottomInset))
            /*case .gifs:
                itemsLayout = .balanced(ItemsLayout.Balanced(containerWidth: availableWidth, items: self.mediaItems, bottomInset: bottomInset))*/
            }
            self.itemsLayout = itemsLayout
        }
        
        self.scrollNode.view.contentSize = CGSize(width: size.width, height: itemsLayout.contentHeight)
        self.updateVisibleItems(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, theme: presentationData.theme, strings: presentationData.strings, synchronousLoad: synchronous)
        
        if isScrollingLockedAtTop {
            if self.scrollNode.view.contentOffset.y > .ulpOfOne {
                transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size))
            }
        }
        self.scrollNode.view.isScrollEnabled = !isScrollingLockedAtTop
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.decelerationAnimator?.isPaused = true
        self.decelerationAnimator = nil
        
        for (_, itemNode) in self.visibleMediaItems {
            itemNode.cancelPreviewGesture()
        }
        
        self.updateHeaderFlashing(animated: true)
        
        self.beganInteractiveDragging?()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let (size, sideInset, bottomInset, visibleHeight, _, _, presentationData) = self.currentParams {
            self.updateVisibleItems(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, theme: presentationData.theme, strings: presentationData.strings, synchronousLoad: false)
            
            if scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.bounds.height * 2.0 {
                self.loadMore?()
            }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            self.isDeceleratingAfterTracking = true
            self.updateHeaderFlashing(animated: true)
        } else {
            self.isDeceleratingAfterTracking = false
            self.resetHeaderFlashTimer(start: true)
            self.updateHeaderFlashing(animated: true)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.isDeceleratingAfterTracking = false
        self.resetHeaderFlashTimer(start: true)
        self.updateHeaderFlashing(animated: true)
    }
    
    private func updateVisibleItems(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, theme: PresentationTheme, strings: PresentationStrings, synchronousLoad: Bool) {
        guard let itemsLayout = self.itemsLayout else {
            return
        }
        
        let headerItemMinY = self.scrollNode.view.bounds.minY + 20.0
        let activeRect = self.scrollNode.view.bounds
        let visibleRect = activeRect.insetBy(dx: 0.0, dy: -400.0)
        
        let (minVisibleIndex, maxVisibleIndex) = itemsLayout.visibleRange(rect: visibleRect)
        
        var headerItem: Message?
        
        var validIds = Set<UInt32>()
        if minVisibleIndex <= maxVisibleIndex {
            for i in minVisibleIndex ... maxVisibleIndex {
                let stableId = self.mediaItems[i].stableId
                validIds.insert(stableId)
                
                let itemFrame = itemsLayout.frame(forItemAt: i, sideInset: sideInset)
                
                let itemNode: VisualMediaItemNode
                if let current = self.visibleMediaItems[stableId] {
                    itemNode = current
                } else {
                    itemNode = VisualMediaItemNode(context: self.context, interaction: self.itemInteraction)
                    self.visibleMediaItems[stableId] = itemNode
                    self.scrollNode.addSubnode(itemNode)
                }
                itemNode.frame = itemFrame
                itemNode.updateAbsoluteRect(itemFrame, within: self.scrollNode.view.bounds.size)
                if headerItem == nil && itemFrame.maxY > headerItemMinY {
                    headerItem = self.mediaItems[i].message
                }
                var itemSynchronousLoad = false
                if itemFrame.maxY <= visibleHeight {
                    itemSynchronousLoad = synchronousLoad
                }
                itemNode.update(size: itemFrame.size, item: self.mediaItems[i], theme: theme, synchronousLoad: itemSynchronousLoad)
                itemNode.updateIsVisible(itemFrame.intersects(activeRect))
            }
        }
        var removeKeys: [UInt32] = []
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
        
        if let headerItem = headerItem {
            let (year, month) = listMessageDateHeaderInfo(timestamp: headerItem.timestamp)
            let headerSize = self.floatingHeaderNode.update(constrainedWidth: size.width, year: year, month: month, theme: theme, strings: strings)
            self.floatingHeaderNode.frame = CGRect(origin: CGPoint(x: floor((size.width - headerSize.width) / 2.0), y: 7.0), size: headerSize)
            self.floatingHeaderNode.isHidden = false
        } else {
            self.floatingHeaderNode.isHidden = true
        }
    }
    
    private func resetHeaderFlashTimer(start: Bool, duration: Double = 0.3) {
        if let flashHeaderDelayTimer = self.flashHeaderDelayTimer {
            flashHeaderDelayTimer.invalidate()
            self.flashHeaderDelayTimer = nil
        }
        
        if start {
            final class TimerProxy: NSObject {
                private let action: () -> ()
                
                init(_ action: @escaping () -> ()) {
                    self.action = action
                    super.init()
                }
                
                @objc func timerEvent() {
                    self.action()
                }
            }
            
            let timer = Timer(timeInterval: duration, target: TimerProxy { [weak self] in
                if let strongSelf = self {
                    if let flashHeaderDelayTimer = strongSelf.flashHeaderDelayTimer {
                        flashHeaderDelayTimer.invalidate()
                        strongSelf.flashHeaderDelayTimer = nil
                        strongSelf.updateHeaderFlashing(animated: true)
                    }
                }
            }, selector: #selector(TimerProxy.timerEvent), userInfo: nil, repeats: false)
            self.flashHeaderDelayTimer = timer
            RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
            self.updateHeaderFlashing(animated: true)
        }
    }
    
    private func headerIsFlashing() -> Bool {
        return self.scrollNode.view.isDragging || self.isDeceleratingAfterTracking || self.flashHeaderDelayTimer != nil
    }
    
    private func updateHeaderFlashing(animated: Bool) {
        let flashing = self.headerIsFlashing()
        let alpha: CGFloat = flashing ? 1.0 : 0.0
        let previousAlpha = self.floatingHeaderNode.alpha
        
        if !previousAlpha.isEqual(to: alpha) {
            self.floatingHeaderNode.alpha = alpha
            if animated {
                let duration: Double = flashing ? 0.3 : 0.4
                self.floatingHeaderNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: duration)
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if self.decelerationAnimator != nil {
            self.decelerationAnimator?.isPaused = true
            self.decelerationAnimator = nil
            
            return self.scrollNode.view
        }
        return result
    }
}

private func calculateItemFrames(items: [VisualMediaItem], containerWidth: CGFloat) -> [CGRect] {
    var frames: [CGRect] = []
    
    var rowsCount = 0
    var firstRowMax = 0;
    
    let viewPortAvailableSize = containerWidth
    
    let preferredRowSize: CGFloat = 100.0
    let itemsCount = items.count
    let spanCount: CGFloat = 100.0
    var spanLeft = spanCount
    var currentItemsInRow = 0
    var currentItemsSpanAmount: CGFloat = 0.0
    
    var itemSpans: [Int: CGFloat] = [:]
    var itemsToRow: [Int: Int] = [:]
    
    for a in 0 ..< itemsCount {
        var size: CGSize = items[a].dimensions
        if size.width <= 0.0 {
            size.width = 100.0
        }
        if size.height <= 0.0 {
            size.height = 100.0
        }
        let aspect: CGFloat = size.width / size.height
        if aspect > 4.0 || aspect < 0.2 {
            size.width = max(size.width, size.height)
            size.height = size.width
        }

        var requiredSpan = min(spanCount, floor(spanCount * (size.width / size.height * preferredRowSize / viewPortAvailableSize)))
        let moveToNewRow = spanLeft < requiredSpan || requiredSpan > 33.0 && spanLeft < requiredSpan - 15.0
        if moveToNewRow {
            if spanLeft > 0 {
                let spanPerItem = floor(spanLeft / CGFloat(currentItemsInRow))
                
                let start = a - currentItemsInRow
                var b = start
                while b < start + currentItemsInRow {
                    if (b == start + currentItemsInRow - 1) {
                        itemSpans[b] = itemSpans[b]! + spanLeft
                    } else {
                        itemSpans[b] = itemSpans[b]! + spanPerItem
                    }
                    spanLeft -= spanPerItem;
                    
                    b += 1
                }
                
                itemsToRow[a - 1] = rowsCount
            }
            rowsCount += 1
            currentItemsSpanAmount = 0
            currentItemsInRow = 0
            spanLeft = spanCount
        } else {
            if spanLeft < requiredSpan {
                requiredSpan = spanLeft
            }
        }
        if rowsCount == 0 {
            firstRowMax = max(firstRowMax, a)
        }
        if a == itemsCount - 1 {
            itemsToRow[a] = rowsCount
        }
        currentItemsSpanAmount += requiredSpan
        currentItemsInRow += 1
        spanLeft -= requiredSpan
        spanLeft = max(0, spanLeft)

        itemSpans[a] = requiredSpan
    }
    if itemsCount != 0 {
        rowsCount += 1
    }
    
    var verticalOffset: CGFloat = 1.0
    
    var currentRowHorizontalOffset: CGFloat = 0.0
    for index in 0 ..< items.count {
        guard let width = itemSpans[index] else {
            continue
        }
        let itemWidth = floor(width * containerWidth / 100.0) - 1
        
        var itemSize = CGSize(width: itemWidth, height: preferredRowSize)
        if itemsToRow[index] != nil && currentRowHorizontalOffset + itemSize.width >= containerWidth - 10.0 {
            itemSize.width = max(itemSize.width, containerWidth - currentRowHorizontalOffset)
        }
        frames.append(CGRect(origin: CGPoint(x: currentRowHorizontalOffset, y: verticalOffset), size: itemSize))
        currentRowHorizontalOffset += itemSize.width + 1.0
        
        if itemsToRow[index] != nil {
            verticalOffset += preferredRowSize + 1.0
            currentRowHorizontalOffset = 0.0
        }
    }
    
    return frames
}
