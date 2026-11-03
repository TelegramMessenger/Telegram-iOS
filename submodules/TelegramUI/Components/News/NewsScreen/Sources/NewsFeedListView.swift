import Foundation
import UIKit
import Display
import TelegramPresentationData
import CoreList
import CoreListComponentHost
import NewsFeedSupport
import NewsFeedComponents

/// One feed list: a `CoreVirtualListView` of component rows, plus the offset reporting, edge loading and
/// pull-to-refresh the screen needs.
final class NewsFeedListView: UIView {
    enum ScrollOffset: Equatable {
        /// Distance the content is scrolled from its top (0 at rest at the top).
        case known(CGFloat)
        /// The first row is not loaded.
        case unknown

        var knownValue: CGFloat? {
            if case let .known(value) = self {
                return value
            }
            return nil
        }
    }

    // Main-thread physics rather than the render-server keyframe flights the chat uses, so the navigation bar,
    // which follows this list's offset, stays in sync with the content.
    let coreList = CoreVirtualListView(forEmbedding: CGRect(), deceleration: .stepped)
    /// Set only during this list's own passes, whose rows are on screen at once; rows a scroll builds load
    /// their avatars in the background.
    let rowLoading = NewsFeedRowLoading()
    private let skeletonView = NewsFeedSkeletonView()
    private var showsSkeleton = false
    private var skeletonParameters: (theme: PresentationTheme, rowLayout: NewsSkeletonModelRow)?
    private(set) var items: [CoreListComponentItem] = []
    private(set) var insets = UIEdgeInsets()
    /// The refresh drop's hold (spec §1.4): extra top inset while it loads. `insets` stay the resting ones, so the
    /// offsets this view reports, and the header that follows them, are measured from the resting edge.
    private(set) var refreshHold: CGFloat = 0.0
    private(set) var isDragging = false

    private var coreListInsets: UIEdgeInsets {
        var insets = self.insets
        insets.top += self.refreshHold
        return insets
    }

    var reduceMotion = false
    /// Content just replaced the skeleton: the next pass cascades its rows in.
    private var pendingCascade = false
    private var cascadeStart: (time: Double, firstIndex: Int)?
    private var cascadedViews = Set<ObjectIdentifier>()
    var onEdgeReached: ((CoreListLoadedEdge) -> Void)?
    /// The offset to follow and how to follow it: the presented offset, `.immediate`, while the user scrolls;
    /// after a programmatic pass, its settled offset with the pass's own transition, since CoreList reports
    /// nothing while that pass animates or when it lands.
    var onScrollOffsetChanged: ((ScrollOffset, CoreListTransition) -> Void)?
    var onVisibleRowsChanged: (() -> Void)?
    var onScrollingEnded: (() -> Void)?
    var onWillBeginDragging: (() -> Void)?
    /// After a programmatic scroll (which fires no visible-window callback): re-read rows with settled geometry.
    var onProgrammaticScroll: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.coreList)
        // Over the rows.
        self.skeletonView.isHidden = true
        self.addSubview(self.skeletonView)

        self.coreList.onLoadedEdgeReached = { [weak self] edge in
            // Runs at the end of a pass: load on the next turn.
            DispatchQueue.main.async {
                self?.onEdgeReached?(edge)
            }
        }
        self.coreList.onVisibleWindowChanged = { [weak self] in
            guard let self else {
                return
            }
            self.onScrollOffsetChanged?(self.scrollOffset(settled: false), .immediate)
            self.onVisibleRowsChanged?()
            self.layoutSkeleton()
            self.applyCascade()
        }
        self.coreList.didEndDragging = { [weak self] in
            guard let self else {
                return
            }
            self.isDragging = false
            // A release without momentum is where scrolling ends; with momentum, `didEndScrolling` reports the
            // end (a `.stepped` deceleration too). Snapping here mid-fling would halt it.
            if !self.coreList.isScrollDecelerating {
                self.onScrollingEnded?()
            }
        }
        self.coreList.didEndScrolling = { [weak self] in
            self?.onScrollingEnded?()
        }
        self.coreList.willBeginDragging = { [weak self] in
            self?.isDragging = true
            // Scrolling closes an open swipe (spec §5).
            self?.closeSwipedRows(animated: true)
            self?.onWillBeginDragging?()
        }
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    func update(size: CGSize, insets: UIEdgeInsets, items: [CoreListComponentItem], scrollTo: CoreListScrollTarget?, anchorMode: CoreListAnchorMode, animatesInsertions: Bool = true, transition: CoreListTransition) {
        self.coreList.frame = CGRect(origin: CGPoint(), size: size)
        self.items = items
        self.insets = insets
        self.withSynchronousRowLoading {
            self.coreList.applyChanges(items: items, newSize: size, newInsets: self.coreListInsets, scrollTo: scrollTo, anchorMode: anchorMode, animatesInsertions: animatesInsertions, transition: transition)
        }
        // Rows may have moved under an open one: the separator above it is recomputed from scratch.
        self.updateSwipeSeparators()
        // A programmatic pass fires no scroll callback: report the settled offset.
        self.onScrollOffsetChanged?(self.scrollOffset(settled: true), transition)
        self.layoutSkeleton()
        if scrollTo != nil {
            self.onProgrammaticScroll?()
        }
        self.applyCascade()
    }

    // MARK: Swipe (spec §1, §4, §5)

    private func postRow(_ view: UIView) -> NewsFeedPostComponent.View? {
        return (view as? CoreListComponentItemView)?.componentView as? NewsFeedPostComponent.View
    }

    /// One open row at a time: closes every loaded row but `keptRow`. A row outside the loaded window is gone and
    /// comes back closed.
    func closeSwipedRows(except keptRow: NewsFeedPostComponent.View? = nil, animated: Bool) {
        for view in self.coreList.loadedItemViews {
            guard let row = self.postRow(view), row !== keptRow else {
                continue
            }
            row.closeSwipe(animated: animated)
        }
    }

    /// The separator above a row is the bottom separator of the row before it; it fades with that row's swipe (the
    /// chat list finds the row above among `ListView` siblings, which CoreList rows are not).
    func updateSwipeSeparators() {
        var rows: [Int: NewsFeedPostComponent.View] = [:]
        var alphas: [Int: CGFloat] = [:]
        for entry in self.coreList.loadedItemEntries {
            guard let row = self.postRow(entry.view) else {
                continue
            }
            rows[entry.index] = row
            alphas[entry.index] = row.swipeSeparatorAlpha
        }
        for (index, alpha) in newsSeparatorAlphasFromRowsBelow(alphas) {
            rows[index]?.setRowBelowSeparatorAlpha(alpha)
        }
    }

    /// Whether `point` (in this view) is on a post row with swipe actions, for the pager's rule.
    func hasSwipeableRow(at point: CGPoint) -> Bool {
        for view in self.coreList.loadedItemViews {
            guard let row = self.postRow(view), row.hasSwipeActions else {
                continue
            }
            if row.bounds.contains(row.convert(point, from: self)) {
                return true
            }
        }
        return false
    }

    private func withSynchronousRowLoading(_ f: () -> Void) {
        let previous = self.rowLoading.isSynchronous
        self.rowLoading.isSynchronous = true
        f()
        self.rowLoading.isSynchronous = previous
    }

    /// Until the list's first content arrives a skeleton stands in for it, moving with the list's offset (an
    /// overscroll while there are no rows); when it arrives, the list fades in and the skeleton out.
    func setShowsSkeleton(_ value: Bool, theme: PresentationTheme, rowLayout: NewsSkeletonModelRow) {
        self.skeletonParameters = (theme, rowLayout)
        if value {
            if !self.showsSkeleton {
                self.showsSkeleton = true
                self.skeletonView.layer.removeAllAnimations()
                self.skeletonView.alpha = 1.0
                self.skeletonView.isHidden = false
            }
            self.layoutSkeleton()
        } else if self.showsSkeleton {
            self.showsSkeleton = false
            self.pendingCascade = true
            // Measured on the mockup's Reload: the skeleton is gone in about 0.1 s as the rows start.
            self.skeletonView.alpha = 0.0
            self.skeletonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, completion: { [weak self] _ in
                guard let self, !self.showsSkeleton else {
                    return
                }
                self.skeletonView.isHidden = true
            })
        }
    }

    /// Rows present within 0.6 s of the content arriving fade and rise in, top to bottom, 45 ms apart (Feed2
    /// FeedRow.swift:104-112). Positions count from the first row loaded when the content arrived (spec §11.4).
    private func applyCascade() {
        if self.pendingCascade {
            self.pendingCascade = false
            guard let range = self.coreList.loadedIndexRange else {
                return
            }
            self.cascadeStart = (CACurrentMediaTime(), range.first)
            self.cascadedViews.removeAll()
        }
        guard let start = self.cascadeStart else {
            return
        }
        let now = CACurrentMediaTime()
        guard now - start.time <= NewsCascade.window else {
            self.cascadeStart = nil
            self.cascadedViews.removeAll()
            return
        }
        guard let range = self.coreList.loadedIndexRange else {
            return
        }
        for index in range.first ... range.last {
            guard let itemView = self.coreList.loadedItemView(at: index) as? CoreListComponentItemView, let content = itemView.componentView else {
                continue
            }
            guard self.cascadedViews.insert(ObjectIdentifier(itemView)).inserted else {
                continue
            }
            let delay = max(0.0, start.time + NewsCascade.delay(position: max(0, index - start.firstIndex)) - now)
            content.layer.add(NewsSpring.appear.makeAnimation(keyPath: "opacity", from: 0.0 as NSNumber, to: 1.0 as NSNumber, delay: delay), forKey: "newsCascadeAlpha")
            if !self.reduceMotion {
                content.layer.add(NewsSpring.appear.makeAnimation(keyPath: "transform.translation.y", from: NewsCascade.offset as NSNumber, to: 0.0 as NSNumber, delay: delay), forKey: "newsCascadeOffset")
            }
        }
    }

    private func layoutSkeleton() {
        guard !self.skeletonView.isHidden, let (theme, rowLayout) = self.skeletonParameters else {
            return
        }
        // Rows start at the content inset; the skeleton moves with the first row, or with the overscroll while
        // there is none.
        let offset = self.scrollOffset(settled: false).knownValue ?? self.coreList.overscrollDistance
        let size = CGSize(width: max(1.0, self.bounds.width - self.insets.left - self.insets.right), height: max(1.0, self.bounds.height))
        self.skeletonView.frame = CGRect(origin: CGPoint(x: self.insets.left, y: self.insets.top - offset), size: size)
        self.skeletonView.update(size: size, theme: theme, rowLayout: rowLayout)
    }

    /// As the chat's overscroll hold: engaging keeps the content under the finger (the band re-measures against
    /// the moved edge); releasing keeps the band's magnitude, so the content rides back with the edge.
    func setRefreshHold(_ hold: CGFloat) {
        guard hold != self.refreshHold else {
            return
        }
        let engaging = hold > self.refreshHold
        self.refreshHold = hold
        self.withSynchronousRowLoading {
            self.coreList.applyChanges(newInsets: self.coreListInsets, compensatesInsetChange: false, absorbsEdgeChangeIntoOverscroll: engaging, transition: .immediate)
        }
        // CoreList reports nothing for a pass it ran itself.
        self.onScrollOffsetChanged?(self.scrollOffset(settled: false), .immediate)
        self.layoutSkeleton()
    }

    /// How far the list is pulled past its resting top, hold included; 0 when scrolled or unknown.
    var pullDistance: CGFloat {
        return max(0.0, -(self.scrollOffset(settled: false).knownValue ?? 0.0))
    }

    /// Resting at its current top edge, held or not (the mockup's `atEdge`).
    var isAtTopEdge: Bool {
        guard let offset = self.scrollOffset(settled: false).knownValue else {
            return false
        }
        return abs(offset + self.refreshHold) < 1.5
    }

    /// Index 0's presented frame, if it is loaded.
    var firstRowFrame: CGRect? {
        guard let range = self.coreList.loadedIndexRange, range.first == 0, let view = self.coreList.loadedItemView(at: 0) else {
            return nil
        }
        return self.coreList.presentedFrame(of: view)
    }

    /// The refreshed posts sliding in: `NewsSpring.spread`, run for its settling time (spec §3.4).
    static var refreshInsertTransition: CoreListTransition {
        let spring = NewsSpring.spread
        return CoreListTransition(animation: .curve(duration: spring.settlingDuration, curve: .customSpring(mass: spring.mass, stiffness: spring.stiffness, damping: spring.damping, initialVelocity: 0.0)))
    }

    /// Rows going in or out for the "Post hidden" flow: `NewsSpring.rows` (`Motion.rows`), run for its settling time.
    static var feedbackRowsTransition: CoreListTransition {
        let spring = NewsSpring.rows
        return CoreListTransition(animation: .curve(duration: spring.settlingDuration, curve: .customSpring(mass: spring.mass, stiffness: spring.stiffness, damping: spring.damping, initialVelocity: 0.0)))
    }

    func scrollOffset(settled: Bool) -> ScrollOffset {
        if self.items.isEmpty {
            // No rows (the skeleton stands in, or the page is empty): the list rests at its top and only an
            // overscroll moves it, so the header shows its search as it would above a first row.
            return .known(self.coreList.overscrollDistance - self.refreshHold)
        }
        guard let range = self.coreList.loadedIndexRange, range.first == 0, let view = self.coreList.loadedItemView(at: 0) else {
            return .unknown
        }
        let frame = settled ? self.coreList.settledFrame(of: view) : self.coreList.presentedFrame(of: view)
        return .known(-(frame.minY - self.insets.top))
    }

    var viewport: CGRect {
        return CGRect(x: 0.0, y: self.insets.top, width: self.bounds.width, height: max(0.0, self.bounds.height - self.insets.top - self.insets.bottom))
    }

    /// The identities of the rows on screen now (their frames meet the viewport).
    var visibleItemIdentities: Set<AnyHashable> {
        let viewport = self.viewport
        var result = Set<AnyHashable>()
        for row in self.visibleRowFrames() where row.index < self.items.count && row.frame.intersects(viewport) {
            result.insert(self.items[row.index].identity)
        }
        return result
    }

    /// Loaded rows and their frames: on screen now, or where a programmatic scroll will leave them (`settled`).
    func visibleRowFrames(settled: Bool = false) -> [(index: Int, frame: CGRect)] {
        guard let range = self.coreList.loadedIndexRange else {
            return []
        }
        var result: [(index: Int, frame: CGRect)] = []
        for index in range.first ... range.last {
            if let view = self.coreList.loadedItemView(at: index) {
                result.append((index, settled ? self.coreList.settledFrame(of: view) : self.coreList.presentedFrame(of: view)))
            }
        }
        return result
    }

    func scroll(toIndex index: Int, pointOffset: CGFloat, transition: CoreListTransition) {
        guard index >= 0, index < self.items.count else {
            return
        }
        self.withSynchronousRowLoading {
            self.coreList.applyChanges(scrollTo: CoreListScrollTarget(index: index, pointOffset: pointOffset), transition: transition)
        }
        self.onScrollOffsetChanged?(self.scrollOffset(settled: true), transition)
        self.onProgrammaticScroll?()
    }

    func scrollToTop() {
        // The default spring: at 0.5 s CoreList and ComponentFlow emit the same system spring, so the header,
        // which unfolds on the pass's transition, keeps pace. ComponentFlow has no UIKit smooth deceleration.
        self.scroll(toIndex: 0, pointOffset: 0.0, transition: .spring(duration: 0.5))
    }
}
