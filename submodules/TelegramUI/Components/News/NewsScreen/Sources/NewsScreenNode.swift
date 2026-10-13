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

private func newsCoreListTransition(_ transition: ContainedViewLayoutTransition) -> CoreListTransition {
    switch transition {
    case .immediate:
        return .immediate
    case let .animated(duration, curve):
        // Case for case, as `CoreListChatHistoryBackend` maps them: the lists must move on the very curve
        // the header and the rest of the layout animate on.
        let coreListCurve: CoreListTransition.Animation.Curve
        switch curve {
        case .linear:
            coreListCurve = .linear
        case .easeInOut:
            coreListCurve = .easeInOut
        case .easeIn:
            coreListCurve = .easeIn
        case .spring:
            coreListCurve = .spring
        case let .customSpring(mass, stiffness, damping, initialVelocity):
            coreListCurve = .customSpring(mass: mass, stiffness: stiffness, damping: damping, initialVelocity: initialVelocity)
        case let .custom(x1, y1, x2, y2):
            coreListCurve = .custom(x1, y1, x2, y2)
        }
        return CoreListTransition(animation: .curve(duration: duration, curve: coreListCurve))
    }
}

final class NewsScreenNode: ASDisplayNode {
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
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat)?
    private var listInsets = UIEdgeInsets()
    private var now: Int32 = Int32(Date().timeIntervalSince1970)
    private var timeTimer: SwiftSignalKit.Timer?
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
                guard let self, let list, self.activeList === list else {
                    return
                }
                // Scroll to top and the snap below scroll programmatically: the header unfolds with them.
                self.updateNavigationScrolling(offset: offset, transition: ComponentTransition(transition))
            }
            list.onScrollingEnded = { [weak self, weak list] in
                guard let self, let list, self.activeList === list else {
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
        self.timeTimer?.invalidate()
        self.foregroundDisposable?.dispose()
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
        // The compact times ("6m") refresh while the screen is visible only.
        self.timeTimer?.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: 30.0, repeat: true, completion: { [weak self] in
            guard let self else {
                return
            }
            self.now = Int32(Date().timeIntervalSince1970)
            self.updateLists(transition: .immediate)
        }, queue: Queue.mainQueue())
        self.timeTimer = timer
        timer.start()
        self.now = Int32(Date().timeIntervalSince1970)
        self.updateLists(transition: .immediate)
    }

    func didDisappear() {
        self.isScreenVisible = false
        self.timeTimer?.invalidate()
        self.timeTimer = nil
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
        self.selectedSegment = index
        self.forYouList.isHidden = index != 0
        self.addedList.isHidden = index != 1
        if index == 1 {
            self.added.feed.revalidate()
        }
        if let (layout, navigationBarHeight) = self.validLayout {
            // The tabs' selection pill slides on the same spring Peer Info uses.
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
        }
        self.trackAddedReading()
    }

    // MARK: Navigation

    private func openPost(peer: EnginePeer, messageId: EngineMessage.Id) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false)))
    }

    private func openPeer(_ peer: EnginePeer) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
    }

    // MARK: Lists

    private func itemEnvironment() -> NewsFeedItemEnvironment {
        return NewsFeedItemEnvironment(context: self.context, presentationData: self.presentationData, now: self.now, openPost: { [weak self] peer, messageId in
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
        let forYouItems = self.forYou.items(environment: self.itemEnvironment())
        self.forYouList.setRefreshing(self.forYou.state?.isRefreshing ?? false)
        self.forYouList.update(size: layout.size, insets: self.listInsets, items: forYouItems, scrollTo: nil, anchorMode: .automatic, transition: transition)
        self.recheckForYouEdgeIfGrown(count: forYouItems.count)
    }

    private func updateAddedList(transition: CoreListTransition) {
        guard let (layout, _) = self.validLayout else {
            return
        }
        self.addedRows = self.added.rows(environment: self.itemEnvironment())
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
        if self.selectedSegment == 1, self.isSearchDisplayControllerActive == nil, let state = self.added.state {
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
                self.view.insertSubview(view, aboveSubview: self.listsContainerNode.view)
            }
            view.isUserInteractionEnabled = true
            transition.setAlpha(view: view, alpha: 1.0)
            transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - size.width) * 0.5), y: self.listInsets.top + 8.0), size: size))
        }
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

        self.segmentNode.update(context: self.context, width: layout.size.width, leftInset: 16.0 + layout.safeInsets.left, rightInset: 16.0 + layout.safeInsets.right, theme: self.presentationData.theme, strings: self.presentationData.strings, selectedIndex: self.selectedSegment, liftWhileSwitching: layout.deviceMetrics.type != .tablet, action: { [weak self] index in
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
        self.forYouList.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.addedList.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.updateLists(transition: newsCoreListTransition(transition))

        let edgeEffectHeight: CGFloat = layout.intrinsicInsets.bottom
        let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - edgeEffectHeight), size: CGSize(width: layout.size.width, height: edgeEffectHeight))
        transition.updateFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
        self.edgeEffectView.update(content: self.presentationData.theme.list.plainBackgroundColor, rect: edgeEffectFrame, edge: .bottom, edgeSize: edgeEffectFrame.height, transition: ComponentTransition(transition))

        // Settled: a programmatic scroll may still be animating toward it.
        self.updateNavigationScrolling(offset: self.activeList.scrollOffset(settled: true), transition: ComponentTransition(transition))
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            navigationBarComponentView.deferScrollApplication = false
            navigationBarComponentView.applyCurrentScroll(transition: ComponentTransition(transition))
        }
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
