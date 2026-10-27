import Foundation
import UIKit
import Photos
import Display
import AsyncDisplayKit
import SwiftSignalKit
import LegacyComponents
import TelegramPresentationData
import SparseItemGrid
import AttachmentUI
import InvisibleInkDustNode
import MediaGrid
import MediaGridPhotoLibrary

final class MediaPickerMediaGridDataSource: MediaGridDataSource {
    let base: MediaGridPhotoLibraryDataSource
    weak var host: MediaPickerMediaGridHost?

    init(base: MediaGridPhotoLibraryDataSource) {
        self.base = base
    }

    var count: Int {
        return self.base.count
    }

    func date(at index: Int) -> Date? {
        return self.base.date(at: index)
    }

    func aspectRatioReader() -> MediaGridAspectRatioReader {
        return self.base.aspectRatioReader()
    }

    func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        if let image = self.host?.editedImage(at: index) {
            completion(image, false)
            return nil
        }
        return self.base.requestImage(at: index, pixelSize: pixelSize, completion: completion)
    }

    func startCaching(indices: [Int], pixelSize: CGSize) {
        self.base.startCaching(indices: indices, pixelSize: pixelSize)
    }

    func stopCaching(indices: [Int], pixelSize: CGSize) {
        self.base.stopCaching(indices: indices, pixelSize: pixelSize)
    }

    func performBatch(_ updates: () -> Void) {
        self.base.performBatch(updates)
    }

    func thumbnail(at index: Int) -> MediaGridThumbnail? {
        if self.host?.editedImage(at: index) != nil {
            return nil
        }
        return self.base.thumbnail(at: index)
    }

    func prepareThumbnails(ranges: [Range<Int>]) {
        self.base.prepareThumbnails(ranges: ranges)
    }

    func launchImage(at index: Int) -> MediaGridLaunchImage? {
        if self.host?.editedImage(at: index) != nil {
            return nil
        }
        return self.base.launchImage(at: index)
    }

    func waitForLaunchImages(timeout: TimeInterval) {
        self.base.waitForLaunchImages(timeout: timeout)
    }
}

final class MediaPickerMediaGridContainerView: UIView, AttachmentScrollableContent {
    var gridView: MediaGridView? {
        didSet {
            if self.gridView !== oldValue {
                oldValue?.removeFromSuperview()
                if let gridView = self.gridView {
                    self.insertSubview(gridView, at: 0)
                }
            }
        }
    }

    var attachmentContentOffset: CGFloat {
        return self.gridView?.contentOffset ?? 0.0
    }

    var attachmentBlocksContainerPan: Bool {
        return self.gridView?.isZooming ?? false
    }

    func attachmentSetContentBounces(_ bounces: Bool) {
        self.gridView?.bounces = bounces
    }

    func attachmentScrollContentToTop() {
        guard let gridView = self.gridView, gridView.contentOffset != 0.0 else {
            return
        }
        gridView.setContentOffset(0.0)
    }

    func attachmentResetContentPanTranslation() {
        self.gridView?.reanchorDrag()
    }
}

final class MediaPickerMediaGridCameraView: UIView {
    let canvas = UIView()

    var canvasSize = CGSize() {
        didSet {
            if self.canvasSize != oldValue {
                self.setNeedsLayout()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.clipsToBounds = true
        self.addSubview(self.canvas)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.bounds
        guard self.canvasSize.width > 0.0, self.canvasSize.height > 0.0, bounds.width > 0.0, bounds.height > 0.0 else {
            return
        }
        let scale = max(bounds.width / self.canvasSize.width, bounds.height / self.canvasSize.height)
        self.canvas.transform = .identity
        self.canvas.bounds = CGRect(origin: CGPoint(), size: self.canvasSize)
        self.canvas.center = CGPoint(x: bounds.midX, y: bounds.midY)
        self.canvas.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}

private final class MediaPickerGridSpoilerOverlayView: UIView {
    let dustNode: MediaDustNode
    private var priceNode: PriceNode?
    private var currentState: (size: CGSize, showsPrice: Bool, price: Int64?)?

    init(enableAnimations: Bool) {
        self.dustNode = MediaDustNode(enableAnimations: enableAnimations)
        super.init(frame: CGRect())
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.addSubview(self.dustNode.view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, showsPrice: Bool, price: Int64?) {
        if let currentState = self.currentState, currentState.size == size, currentState.showsPrice == showsPrice, currentState.price == price {
            return
        }
        self.currentState = (size, showsPrice, price)
        self.dustNode.frame = CGRect(origin: CGPoint(), size: size)
        self.dustNode.update(size: size, color: .white, transition: .immediate)
        if showsPrice {
            let priceNode: PriceNode
            if let current = self.priceNode {
                priceNode = current
            } else {
                priceNode = PriceNode()
                self.addSubview(priceNode.view)
                self.priceNode = priceNode
            }
            priceNode.frame = CGRect(origin: CGPoint(), size: size)
            priceNode.update(size: size, price: price, small: true, transition: .immediate)
        } else if let priceNode = self.priceNode {
            self.priceNode = nil
            priceNode.view.removeFromSuperview()
        }
    }
}

private final class MediaPickerGridCellProxyView: UIView {
    weak var cell: MediaPickerGridCellLayer?
    var identifier: String?

    override var alpha: CGFloat {
        didSet {
            if let cell = self.cell, cell.identifier == self.identifier {
                cell.opacity = Float(self.alpha)
            }
        }
    }
}

private struct MediaPickerGridItemInfo {
    var asset: MediaPickerGridAssetInfo
    var edit: MediaPickerGridEditInfo?
}

final class MediaPickerMediaGridItem: MediaPickerGridHostItem {
    private weak var host: MediaPickerMediaGridHost?
    let index: Int
    let cell: MediaPickerGridCellLayer
    let asset: PHAsset

    init(host: MediaPickerMediaGridHost, index: Int, cell: MediaPickerGridCellLayer, asset: PHAsset) {
        self.host = host
        self.index = index
        self.cell = cell
        self.asset = asset
    }

    var identifier: String {
        return self.asset.localIdentifier
    }

    var tag: Int32? {
        guard let localTimestamp = self.asset.creationDate?.timeIntervalSince1970 else {
            return nil
        }
        return Month(localTimestamp: Int32(exactly: floor(localTimestamp)) ?? 0).packedValue
    }

    var selectableItem: TGMediaSelectableItem? {
        return TGMediaAsset(phAsset: self.asset)
    }

    func transitionView(snapshot: Bool) -> UIView {
        return self.host?.snapshotView(index: self.index, cell: self.cell) ?? UIView()
    }

    func transitionImage() -> UIImage? {
        return self.cell.transitionImage
    }

    func hideTransitionSource() {
        self.cell.isHidden = true
        self.host?.updateOverlays()
    }

    func selectedListTransition() -> (UIView, ASDisplayNode?, (Bool) -> Void) {
        let view = self.host?.proxyView(index: self.index, cell: self.cell) ?? UIView()
        return (view, nil, { [weak cell = self.cell] animateCheck in
            cell?.animateFadeIn(animateCheck: animateCheck)
        })
    }

    func updateHiddenMedia() {
        self.host?.refresh(cell: self.cell, animated: false)
    }

    func updateGridSelectionState(animated: Bool) {
        self.host?.refresh(cell: self.cell, animated: animated)
    }
}

final class MediaPickerMediaGridHost: MediaPickerGridHost, MediaPickerGridCellStateProvider, SparseItemGridScrollingTarget {
    private let containerView: MediaPickerMediaGridContainerView
    private let containerNode: ASDisplayNode
    private let headerNode: ASDisplayNode
    private let cameraContainerView: MediaPickerMediaGridCameraView
    private let interaction: MediaPickerInteraction
    private let getTheme: () -> PresentationTheme
    private let isSelectable: Bool
    private let enableAnimations: Bool
    private let selectionPanBegan: () -> Void

    private var gridView: MediaGridView?
    private var dataSource: MediaPickerMediaGridDataSource?
    private var configuration: MediaPickerGridAssetsConfiguration?
    private var level: MediaGridLevel?
    private weak var levelInitializedGrid: MediaGridView?

    private var layoutState: (size: CGSize, insets: UIEdgeInsets, isLandscape: Bool, hasCamera: Bool)?
    private var selectionNumbers: [String: Int] = [:]
    private var itemInfos: [String: MediaPickerGridItemInfo] = [:]
    private var editedThumbnails: [String: UIImage] = [:]
    private var pendingThumbnailDisposables: [String: SDisposable] = [:]
    private var spoilerIdentifiers = Set<String>()
    private var overlays: [String: MediaPickerGridSpoilerOverlayView] = [:]
    private var proxyViews: [String: MediaPickerGridCellProxyView] = [:]
    private var editingDisposables: [SDisposable] = []

    static let itemInfoLimit = 8192

    var scrollingInitiated: (() -> Void)?
    var visibleContentOffsetChanged: (GridNodeVisibleContentOffset) -> Void = { _ in }
    var visibleItemsUpdated: (() -> Void)?
    var headerHeight: CGFloat = 0.0

    init(interaction: MediaPickerInteraction, isSelectable: Bool, enableAnimations: Bool, getTheme: @escaping () -> PresentationTheme, selectionPanBegan: @escaping () -> Void) {
        self.interaction = interaction
        self.isSelectable = isSelectable
        self.enableAnimations = enableAnimations
        self.getTheme = getTheme
        self.selectionPanBegan = selectionPanBegan

        let containerView = MediaPickerMediaGridContainerView()
        self.containerView = containerView
        self.containerNode = ASDisplayNode(viewBlock: {
            return containerView
        })
        self.headerNode = ASDisplayNode()
        self.cameraContainerView = MediaPickerMediaGridCameraView()

        self.subscribeToEdits()
    }

    deinit {
        for disposable in self.editingDisposables {
            disposable.dispose()
        }
        for (_, disposable) in self.pendingThumbnailDisposables {
            disposable.dispose()
        }
    }

    private func subscribeToEdits() {
        let editingState = self.interaction.editingState
        let signals: [SSignal?] = [
            editingState.adjustmentsUpdatedSignal(),
            editingState.spoilersUpdatedSignal(),
            editingState.pricesUpdatedSignal(),
            editingState.livePhotoModesUpdatedSignal()
        ]
        for signal in signals {
            guard let signal else {
                continue
            }
            if let disposable = signal.start(next: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.editsChanged()
                }
            }, error: { _ in
            }, completed: {
            }) {
                self.editingDisposables.append(disposable)
            }
        }
    }

    var view: UIView {
        return self.containerView
    }

    var cameraHostView: UIView {
        return self.cameraContainerView.canvas
    }

    var headerHostNode: ASDisplayNode {
        return self.headerNode
    }

    var fastScrollView: UIScrollView? {
        return nil
    }

    var fastScrollTarget: SparseItemGridScrollingTarget? {
        return self.gridView != nil ? self : nil
    }

    var appliesFastScrollImmediately: Bool {
        return true
    }

    var consumesEntries: Bool {
        return false
    }

    var usesPickerSelectionGesture: Bool {
        return false
    }

    var isHidden: Bool {
        get {
            return self.containerNode.isHidden
        }
        set {
            self.containerNode.isHidden = newValue
        }
    }

    var isUserInteractionEnabled: Bool {
        get {
            return self.containerNode.isUserInteractionEnabled
        }
        set {
            self.containerNode.isUserInteractionEnabled = newValue
        }
    }

    var contentInsets: UIEdgeInsets {
        return self.layoutState?.insets ?? UIEdgeInsets()
    }

    var contentHeight: CGFloat {
        return self.gridView?.contentHeight ?? 0.0
    }

    var contentOffset: CGPoint {
        return CGPoint(x: 0.0, y: self.gridView?.contentOffset ?? 0.0)
    }

    var scrollBounds: CGRect {
        return CGRect(origin: self.contentOffset, size: self.containerView.bounds.size)
    }

    var isDragging: Bool {
        return self.gridView?.isUserScrolling ?? false
    }

    var isDecelerating: Bool {
        return false
    }

    var scrollingTargetContentOffset: CGFloat {
        return self.gridView?.contentOffset ?? 0.0
    }

    var scrollingTargetMaxContentOffset: CGFloat {
        guard let gridView = self.gridView else {
            return 0.0
        }
        return max(0.0, gridView.contentHeight - gridView.bounds.height)
    }

    var cellTheme: PresentationTheme {
        return self.getTheme()
    }

    func attach(to container: ASDisplayNode) {
        container.addSubnode(self.containerNode)
    }

    func hostDidLoad() {
    }

    func updateFrame(_ frame: CGRect, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerNode, frame: frame)
    }

    func updateLayout(size: CGSize, insets: UIEdgeInsets, preloadSize: CGFloat, itemSize: CGSize, itemSpacing: CGFloat, cutouts: [CGRect], transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let contentWidth = size.width - insets.left - insets.right
        let columns = itemSize.width > 0.0 ? Int(((contentWidth + itemSpacing) / (itemSize.width + itemSpacing)).rounded()) : 3
        self.layoutState = (size, insets, columns >= MediaGridLevel.five.columns, !cutouts.isEmpty)
        var duration: TimeInterval = 0.0
        if case let .animated(value, _) = transition {
            duration = value
        }
        self.applyLayout(duration: duration)
        completion()
    }

    private func applyLayout(duration: TimeInterval) {
        guard let gridView = self.gridView, let layoutState = self.layoutState else {
            return
        }
        let headerHeight = max(0.0, self.headerHeight)
        if gridView.frame != CGRect(origin: CGPoint(), size: layoutState.size) {
            gridView.frame = CGRect(origin: CGPoint(), size: layoutState.size)
        }
        let cameraView: UIView? = layoutState.hasCamera ? self.cameraContainerView : nil
        if gridView.cameraView !== cameraView {
            gridView.cameraView = cameraView
        }
        gridView.headerHeight = headerHeight
        self.headerNode.bounds = CGRect(origin: CGPoint(x: 0.0, y: -headerHeight), size: CGSize(width: layoutState.size.width, height: headerHeight))
        let insets = layoutState.insets
        gridView.geometryInsets = UIEdgeInsets(top: max(0.0, insets.top - headerHeight), left: insets.left, bottom: insets.bottom, right: insets.right)
        if self.levelInitializedGrid !== gridView {
            self.levelInitializedGrid = gridView
            let columns = mediaPickerGridInitialLevelColumns(carriedColumns: self.level?.columns, isLandscape: layoutState.isLandscape)
            let level = MediaGridLevel(rawValue: columns) ?? MediaGridLevel.defaultLevel(isLandscape: layoutState.isLandscape)
            self.level = level
            gridView.setLevel(level, animated: false)
        }
        gridView.updateLayout(size: layoutState.size, safeInsets: insets, isLandscape: layoutState.isLandscape, transition: duration)
        gridView.layoutIfNeeded()
        self.updateOverlays()
    }

    func updateAssets(fetchResult: PHFetchResult<PHAsset>, configuration: MediaPickerGridAssetsConfiguration) {
        guard mediaPickerGridNeedsInstall(current: self.configuration, hasGrid: self.gridView != nil, new: configuration) else {
            return
        }
        self.configuration = configuration
        self.installGrid(fetchResult: fetchResult, configuration: configuration)
    }

    private func installGrid(fetchResult: PHFetchResult<PHAsset>, configuration: MediaPickerGridAssetsConfiguration) {
        if let previous = self.gridView {
            self.level = previous.level
            previous.cameraView = nil
            previous.headerView = nil
        }
        self.dataSource?.base.onChange = nil
        self.dataSource?.base.onThumbnailsChanged = nil
        self.dataSource?.base.filler?.isMovingFast = false
        self.containerView.gridView = nil
        self.gridView = nil
        self.dataSource = nil
        self.itemInfos.removeAll()
        self.spoilerIdentifiers.removeAll()
        self.removeOverlays()

        let services = MediaGridPhotoLibraryServices.shared
        let base = services.makeDataSource(fetchResult: fetchResult, reversed: configuration.isReversed, isLibrary: configuration.isLibrary)
        let dataSource = MediaPickerMediaGridDataSource(base: base)
        dataSource.host = self
        self.dataSource = dataSource

        let gridView = MediaGridView(dataSource: dataSource, cellFactory: { [weak self] in
            let cell = MediaPickerGridCellLayer()
            cell.provider = self
            return cell
        })
        gridView.backgroundColor = .clear
        gridView.isZoomEnabled = true
        gridView.headerView = self.headerNode.view
        self.gridView = gridView
        self.containerView.gridView = gridView

        base.onChange = { [weak self, weak base] changes in
            guard let self, let base, self.dataSource?.base === base, let gridView = self.gridView else {
                return
            }
            self.itemInfos.removeAll()
            if let changes {
                gridView.apply(changes)
            } else {
                gridView.reloadData()
            }
            self.refreshVisibleCells(animated: false)
            self.visibleItemsUpdated?()
        }
        base.onThumbnailsChanged = { [weak self, weak base] indices in
            guard let self, let base, self.dataSource?.base === base else {
                return
            }
            self.gridView?.thumbnailsDidChange(indices: indices)
        }

        gridView.isItemSelected = { [weak self] index in
            guard let self, let identifier = self.identifier(at: index) else {
                return false
            }
            return self.selectionNumbers[identifier] != nil
        }
        gridView.onSelectionPan = { [weak self] index, selected in
            self?.selectionPanned(index: index, selected: selected)
        }
        gridView.onSelectionPanBegan = { [weak self] in
            self?.selectionPanBegan()
        }
        gridView.onTapItemAt = { [weak self] index, point in
            self?.tapped(index: index, point: point)
        }
        gridView.onWillBeginDragging = { [weak self] in
            self?.scrollingInitiated?()
        }
        gridView.onScroll = { [weak self] offset in
            guard let self else {
                return
            }
            self.visibleContentOffsetChanged(.known(offset))
            self.visibleItemsUpdated?()
            if !self.spoilerIdentifiers.isEmpty || !self.overlays.isEmpty {
                self.updateOverlays()
            }
        }
        gridView.onLevelChanged = { [weak self] level in
            guard let self else {
                return
            }
            self.level = level
            self.visibleItemsUpdated?()
            self.updateOverlays()
        }
        gridView.onZoomingChanged = { [weak self] _ in
            self?.updateOverlays()
        }
        gridView.onMovingFastChanged = { [weak self, weak base] isMovingFast in
            guard let self, let base, self.dataSource?.base === base else {
                return
            }
            base.filler?.isMovingFast = isMovingFast
        }

        self.updateSelectionNumbers()
        if configuration.scrollsToEnd {
            gridView.scrollToEnd()
        }
        self.applyLayout(duration: 0.0)
        self.visibleItemsUpdated?()
    }

    func apply(_ transaction: MediaPickerGridTransaction) {
    }

    func visibleContentOffset() -> GridNodeVisibleContentOffset {
        guard let gridView = self.gridView else {
            return .none
        }
        return .known(gridView.contentOffset)
    }

    func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        if animated {
            if contentOffset.y <= 0.0 {
                self.gridView?.scrollToTop(animated: true)
                return
            }
        }
        self.gridView?.setContentOffset(contentOffset.y)
    }

    func scrollToTop(animated: Bool) {
        self.gridView?.scrollToTop(animated: animated)
    }

    func scrollingTag() -> Int32? {
        guard let date = self.gridView?.topVisibleDate else {
            return nil
        }
        return Month(localTimestamp: Int32(exactly: floor(date.timeIntervalSince1970)) ?? 0).packedValue
    }

    func isCameraPreviewVisible(_ cameraView: UIView) -> Bool {
        return self.gridView?.isCameraVisible ?? false
    }

    func cameraAccessibilityFrame(for rect: CGRect) -> CGRect {
        guard let gridView = self.gridView, let cameraView = gridView.cameraView, cameraView.superview != nil, !cameraView.isHidden else {
            return CGRect()
        }
        return cameraView.convert(cameraView.bounds, to: self.headerNode.view)
    }

    func cameraFrame(for rect: CGRect) -> CGRect {
        self.cameraContainerView.canvasSize = rect.size
        return CGRect(origin: CGPoint(), size: rect.size)
    }

    func updateItemsSelectionState(animated: Bool) {
        self.updateSelectionNumbers()
        self.refreshVisibleCells(animated: animated)
    }

    func updateItemsHiddenMedia() {
        self.refreshVisibleCells(animated: false)
        if self.interaction.hiddenMediaId == nil {
            self.editsChanged()
        }
    }

    func forEachVisibleItem(_ f: (MediaPickerGridHostItem) -> Void) {
        guard let gridView = self.gridView, let dataSource = self.dataSource else {
            return
        }
        gridView.forEachVisibleCell { index, cell in
            if let cell = cell as? MediaPickerGridCellLayer, let asset = dataSource.base.asset(at: index) {
                f(MediaPickerMediaGridItem(host: self, index: index, cell: cell, asset: asset))
            }
        }
    }

    func visibleItem(identifier: String) -> MediaPickerGridHostItem? {
        guard let gridView = self.gridView, let dataSource = self.dataSource else {
            return nil
        }
        var result: MediaPickerGridHostItem?
        gridView.forEachVisibleCell { index, cell in
            if let cell = cell as? MediaPickerGridCellLayer, cell.identifier == identifier, let asset = dataSource.base.asset(at: index) {
                result = MediaPickerMediaGridItem(host: self, index: index, cell: cell, asset: asset)
            }
        }
        return result
    }

    func item(at point: CGPoint) -> MediaPickerGridHostItem? {
        guard let gridView = self.gridView, let dataSource = self.dataSource else {
            return nil
        }
        let gridPoint = gridView.convert(point, from: self.containerView)
        guard let index = gridView.index(at: gridPoint), let asset = dataSource.base.asset(at: index) else {
            return nil
        }
        var result: MediaPickerGridHostItem?
        gridView.forEachVisibleCell { visibleIndex, cell in
            if visibleIndex == index, let cell = cell as? MediaPickerGridCellLayer {
                result = MediaPickerMediaGridItem(host: self, index: index, cell: cell, asset: asset)
            }
        }
        return result
    }

    private func identifier(at index: Int) -> String? {
        return self.dataSource?.base.asset(at: index)?.localIdentifier
    }

    private func updateSelectionNumbers() {
        guard let selectionState = self.interaction.selectionState else {
            self.selectionNumbers = [:]
            return
        }
        let identifiers = (selectionState.selectedItemsIdentifiers()?.array as? [String]) ?? []
        self.selectionNumbers = mediaPickerGridSelectionNumbers(identifiers)
    }

    private var isCompact: Bool {
        return !(self.gridView?.level.isInteractive ?? true)
    }

    func refresh(cell: MediaPickerGridCellLayer, animated: Bool) {
        cell.refresh(isCompact: self.isCompact, animated: animated)
    }

    private func refreshVisibleCells(animated: Bool) {
        guard let gridView = self.gridView else {
            return
        }
        let isCompact = self.isCompact
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gridView.forEachCell { _, cell in
            (cell as? MediaPickerGridCellLayer)?.refresh(isCompact: isCompact, animated: animated)
        }
        CATransaction.commit()
        self.updateOverlays()
    }

    func cellState(at index: Int, isCompact: Bool) -> MediaPickerGridCellState? {
        guard let dataSource = self.dataSource, let asset = dataSource.base.asset(at: index) else {
            return nil
        }
        let identifier = asset.localIdentifier
        let info: MediaPickerGridItemInfo?
        if isCompact {
            info = self.itemInfos[identifier]
        } else {
            info = self.itemInfo(for: asset)
        }
        let number = self.selectionNumbers[identifier]
        let selection = MediaPickerGridSelectionInfo(isSelected: number != nil, number: number, count: self.selectionNumbers.count)
        let decorations = mediaPickerGridCellDecorations(
            isCompact: isCompact,
            isSelectable: self.isSelectable && self.interaction.selectionState != nil,
            selection: selection,
            asset: info?.asset ?? MediaPickerGridAssetInfo(),
            edit: info?.edit ?? MediaPickerGridEditInfo(),
            displaysLivePhotoIcon: self.interaction.displayLivePhotoIcon,
            isForceLivePhotoEnabled: self.interaction.editingState.isForceLivePhotoEnabled()
        )
        if decorations.showsSpoilerBlur || decorations.showsSpoilerOverlay {
            self.spoilerIdentifiers.insert(identifier)
        }
        return MediaPickerGridCellState(identifier: identifier, decorations: decorations, isHidden: identifier == self.interaction.hiddenMediaId)
    }

    private func itemInfo(for asset: PHAsset) -> MediaPickerGridItemInfo {
        let identifier = asset.localIdentifier
        if let info = self.itemInfos[identifier], info.edit != nil {
            return info
        }
        let assetInfo: MediaPickerGridAssetInfo
        if let info = self.itemInfos[identifier] {
            assetInfo = info.asset
        } else {
            let subtypes = asset.mediaSubtypes
            assetInfo = MediaPickerGridAssetInfo(
                isGif: asset.value(forKey: "uniformTypeIdentifier") as? String == "com.compuserve.gif",
                isVideo: asset.mediaType == .video,
                isSlomo: subtypes.contains(.videoHighFrameRate),
                isTimelapse: subtypes.contains(.videoTimelapse),
                duration: asset.duration,
                isFavorite: asset.isFavorite,
                isLivePhoto: subtypes.contains(.photoLive)
            )
        }
        let info = MediaPickerGridItemInfo(asset: assetInfo, edit: self.editInfo(for: asset))
        if self.itemInfos.count >= MediaPickerMediaGridHost.itemInfoLimit {
            self.itemInfos.removeAll(keepingCapacity: true)
        }
        self.itemInfos[identifier] = info
        return info
    }

    private func editInfo(for asset: PHAsset) -> MediaPickerGridEditInfo {
        let editingState = self.interaction.editingState
        guard let item = TGMediaAsset(phAsset: asset) else {
            return MediaPickerGridEditInfo()
        }
        let identifier = asset.localIdentifier
        let hasSpoiler = editingState.spoiler(for: item)
        let price = (editingState.price(for: item) as NSNumber?)?.int64Value
        var isLivePhotoModeOn: Bool?
        if let mode = (editingState.livePhotoMode(for: item) as NSNumber?)?.uintValue, let liveMode = TGMediaLivePhotoMode(rawValue: mode) {
            isLivePhotoModeOn = liveMode != .off
        }
        if editingState.adjustments(for: item) != nil {
            self.loadEditedThumbnail(identifier: identifier)
        } else if self.editedThumbnails.removeValue(forKey: identifier) != nil {
            self.editedThumbnailChanged(identifier: identifier)
        }
        return MediaPickerGridEditInfo(hasSpoiler: hasSpoiler, price: price, isLivePhotoModeOn: isLivePhotoModeOn)
    }

    private func loadEditedThumbnail(identifier: String) {
        guard self.pendingThumbnailDisposables[identifier] == nil, let signal = self.interaction.editingState.thumbnailImageSignal(forIdentifier: identifier, withUpdates: false, synchronous: true) else {
            return
        }
        var isSynchronous = true
        var synchronousImage: UIImage?
        var didDeliverSynchronously = false
        let disposable = signal.start(next: { [weak self] next in
            let image = next as? UIImage
            if isSynchronous {
                synchronousImage = image
                didDeliverSynchronously = true
            } else {
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.pendingThumbnailDisposables.removeValue(forKey: identifier)?.dispose()
                    self.setEditedThumbnail(image, identifier: identifier)
                }
            }
        }, error: { _ in
        }, completed: {
        })
        isSynchronous = false
        if didDeliverSynchronously {
            disposable?.dispose()
            self.setEditedThumbnail(synchronousImage, identifier: identifier)
        } else if let disposable {
            self.pendingThumbnailDisposables[identifier] = disposable
        }
    }

    private func setEditedThumbnail(_ image: UIImage?, identifier: String) {
        let previous = self.editedThumbnails[identifier]
        if let image {
            self.editedThumbnails[identifier] = image
        } else {
            self.editedThumbnails.removeValue(forKey: identifier)
        }
        if previous !== image {
            self.editedThumbnailChanged(identifier: identifier)
        }
    }

    private func editedThumbnailChanged(identifier: String) {
        guard let gridView = self.gridView, let dataSource = self.dataSource else {
            return
        }
        var changed = IndexSet()
        gridView.forEachVisibleCell { index, cell in
            if (cell as? MediaPickerGridCellLayer)?.identifier == identifier || dataSource.base.asset(at: index)?.localIdentifier == identifier {
                changed.insert(index)
            }
        }
        if !changed.isEmpty {
            DispatchQueue.main.async { [weak self, weak gridView] in
                guard let self, let gridView, self.gridView === gridView else {
                    return
                }
                gridView.reloadImages(at: changed)
            }
        }
    }

    func editedImage(at index: Int) -> UIImage? {
        if self.editedThumbnails.isEmpty {
            return nil
        }
        guard let identifier = self.identifier(at: index) else {
            return nil
        }
        return self.editedThumbnails[identifier]
    }

    private func editsChanged() {
        for (identifier, info) in self.itemInfos {
            self.itemInfos[identifier] = MediaPickerGridItemInfo(asset: info.asset, edit: nil)
        }
        if let gridView = self.gridView, let dataSource = self.dataSource {
            let isCompact = self.isCompact
            gridView.forEachVisibleCell { index, _ in
                if !isCompact, let asset = dataSource.base.asset(at: index) {
                    let _ = self.itemInfo(for: asset)
                }
            }
        }
        self.spoilerIdentifiers.removeAll()
        self.refreshVisibleCells(animated: false)
    }

    private func selectionPanned(index: Int, selected: Bool) {
        guard let asset = self.dataSource?.base.asset(at: index), let item = TGMediaAsset(phAsset: asset) else {
            return
        }
        self.interaction.selectionState?.setItem(item, selected: selected, animated: true, sender: nil)
    }

    private func tapped(index: Int, point: CGPoint) {
        guard let gridView = self.gridView, let dataSource = self.dataSource, let asset = dataSource.base.asset(at: index) else {
            return
        }
        var cell: MediaPickerGridCellLayer?
        gridView.forEachVisibleCell { visibleIndex, visibleCell in
            if visibleIndex == index {
                cell = visibleCell as? MediaPickerGridCellLayer
            }
        }
        if let cell, cell.decorations.check != nil, let frame = gridView.frameForItem(at: index) {
            let localPoint = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
            let checkFrame = MediaPickerGridCellLayer.checkFrame(in: CGRect(origin: CGPoint(), size: frame.size)).insetBy(dx: -8.0, dy: -8.0)
            if checkFrame.contains(localPoint), let item = TGMediaAsset(phAsset: asset) {
                let isSelected = self.selectionNumbers[asset.localIdentifier] != nil
                let _ = self.interaction.toggleSelection(item, !isSelected, false)
                return
            }
        }
        let fetchResult = dataSource.base.fetchResult
        let fetchIndex = mediaPickerGridFetchIndex(gridIndex: index, count: fetchResult.count, isReversed: dataSource.base.reversed)
        self.interaction.openMedia(fetchResult, fetchIndex, cell?.transitionImage)
    }

    func snapshotView(index: Int, cell: MediaPickerGridCellLayer) -> UIView {
        guard let gridView = self.gridView, let frame = gridView.frameForItem(at: index) else {
            return cell.makeSnapshotView(frame: CGRect())
        }
        return cell.makeSnapshotView(frame: gridView.convert(frame, to: nil))
    }

    func proxyView(index: Int, cell: MediaPickerGridCellLayer) -> UIView {
        guard let gridView = self.gridView, let identifier = cell.identifier, let frame = gridView.contentFrameForItem(at: index) else {
            return UIView()
        }
        let view: MediaPickerGridCellProxyView
        if let current = self.proxyViews[identifier] {
            view = current
        } else {
            if self.proxyViews.count >= 32 {
                for (_, view) in self.proxyViews {
                    view.removeFromSuperview()
                }
                self.proxyViews.removeAll()
            }
            view = MediaPickerGridCellProxyView()
            view.isUserInteractionEnabled = false
            self.proxyViews[identifier] = view
        }
        view.cell = cell
        view.identifier = identifier
        view.frame = frame
        if view.superview !== gridView.overlayView {
            gridView.overlayView.addSubview(view)
        }
        return view
    }

    private func removeOverlays() {
        for (_, overlay) in self.overlays {
            overlay.removeFromSuperview()
        }
        self.overlays.removeAll()
        for (_, view) in self.proxyViews {
            view.removeFromSuperview()
        }
        self.proxyViews.removeAll()
    }

    func updateOverlays() {
        guard let gridView = self.gridView else {
            return
        }
        if self.spoilerIdentifiers.isEmpty && self.overlays.isEmpty {
            return
        }
        var visible = Set<String>()
        if !gridView.isZooming && gridView.level.isInteractive {
            gridView.forEachVisibleCell { index, cell in
                guard let cell = cell as? MediaPickerGridCellLayer, let identifier = cell.identifier, cell.decorations.showsSpoilerOverlay, !cell.isHidden, let frame = gridView.contentFrameForItem(at: index) else {
                    return
                }
                visible.insert(identifier)
                let overlay: MediaPickerGridSpoilerOverlayView
                if let current = self.overlays[identifier] {
                    overlay = current
                } else {
                    overlay = MediaPickerGridSpoilerOverlayView(enableAnimations: self.enableAnimations)
                    gridView.overlayView.addSubview(overlay)
                    self.overlays[identifier] = overlay
                }
                if overlay.frame != frame {
                    overlay.frame = frame
                }
                overlay.update(size: frame.size, showsPrice: cell.decorations.showsPrice, price: cell.decorations.price)
            }
        }
        for (identifier, overlay) in self.overlays where !visible.contains(identifier) {
            overlay.removeFromSuperview()
            self.overlays.removeValue(forKey: identifier)
        }
    }
}
