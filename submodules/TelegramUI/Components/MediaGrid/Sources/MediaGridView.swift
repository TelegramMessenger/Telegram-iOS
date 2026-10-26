import Foundation
import UIKit
import QuartzCore
import CoreList

public final class MediaGridView: UIView {
    private let dataSource: MediaGridDataSource
    private let engine: PhysicsScrollEngine
    private let pool: MediaGridCellPool
    let activeLayoutLayer: MediaGridLayoutLayer

    public private(set) var level: MediaGridLevel = .three
    private var itemCount: Int
    private(set) var currentLayout: MediaGridUniformLayout?
    private var needsLayoutRebuild = true
    private var prefetchPlanner = MediaGridPrefetchPlanner()
    private var prefetchPixelSize: CGSize = .zero
    private var settledFlightOffset: CGFloat?
    private var isDragging = false
    private var isNotifyingScroll = false
    private var pendingContentOffset: CGFloat?
    private var dateCache: [Int: Date?] = [:]

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

    public var cellAspect: CGFloat = 1.0 {
        didSet {
            if self.cellAspect != oldValue {
                self.invalidateGridLayout()
            }
        }
    }

    public var onScroll: ((CGFloat) -> Void)?

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
        self.engine.onScroll = { [weak self] offset in
            self?.scrolled(to: offset)
        }
        self.engine.onWillBeginDragging = { [weak self] in
            self?.isDragging = true
        }
        self.engine.onDidEndDragging = { [weak self] in
            self?.isDragging = false
        }
        self.engine.onFlightChanged = { [weak self] flight in
            self?.flightChanged(settledOffset: flight?.settledOffset)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.engine.tearDown()
        self.resetPrefetch()
        self.activeLayoutLayer.removeAllCells()
    }

    public var contentOffset: CGFloat {
        return self.engine.offset
    }

    public var contentHeight: CGFloat {
        return self.currentLayout?.contentHeight ?? 0.0
    }

    public var isUserScrolling: Bool {
        return self.isDragging || self.engine.isDecelerating
    }

    public var topVisibleIndex: Int? {
        guard let layout = self.currentLayout, layout.count > 0 else {
            return nil
        }
        let pitch = layout.itemSize.height + layout.geometry.spacing
        let minY = min(max(layout.geometry.topInset, self.engine.offset + layout.geometry.topInset), max(layout.geometry.topInset, layout.contentHeight - layout.geometry.bottomInset - 1.0))
        let strip = CGRect(x: 0.0, y: minY, width: layout.geometry.width, height: max(1.0, pitch))
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
        self.dateCache[index] = .some(date)
        return date
    }

    private var maxOffset: CGFloat {
        return max(0.0, self.contentHeight - self.bounds.height)
    }

    public func reloadData() {
        self.itemCount = max(0, self.dataSource.count)
        self.needsLayoutRebuild = true
        self.dateCache = [:]
        self.resetPrefetch()
        self.activeLayoutLayer.reloadCells()
        self.updateGridLayout()
    }

    public func setContentOffset(_ y: CGFloat) {
        guard y.isFinite else {
            return
        }
        guard self.currentLayout != nil else {
            self.pendingContentOffset = y
            return
        }
        let offset = min(max(0.0, y), self.maxOffset)
        self.engine.setOffset(offset)
        self.scrolled(to: offset)
    }

    public func forEachVisibleCell(_ f: (Int, MediaGridCellLayer) -> Void) {
        for (index, cell) in self.activeLayoutLayer.visibleCells {
            f(index, cell)
        }
    }

    public func frameForItem(at index: Int) -> CGRect? {
        guard let layout = self.currentLayout, index >= 0, index < layout.count else {
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
        return self.level.isInteractive ? .full : .compact
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
        let insets = self.geometryInsets
        let geometry = MediaGridGeometry(width: size.width, sideInset: max(insets.left, insets.right), topInset: insets.top, bottomInset: insets.bottom, spacing: 1.0, scale: self.displayScale)
        if self.needsLayoutRebuild || self.currentLayout?.geometry != geometry {
            self.needsLayoutRebuild = false
            let layout = MediaGridUniformLayout(geometry: geometry, columns: self.level.columns, cellAspect: self.cellAspect, reservedSlots: [], count: self.itemCount)
            self.resetPrefetch()
            self.currentLayout = layout
            let pixelSize = CGSize(width: ceil(layout.itemSize.width * geometry.scale), height: ceil(layout.itemSize.height * geometry.scale))
            self.prefetchPixelSize = pixelSize
            self.activeLayoutLayer.setLayout(layout, pixelSize: pixelSize, detail: self.cellDetail)
            self.activeLayoutLayer.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: layout.contentHeight)
        }
        self.engine.setEdges(min: 0.0, max: self.maxOffset)
        if let pending = self.pendingContentOffset {
            self.pendingContentOffset = nil
            self.engine.setOffset(min(max(0.0, pending), self.maxOffset))
            self.scrolled(to: self.engine.offset)
        }
        if !self.engine.isDecelerating && self.engine.offset > self.maxOffset {
            self.engine.setOffset(self.maxOffset)
        }
        self.updateVisibleCells(offset: self.engine.offset)
        self.updatePrefetch(offset: self.engine.offset)
    }

    private func scrolled(to offset: CGFloat) {
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

    private func flightChanged(settledOffset: CGFloat?) {
        self.settledFlightOffset = settledOffset
        self.updatePrefetch(offset: self.engine.offset)
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
        if !stale.isEmpty {
            self.dataSource.stopCaching(indices: stale, pixelSize: self.prefetchPixelSize)
        }
    }

    private func updatePrefetch(offset: CGFloat) {
        guard let layout = self.currentLayout else {
            return
        }
        let plan = self.prefetchPlanner.update(layout: layout, viewportHeight: self.bounds.height, offset: offset, settledOffset: self.settledFlightOffset)
        if !plan.stop.isEmpty {
            self.dataSource.stopCaching(indices: plan.stop, pixelSize: self.prefetchPixelSize)
        }
        if !plan.start.isEmpty {
            self.dataSource.startCaching(indices: plan.start, pixelSize: self.prefetchPixelSize)
        }
    }

    private func updateVisibleCells(offset: CGFloat) {
        guard let layout = self.currentLayout else {
            return
        }
        let height = self.bounds.height
        guard offset.isFinite, height > 0.0, height.isFinite else {
            return
        }
        let viewport = CGRect(x: 0.0, y: offset, width: self.bounds.width, height: height)
        let range = layout.indexRange(intersecting: viewport.insetBy(dx: 0.0, dy: -height))
        self.activeLayoutLayer.updateVisibleRange(range)
    }
}
