import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import TelegramCore
import TelegramPresentationData
import SearchUI
import SearchBarNode
import ChatListUI
import ChatListHeaderComponent
import ChatListTitleView
import EdgeEffect
import CoreList
import CoreListComponentHost
import NewsFeedSupport
import NewsFeedComponents

final class NewsScreenNode: ASDisplayNode, ASGestureRecognizerDelegate {
    private let context: AccountContext
    private weak var controller: NewsScreen?
    private var presentationData: PresentationData

    let navigationBarView = ComponentView<Empty>()
    private let segmentNode = NewsSegmentNode()
    private let listsContainerNode = ASDisplayNode()
    private let forYouList = NewsFeedListView()
    private let addedList = NewsFeedListView()
    private let pill = ComponentView<Empty>()
    private let edgeEffectView = EdgeEffectView()

    private let forYou: NewsForYouFeedBinding
    private let added: NewsAddedFeedBinding
    private var addedRows = NewsAddedFeedBinding.Rows(items: [], positions: [:], firstUnreadItemIndex: nil)
    private var pendingAddedReposition = false
    /// The user dragged the Added list since it was last positioned: a late window replacement must not
    /// pull the list away from what they are reading.
    private var addedUserScrolledSinceReposition = false
    private var previousForYouCount = 0
    private var previousAddedCount = 0

    private var selectedSegment = 0
    /// The swipe between the lists in progress, as a signed fraction of the width: negative towards Added.
    private var pagerFraction: CGFloat = 0.0
    private var isPagerDragging = false
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat)?
    private var listInsets = UIEdgeInsets()
    private var skeletonRowLayoutCache: (width: CGFloat, theme: PresentationTheme, strings: PresentationStrings, layout: NewsFeedSkeletonRowLayout)?
    private var foregroundDisposable: Disposable?
    var isScreenVisible = false

    private var searchDisplayController: SearchDisplayController?
    private var isSearchDisplayControllerActive: ChatListNavigationBar.ActiveSearch?

    var requestActivateSearch: (() -> Void)?
    var requestDeactivateSearch: (() -> Void)?
    var openMoreMenu: ((UIView) -> Void)?

    init(context: AccountContext, controller: NewsScreen) {
        self.context = context
        self.controller = controller
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.forYou = NewsForYouFeedBinding(context: context)
        self.added = NewsAddedFeedBinding(context: context)

        super.init()

        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor

        self.addSubnode(self.listsContainerNode)
        self.listsContainerNode.view.addSubview(self.forYouList)
        self.listsContainerNode.view.addSubview(self.addedList)
        self.addedList.isHidden = true
        self.view.addSubview(self.edgeEffectView)

        self.forYouList.isPullToRefreshEnabled = true
        self.forYouList.updateTheme(indicatorColor: self.presentationData.theme.list.itemSecondaryTextColor)
        self.addedList.updateTheme(indicatorColor: self.presentationData.theme.list.itemSecondaryTextColor)

        self.forYouList.onEdgeReached = { [weak self] edge in
            if edge == .bottom {
                self?.forYou.feed.loadMore()
            }
        }
        self.forYouList.onPullToRefresh = { [weak self] in
            self?.forYou.feed.refresh()
        }
        self.addedList.onEdgeReached = { [weak self] edge in
            switch edge {
            case .top:
                self?.added.feed.loadNewer()
            case .bottom:
                self?.added.feed.loadOlder()
            }
        }
        for list in [self.forYouList, self.addedList] {
            list.onScrollOffsetChanged = { [weak self, weak list] offset, transition in
                guard let self, let list else {
                    return
                }
                if self.pagerFraction != 0.0 {
                    // Mid-swipe the header blends both lists, so either one moving changes it.
                    self.updateNavigationScrolling(offset: self.navigationScrollOffset(settled: false), transition: .immediate)
                    return
                }
                guard self.activeList === list else {
                    return
                }
                // Scroll to top and the snap below scroll programmatically: the header unfolds with them.
                self.updateNavigationScrolling(offset: offset, transition: ComponentTransition(transition))
            }
            list.onScrollingEnded = { [weak self, weak list] in
                guard let self, let list, self.activeList === list, self.pagerFraction == 0.0 else {
                    return
                }
                self.snapNavigationBar()
            }
        }
        self.addedList.onVisibleRowsChanged = { [weak self] in
            guard let self else {
                return
            }
            self.trackAddedReading()
            self.updatePill(transition: .immediate)
        }

        self.addedList.onProgrammaticScroll = { [weak self] in
            guard let self else {
                return
            }
            self.trackAddedReading(settled: true)
            self.updatePill(transition: .immediate, settled: true)
        }
        self.addedList.onWillBeginDragging = { [weak self] in
            self?.addedUserScrolledSinceReposition = true
        }

        self.forYou.updated = { [weak self] in
            self?.updateForYouList(transition: .immediate)
        }
        self.added.updated = { [weak self] windowReplaced in
            guard let self else {
                return
            }
            if windowReplaced {
                self.pendingAddedReposition = true
            }
            self.updateAddedList(transition: .immediate)
        }

        self.foregroundDisposable = (context.sharedContext.applicationBindings.applicationInForeground
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] inForeground in
            // Only while News is on screen; didAppear revalidates when the user comes back to it.
            if inForeground, let self, self.isScreenVisible {
                self.added.feed.revalidate()
            }
        })
    }

    deinit {
        self.foregroundDisposable?.dispose()
    }

    override func didLoad() {
        super.didLoad()

        // Swiping between the lists, set up as Peer Info's panes (PeerInfoPaneContainerNode).
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.pagerPanGesture(_:)), allowedDirections: { [weak self] _ in
            guard let self, self.isSearchDisplayControllerActive == nil else {
                return []
            }
            return self.selectedSegment == 0 ? .left : .right
        })
        panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        self.listsContainerNode.view.addGestureRecognizer(panRecognizer)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    // The lists' scrolling waits for the swipe to fail, as it waits for the navigation back swipe.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is InteractiveTransitionGestureRecognizer {
            return false
        }
        return otherGestureRecognizer is UIPanGestureRecognizer
    }

    @objc private func pagerPanGesture(_ recognizer: UIPanGestureRecognizer) {
        guard let (layout, navigationBarHeight) = self.validLayout else {
            return
        }
        let width = max(1.0, layout.size.width)
        switch recognizer.state {
        case .began:
            self.isPagerDragging = true
            self.forYouList.isHidden = false
            self.addedList.isHidden = false
        case .changed:
            var fraction = recognizer.translation(in: self.view).x / width
            if self.selectedSegment == 0 {
                fraction = min(0.0, fraction)
            } else {
                fraction = max(0.0, fraction)
            }
            self.pagerFraction = fraction
            self.layoutPages(transition: .immediate)
            self.segmentNode.updateTabSwitchFraction(fraction, isDragging: true, transition: .immediate)
            self.updateNavigationScrolling(offset: self.navigationScrollOffset(settled: false), transition: .immediate)
        case .ended, .cancelled:
            var target = self.selectedSegment
            if recognizer.state == .ended {
                target = newsPagerSettledIndex(currentIndex: self.selectedSegment, pageCount: 2, translation: recognizer.translation(in: self.view).x, velocity: recognizer.velocity(in: self.view).x, width: width)
            }
            self.isPagerDragging = false
            self.pagerFraction = 0.0
            // Peer Info's release spring.
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
            if target != self.selectedSegment {
                self.setSelectedSegment(target, transition: transition)
            } else {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
            }
        default:
            break
        }
    }

    private var activeList: NewsFeedListView {
        return self.selectedSegment == 0 ? self.forYouList : self.addedList
    }

    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        self.forYouList.updateTheme(indicatorColor: presentationData.theme.list.itemSecondaryTextColor)
        self.addedList.updateTheme(indicatorColor: presentationData.theme.list.itemSecondaryTextColor)
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    func didAppear() {
        self.isScreenVisible = true
        self.added.feed.revalidate()
    }

    func didDisappear() {
        self.isScreenVisible = false
    }

    func scrollToTop() {
        self.activeList.scrollToTop()
    }

    func markAllAsRead() {
        self.added.feed.markAllRead()
    }

    private func selectSegment(_ index: Int) {
        guard index != self.selectedSegment else {
            // As tapping the current Peer Info tab does.
            self.activeList.scrollToTop()
            return
        }
        guard !self.isPagerDragging else {
            return
        }
        // The tabs' selection pill and the lists slide on the same spring Peer Info uses.
        self.setSelectedSegment(index, transition: .animated(duration: 0.4, curve: .spring))
    }

    /// A tap on a tab, or a swipe that settled on it.
    private func setSelectedSegment(_ index: Int, transition: ContainedViewLayoutTransition) {
        self.selectedSegment = index
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        // After the layout: revalidating can push the feed's state synchronously, and the Added list's update then
        // moves the header to its fold at once, leaving the animated layout nothing to animate.
        if index == 1 {
            self.added.feed.revalidate()
        }
        self.trackAddedReading()
    }

    /// The two lists side by side, the selected one on screen, moved by a swipe in progress. The other one is
    /// hidden once nothing shows it.
    private func layoutPages(transition: ContainedViewLayoutTransition) {
        guard let (layout, _) = self.validLayout else {
            return
        }
        let isPaging = self.isPagerDragging || self.pagerFraction != 0.0
        for (index, list) in [self.forYouList, self.addedList].enumerated() {
            let frame = CGRect(origin: CGPoint(x: (CGFloat(index - self.selectedSegment) + self.pagerFraction) * layout.size.width, y: 0.0), size: layout.size)
            if list.bounds.size != frame.size {
                // Only the position animates.
                list.frame = CGRect(origin: list.frame.origin, size: frame.size)
            }
            if index == self.selectedSegment || isPaging {
                list.isHidden = false
            }
            transition.updateFrame(view: list, frame: frame, completion: { [weak self, weak list] _ in
                guard let self, let list else {
                    return
                }
                if index != self.selectedSegment && !self.isPagerDragging && self.pagerFraction == 0.0 {
                    list.isHidden = true
                }
            })
        }
    }

    // MARK: Navigation

    private func openPost(peer: EnginePeer, messageId: EngineMessage.Id) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: nil, timecode: nil, setupReply: false, cachedAnchor: true)))
    }

    private func openPeer(_ peer: EnginePeer) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
    }

    // MARK: Lists

    /// A post row measured at the rows' width, for the skeletons; measured again when the width or the
    /// presentation changes.
    private func skeletonRowLayout() -> NewsFeedSkeletonRowLayout {
        let width = max(1.0, (self.validLayout?.layout.size.width ?? 0.0) - self.listInsets.left - self.listInsets.right)
        let presentationData = self.presentationData
        if let cache = self.skeletonRowLayoutCache, cache.width == width, cache.theme === presentationData.theme, cache.strings === presentationData.strings {
            return cache.layout
        }
        let layout = newsFeedSkeletonRowLayout(context: self.context, theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, width: width)
        self.skeletonRowLayoutCache = (width, presentationData.theme, presentationData.strings, layout)
        return layout
    }

    private func itemEnvironment(list: NewsFeedListView) -> NewsFeedItemEnvironment {
        return NewsFeedItemEnvironment(context: self.context, presentationData: self.presentationData, skeletonRowLayout: self.skeletonRowLayout(), rowLoading: list.rowLoading, openPost: { [weak self] peer, messageId in
            self?.openPost(peer: peer, messageId: messageId)
        })
    }

    private func updateLists(transition: CoreListTransition) {
        self.updateForYouList(transition: transition)
        self.updateAddedList(transition: transition)
    }

    private func updateForYouList(transition: CoreListTransition) {
        guard let (layout, _) = self.validLayout else {
            return
        }
        let environment = self.itemEnvironment(list: self.forYouList)
        let forYouRows = self.forYou.items(environment: environment)
        self.forYouList.setShowsSkeleton(forYouRows.isLoading, theme: environment.presentationData.theme, rowLayout: environment.skeletonRowLayout)
        self.forYouList.setRefreshing(self.forYou.state?.isRefreshing ?? false)
        self.forYouList.update(size: layout.size, insets: self.listInsets, items: forYouRows.items, scrollTo: nil, anchorMode: .automatic, transition: transition)
        self.recheckForYouEdgeIfGrown(count: forYouRows.items.count)
    }

    private func updateAddedList(transition: CoreListTransition) {
        guard let (layout, _) = self.validLayout else {
            return
        }
        let environment = self.itemEnvironment(list: self.addedList)
        self.addedRows = self.added.rows(environment: environment)
        self.addedList.setShowsSkeleton(self.addedRows.isLoading, theme: environment.presentationData.theme, rowLayout: environment.skeletonRowLayout)
        var scrollTo: CoreListScrollTarget?
        let hasPosts = !self.addedRows.positions.isEmpty
        if self.pendingAddedReposition, hasPosts {
            self.pendingAddedReposition = false
            let anchor = self.added.state?.windowAnchor ?? .readMark
            // A jump to the newest is the user's own request; any other window replacement (the server page
            // replacing the snapshot) leaves a list the user has already scrolled where it is.
            if anchor == .top || !self.addedUserScrolledSinceReposition {
                self.addedUserScrolledSinceReposition = false
                if anchor == .readMark, let firstUnreadItemIndex = self.addedRows.firstUnreadItemIndex {
                    let viewportHeight = max(0.0, layout.size.height - self.listInsets.top - self.listInsets.bottom)
                    // The oldest unread post sits at the bottom of the viewport.
                    scrollTo = CoreListScrollTarget(index: firstUnreadItemIndex, resolve: { rowHeight, _ in
                        return max(0.0, viewportHeight - rowHeight)
                    })
                } else {
                    scrollTo = CoreListScrollTarget(index: 0, pointOffset: 0.0)
                }
            }
        }
        self.addedList.update(size: layout.size, insets: self.listInsets, items: self.addedRows.items, scrollTo: scrollTo, anchorMode: .preserveVisibleContent, transition: scrollTo != nil ? .immediate : transition)

        self.recheckAddedEdgesIfGrown(count: self.addedRows.items.count)
        self.updatePill(transition: .immediate)
        self.trackAddedReading()
    }

    /// CoreList reports an edge only on entering it; after a page grows a list while it is still at the edge,
    /// ask again. Only on growth, so a failing request is not retried in a loop.
    private func recheckForYouEdgeIfGrown(count: Int) {
        let grew = count > self.previousForYouCount
        self.previousForYouCount = count
        guard grew else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            if self.forYouList.coreList.reachedLoadedEdges.contains(.bottom) {
                self.forYou.feed.loadMore()
            }
        }
    }

    private func recheckAddedEdgesIfGrown(count: Int) {
        let grew = count > self.previousAddedCount
        self.previousAddedCount = count
        guard grew else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            if self.addedList.coreList.reachedLoadedEdges.contains(.bottom) {
                self.added.feed.loadOlder()
            }
            if self.addedList.coreList.reachedLoadedEdges.contains(.top) {
                self.added.feed.loadNewer()
            }
        }
    }

    private func trackAddedReading(settled: Bool = false) {
        guard self.isScreenVisible, self.selectedSegment == 1, self.isSearchDisplayControllerActive == nil else {
            return
        }
        let positions = self.addedRows.positions
        let visible = self.addedList.visibleRowFrames(settled: settled).compactMap { row -> NewsVisibleRow? in
            guard let position = positions[row.index] else {
                return nil
            }
            return NewsVisibleRow(position: position, frame: row.frame)
        }
        if let position = newsNewestFullyVisiblePosition(rows: visible, viewport: self.addedList.viewport) {
            self.added.feed.markRead(upTo: position)
        }
    }

    private func updatePill(transition: ComponentTransition, settled: Bool = false) {
        guard let (layout, _) = self.validLayout else {
            return
        }
        var title: String?
        // The pill lives on the Added page, so it shows only where that page does, and slides with it.
        if self.isSearchDisplayControllerActive == nil, let state = self.added.state {
            if state.hasNewer {
                title = "↑ " + self.presentationData.strings.News_NewPostsPill
            } else if let readMax = state.readMaxPosition {
                let viewport = self.addedList.viewport
                if let firstVisible = self.addedList.visibleRowFrames(settled: settled).first(where: { $0.frame.maxY > viewport.minY + 1.0 }) {
                    var unreadAbove = 0
                    for (index, position) in self.addedRows.positions where index < firstVisible.index && position > readMax {
                        unreadAbove += 1
                    }
                    if unreadAbove > 0 {
                        title = "↑ " + self.presentationData.strings.News_NewPostsCount("\(unreadAbove)").string
                    }
                }
            }
        }
        guard let title else {
            if let view = self.pill.view {
                transition.setAlpha(view: view, alpha: 0.0)
                view.isUserInteractionEnabled = false
            }
            return
        }
        let size = self.pill.update(
            transition: transition,
            component: AnyComponent(NewsNewPostsPillComponent(theme: self.presentationData.theme, title: title, action: { [weak self] in
                self?.pillTapped()
            })),
            environment: {},
            containerSize: CGSize(width: layout.size.width - 32.0, height: 36.0)
        )
        if let view = self.pill.view {
            if view.superview == nil {
                // Moved like the header's tabs, with an additive position.
                view.layer.anchorPoint = CGPoint()
                // The page's origin is the screen's top, so the header-relative position holds.
                self.addedList.addSubview(view)
            }
            view.isUserInteractionEnabled = true
            transition.setAlpha(view: view, alpha: 1.0)
            // Additive, so an immediate update (a new count) leaves a header animation in flight running.
            transition.setFrameWithAdditivePosition(view: view, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - size.width) * 0.5), y: self.pillOriginY()), size: size))
        }
    }

    /// 8 pt below the header's bottom edge, which rises as the search field folds away (and drops with an overscroll).
    private func pillOriginY() -> CGFloat {
        var clippedScrollOffset: CGFloat = 0.0
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View, let value = navigationBarComponentView.clippedScrollOffset {
            clippedScrollOffset = value
        }
        return self.listInsets.top + 8.0 - clippedScrollOffset
    }

    /// Moves the pill with the header's tabs, on the same transition.
    private func updatePillPosition(transition: ComponentTransition) {
        guard let view = self.pill.view, view.superview != nil else {
            return
        }
        var frame = view.frame
        frame.origin.y = self.pillOriginY()
        transition.setFrameWithAdditivePosition(view: view, frame: frame)
    }

    private func pillTapped() {
        guard let state = self.added.state else {
            return
        }
        if state.hasNewer {
            self.added.feed.jumpToNewest()
        } else {
            self.addedList.scrollToTop()
        }
    }

    // MARK: Header (as ContactsControllerNode)

    private func updateNavigationBar(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        let rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = [
            AnyComponentWithIdentity(id: "more", component: AnyComponent(NavigationButtonComponent(
                content: .more,
                pressed: { [weak self] sourceView in
                    self?.openMoreMenu?(sourceView)
                }
            )))
        ]
        let title = self.presentationData.strings.News_Title
        let primaryContent = ChatListHeaderComponent.Content(
            title: title,
            navigationBackTitle: nil,
            titleComponent: nil,
            chatListTitle: NetworkStatusTitle(text: title, activity: false, hasProxy: false, connectsViaProxy: false, isPasscodeSet: false, isManuallyLocked: false, peerStatus: nil),
            leftButton: nil,
            rightButtons: rightButtons,
            backPressed: nil
        )

        self.segmentNode.update(context: self.context, width: layout.size.width, leftInset: 16.0 + layout.safeInsets.left, rightInset: 16.0 + layout.safeInsets.right, theme: self.presentationData.theme, strings: self.presentationData.strings, selectedIndex: self.selectedSegment, tabSwitchFraction: self.pagerFraction, isSwitchingByDragging: self.isPagerDragging, liftWhileSwitching: layout.deviceMetrics.type != .tablet, action: { [weak self] index in
            self?.selectSegment(index)
        }, transition: ComponentTransition(transition))

        let navigationBarSize = self.navigationBarView.update(
            transition: ComponentTransition(transition),
            component: AnyComponent(ChatListNavigationBar(
                context: self.context,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                statusBarHeight: layout.navigationBarStatusBarHeight ?? 0.0,
                leftInset: layout.safeInsets.left,
                rightInset: layout.safeInsets.right,
                trailingButtonsInset: layout.navigationBarTrailingButtonsInset,
                search: ChatListNavigationBar.Search(isEnabled: true),
                activeSearch: self.isSearchDisplayControllerActive,
                primaryContent: primaryContent,
                secondaryContent: nil,
                secondaryTransition: 0.0,
                storySubscriptions: nil,
                storiesIncludeHidden: true,
                uploadProgress: [:],
                headerPanels: nil,
                tabsNode: self.isSearchDisplayControllerActive == nil ? self.segmentNode : nil,
                tabsNodeIsSearch: false,
                accessoryPanelContainer: nil,
                accessoryPanelContainerHeight: 0.0,
                activateSearch: { [weak self] _ in
                    self?.requestActivateSearch?()
                },
                openStatusSetup: { _ in
                },
                allowAutomaticOrder: {
                }
            )),
            environment: {},
            containerSize: layout.size
        )
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            navigationBarComponentView.deferScrollApplication = true
            if navigationBarComponentView.superview == nil {
                self.view.addSubview(navigationBarComponentView)
            }
            transition.updateFrame(view: navigationBarComponentView, frame: CGRect(origin: CGPoint(), size: navigationBarSize))
            return navigationBarSize.height
        } else {
            return 0.0
        }
    }

    /// The header follows the selected list; while a swipe is in progress, a blend of both lists' folds.
    private func navigationScrollOffset(settled: Bool) -> NewsFeedListView.ScrollOffset {
        let current = self.activeList.scrollOffset(settled: settled)
        guard self.pagerFraction != 0.0 else {
            return current
        }
        let next = (self.selectedSegment == 0 ? self.addedList : self.forYouList).scrollOffset(settled: settled)
        return .known(newsPagerHeaderOffset(current: current.knownValue, next: next.knownValue, progress: abs(self.pagerFraction), foldHeight: ChatListNavigationBar.searchScrollHeight))
    }

    private func updateNavigationScrolling(offset scrollOffset: NewsFeedListView.ScrollOffset, transition: ComponentTransition) {
        var offset: CGFloat
        switch scrollOffset {
        case let .known(value):
            offset = value
        case .unknown:
            offset = 1000.0
        }
        if self.isSearchDisplayControllerActive != nil {
            offset = 0.0
        }
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            navigationBarComponentView.applyScroll(offset: offset, allowAvatarsExpansion: false, transition: transition)
        }
        self.updatePillPosition(transition: transition)
    }

    /// As `ContactsControllerNode.contentScrollingEnded`: a half-collapsed search field snaps open or shut.
    private func snapNavigationBar() {
        guard let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View, let clippedScrollOffset = navigationBarComponentView.clippedScrollOffset else {
            return
        }
        guard clippedScrollOffset > 0.0 && clippedScrollOffset < ChatListNavigationBar.searchScrollHeight else {
            return
        }
        let target: CGFloat = clippedScrollOffset < ChatListNavigationBar.searchScrollHeight * 0.5 ? 0.0 : ChatListNavigationBar.searchScrollHeight
        self.activeList.scroll(toIndex: 0, pointOffset: -target, transition: .uiKitScroll())
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)

        let navigationHeight = self.updateNavigationBar(layout: layout, transition: transition)

        var insets = layout.insets(options: [.input])
        insets.top += navigationHeight
        // Both feeds start 8 pt below the header.
        self.listInsets = UIEdgeInsets(top: insets.top + 8.0, left: layout.safeInsets.left, bottom: insets.bottom, right: layout.safeInsets.right)

        let innerLayout = ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, reservedCorners: layout.reservedCorners, division: layout.division, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver, presentedInFormSheet: layout.presentedInFormSheet)
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(innerLayout, navigationBarHeight: navigationHeight, transition: transition)
        }

        transition.updateFrame(node: self.listsContainerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.layoutPages(transition: transition)
        self.updateLists(transition: CoreListTransition(transition))

        let edgeEffectHeight: CGFloat = layout.intrinsicInsets.bottom
        let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - edgeEffectHeight), size: CGSize(width: layout.size.width, height: edgeEffectHeight))
        transition.updateFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
        self.edgeEffectView.update(content: self.presentationData.theme.list.plainBackgroundColor, rect: edgeEffectFrame, edge: .bottom, edgeSize: edgeEffectFrame.height, transition: ComponentTransition(transition))

        // Settled: a programmatic scroll may still be animating toward it.
        self.updateNavigationScrolling(offset: self.navigationScrollOffset(settled: true), transition: ComponentTransition(transition))
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            navigationBarComponentView.deferScrollApplication = false
            navigationBarComponentView.applyCurrentScroll(transition: ComponentTransition(transition))
        }
        // The scroll applied just above; the pill was laid out before it.
        self.updatePillPosition(transition: ComponentTransition(transition))
    }

    // MARK: Search (as ContactsControllerNode, with the chat list's search content)

    func activateSearch(placeholderNode: SearchBarPlaceholderNode?) {
        guard let (layout, navigationBarHeight) = self.validLayout, self.searchDisplayController == nil else {
            return
        }
        self.isSearchDisplayControllerActive = ChatListNavigationBar.ActiveSearch(isExternal: placeholderNode == nil)

        let contentNode = ChatListSearchContainerNode(
            context: self.context,
            animationCache: self.context.animationCache,
            animationRenderer: self.context.animationRenderer,
            filter: [],
            requestPeerType: nil,
            location: .chatList(groupId: .root),
            folder: nil,
            displaySearchFilters: true,
            hasDownloads: false,
            initialFilter: .channels,
            openPeer: { [weak self] peer, _, _, _ in
                self?.openPeer(peer)
            },
            openDisabledPeer: { _, _, _ in
            },
            openRecentPeerOptions: { _ in
            },
            openMessage: { [weak self] peer, _, messageId, _ in
                self?.openPost(peer: peer, messageId: messageId)
            },
            addContact: nil,
            peerContextAction: nil,
            present: { [weak self] c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            },
            presentInGlobalOverlay: { [weak self] c, a in
                self?.controller?.presentInGlobalOverlay(c, with: a)
            },
            navigationController: self.controller?.navigationController as? NavigationController,
            parentController: { [weak self] in
                return self?.controller
            }
        )
        contentNode.dismissSearch = { [weak self] in
            self?.requestDeactivateSearch?()
        }

        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .navigation, contentNode: contentNode, cancel: { [weak self] in
            self?.requestDeactivateSearch?()
        }, fieldStyle: placeholderNode?.fieldStyle ?? .modern)
        self.searchDisplayController?.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self] subnode, isSearchBar in
            guard let self else {
                return
            }
            if isSearchBar {
                if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                    navigationBarComponentView.searchContentNode?.addSubnode(subnode)
                }
            } else {
                self.insertSubnode(subnode, aboveSubnode: self.listsContainerNode)
            }
        }, placeholder: placeholderNode)
        self.updatePill(transition: .immediate)
    }

    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode?, animated: Bool) {
        self.isSearchDisplayControllerActive = nil
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
            self.searchDisplayController = nil
        }
        self.updatePill(transition: .immediate)
    }
}
