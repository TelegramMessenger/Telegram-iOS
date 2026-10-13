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

    // Main-thread physics for now, rather than the render-server keyframe flights the chat uses.
    let coreList = CoreVirtualListView(forEmbedding: CGRect(), deceleration: .stepped)
    private let refreshIndicator = UIActivityIndicatorView(style: .medium)
    private let skeletonView = NewsFeedSkeletonView()
    private var showsSkeleton = false
    private var skeletonParameters: (theme: PresentationTheme, rowLayout: NewsFeedSkeletonRowLayout)?
    private(set) var items: [CoreListComponentItem] = []
    private(set) var insets = UIEdgeInsets()
    private var isRefreshing = false

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
        // Over the rows, under the pull-to-refresh indicator.
        self.skeletonView.isHidden = true
        self.addSubview(self.skeletonView)
        self.refreshIndicator.hidesWhenStopped = false
        self.refreshIndicator.alpha = 0.0
        self.addSubview(self.refreshIndicator)

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
            self.updateRefreshIndicator()
            self.layoutSkeleton()
        }
        self.coreList.didEndDragging = { [weak self] in
            guard let self else {
                return
            }
            if self.isPullToRefreshEnabled, !self.isRefreshing, self.coreList.overscrollDistance <= -70.0 {
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

    func updateTheme(indicatorColor: UIColor) {
        self.refreshIndicator.color = indicatorColor
    }

    func update(size: CGSize, insets: UIEdgeInsets, items: [CoreListComponentItem], scrollTo: CoreListScrollTarget?, anchorMode: CoreListAnchorMode, transition: CoreListTransition) {
        self.coreList.frame = CGRect(origin: CGPoint(), size: size)
        self.items = items
        self.insets = insets
        self.coreList.applyChanges(items: items, newSize: size, newInsets: insets, scrollTo: scrollTo, anchorMode: anchorMode, transition: transition)
        // A programmatic pass fires no scroll callback: report the settled offset.
        self.onScrollOffsetChanged?(self.scrollOffset(settled: true), transition)
        self.layoutRefreshIndicator()
        self.layoutSkeleton()
        if scrollTo != nil {
            self.onProgrammaticScroll?()
        }
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
        self.coreList.applyChanges(scrollTo: CoreListScrollTarget(index: index, pointOffset: pointOffset), transition: transition)
        self.onScrollOffsetChanged?(self.scrollOffset(settled: true), transition)
        self.onProgrammaticScroll?()
    }

    func scrollToTop() {
        // The default spring: at 0.5 s CoreList and ComponentFlow emit the same system spring, so the header,
        // which unfolds on the pass's transition, keeps pace. ComponentFlow has no UIKit smooth deceleration.
        self.scroll(toIndex: 0, pointOffset: 0.0, transition: .spring(duration: 0.5))
    }

    func setRefreshing(_ value: Bool) {
        self.isRefreshing = value
        self.updateRefreshIndicator()
    }

    private func updateRefreshIndicator() {
        let pull = max(0.0, -self.coreList.overscrollDistance)
        let alpha: CGFloat
        if self.isRefreshing {
            alpha = 1.0
        } else if self.isPullToRefreshEnabled {
            alpha = min(1.0, pull / 70.0)
        } else {
            alpha = 0.0
        }
        self.refreshIndicator.alpha = alpha
        if alpha > 0.0 {
            if !self.refreshIndicator.isAnimating {
                self.refreshIndicator.startAnimating()
            }
        } else if self.refreshIndicator.isAnimating {
            self.refreshIndicator.stopAnimating()
        }
        self.layoutRefreshIndicator()
    }

    private func layoutRefreshIndicator() {
        let pull = max(0.0, -self.coreList.overscrollDistance)
        let size = CGSize(width: 20.0, height: 20.0)
        self.refreshIndicator.frame = CGRect(origin: CGPoint(x: floor((self.bounds.width - size.width) * 0.5), y: self.insets.top + max(8.0, floor((pull - size.height) * 0.5))), size: size)
    }
}
