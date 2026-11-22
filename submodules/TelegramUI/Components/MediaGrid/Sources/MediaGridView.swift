import Foundation
import UIKit
import QuartzCore
import CoreList

public final class MediaGridView: UIView {
    private let dataSource: MediaGridDataSource
    let engine: PhysicsScrollEngine
    let pool: MediaGridCellPool
    private(set) var activeLayoutLayer: MediaGridLayoutLayer
    private var spareLayoutLayer: MediaGridLayoutLayer?
    private(set) var transition: MediaGridZoomTransition?
    private var pendingZoom: (anchor: MediaGridZoomAnchor, relativePosition: CGPoint)?
    private var transitionAnchor: (anchor: MediaGridZoomAnchor, relativePosition: CGPoint)?
    private var pinch: PinchSession?

    public private(set) var level: MediaGridLevel = .three
    private var layoutLevel: MediaGridLevel = .three
    private var itemCount: Int
    private(set) var gridLayout: MediaGridLayout?
    var currentLayout: MediaGridUniformLayout? {
        return self.gridLayout as? MediaGridUniformLayout
    }
    private var needsLayoutRebuild = true
    private var prefetchPlanner = MediaGridPrefetchPlanner()
    private var prefetchLayout: MediaGridLayout?
    private var aspects: [Float]?
    private var aspectGeneration = 0
    private var cancelAspectLoad: (() -> Void)?
    private var isLoadingAspects = false
    private var aspectTables: [MediaGridAspectTable] = []
    private var pendingTableKeys = Set<MediaGridAspectTable.Key>()
    private var listVersion = 0
    private var aspectsVersion = 0
    private var tableVersion = 0
    private var changeLog: [(version: Int, changes: MediaGridChanges)] = []
    private var isApplyingAspectChanges = false
    private var isFlightActive = false
    private var isSelecting = false
    var aspectLoader: (Int, @escaping MediaGridAspectRatioReader, @escaping ([Float]) -> Void) -> (() -> Void) = { count, reader, completion in
        let index = MediaGridAspectIndex(count: count, aspectRatio: reader)
        index.build(completion: completion)
        return {
            index.cancel()
        }
    }
    var aspectChangeApplier: ([Float], [MediaGridChanges], @escaping MediaGridAspectRatioReader, @escaping ([Float]) -> Void) -> (() -> Void) = { aspects, changes, reader, completion in
        let index = MediaGridAspectIndex(aspects: aspects)
        index.build(applying: changes, aspectRatio: reader, completion: completion)
        return {
            index.cancel()
        }
    }
    var aspectTableBuilder: (MediaGridAspectTable.Key, [Float], @escaping (MediaGridAspectTable) -> Void) -> Void = { key, aspects, completion in
        DispatchQueue.global(qos: .userInitiated).async {
            let table = MediaGridAspectTable(key: key, aspects: aspects)
            DispatchQueue.main.async {
                completion(table)
            }
        }
    }
    private var scrollStep: CGFloat = 0.0
    private var lastScrolledOffset: CGFloat?
    private var flightTargetOffset: CGFloat?
    private var transitionPrepareRanges: [Range<Int>] = []
    private var lastPreparedRanges: [Range<Int>]?
    private var motionSample: (time: CFTimeInterval, offset: CGFloat)? {
        didSet {
            if self.motionSample == nil {
                self.lastScrollEvent = nil
                self.lastScrolledOffset = nil
                self.scrollStep = 0.0
            }
        }
    }
    private var lastScrollEvent: (time: CFTimeInterval, offset: CGFloat)?
    private var lastFastMotionTime: CFTimeInterval?
    private var motionSettleScheduled = false
    var motionClock: () -> CFTimeInterval = CACurrentMediaTime
    static let fastScrollSpeed: CGFloat = 2.0
    static let motionSampleInterval: CFTimeInterval = 0.05
    static let motionSettleDelay: CFTimeInterval = 0.12
    static let minimumJumpInterval: CFTimeInterval = 0.008
    private var settledFlightOffset: CGFloat?
    private var isDragging = false
    private var isNotifyingScroll = false
    private var pendingContentOffset: CGFloat?
    private(set) var dateCache: [Int: Date?] = [:]
    static let dateCacheLimit = 256
    private var isLandscape: Bool?
    private var anchorsNextRebuild = false
    private var haltsNextRelease = false
    private var rotationAnchor: (index: Int, fraction: CGFloat, offset: CGFloat, version: Int)?
    private var defersCellBinding = false
    private var isCellBindingScheduled = false
    private var hasWaitedForLaunchImages = false
    static let launchImageWait: TimeInterval = 0.05
    public private(set) var launchImageWaitDuration: CFTimeInterval?

    var scaleOverride: CGFloat? {
        didSet {
            self.invalidateGridLayout()
        }
    }

    public var geometryInsets: UIEdgeInsets = .zero {
        didSet {
            if self.geometryInsets != oldValue {
                self.invalidateGridLayout()
            }
        }
    }

    public var compactLevelTopInset: CGFloat? {
        didSet {
            if self.compactLevelTopInset != oldValue {
                self.invalidateGridLayout()
            }
        }
    }

    public var onTargetLevelChanged: ((MediaGridLevel) -> Void)? {
        didSet {
            self.reportedTargetLevel = self.targetLevel
        }
    }
    private var reportedTargetLevel: MediaGridLevel?
    private var interactiveTopInset: CGFloat = 0.0
    private var headerFrame: CGRect = .zero

    public var cellAspect: CGFloat = 1.0 {
        didSet {
            if self.cellAspect != oldValue {
                self.invalidateGridLayout()
            }
        }
    }

    public var onScroll: ((CGFloat) -> Void)?
    public var onLevelChanged: ((MediaGridLevel) -> Void)?
    public var isZoomEnabled: Bool = true {
        didSet {
            self.updateGestureAvailability()
        }
    }
    public var onTapItem: ((Int) -> Void)?
    public var isItemSelected: ((Int) -> Bool)? {
        didSet {
            self.activeLayoutLayer.isItemSelected = self.isItemSelected
            self.transition?.incoming.isItemSelected = self.isItemSelected
            self.updateSelectionForVisibleItems()
        }
    }
    public var onSelectionPan: ((Int, Bool) -> Void)?
    public var onSelectionPanBegan: (() -> Void)?
    public var onTapItemAt: ((Int, CGPoint) -> Void)?
    public var onWillBeginDragging: (() -> Void)?
    public var onDidEndDragging: (() -> Void)?
    public var bounces = true
    public var onZoomingChanged: ((Bool) -> Void)?
    public var onZoomFrame: (() -> Void)?

    public var zoomContentMinY: CGFloat? {
        guard let transition = self.transition else {
            return nil
        }
        var minY = CGFloat.greatestFiniteMagnitude
        for layer in [transition.outgoing, transition.incoming] where layer.opacity > 0.0 && !layer.isHidden {
            for (_, cell) in layer.visibleCells where !cell.isHidden {
                minY = min(minY, layer.convert(cell.frame, to: self.layer).minY - self.bounds.minY)
            }
        }
        return minY == CGFloat.greatestFiniteMagnitude ? nil : minY
    }
    private var reportedZooming = false
    public let overlayView = UIView()

    public var headerView: UIView? {
        didSet {
            if self.headerView !== oldValue {
                oldValue?.removeFromSuperview()
                if let headerView = self.headerView {
                    self.engine.contentHost.insertSubview(headerView, belowSubview: self.overlayView)
                }
                self.invalidateGridLayout()
            }
        }
    }

    public var headerHeight: CGFloat = 0.0 {
        didSet {
            if self.headerHeight != oldValue {
                self.invalidateGridLayout()
            }
        }
    }

    public var cameraView: UIView? {
        didSet {
            if self.cameraView !== oldValue {
                self.endInteraction()
                oldValue?.removeFromSuperview()
                if let cameraView = self.cameraView {
                    self.engine.contentHost.addSubview(cameraView)
                }
                self.invalidateGridLayout()
            }
        }
    }

    public var cameraLevels: Set<MediaGridLevel> = [.three] {
        didSet {
            if self.cameraLevels != oldValue {
                self.endInteraction()
                self.invalidateGridLayout()
            }
        }
    }

    public var accessoryView: UIView? {
        didSet {
            if self.accessoryView !== oldValue {
                self.endInteraction()
                oldValue?.removeFromSuperview()
                if let accessoryView = self.accessoryView {
                    self.engine.contentHost.addSubview(accessoryView)
                }
                self.invalidateGridLayout()
            }
        }
    }

    public var accessoryLevels: Set<MediaGridLevel> = [.three, .five] {
        didSet {
            if self.accessoryLevels != oldValue {
                self.endInteraction()
                self.invalidateGridLayout()
            }
        }
    }

    public var compactLevelsRequestSharpImages: Bool = false {
        didSet {
            if self.compactLevelsRequestSharpImages != oldValue {
                self.activeLayoutLayer.compactRequestsSharpImages = self.compactLevelsRequestSharpImages
                self.spareLayoutLayer?.compactRequestsSharpImages = self.compactLevelsRequestSharpImages
                if !self.layoutLevel.isInteractive {
                    self.requestVisibleSharpImages()
                    self.updatePrefetch(offset: self.engine.offset)
                }
            }
        }
    }

    public var isScrollingLockedAtTop: Bool = false {
        didSet {
            if self.isScrollingLockedAtTop == oldValue {
                return
            }
            if self.isScrollingLockedAtTop {
                self.stopScrollAnimation()
                self.engine.isScrollEnabled = false
                if self.engine.offset != 0.0 {
                    self.setContentOffset(0.0)
                }
            } else {
                self.engine.isScrollEnabled = self.transition == nil && self.pinch == nil && !self.isSelecting
            }
        }
    }

    public var availableLevels: [MediaGridLevel] = MediaGridLevel.allCases {
        didSet {
            let sorted = self.availableLevels.sorted()
            if sorted.isEmpty {
                self.availableLevels = oldValue
                return
            }
            if sorted != self.availableLevels {
                self.availableLevels = sorted
                return
            }
            if sorted != oldValue, !sorted.contains(self.level) {
                self.setLevel(self.level, animated: false)
            }
        }
    }

    public var isSelectionPanEnabled: Bool = true {
        didSet {
            if self.isSelectionPanEnabled != oldValue {
                self.updateGestureAvailability()
            }
        }
    }

    private let tapRecognizer = UITapGestureRecognizer()
    let selectionGesture = MediaGridSelectionGesture()
    private let pinchRecognizer = UIPinchGestureRecognizer()
    private let pinchDelegate = MediaGridPinchDelegate()
    private let touchFilter = MediaGridTouchFilter()

    private static let cameraSlots: Set<MediaGridSlot> = [MediaGridSlot(row: 0, column: 0), MediaGridSlot(row: 1, column: 0)]

    private func cameraSlots(for level: MediaGridLevel) -> Set<MediaGridSlot> {
        return self.cameraLevels.contains(level) && self.cameraView != nil ? MediaGridView.cameraSlots : []
    }

    private func accessorySlots(for level: MediaGridLevel) -> Set<MediaGridSlot> {
        guard self.accessoryView != nil, self.accessoryLevels.contains(level) else {
            return []
        }
        let column = self.cameraSlots(for: level).isEmpty ? 0 : 1
        guard column < level.columns else {
            return []
        }
        return [MediaGridSlot(row: 0, column: column)]
    }

    private func reservedSlots(for level: MediaGridLevel) -> Set<MediaGridSlot> {
        return self.cameraSlots(for: level).union(self.accessorySlots(for: level))
    }

    public init(dataSource: MediaGridDataSource, cellFactory: @escaping () -> MediaGridCellLayer) {
        self.dataSource = dataSource
        self.itemCount = max(0, dataSource.count)
        self.engine = PhysicsScrollEngine()
        self.engine.decelerationMode = .keyframe
        self.pool = MediaGridCellPool(factory: cellFactory)
        self.activeLayoutLayer = MediaGridLayoutLayer(dataSource: dataSource, pool: self.pool)

        super.init(frame: .zero)

        self.clipsToBounds = true
        self.addSubview(self.engine.contentHost)
        self.engine.contentHost.layer.addSublayer(self.activeLayoutLayer)
        self.overlayView.isUserInteractionEnabled = false
        self.engine.contentHost.addSubview(self.overlayView)
        self.tapRecognizer.addTarget(self, action: #selector(self.tapped(_:)))
        self.touchFilter.receivesTouch = { [weak self] view in
            return self?.gridGesturesReceiveTouch(in: view) ?? true
        }
        self.tapRecognizer.delegate = self.touchFilter
        self.addGestureRecognizer(self.tapRecognizer)
        self.selectionGesture.sideInset = 44.0
        self.selectionGesture.itemAt = { [weak self] point in
            guard let self, let index = self.index(at: point) else {
                return nil
            }
            return (index, self.isItemSelected?(index) ?? false)
        }
        self.selectionGesture.updateSelection = { [weak self] index, selected in
            guard let self else {
                return
            }
            self.onSelectionPan?(index, selected)
            self.updateSelectionForVisibleItems()
        }
        self.selectionGesture.updateIsScrollEnabled = { [weak self] isEnabled in
            guard let self else {
                return
            }
            let began = !isEnabled && !self.isSelecting
            self.isSelecting = !isEnabled
            if began {
                self.stopScrollAnimation()
            }
            self.engine.isScrollEnabled = isEnabled && self.transition == nil && self.pinch == nil && !self.isScrollingLockedAtTop
            if began {
                self.onSelectionPanBegan?()
            }
            if isEnabled {
                self.applyAspects()
            }
        }
        self.selectionGesture.delegate = self.touchFilter
        self.addGestureRecognizer(self.selectionGesture)
        self.pinchRecognizer.addTarget(self, action: #selector(self.pinched(_:)))
        self.pinchDelegate.shouldBegin = { [weak self] in
            return self?.canBeginPinch ?? false
        }
        self.pinchDelegate.recognizesSimultaneously = { [weak self] other in
            guard let self else {
                return false
            }
            return other.view === self.engine.contentHost && other is UIPanGestureRecognizer
        }
        self.pinchRecognizer.delegate = self.pinchDelegate
        self.addGestureRecognizer(self.pinchRecognizer)
        self.engine.onScroll = { [weak self] offset in
            self?.scrolled(to: offset)
        }
        self.engine.onWillBeginDragging = { [weak self] in
            guard let self else {
                return
            }
            self.stopScrollAnimation()
            self.isDragging = true
            self.onWillBeginDragging?()
        }
        self.engine.onDidEndDragging = { [weak self] in
            guard let self else {
                return
            }
            self.isDragging = false
            self.haltsNextRelease = false
            self.holdsDragAtTop = false
            self.applyAspects()
            self.onDidEndDragging?()
        }
        self.engine.onFlightChanged = { [weak self] flight in
            self?.flightChanged(settledOffset: flight?.settledOffset)
        }
        self.engine.shouldStopScrollingOnRelease = { [weak self] _ in
            guard let self else {
                return false
            }
            return self.haltsNextRelease || self.holdsDragAtTop
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.scrollAnimationLink?.invalidate()
        self.engine.tearDown()
        self.resetPrefetch()
        if let transition = self.transition {
            transition.removeAnimations()
            transition.outgoing.removeAllCells()
            transition.incoming.removeAllCells()
        }
        self.activeLayoutLayer.removeAllCells()
    }

    public var contentOffset: CGFloat {
        return self.engine.offset
    }

    public var contentHeight: CGFloat {
        return self.gridLayout?.contentHeight ?? 0.0
    }

    public var isUserScrolling: Bool {
        return self.isDragging || self.engine.isDecelerating
    }

    public private(set) var isMovingFast = false
    public var onMovingFastChanged: ((Bool) -> Void)?

    public var topVisibleIndex: Int? {
        guard let layout = self.gridLayout, layout.count > 0 else {
            return nil
        }
        let minY = min(max(layout.geometry.topInset, self.engine.offset + layout.geometry.topInset), max(layout.geometry.topInset, layout.contentHeight - layout.geometry.bottomInset - 1.0))
        let strip = CGRect(x: 0.0, y: minY, width: layout.geometry.width, height: max(1.0, self.bounds.height))
        for index in layout.indexRange(intersecting: strip) {
            if layout.frame(at: index).intersects(strip) {
                return index
            }
        }
        return nil
    }

    public var topVisibleDate: Date? {
        guard let index = self.topVisibleIndex else {
            return nil
        }
        if let cached = self.dateCache[index] {
            return cached
        }
        let date = self.dataSource.date(at: index)
        if self.dateCache.count >= MediaGridView.dateCacheLimit {
            self.dateCache.removeAll(keepingCapacity: true)
        }
        self.dateCache[index] = .some(date)
        return date
    }

    private var maxOffset: CGFloat {
        return max(0.0, self.contentHeight - self.bounds.height)
    }

    public func reloadData() {
        self.stopScrollAnimation()
        self.endInteraction()
        self.rotationAnchor = nil
        self.itemCount = max(0, self.dataSource.count)
        self.aspectGeneration += 1
        self.cancelAspectLoad?()
        self.cancelAspectLoad = nil
        self.aspects = nil
        self.isLoadingAspects = false
        self.isApplyingAspectChanges = false
        self.aspectTables = []
        self.pendingTableKeys = []
        self.changeLog = []
        self.aspectsVersion = self.listVersion
        self.tableVersion = self.listVersion
        self.needsLayoutRebuild = true
        self.dateCache = [:]
        self.motionSample = nil
        self.lastPreparedRanges = nil
        self.resetPrefetch()
        self.activeLayoutLayer.removeAllCells()
        self.updateGridLayout()
    }

    public func apply(_ changes: MediaGridChanges) {
        let newCount = max(0, self.dataSource.count)
        guard changes.isValid(oldCount: self.itemCount, newCount: newCount) else {
            self.reloadData()
            return
        }
        if changes.isEmpty {
            return
        }
        self.stopScrollAnimation()
        self.endInteraction()
        self.rotationAnchor = nil
        var anchor: (index: Int, y: CGFloat)?
        if let layout = self.gridLayout, let top = self.topVisibleIndex, let survivor = changes.nearestSurvivor(toOld: top, oldCount: self.itemCount), let index = changes.newIndex(forOld: survivor) {
            anchor = (index, layout.frame(at: top).minY - self.engine.offset)
        }
        self.itemCount = newCount
        self.dateCache = [:]
        self.lastPreparedRanges = nil
        self.listVersion += 1
        self.changeLog.append((self.listVersion, changes))
        self.updateAspects()
        guard let previous = self.gridLayout, self.bounds.width > 0.0, self.bounds.height > 0.0 else {
            self.invalidateGridLayout()
            return
        }
        let layout = self.makeLayout(level: self.layoutLevel, geometry: previous.geometry)
        self.motionSample = nil
        self.prefetchPlanner.apply(changes)
        self.prefetchLayout = layout
        self.gridLayout = layout
        self.activeLayoutLayer.apply(changes, layout: layout)
        self.activeLayoutLayer.frame = CGRect(x: 0.0, y: 0.0, width: self.bounds.width, height: layout.contentHeight)
        self.layoutCamera(layout: layout)
        let isMoving = self.isDragging || self.engine.isDecelerating
        var target = anchor.map { layout.frame(at: $0.index).minY - $0.y } ?? self.engine.offset
        if !isMoving || layout.count == 0 {
            target = min(max(0.0, target), self.maxOffset)
        }
        let delta = target - self.engine.offset
        if delta < 0.0 {
            self.engine.applyShift(delta)
            self.engine.setEdges(min: 0.0, max: self.maxOffset)
        } else {
            self.engine.setEdges(min: 0.0, max: self.maxOffset)
            if delta > 0.0 {
                self.engine.applyShift(delta)
            }
        }
        if self.isDragging {
            self.engine.reanchorDragToCurrentPosition()
        }
        self.scrolled(to: self.engine.offset)
        self.startAspectLoad()
    }

    private func updateAspects() {
        self.aspectGeneration += 1
        self.pendingTableKeys = []
        self.cancelAspectLoad?()
        self.cancelAspectLoad = nil
        self.isApplyingAspectChanges = false
        if self.isLoadingAspects {
            self.isLoadingAspects = false
            self.aspects = nil
        }
        if let aspects = self.aspects {
            let base = self.aspectsVersion
            let version = self.listVersion
            let generation = self.aspectGeneration
            let pending = self.changeLog.filter { $0.version > base }.map { $0.changes }
            self.isApplyingAspectChanges = true
            self.cancelAspectLoad = self.aspectChangeApplier(aspects, pending, self.dataSource.aspectRatioReader(), { [weak self] aspects in
                guard let self, self.aspectGeneration == generation else {
                    return
                }
                self.isApplyingAspectChanges = false
                self.cancelAspectLoad = nil
                self.aspects = aspects
                self.aspectsVersion = version
                self.pruneChangeLog()
                self.requestCurrentAspectTable()
            })
        }
        self.pruneChangeLog()
    }

    private func pruneChangeLog() {
        let aspectsBase = self.aspects == nil ? self.listVersion : self.aspectsVersion
        let tableBase = self.aspectTables.isEmpty ? self.listVersion : self.tableVersion
        let base = min(aspectsBase, tableBase)
        self.changeLog.removeAll(where: { $0.version <= base })
    }

    private func aspectPatches(since version: Int) -> [MediaGridChanges] {
        return self.changeLog.filter { $0.version > version }.map { $0.changes }
    }

    public func updateLayout(size: CGSize, safeInsets: UIEdgeInsets, isLandscape: Bool, transition duration: TimeInterval) {
        let previousLandscape = self.isLandscape
        self.isLandscape = isLandscape
        let insets = UIEdgeInsets(top: self.geometryInsets.top, left: safeInsets.left, bottom: safeInsets.bottom, right: safeInsets.right)
        let rotates = previousLandscape.map { $0 != isLandscape } ?? false
        let resizes = self.gridLayout.map { $0.geometry.width != size.width } ?? false
        let reflows = rotates || resizes || insets.left != self.geometryInsets.left || insets.right != self.geometryInsets.right
        guard reflows else {
            self.geometryInsets = insets
            return
        }
        self.endInteraction()
        self.stopMotion()
        let previousLevel = self.level
        if rotates {
            let target = self.level.rotated(toLandscape: isLandscape, within: self.availableLevels)
            if target != self.level {
                self.level = target
                self.layoutLevel = target
                self.needsLayoutRebuild = true
            }
        }
        if duration > 0.0, self.gridLayout != nil, self.window != nil {
            let fade = CATransition()
            fade.type = .fade
            fade.duration = duration
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.layer.add(fade, forKey: kCATransition)
        }
        self.anchorsNextRebuild = true
        self.geometryInsets = insets
        self.invalidateGridLayout()
        if self.bounds.size == size || self.level != previousLevel {
            self.defersCellBinding = duration > 0.0 && self.window != nil
            UIView.performWithoutAnimation {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.engine.contentHost.frame = self.bounds
                self.updateGridLayout()
                CATransaction.commit()
            }
            self.defersCellBinding = false
        }
        if self.level != previousLevel {
            self.updateGestureAvailability()
            self.onLevelChanged?(self.level)
        }
        self.noteTargetLevel()
    }

    private func stopMotion() {
        self.stopScrollAnimation()
        if self.isDragging {
            self.haltsNextRelease = true
            let isEnabled = self.engine.isScrollEnabled
            self.engine.isScrollEnabled = false
            self.engine.isScrollEnabled = isEnabled
        }
        self.engine.haltMotionInPlace()
        if self.isDragging {
            self.engine.reanchorDragToCurrentPosition()
        } else {
            self.haltsNextRelease = false
        }
    }

    private func topAnchor(in layout: MediaGridLayout) -> (index: Int, fraction: CGFloat)? {
        guard let index = self.topVisibleIndex, index < layout.count else {
            return nil
        }
        let frame = layout.frame(at: index)
        let line = self.engine.offset + layout.geometry.topInset
        let fraction = frame.height > 0.0 ? min(1.0, max(0.0, (line - frame.minY) / frame.height)) : 0.0
        return (index, fraction)
    }

    public func setContentOffset(_ y: CGFloat) {
        guard y.isFinite else {
            return
        }
        self.stopScrollAnimation()
        guard self.gridLayout != nil else {
            self.pendingContentOffset = y
            return
        }
        self.endInteraction()
        let offset = min(max(0.0, y), self.maxOffset)
        if self.isDragging {
            self.engine.applyShift(offset - self.engine.offset)
            self.engine.reanchorDragToCurrentPosition()
        } else {
            self.engine.setOffset(offset)
        }
        self.scrolled(to: offset)
    }

    public func reanchorDrag() {
        if self.isDragging {
            self.engine.reanchorDragToCurrentPosition()
        }
    }

    public var holdsDragAtTop = false {
        didSet {
            if self.holdsDragAtTop && !oldValue {
                self.stopScrollAnimation()
                self.engine.haltMotionInPlace()
                if self.engine.offset != 0.0 {
                    self.setContentOffset(0.0)
                }
            }
        }
    }

    public func endDragHold() {
        if self.holdsDragAtTop && self.isDragging {
            self.haltsNextRelease = true
        }
        self.holdsDragAtTop = false
    }

    private func noteZoomingChanged() {
        let isZooming = self.isZooming
        if isZooming != self.reportedZooming {
            self.reportedZooming = isZooming
            self.onZoomingChanged?(isZooming)
            self.onZoomFrame?()
        }
        self.noteTargetLevel()
    }

    public var targetLevel: MediaGridLevel {
        if let pinch = self.pinch, pinch.isTracking {
            return pinch.state.settle(velocity: 0.0)
        }
        if let transition = self.transition {
            let progress = transition.destination ?? transition.progress
            return progress >= 0.5 ? transition.targetLevel : transition.sourceLevel
        }
        return self.pinch != nil ? self.layoutLevel : self.level
    }

    private func noteTargetLevel() {
        let target = self.targetLevel
        if target != self.reportedTargetLevel {
            self.reportedTargetLevel = target
            self.onTargetLevelChanged?(target)
        }
    }

    public func scrollToEnd() {
        self.setContentOffset(CGFloat.greatestFiniteMagnitude)
    }

    static let scrollToTopDuration: CFTimeInterval = 0.3
    static let scrollToTopMaxDistance: CGFloat = 2.0

    private var scrollAnimation: (from: CGFloat, start: CFTimeInterval)?
    private var scrollAnimationLink: CADisplayLink?
    private var velocityTransfer: (velocity: CGFloat, start: CFTimeInterval)?
    var _testAllowsWindowlessScrollAnimation = false

    public var isAnimatingScroll: Bool {
        return self.scrollAnimation != nil || self.velocityTransfer != nil
    }

    public func scrollToTop(animated: Bool) {
        self.stopScrollAnimation()
        guard animated, self.gridLayout != nil, self.engine.offset > 0.5, self.window != nil || self._testAllowsWindowlessScrollAnimation else {
            self.setContentOffset(0.0)
            return
        }
        self.endInteraction()
        self.engine.haltMotionInPlace()
        let limit = MediaGridView.scrollToTopMaxDistance * self.bounds.height
        var from = self.engine.offset
        if from > limit {
            from = limit
            self.engine.setOffset(from)
            self.scrolled(to: from)
        }
        self.scrollAnimation = (from, self.motionClock())
        if self.window != nil {
            let link = CADisplayLink(target: MediaGridDisplayLinkTarget(self), selector: #selector(MediaGridDisplayLinkTarget.tick))
            link.add(to: .main, forMode: .common)
            self.scrollAnimationLink = link
        }
    }

    public func transferVelocity(_ velocity: CGFloat) {
        guard velocity > 0.0, velocity.isFinite, self.gridLayout != nil, self.window != nil || self._testAllowsWindowlessScrollAnimation, !self.isScrollingLockedAtTop else {
            return
        }
        self.stopScrollAnimation()
        self.endInteraction()
        self.engine.haltMotionInPlace()
        self.velocityTransfer = (velocity, self.motionClock())
        if self.window != nil {
            let link = CADisplayLink(target: MediaGridDisplayLinkTarget(self), selector: #selector(MediaGridDisplayLinkTarget.tick))
            link.add(to: .main, forMode: .common)
            self.scrollAnimationLink = link
        }
    }

    private func stepVelocityTransfer() {
        guard let transfer = self.velocityTransfer else {
            return
        }
        let t = max(0.0, self.motionClock() - transfer.start)
        let velocity = transfer.velocity * 15.0 * CGFloat(pow(MediaGridView.velocityTransferDecelerationRate, 1000.0 * t))
        let maxOffset = max(0.0, self.contentHeight - self.bounds.height)
        var offset = self.engine.offset + velocity
        var ended = abs(velocity) < 0.1
        if offset >= maxOffset {
            offset = maxOffset
            ended = true
        }
        if ended {
            self.stopScrollAnimation()
        }
        self.engine.setOffset(offset)
        self.scrolled(to: offset)
    }

    private static let velocityTransferDecelerationRate: Double = 0.998

    func _testStepTransferredVelocity() {
        self.stepVelocityTransfer()
    }

    private func stopScrollAnimation() {
        self.scrollAnimation = nil
        self.velocityTransfer = nil
        self.scrollAnimationLink?.invalidate()
        self.scrollAnimationLink = nil
    }

    fileprivate func stepScrollAnimation() {
        if self.velocityTransfer != nil {
            self.stepVelocityTransfer()
            return
        }
        guard let animation = self.scrollAnimation else {
            self.stopScrollAnimation()
            return
        }
        let t = min(1.0, max(0.0, (self.motionClock() - animation.start) / MediaGridView.scrollToTopDuration))
        let eased = 1.0 - pow(1.0 - CGFloat(t), 3.0)
        let offset = animation.from * (1.0 - eased)
        if t >= 1.0 {
            self.stopScrollAnimation()
        }
        self.engine.setOffset(offset)
        self.scrolled(to: offset)
    }

    func _testStepScrollAnimation() {
        self.stepScrollAnimation()
    }

    public var isCameraVisible: Bool {
        guard let cameraView = self.cameraView, !cameraView.isHidden, cameraView.alpha > 0.0, self.bounds.height > 0.0 else {
            return false
        }
        let viewport = CGRect(x: 0.0, y: self.engine.offset, width: self.bounds.width, height: self.bounds.height)
        return viewport.intersects(cameraView.frame)
    }

    public var isZooming: Bool {
        return self.transition != nil || self.pinch != nil
    }

    public func contentFrameForItem(at index: Int) -> CGRect? {
        guard let layout = self.gridLayout, index >= 0, index < layout.count else {
            return nil
        }
        return layout.frame(at: index)
    }

    public func forEachVisibleCell(_ f: (Int, MediaGridCellLayer) -> Void) {
        for (index, cell) in self.activeLayoutLayer.visibleCells {
            f(index, cell)
        }
    }

    public func forEachCell(_ f: (Int, MediaGridCellLayer) -> Void) {
        for (index, cell) in self.activeLayoutLayer.visibleCells {
            f(index, cell)
        }
        if let incoming = self.transition?.incoming, incoming !== self.activeLayoutLayer {
            for (index, cell) in incoming.visibleCells {
                f(index, cell)
            }
        }
    }

    public func reloadImages(at indices: IndexSet) {
        guard !indices.isEmpty else {
            return
        }
        self.activeLayoutLayer.invalidateImages(indices)
        if let incoming = self.transition?.incoming, incoming !== self.activeLayoutLayer {
            incoming.invalidateImages(indices)
        }
    }

    func gridGesturesReceiveTouch(in view: UIView?) -> Bool {
        guard let view else {
            return true
        }
        if let headerView = self.headerView, view.isDescendant(of: headerView) {
            return false
        }
        if let cameraView = self.cameraView, view.isDescendant(of: cameraView) {
            return false
        }
        if let accessoryView = self.accessoryView, view.isDescendant(of: accessoryView) {
            return false
        }
        return true
    }

    public func index(at point: CGPoint) -> Int? {
        guard let layout = self.gridLayout else {
            return nil
        }
        let host = self.engine.contentHost
        return layout.index(at: CGPoint(x: point.x - host.frame.minX, y: point.y - host.frame.minY + self.engine.offset))
    }

    public func updateSelectionForVisibleItems() {
        self.activeLayoutLayer.refreshSelection()
        self.transition?.incoming.refreshSelection()
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            self.handleTap(at: recognizer.location(in: self))
        }
    }

    private func handleTap(at point: CGPoint) {
        guard self.transition == nil, self.pinch == nil, let index = self.index(at: point) else {
            return
        }
        if self.layoutLevel.isInteractive {
            self.onTapItem?(index)
            self.onTapItemAt?(index, point)
            self.updateSelectionForVisibleItems()
        } else if self.isZoomEnabled, let target = self.layoutLevel.zoomedIn(within: self.availableLevels) {
            self.setLevel(target, animated: true, anchor: MediaGridZoomAnchor(index: index, pointInView: point))
        }
    }

    public var canZoomIn: Bool {
        return self.isZoomEnabled && self.level.zoomedIn(within: self.availableLevels) != nil
    }

    public var canZoomOut: Bool {
        return self.isZoomEnabled && self.level.zoomedOut(within: self.availableLevels) != nil
    }

    public func zoomIn() {
        self.endInteraction()
        guard self.isZoomEnabled, let target = self.level.zoomedIn(within: self.availableLevels) else {
            return
        }
        self.setLevel(target, animated: true, anchor: self.centerAnchor())
    }

    public func zoomOut() {
        self.endInteraction()
        guard self.isZoomEnabled, let target = self.level.zoomedOut(within: self.availableLevels) else {
            return
        }
        self.setLevel(target, animated: true, anchor: self.centerAnchor())
    }

    private func centerAnchor() -> MediaGridZoomAnchor? {
        return self.anchor(at: CGPoint(x: self.bounds.midX, y: self.bounds.midY))
    }

    private func anchor(at center: CGPoint) -> MediaGridZoomAnchor? {
        guard let layout = self.gridLayout, layout.count > 0, self.bounds.height > 0.0 else {
            return nil
        }
        if let index = self.index(at: center) {
            return MediaGridZoomAnchor(index: index, pointInView: center)
        }
        let host = self.engine.contentHost.frame
        let strip = CGRect(x: 0.0, y: center.y - host.minY + self.engine.offset, width: layout.geometry.width, height: max(1.0, self.bounds.height))
        let range = layout.indexRange(intersecting: strip)
        let index = range.isEmpty ? (self.topVisibleIndex ?? layout.count - 1) : range.lowerBound
        guard let frame = self.frameForItem(at: index) else {
            return nil
        }
        return MediaGridZoomAnchor(index: index, pointInView: CGPoint(x: frame.midX, y: center.y))
    }

    private func relativePosition(of anchor: MediaGridZoomAnchor) -> CGPoint {
        guard let frame = self.frameForItem(at: anchor.index) else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        return MediaGridZoomMath.relativePosition(of: anchor.pointInView, in: frame)
    }

    public func setLevel(_ level: MediaGridLevel, animated: Bool, anchor: MediaGridZoomAnchor? = nil) {
        let level = level.nearest(within: self.availableLevels)
        self.endInteraction()
        self.rotationAnchor = nil
        guard level != self.level else {
            return
        }
        let resolvedAnchor = anchor ?? self.centerAnchor()
        guard let source = self.gridLayout, self.bounds.width > 0.0, self.bounds.height > 0.0, let resolvedAnchor, resolvedAnchor.index >= 0, resolvedAnchor.index < source.count else {
            self.level = level
            self.layoutLevel = level
            self.invalidateGridLayout()
            self.updateGridLayout()
            self.onLevelChanged?(level)
            self.noteTargetLevel()
            return
        }
        let relative = self.relativePosition(of: resolvedAnchor)
        self.engine.haltMotionInPlace()
        if !animated {
            self.level = level
            self.layoutLevel = level
            self.pendingZoom = (resolvedAnchor, relative)
            self.needsLayoutRebuild = true
            self.updateGridLayout()
            self.onLevelChanged?(level)
            self.noteTargetLevel()
            return
        }
        let transition = self.beginTransition(to: level, source: source, anchor: resolvedAnchor, relativePosition: relative, binding: 0.0 ... 1.0)
        transition.animate(to: 1.0, completion: { [weak self, weak transition] in
            guard let self, let transition, self.transition === transition else {
                return
            }
            self.finishTransition()
        })
        self.noteTargetLevel()
    }

    private func showsHeader(at level: MediaGridLevel) -> Bool {
        return level.isInteractive || self.compactLevelTopInset == nil
    }

    private func levelGeometry(_ geometry: MediaGridGeometry, level: MediaGridLevel) -> MediaGridGeometry {
        var geometry = geometry
        if level.isInteractive {
            geometry.topInset = self.interactiveTopInset
        } else {
            geometry.topInset = self.compactLevelTopInset ?? self.interactiveTopInset
        }
        return geometry
    }

    private func makeLayout(level: MediaGridLevel, geometry: MediaGridGeometry, requestsTable: Bool = true) -> MediaGridLayout {
        let geometry = self.levelGeometry(geometry, level: level)
        if level == .one {
            let key = MediaGridAspectTable.Key(geometry: geometry)
            let table = self.aspectTables.first(where: { $0.key == key }) ?? self.aspectTables.first
            if requestsTable && (table?.key != key || self.tableVersion != self.listVersion) {
                self.requestAspectTable(key: key)
            }
            return MediaGridAspectLayout(geometry: geometry, count: self.itemCount, table: table, patches: table == nil ? [] : self.aspectPatches(since: self.tableVersion))
        }
        return MediaGridUniformLayout(geometry: geometry, columns: level.columns, cellAspect: self.cellAspect, reservedSlots: self.reservedSlots(for: level), count: self.itemCount)
    }

    private func startAspectLoad() {
        guard self.aspects == nil, !self.isLoadingAspects, !self.isApplyingAspectChanges, self.itemCount > 0 else {
            return
        }
        self.isLoadingAspects = true
        let generation = self.aspectGeneration
        let version = self.listVersion
        self.cancelAspectLoad = self.aspectLoader(self.itemCount, self.dataSource.aspectRatioReader(), { [weak self] aspects in
            guard let self, self.aspectGeneration == generation else {
                return
            }
            self.isLoadingAspects = false
            self.cancelAspectLoad = nil
            self.aspects = aspects
            self.aspectsVersion = version
            self.pruneChangeLog()
            self.requestCurrentAspectTable()
        })
    }

    private func requestCurrentAspectTable() {
        if let layout = self.gridLayout as? MediaGridAspectLayout {
            self.requestAspectTable(key: layout.tableKey)
        } else if let geometry = self.gridLayout?.geometry {
            self.requestAspectTable(key: MediaGridAspectTable.Key(geometry: geometry))
        }
    }

    private func requestAspectTable(key: MediaGridAspectTable.Key) {
        guard let aspects = self.aspects, self.aspectsVersion == self.listVersion, !self.pendingTableKeys.contains(key), !(self.tableVersion == self.listVersion && self.aspectTables.contains(where: { $0.key == key })) else {
            return
        }
        self.pendingTableKeys.insert(key)
        let generation = self.aspectGeneration
        let version = self.listVersion
        self.aspectTableBuilder(key, aspects, { [weak self] table in
            guard let self, self.aspectGeneration == generation else {
                return
            }
            self.pendingTableKeys.remove(key)
            if self.tableVersion != version {
                self.aspectTables = []
                self.tableVersion = version
            }
            self.aspectTables.removeAll(where: { $0.key == table.key })
            self.aspectTables.insert(table, at: 0)
            if self.aspectTables.count > 2 {
                self.aspectTables.removeLast(self.aspectTables.count - 2)
            }
            self.pruneChangeLog()
            self.applyAspects()
        })
    }

    private var isAspectSwapBlocked: Bool {
        return self.transition != nil || self.pinch != nil || self.isDragging || self.isFlightActive || self.engine.isDecelerating || self.isSelecting
    }

    private func applyAspects(notify: Bool = true) {
        guard self.layoutLevel == .one, let layout = self.gridLayout as? MediaGridAspectLayout, !layout.isExact, self.tableVersion == self.listVersion, let table = self.aspectTables.first(where: { $0.key == layout.tableKey }) else {
            return
        }
        guard !self.isAspectSwapBlocked, self.bounds.height > 0.0 else {
            return
        }
        let target = MediaGridAspectLayout(geometry: layout.geometry, count: self.itemCount, table: table)
        var offset = self.engine.offset
        let rotationAnchor = self.validRotationAnchor(count: target.count)
        if let rotationAnchor {
            let new = target.frame(at: rotationAnchor.index)
            offset = new.minY + rotationAnchor.fraction * new.height - layout.geometry.topInset
        } else if let index = self.topVisibleIndex, index < target.count {
            let old = layout.frame(at: index)
            let new = target.frame(at: index)
            let line = offset + layout.geometry.topInset
            let fraction = old.height > 0.0 ? (line - old.minY) / old.height : 0.0
            offset = new.minY + fraction * new.height - layout.geometry.topInset
        }
        self.motionSample = nil
        self.resetPrefetch()
        self.gridLayout = target
        self.prefetchLayout = target
        self.activeLayoutLayer.setLayout(target, detail: self.cellDetail)
        self.activeLayoutLayer.frame = CGRect(x: 0.0, y: 0.0, width: self.bounds.width, height: target.contentHeight)
        self.engine.setEdges(min: 0.0, max: self.maxOffset)
        self.engine.setOffset(min(max(0.0, offset), self.maxOffset))
        if let rotationAnchor {
            self.rotationAnchor = (rotationAnchor.index, rotationAnchor.fraction, self.engine.offset, self.listVersion)
        }
        if notify {
            self.scrolled(to: self.engine.offset)
        }
    }

    private func validRotationAnchor(count: Int) -> (index: Int, fraction: CGFloat)? {
        guard let stored = self.rotationAnchor, stored.offset == self.engine.offset, stored.version == self.listVersion, stored.index < count else {
            return nil
        }
        return (stored.index, stored.fraction)
    }

    @discardableResult
    private func beginTransition(to level: MediaGridLevel, source: MediaGridLayout, anchor: MediaGridZoomAnchor, relativePosition: CGPoint, binding: ClosedRange<CGFloat>) -> MediaGridZoomTransition {
        if self.isMovingFast {
            self.setMovingFast(false, upgrade: false)
        }
        self.motionSample = nil
        self.rotationAnchor = nil
        let sourceLevel = self.layoutLevel

        let width = self.bounds.width
        let height = self.bounds.height
        let host = self.engine.contentHost.frame
        let sourceOffset = self.engine.offset
        let target = self.makeLayout(level: level, geometry: source.geometry)
        let targetOffset = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: anchor.index, pointInView: CGPoint(x: anchor.pointInView.x - host.minX, y: anchor.pointInView.y - host.minY)), in: target, viewportHeight: height, relativePosition: relativePosition)
        let scale = MediaGridZoomMath.scale(from: source, to: target, anchorIndex: anchor.index)
        var heightRatio: CGFloat = 1.0
        if source is MediaGridAspectLayout || target is MediaGridAspectLayout {
            let sourceHeight = source.frame(at: anchor.index).height
            let targetHeight = target.frame(at: anchor.index).height
            if sourceHeight > 0.0, targetHeight > 0.0, scale > 0.0 {
                heightRatio = targetHeight / (sourceHeight * scale)
            }
        }
        let anchorPoint = CGPoint(x: anchor.pointInView.x - host.minX, y: anchor.pointInView.y - host.minY + sourceOffset)
        let shift = sourceOffset - targetOffset

        let incoming = self.spareLayoutLayer ?? MediaGridLayoutLayer(dataSource: self.dataSource, pool: self.pool)
        incoming.compactRequestsSharpImages = self.compactLevelsRequestSharpImages
        self.spareLayoutLayer = nil
        incoming.isItemSelected = self.isItemSelected
        incoming.suspendsSharpRequests = false
        incoming.donor = self.activeLayoutLayer
        incoming.opacity = 1.0
        incoming.setLayout(target, detail: level.isInteractive ? .full : .compact)
        MediaGridZoomTransition.resetPivot(incoming, width: width, height: target.contentHeight, originY: shift)
        if level.columns > sourceLevel.columns {
            self.engine.contentHost.layer.insertSublayer(incoming, below: self.activeLayoutLayer)
        } else {
            self.engine.contentHost.layer.insertSublayer(incoming, above: self.activeLayoutLayer)
        }

        var cameraRole: MediaGridZoomTransition.CameraRole = .none
        var cameraAlpha: (CGFloat, CGFloat) = (0.0, 0.0)
        if let cameraView = self.cameraView {
            let sourceShows = !self.cameraSlots(for: sourceLevel).isEmpty
            let targetSlots = self.cameraSlots(for: level)
            let targetFrame = (target as? MediaGridUniformLayout)?.reservedFrame(targetSlots)
            if sourceShows, !targetSlots.isEmpty, let frame = targetFrame {
                cameraRole = .moving(from: cameraView.frame, to: frame.offsetBy(dx: 0.0, dy: shift))
                cameraAlpha = (1.0, 1.0)
            } else if !targetSlots.isEmpty, let frame = targetFrame {
                cameraRole = .incoming
                cameraAlpha = (0.0, 1.0)
                cameraView.layer.transform = CATransform3DIdentity
                cameraView.frame = frame.offsetBy(dx: 0.0, dy: shift)
                cameraView.isHidden = false
            } else if sourceShows {
                cameraRole = .outgoing
                cameraAlpha = (1.0, 0.0)
            }
        }

        self.accessoryView?.isHidden = true

        var headerRole: MediaGridZoomTransition.CameraRole = .none
        if let headerView = self.headerView, self.headerFrame.height > 0.0 {
            let sourceShows = self.showsHeader(at: sourceLevel)
            let targetShows = self.showsHeader(at: level)
            if sourceShows && !targetShows {
                headerRole = .outgoing
            } else if !sourceShows && targetShows {
                headerRole = .incoming
                headerView.layer.transform = CATransform3DIdentity
                headerView.frame = self.headerFrame.offsetBy(dx: 0.0, dy: shift)
                headerView.isHidden = false
            }
        }

        var cameraTakesPart = true
        if case .none = cameraRole {
            cameraTakesPart = false
        }
        let transition = MediaGridZoomTransition(sourceLevel: sourceLevel, targetLevel: level, sourceLayout: source, outgoing: self.activeLayoutLayer, outgoingLocalAnchor: anchorPoint, incoming: incoming, incomingLocalAnchor: CGPoint(x: anchorPoint.x, y: anchorPoint.y - shift), anchorPoint: anchorPoint, viewportSize: CGSize(width: width, height: height), scale: scale, heightRatio: heightRatio, targetLayout: target, targetOffset: targetOffset, camera: cameraTakesPart ? self.cameraView : nil, cameraRole: cameraRole, cameraAlphaRange: cameraAlpha)
        transition.viewport = CGRect(x: 0.0, y: sourceOffset, width: width, height: height)
        transition.shift = shift
        if case .none = headerRole {
        } else {
            transition.header = self.headerView
            transition.headerRole = headerRole
        }
        self.transition = transition
        self.transitionAnchor = (anchor, relativePosition)
        self.bindTransition(transition, covering: binding)
        transition.apply(progress: 0.0)
        self.updateGestureAvailability()
        self.engine.isScrollEnabled = false
        self.noteZoomingChanged()
        return transition
    }

    private static let bindStep: CGFloat = 0.125
    private static let maxExtrapolation: CGFloat = 0.25

    private func bindTransition(_ transition: MediaGridZoomTransition, covering range: ClosedRange<CGFloat>) {
        let lower = max(-MediaGridView.maxExtrapolation, range.lowerBound)
        let upper = min(1.0 + MediaGridView.maxExtrapolation, range.upperBound)
        if let bound = transition.boundRange, bound.lowerBound <= lower, bound.upperBound >= upper {
            return
        }
        let step = MediaGridView.bindStep
        var newLower = lower < 0.0 ? lower : max(0.0, floor(lower / step) * step)
        var newUpper = upper > 1.0 ? upper : min(1.0, ceil(upper / step) * step)
        if let bound = transition.boundRange {
            newLower = min(newLower, bound.lowerBound)
            newUpper = max(newUpper, bound.upperBound)
        }
        transition.boundRange = newLower ... newUpper
        let pad = self.bounds.height * 0.05
        let incomingRect = transition.incomingRect(at: newLower).union(transition.incomingRect(at: newUpper)).insetBy(dx: 0.0, dy: -pad)
        let incomingRange = transition.targetLayout.indexRange(intersecting: incomingRect)
        let outgoingRect = transition.outgoingRect(at: newLower).union(transition.outgoingRect(at: newUpper)).insetBy(dx: 0.0, dy: -pad)
        var outgoingRange = transition.sourceLayout.indexRange(intersecting: outgoingRect)
        let current = transition.outgoing.visibleRange
        if !current.isEmpty, current.overlaps(outgoingRange) {
            outgoingRange = min(current.lowerBound, outgoingRange.lowerBound) ..< max(current.upperBound, outgoingRange.upperBound)
        }
        self.transitionPrepareRanges = [incomingRange, transition.targetLayout.indexRange(intersecting: transition.incomingRect(at: 1.0)), outgoingRange]
        self.updateThumbnailPreparation()
        self.dataSource.performBatch {
            transition.incoming.updateVisibleRange(incomingRange)
        }
        transition.outgoing.updateVisibleRange(outgoingRange)
        self.pool.setVisibleCount(transition.outgoing.visibleCells.count + transition.incoming.visibleCells.count)
    }

    private func jumpLayout(to level: MediaGridLevel, anchor: MediaGridZoomAnchor, relativePosition: CGPoint) {
        guard let source = self.gridLayout else {
            return
        }
        let height = self.bounds.height
        let host = self.engine.contentHost.frame
        let target = self.makeLayout(level: level, geometry: source.geometry)
        let offset = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: anchor.index, pointInView: CGPoint(x: anchor.pointInView.x - host.minX, y: anchor.pointInView.y - host.minY)), in: target, viewportHeight: height, relativePosition: relativePosition)
        self.motionSample = nil
        self.activeLayoutLayer.removeAllCells()
        self.activeLayoutLayer.setLayout(target, detail: level.isInteractive ? .full : .compact)
        self.activeLayoutLayer.frame = CGRect(x: 0.0, y: 0.0, width: self.bounds.width, height: target.contentHeight)
        self.layoutLevel = level
        self.gridLayout = target
        self.engine.setEdges(min: 0.0, max: self.maxOffset)
        self.engine.setOffset(min(max(0.0, offset), self.maxOffset))
        self.layoutCamera(layout: target)
    }

    private func endInteraction() {
        if self.transition != nil {
            self.finishTransition()
        } else if self.pinch != nil {
            self.completeZoom()
        }
    }

    private func finishTransition(commit: Bool? = nil, quiet: Bool = false) {
        guard let transition = self.transition else {
            return
        }
        let commits = commit ?? transition.destination.map { $0 >= 0.5 } ?? (transition.progress >= 0.5)
        self.transition = nil
        self.motionSample = nil
        self.transitionAnchor = nil
        transition.removeAnimations()
        let width = self.bounds.width
        let outgoing = transition.outgoing
        let incoming = transition.incoming
        outgoing.donor = nil
        incoming.donor = nil
        if commits {
            outgoing.removeAllCells()
            MediaGridZoomTransition.resetPivot(outgoing, width: width, height: 0.0, originY: 0.0)
            outgoing.opacity = 1.0
            outgoing.removeFromSuperlayer()
            self.spareLayoutLayer = outgoing

            MediaGridZoomTransition.resetPivot(incoming, width: width, height: transition.targetLayout.contentHeight, originY: 0.0)
            incoming.opacity = 1.0
            incoming.suspendsSharpRequests = self.isMovingFast
            self.activeLayoutLayer = incoming

            self.layoutLevel = transition.targetLevel
            self.gridLayout = transition.targetLayout
            self.engine.setEdges(min: 0.0, max: self.maxOffset)
            self.engine.setOffset(min(max(0.0, transition.targetOffset), self.maxOffset))
        } else {
            incoming.removeAllCells()
            MediaGridZoomTransition.resetPivot(incoming, width: width, height: 0.0, originY: 0.0)
            incoming.opacity = 1.0
            incoming.removeFromSuperlayer()
            self.spareLayoutLayer = incoming

            MediaGridZoomTransition.resetPivot(outgoing, width: width, height: transition.sourceLayout.contentHeight, originY: 0.0)
            outgoing.opacity = 1.0
        }
        if let layout = self.gridLayout {
            self.layoutCamera(layout: layout)
        }
        if !quiet {
            self.completeZoom()
        }
        self.noteZoomingChanged()
    }

    private func completeZoom() {
        if let pinch = self.pinch {
            self.pinch = nil
            if pinch.isTracking {
                self.resetOvershoot()
            }
        }
        let previousLevel = self.level
        self.level = self.layoutLevel
        if let layout = self.gridLayout, !MediaGridView.samePixelSizes(self.prefetchLayout, layout) {
            self.resetPrefetch()
            self.prefetchLayout = layout
        }
        self.engine.isScrollEnabled = !self.isScrollingLockedAtTop
        self.updateGestureAvailability()
        self.applyAspects(notify: false)
        self.scrolled(to: self.engine.offset)
        if !self.isMovingFast {
            self.requestVisibleSharpImages()
        }
        if self.level != previousLevel {
            self.onLevelChanged?(self.level)
        }
        self.noteZoomingChanged()
        self.noteTargetLevel()
    }

    private static func samePixelSizes(_ lhs: MediaGridLayout?, _ rhs: MediaGridLayout) -> Bool {
        if let lhs = lhs as? MediaGridUniformLayout, let rhs = rhs as? MediaGridUniformLayout {
            return lhs.pixelSize(at: 0) == rhs.pixelSize(at: 0)
        }
        if let lhs = lhs as? MediaGridAspectLayout, let rhs = rhs as? MediaGridAspectLayout {
            return lhs.geometry == rhs.geometry && lhs.count == rhs.count && lhs.isExact && rhs.isExact
        }
        return false
    }

    private func updateGestureAvailability() {
        let idle = self.transition == nil && self.pinch == nil
        let interactive = self.layoutLevel.isInteractive
        self.tapRecognizer.isEnabled = idle && (interactive || self.isZoomEnabled)
        self.selectionGesture.isEnabled = idle && interactive && self.isSelectionPanEnabled
        self.pinchRecognizer.isEnabled = self.isZoomEnabled
    }

    private struct PinchSession {
        var state: MediaGridPinchState
        var relativePosition: CGPoint
        var isTracking: Bool
    }

    private static let overshootKey = "mediaGridZoom.overshoot"
    private static let crossingHysteresis: CGFloat = 0.05

    private func resetOvershoot() {
        let hostLayer = self.engine.contentHost.layer
        hostLayer.removeAnimation(forKey: MediaGridView.overshootKey)
        hostLayer.sublayerTransform = CATransform3DIdentity
    }

    var pinchAnchor: MediaGridZoomAnchor? {
        return self.pinch?.state.anchor
    }

    private var canBeginPinch: Bool {
        guard self.isZoomEnabled, let layout = self.gridLayout, layout.count > 0, self.bounds.width > 0.0, self.bounds.height > 0.0 else {
            return false
        }
        return !self.selectionGesture.isProcessing
    }

    @objc private func pinched(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.beginPinch(center: recognizer.location(in: self))
        case .changed:
            self.updatePinch(scale: recognizer.scale)
        case .ended:
            self.endPinch(velocity: recognizer.velocity)
        case .cancelled, .failed:
            self.endPinch(velocity: 0.0)
        default:
            break
        }
    }

    private func beginPinch(center: CGPoint) {
        guard self.canBeginPinch else {
            return
        }
        self.stopScrollAnimation()
        self.engine.haltMotionInPlace()
        self.resetOvershoot()
        self.rotationAnchor = nil
        let state: MediaGridPinchState
        let relativePosition: CGPoint
        if let transition = self.transition, let (anchor, relative) = self.transitionAnchor {
            transition.interrupt()
            state = MediaGridPinchState(startLevel: transition.sourceLevel, anchor: anchor, toward: transition.targetLevel, startProgress: transition.progress, levels: self.availableLevels)
            relativePosition = relative
        } else {
            let hostLayer = self.engine.contentHost.layer
            if let keys = hostLayer.animationKeys(), !keys.isEmpty, let presentedOffset = hostLayer.presentation()?.bounds.origin.y, presentedOffset.isFinite, abs(presentedOffset - self.engine.offset) > 0.5 {
                self.engine.setOffset(presentedOffset)
            }
            guard let anchor = self.anchor(at: center) else {
                return
            }
            state = MediaGridPinchState(startLevel: self.layoutLevel, anchor: anchor, levels: self.availableLevels)
            relativePosition = self.relativePosition(of: anchor)
        }
        self.pinch = PinchSession(state: state, relativePosition: relativePosition, isTracking: true)
        self.updateThumbnailPreparation()
        self.updateGestureAvailability()
        self.engine.isScrollEnabled = false
        self.noteZoomingChanged()
    }

    private func neighbourPrepareRanges() -> [Range<Int>] {
        guard self.isZoomEnabled, let source = self.gridLayout, self.bounds.height > 0.0 else {
            return []
        }
        let anchor: MediaGridZoomAnchor
        let relativePosition: CGPoint
        if let pinch = self.pinch {
            anchor = pinch.state.anchor
            relativePosition = pinch.relativePosition
        } else if let center = self.centerAnchor() {
            anchor = center
            relativePosition = self.relativePosition(of: center)
        } else {
            return []
        }
        let host = self.engine.contentHost.frame
        let point = CGPoint(x: anchor.pointInView.x - host.minX, y: anchor.pointInView.y - host.minY)
        var ranges: [Range<Int>] = []
        for level in [self.layoutLevel.zoomedIn(within: self.availableLevels), self.layoutLevel.zoomedOut(within: self.availableLevels)] {
            guard let level else {
                continue
            }
            let target = self.makeLayout(level: level, geometry: source.geometry, requestsTable: false)
            let offset = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: anchor.index, pointInView: point), in: target, viewportHeight: self.bounds.height, relativePosition: relativePosition)
            ranges.append(target.indexRange(intersecting: CGRect(x: 0.0, y: offset, width: source.geometry.width, height: self.bounds.height)))
        }
        return ranges
    }

    private func updateThumbnailPreparation() {
        guard let layout = self.gridLayout, self.bounds.width > 0.0, self.bounds.height > 0.0 else {
            return
        }
        var ranges: [Range<Int>]
        if self.transition != nil {
            ranges = self.transitionPrepareRanges
        } else {
            let width = self.bounds.width
            let height = self.bounds.height
            let viewport = CGRect(x: 0.0, y: self.engine.offset, width: width, height: height)
            ranges = [layout.indexRange(intersecting: viewport)]
            if self.isMovingFast, self.scrollStep != 0.0, self.scrollStep.isFinite {
                ranges.append(layout.indexRange(intersecting: viewport.offsetBy(dx: 0.0, dy: self.scrollStep)))
                ranges.append(layout.indexRange(intersecting: viewport.offsetBy(dx: 0.0, dy: 2.0 * self.scrollStep)))
            }
            if !self.isMovingFast || self.pinch != nil {
                ranges.append(contentsOf: self.neighbourPrepareRanges())
            }
            ranges.append(layout.indexRange(intersecting: viewport.insetBy(dx: 0.0, dy: -self.windowMargin(level: self.layoutLevel))))
            if let target = self.flightTargetOffset, target.isFinite {
                ranges.append(layout.indexRange(intersecting: CGRect(x: 0.0, y: target, width: width, height: height)))
            }
            if !(self.isMovingFast && !self.layoutLevel.isInteractive) {
                ranges.append(layout.indexRange(intersecting: viewport.insetBy(dx: 0.0, dy: -height)))
            }
        }
        let disjoint = MediaGridView.disjointRanges(ranges)
        if disjoint == self.lastPreparedRanges {
            return
        }
        self.lastPreparedRanges = disjoint
        self.dataSource.prepareThumbnails(ranges: disjoint)
    }

    static func disjointRanges(_ ranges: [Range<Int>]) -> [Range<Int>] {
        var covered = IndexSet()
        var result: [Range<Int>] = []
        for range in ranges where !range.isEmpty {
            var pieces = IndexSet(integersIn: range)
            pieces.subtract(covered)
            result.append(contentsOf: pieces.rangeView)
            covered.insert(integersIn: range)
        }
        return result
    }

    public func thumbnailsDidChange(indices: IndexSet?) {
        self.activeLayoutLayer.refreshThumbnails(indices: indices)
        if let transition = self.transition, transition.incoming !== self.activeLayoutLayer {
            transition.incoming.refreshThumbnails(indices: indices)
        }
    }

    private func updatePinch(scale: CGFloat) {
        guard var session = self.pinch, session.isTracking else {
            return
        }
        if self.engine.isDecelerating {
            self.engine.haltMotionInPlace()
        }
        let result = session.state.update(scale: scale)
        self.pinch = session
        self.drivePinch(from: result.from, to: result.to, progress: result.progress)
        self.applyOvershoot(session.state.overshoot, about: session.state.anchor.pointInView)
        self.noteTargetLevel()
        self.onZoomFrame?()
    }

    private func drivePinch(from: MediaGridLevel, to: MediaGridLevel, progress: CGFloat) {
        for _ in 0 ..< 8 {
            if let transition = self.transition {
                let source = transition.sourceLevel
                let target = transition.targetLevel
                if source == from && target == to {
                    transition.apply(progress: progress)
                    self.bindTransition(transition, covering: progress ... progress)
                    return
                }
                if source == to && target == from {
                    transition.apply(progress: 1.0 - progress)
                    self.bindTransition(transition, covering: (1.0 - progress) ... (1.0 - progress))
                    return
                }
                if let shared = [from, to].first(where: { $0 == source || $0 == target }) {
                    let distance = shared == from ? progress : 1.0 - progress
                    if distance < MediaGridView.crossingHysteresis {
                        let span = abs(MediaGridPinchState.position(of: from) - MediaGridPinchState.position(of: to))
                        let ownSpan = max(1e-6, abs(MediaGridPinchState.position(of: source) - MediaGridPinchState.position(of: target)))
                        let beyond = min(MediaGridView.maxExtrapolation, distance * span / ownSpan)
                        let extrapolated = shared == target ? 1.0 + beyond : -beyond
                        transition.apply(progress: extrapolated)
                        self.bindTransition(transition, covering: min(extrapolated, shared == target ? 1.0 : 0.0) ... max(extrapolated, shared == target ? 1.0 : 0.0))
                        return
                    }
                }
                let commit: Bool
                if source == from || source == to {
                    commit = false
                } else if target == from || target == to {
                    commit = true
                } else {
                    commit = (target > source && from >= target) || (target < source && from <= target)
                }
                self.finishTransition(commit: commit, quiet: true)
                continue
            }
            guard let session = self.pinch, let source = self.gridLayout else {
                return
            }
            let level = self.layoutLevel
            let anchor = session.state.anchor
            if level == from || level == to {
                guard from != to else {
                    return
                }
                let next = level == from ? to : from
                let start = level == from ? progress : 1.0 - progress
                self.beginTransition(to: next, source: source, anchor: anchor, relativePosition: session.relativePosition, binding: start ... start)
            } else if let next = from > level ? level.zoomedOut(within: self.availableLevels) : level.zoomedIn(within: self.availableLevels) {
                self.jumpLayout(to: next, anchor: anchor, relativePosition: session.relativePosition)
            } else {
                return
            }
        }
    }

    private func applyOvershoot(_ overshoot: CGFloat, about point: CGPoint) {
        let hostLayer = self.engine.contentHost.layer
        if overshoot == 0.0 {
            hostLayer.sublayerTransform = CATransform3DIdentity
        } else {
            let host = self.engine.contentHost.frame
            hostLayer.sublayerTransform = MediaGridZoomMath.transform(scale: exp(-overshoot), about: CGPoint(x: point.x - host.minX, y: point.y - host.minY), layerPosition: CGPoint(x: host.width * 0.5, y: host.height * 0.5))
        }
    }

    private func endPinch(velocity: CGFloat) {
        guard var session = self.pinch, session.isTracking else {
            return
        }
        session.isTracking = false
        self.pinch = session
        let hostLayer = self.engine.contentHost.layer
        if !CATransform3DIsIdentity(hostLayer.sublayerTransform) {
            let animation = CASpringAnimation(keyPath: "sublayerTransform")
            animation.stiffness = 300.0
            animation.damping = 2.0 * sqrt(animation.stiffness * animation.mass)
            animation.fromValue = NSValue(caTransform3D: hostLayer.sublayerTransform)
            animation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
            let settling = animation.settlingDuration
            animation.duration = settling
            animation.speed = Float(settling / MediaGridZoomTransition.duration)
            hostLayer.sublayerTransform = CATransform3DIdentity
            hostLayer.add(animation, forKey: MediaGridView.overshootKey)
        }
        guard let transition = self.transition else {
            self.completeZoom()
            return
        }
        let target = session.state.settle(velocity: velocity)
        let pair = session.state.current
        let stateVelocity = session.state.progressVelocity(scaleVelocity: velocity)
        if target != transition.sourceLevel, target != transition.targetLevel, let shared = [pair.from, pair.to].first(where: { $0 == transition.sourceLevel || $0 == transition.targetLevel }), let anchor = self.transitionAnchor {
            self.finishTransition(commit: shared == transition.targetLevel, quiet: true)
            guard let source = self.gridLayout else {
                self.completeZoom()
                return
            }
            let start = min(1.0, max(0.0, shared == pair.from ? pair.progress : 1.0 - pair.progress))
            let next = self.beginTransition(to: target, source: source, anchor: anchor.anchor, relativePosition: anchor.relativePosition, binding: start ... 1.0)
            next.apply(progress: start)
            self.settle(next, to: 1.0, velocity: self.transitionVelocity(stateVelocity, pair: pair, transition: next))
            self.noteTargetLevel()
            return
        }
        let destination: CGFloat = target == transition.targetLevel ? 1.0 : 0.0
        self.bindTransition(transition, covering: min(transition.progress, destination) ... max(transition.progress, destination))
        self.settle(transition, to: destination, velocity: self.transitionVelocity(stateVelocity, pair: pair, transition: transition))
        self.noteTargetLevel()
    }

    private func transitionVelocity(_ velocity: CGFloat, pair: (from: MediaGridLevel, to: MediaGridLevel, progress: CGFloat), transition: MediaGridZoomTransition) -> CGFloat {
        let span = MediaGridPinchState.position(of: pair.to) - MediaGridPinchState.position(of: pair.from)
        let ownSpan = MediaGridPinchState.position(of: transition.targetLevel) - MediaGridPinchState.position(of: transition.sourceLevel)
        guard abs(ownSpan) > 1e-6 else {
            return 0.0
        }
        return velocity * span / ownSpan
    }

    private func settle(_ transition: MediaGridZoomTransition, to destination: CGFloat, velocity: CGFloat) {
        transition.animate(to: destination, velocity: velocity, completion: { [weak self, weak transition] in
            guard let self, let transition, self.transition === transition else {
                return
            }
            self.finishTransition()
        })
    }

    func _testPinch(_ state: UIGestureRecognizer.State, center: CGPoint, scale: CGFloat = 1.0, velocity: CGFloat = 0.0) {
        switch state {
        case .began:
            self.beginPinch(center: center)
        case .changed:
            self.updatePinch(scale: scale)
        case .ended:
            self.endPinch(velocity: velocity)
        default:
            self.endPinch(velocity: 0.0)
        }
    }

    #if DEBUG
    public var debugIsZooming: Bool {
        return self.transition != nil || self.pinch != nil
    }

    public func debugEmptyVisibleCellCount(counting isCounted: ((Int) -> Bool)? = nil, treatingAsEmpty isEmpty: ((Int) -> Bool)? = nil) -> (empty: Int, visible: Int) {
        var empty = 0
        var visible = 0
        let count: (MediaGridLayoutLayer, CGRect) -> Void = { layer, rect in
            guard let layout = layer.layout else {
                return
            }
            for index in layout.indexRange(intersecting: rect) {
                guard layout.frame(at: index).intersects(rect) else {
                    continue
                }
                visible += 1
                if isEmpty?(index) ?? !(layer.visibleCells[index]?.hasImage ?? false), isCounted?(index) ?? true {
                    empty += 1
                }
            }
        }
        if let transition = self.transition {
            let progress = transition.presentedProgress
            if progress < 1.0 {
                count(transition.outgoing, transition.outgoingRect(at: progress))
            }
            if progress > 0.0 {
                count(transition.incoming, transition.incomingRect(at: progress))
            }
        } else {
            count(self.activeLayoutLayer, CGRect(x: 0.0, y: self.engine.offset, width: self.bounds.width, height: self.bounds.height))
        }
        return (empty, visible)
    }

    public func debugVisibleFinalImageCount() -> (final: Int, visible: Int) {
        guard let layout = self.activeLayoutLayer.layout else {
            return (0, 0)
        }
        let rect = CGRect(x: 0.0, y: self.engine.offset, width: self.bounds.width, height: self.bounds.height)
        var final = 0
        var visible = 0
        for index in layout.indexRange(intersecting: rect) where layout.frame(at: index).intersects(rect) {
            visible += 1
            if self.activeLayoutLayer.visibleCells[index]?.hasFinalImage ?? false {
                final += 1
            }
        }
        return (final, visible)
    }

    public func debugDrivePinch(_ state: UIGestureRecognizer.State, center: CGPoint, scale: CGFloat, velocity: CGFloat) {
        self._testPinch(state, center: center, scale: scale, velocity: velocity)
    }
    #endif

    private func layoutHeader() {
        guard let headerView = self.headerView else {
            return
        }
        headerView.layer.transform = CATransform3DIdentity
        headerView.frame = self.headerFrame
        headerView.alpha = 1.0
        headerView.isHidden = !self.showsHeader(at: self.layoutLevel)
    }

    private func layoutAccessory(layout: MediaGridLayout) {
        guard let accessoryView = self.accessoryView else {
            return
        }
        let slots = self.accessorySlots(for: self.layoutLevel)
        if !slots.isEmpty, let frame = (layout as? MediaGridUniformLayout)?.reservedFrame(slots) {
            accessoryView.isHidden = false
            accessoryView.frame = frame
        } else {
            accessoryView.isHidden = true
        }
    }

    private func layoutCamera(layout: MediaGridLayout) {
        self.layoutHeader()
        self.layoutAccessory(layout: layout)
        guard let cameraView = self.cameraView else {
            return
        }
        cameraView.layer.transform = CATransform3DIdentity
        if !self.cameraSlots(for: self.layoutLevel).isEmpty, let frame = (layout as? MediaGridUniformLayout)?.reservedFrame(MediaGridView.cameraSlots) {
            cameraView.isHidden = false
            cameraView.alpha = 1.0
            cameraView.frame = frame
        } else {
            cameraView.alpha = 0.0
            cameraView.isHidden = true
        }
    }

    func _testFinishAnimations() {
        self.finishTransition()
    }

    func _testTap(at point: CGPoint) {
        self.handleTap(at: point)
    }

    public func frameForItem(at index: Int) -> CGRect? {
        guard let layout = self.gridLayout, index >= 0, index < layout.count else {
            return nil
        }
        let frame = layout.frame(at: index)
        return frame.offsetBy(dx: self.engine.contentHost.frame.minX, dy: self.engine.contentHost.frame.minY - self.engine.offset)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.engine.contentHost.frame = self.bounds
        self.updateGridLayout()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        self.invalidateGridLayout()
    }

    private var displayScale: CGFloat {
        if let scaleOverride = self.scaleOverride {
            return scaleOverride
        }
        let scale = self.traitCollection.displayScale
        return scale > 0.0 ? scale : 2.0
    }

    private var cellDetail: MediaGridCellDetail {
        return self.layoutLevel.isInteractive ? .full : .compact
    }

    private func invalidateGridLayout() {
        self.needsLayoutRebuild = true
        self.setNeedsLayout()
    }

    private func updateGridLayout() {
        let size = self.bounds.size
        guard size.width > 0.0, size.height > 0.0 else {
            return
        }
        if !self.hasWaitedForLaunchImages {
            self.hasWaitedForLaunchImages = true
            if self.itemCount > 0 {
                let start = CACurrentMediaTime()
                self.dataSource.waitForLaunchImages(timeout: MediaGridView.launchImageWait)
                self.launchImageWaitDuration = CACurrentMediaTime() - start
            }
        }
        let insets = self.geometryInsets
        let headerHeight = max(0.0, self.headerHeight)
        self.interactiveTopInset = insets.top + headerHeight
        let baseGeometry = MediaGridGeometry(width: size.width, leftInset: insets.left, rightInset: insets.right, topInset: self.interactiveTopInset, bottomInset: insets.bottom, spacing: 1.0, scale: self.displayScale)
        let headerFrame = CGRect(x: 0.0, y: insets.top, width: size.width, height: headerHeight)
        if let transition = self.transition {
            if !self.needsLayoutRebuild && transition.targetLayout.geometry == self.levelGeometry(baseGeometry, level: transition.targetLevel) && headerFrame == self.headerFrame {
                return
            }
            self.finishTransition()
        }
        self.headerFrame = headerFrame
        if let headerView = self.headerView {
            headerView.frame = headerFrame
            headerView.isHidden = !self.showsHeader(at: self.layoutLevel)
        }
        let geometry = self.levelGeometry(baseGeometry, level: self.layoutLevel)
        let topInset = geometry.topInset
        if self.pinch != nil && (self.needsLayoutRebuild || self.gridLayout?.geometry != geometry) {
            self.completeZoom()
        }
        var compensatedOffset: CGFloat?
        var zoomOffset: CGFloat?
        var anchoredOffset: (offset: CGFloat, index: Int, fraction: CGFloat)?
        if self.needsLayoutRebuild || self.gridLayout?.geometry != geometry {
            self.needsLayoutRebuild = false
            var anchor: (index: Int, fraction: CGFloat)?
            if let previous = self.gridLayout {
                let old = previous.geometry
                if self.anchorsNextRebuild || old.width != geometry.width || old.leftInset != geometry.leftInset || old.rightInset != geometry.rightInset || old.scale != geometry.scale {
                    anchor = self.validRotationAnchor(count: previous.count) ?? self.topAnchor(in: previous)
                }
            }
            self.anchorsNextRebuild = false
            let layout = self.makeLayout(level: self.layoutLevel, geometry: geometry)
            if let anchor, anchor.index < layout.count {
                let frame = layout.frame(at: anchor.index)
                anchoredOffset = (frame.minY + anchor.fraction * frame.height - geometry.topInset, anchor.index, anchor.fraction)
            } else if let lastTopInset = self.gridLayout?.geometry.topInset, lastTopInset != topInset, self.engine.offset > 0.0, self.pendingContentOffset == nil {
                compensatedOffset = max(0.0, self.engine.offset + (topInset - lastTopInset))
            }
            if let zoom = self.pendingZoom {
                compensatedOffset = nil
                anchoredOffset = nil
                let host = self.engine.contentHost.frame
                let point = CGPoint(x: zoom.anchor.pointInView.x - host.minX, y: zoom.anchor.pointInView.y - host.minY)
                zoomOffset = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: zoom.anchor.index, pointInView: point), in: layout, viewportHeight: size.height, relativePosition: zoom.relativePosition)
            }
            self.motionSample = nil
            self.resetPrefetch()
            self.gridLayout = layout
            self.prefetchLayout = layout
            self.activeLayoutLayer.setLayout(layout, detail: self.cellDetail)
            self.activeLayoutLayer.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: layout.contentHeight)
            self.layoutCamera(layout: layout)
        }
        self.pendingZoom = nil
        self.updateGestureAvailability()
        self.engine.setEdges(min: 0.0, max: self.maxOffset)
        if let zoomOffset {
            self.engine.setOffset(min(max(0.0, zoomOffset), self.maxOffset))
            self.scrolled(to: self.engine.offset)
        }
        if let anchoredOffset {
            self.engine.setOffset(min(max(0.0, anchoredOffset.offset), self.maxOffset))
            self.rotationAnchor = (anchoredOffset.index, anchoredOffset.fraction, self.engine.offset, self.listVersion)
            if self.isDragging {
                self.engine.reanchorDragToCurrentPosition()
            }
            self.scrolled(to: self.engine.offset)
        }
        if let compensated = compensatedOffset {
            if self.isDragging || self.engine.isDecelerating {
                self.engine.applyShift(compensated - self.engine.offset)
                if self.isDragging {
                    self.engine.reanchorDragToCurrentPosition()
                }
            } else {
                self.engine.setOffset(min(compensated, self.maxOffset))
            }
            self.scrolled(to: self.engine.offset)
        }
        if let pending = self.pendingContentOffset {
            self.pendingContentOffset = nil
            self.engine.setOffset(min(max(0.0, pending), self.maxOffset))
            self.scrolled(to: self.engine.offset)
        }
        if !self.isDragging && !self.engine.isDecelerating && self.engine.offset > self.maxOffset {
            self.engine.setOffset(self.maxOffset)
        }
        self.applyAspects()
        self.updateVisibleCells(offset: self.engine.offset)
        self.updatePrefetch(offset: self.engine.offset)
        self.startAspectLoad()
    }

    private func scrolled(to offset: CGFloat) {
        var offset = offset
        if (self.holdsDragAtTop && self.isDragging && offset != 0.0) || (!self.bounces && offset < 0.0), self.transition == nil {
            if self.isDragging {
                self.engine.applyShift(-self.engine.offset)
                self.engine.reanchorDragToCurrentPosition()
            } else {
                self.engine.setOffset(0.0)
            }
            offset = 0.0
        }
        if let anchor = self.rotationAnchor, anchor.offset != offset {
            self.rotationAnchor = nil
        }
        if self.transition != nil {
            return
        }
        if let last = self.lastScrolledOffset {
            self.scrollStep = offset - last
        }
        self.lastScrolledOffset = offset
        self.updateMotion(offset: offset)
        self.updateVisibleCells(offset: offset)
        self.updatePrefetch(offset: offset)
        if !self.isNotifyingScroll {
            self.isNotifyingScroll = true
            var reported = offset
            var depth = 0
            while true {
                self.onScroll?(reported)
                depth += 1
                let current = self.engine.offset
                if current == reported || depth >= 4 {
                    break
                }
                reported = current
            }
            self.isNotifyingScroll = false
        }
    }

    private func updateMotion(offset: CGFloat) {
        let now = self.motionClock()
        guard let sample = self.motionSample else {
            self.motionSample = (now, offset)
            self.lastScrollEvent = (now, offset)
            return
        }
        let height = self.bounds.height
        if let last = self.lastScrollEvent, now - last.time >= MediaGridView.minimumJumpInterval, height > 0.0, abs(offset - last.offset) >= height {
            self.motionSample = (now, offset)
            self.lastScrollEvent = (now, offset)
            self.lastFastMotionTime = now
            if !self.isMovingFast {
                self.setMovingFast(true)
            }
            self.scheduleMotionSettle()
            return
        }
        self.lastScrollEvent = (now, offset)
        let elapsed = now - sample.time
        guard elapsed >= MediaGridView.motionSampleInterval else {
            return
        }
        self.motionSample = (now, offset)
        guard height > 0.0 else {
            return
        }
        let speed = abs(offset - sample.offset) / CGFloat(elapsed) / height
        if speed >= MediaGridView.fastScrollSpeed {
            self.lastFastMotionTime = now
            if !self.isMovingFast {
                self.setMovingFast(true)
            }
            self.scheduleMotionSettle()
        } else if self.isMovingFast, let last = self.lastFastMotionTime, now - last >= MediaGridView.motionSettleDelay {
            self.setMovingFast(false)
        }
    }

    private func scheduleMotionSettle() {
        guard !self.motionSettleScheduled else {
            return
        }
        self.motionSettleScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + MediaGridView.motionSettleDelay) { [weak self] in
            guard let self else {
                return
            }
            self.motionSettleScheduled = false
            self.checkMotionSettled()
        }
    }

    private func checkMotionSettled() {
        guard self.isMovingFast else {
            return
        }
        let now = self.motionClock()
        if let last = self.lastFastMotionTime, now - last < MediaGridView.motionSettleDelay {
            self.scheduleMotionSettle()
            return
        }
        self.motionSample = (now, self.engine.offset)
        self.setMovingFast(false)
    }

    private func setMovingFast(_ isMovingFast: Bool, upgrade: Bool = true) {
        let changed = self.isMovingFast != isMovingFast
        self.isMovingFast = isMovingFast
        self.activeLayoutLayer.suspendsSharpRequests = isMovingFast || self.isCellBindingScheduled
        self.resetPrefetch()
        if upgrade, !isMovingFast, self.transition == nil {
            if !self.layoutLevel.isInteractive {
                self.updateVisibleCells(offset: self.engine.offset)
            }
            self.requestVisibleSharpImages()
            self.updatePrefetch(offset: self.engine.offset)
            self.updateThumbnailPreparation()
        }
        if changed {
            self.onMovingFastChanged?(isMovingFast)
        }
    }

    private func requestVisibleSharpImages() {
        guard let layout = self.gridLayout, !self.isCellBindingScheduled, !self.defersCellBinding else {
            return
        }
        self.activeLayoutLayer.suspendsSharpRequests = self.isMovingFast
        let viewport = CGRect(x: 0.0, y: self.engine.offset, width: self.bounds.width, height: self.bounds.height)
        self.dataSource.performBatch {
            self.activeLayoutLayer.requestSharpImages(prioritizing: layout.indexRange(intersecting: viewport))
        }
    }

    func _testSettleMotion() {
        self.checkMotionSettled()
    }

    private func flightChanged(settledOffset: CGFloat?) {
        self.settledFlightOffset = settledOffset
        self.flightTargetOffset = settledOffset
        self.isFlightActive = settledOffset != nil
        self.updatePrefetch(offset: self.engine.offset)
        if self.transition == nil {
            self.updateThumbnailPreparation()
        }
        if settledOffset == nil {
            self.applyAspects()
        }
    }

    func _testSetRawOffset(_ y: CGFloat) {
        self.engine.setOffset(y)
        self.scrolled(to: self.engine.offset)
    }

    func _testFlight(settledOffset: CGFloat?) {
        self.flightChanged(settledOffset: settledOffset)
    }

    private func resetPrefetch() {
        let stale = self.prefetchPlanner.reset()
        self.settledFlightOffset = nil
        if !stale.isEmpty, let layout = self.prefetchLayout {
            MediaGridView.forEachPixelSizeRun(stale, layout: layout) { indices, pixelSize in
                self.dataSource.stopCaching(indices: indices, pixelSize: pixelSize)
            }
        }
    }

    private func updatePrefetch(offset: CGFloat) {
        guard let layout = self.gridLayout else {
            return
        }
        if self.defersCellBinding || self.isCellBindingScheduled || self.isMovingFast || !self.requestsSharpImages(at: self.layoutLevel) {
            return
        }
        let sizing = self.prefetchLayout ?? layout
        self.prefetchLayout = sizing
        let plan = self.prefetchPlanner.update(layout: layout, viewportHeight: self.bounds.height, offset: offset, settledOffset: self.settledFlightOffset)
        if !plan.stop.isEmpty {
            MediaGridView.forEachPixelSizeRun(plan.stop, layout: sizing) { indices, pixelSize in
                self.dataSource.stopCaching(indices: indices, pixelSize: pixelSize)
            }
        }
        if !plan.start.isEmpty {
            let center = layout.indexRange(intersecting: CGRect(x: 0.0, y: offset + self.bounds.height * 0.5, width: layout.geometry.width, height: 1.0)).lowerBound
            MediaGridView.forEachPixelSizeRun(MediaGridView.nearestFirst(plan.start, center: center), layout: sizing) { indices, pixelSize in
                self.dataSource.startCaching(indices: indices, pixelSize: pixelSize)
            }
        }
    }

    static func forEachPixelSizeRun(_ indices: [Int], layout: MediaGridLayout, _ body: ([Int], CGSize) -> Void) {
        var run: [Int] = []
        var runSize = CGSize.zero
        for index in indices where index < layout.count {
            let size = layout.pixelSize(at: index)
            if !run.isEmpty && size != runSize {
                body(run, runSize)
                run.removeAll(keepingCapacity: true)
            }
            runSize = size
            run.append(index)
        }
        if !run.isEmpty {
            body(run, runSize)
        }
    }

    static func nearestFirst(_ ascending: [Int], center: Int) -> [Int] {
        var upper = ascending.firstIndex(where: { $0 >= center }) ?? ascending.count
        var lower = upper - 1
        var result: [Int] = []
        result.reserveCapacity(ascending.count)
        while lower >= 0 || upper < ascending.count {
            if upper < ascending.count && (lower < 0 || ascending[upper] - center <= center - ascending[lower]) {
                result.append(ascending[upper])
                upper += 1
            } else {
                result.append(ascending[lower])
                lower -= 1
            }
        }
        return result
    }

    private func updateVisibleCells(offset: CGFloat) {
        guard let layout = self.gridLayout else {
            return
        }
        if self.defersCellBinding {
            self.scheduleCellBinding()
        }
        let height = self.bounds.height
        guard offset.isFinite, height > 0.0, height.isFinite else {
            return
        }
        let viewport = CGRect(x: 0.0, y: offset, width: self.bounds.width, height: height)
        let range = layout.indexRange(intersecting: viewport.insetBy(dx: 0.0, dy: -self.windowMargin(level: self.layoutLevel)))
        let priority = layout.indexRange(intersecting: viewport)
        self.updateThumbnailPreparation()
        self.activeLayoutLayer.suspendsSharpRequests = self.isMovingFast || self.isCellBindingScheduled
        self.dataSource.performBatch {
            self.activeLayoutLayer.updateVisibleRange(range, priority: priority)
        }
        self.pool.setVisibleCount(self.activeLayoutLayer.visibleCells.count)
        self.noteVisibleRange(priority)
    }

    public var visibleIndexRange: Range<Int>? {
        guard let layout = self.gridLayout, self.bounds.height > 0.0 else {
            return nil
        }
        return layout.indexRange(intersecting: CGRect(x: 0.0, y: self.engine.offset, width: self.bounds.width, height: self.bounds.height))
    }

    public var onVisibleRangeChanged: ((Range<Int>) -> Void)?
    private var lastReportedVisibleRange: Range<Int>?

    private func noteVisibleRange(_ range: Range<Int>) {
        if range == self.lastReportedVisibleRange {
            return
        }
        self.lastReportedVisibleRange = range
        self.onVisibleRangeChanged?(range)
    }

    private func scheduleCellBinding() {
        guard !self.isCellBindingScheduled else {
            return
        }
        self.isCellBindingScheduled = true
        let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.afterWaiting.rawValue, false, 0) { [weak self] _, _ in
            guard let self, self.isCellBindingScheduled else {
                return
            }
            self.isCellBindingScheduled = false
            if self.transition == nil {
                self.updateVisibleCells(offset: self.engine.offset)
                if !self.isMovingFast {
                    self.requestVisibleSharpImages()
                }
                self.updatePrefetch(offset: self.engine.offset)
            }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    private func requestsSharpImages(at level: MediaGridLevel) -> Bool {
        return level.isInteractive || self.compactLevelsRequestSharpImages
    }

    private func windowMargin(level: MediaGridLevel) -> CGFloat {
        if level.isInteractive {
            return self.bounds.height
        }
        return self.isMovingFast ? 0.0 : self.bounds.height * 0.25
    }
}

private final class MediaGridDisplayLinkTarget: NSObject {
    private weak var view: MediaGridView?

    init(_ view: MediaGridView) {
        self.view = view
    }

    @objc func tick() {
        self.view?.stepScrollAnimation()
    }
}

private final class MediaGridTouchFilter: NSObject, UIGestureRecognizerDelegate {
    var receivesTouch: (UIView?) -> Bool = { _ in return true }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return self.receivesTouch(touch.view)
    }
}

private final class MediaGridPinchDelegate: NSObject, UIGestureRecognizerDelegate {
    var shouldBegin: () -> Bool = { return false }
    var recognizesSimultaneously: (UIGestureRecognizer) -> Bool = { _ in return false }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.shouldBegin()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.recognizesSimultaneously(otherGestureRecognizer)
    }
}
