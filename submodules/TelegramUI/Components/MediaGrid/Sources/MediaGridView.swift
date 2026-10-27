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

    private let tapRecognizer = UITapGestureRecognizer()
    private let selectionGesture = MediaGridSelectionGesture()
    private let pinchRecognizer = UIPinchGestureRecognizer()
    private let pinchDelegate = MediaGridPinchDelegate()
    private var lastTopInset: CGFloat?

    private static let cameraSlots: Set<MediaGridSlot> = [MediaGridSlot(row: 0, column: 0), MediaGridSlot(row: 1, column: 0)]

    private func reservedSlots(for level: MediaGridLevel) -> Set<MediaGridSlot> {
        return level.showsCamera && self.cameraView != nil ? MediaGridView.cameraSlots : []
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
        self.tapRecognizer.addTarget(self, action: #selector(self.tapped(_:)))
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
            self.engine.isScrollEnabled = isEnabled && self.transition == nil && self.pinch == nil
        }
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
        self.endInteraction()
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
        self.endInteraction()
        let offset = min(max(0.0, y), self.maxOffset)
        self.engine.setOffset(offset)
        self.scrolled(to: offset)
    }

    public func forEachVisibleCell(_ f: (Int, MediaGridCellLayer) -> Void) {
        for (index, cell) in self.activeLayoutLayer.visibleCells {
            f(index, cell)
        }
    }

    public func index(at point: CGPoint) -> Int? {
        guard let layout = self.currentLayout else {
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
            self.updateSelectionForVisibleItems()
        } else if self.isZoomEnabled, let target = self.layoutLevel.zoomedIn {
            self.setLevel(target, animated: true, anchor: MediaGridZoomAnchor(index: index, pointInView: point))
        }
    }

    public var canZoomIn: Bool {
        return self.isZoomEnabled && self.level.zoomedIn != nil
    }

    public var canZoomOut: Bool {
        return self.isZoomEnabled && self.level.zoomedOut != nil
    }

    public func zoomIn() {
        self.endInteraction()
        guard self.isZoomEnabled, let target = self.level.zoomedIn else {
            return
        }
        self.setLevel(target, animated: true, anchor: self.centreAnchor())
    }

    public func zoomOut() {
        self.endInteraction()
        guard self.isZoomEnabled, let target = self.level.zoomedOut else {
            return
        }
        self.setLevel(target, animated: true, anchor: self.centreAnchor())
    }

    private func centreAnchor() -> MediaGridZoomAnchor? {
        return self.anchor(at: CGPoint(x: self.bounds.midX, y: self.bounds.midY))
    }

    private func anchor(at centre: CGPoint) -> MediaGridZoomAnchor? {
        guard let layout = self.currentLayout, layout.count > 0, self.bounds.height > 0.0 else {
            return nil
        }
        if let index = self.index(at: centre) {
            return MediaGridZoomAnchor(index: index, pointInView: centre)
        }
        let host = self.engine.contentHost.frame
        let strip = CGRect(x: 0.0, y: centre.y - host.minY + self.engine.offset, width: layout.geometry.width, height: layout.itemSize.height + layout.geometry.spacing)
        let range = layout.indexRange(intersecting: strip)
        let index = range.isEmpty ? (self.topVisibleIndex ?? layout.count - 1) : range.lowerBound
        guard let frame = self.frameForItem(at: index) else {
            return nil
        }
        return MediaGridZoomAnchor(index: index, pointInView: CGPoint(x: frame.midX, y: centre.y))
    }

    private func relativePosition(of anchor: MediaGridZoomAnchor) -> CGPoint {
        guard let frame = self.frameForItem(at: anchor.index) else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        return MediaGridZoomMath.relativePosition(of: anchor.pointInView, in: frame)
    }

    public func setLevel(_ level: MediaGridLevel, animated: Bool, anchor: MediaGridZoomAnchor? = nil) {
        self.endInteraction()
        guard level != self.level else {
            return
        }
        let resolvedAnchor = anchor ?? self.centreAnchor()
        guard let source = self.currentLayout, self.bounds.width > 0.0, self.bounds.height > 0.0, let resolvedAnchor, resolvedAnchor.index >= 0, resolvedAnchor.index < source.count else {
            self.level = level
            self.layoutLevel = level
            self.invalidateGridLayout()
            self.updateGridLayout()
            self.onLevelChanged?(level)
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
            return
        }
        let transition = self.beginTransition(to: level, source: source, anchor: resolvedAnchor, relativePosition: relative, binding: 0.0 ... 1.0)
        transition.animate(to: 1.0, completion: { [weak self, weak transition] in
            guard let self, let transition, self.transition === transition else {
                return
            }
            self.finishTransition()
        })
    }

    private func makeLayout(level: MediaGridLevel, geometry: MediaGridGeometry) -> MediaGridUniformLayout {
        return MediaGridUniformLayout(geometry: geometry, columns: level.columns, cellAspect: self.cellAspect, reservedSlots: self.reservedSlots(for: level), count: self.itemCount)
    }

    private func pixelSize(for layout: MediaGridUniformLayout) -> CGSize {
        return CGSize(width: ceil(layout.itemSize.width * layout.geometry.scale), height: ceil(layout.itemSize.height * layout.geometry.scale))
    }

    @discardableResult
    private func beginTransition(to level: MediaGridLevel, source: MediaGridUniformLayout, anchor: MediaGridZoomAnchor, relativePosition: CGPoint, binding: ClosedRange<CGFloat>) -> MediaGridZoomTransition {
        let sourceLevel = self.layoutLevel

        let width = self.bounds.width
        let height = self.bounds.height
        let host = self.engine.contentHost.frame
        let sourceOffset = self.engine.offset
        let target = self.makeLayout(level: level, geometry: source.geometry)
        let targetOffset = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: anchor.index, pointInView: CGPoint(x: anchor.pointInView.x - host.minX, y: anchor.pointInView.y - host.minY)), in: target, viewportHeight: height, relativePosition: relativePosition)
        let scale = MediaGridZoomMath.scale(from: source, to: target, anchorIndex: anchor.index)
        let anchorPoint = CGPoint(x: anchor.pointInView.x - host.minX, y: anchor.pointInView.y - host.minY + sourceOffset)
        let shift = sourceOffset - targetOffset
        let pixelSize = self.pixelSize(for: target)

        let incoming = self.spareLayoutLayer ?? MediaGridLayoutLayer(dataSource: self.dataSource, pool: self.pool)
        self.spareLayoutLayer = nil
        incoming.isItemSelected = self.isItemSelected
        incoming.opacity = 1.0
        incoming.setLayout(target, pixelSize: pixelSize, detail: level.isInteractive ? .full : .compact)
        MediaGridZoomTransition.resetPivot(incoming, width: width, height: target.contentHeight, originY: shift)
        self.engine.contentHost.layer.insertSublayer(incoming, above: self.activeLayoutLayer)

        var cameraRole: MediaGridZoomTransition.CameraRole = .none
        var cameraAlpha: (CGFloat, CGFloat) = (0.0, 0.0)
        if let cameraView = self.cameraView {
            let sourceShows = !self.reservedSlots(for: sourceLevel).isEmpty
            let targetSlots = self.reservedSlots(for: level)
            if sourceShows, !targetSlots.isEmpty, let frame = target.reservedFrame(targetSlots) {
                cameraRole = .moving(from: cameraView.frame, to: frame.offsetBy(dx: 0.0, dy: shift))
                cameraAlpha = (1.0, 1.0)
            } else if !targetSlots.isEmpty, let frame = target.reservedFrame(targetSlots) {
                cameraRole = .incoming
                cameraAlpha = (sourceShows ? 1.0 : 0.0, 1.0)
                cameraView.layer.transform = CATransform3DIdentity
                cameraView.frame = frame.offsetBy(dx: 0.0, dy: shift)
                cameraView.isHidden = false
            } else if sourceShows {
                cameraRole = .outgoing
                cameraAlpha = (1.0, 0.0)
            }
        }

        var cameraTakesPart = true
        if case .none = cameraRole {
            cameraTakesPart = false
        }
        let transition = MediaGridZoomTransition(sourceLevel: sourceLevel, targetLevel: level, sourceLayout: source, outgoing: self.activeLayoutLayer, outgoingLocalAnchor: anchorPoint, incoming: incoming, incomingLocalAnchor: CGPoint(x: anchorPoint.x, y: anchorPoint.y - shift), anchorPoint: anchorPoint, viewportSize: CGSize(width: width, height: height), scale: scale, targetLayout: target, targetOffset: targetOffset, targetPixelSize: pixelSize, camera: cameraTakesPart ? self.cameraView : nil, cameraRole: cameraRole, cameraAlphaRange: cameraAlpha)
        transition.viewport = CGRect(x: 0.0, y: sourceOffset, width: width, height: height)
        transition.shift = shift
        self.transition = transition
        self.transitionAnchor = (anchor, relativePosition)
        self.bindTransition(transition, covering: binding)
        transition.apply(progress: 0.0)
        self.updateGestureAvailability()
        self.engine.isScrollEnabled = false
        return transition
    }

    private static let bindStep: CGFloat = 0.125

    private func bindTransition(_ transition: MediaGridZoomTransition, covering range: ClosedRange<CGFloat>) {
        let lower = min(1.0, max(0.0, range.lowerBound))
        let upper = min(1.0, max(0.0, range.upperBound))
        if let bound = transition.boundRange, bound.lowerBound <= lower, bound.upperBound >= upper {
            return
        }
        let step = MediaGridView.bindStep
        var newLower = max(0.0, floor(lower / step) * step)
        var newUpper = min(1.0, ceil(upper / step) * step)
        if let bound = transition.boundRange {
            newLower = min(newLower, bound.lowerBound)
            newUpper = max(newUpper, bound.upperBound)
        }
        transition.boundRange = newLower ... newUpper
        let pad = self.bounds.height * 0.05
        let incomingRect = transition.incomingRect(at: newLower).union(transition.incomingRect(at: newUpper)).insetBy(dx: 0.0, dy: -pad)
        transition.incoming.updateVisibleRange(transition.targetLayout.indexRange(intersecting: incomingRect))
        let outgoingRect = transition.outgoingRect(at: newLower).union(transition.outgoingRect(at: newUpper)).insetBy(dx: 0.0, dy: -pad)
        var outgoingRange = transition.sourceLayout.indexRange(intersecting: outgoingRect)
        let current = transition.outgoing.visibleRange
        if !current.isEmpty, current.overlaps(outgoingRange) {
            outgoingRange = min(current.lowerBound, outgoingRange.lowerBound) ..< max(current.upperBound, outgoingRange.upperBound)
        }
        transition.outgoing.updateVisibleRange(outgoingRange)
        self.pool.setVisibleCount(transition.outgoing.visibleCells.count + transition.incoming.visibleCells.count)
    }

    private func jumpLayout(to level: MediaGridLevel, anchor: MediaGridZoomAnchor, relativePosition: CGPoint) {
        guard let source = self.currentLayout else {
            return
        }
        let height = self.bounds.height
        let host = self.engine.contentHost.frame
        let target = self.makeLayout(level: level, geometry: source.geometry)
        let offset = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: anchor.index, pointInView: CGPoint(x: anchor.pointInView.x - host.minX, y: anchor.pointInView.y - host.minY)), in: target, viewportHeight: height, relativePosition: relativePosition)
        self.activeLayoutLayer.removeAllCells()
        self.activeLayoutLayer.setLayout(target, pixelSize: self.pixelSize(for: target), detail: level.isInteractive ? .full : .compact)
        self.activeLayoutLayer.frame = CGRect(x: 0.0, y: 0.0, width: self.bounds.width, height: target.contentHeight)
        self.layoutLevel = level
        self.currentLayout = target
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
        self.transitionAnchor = nil
        transition.removeAnimations()
        let width = self.bounds.width
        let outgoing = transition.outgoing
        let incoming = transition.incoming
        if commits {
            outgoing.removeAllCells()
            MediaGridZoomTransition.resetPivot(outgoing, width: width, height: 0.0, originY: 0.0)
            outgoing.opacity = 1.0
            outgoing.removeFromSuperlayer()
            self.spareLayoutLayer = outgoing

            MediaGridZoomTransition.resetPivot(incoming, width: width, height: transition.targetLayout.contentHeight, originY: 0.0)
            incoming.opacity = 1.0
            self.activeLayoutLayer = incoming

            self.layoutLevel = transition.targetLevel
            self.currentLayout = transition.targetLayout
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
        if let layout = self.currentLayout {
            self.layoutCamera(layout: layout)
        }
        if !quiet {
            self.completeZoom()
        }
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
        if let layout = self.currentLayout {
            let pixelSize = self.pixelSize(for: layout)
            if pixelSize != self.prefetchPixelSize {
                self.resetPrefetch()
                self.prefetchPixelSize = pixelSize
            }
        }
        self.engine.isScrollEnabled = true
        self.updateGestureAvailability()
        self.scrolled(to: self.engine.offset)
        if self.level != previousLevel {
            self.onLevelChanged?(self.level)
        }
    }

    private func updateGestureAvailability() {
        let idle = self.transition == nil && self.pinch == nil
        let interactive = self.layoutLevel.isInteractive
        self.tapRecognizer.isEnabled = idle && (interactive || self.isZoomEnabled)
        self.selectionGesture.isEnabled = idle && interactive
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
        guard self.isZoomEnabled, let layout = self.currentLayout, layout.count > 0, self.bounds.width > 0.0, self.bounds.height > 0.0 else {
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
        self.engine.haltMotionInPlace()
        self.resetOvershoot()
        let state: MediaGridPinchState
        let relativePosition: CGPoint
        if let transition = self.transition, let (anchor, relative) = self.transitionAnchor {
            transition.interrupt()
            state = MediaGridPinchState(startLevel: transition.sourceLevel, anchor: anchor, toward: transition.targetLevel, startProgress: transition.progress)
            relativePosition = relative
        } else {
            let hostLayer = self.engine.contentHost.layer
            if let keys = hostLayer.animationKeys(), !keys.isEmpty, let presentedOffset = hostLayer.presentation()?.bounds.origin.y, presentedOffset.isFinite, abs(presentedOffset - self.engine.offset) > 0.5 {
                self.engine.setOffset(presentedOffset)
            }
            guard let anchor = self.anchor(at: center) else {
                return
            }
            state = MediaGridPinchState(startLevel: self.layoutLevel, anchor: anchor)
            relativePosition = self.relativePosition(of: anchor)
        }
        self.pinch = PinchSession(state: state, relativePosition: relativePosition, isTracking: true)
        self.updateGestureAvailability()
        self.engine.isScrollEnabled = false
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
                        let beyond = distance * span / ownSpan
                        transition.apply(progress: shared == target ? 1.0 + beyond : -beyond)
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
            guard let session = self.pinch, let source = self.currentLayout else {
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
            } else if let next = from > level ? level.zoomedOut : level.zoomedIn {
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
        let destination: CGFloat = target == transition.targetLevel ? 1.0 : 0.0
        self.bindTransition(transition, covering: min(transition.progress, destination) ... max(transition.progress, destination))
        let progressVelocity = session.state.progressVelocity(scaleVelocity: velocity)
        transition.animate(to: destination, velocity: transition.sourceLevel == session.state.current.from ? progressVelocity : -progressVelocity, completion: { [weak self, weak transition] in
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
    public func debugDrivePinch(_ state: UIGestureRecognizer.State, center: CGPoint, scale: CGFloat, velocity: CGFloat) {
        self._testPinch(state, center: center, scale: scale, velocity: velocity)
    }
    #endif

    private func layoutCamera(layout: MediaGridUniformLayout) {
        guard let cameraView = self.cameraView else {
            return
        }
        cameraView.layer.transform = CATransform3DIdentity
        if !self.reservedSlots(for: self.layoutLevel).isEmpty, let frame = layout.reservedFrame(MediaGridView.cameraSlots) {
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
        let insets = self.geometryInsets
        let geometry = MediaGridGeometry(width: size.width, sideInset: max(insets.left, insets.right), topInset: insets.top, bottomInset: insets.bottom, spacing: 1.0, scale: self.displayScale)
        if let transition = self.transition {
            if !self.needsLayoutRebuild && transition.targetLayout.geometry == geometry {
                return
            }
            self.finishTransition()
        }
        if self.pinch != nil && (self.needsLayoutRebuild || self.currentLayout?.geometry != geometry) {
            self.completeZoom()
        }
        var compensatedOffset: CGFloat?
        var zoomOffset: CGFloat?
        if self.needsLayoutRebuild || self.currentLayout?.geometry != geometry {
            self.needsLayoutRebuild = false
            let layout = self.makeLayout(level: self.layoutLevel, geometry: geometry)
            if let lastTopInset = self.lastTopInset, lastTopInset != insets.top, self.engine.offset > 0.0, self.pendingContentOffset == nil {
                compensatedOffset = max(0.0, self.engine.offset + (insets.top - lastTopInset))
            }
            if let zoom = self.pendingZoom {
                compensatedOffset = nil
                let host = self.engine.contentHost.frame
                let point = CGPoint(x: zoom.anchor.pointInView.x - host.minX, y: zoom.anchor.pointInView.y - host.minY)
                zoomOffset = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: zoom.anchor.index, pointInView: point), in: layout, viewportHeight: size.height, relativePosition: zoom.relativePosition)
            }
            self.lastTopInset = insets.top
            self.resetPrefetch()
            self.currentLayout = layout
            let pixelSize = self.pixelSize(for: layout)
            self.prefetchPixelSize = pixelSize
            self.activeLayoutLayer.setLayout(layout, pixelSize: pixelSize, detail: self.cellDetail)
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
        if let compensated = compensatedOffset {
            self.engine.setOffset(min(compensated, self.maxOffset))
            self.scrolled(to: self.engine.offset)
        }
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
        if self.transition != nil {
            return
        }
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
        let range = layout.indexRange(intersecting: viewport.insetBy(dx: 0.0, dy: -self.windowMargin(level: self.layoutLevel)))
        self.activeLayoutLayer.updateVisibleRange(range)
        self.pool.setVisibleCount(self.activeLayoutLayer.visibleCells.count)
    }

    private func windowMargin(level: MediaGridLevel) -> CGFloat {
        return level.isInteractive ? self.bounds.height : self.bounds.height * 0.25
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
