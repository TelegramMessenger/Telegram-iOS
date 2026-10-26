import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import AccountContext
import TelegramPresentationData
import ViewControllerComponent
import PeerListItemComponent
import SwiftSignalKit
import EdgeEffect
import ResizableSheetComponent
import HorizontalTabsComponent
import NavigationStackComponent
import TooltipUI
import TelegramNotices

final class ShareScreenContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    let model: ShareScreenState
    let revision: Int
    let height: CGFloat
    let bottomInset: CGFloat
    let select: (EnginePeer) -> Void
    let story: (() -> Void)?
    let createGroup: () -> Void
    let boundsUpdated: ActionSlot<ResizableSheetComponentEnvironment.BoundsUpdate>
    let layoutApplied: ActionSlot<Void>
    let isLoading: Bool
    let header: AnyComponentWithIdentity<Empty>?

    init(model: ShareScreenState, height: CGFloat, bottomInset: CGFloat, isLoading: Bool, header: AnyComponentWithIdentity<Empty>? = nil, select: @escaping (EnginePeer) -> Void, story: (() -> Void)?, createGroup: @escaping () -> Void, boundsUpdated: ActionSlot<ResizableSheetComponentEnvironment.BoundsUpdate>, layoutApplied: ActionSlot<Void>) {
        self.model = model
        self.revision = model.revision
        self.height = height
        self.bottomInset = bottomInset
        self.select = select
        self.story = story
        self.createGroup = createGroup
        self.boundsUpdated = boundsUpdated
        self.layoutApplied = layoutApplied
        self.isLoading = isLoading
        self.header = header
    }

    static func ==(lhs: ShareScreenContentComponent, rhs: ShareScreenContentComponent) -> Bool {
        return lhs.model === rhs.model && lhs.revision == rhs.revision && lhs.height == rhs.height && lhs.bottomInset == rhs.bottomInset && lhs.isLoading == rhs.isLoading && lhs.header == rhs.header
    }

    final class View: UIView, UIGestureRecognizerDelegate, UIScrollViewDelegate {
        private var topics = ComponentView<EnvironmentType>()
        private var community = ComponentView<EnvironmentType>()
        private let search = ComponentView<Empty>()
        private var header: ComponentView<Empty>?
        private var headerId: AnyHashable?
        private let searchContainer = UIView()
        private var outgoingSearchItems: UIView?
        private let mainContent = UIView()
        private var searchNavigation = ComponentView<EnvironmentType>()
        private var mainScrollOffset: CGFloat = 0.0
        private var communityScrollOffset: CGFloat = 0.0
        private var mainContentSize: CGSize = .zero
        private var communityContentSize: CGSize = .zero
        private var topicsContentSize: CGSize = .zero
        private let itemsContainer = UIView()
        private var visibleBounds = CGRect.zero
        private var contentHeight: CGFloat = 0.0
        private var topInset: CGFloat = 0.0
        private var headerInset: CGFloat = 0.0
        private var headerSize: CGSize = .zero
        private let topEdge = EdgeEffectView()
        private let gridItems = ShareScreenItemsView(frame: .zero)
        private let folderPager = UIScrollView()
        private var folderPan: InteractiveTransitionGestureRecognizer?
        private var folderPanStartOffset: CGFloat = 0.0
        private var folderPages: [Int32: ShareScreenItemsView] = [:]
        private var pagerIds: [Int32] = []
        private var pagerSelectedId: Int32?
        private var pagerIsUpdating = false
        private var isAnimatingPager = false
        private var component: ShareScreenContentComponent?
        private var environment: EnvironmentType?
        private var previousMode = false
        private var previousFilter: Int32 = 0
        private var previousQuery = ""
        private var isUpdating = false
        private var previousForumId: EnginePeer.Id?
        private var previousCommunityId: EnginePeer.Id?
        private var previousCommunityUsesGrid = false
        private var gridTransition: ShareScreenGridTransition?
        private var gridTransitionPrepared = false

        private func gridViews() -> [UIView] {
            if self.previousForumId != nil {
                return (self.topics.view as? ShareScreenTopicsComponent.View)?.transitionViews ?? []
            } else if self.previousCommunityId != nil {
                return (self.community.view as? ShareScreenCommunityComponent.View)?.transitionViews ?? []
            } else {
                return self.gridItems.visibleItems.values.compactMap { $0.view }
            }
        }

        private func gridView(peerId: EnginePeer.Id) -> UIView? {
            if self.previousCommunityId != nil {
                return (self.community.view as? ShareScreenCommunityComponent.View)?.transitionView(peerId: peerId)
            }
            return self.gridItems.visibleItems["grid-\(peerId)"]?.view
        }

        private func prepareGridTransition(model: ShareScreenState, transition: ComponentTransition) {
            let forumId = model.forumPeer?.id
            let communityId = model.communityPeer?.id
            guard forumId != self.previousForumId || communityId != self.previousCommunityId else { return }
            if !self.gridTransitionPrepared || model.isSearching || transition.animation.isImmediate {
                self.gridTransition?.cancel()
                self.gridTransition = nil
            }
            self.gridTransitionPrepared = false
            self.previousForumId = forumId
            self.previousCommunityId = communityId
            self.previousCommunityUsesGrid = model.communityUsesGrid
        }

        func makeAccountSwitchOutgoingItems(in container: UIView) {
            guard self.component?.model.isSearching == false, self.component?.model.forumPeer == nil, self.component?.model.communityPeer == nil else { return }
            let visibleRect = container.convert(self.visibleBounds, from: self)
            let views = self.gridItems.visibleItems.values.compactMap { $0.view }
            let topY = views.map { $0.convert($0.bounds, to: container).minY }.min() ?? 0.0
            for view in views {
                let frame = view.convert(view.bounds, to: container)
                guard frame.intersects(visibleRect) else { continue }
                view.layer.removeAllAnimations()
                container.addSubview(view)
                view.frame = frame
                let row = max(0.0, floor((frame.minY - topY + 1.0) / 100.0))
                let delay = row * 0.04
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: delay, removeOnCompletion: false, completion: { [weak view] _ in
                    view?.removeFromSuperview()
                })
                view.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 26.0), duration: 0.3, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.6, 0.0, 0.8, 0.4), removeOnCompletion: false, additive: true)
            }
            self.gridItems.visibleItems.removeAll()
        }

        func scatterItems(into container: UIView) {
            let views: [UIView]
            if self.component?.model.isSearching == true {
                views = (self.folderPages[self.pagerSelectedId ?? 0]?.visibleItems.values.compactMap { $0.view } ?? [])
            } else {
                views = self.gridViews()
            }
            let center = container.convert(CGPoint(x: self.bounds.midX, y: self.visibleBounds.midY), from: self)
            let visibleRect = container.convert(self.visibleBounds, from: self)
            let outgoing = UIView(frame: container.bounds)
            outgoing.isUserInteractionEnabled = false
            container.addSubview(outgoing)
            for view in views {
                let frame = view.convert(view.bounds, to: container)
                guard frame.intersects(visibleRect), let snapshot = view.snapshotView(afterScreenUpdates: false) else { continue }
                snapshot.frame = frame
                outgoing.addSubview(snapshot)
                let position = snapshot.center
                let destination = CGPoint(x: position.x + (position.x - center.x) * 2.8, y: position.y + (position.y - center.y) * 2.8)
                snapshot.layer.animatePosition(from: position, to: destination, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                snapshot.layer.animateScale(from: 1.0, to: 1.35, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            }
            outgoing.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak outgoing] _ in
                outgoing?.removeFromSuperview()
            })
            self.setItemsHidden(true)
        }

        func setItemsHidden(_ hidden: Bool) {
            for view in [self.itemsContainer, self.topics.view, self.community.view].compactMap({ $0 }) {
                view.alpha = hidden ? 0.0 : 1.0
            }
        }

        private func runGridTransition() {
            guard let animation = self.gridTransition, !animation.isCompleted else { return }
            animation.animate(in: self, views: self.gridViews(), targetView: self.gridView(peerId: animation.peerId), visibleBounds: self.visibleBounds)
        }

        private func updateSearchNavigation(transition: ComponentTransition) -> CGSize {
            guard let component = self.component, let environment = self.environment else { return .zero }
            let model = component.model
            var pages: [AnyComponentWithIdentity<EnvironmentType>] = []
            func append(_ id: String, view: UIView, size: CGSize, scrollOffset: CGFloat, active: Bool) {
                pages.append(AnyComponentWithIdentity(id: id, component: AnyComponent(ShareScreenNavigationPage(
                    content: view, size: size, offset: active ? 0.0 : self.visibleBounds.minY - scrollOffset,
                    backgroundColor: environment.theme.list.modalPlainBackgroundColor
                ))))
            }
            append("search", view: self.mainContent, size: self.mainContentSize, scrollOffset: self.mainScrollOffset, active: model.communityPeer == nil && model.forumPeer == nil)
            if let peer = model.communityPeer, let view = self.community.view {
                append("community-\(peer.id)", view: view, size: self.communityContentSize, scrollOffset: self.communityScrollOffset, active: model.forumPeer == nil)
            }
            if let peer = model.forumPeer, let view = self.topics.view {
                append("forum-\(peer.id)", view: view, size: self.topicsContentSize, scrollOffset: 0.0, active: true)
            }
            let size = self.searchNavigation.update(transition: transition, component: AnyComponent(NavigationStackComponent(
                items: pages, clipContent: false, requestPop: { [weak model] in
                    guard let model else { return }
                    if model.forumPeer != nil { model.closeForum() }
                    else if model.communityPeer != nil { model.closeCommunity() }
                }
            )), environment: { environment }, containerSize: CGSize(width: self.bounds.width, height: component.height))
            if let view = self.searchNavigation.view {
                if view.superview == nil { self.addSubview(view) }
                view.frame = CGRect(origin: .zero, size: size)
            }
            return size
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.mainContent)
            self.mainContent.addSubview(self.itemsContainer)
            self.topEdge.isUserInteractionEnabled = false
            self.mainContent.addSubview(self.topEdge)
            self.mainContent.addSubview(self.searchContainer)
            self.itemsContainer.addSubview(self.gridItems)
            self.itemsContainer.addSubview(self.folderPager)
            self.folderPager.delegate = self
            self.folderPager.isPagingEnabled = true
            self.folderPager.isScrollEnabled = false
            self.folderPager.isDirectionalLockEnabled = true
            self.folderPager.alwaysBounceHorizontal = true
            self.folderPager.alwaysBounceVertical = false
            self.folderPager.showsHorizontalScrollIndicator = false
            self.folderPager.showsVerticalScrollIndicator = false
            self.folderPager.contentInsetAdjustmentBehavior = .never
            let folderPan = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.folderPanGesture(_:)), allowedDirections: { [weak self] point in
                guard let self, let model = self.component?.model, model.isSearching, model.forumPeer == nil, model.communityPeer == nil else { return [] }
                if model.filterId == 0 && model.query.isEmpty && point.y < 110.0 { return [] }
                return [.left, .right]
            })
            folderPan.delegate = self
            self.itemsContainer.addGestureRecognizer(folderPan)
            self.folderPan = folderPan
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if otherGestureRecognizer is InteractiveTransitionGestureRecognizer { return false }
            return otherGestureRecognizer is UIPanGestureRecognizer
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }

        @objc private func folderPanGesture(_ recognizer: InteractiveTransitionGestureRecognizer) {
            let width = self.folderPager.bounds.width
            guard width > 0.0, !self.pagerIds.isEmpty else { return }
            switch recognizer.state {
            case .began:
                self.stopPagerAnimation()
                self.folderPanStartOffset = self.folderPager.contentOffset.x
            case .changed:
                var offset = self.folderPanStartOffset - recognizer.translation(in: self.itemsContainer).x
                let maxOffset = CGFloat(self.pagerIds.count - 1) * width
                if offset < 0.0 { offset *= 0.25 }
                if offset > maxOffset { offset = maxOffset + (offset - maxOffset) * 0.25 }
                self.folderPager.setContentOffset(CGPoint(x: offset, y: 0.0), animated: false)
            case .ended, .cancelled:
                let startIndex = Int(round(self.folderPanStartOffset / width))
                let velocity = recognizer.velocity(in: self.itemsContainer).x
                var index = Int(round(self.folderPager.contentOffset.x / width))
                if recognizer.state == .cancelled {
                    index = startIndex
                } else if abs(velocity) > 300.0 {
                    index = startIndex + (velocity < 0.0 ? 1 : -1)
                }
                self.animatePager(toIndex: max(0, min(self.pagerIds.count - 1, index)))
            default:
                break
            }
        }

        private func updateFolderPages(transition: ComponentTransition) {
            guard let component = self.component, let environment = self.environment else { return }
            let model = component.model
            let ids: [Int32] = [0] + model.filters.map(\.id).filter { $0 != 0 }
            let width = self.bounds.width
            guard width > 0.0, let selectedIndex = ids.firstIndex(of: model.filterId) else { return }
            self.pagerIsUpdating = true
            defer { self.pagerIsUpdating = false }
            let idsChanged = self.pagerIds != ids
            self.pagerIds = ids
            if idsChanged || self.pagerSelectedId != model.filterId || self.folderPager.bounds.width != width {
                self.pagerSelectedId = model.filterId
                self.folderPager.setContentOffset(CGPoint(x: CGFloat(selectedIndex) * width, y: 0.0), animated: false)
            }
            let offsetIndex = self.folderPager.contentOffset.x / width
            var indices = Set([selectedIndex])
            for index in (Int(floor(offsetIndex)) - 1)...(Int(ceil(offsetIndex)) + 1) where ids.indices.contains(index) { indices.insert(index) }
            var valid = Set<Int32>()
            for index in indices {
                let id = ids[index]
                valid.insert(id)
                let page = self.folderPages[id] ?? ShareScreenItemsView(frame: .zero)
                self.folderPages[id] = page
                if page.superview == nil { self.folderPager.addSubview(page) }
                let data = model.folderPage(id)
                // A neighboring folder starts beneath the pinned header even
                // when the current folder has been scrolled far down.
                let pageOffset = id == model.filterId ? 0.0 : max(0.0, self.visibleBounds.minY)
                page.update(component: component, environment: environment, availableWidth: width, visibleBounds: self.visibleBounds.offsetBy(dx: 0.0, dy: -self.topInset - pageOffset), peers: data.peers, filterId: id, isLoading: data.isLoading, transition: transition)
                page.frame.origin = CGPoint(x: CGFloat(index) * width, y: pageOffset)
            }
            for id in Array(self.folderPages.keys) where !valid.contains(id) { self.folderPages.removeValue(forKey: id)?.removeFromSuperview() }
            let pageHeight = self.folderPages[model.filterId]?.contentHeight ?? component.height
            self.contentHeight = self.topInset + pageHeight
            let pagerHeight = max(pageHeight, component.height - self.topInset, self.visibleBounds.maxY - self.topInset)
            self.folderPager.frame = CGRect(x: 0.0, y: 0.0, width: width, height: pagerHeight)
            let contentSize = CGSize(width: CGFloat(ids.count) * width, height: pagerHeight)
            if self.folderPager.contentSize != contentSize { self.folderPager.contentSize = contentSize }
        }

        private func navigateToFolder(_ id: Int32) {
            guard let index = self.pagerIds.firstIndex(of: id), self.folderPager.bounds.width > 0.0 else { return }
            self.stopPagerAnimation()
            self.animatePager(toIndex: index)
        }

        private func animatePager(toIndex index: Int) {
            let width = self.folderPager.bounds.width
            guard width > 0.0, self.pagerIds.indices.contains(index) else { return }
            let source = self.folderPager.contentOffset
            let target = CGPoint(x: CGFloat(index) * width, y: 0.0)
            guard source != target else {
                self.finishPaging()
                return
            }
            let transition: ComponentTransition = .spring(duration: 0.4)
            self.pagerIsUpdating = true
            self.folderPager.setContentOffset(target, animated: false)
            self.pagerIsUpdating = false
            self.updateFolderPages(transition: .immediate)
            (self.search.view as? SearchInputPanelComponent.View)?.updateTabSwitchFraction(0.0, selectedTab: self.pagerIds[index], isDragging: false, transition: transition)
            self.isAnimatingPager = true
            transition.animateBoundsOrigin(view: self.folderPager, from: CGPoint(x: source.x - target.x, y: 0.0), to: .zero, additive: true, completion: { [weak self] finished in
                guard let self, finished, self.isAnimatingPager else { return }
                self.isAnimatingPager = false
                self.finishPaging()
            })
        }

        private func stopPagerAnimation() {
            guard self.isAnimatingPager else { return }
            self.isAnimatingPager = false
            let offset = self.folderPager.layer.presentation()?.bounds.origin ?? self.folderPager.contentOffset
            self.folderPager.layer.removeAllAnimations()
            self.pagerIsUpdating = true
            self.folderPager.setContentOffset(offset, animated: false)
            self.pagerIsUpdating = false
            self.updateFolderPages(transition: .immediate)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !self.pagerIsUpdating, !self.isUpdating, let model = self.component?.model, model.isSearching, self.bounds.width > 0.0 else { return }
            self.updateFolderPages(transition: .immediate)
            if !self.pagerIds.isEmpty {
                let position = scrollView.contentOffset.x / self.bounds.width
                let index = max(0, min(self.pagerIds.count - 1, Int(floor(position))))
                (self.search.view as? SearchInputPanelComponent.View)?.updateTabSwitchFraction(CGFloat(index) - position, selectedTab: self.pagerIds[index], isDragging: self.folderPan?.state == .changed)
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { self.finishPaging() }
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { if !decelerate { self.finishPaging() } }
        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { self.finishPaging() }
        private func finishPaging() {
            guard let model = self.component?.model, model.isSearching, self.bounds.width > 0.0, !self.pagerIds.isEmpty else { return }
            let index = max(0, min(self.pagerIds.count - 1, Int(round(self.folderPager.contentOffset.x / self.bounds.width))))
            self.pagerSelectedId = self.pagerIds[index]
            model.selectFilter(self.pagerIds[index])
            (self.search.view as? SearchInputPanelComponent.View)?.updateTabSwitchFraction(0.0, selectedTab: nil, isDragging: false)
        }

        private func updateVisibleBounds(_ bounds: CGRect) {
            self.visibleBounds = bounds
            defer {
                if !self.isUpdating, self.component?.model.isSearching == true {
                    let _ = self.updateSearchNavigation(transition: .immediate)
                }
            }
            guard !self.isUpdating, let component = self.component else { return }
            if component.model.forumPeer != nil {
                (self.topics.view as? ShareScreenTopicsComponent.View)?.updateVisibleBounds(bounds)
                return
            } else if component.model.communityPeer != nil {
                (self.community.view as? ShareScreenCommunityComponent.View)?.updateVisibleBounds(bounds)
                return
            }
            self.isUpdating = true
            self.updatePinnedSearch(transition: .immediate)
            self.updateItems(transition: .immediate)
            self.isUpdating = false
        }

        private func updatePinnedSearch(transition: ComponentTransition) {
            guard let environment = self.environment else { return }
            let y = max(0.0, self.visibleBounds.minY)
            // Scrolling moves the pinned container, without cancelling the
            // search field's independent animation between header layouts.
            self.searchContainer.frame.origin = CGPoint(x: 0.0, y: y)
            let frame = CGRect(x: 0.0, y: y, width: self.bounds.width, height: self.topInset + 16.0)
            transition.setFrame(view: self.topEdge, frame: frame)
            self.topEdge.update(content: environment.theme.list.modalPlainBackgroundColor, blur: true, alpha: 1.0, rect: CGRect(origin: .zero, size: frame.size), edge: .top, edgeSize: frame.height, transition: transition)
        }

        private func updateItems(transition: ComponentTransition) {
            guard let component = self.component, let environment = self.environment else { return }
            let model = component.model
            let itemsTop = self.topInset + (model.isSearching ? 0.0 : self.headerInset)
            let visible = self.visibleBounds.offsetBy(dx: 0.0, dy: -itemsTop)
            self.gridItems.isHidden = model.isSearching
            self.folderPager.isHidden = !model.isSearching
            if model.isSearching {
                self.updateFolderPages(transition: transition)
            } else {
                self.gridItems.update(component: component, environment: environment, availableWidth: self.bounds.width, visibleBounds: visible, peers: model.gridPeers, filterId: 0, isLoading: model.isLoading, transition: transition)
                self.gridItems.frame.origin = .zero
                self.contentHeight = itemsTop + self.gridItems.contentHeight
            }
            self.itemsContainer.frame = CGRect(x: 0.0, y: itemsTop, width: self.bounds.width, height: max(self.contentHeight - itemsTop, component.height - itemsTop))
        }

        func update(component: ShareScreenContentComponent, availableSize: CGSize, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            self.prepareGridTransition(model: component.model, transition: transition)
            self.component = component
            component.model.navigationWillChange = { [weak self] peerId, opening in
                guard let self, let model = self.component?.model else { return }
                self.gridTransition?.cancel()
                self.gridTransition = nil
                self.gridTransitionPrepared = true
                if model.isSearching {
                    if opening {
                        if model.communityPeer != nil { self.communityScrollOffset = self.visibleBounds.minY }
                        else { self.mainScrollOffset = self.visibleBounds.minY }
                    }
                    return
                }
                guard self.previousCommunityId == nil || self.previousCommunityUsesGrid else { return }
                self.gridTransition = ShareScreenGridTransition(
                    opening: opening, peerId: peerId, views: self.gridViews(),
                    sourceView: opening ? self.gridView(peerId: peerId) : nil,
                    contentView: self, visibleBounds: self.visibleBounds
                )
                if self.previousForumId == nil && self.previousCommunityId == nil {
                    for item in self.gridItems.visibleItems.values where item.view?.superview === self.gridItems {
                        item.view?.removeFromSuperview()
                    }
                    self.gridItems.visibleItems.removeAll()
                }
            }
            component.boundsUpdated.connect { [weak self] update in self?.updateVisibleBounds(update.contentBounds) }
            component.layoutApplied.connect { [weak self] _ in self?.runGridTransition() }
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            let model = component.model
            let size = CGSize(width: availableSize.width, height: component.height)
            self.bounds.size.width = size.width
            if self.visibleBounds.isEmpty { self.visibleBounds = CGRect(origin: .zero, size: size) }
            let showingTopics = model.forumPeer != nil
            let showingCommunity = model.communityPeer != nil && !showingTopics
            self.itemsContainer.isHidden = !model.isSearching && (showingTopics || showingCommunity)
            self.topEdge.isHidden = !model.isSearching && (showingTopics || showingCommunity)
            if !showingCommunity && !(model.isSearching && model.communityPeer != nil), let view = self.community.view {
                if !model.isSearching { view.removeFromSuperview() }
                self.community = ComponentView<EnvironmentType>()
            }
            if !showingTopics, let view = self.topics.view {
                if !model.isSearching { view.removeFromSuperview() }
                self.topics = ComponentView<EnvironmentType>()
            }
            if !model.isSearching && (showingTopics || showingCommunity) {
                for item in self.gridItems.visibleItems.values { item.view?.removeFromSuperview() }
                self.gridItems.visibleItems.removeAll()
            }
            let modeChanged = self.previousMode != model.isSearching
            if modeChanged {
                if !model.isSearching {
                    self.folderPager.setContentOffset(self.folderPager.contentOffset, animated: false)
                    (self.search.view as? SearchInputPanelComponent.View)?.updateTabSwitchFraction(0.0, selectedTab: nil, isDragging: false)
                }
                self.outgoingSearchItems?.removeFromSuperview()
                self.outgoingSearchItems = nil
                if !transition.animation.isImmediate {
                    let rect = self.itemsContainer.convert(self.visibleBounds, from: self).intersection(self.itemsContainer.bounds)
                    if !rect.isEmpty, let snapshot = self.itemsContainer.resizableSnapshotView(from: rect, afterScreenUpdates: false, withCapInsets: .zero) {
                        snapshot.frame = self.itemsContainer.convert(rect, to: self.mainContent)
                        snapshot.isUserInteractionEnabled = false
                        self.mainContent.insertSubview(snapshot, belowSubview: self.topEdge)
                        self.outgoingSearchItems = snapshot
                        transition.setBlur(layer: snapshot.layer, radius: 8.0)
                        transition.setAlpha(view: snapshot, alpha: 0.0, completion: { [weak self, weak snapshot] _ in
                            snapshot?.removeFromSuperview()
                            if self?.outgoingSearchItems === snapshot { self?.outgoingSearchItems = nil }
                        })
                    }
                }
                self.itemsContainer.alpha = 1.0
            }
            let contentTransition = transition
            if let header = component.header {
                let headerView: ComponentView<Empty>
                if let current = self.header, self.headerId == header.id {
                    headerView = current
                } else {
                    self.header?.view?.removeFromSuperview()
                    headerView = ComponentView<Empty>()
                    self.header = headerView
                    self.headerId = header.id
                }
                self.headerSize = headerView.update(transition: transition, component: header.component, environment: {}, containerSize: CGSize(width: availableSize.width - 32.0, height: 1000.0))
                if let view = headerView.view {
                    if view.superview == nil {
                        self.mainContent.insertSubview(view, belowSubview: self.topEdge)
                    }
                    let headerShown = !model.isSearching && !showingTopics && !showingCommunity && !component.isLoading
                    shareScreenSetFadeVisible(view, isVisible: headerShown, blurRadius: 8.0, transition: transition)
                    view.isUserInteractionEnabled = headerShown
                }
                self.headerInset = self.headerSize.height + 16.0
            } else {
                if let header = self.header {
                    header.view?.removeFromSuperview()
                    self.header = nil
                    self.headerId = nil
                }
                self.headerInset = 0.0
            }
            let searchY: CGFloat = model.isSearching ? 16.0 : 76.0
            var tabs: [HorizontalTabsComponent.Tab] = [HorizontalTabsComponent.Tab(
                id: Int32(0),
                content: .title(.init(text: environment.strings.ChatList_Tabs_All, entities: [], enableAnimations: false)),
                badge: nil,
                action: { [weak self] in self?.navigateToFolder(0) }
            )]
            for filter in model.filters {
                if case let .filter(id, title, _, _) = filter {
                    tabs.append(HorizontalTabsComponent.Tab(
                        id: id,
                        content: .title(.init(text: title.text, entities: title.entities, enableAnimations: title.enableAnimations)),
                        badge: nil,
                        action: { [weak self] in self?.navigateToFolder(id) }
                    ))
                }
            }
            let searchSize = self.search.update(transition: transition, component: AnyComponent(SearchInputPanelComponent(
                context: model.context, theme: environment.theme, strings: environment.strings, metrics: environment.metrics, safeInsets: .zero,
                groupPeers: model.selection.peers.filter { if case let .user(user) = $0 { return user.botInfo == nil && user.id != model.context.account.peerId }; return false },
                isVisible: true,
                isSearching: model.isSearching,
                tabs: tabs,
                selectedTab: model.filterId,
                activated: { [weak model] in
                    model?.setSearching(true)
                },
                createGroup: { [weak self] in
                    guard let self, let component = self.component else { return }
                    let _ = ApplicationSpecificNotice.incrementShareCreateGroupTooltip(accountManager: component.model.context.sharedContext.accountManager, count: 3).startStandalone()
                    component.createGroup()
                },
                groupTooltip: { [weak self] source in
                    guard let self, let model = self.component?.model else { return }
                    let accountManager = model.context.sharedContext.accountManager
                    let _ = (ApplicationSpecificNotice.getShareCreateGroupTooltip(accountManager: accountManager)
                    |> deliverOnMainQueue).startStandalone(next: { [weak self, weak source] count in
                        guard count < 3, let self, let source, source.window != nil, let environment = self.environment, let model = self.component?.model, let controller = environment.controller() else { return }
                        let _ = ApplicationSpecificNotice.incrementShareCreateGroupTooltip(accountManager: accountManager).startStandalone()
                        let sourceFrame = source.convert(source.bounds, to: controller.view)
                        let tooltip = TooltipScreen(account: model.context.account, sharedContext: model.context.sharedContext, text: .plain(text: environment.strings.ShareScreen_CreateGroupTooltip), style: .default, icon: nil, location: .point(sourceFrame.insetBy(dx: 0.0, dy: 2.0), .top), displayDuration: .custom(4.0), inset: 16.0, shouldDismissOnTouch: { _, _ in
                            return .dismiss(consume: false)
                        })
                        controller.present(tooltip, in: .current)
                    })
                },
                updated: { [weak model] query in model?.search(query) },
                cancel: { [weak model] in
                    model?.setSearching(false)
                }
            )), environment: {}, containerSize: CGSize(width: availableSize.width, height: 44.0))
            if let view = self.search.view {
                if view.superview == nil { self.searchContainer.addSubview(view) }
                let searchShown = (model.isSearching || (!showingTopics && !showingCommunity)) && !component.isLoading
                shareScreenSetFadeVisible(view, isVisible: searchShown, blurRadius: 8.0, transition: transition)
                self.searchContainer.isUserInteractionEnabled = searchShown
                self.searchContainer.accessibilityElementsHidden = !searchShown
                self.searchContainer.bounds.size = CGSize(width: searchSize.width, height: searchY + searchSize.height)
                if !model.isSearching || (!showingTopics && !showingCommunity) {
                    contentTransition.setFrame(view: view, frame: CGRect(x: 0.0, y: searchY, width: searchSize.width, height: searchSize.height))
                }
            }
            if showingTopics {
                let topicSize = self.topics.update(transition: ComponentTransition.immediate.withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: true)), component: AnyComponent(ShareScreenTopicsComponent(model: model, bottomInset: component.bottomInset)), environment: { environment }, containerSize: size)
                if let view = self.topics.view {
                    if view.superview == nil { self.addSubview(view) }
                    view.frame = CGRect(origin: .zero, size: topicSize)
                    (view as? ShareScreenTopicsComponent.View)?.updateVisibleBounds(self.visibleBounds)
                }
                self.topicsContentSize = CGSize(width: topicSize.width, height: max(component.height, topicSize.height))
                if model.isSearching { return self.updateSearchNavigation(transition: transition) }
                return self.topicsContentSize
            }
            if showingCommunity {
                let communitySize = self.community.update(transition: transition.withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: true)), component: AnyComponent(ShareScreenCommunityComponent(model: model, bottomInset: component.bottomInset, select: component.select)), environment: { environment }, containerSize: size)
                if let view = self.community.view {
                    if view.superview == nil { self.addSubview(view) }
                    view.frame = CGRect(origin: .zero, size: communitySize)
                    (view as? ShareScreenCommunityComponent.View)?.updateVisibleBounds(self.visibleBounds)
                }
                self.communityContentSize = communitySize
                if model.isSearching { return self.updateSearchNavigation(transition: transition) }
                return communitySize
            }
            self.topInset = searchY + searchSize.height + 8.0
            if !model.isSearching, let view = self.header?.view {
                contentTransition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: 16.0, y: self.topInset + 4.0), size: self.headerSize))
            }
            let resetOffset = self.previousMode != model.isSearching || self.previousFilter != model.filterId || self.previousQuery != model.query
            let itemsTransition = (resetOffset ? .immediate : transition).withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: true))
            self.previousMode = model.isSearching
            self.previousFilter = model.filterId
            self.previousQuery = model.query
            self.updateItems(transition: itemsTransition)
            self.updatePinnedSearch(transition: contentTransition)
            if modeChanged && !transition.animation.isImmediate {
                transition.animateAlpha(view: self.itemsContainer, from: 0.0, to: 1.0)
                ComponentTransition.immediate.setBlur(layer: self.itemsContainer.layer, radius: 8.0)
                transition.setBlur(layer: self.itemsContainer.layer, radius: 0.0)
            }
            if modeChanged && model.isSearching {
                Queue.mainQueue().justDispatch { [weak self] in
                    guard let self, let model = self.component?.model, model.isSearching, model.communityPeer == nil, model.forumPeer == nil else { return }
                    (self.search.view as? SearchInputPanelComponent.View)?.activateInput()
                }
            }
            self.mainContentSize = CGSize(width: size.width, height: max(model.isSearching ? component.height : 540.0, self.contentHeight))
            if model.isSearching { return self.updateSearchNavigation(transition: transition) }
            if self.mainContent.superview !== self { self.addSubview(self.mainContent) }
            self.mainContent.frame = CGRect(origin: .zero, size: self.mainContentSize)
            self.searchNavigation.view?.removeFromSuperview()
            self.searchNavigation = ComponentView<EnvironmentType>()
            return self.mainContentSize
        }
    }
    func makeView() -> View { return View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}
