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
import MediaEditor
import RadialStatusNode
import MediaAssetsContext

enum MediaPickerGridExtraItem {
    case draft(MediaEditorDraft)
    case media(MediaPickerScreenImpl.Subject.Media, TGMediaSelectableItem)

    var identifier: String {
        switch self {
        case let .draft(draft):
            return draft.path
        case let .media(_, item):
            return item.uniqueIdentifier
        }
    }

    var image: UIImage? {
        switch self {
        case let .draft(draft):
            return draft.thumbnail
        case let .media(media, _):
            if case let .image(image) = media {
                return image
            }
            return nil
        }
    }

    var aspectRatio: CGFloat {
        guard let size = self.image?.size, size.width > 0.0, size.height > 0.0 else {
            return 1.0
        }
        return size.width / size.height
    }

    var date: Date? {
        if case let .draft(draft) = self {
            return Date(timeIntervalSince1970: Double(draft.timestamp))
        }
        return nil
    }

    var selectableItem: TGMediaSelectableItem? {
        if case let .media(_, item) = self {
            return item
        }
        return nil
    }

    static func sameItems(_ lhs: [MediaPickerGridExtraItem], _ rhs: [MediaPickerGridExtraItem]) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        for i in 0 ..< lhs.count {
            if lhs[i].identifier != rhs[i].identifier {
                return false
            }
            if case let .draft(lhsDraft) = lhs[i], case let .draft(rhsDraft) = rhs[i], lhsDraft.thumbnail !== rhsDraft.thumbnail {
                return false
            }
        }
        return true
    }
}

final class MediaPickerMediaGridDataSource: MediaGridDataSource {
    let base: MediaGridPhotoLibraryDataSource?
    private(set) var extras: [MediaPickerGridExtraItem]
    weak var host: MediaPickerMediaGridHost?

    init(base: MediaGridPhotoLibraryDataSource?, extras: [MediaPickerGridExtraItem]) {
        self.base = base
        self.extras = extras
    }

    var extraCount: Int {
        return self.extras.count
    }

    var assetCount: Int {
        return self.base?.count ?? 0
    }

    var count: Int {
        return self.extraCount + self.assetCount
    }

    func slot(at index: Int) -> MediaPickerGridSlot? {
        return mediaPickerGridSlot(index: index, extraCount: self.extraCount, assetCount: self.assetCount)
    }

    func asset(at index: Int) -> PHAsset? {
        if case let .asset(assetIndex) = self.slot(at: index) {
            return self.base?.asset(at: assetIndex)
        }
        return nil
    }

    func extra(at index: Int) -> MediaPickerGridExtraItem? {
        if case let .extra(extraIndex) = self.slot(at: index) {
            return self.extras[extraIndex]
        }
        return nil
    }

    func identifier(at index: Int) -> String? {
        switch self.slot(at: index) {
        case let .extra(extraIndex):
            return self.extras[extraIndex].identifier
        case let .asset(assetIndex):
            return self.base?.asset(at: assetIndex)?.localIdentifier
        case .none:
            return nil
        }
    }

    func assetIndex(at index: Int) -> Int? {
        if case let .asset(assetIndex) = self.slot(at: index) {
            return assetIndex
        }
        return nil
    }

    func gridChanges(fromAssetChanges changes: MediaGridChanges) -> MediaGridChanges {
        let offset = self.extraCount
        return MediaGridChanges(removed: mediaPickerGridShifted(changes.removed, by: offset), inserted: mediaPickerGridShifted(changes.inserted, by: offset), changed: mediaPickerGridShifted(changes.changed, by: offset))
    }

    func gridIndices(fromAssetIndices indices: IndexSet) -> IndexSet {
        return mediaPickerGridShifted(indices, by: self.extraCount)
    }

    func updateExtras(_ extras: [MediaPickerGridExtraItem]) -> MediaGridChanges? {
        if MediaPickerGridExtraItem.sameItems(self.extras, extras) {
            self.extras = extras
            return nil
        }
        let change = mediaPickerGridPrefixChange(oldCount: self.extras.count, newCount: extras.count)
        self.extras = extras
        return MediaGridChanges(removed: change.removed, inserted: change.inserted, changed: IndexSet())
    }

    func date(at index: Int) -> Date? {
        switch self.slot(at: index) {
        case let .extra(extraIndex):
            return self.extras[extraIndex].date
        case let .asset(assetIndex):
            return self.base?.date(at: assetIndex)
        case .none:
            return nil
        }
    }

    func aspectRatioReader() -> MediaGridAspectRatioReader {
        let extraAspects = self.extras.map { $0.aspectRatio }
        let extraCount = extraAspects.count
        guard let baseReader = self.base?.aspectRatioReader() else {
            return { index in
                return index >= 0 && index < extraCount ? extraAspects[index] : 1.0
            }
        }
        return { index in
            if index >= 0 && index < extraCount {
                return extraAspects[index]
            }
            return baseReader(index - extraCount)
        }
    }

    func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        if let image = self.host?.editedImage(at: index) {
            completion(image, false)
            return nil
        }
        switch self.slot(at: index) {
        case let .extra(extraIndex):
            completion(self.extras[extraIndex].image, false)
            return nil
        case let .asset(assetIndex):
            guard let base = self.base else {
                completion(nil, false)
                return nil
            }
            return base.requestImage(at: assetIndex, pixelSize: pixelSize, completion: completion)
        case .none:
            completion(nil, false)
            return nil
        }
    }

    func startCaching(indices: [Int], pixelSize: CGSize) {
        guard let base = self.base else {
            return
        }
        let assetIndices = mediaPickerGridAssetIndices(indices, extraCount: self.extraCount, assetCount: self.assetCount)
        if !assetIndices.isEmpty {
            base.startCaching(indices: assetIndices, pixelSize: pixelSize)
        }
    }

    func stopCaching(indices: [Int], pixelSize: CGSize) {
        guard let base = self.base else {
            return
        }
        let assetIndices = mediaPickerGridAssetIndices(indices, extraCount: self.extraCount, assetCount: self.assetCount)
        if !assetIndices.isEmpty {
            base.stopCaching(indices: assetIndices, pixelSize: pixelSize)
        }
    }

    func performBatch(_ updates: () -> Void) {
        if let base = self.base {
            base.performBatch(updates)
        } else {
            updates()
        }
    }

    func thumbnail(at index: Int) -> MediaGridThumbnail? {
        guard let base = self.base, case let .asset(assetIndex) = self.slot(at: index) else {
            return nil
        }
        if self.host?.editedImage(at: index) != nil {
            return nil
        }
        return base.thumbnail(at: assetIndex)
    }

    func prepareThumbnails(ranges: [Range<Int>]) {
        self.base?.prepareThumbnails(ranges: mediaPickerGridAssetRanges(ranges, extraCount: self.extraCount, assetCount: self.assetCount))
    }

    func launchImage(at index: Int) -> MediaGridLaunchImage? {
        guard let base = self.base, case let .asset(assetIndex) = self.slot(at: index) else {
            return nil
        }
        if self.host?.editedImage(at: index) != nil {
            return nil
        }
        return base.launchImage(at: assetIndex)
    }

    func waitForLaunchImages(timeout: TimeInterval) {
        self.base?.waitForLaunchImages(timeout: timeout)
    }
}

final class MediaPickerMediaGridAccessoryContainerView: UIView {
    let contentView: UIView
    let layout: (CGSize) -> Void

    init(contentView: UIView, layout: @escaping (CGSize) -> Void) {
        self.contentView = contentView
        self.layout = layout
        super.init(frame: CGRect())
        self.addSubview(contentView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.bounds
        if self.contentView.frame != bounds {
            self.contentView.frame = bounds
        }
        self.layout(bounds.size)
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

    func attachmentSetContentHeldAtTop(_ held: Bool) {
        self.gridView?.holdsDragAtTop = held
    }

    func attachmentEndContentHold() {
        self.gridView?.endDragHold()
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

enum MediaPickerMediaGridItemContent {
    case asset(PHAsset)
    case extra(MediaPickerGridExtraItem)
}

final class MediaPickerMediaGridItem: MediaPickerGridHostItem {
    private weak var host: MediaPickerMediaGridHost?
    let index: Int
    let cell: MediaPickerGridCellLayer
    let content: MediaPickerMediaGridItemContent

    init(host: MediaPickerMediaGridHost, index: Int, cell: MediaPickerGridCellLayer, content: MediaPickerMediaGridItemContent) {
        self.host = host
        self.index = index
        self.cell = cell
        self.content = content
    }

    var identifier: String {
        switch self.content {
        case let .asset(asset):
            return asset.localIdentifier
        case let .extra(item):
            return item.identifier
        }
    }

    var tag: Int32? {
        let date: Date?
        switch self.content {
        case let .asset(asset):
            date = asset.creationDate
        case let .extra(item):
            date = item.date
        }
        guard let localTimestamp = date?.timeIntervalSince1970 else {
            return nil
        }
        return Month(localTimestamp: Int32(exactly: floor(localTimestamp)) ?? 0).packedValue
    }

    var selectableItem: TGMediaSelectableItem? {
        switch self.content {
        case let .asset(asset):
            return TGMediaAsset(phAsset: asset)
        case let .extra(item):
            return item.selectableItem
        }
    }

    func transitionView(snapshot: Bool) -> UIView {
        if !snapshot, let view = self.host?.proxyView(index: self.index, cell: self.cell) {
            return view
        }
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
    private let mode: MediaPickerGridModeConfiguration
    private let draftLabel: String
    private let enableAnimations: Bool
    private let selectionPanBegan: () -> Void
    private var accessoryContainerView: MediaPickerMediaGridAccessoryContainerView?

    var isSelectable: Bool {
        didSet {
            if self.isSelectable != oldValue {
                self.gridView?.isSelectionPanEnabled = self.isSelectable
                self.refreshVisibleCells(animated: false)
            }
        }
    }

    private var gridView: MediaGridView?
    private var dataSource: MediaPickerMediaGridDataSource?
    private var configuration: MediaPickerGridAssetsConfiguration?
    private var level: MediaGridLevel?
    private weak var levelInitializedGrid: MediaGridView?

    private var layoutState: (size: CGSize, insets: UIEdgeInsets, isLandscape: Bool, hasCamera: Bool)?
    private var fitBackgrounds: [String: UIImage] = [:]
    private var pendingFitBackgrounds = Set<String>()
    private var downloadDisposables: [String: Disposable] = [:]
    private var downloadProgress: [String: Float] = [:]
    private var downloadIndices: [String: Int] = [:]
    private var downloadOverlays: [String: RadialStatusNode] = [:]
    private var isDownloadTrackingScheduled = false
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
    var zoomingStarted: (() -> Void)?
    var visibleContentOffsetChanged: (GridNodeVisibleContentOffset) -> Void = { _ in }
    var visibleItemsUpdated: (() -> Void)?
    var headerHeight: CGFloat = 0.0
    var contentUnderBarChanged: (() -> Void)?
    private(set) var isContentUnderBar = false

    init(interaction: MediaPickerInteraction, mode: MediaPickerGridModeConfiguration, isSelectable: Bool, draftLabel: String, enableAnimations: Bool, getTheme: @escaping () -> PresentationTheme, selectionPanBegan: @escaping () -> Void) {
        self.interaction = interaction
        self.mode = mode
        self.isSelectable = isSelectable
        self.draftLabel = draftLabel
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
        for (_, disposable) in self.downloadDisposables {
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

    func updateLayout(size: CGSize, insets: UIEdgeInsets, preloadSize: CGFloat, itemSize: CGSize, itemSpacing: CGFloat, cutouts: [CGRect], hasCamera: Bool, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let contentWidth = size.width - insets.left - insets.right
        let columns = itemSize.width > 0.0 ? Int(((contentWidth + itemSpacing) / (itemSize.width + itemSpacing)).rounded()) : 3
        self.layoutState = (size, insets, columns >= MediaGridLevel.five.columns, hasCamera)
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
        self.updateDownloadTracking()
    }

    func updateAssets(fetchResult: PHFetchResult<PHAsset>, configuration: MediaPickerGridAssetsConfiguration, extras: [MediaPickerGridExtraItem]) {
        guard mediaPickerGridNeedsInstall(current: self.configuration, hasGrid: self.gridView != nil, new: configuration) else {
            self.updateExtras(extras)
            return
        }
        self.configuration = configuration
        self.installGrid(fetchResult: fetchResult, configuration: configuration, extras: extras)
    }

    func updateMedia(_ items: [MediaPickerGridExtraItem]) {
        if self.gridView == nil || self.configuration != nil {
            self.configuration = nil
            self.installGrid(fetchResult: nil, configuration: nil, extras: items)
        } else {
            self.updateExtras(items)
        }
    }

    private func updateExtras(_ extras: [MediaPickerGridExtraItem]) {
        guard let gridView = self.gridView, let dataSource = self.dataSource, let changes = dataSource.updateExtras(extras) else {
            return
        }
        self.itemInfos.removeAll()
        gridView.apply(changes)
        self.refreshVisibleCells(animated: false)
        self.visibleItemsUpdated?()
        self.updateDownloadTracking()
    }

    func setAccessoryView(_ view: UIView, layout: @escaping (CGSize) -> Void) {
        let containerView = MediaPickerMediaGridAccessoryContainerView(contentView: view, layout: layout)
        self.accessoryContainerView = containerView
        self.gridView?.accessoryView = containerView
    }

    func updateAccessoryFrame(_ view: UIView, frame: CGRect) {
    }

    private func installGrid(fetchResult: PHFetchResult<PHAsset>?, configuration: MediaPickerGridAssetsConfiguration?, extras: [MediaPickerGridExtraItem]) {
        if let previous = self.gridView {
            self.level = previous.level
            previous.cameraView = nil
            previous.headerView = nil
            previous.accessoryView = nil
        }
        self.dataSource?.base?.onChange = nil
        self.dataSource?.base?.onThumbnailsChanged = nil
        self.dataSource?.base?.filler?.isMovingFast = false
        self.containerView.gridView = nil
        self.gridView = nil
        self.dataSource = nil
        self.itemInfos.removeAll()
        self.spoilerIdentifiers.removeAll()
        self.removeOverlays()
        self.removeDownloadTracking()

        var base: MediaGridPhotoLibraryDataSource?
        if let fetchResult, let configuration {
            base = MediaGridPhotoLibraryServices.shared.makeDataSource(fetchResult: fetchResult, reversed: configuration.isReversed, isLibrary: configuration.isLibrary)
        }
        let dataSource = MediaPickerMediaGridDataSource(base: base, extras: extras)
        dataSource.host = self
        self.dataSource = dataSource

        let gridView = MediaGridView(dataSource: dataSource, cellFactory: { [weak self] in
            let cell = MediaPickerGridCellLayer()
            cell.provider = self
            return cell
        })
        gridView.backgroundColor = .clear
        gridView.isZoomEnabled = self.mode.isZoomEnabled
        gridView.cellAspect = self.mode.cellAspect
        gridView.cameraLevels = Set(self.mode.cameraColumns.compactMap { MediaGridLevel(rawValue: $0) })
        gridView.isSelectionPanEnabled = self.isSelectable
        gridView.accessoryView = self.accessoryContainerView
        gridView.headerView = self.headerNode.view
        gridView.compactLevelTopInset = 0.0
        self.gridView = gridView
        self.containerView.gridView = gridView

        base?.onChange = { [weak self, weak base] changes in
            guard let self, let base, let dataSource = self.dataSource, dataSource.base === base, let gridView = self.gridView else {
                return
            }
            self.itemInfos.removeAll()
            if let changes {
                gridView.apply(dataSource.gridChanges(fromAssetChanges: changes))
            } else {
                gridView.reloadData()
            }
            self.refreshVisibleCells(animated: false)
            self.visibleItemsUpdated?()
            self.updateDownloadTracking()
        }
        base?.onThumbnailsChanged = { [weak self, weak base] indices in
            guard let self, let base, let dataSource = self.dataSource, dataSource.base === base else {
                return
            }
            self.gridView?.thumbnailsDidChange(indices: dataSource.gridIndices(fromAssetIndices: indices))
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
            self.updateDownloadTracking()
        }
        gridView.onLevelChanged = { [weak self] level in
            guard let self else {
                return
            }
            self.level = level
            self.visibleItemsUpdated?()
            self.updateOverlays()
            self.updateDownloadTracking()
        }
        gridView.onZoomingChanged = { [weak self] isZooming in
            if isZooming {
                self?.zoomingStarted?()
            }
            self?.updateOverlays()
        }
        gridView.onTargetLevelChanged = { [weak self, weak gridView] _ in
            guard let self, let gridView, self.gridView === gridView else {
                return
            }
            self.updateContentUnderBar()
        }
        gridView.onZoomFrame = { [weak self, weak gridView] in
            guard let self, let gridView, self.gridView === gridView else {
                return
            }
            self.updateContentUnderBar()
        }
        self.updateContentUnderBar()
        gridView.onMovingFastChanged = { [weak self, weak base] isMovingFast in
            guard let self, let base, self.dataSource?.base === base else {
                return
            }
            base.filler?.isMovingFast = isMovingFast
        }

        self.updateSelectionNumbers()
        if configuration?.scrollsToEnd == true {
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

    private func content(at index: Int) -> MediaPickerMediaGridItemContent? {
        guard let dataSource = self.dataSource else {
            return nil
        }
        if let asset = dataSource.asset(at: index) {
            return .asset(asset)
        }
        if let extra = dataSource.extra(at: index) {
            return .extra(extra)
        }
        return nil
    }

    private func visibleCell(at index: Int) -> MediaPickerGridCellLayer? {
        var result: MediaPickerGridCellLayer?
        self.gridView?.forEachVisibleCell { visibleIndex, cell in
            if visibleIndex == index {
                result = cell as? MediaPickerGridCellLayer
            }
        }
        return result
    }

    func forEachVisibleItem(_ f: (MediaPickerGridHostItem) -> Void) {
        guard let gridView = self.gridView else {
            return
        }
        gridView.forEachVisibleCell { index, cell in
            if let cell = cell as? MediaPickerGridCellLayer, let content = self.content(at: index) {
                f(MediaPickerMediaGridItem(host: self, index: index, cell: cell, content: content))
            }
        }
    }

    func visibleItem(identifier: String) -> MediaPickerGridHostItem? {
        guard let gridView = self.gridView else {
            return nil
        }
        var result: MediaPickerGridHostItem?
        gridView.forEachVisibleCell { index, cell in
            if let cell = cell as? MediaPickerGridCellLayer, cell.identifier == identifier, let content = self.content(at: index) {
                result = MediaPickerMediaGridItem(host: self, index: index, cell: cell, content: content)
            }
        }
        return result
    }

    func item(at point: CGPoint) -> MediaPickerGridHostItem? {
        guard let gridView = self.gridView else {
            return nil
        }
        let gridPoint = gridView.convert(point, from: self.containerView)
        guard let index = gridView.index(at: gridPoint), let content = self.content(at: index), let cell = self.visibleCell(at: index) else {
            return nil
        }
        return MediaPickerMediaGridItem(host: self, index: index, cell: cell, content: content)
    }

    func defaultTransitionItem() -> MediaPickerGridHostItem? {
        guard let content = self.content(at: 0), let cell = self.visibleCell(at: 0) else {
            return nil
        }
        return MediaPickerMediaGridItem(host: self, index: 0, cell: cell, content: content)
    }

    private func identifier(at index: Int) -> String? {
        return self.dataSource?.identifier(at: index)
    }

    private func updateSelectionNumbers() {
        guard let selectionState = self.interaction.selectionState else {
            self.selectionNumbers = [:]
            return
        }
        let identifiers = (selectionState.selectedItemsIdentifiers()?.array as? [String]) ?? []
        self.selectionNumbers = mediaPickerGridSelectionNumbers(identifiers)
    }

    private func updateContentUnderBar() {
        guard let gridView = self.gridView else {
            return
        }
        var isContentUnderBar = !gridView.targetLevel.isInteractive
        if !isContentUnderBar, let minY = gridView.zoomContentMinY, minY < gridView.geometryInsets.top + gridView.headerHeight - 1.0 {
            isContentUnderBar = true
        }
        if self.isContentUnderBar != isContentUnderBar {
            self.isContentUnderBar = isContentUnderBar
            self.contentUnderBarChanged?()
        }
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
        guard let dataSource = self.dataSource else {
            return nil
        }
        guard let asset = dataSource.asset(at: index) else {
            if let extra = dataSource.extra(at: index) {
                return self.extraCellState(extra, isCompact: isCompact)
            }
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
        var fitAspect: CGFloat?
        if mediaPickerGridFitsImage(fitsLandscapeImages: self.mode.fitsLandscapeImages, pixelWidth: asset.pixelWidth, pixelHeight: asset.pixelHeight) {
            fitAspect = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
        }
        return MediaPickerGridCellState(identifier: identifier, decorations: decorations, isHidden: identifier == self.interaction.hiddenMediaId, fitAspect: fitAspect)
    }

    private func extraCellState(_ extra: MediaPickerGridExtraItem, isCompact: Bool) -> MediaPickerGridCellState {
        let identifier = extra.identifier
        let decorations: MediaPickerGridCellDecorations
        switch extra {
        case let .draft(draft):
            decorations = mediaPickerGridDraftDecorations(isCompact: isCompact, isVideo: draft.isVideo, duration: draft.duration, draftLabel: self.draftLabel)
        case let .media(_, item):
            let number = self.selectionNumbers[identifier]
            let selection = MediaPickerGridSelectionInfo(isSelected: number != nil, number: number, count: self.selectionNumbers.count)
            let edit: MediaPickerGridEditInfo
            if let cached = self.itemInfos[identifier]?.edit {
                edit = cached
            } else {
                edit = (item as? TGMediaEditableItem).flatMap { self.editInfo(for: $0, identifier: identifier) } ?? MediaPickerGridEditInfo()
                self.itemInfos[identifier] = MediaPickerGridItemInfo(asset: MediaPickerGridAssetInfo(), edit: edit)
            }
            decorations = mediaPickerGridMediaDecorations(isCompact: isCompact, isSelectable: self.isSelectable && self.interaction.selectionState != nil, selection: selection, edit: edit)
            if decorations.showsSpoilerBlur || decorations.showsSpoilerOverlay {
                self.spoilerIdentifiers.insert(identifier)
            }
        }
        return MediaPickerGridCellState(identifier: identifier, decorations: decorations, isHidden: identifier == self.interaction.hiddenMediaId)
    }

    func fitBackground(identifier: String, image: () -> UIImage?) -> UIImage? {
        if let background = self.fitBackgrounds[identifier] {
            return background
        }
        if self.pendingFitBackgrounds.contains(identifier) {
            return nil
        }
        guard let image = image() else {
            return nil
        }
        self.pendingFitBackgrounds.insert(identifier)
        Queue.concurrentDefaultQueue().async { [weak self] in
            let colors = mediaEditorGetGradientColors(from: image)
            let background = mediaEditorGenerateGradientImage(size: CGSize(width: 3.0, height: 128.0), colors: colors.array)
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                self.pendingFitBackgrounds.remove(identifier)
                guard let background else {
                    return
                }
                if self.fitBackgrounds.count >= 512 {
                    self.fitBackgrounds.removeAll()
                }
                self.fitBackgrounds[identifier] = background
                self.gridView?.forEachCell { _, cell in
                    (cell as? MediaPickerGridCellLayer)?.setFitBackground(background, identifier: identifier)
                }
            }
        }
        return nil
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
        let info = MediaPickerGridItemInfo(asset: assetInfo, edit: TGMediaAsset(phAsset: asset).flatMap { self.editInfo(for: $0, identifier: identifier) } ?? MediaPickerGridEditInfo())
        if self.itemInfos.count >= MediaPickerMediaGridHost.itemInfoLimit {
            self.itemInfos.removeAll(keepingCapacity: true)
        }
        self.itemInfos[identifier] = info
        return info
    }

    private func editInfo(for item: TGMediaEditableItem, identifier: String) -> MediaPickerGridEditInfo {
        let editingState = self.interaction.editingState
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
            if (cell as? MediaPickerGridCellLayer)?.identifier == identifier || dataSource.identifier(at: index) == identifier {
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
                if !isCompact, let asset = dataSource.asset(at: index) {
                    let _ = self.itemInfo(for: asset)
                }
            }
        }
        self.spoilerIdentifiers.removeAll()
        self.refreshVisibleCells(animated: false)
    }

    private func selectableItem(at index: Int) -> TGMediaSelectableItem? {
        guard let dataSource = self.dataSource else {
            return nil
        }
        if let asset = dataSource.asset(at: index) {
            return TGMediaAsset(phAsset: asset)
        }
        return dataSource.extra(at: index)?.selectableItem
    }

    private func selectionPanned(index: Int, selected: Bool) {
        guard self.isSelectable, let item = self.selectableItem(at: index) else {
            return
        }
        self.interaction.selectionState?.setItem(item, selected: selected, animated: true, sender: nil)
    }

    private func tapped(index: Int, point: CGPoint) {
        guard let gridView = self.gridView, let dataSource = self.dataSource, let content = self.content(at: index) else {
            return
        }
        let cell = self.visibleCell(at: index)
        if let cell, cell.decorations.check != nil, let frame = gridView.frameForItem(at: index) {
            let localPoint = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
            let checkFrame = MediaPickerGridCellLayer.checkFrame(in: CGRect(origin: CGPoint(), size: frame.size)).insetBy(dx: -8.0, dy: -8.0)
            if checkFrame.contains(localPoint), let item = self.selectableItem(at: index) {
                let isSelected = self.selectionNumbers[item.uniqueIdentifier] != nil
                let _ = self.interaction.toggleSelection(item, !isSelected, false)
                return
            }
        }
        switch content {
        case let .asset(asset):
            if self.downloadProgress[asset.localIdentifier] != nil {
                self.interaction.downloadManager.cancel(identifier: asset.localIdentifier)
                return
            }
            guard let base = dataSource.base, let assetIndex = dataSource.assetIndex(at: index) else {
                return
            }
            let fetchResult = base.fetchResult
            let fetchIndex = mediaPickerGridFetchIndex(gridIndex: assetIndex, count: fetchResult.count, isReversed: base.reversed)
            self.interaction.openMedia(fetchResult, fetchIndex, cell?.transitionImage)
        case let .extra(extra):
            if case let .draft(draft) = extra {
                self.interaction.openDraft(draft, cell?.transitionImage)
            }
        }
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

    private func removeDownloadTracking() {
        for (_, disposable) in self.downloadDisposables {
            disposable.dispose()
        }
        self.downloadDisposables.removeAll()
        self.downloadProgress.removeAll()
        self.downloadIndices.removeAll()
        for (_, overlay) in self.downloadOverlays {
            overlay.view.removeFromSuperview()
        }
        self.downloadOverlays.removeAll()
    }

    private func scheduleDownloadTracking() {
        if self.isDownloadTrackingScheduled {
            return
        }
        self.isDownloadTrackingScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.isDownloadTrackingScheduled = false
            self.updateDownloadTracking()
        }
    }

    private static let downloadStatusSize = CGSize(width: 40.0, height: 40.0)

    private func downloadStatusFrame(index: Int) -> CGRect? {
        guard let frame = self.gridView?.contentFrameForItem(at: index) else {
            return nil
        }
        let size = MediaPickerMediaGridHost.downloadStatusSize
        return CGRect(origin: CGPoint(x: floorToScreenPixels(frame.midX - size.width / 2.0), y: floorToScreenPixels(frame.midY - size.height / 2.0)), size: size)
    }

    private func updateDownloadTracking() {
        guard self.mode.tracksDownloads, let gridView = self.gridView, let dataSource = self.dataSource, dataSource.base != nil else {
            return
        }
        var visible: [String: Int] = [:]
        gridView.forEachVisibleCell { index, _ in
            if let asset = dataSource.asset(at: index) {
                visible[asset.localIdentifier] = index
            }
        }
        self.downloadIndices = visible
        for (identifier, disposable) in self.downloadDisposables where visible[identifier] == nil {
            disposable.dispose()
            self.downloadDisposables.removeValue(forKey: identifier)
            self.downloadProgress.removeValue(forKey: identifier)
            if let overlay = self.downloadOverlays.removeValue(forKey: identifier) {
                overlay.view.removeFromSuperview()
            }
        }
        for (identifier, index) in visible {
            if self.downloadDisposables[identifier] == nil {
                self.downloadDisposables[identifier] = (self.interaction.downloadManager.downloadProgress(identifier: identifier)
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    self?.downloadStatusChanged(identifier: identifier, status: status)
                })
            }
            if let overlay = self.downloadOverlays[identifier], let frame = self.downloadStatusFrame(index: index), overlay.view.frame != frame {
                overlay.view.frame = frame
            }
        }
    }

    private func downloadStatusChanged(identifier: String, status: AssetDownloadStatus) {
        guard self.downloadDisposables[identifier] != nil else {
            return
        }
        switch status {
        case let .progress(value):
            self.downloadProgress[identifier] = value
            let overlay: RadialStatusNode
            if let current = self.downloadOverlays[identifier] {
                overlay = current
            } else {
                overlay = RadialStatusNode(backgroundNodeColor: UIColor(rgb: 0x000000, alpha: 0.6))
                overlay.isUserInteractionEnabled = false
                self.downloadOverlays[identifier] = overlay
                self.gridView?.overlayView.addSubview(overlay.view)
            }
            if let index = self.downloadIndices[identifier], let frame = self.downloadStatusFrame(index: index) {
                overlay.view.frame = frame
            }
            overlay.transitionToState(.progress(color: .white, lineWidth: nil, value: max(0.027, CGFloat(value)), cancelEnabled: true, animateRotation: true))
        case .none, .completed, .failed:
            self.downloadProgress.removeValue(forKey: identifier)
            if let overlay = self.downloadOverlays.removeValue(forKey: identifier) {
                overlay.transitionToState(.none, animated: true, completion: { [weak overlay] in
                    overlay?.view.removeFromSuperview()
                })
            }
            if case .none = status {
                break
            }
            self.downloadDisposables.removeValue(forKey: identifier)?.dispose()
            self.scheduleDownloadTracking()
        }
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
