import Foundation
import UIKit
import Display
import TelegramPresentationData
import CoreList
import CoreListComponentHost
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
    private var skeletonParameters: (theme: PresentationTheme, rowLayout: NewsFeedSkeletonRowLayout)?
    private(set) var items: [CoreListComponentItem] = []
    private(set) var insets = UIEdgeInsets()

    var isPullToRefreshEnabled = false
    var onEdgeReached: ((CoreListLoadedEdge) -> Void)?
    /// The offset to follow and how to follow it: the presented offset, `.immediate`, while the user scrolls;
    /// after a programmatic pass, its settled offset with the pass's own transition, since CoreList reports
    /// nothing while that pass animates or when it lands.
    var onScrollOffsetChanged: ((ScrollOffset, CoreListTransition) -> Void)?
    var onVisibleRowsChanged: (() -> Void)?
    var onPullToRefresh: (() -> Void)?
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
        }
        self.coreList.didEndDragging = { [weak self] in
            guard let self else {
                return
            }
            // A pull while a refresh runs is ignored by the feed itself.
            if self.isPullToRefreshEnabled, self.coreList.overscrollDistance <= -70.0 {
                self.onPullToRefresh?()
            }
        }
        self.coreList.didEndScrolling = { [weak self] in
            self?.onScrollingEnded?()
        }
        self.coreList.willBeginDragging = { [weak self] in
            self?.onWillBeginDragging?()
        }
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    func update(size: CGSize, insets: UIEdgeInsets, items: [CoreListComponentItem], scrollTo: CoreListScrollTarget?, anchorMode: CoreListAnchorMode, transition: CoreListTransition) {
        self.coreList.frame = CGRect(origin: CGPoint(), size: size)
        self.items = items
        self.insets = insets
        self.withSynchronousRowLoading {
            self.coreList.applyChanges(items: items, newSize: size, newInsets: insets, scrollTo: scrollTo, anchorMode: anchorMode, transition: transition)
        }
        // A programmatic pass fires no scroll callback: report the settled offset.
        self.onScrollOffsetChanged?(self.scrollOffset(settled: true), transition)
        self.layoutSkeleton()
        if scrollTo != nil {
            self.onProgrammaticScroll?()
        }
    }

    private func withSynchronousRowLoading(_ f: () -> Void) {
        let previous = self.rowLoading.isSynchronous
        self.rowLoading.isSynchronous = true
        f()
        self.rowLoading.isSynchronous = previous
    }

    /// Until the list's first content arrives a skeleton stands in for it, moving with the list's offset (an
    /// overscroll while there are no rows); when it arrives, the list fades in and the skeleton out.
    func setShowsSkeleton(_ value: Bool, theme: PresentationTheme, rowLayout: NewsFeedSkeletonRowLayout) {
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
            let duration: Double = 0.25
            self.coreList.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
            self.skeletonView.alpha = 0.0
            self.skeletonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, completion: { [weak self] _ in
                guard let self, !self.showsSkeleton else {
                    return
                }
                self.skeletonView.isHidden = true
            })
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

    func scrollOffset(settled: Bool) -> ScrollOffset {
        guard let range = self.coreList.loadedIndexRange, range.first == 0, let view = self.coreList.loadedItemView(at: 0) else {
            return .unknown
        }
        let frame = settled ? self.coreList.settledFrame(of: view) : self.coreList.presentedFrame(of: view)
        return .known(-(frame.minY - self.insets.top))
    }

    var viewport: CGRect {
        return CGRect(x: 0.0, y: self.insets.top, width: self.bounds.width, height: max(0.0, self.bounds.height - self.insets.top - self.insets.bottom))
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
