import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import RadialStatusNode
import TelegramStringFormatting
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
        
        self.containerNode.activated = { [weak self] gesture in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            strongSelf.interaction.openMessageContextActions(item.0.message, strongSelf.containerNode, strongSelf.containerNode.bounds, gesture)
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
    }
    
    @objc func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                if case .tap = gesture {
                    if let (item, _, _, _) = self.item {
                        self.interaction.openMessage(item.message)
                    }
                }
            }
        }
    }
    
    func update(size: CGSize, item: VisualMediaItem, theme: PresentationTheme, synchronousLoad: Bool) {
        if item === self.item?.0 && size == self.item?.2 {
            return
        }
        self.theme = theme
        var media: Media?
        for value in item.message.media {
            if let image = value as? TelegramMediaImage {
                media = image
                break
            } else if let file = value as? TelegramMediaFile {
                media = file
                break
            }
        }
        
        if let media = media, (self.item?.1 == nil || !media.isEqual(to: self.item!.1!)) {
            var mediaDimensions: CGSize?
            if let image = media as? TelegramMediaImage, let largestSize = largestImageRepresentation(image.representations)?.dimensions {
                mediaDimensions = largestSize.cgSize
               
                self.imageNode.setSignal(mediaGridMessagePhoto(account: context.account, photoReference: .message(message: MessageReference(item.message), media: image), fullRepresentationSize: CGSize(width: 300.0, height: 300.0), synchronousLoad: synchronousLoad), attemptSynchronously: synchronousLoad, dispatchOnDisplayLink: true)
                
                self.fetchStatusDisposable.set(nil)
                self.statusNode.transitionToState(.none, completion: { [weak self] in
                    self?.statusNode.isHidden = true
                })
                self.mediaBadgeNode.isHidden = true
                self.resourceStatus = nil
            } else if let file = media as? TelegramMediaFile, file.isVideo {
                mediaDimensions = file.dimensions?.cgSize
                self.imageNode.setSignal(mediaGridMessageVideo(postbox: context.account.postbox, videoReference: .message(message: MessageReference(item.message), media: file), synchronousLoad: synchronousLoad, autoFetchFullSizeThumbnail: true), attemptSynchronously: synchronousLoad)
                
                self.mediaBadgeNode.isHidden = false
                
                self.resourceStatus = nil
                self.fetchStatusDisposable.set((messageMediaFileStatus(context: context, messageId: item.message.id, file: file) |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self, let (item, _, _, _) = strongSelf.item {
                        strongSelf.resourceStatus = status
                        
                        let isStreamable = isMediaStreamable(message: item.message, media: file)
                        
                        let statusState: RadialStatusNodeState = .none
                        /*if isStreamable {
                            statusState = .none
                        } else {
                            switch status {
                                case let .Fetching(_, progress):
                                    let adjustedProgress = max(progress, 0.027)
                                    statusState = .progress(color: .white, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true)
                                case .Local:
                                    statusState = .none
                                case .Remote:
                                    statusState = .download(.white)
                            }
                        }*/
                        
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
            
            let progressDiameter: CGFloat = 40.0
            self.statusNode.frame = CGRect(origin: CGPoint(x: floor((size.width - progressDiameter) / 2.0), y: floor((size.height - progressDiameter) / 2.0)), size: CGSize(width: progressDiameter, height: progressDiameter))
            
            self.mediaBadgeNode.frame = CGRect(origin: CGPoint(x: size.width - 3.0, y: size.height - 18.0 - 3.0), size: CGSize(width: 50.0, height: 50.0))
            
            self.selectionNode?.frame = CGRect(origin: CGPoint(), size: size)
            
            self.updateHiddenMedia()
        }
        
        if let (item, media, _, mediaDimensions) = self.item {
            self.item = (item, media, size, mediaDimensions)
            
            let imageFrame = CGRect(origin: CGPoint(), size: size)
            
            self.containerNode.frame = imageFrame
            self.imageNode.frame = imageFrame
            
            if let mediaDimensions = mediaDimensions {
                let imageSize = mediaDimensions.aspectFilled(imageFrame.size)
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets(), emptyColor: theme.list.mediaPlaceholderColor))()
            }
            
            self.updateSelectionState(animated: false)
        }
    }
    
    func updateSelectionState(animated: Bool) {
        if let (item, media, _, mediaDimensions) = self.item, let theme = self.theme {
            self.containerNode.isGestureEnabled = self.interaction.selectedMessageIds == nil
            
            if let selectedIds = self.interaction.selectedMessageIds {
                let selected = selectedIds.contains(item.message.id)
                
                if let selectionNode = self.selectionNode {
                    selectionNode.updateSelected(selected, animated: animated)
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                } else {
                    let selectionNode = GridMessageSelectionNode(theme: theme, toggle: { [weak self] value in
                        if let strongSelf = self, let messageId = strongSelf.item?.0.message.id {
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
            let view = imageNode?.view.snapshotContentTree(unhide: true)
            if let strongSelf = self {
                strongSelf.statusNode.isHidden = statusNodeHidden
                strongSelf.mediaBadgeNode.isHidden = accessoryHidden
            }
            return (view, nil)
        })
    }
    
    func updateHiddenMedia() {
        if let (item, _, _, _) = self.item {
            if let _ = self.interaction.hiddenMedia[item.message.id] {
                self.isHidden = true
            } else {
                self.isHidden = false
            }
        } else {
            self.isHidden = false
        }
    }
}

private final class VisualMediaItem {
    let message: Message
    
    init(message: Message) {
        self.message = message
    }
}

final class PeerInfoVisualMediaPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let peerId: PeerId
    private let chatControllerInteraction: ChatControllerInteraction
    
    private let scrollNode: ASScrollNode
    
    private var _itemInteraction: VisualMediaItemInteraction?
    private var itemInteraction: VisualMediaItemInteraction {
        return self._itemInteraction!
    }
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
    
    private let listDisposable = MetaDisposable()
    private var hiddenMediaDisposable: Disposable?
    private var mediaItems: [VisualMediaItem] = []
    private var visibleMediaItems: [UInt32: VisualMediaItemNode] = [:]
    
    private var numberOfItemsToRequest: Int = 50
    private var currentView: MessageHistoryView?
    private var isRequestingView: Bool = false
    private var isFirstHistoryView: Bool = true
    
    private var decelerationAnimator: ConstantDisplayLinkAnimator?
    
    init(context: AccountContext, chatControllerInteraction: ChatControllerInteraction, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        
        self.scrollNode = ASScrollNode()
        
        super.init()
        
        self._itemInteraction = VisualMediaItemInteraction(
            openMessage: { [weak self] message in
                self?.chatControllerInteraction.openMessage(message, .default)
            },
            openMessageContextActions: { [weak self] message, sourceNode, sourceRect, gesture in
                self?.chatControllerInteraction.openMessageContextActions(message, sourceNode, sourceRect, gesture)
            },
            toggleSelection: { [weak self] id, value in
                self?.chatControllerInteraction.toggleMessagesSelection([id], value)
            }
        )
        self.itemInteraction.selectedMessageIds = chatControllerInteraction.selectionState.flatMap { $0.selectedIds }
        
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delegate = self
        
        self.addSubnode(self.scrollNode)
        
        self.requestHistoryAroundVisiblePosition()
        
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
    }
    
    private func requestHistoryAroundVisiblePosition() {
        if self.isRequestingView {
            return
        }
        self.isRequestingView = true
        self.listDisposable.set((self.context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(self.peerId), index: .upperBound, anchorIndex: .upperBound, count: self.numberOfItemsToRequest, fixedCombinedReadStates: nil, tagMask: .photoOrVideo)
        |> deliverOnMainQueue).start(next: { [weak self] (view, updateType, _) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateHistory(view: view, updateType: updateType)
            strongSelf.isRequestingView = false
        }))
    }
    
    private func updateHistory(view: MessageHistoryView, updateType: ViewUpdateType) {
        self.currentView = view
        
        self.mediaItems.removeAll()
        switch updateType {
        case .FillHole:
            self.requestHistoryAroundVisiblePosition()
        default:
            for entry in view.entries.reversed() {
                self.mediaItems.append(VisualMediaItem(message: entry.message))
            }
            
            let wasFirstHistoryView = self.isFirstHistoryView
            self.isFirstHistoryView = false
            
            if let (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, presentationData) = self.currentParams {
                self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, presentationData: presentationData, synchronous: wasFirstHistoryView, transition: .immediate)
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
            if item.message.id == id {
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
    
    func transferVelocity(_ velocity: CGFloat) {
        if velocity > 0.0 {
            //print("transferVelocity \(velocity)")
            self.decelerationAnimator?.isPaused = true
            let startTime = CACurrentMediaTime()
            var currentOffset = self.scrollNode.view.contentOffset
            let decelerationRate: CGFloat = 0.998
            self.decelerationAnimator = ConstantDisplayLinkAnimator(update: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let t = CACurrentMediaTime() - startTime
                var currentVelocity = velocity * 15.0 * CGFloat(pow(Double(decelerationRate), 1000.0 * t))
                //print("value at \(t) = \(currentVelocity)")
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
                
                if abs(currentVelocity) < 0.1 {
                    strongSelf.decelerationAnimator?.isPaused = true
                    strongSelf.decelerationAnimator = nil
                }
                var contentOffset = strongSelf.scrollNode.view.contentOffset
                contentOffset.y = floorToScreenPixels(currentOffset.y)
                strongSelf.scrollNode.view.setContentOffset(contentOffset, animated: false)
            })
            self.decelerationAnimator?.isPaused = false
        }
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        for item in self.mediaItems {
            if item.message.id == messageId {
                if let itemNode = self.visibleMediaItems[item.message.stableId] {
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
    
    func updateSelectedMessages(animated: Bool) {
        self.itemInteraction.selectedMessageIds = self.chatControllerInteraction.selectionState.flatMap { $0.selectedIds }
        for (_, itemNode) in self.visibleMediaItems {
            itemNode.updateSelectionState(animated: animated)
        }
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, presentationData)
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let itemSpacing: CGFloat = 1.0
        let itemsInRow: Int = max(3, min(6, Int(size.width / 100.0)))
        let itemSize: CGFloat = floor(size.width / CGFloat(itemsInRow))
        
        let rowCount: Int = self.mediaItems.count / itemsInRow + (self.mediaItems.count % itemsInRow == 0 ? 0 : 1)
        let contentHeight = CGFloat(rowCount + 1) * itemSpacing + CGFloat(rowCount) * itemSize + bottomInset
        
        self.scrollNode.view.contentSize = CGSize(width: size.width, height: contentHeight)
        self.updateVisibleItems(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, theme: presentationData.theme, synchronousLoad: synchronous)
        
        if isScrollingLockedAtTop {
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size))
        }
        self.scrollNode.view.isScrollEnabled = !isScrollingLockedAtTop
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.decelerationAnimator?.isPaused = true
        self.decelerationAnimator = nil
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let (size, sideInset, bottomInset, visibleHeight, _, presentationData) = self.currentParams {
            self.updateVisibleItems(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, theme: presentationData.theme, synchronousLoad: false)
            
            if scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.bounds.height * 2.0, let currentView = self.currentView, currentView.earlierId != nil {
                if !self.isRequestingView {
                    self.numberOfItemsToRequest += 50
                    self.requestHistoryAroundVisiblePosition()
                }
            }
        }
    }
    
    private func updateVisibleItems(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, theme: PresentationTheme, synchronousLoad: Bool) {
        let availableWidth = size.width - sideInset * 2.0
        
        let itemSpacing: CGFloat = 1.0
        let itemsInRow: Int = max(3, min(6, Int(availableWidth / 140.0)))
        let itemSize: CGFloat = floor(availableWidth / CGFloat(itemsInRow))
        
        let rowCount: Int = self.mediaItems.count / itemsInRow + (self.mediaItems.count % itemsInRow == 0 ? 0 : 1)
        
        let visibleRect = self.scrollNode.view.bounds
        var minVisibleRow = Int(floor((visibleRect.minY - itemSpacing) / (itemSize + itemSpacing)))
        minVisibleRow = max(0, minVisibleRow)
        var maxVisibleRow = Int(ceil((visibleRect.maxY - itemSpacing) / (itemSize + itemSpacing)))
        maxVisibleRow = min(rowCount - 1, maxVisibleRow)
        
        let minVisibleIndex = minVisibleRow * itemsInRow
        let maxVisibleIndex = min(self.mediaItems.count - 1, (maxVisibleRow + 1) * itemsInRow - 1)
        
        var validIds = Set<UInt32>()
        if minVisibleIndex <= maxVisibleIndex {
            for i in minVisibleIndex ... maxVisibleIndex {
                let stableId = self.mediaItems[i].message.stableId
                validIds.insert(stableId)
                let rowIndex = i / Int(itemsInRow)
                let columnIndex = i % Int(itemsInRow)
                let itemOrigin = CGPoint(x: sideInset + CGFloat(columnIndex) * (itemSize + itemSpacing), y: itemSpacing + CGFloat(rowIndex) * (itemSize + itemSpacing))
                let itemFrame = CGRect(origin: itemOrigin, size: CGSize(width: columnIndex == itemsInRow ? (availableWidth - itemOrigin.x) : itemSize, height: itemSize))
                let itemNode: VisualMediaItemNode
                if let current = self.visibleMediaItems[stableId] {
                    itemNode = current
                } else {
                    itemNode = VisualMediaItemNode(context: self.context, interaction: self.itemInteraction)
                    self.visibleMediaItems[stableId] = itemNode
                    self.scrollNode.addSubnode(itemNode)
                }
                itemNode.frame = itemFrame
                var itemSynchronousLoad = false
                if itemFrame.maxY <= visibleHeight {
                    itemSynchronousLoad = synchronousLoad
                }
                itemNode.update(size: itemFrame.size, item: self.mediaItems[i], theme: theme, synchronousLoad: itemSynchronousLoad)
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
