import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ContextUI
import ComponentFlow
import CheckNode
import ChatControllerInteraction
import DirectMediaImageCache
import SparseItemGrid
import TelegramNotices
import TelegramStringFormatting
import PeerInfoPaneNode
import MediaGrid

private final class MediaGridPaneHostNode: ASDisplayNode {
    let gridView: MediaGridView

    init(gridView: MediaGridView) {
        self.gridView = gridView
        super.init()
        self.view.addSubview(gridView)
    }

    override func layout() {
        super.layout()
        self.gridView.frame = self.bounds
    }
}

public final class PeerInfoMediaGridPaneNode: ASDisplayNode, PeerInfoVisualMediaPane, MediaGridPaneCellProvider, SparseItemGridScrollingTarget {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let chatLocation: ChatLocation
    private let chatControllerInteraction: ChatControllerInteraction
    public private(set) var contentType: PeerInfoVisualMediaPaneNode.ContentType
    private let contentTypePromise: ValuePromise<PeerInfoVisualMediaPaneNode.ContentType>
    private let stateTag: EngineMessage.Tags
    private var initialMessageIndex: EngineMessage.Index?

    public weak var parentController: ViewController?

    private let directMediaImageCache: DirectMediaImageCache
    private let dataSource: MediaGridPaneDataSource
    private let gridView: MediaGridView
    private let hostNode: MediaGridPaneHostNode
    private let contextGestureContainerNode: ContextControllerSourceNode
    private let scrollingArea: SparseItemGridScrollingArea

    private var listSource: SparseMessageList
    public private(set) var calendarSource: SparseMessageCalendar?
    private let listDisposable = MetaDisposable()
    private var listGeneration = 0
    private var stateGate = MediaGridPaneStateGate<SparseMessageList.State>()
    private var isLoadingHole = false
    private var didReceiveState = false

    private var hiddenMedia: [EngineMessage.Id: [EngineMedia]] = [:]
    private var hiddenMediaDisposable: Disposable?
    private var revealedSpoilerMessageIds = Set<EngineMessage.Id>()
    private var storedStateDisposable: Disposable?
    private var presentationDataDisposable: Disposable?
    private var presentationData: PresentationData
    private(set) var checkTheme: CheckNodeTheme
    private(set) var shimmerColors: MediaGridPaneShimmerColors

    private var currentParams: (size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    private var coveringInsetOffset: CGFloat = 0.0
    private var previousScrollOffset: CGFloat = 0.0
    private var isFastScrolling = false
    private var touchActionsDisabled = false
    private var processedOnBeginFastScrolling = false
    private var currentScrollingTag: Int32?
    private var scrollerTextCache: (tag: Int32, strings: PresentationStrings, text: String)?
    private let shimmeringCells = NSHashTable<MediaGridPaneCellLayer>.weakObjects()
    private var readyRowStarts = Set<Int>()
    private var readyRowsColumns = 0
    private var gestureIndex: Int?

    private let ready = Promise<Bool>()
    private var didSetReady = false
    public var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    private let statusPromise = Promise<PeerInfoStatusData?>(nil)
    public var status: Signal<PeerInfoStatusData?, NoError> {
        return self.statusPromise.get()
    }

    public var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    public var tabBarOffset: CGFloat {
        return self.coveringInsetOffset
    }

    public var openCurrentDate: (() -> Void)?
    public var paneDidScroll: (() -> Void)?

    public init(context: AccountContext, chatControllerInteraction: ChatControllerInteraction, peerId: EnginePeer.Id, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, contentType: PeerInfoVisualMediaPaneNode.ContentType, captureProtected: Bool, initialFocusMessageIndex: EngineMessage.Index?) {
        self.context = context
        self.peerId = peerId
        self.chatLocation = chatLocation
        self.chatControllerInteraction = chatControllerInteraction
        self.contentType = contentType
        self.contentTypePromise = ValuePromise(contentType)
        self.stateTag = tagMaskForType(contentType)
        self.initialMessageIndex = initialFocusMessageIndex

        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.checkTheme = CheckNodeTheme(theme: self.presentationData.theme, style: .overlay, hasInset: true)
        self.shimmerColors = PeerInfoMediaGridPaneNode.shimmerColors(theme: self.presentationData.theme)

        self.directMediaImageCache = DirectMediaImageCache(account: context.account)
        self.dataSource = MediaGridPaneDataSource(directMediaImageCache: self.directMediaImageCache)
        var cellProvider: (() -> MediaGridPaneCellProvider?)?
        self.gridView = MediaGridView(dataSource: self.dataSource, cellFactory: {
            let cell = MediaGridPaneCellLayer()
            cell.provider = cellProvider?()
            return cell
        })
        self.gridView.availableLevels = [.three, .five, .fifteen]
        self.gridView.compactLevelsRequestSharpImages = true
        self.gridView.isSelectionPanEnabled = false
        self.hostNode = MediaGridPaneHostNode(gridView: self.gridView)
        self.contextGestureContainerNode = ContextControllerSourceNode()
        self.scrollingArea = SparseItemGridScrollingArea()

        let threadId = chatLocation.threadId
        self.listSource = context.engine.messages.sparseMessageList(peerId: peerId, threadId: threadId, tag: tagMaskForType(contentType), initialMessageIndex: initialFocusMessageIndex)
        if threadId == nil {
            self.calendarSource = context.engine.messages.sparseMessageCalendar(peerId: peerId, threadId: nil, tag: tagMaskForType(contentType), displayMedia: true)
        } else {
            self.calendarSource = nil
        }

        super.init()

        cellProvider = { [weak self] in
            return self
        }

        self.contextGestureContainerNode.addSubnode(self.hostNode)
        self.addSubnode(self.contextGestureContainerNode)
        self.addSubnode(self.scrollingArea)

        self.setupGrid()
        self.setupScrollingArea()
        self.setupContextGesture()
        self.setupStatus()

        self.storedStateDisposable = (visualMediaStoredState(engine: context.engine, peerId: peerId, messageTag: self.stateTag)
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else {
                return
            }
            let columns = mediaGridPaneLevelColumns(storedColumns: value?.zoomLevel)
            if let level = MediaGridLevel(rawValue: columns) {
                self.gridView.setLevel(level, animated: false)
            }
            self.subscribeToList()
        })

        self.hiddenMediaDisposable = context.sharedContext.mediaManager.galleryHiddenMediaManager.hiddenIds().start(next: { [weak self] ids in
            guard let self else {
                return
            }
            var hiddenMedia: [EngineMessage.Id: [EngineMedia]] = [:]
            for id in ids {
                if case let .chat(accountId, messageId, media) = id, accountId == self.context.account.id {
                    hiddenMedia[messageId] = [EngineMedia(media)]
                }
            }
            self.hiddenMedia = hiddenMedia
            for id in hiddenMedia.keys {
                if let index = self.dataSource.index(of: id), let frame = self.gridView.frameForItem(at: index), !self.gridView.bounds.intersects(frame) {
                    self.scrollToItem(index: index)
                    break
                }
            }
            self.updateHiddenMedia()
        })

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            self.presentationData = presentationData
            self.checkTheme = CheckNodeTheme(theme: presentationData.theme, style: .overlay, hasInset: true)
            self.shimmerColors = PeerInfoMediaGridPaneNode.shimmerColors(theme: presentationData.theme)
            self.refreshVisibleCells(animated: false)
        })

        let _ = (ApplicationSpecificNotice.getSharedMediaScrollingTooltip(accountManager: context.sharedContext.accountManager)
        |> deliverOnMainQueue).start(next: { [weak self] count in
            guard let self, count < 1 else {
                return
            }
            self.scrollingArea.displayTooltip = SparseItemGridScrollingArea.DisplayTooltip(animation: "anim_infotip", text: self.presentationData.strings.SharedMedia_FastScrollTooltip, completed: { [weak self] in
                guard let self else {
                    return
                }
                let _ = ApplicationSpecificNotice.incrementSharedMediaScrollingTooltip(accountManager: self.context.sharedContext.accountManager, count: 1).start()
            })
        })
    }

    deinit {
        self.listDisposable.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.storedStateDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
    }

    private static func shimmerColors(theme: PresentationTheme) -> MediaGridPaneShimmerColors {
        return MediaGridPaneShimmerColors(background: theme.list.mediaPlaceholderColor, foreground: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.6))
    }

    var shimmerViewport: (offset: CGFloat, height: CGFloat) {
        return (self.gridView.contentOffset, self.gridView.bounds.height)
    }

    func cellState(at index: Int) -> MediaGridPaneCellState? {
        guard let message = self.dataSource.message(at: index) else {
            return nil
        }
        let rawMessage = message._asMessage()
        var hasSpoiler = rawMessage.attributes.contains(where: { $0 is MediaSpoilerMessageAttribute }) && !self.revealedSpoilerMessageIds.contains(message.id)
        if rawMessage.isSensitiveContent(platform: "ios", contentSettings: self.context.currentContentSettings.with { $0 }) {
            hasSpoiler = true
        }
        let isHidden = self.hiddenMedia[message.id] != nil
        if isHidden {
            hasSpoiler = false
        }
        var duration: Int32?
        var isLivePhoto = false
        let selectedMedia = mediaGridPaneSelectedMedia(message)
        if case let .image(image) = selectedMedia, image.video != nil {
            isLivePhoto = true
        } else if case let .file(file) = selectedMedia, !file.isAnimated {
            duration = file.duration.flatMap { Int32(floor($0)) }
        }
        var spoilerImage: UIImage?
        if hasSpoiler, let thumbnail = self.dataSource.thumbnail(at: index) {
            spoilerImage = UIImage(cgImage: thumbnail.image)
        }
        let isSelected = self.chatControllerInteraction.selectionState.flatMap { $0.selectedIds.contains(message.id) }
        return MediaGridPaneCellState(duration: duration, isLivePhoto: isLivePhoto, hasSpoiler: hasSpoiler, spoilerImage: spoilerImage, isSelected: isSelected, isHidden: isHidden)
    }

    func shimmerDidChange(_ cell: MediaGridPaneCellLayer, isActive: Bool) {
        if isActive {
            self.shimmeringCells.add(cell)
        } else {
            self.shimmeringCells.remove(cell)
        }
    }

    func isRowReady(at index: Int) -> Bool {
        let columns = max(1, self.gridView.level.columns)
        if self.readyRowsColumns != columns {
            self.readyRowsColumns = columns
            self.readyRowStarts.removeAll()
        }
        let rowStart = (index / columns) * columns
        if self.readyRowStarts.contains(rowStart) {
            return true
        }
        let dataSource = self.dataSource
        let isReady = mediaGridPaneRowIsReady(index: index, columns: columns, count: dataSource.count, isEndKnown: dataSource.isEndKnown, isReady: { dataSource.isContentReady(at: $0) })
        if isReady {
            self.readyRowStarts.insert(rowStart)
        }
        return isReady
    }

    private func revealReadyRows() {
        let columns = max(1, self.gridView.level.columns)
        var pending: [(index: Int, cell: MediaGridPaneCellLayer)] = []
        self.gridView.forEachCell { index, cell in
            guard let cell = cell as? MediaGridPaneCellLayer, !cell.isRevealed, self.isRowReady(at: index) else {
                return
            }
            pending.append((index, cell))
        }
        let delays = mediaGridPaneRevealDelays(rows: pending.map { $0.index / columns })
        for (index, cell) in pending {
            cell.reveal(delay: delays[index / columns] ?? 0.0)
        }
    }

    private func setupGrid() {
        self.dataSource.onThumbnailsReady = { [weak self] indices in
            guard let self else {
                return
            }
            self.gridView.thumbnailsDidChange(indices: indices)
            self.gridView.forEachCell { index, cell in
                if indices.contains(index) {
                    (cell as? MediaGridPaneCellLayer)?.refresh(animated: false)
                }
            }
            self.revealReadyRows()
        }
        self.gridView.onTapItem = { [weak self] index in
            self?.handleTap(index: index)
        }
        self.gridView.isItemSelected = { [weak self] index in
            guard let self, let message = self.dataSource.message(at: index) else {
                return false
            }
            return self.chatControllerInteraction.selectionState?.selectedIds.contains(message.id) ?? false
        }
        self.gridView.onSelectionPan = { [weak self] index, selected in
            guard let self, let message = self.dataSource.message(at: index) else {
                return
            }
            self.chatControllerInteraction.toggleMessagesSelection([message.id], selected)
        }
        self.gridView.onLevelChanged = { [weak self] level in
            guard let self else {
                return
            }
            let _ = updateVisualMediaStoredState(engine: self.context.engine, peerId: self.peerId, messageTag: self.stateTag, state: VisualMediaStoredState(zoomLevel: Int32(level.columns))).start()
        }
        self.gridView.onVisibleRangeChanged = { [weak self] _ in
            self?.updateHoleToLoad()
        }
        self.gridView.onWillBeginDragging = { [weak self] in
            self?.contextGestureContainerNode.cancelGesture()
        }
        self.gridView.onDidEndDragging = { [weak self] in
            guard let self, !self.gridView.isUserScrolling else {
                return
            }
            self.snapCoveringInsetOffset()
        }
        self.gridView.onScroll = { [weak self] offset in
            self?.gridDidScroll(offset: offset)
        }
        self.gridView.onZoomingChanged = { [weak self] isZooming in
            guard let self else {
                return
            }
            if isZooming {
                self.contextGestureContainerNode.cancelGesture()
            } else {
                self.applyHeldStateIfIdle()
                self.revealReadyRows()
                self.updateHoleToLoad()
            }
            self.updateScrollingArea()
        }
    }

    private func setupScrollingArea() {
        self.scrollingArea.beginScrolling = { [weak self] in
            guard let self else {
                return nil
            }
            self.isFastScrolling = true
            self.onBeginFastScrolling()
            return nil
        }
        self.scrollingArea.beginScrollingTarget = { [weak self] in
            return self
        }
        self.scrollingArea.finishedScrolling = { [weak self] in
            guard let self else {
                return
            }
            self.isFastScrolling = false
            self.snapCoveringInsetOffset()
        }
        self.scrollingArea.setContentOffset = { [weak self] offset in
            self?.gridView.setContentOffset(offset.y)
        }
        self.scrollingArea.openCurrentDate = { [weak self] in
            self?.openCurrentDate?()
        }
        self.scrollingArea.isDecelerating = { [weak self] in
            return self?.gridView.isUserScrolling ?? false
        }
    }

    private func setupContextGesture() {
        self.contextGestureContainerNode.shouldBegin = { [weak self] point in
            guard let self, !self.gridView.isZooming, self.gridView.level.isInteractive else {
                return false
            }
            if let result = self.view.hitTest(point, with: nil), result.asyncdisplaykit_node is SparseItemGridScrollingArea {
                return false
            }
            let gridPoint = self.gridView.convert(point, from: self.view)
            guard let index = self.gridView.index(at: gridPoint), self.dataSource.message(at: index) != nil else {
                return false
            }
            self.gestureIndex = index
            return true
        }
        self.contextGestureContainerNode.customActivationProgress = { [weak self] progress, update in
            guard let self, let index = self.gestureIndex, let cell = self.visibleCell(at: index) else {
                return
            }
            let scaleSide = cell.bounds.width
            let minScale: CGFloat = max(0.7, (scaleSide - 15.0) / scaleSide)
            let currentScale = 1.0 * (1.0 - progress) + minScale * progress
            let transform = CATransform3DMakeScale(currentScale, currentScale, 1.0)
            switch update {
            case .update, .begin:
                cell.transform = transform
            case .ended:
                let previousTransform = cell.transform
                cell.transform = transform
                cell.animate(from: NSValue(caTransform3D: previousTransform), to: NSValue(caTransform3D: transform), keyPath: "transform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
            }
        }
        self.contextGestureContainerNode.activated = { [weak self] gesture, _ in
            guard let self, let index = self.gestureIndex else {
                return
            }
            self.gestureIndex = nil
            guard let message = self.dataSource.message(at: index), let frame = self.gridView.frameForItem(at: index) else {
                return
            }
            let rect = self.view.convert(frame, from: self.gridView)
            self.chatControllerInteraction.openMessageContextActions(message._asMessage(), self, rect, gesture)
        }
    }

    private func setupStatus() {
        let context = self.context
        let peerId = self.peerId
        let threadId = self.chatLocation.threadId
        let counts: Signal<(PeerInfoVisualMediaPaneNode.ContentType, [EngineMessage.Tags: Int32]), NoError> = self.contentTypePromise.get()
        |> distinctUntilChanged
        |> mapToSignal { contentType -> Signal<(PeerInfoVisualMediaPaneNode.ContentType, [EngineMessage.Tags: Int32]), NoError> in
            return PeerInfoMediaGridPaneNode.mediaCounts(context: context, peerId: peerId, threadId: threadId, contentType: contentType)
        }
        let distinctCounts: Signal<(PeerInfoVisualMediaPaneNode.ContentType, [EngineMessage.Tags: Int32]), NoError> = counts
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs.0 == rhs.0 && lhs.1 == rhs.1
        })
        let status: Signal<PeerInfoStatusData?, NoError> = distinctCounts
        |> map { contentType, dict -> PeerInfoStatusData? in
            return PeerInfoMediaGridPaneNode.statusData(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, contentType: contentType, counts: dict)
        }
        self.statusPromise.set(status)
    }

    private static func mediaCounts(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64?, contentType: PeerInfoVisualMediaPaneNode.ContentType) -> Signal<(PeerInfoVisualMediaPaneNode.ContentType, [EngineMessage.Tags: Int32]), NoError> {
        var summaries: [EngineMessage.Tags] = []
        switch contentType {
        case .photoOrVideo:
            summaries.append(.photo)
            summaries.append(.video)
        case .photo:
            summaries.append(.photo)
        case .video:
            summaries.append(.video)
        default:
            break
        }
        let items = summaries.map { TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: peerId, threadId: threadId, tag: $0) }
        return context.engine.data.subscribe(EngineDataMap(items))
        |> map { summaries -> (PeerInfoVisualMediaPaneNode.ContentType, [EngineMessage.Tags: Int32]) in
            var result: [EngineMessage.Tags: Int32] = [:]
            for (key, count) in summaries {
                result[key.tag] = count.flatMap(Int32.init) ?? 0
            }
            return (contentType, result)
        }
    }

    private static func statusData(strings: PresentationStrings, contentType: PeerInfoVisualMediaPaneNode.ContentType, counts: [EngineMessage.Tags: Int32]) -> PeerInfoStatusData? {
        let photoCount: Int32 = counts[.photo] ?? 0
        let videoCount: Int32 = counts[.video] ?? 0
        switch contentType {
        case .photoOrVideo:
            if photoCount != 0 && videoCount != 0 {
                return PeerInfoStatusData(text: "\(strings.SharedMedia_PhotoCount(photoCount)), \(strings.SharedMedia_VideoCount(videoCount))", isActivity: false, key: .media)
            } else if photoCount != 0 {
                return PeerInfoStatusData(text: strings.SharedMedia_PhotoCount(photoCount), isActivity: false, key: .media)
            } else if videoCount != 0 {
                return PeerInfoStatusData(text: strings.SharedMedia_VideoCount(videoCount), isActivity: false, key: .media)
            } else {
                return nil
            }
        case .photo:
            return photoCount != 0 ? PeerInfoStatusData(text: strings.SharedMedia_PhotoCount(photoCount), isActivity: false, key: .media) : nil
        case .video:
            return videoCount != 0 ? PeerInfoStatusData(text: strings.SharedMedia_VideoCount(videoCount), isActivity: false, key: .media) : nil
        default:
            return nil
        }
    }

    private func subscribeToList() {
        self.listGeneration += 1
        let generation = self.listGeneration
        self.isLoadingHole = false
        self.listDisposable.set((self.listSource.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self, self.listGeneration == generation else {
                return
            }
            if let state = self.stateGate.offer(state, isBusy: self.isGridBusy) {
                self.applyState(state)
            }
        }))
    }

    private func applyState(_ state: SparseMessageList.State) {
        self.readyRowStarts.removeAll()
        if let changes = self.dataSource.update(state: state) {
            self.gridView.apply(changes)
        }
        self.didReceiveState = true
        if let initialMessageIndex = self.initialMessageIndex, self.dataSource.hasLoadedMessages {
            self.initialMessageIndex = nil
            for message in self.dataSource.loadedMessages where message.index <= initialMessageIndex {
                if let index = self.dataSource.index(of: message.id) {
                    self.scrollToItem(index: index)
                }
                break
            }
        }
        self.refreshVisibleCells(animated: false)
        self.revealReadyRows()
        self.updateHoleToLoad()
        self.updateScrollingArea()
        if !self.didSetReady {
            self.didSetReady = true
            self.ready.set(.single(true))
        }
    }

    private var isGridBusy: Bool {
        return self.gridView.isZooming || self.gridView.isAnimatingScroll
    }

    private func applyHeldStateIfIdle() {
        guard self.stateGate.isHolding, !self.isGridBusy, let state = self.stateGate.release() else {
            return
        }
        self.applyState(state)
    }

    private func updateHoleToLoad() {
        guard !self.isLoadingHole, !self.gridView.isZooming, self.didReceiveState, !self.dataSource.isPlaceholderCount, let visible = self.gridView.visibleIndexRange, !visible.isEmpty else {
            return
        }
        guard let firstEmpty = self.dataSource.firstUnloadedIndex(in: visible), let hole = mediaGridPaneHoleNearest(to: firstEmpty, sortedHoles: self.dataSource.holes()), let messageId = self.dataSource.holeAnchorMessageId(at: hole.anchorIndex) else {
            return
        }
        self.isLoadingHole = true
        let generation = self.listGeneration
        self.listSource.loadHole(anchor: messageId, direction: .later, completion: { [weak self] in
            Queue.mainQueue().async {
                guard let self, self.listGeneration == generation else {
                    return
                }
                self.isLoadingHole = false
                self.updateHoleToLoad()
            }
        })
    }

    private func handleTap(index: Int) {
        guard !self.touchActionsDisabled, let message = self.dataSource.message(at: index) else {
            return
        }
        if let selectionState = self.chatControllerInteraction.selectionState {
            self.chatControllerInteraction.toggleMessagesSelection([message.id], !selectionState.selectedIds.contains(message.id))
        } else if !message._asMessage().isSensitiveContent(platform: "ios", contentSettings: self.context.currentContentSettings.with { $0 }) {
            let _ = self.chatControllerInteraction.openMessage(message._asMessage(), OpenMessageParams(mode: .default))
        }
    }

    private func onBeginFastScrolling() {
        if self.calendarSource == nil || self.processedOnBeginFastScrolling {
            return
        }
        self.processedOnBeginFastScrolling = true
        let _ = (ApplicationSpecificNotice.getSharedMediaFastScrollingTooltip(accountManager: self.context.sharedContext.accountManager)
        |> deliverOnMainQueue).start(next: { [weak self] count in
            guard let self, count < 1 else {
                return
            }
            let _ = ApplicationSpecificNotice.incrementSharedMediaFastScrollingTooltip(accountManager: self.context.sharedContext.accountManager).start()
            var currentNode: ASDisplayNode = self
            while true {
                if let node = currentNode as? PeerInfoScreenNodeProtocol {
                    node.displaySharedMediaFastScrollingTooltip()
                    break
                } else if let supernode = currentNode.supernode {
                    currentNode = supernode
                } else {
                    break
                }
            }
        })
    }

    private func gridDidScroll(offset: CGFloat) {
        self.paneDidScroll?()
        if let params = self.currentParams {
            let delta = offset - self.previousScrollOffset
            let topInset = params.topInset
            var coveringInsetOffset = self.coveringInsetOffset + delta
            coveringInsetOffset = max(0.0, min(topInset, coveringInsetOffset))
            if offset <= 0.0 {
                coveringInsetOffset = 0.0
            }
            if self.isFastScrolling {
                if offset <= topInset, coveringInsetOffset < self.coveringInsetOffset {
                    self.coveringInsetOffset = coveringInsetOffset
                    self.tabBarOffsetUpdated?(.immediate)
                }
            } else if coveringInsetOffset != self.coveringInsetOffset {
                self.coveringInsetOffset = coveringInsetOffset
                self.tabBarOffsetUpdated?(.immediate)
            }
        }
        self.previousScrollOffset = offset
        if self.stateGate.isHolding && !self.isGridBusy {
            DispatchQueue.main.async { [weak self] in
                self?.applyHeldStateIfIdle()
            }
        }
        let viewport = self.shimmerViewport
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for cell in self.shimmeringCells.allObjects {
            cell.updateShimmerPosition(viewport: viewport)
        }
        CATransaction.commit()
        self.updateScrollingArea()
    }

    private func snapCoveringInsetOffset() {
        guard let params = self.currentParams else {
            return
        }
        let offset = self.gridView.contentOffset
        if offset < params.topInset {
            return
        }
        var coveringInsetOffset: CGFloat = self.coveringInsetOffset > params.topInset / 2.0 ? params.topInset : 0.0
        if offset <= 0.0 {
            coveringInsetOffset = 0.0
        }
        if coveringInsetOffset != self.coveringInsetOffset {
            self.coveringInsetOffset = coveringInsetOffset
            self.tabBarOffsetUpdated?(.animated(duration: 0.2, curve: .easeInOut))
        }
    }

    private func scrollerText(tag: Int32) -> String {
        if let cached = self.scrollerTextCache, cached.tag == tag, cached.strings === self.presentationData.strings {
            return cached.text
        }
        let month = VisualMediaMonth(packedValue: tag)
        let text = stringForMonth(strings: self.presentationData.strings, month: month.month, ofYear: month.year)
        self.scrollerTextCache = (tag, self.presentationData.strings, text)
        return text
    }

    private func updateScrollingArea() {
        guard let params = self.currentParams else {
            return
        }
        var tag: Int32?
        if let date = self.gridView.topVisibleDate {
            let timezoneOffset = Int32(TimeZone.current.secondsFromGMT())
            tag = VisualMediaMonth(localTimestamp: Int32(date.timeIntervalSince1970) + timezoneOffset).packedValue
        }
        if self.currentScrollingTag != tag {
            self.currentScrollingTag = tag
            if self.scrollingArea.isDragging {
                self.scrollingArea.feedbackTap()
            }
        }
        self.scrollingArea.update(
            containerSize: params.size,
            containerInsets: UIEdgeInsets(top: params.topInset, left: 0.0, bottom: params.bottomInset, right: 0.0),
            contentHeight: self.gridView.contentHeight,
            contentOffset: self.gridView.contentOffset,
            isScrolling: self.gridView.isUserScrolling,
            date: (tag.flatMap { self.scrollerText(tag: $0) } ?? "", tag ?? 0),
            theme: params.presentationData.theme,
            transition: .immediate
        )
    }

    public var scrollingTargetContentOffset: CGFloat {
        return self.gridView.contentOffset
    }

    public var scrollingTargetMaxContentOffset: CGFloat {
        return max(0.0, self.gridView.contentHeight - self.gridView.bounds.height)
    }

    private func visibleCell(at index: Int) -> MediaGridPaneCellLayer? {
        var result: MediaGridPaneCellLayer?
        self.gridView.forEachVisibleCell { cellIndex, cell in
            if cellIndex == index {
                result = cell as? MediaGridPaneCellLayer
            }
        }
        return result
    }

    private func refreshVisibleCells(animated: Bool) {
        self.gridView.forEachCell { _, cell in
            (cell as? MediaGridPaneCellLayer)?.refresh(animated: animated)
        }
    }

    public func updateContentType(contentType: PeerInfoVisualMediaPaneNode.ContentType) {
        if self.contentType == contentType {
            return
        }
        self.contentType = contentType
        self.contentTypePromise.set(contentType)
        self.scrollingArea.hideScroller()
        self.listSource = self.context.engine.messages.sparseMessageList(peerId: self.peerId, threadId: self.chatLocation.threadId, tag: tagMaskForType(contentType))
        self.dataSource.reset()
        self.readyRowStarts.removeAll()
        _ = self.stateGate.release()
        self.didReceiveState = false
        self.gridView.reloadData()
        self.gridView.scrollToTop(animated: false)
        self.subscribeToList()
    }

    public func currentTopTimestamp() -> Int32? {
        guard let range = self.gridView.visibleIndexRange else {
            return nil
        }
        var timestamp: Int32?
        for index in range {
            if let message = self.dataSource.message(at: index) {
                timestamp = max(timestamp ?? message.timestamp, message.timestamp)
            }
        }
        return timestamp
    }

    public func scrollToItem(index: Int) {
        guard let frame = self.gridView.contentFrameForItem(at: index) else {
            return
        }
        let maxOffset = max(0.0, self.gridView.contentHeight - self.gridView.bounds.height)
        let offset = max(0.0, min(maxOffset, floor(frame.midY - self.gridView.bounds.height / 2.0)))
        self.gridView.setContentOffset(offset)
    }

    public func brieflyDisableTouchActions() {
        if self.touchActionsDisabled {
            return
        }
        self.touchActionsDisabled = true
        DispatchQueue.main.async { [weak self] in
            self?.touchActionsDisabled = false
        }
    }

    public func canZoom(isZoomIn: Bool) -> Bool {
        return isZoomIn ? self.gridView.canZoomIn : self.gridView.canZoomOut
    }

    public func zoom(isZoomIn: Bool) {
        if isZoomIn {
            self.gridView.zoomIn()
        } else {
            self.gridView.zoomOut()
        }
    }

    public func scrollToTop() -> Bool {
        if self.gridView.contentOffset > 0.0 {
            self.gridView.scrollToTop(animated: true)
            return true
        }
        return false
    }

    public func hitTestResultForScrolling() -> UIView? {
        return self.gridView.isZooming ? nil : self.gridView
    }

    public func transferVelocity(_ velocity: CGFloat) {
        self.gridView.transferVelocity(velocity)
    }

    public func cancelPreviewGestures() {
    }

    public func findLoadedMessage(id: EngineMessage.Id) -> EngineMessage? {
        guard let index = self.dataSource.index(of: id) else {
            return nil
        }
        return self.dataSource.message(at: index)
    }

    public func transitionNodeForGallery(messageId: EngineMessage.Id, media: EngineMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        guard let index = self.dataSource.index(of: messageId), let cell = self.visibleCell(at: index), let frame = self.gridView.frameForItem(at: index) else {
            return nil
        }
        let proxyNode = ASDisplayNode()
        proxyNode.frame = self.view.convert(frame, from: self.gridView)
        proxyNode.contents = cell.contents
        proxyNode.layer.contentsRect = cell.contentsRect
        proxyNode.layer.contentsGravity = .resizeAspectFill
        proxyNode.clipsToBounds = true
        proxyNode.isHidden = true
        self.addSubnode(proxyNode)
        let escapeNotification = EscapeNotification {
            proxyNode.removeFromSupernode()
        }
        return (proxyNode, proxyNode.bounds, {
            let view = UIView()
            view.frame = proxyNode.frame
            view.clipsToBounds = true
            view.layer.contents = proxyNode.layer.contents
            view.layer.contentsRect = proxyNode.layer.contentsRect
            view.layer.contentsGravity = .resizeAspectFill
            escapeNotification.keep()
            return (view, nil)
        })
    }

    public func addToTransitionSurface(view: UIView) {
        self.view.insertSubview(view, belowSubview: self.scrollingArea.view)
    }

    public func updateHiddenMedia() {
        for id in self.hiddenMedia.keys {
            self.revealedSpoilerMessageIds.insert(id)
        }
        self.refreshVisibleCells(animated: false)
    }

    public func updateSelectedMessages(animated: Bool) {
        let isSelecting = self.chatControllerInteraction.selectionState != nil
        self.gridView.isZoomEnabled = !isSelecting
        self.gridView.isSelectionPanEnabled = isSelecting
        self.refreshVisibleCells(animated: animated)
    }

    public func ensureMessageIsVisible(id: EngineMessage.Id) {
    }

    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, topInset, sideInset, bottomInset, isScrollingLockedAtTop, presentationData)
        let bounds = CGRect(origin: CGPoint(), size: size)
        transition.updateFrame(node: self.contextGestureContainerNode, frame: bounds)
        transition.updateFrame(node: self.hostNode, frame: bounds)
        self.gridView.frame = bounds
        self.gridView.geometryInsets = UIEdgeInsets(top: topInset, left: 0.0, bottom: 0.0, right: 0.0)
        self.gridView.updateLayout(size: size, safeInsets: UIEdgeInsets(top: 0.0, left: sideInset, bottom: bottomInset, right: sideInset), isLandscape: false, transition: 0.0)
        self.gridView.isScrollingLockedAtTop = isScrollingLockedAtTop
        self.scrollingArea.frame = bounds
        self.scrollingArea.isHidden = isScrollingLockedAtTop
        self.updateScrollingArea()
    }
}
