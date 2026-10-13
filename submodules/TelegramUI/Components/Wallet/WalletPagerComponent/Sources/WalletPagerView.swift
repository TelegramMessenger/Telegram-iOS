import Foundation
import UIKit
import ComponentFlow
import Display
import ViewControllerComponent

public final class WalletPagerView: UIView, UIScrollViewDelegate, ComponentTaggedView {
    public typealias EnvironmentType = ViewControllerComponentContainer.Environment

    public final class Tag {
        public init() {
        }
    }

    public final class ItemPosition {
        public private(set) var offset: CGFloat = 0.0
        public private(set) var isVisible = false
        /// A reset rebases motion after data/layout changes, rather than imparting velocity.
        public var updated: ((_ reset: Bool) -> Void)?

        fileprivate func update(offset: CGFloat, isVisible: Bool, reset: Bool) {
            let changed = self.isVisible != isVisible || (isVisible && self.offset != offset)
            self.offset = offset
            self.isVisible = isVisible
            if changed || reset {
                self.updated?(reset)
            }
        }
    }

    public func matches(tag: Any) -> Bool {
        return tag is Tag
    }

    private let dimView: UIView
    private var isDimHidden = false
    private let scrollView: UIScrollView
    private var itemViews: [String: ComponentHostView<EnvironmentType>] = [:]
    private var itemPositions: [String: ItemPosition] = [:]
    private var pagerState = WalletPagerState()
    private var environment: Environment<EnvironmentType>?
    private var makeContent: ((Int, Bool) -> AnyComponent<EnvironmentType>)?
    private var indexUpdated: ((Int) -> Void)?
    private var draggingBegan: ((Int) -> Void)?
    private var previousIsDisplaying = false
    private var currentItemId: String?
    private var isUpdating = false
    private var ignoreContentOffsetChange = false
    private var isSwiping = false

    public override init(frame: CGRect) {
        self.dimView = UIView()
        self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)

        self.scrollView = UIScrollView(frame: frame)
        self.scrollView.clipsToBounds = true
        self.scrollView.isPagingEnabled = true
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = true
        self.scrollView.bounces = true
        self.scrollView.layer.cornerRadius = 10.0
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }

        super.init(frame: frame)

        self.addSubview(self.dimView)
        self.scrollView.delegate = self
        self.addSubview(self.scrollView)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        self.updateItemPositions(reset: true)
    }

    public func itemPosition(for id: String) -> ItemPosition? {
        if let position = self.itemPositions[id] {
            return position
        }
        guard self.pagerState.index(forId: id) != nil else { return nil }
        let position = ItemPosition()
        self.itemPositions[id] = position
        self.updateItemPosition(position, id: id, reset: true)
        return position
    }

    private func updateItemPosition(_ position: ItemPosition, id: String, reset: Bool) {
        let layout = self.pagerState.layout
        guard layout.isValid, let index = self.pagerState.index(forId: id) else {
            position.update(offset: 0.0, isVisible: false, reset: true)
            return
        }
        let isVisible = self.window != nil && self.environment?[EnvironmentType.self].value.isVisible == true
            && layout.itemFrame(at: index).intersects(self.scrollView.bounds)
        position.update(offset: CGFloat(index) * layout.itemStride - self.scrollView.contentOffset.x,
                        isVisible: isVisible, reset: reset)
    }

    private func updateItemPositions(reset: Bool) {
        for (id, position) in self.itemPositions {
            self.updateItemPosition(position, id: id, reset: reset)
        }
    }

    public func setDimHidden(_ hidden: Bool, animated: Bool) {
        self.isDimHidden = hidden
        let transition: ComponentTransition
        if animated {
            transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .linear))
        } else {
            transition = .immediate
        }
        transition.setAlpha(view: self.dimView, alpha: hidden ? 0.0 : 1.0)
    }

    private func reportCurrentIndex() {
        guard !self.pagerState.itemIds.isEmpty, self.pagerState.layout.isValid else {
            return
        }
        let index = self.pagerState.layout.currentIndex(at: self.scrollView.contentOffset.x)
        self.indexUpdated?(index)
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard !self.pagerState.itemIds.isEmpty, self.pagerState.layout.isValid else {
            return
        }
        self.isSwiping = true
        self.draggingBegan?(self.pagerState.layout.currentIndex(at: scrollView.contentOffset.x))
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.finishScrolling()
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.finishScrolling()
    }

    private func finishScrolling() {
        guard self.isSwiping else {
            return
        }
        self.isSwiping = false
        let wasUpdating = self.isUpdating
        self.isUpdating = true
        self.updatePages(transition: .immediate)
        self.isUpdating = wasUpdating
        self.reportCurrentIndex()
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !self.ignoreContentOffsetChange, !self.isUpdating else {
            return
        }
        self.isUpdating = true
        // Prepared pages move with the scroll view without any component updates.
        // A long or interrupted gesture may expose a page outside the prepared set.
        for index in self.pagerState.layout.visibleIndices(at: scrollView.contentOffset.x) {
            if self.itemViews[self.pagerState.itemIds[index]] == nil {
                self.updatePage(at: index, transition: .immediate)
            }
        }
        self.updateItemPositions(reset: false)
        self.isUpdating = false
    }

    private func updatePage(at index: Int, transition: ComponentTransition) {
        guard let environment = self.environment, let makeContent = self.makeContent else {
            return
        }
        let layout = self.pagerState.layout
        let id = self.pagerState.itemIds[index]
        let itemView: ComponentHostView<EnvironmentType>
        var itemTransition = transition
        if let current = self.itemViews[id] {
            itemView = current
        } else {
            itemTransition = transition.withAnimation(.none)
            itemView = ComponentHostView<EnvironmentType>()
            self.itemViews[id] = itemView
            self.scrollView.addSubview(itemView)
        }

        let _ = itemView.update(
            transition: itemTransition,
            component: makeContent(index, id == self.currentItemId),
            environment: { environment[EnvironmentType.self] },
            containerSize: layout.size
        )
        itemView.frame = layout.itemFrame(at: index)
    }

    private func updatePages(transition: ComponentTransition) {
        let layout = self.pagerState.layout
        let offset = self.scrollView.contentOffset.x
        if !self.isSwiping, layout.isValid, !self.pagerState.itemIds.isEmpty {
            self.currentItemId = self.pagerState.itemIds[layout.currentIndex(at: offset)]
        }

        var indices = Set(self.isSwiping ? layout.visibleIndices(at: offset) : layout.preloadedIndices(at: offset))
        if self.isSwiping, layout.isValid {
            // External data and layout changes still update retained pages in place.
            // Keep the same presentation owner until the gesture has finished.
            for id in self.itemViews.keys {
                if let index = self.pagerState.index(forId: id) {
                    indices.insert(index)
                }
            }
        }
        var validIds = Set<String>()
        for index in indices.sorted() {
            validIds.insert(self.pagerState.itemIds[index])
            self.updatePage(at: index, transition: transition)
        }

        var removeIds: [String] = []
        for (id, itemView) in self.itemViews where !validIds.contains(id) {
            removeIds.append(id)
            itemView.removeFromSuperview()
        }
        for id in removeIds {
            self.itemViews.removeValue(forKey: id)
            if let position = self.itemPositions.removeValue(forKey: id) {
                position.update(offset: position.offset, isVisible: false, reset: true)
                position.updated = nil
            }
        }
    }

    public func update(
        itemIds: [String],
        initialIndex: Int,
        itemSpacing: CGFloat,
        availableSize: CGSize,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition,
        makeContent: @escaping (Int, Bool) -> AnyComponent<EnvironmentType>,
        indexUpdated: @escaping (Int) -> Void,
        draggingBegan: @escaping (Int) -> Void
    ) -> CGSize {
        let wasUpdating = self.isUpdating
        var shouldReportIndex = false
        self.isUpdating = true
        defer {
            self.isUpdating = wasUpdating
            if shouldReportIndex {
                self.reportCurrentIndex()
            }
        }

        let wasInitialized = self.pagerState.isInitialized
        let rebasePositions = self.pagerState.itemIds != itemIds
            || self.pagerState.layout.size != availableSize || self.pagerState.layout.itemSpacing != itemSpacing
        let previousOffset = self.scrollView.contentOffset.x
        let targetOffset = self.pagerState.update(
            itemIds: itemIds,
            initialIndex: initialIndex,
            size: availableSize,
            itemSpacing: itemSpacing,
            offset: self.scrollView.contentOffset.x,
            isSwiping: self.isSwiping
        )
        self.environment = environment
        self.makeContent = makeContent
        self.indexUpdated = indexUpdated
        self.draggingBegan = draggingBegan

        transition.setFrame(view: self.dimView, frame: CGRect(origin: .zero, size: availableSize))
        let layout = self.pagerState.layout
        if self.scrollView.contentSize != layout.contentSize {
            self.scrollView.contentSize = layout.contentSize
        }
        if self.scrollView.frame != layout.scrollFrame {
            self.scrollView.frame = layout.scrollFrame
        }
        if self.scrollView.contentOffset != CGPoint(x: targetOffset, y: 0.0) {
            self.ignoreContentOffsetChange = true
            self.scrollView.contentOffset = CGPoint(x: targetOffset, y: 0.0)
            self.ignoreContentOffsetChange = false
        }
        self.updateItemPositions(reset: rebasePositions || previousOffset != targetOffset)
        self.updatePages(transition: transition)

        if !self.isDimHidden {
            if let _ = transition.userData(ViewControllerComponentContainer.AnimateInTransition.self) {
                self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            } else if self.previousIsDisplaying,
                      let _ = transition.userData(ViewControllerComponentContainer.AnimateOutTransition.self) {
                self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
        }
        self.previousIsDisplaying = environment[EnvironmentType.self].value.isVisible

        shouldReportIndex = !wasInitialized && self.pagerState.isInitialized
        return availableSize
    }
}
