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
import ChatListHeaderComponent
import NavigationBarComponent
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

    let headerView = NewsHeaderView()
    private let listsContainerNode = ASDisplayNode()
    private let forYouList = NewsFeedListView()
    private let addedList = NewsFeedListView()
    private let pill = ComponentView<Empty>()
    private let edgeEffectView = EdgeEffectView()

    private let forYou: NewsForYouFeedBinding
    private let added: NewsAddedFeedBinding
    private var addedRows = NewsAddedFeedBinding.Rows(items: [], positions: [:], firstUnreadItemIndex: nil)
    /// The pull-to-refresh drop (spec): its model, ticked while anything moves.
    private let refreshController = NewsRefreshController()
    private var forYouHasPosts = false
    private var addedHasPosts = false
    private var pendingAddedReposition = false
    /// The user dragged the Added list since it was last positioned: a late window replacement must not
    /// pull the list away from what they are reading.
    private var addedUserScrolledSinceReposition = false
    private var previousForYouCount = 0
    private var previousAddedCount = 0

    private var selectedSegment = 0
    /// The tab a tap selected while its shutter runs: the tabs show it at once, the pages swap under the shutter.
    private var tappedSegment: Int?
    private let tabSwitchGeneration = NewsGeneration()
    /// The swipe between the lists in progress, as a signed fraction of the width: negative towards Added.
    private var pagerFraction: CGFloat = 0.0
    private var isPagerDragging = false
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat)?
    private var listInsets = UIEdgeInsets()
    /// Each tab's "Post hidden" flow, for the screen's lifetime (spec §2).
    private let forYouFeedback = NewsPostFeedbackController(tab: .forYou)
    private let addedFeedback = NewsPostFeedbackController(tab: .added)
    private var skeletonRowLayoutCache: (width: CGFloat, theme: PresentationTheme, strings: PresentationStrings, layout: NewsSkeletonModelRow)?
    private var foregroundDisposable: Disposable?
    var isScreenVisible = false

    private var searchDisplayController: SearchDisplayController?
    private var searchContentNode: NewsSearchContentNode?
    private var isSearchActive = false

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
        self.view.addSubview(self.headerView)
        self.headerView.activateSearch = { [weak self] in
            self?.requestActivateSearch?()
        }
        self.headerView.openMoreMenu = { [weak self] sourceView in
            self?.openMoreMenu?(sourceView)
        }
        self.headerView.selectSegment = { [weak self] index in
            self?.selectSegment(index)
        }

        self.forYouList.reduceMotion = self.presentationData.reduceMotion
        self.addedList.reduceMotion = self.presentationData.reduceMotion

        self.forYouList.onEdgeReached = { [weak self] edge in
            if edge == .bottom {
                self?.forYou.feed.loadMore()
            }
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
                self.refreshController.listMoved()
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

        self.refreshController.selectedPage = { [weak self] in
            return self?.selectedSegment ?? 0
        }
        self.refreshController.makeInput = { [weak self] page in
            return self?.refreshInput(page: page)
        }
        self.refreshController.onBegin = { [weak self] page in
            if page == 0 {
                self?.forYou.beginPullRefresh()
            } else {
                self?.added.beginPullRefresh()
            }
        }
        self.refreshController.onHold = { [weak self] page, hold in
            (page == 0 ? self?.forYouList : self?.addedList)?.setRefreshHold(hold)
        }
        self.refreshController.onPose = { [weak self] _, pose in
            guard let self else {
                return
            }
            self.headerView.segmentNode.updateRefreshDrop(pose: pose, theme: self.presentationData.theme, lottieSettings: self.context.lottieRenderingSettings)
        }
        self.refreshController.onInsertRows = { [weak self] page, slides in
            self?.revealPullRefresh(page: page, slides: slides)
        }
        self.forYou.onPullRefreshEnded = { [weak self] outcome in
            self?.refreshController.fetchEnded(outcome)
        }
        self.added.onPullRefreshEnded = { [weak self] outcome in
            self?.refreshController.fetchEnded(outcome)
        }

        self.forYou.updated = { [weak self] in
            self?.updateForYouList(transition: .immediate)
            self?.searchContentNode?.corpusUpdated()
        }
        self.added.updated = { [weak self] windowReplaced in
            guard let self else {
                return
            }
            if windowReplaced {
                self.pendingAddedReposition = true
            }
            self.updateAddedList(transition: .immediate)
            self.searchContentNode?.corpusUpdated()
        }
        // Rows going in or out ride `NewsSpring.rows` and play their own appears, so the list adds no fade of its own.
        self.forYouFeedback.updated = { [weak self] rowsChanged in
            self?.updateForYouList(transition: rowsChanged ? NewsFeedListView.feedbackRowsTransition : .immediate, animatesInsertions: !rowsChanged)
        }
        self.forYouFeedback.currentPosts = { [weak self] in
            return self?.forYou.feedbackPosts ?? []
        }
        self.forYouFeedback.visiblePosts = { [weak self] in
            return self?.forYouList.visibleItemIdentities ?? []
        }
        self.addedFeedback.updated = { [weak self] rowsChanged in
            self?.updateAddedList(transition: rowsChanged ? NewsFeedListView.feedbackRowsTransition : .immediate, animatesInsertions: !rowsChanged)
        }
        self.addedFeedback.currentPosts = { [weak self] in
            return self?.added.feedbackPosts ?? []
        }
        self.addedFeedback.visiblePosts = { [weak self] in
            return self?.addedList.visibleItemIdentities ?? []
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
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.pagerPanGesture(_:)), allowedDirections: { [weak self] point in
            guard let self, !self.isSearchActive, self.tappedSegment == nil else {
                return []
            }
            if self.selectedSegment == 0 {
                // The chat list's rule with folders (spec §4): a swipe from a post row's right edge reveals its actions,
                // one from the middle pages to Added.
                let list = self.forYouList
                let pointInList = list.convert(point, from: self.listsContainerNode.view)
                if newsPagerDefersToRowReveal(touchX: pointInList.x, width: list.bounds.width, rightInset: list.insets.right, isOnRevealableRow: list.hasSwipeableRow(at: pointInList)) {
                    return []
                }
                return .left
            }
            return .right
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
            self.refreshController.detach()
            self.closeSwipedRows(animated: true)
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
            self.headerView.segmentNode.updateTabSwitchFraction(fraction, isDragging: true, transition: .immediate)
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
        self.forYouList.reduceMotion = presentationData.reduceMotion
        self.addedList.reduceMotion = presentationData.reduceMotion
        self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    func didAppear() {
        self.isScreenVisible = true
        self.refreshController.isScreenVisible = true
        self.added.feed.revalidate()
    }

    func didDisappear() {
        self.isScreenVisible = false
        self.refreshController.isScreenVisible = false
    }

    func scrollToTop() {
        self.activeList.scrollToTop()
    }

    func markAllAsRead() {
        self.added.feed.markAllRead()
    }

    /// The current page reloads under its skeleton, from the top.
    func reloadFeed() {
        self.activeList.scroll(toIndex: 0, pointOffset: 0.0, transition: .immediate)
        if self.selectedSegment == 0 {
            self.forYou.reloadFeed()
        } else {
            // The reload is the user's own request: its window opens at the read mark however the list was
            // scrolled before.
            self.addedUserScrolledSinceReposition = false
            self.added.reloadFeed()
        }
    }

    private func selectSegment(_ index: Int) {
        let displayed = self.tappedSegment ?? self.selectedSegment
        guard index != displayed else {
            if self.tappedSegment == nil {
                // As tapping the current Peer Info tab does.
                self.activeList.scrollToTop()
            }
            return
        }
        guard !self.isPagerDragging, let (layout, navigationBarHeight) = self.validLayout else {
            return
        }
        self.refreshController.detach()
        // Feed2 FeedStore.swift:799-815: the shutter fades in, the pages swap while it is opaque, and it fades out.
        let token = self.tabSwitchGeneration.begin()
        self.tappedSegment = index
        self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))

        let shutter = self.headerView.shutterView
        let fromAlpha = CGFloat(shutter.layer.presentation()?.opacity ?? Float(shutter.alpha))
        shutter.layer.removeAnimation(forKey: "opacity")
        shutter.alpha = 1.0
        shutter.layer.animateAlpha(from: fromAlpha, to: 1.0, duration: NewsShutter.fadeInDuration, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)

        Queue.mainQueue().after(NewsShutter.swapDelay, { [weak self] in
            guard let self, self.tabSwitchGeneration.isCurrent(token) else {
                return
            }
            self.tappedSegment = nil
            self.setSelectedSegment(index, transition: .immediate)
        })
        Queue.mainQueue().after(NewsShutter.fadeOutDelay, { [weak self] in
            guard let self, self.tabSwitchGeneration.isCurrent(token) else {
                return
            }
            let shutter = self.headerView.shutterView
            shutter.alpha = 0.0
            shutter.layer.animateAlpha(from: 1.0, to: 0.0, duration: NewsShutter.fadeOutDuration, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        })
    }

    /// A tap on a tab, or a swipe that settled on it.
    private func setSelectedSegment(_ index: Int, transition: ContainedViewLayoutTransition) {
        self.closeSwipedRows(animated: true)
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
        // Back returns to a feed without an open swipe.
        self.closeSwipedRows(animated: false)
        // Back returns to the feed, so the back button shows no unread chats.
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: nil, timecode: nil, setupReply: false, cachedAnchor: true), showsUnreadChatsBackBadge: false))
    }

    // MARK: Lists

    /// A post row measured at the rows' width, for the skeletons; measured again when the width or the
    /// presentation changes.
    private func skeletonRowLayout() -> NewsSkeletonModelRow {
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
        // The feeds' rows swipe and have the "Post hidden" flow; search results do neither (spec §1, §3).
        let feedbackController: NewsPostFeedbackController?
        if list === self.forYouList {
            feedbackController = self.forYouFeedback
        } else if list === self.addedList {
            feedbackController = self.addedFeedback
        } else {
            feedbackController = nil
        }
        var postSwipe: ((EnginePeer, EngineMessage.Id, AnyHashable) -> NewsPostSwipe)?
        var feedback: NewsFeedItemFeedback?
        if let feedbackController {
            postSwipe = { [weak self, weak list, weak feedbackController] peer, messageId, post in
                return NewsPostSwipe(action: { action in
                    self?.postSwipeAction(action, peer: peer, messageId: messageId, post: post, feedback: feedbackController)
                }, opened: { row in
                    list?.closeSwipedRows(except: row, animated: true)
                }, separatorAlphaChanged: { _ in
                    list?.updateSwipeSeparators()
                })
            }
            feedback = NewsFeedItemFeedback(state: feedbackController.state, tab: feedbackController.tab, postAppearTimes: feedbackController.postAppearTimes, panelAppearTimes: feedbackController.panelAppearTimes, undo: { [weak feedbackController] post, channel in
                feedbackController?.undo(post: post, channel: channel)
            }, choose: { [weak feedbackController] post, channel, choice in
                feedbackController?.choose(post: post, channel: channel, choice: choice)
            })
        }
        return NewsFeedItemEnvironment(context: self.context, presentationData: self.presentationData, skeletonRowLayout: self.skeletonRowLayout(), rowLoading: list.rowLoading, openPost: { [weak self] peer, messageId in
            self?.openPost(peer: peer, messageId: messageId)
        }, postSwipe: postSwipe, feedback: feedback)
    }

    /// A post row's swipe action (spec §3). Not Interested starts the tab's local "Post hidden" flow; Interesting has
    /// nothing to do yet. Neither reaches the server: there is no API. Its requests, for `peer` and `messageId`, go
    /// here once it exists.
    private func postSwipeAction(_ action: NewsPostSwipeAction, peer: EnginePeer, messageId: EngineMessage.Id, post: AnyHashable, feedback: NewsPostFeedbackController?) {
        switch action {
        case .notInterested:
            feedback?.notInterested(post: post)
        case .interesting:
            break
        }
    }

    /// Closes an open swipe in either feed (spec §5).
    private func closeSwipedRows(animated: Bool) {
        self.forYouList.closeSwipedRows(animated: animated)
        self.addedList.closeSwipedRows(animated: animated)
    }

    private func updateLists(transition: CoreListTransition) {
        self.updateForYouList(transition: transition)
        self.updateAddedList(transition: transition)
    }

    private func updateForYouList(transition: CoreListTransition, anchorMode: CoreListAnchorMode = .automatic, animatesInsertions: Bool = true) {
        guard let (layout, _) = self.validLayout else {
            return
        }
        let environment = self.itemEnvironment(list: self.forYouList)
        let forYouRows = self.forYou.items(environment: environment)
        self.forYouList.setShowsSkeleton(forYouRows.isLoading, theme: environment.presentationData.theme, rowLayout: environment.skeletonRowLayout)
        self.forYouHasPosts = forYouRows.hasPosts
        self.forYouList.update(size: layout.size, insets: self.listInsets, items: forYouRows.items, scrollTo: nil, anchorMode: anchorMode, animatesInsertions: animatesInsertions, transition: transition)
        self.recheckForYouEdgeIfGrown(count: forYouRows.items.count)
    }

    private func updateAddedList(transition: CoreListTransition, anchorMode: CoreListAnchorMode = .preserveVisibleContent, animatesInsertions: Bool = true) {
        guard let (layout, _) = self.validLayout else {
            return
        }
        let environment = self.itemEnvironment(list: self.addedList)
        self.addedRows = self.added.rows(environment: environment)
        self.addedHasPosts = !self.addedRows.isLoading && self.addedRows.hasPostRows
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
        self.addedList.update(size: layout.size, insets: self.listInsets, items: self.addedRows.items, scrollTo: scrollTo, anchorMode: anchorMode, animatesInsertions: animatesInsertions, transition: scrollTo != nil ? .immediate : transition)

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
        guard self.isScreenVisible, self.selectedSegment == 1, !self.isSearchActive else {
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
        if !self.isSearchActive, let state = self.added.state {
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

    /// 8 pt below the header's current bottom edge, which rises as the search scrolls under the top row (and drops
    /// with an overscroll).
    private func pillOriginY() -> CGFloat {
        return self.headerView.currentBottom + 8.0
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

    // MARK: Header

    private func updateHeader(layout: ContainerViewLayout, transition: ComponentTransition) -> NewsHeaderGeometry {
        transition.setFrame(view: self.headerView, frame: CGRect(origin: CGPoint(), size: layout.size))
        return self.headerView.update(params: NewsHeaderView.Params(
            context: self.context,
            theme: self.presentationData.theme,
            strings: self.presentationData.strings,
            layout: layout,
            isSearchActive: self.isSearchActive,
            selectedSegment: self.tappedSegment ?? self.selectedSegment,
            tabSwitchFraction: self.pagerFraction,
            isSwitchingByDragging: self.isPagerDragging
        ), transition: transition)
    }

    /// The header follows the selected list; while a swipe is in progress, a blend of both lists' offsets.
    private func navigationScrollOffset(settled: Bool) -> NewsFeedListView.ScrollOffset {
        let current = self.activeList.scrollOffset(settled: settled)
        guard self.pagerFraction != 0.0, let geometry = self.headerView.geometry else {
            return current
        }
        let next = (self.selectedSegment == 0 ? self.addedList : self.forYouList).scrollOffset(settled: settled)
        // Blended up to the search's full travel, so mid-swipe it can still be scrolled entirely away.
        return .known(newsPagerHeaderOffset(current: current.knownValue, next: next.knownValue, progress: abs(self.pagerFraction), foldHeight: geometry.searchTravelLimit))
    }

    private func updateNavigationScrolling(offset scrollOffset: NewsFeedListView.ScrollOffset, transition: ComponentTransition) {
        var offset: CGFloat
        switch scrollOffset {
        case let .known(value):
            offset = value
        case .unknown:
            // The first row is not loaded: the list is scrolled well past the search, which is off the screen.
            offset = self.headerView.geometry?.searchTravelLimit ?? 0.0
        }
        if self.isSearchActive {
            offset = 0.0
        }
        self.headerView.applyScroll(listOffset: offset, transition: transition)
        self.updatePillPosition(transition: transition)
    }

    /// A half-hidden search snaps open or shut when scrolling ends (as `ContactsControllerNode.contentScrollingEnded`).
    private func snapNavigationBar() {
        guard let geometry = self.headerView.geometry, let target = newsHeaderSnapTarget(blockOffset: self.headerView.blockOffset, blockHeight: geometry.blockHeight) else {
            return
        }
        self.activeList.scroll(toIndex: 0, pointOffset: -target, transition: .uiKitScroll())
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)

        let geometry = self.updateHeader(layout: layout, transition: ComponentTransition(transition))

        var insets = layout.insets(options: [.input])
        // The lists keep the resting header's inset while search is up (spec §11.3); search lays out under the
        // active bar.
        insets.top += geometry.listTopInset
        // The first row starts at the search field's bottom edge; rows carry their own top padding.
        self.listInsets = UIEdgeInsets(top: insets.top, left: layout.safeInsets.left, bottom: insets.bottom, right: layout.safeInsets.right)

        var searchInsets = layout.insets(options: [.input])
        let searchNavigationHeight = self.isSearchActive ? self.headerView.activeSearchNavigationHeight : geometry.listTopInset
        searchInsets.top += searchNavigationHeight
        let innerLayout = ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: searchInsets, safeInsets: layout.safeInsets, reservedCorners: layout.reservedCorners, division: layout.division, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver, presentedInFormSheet: layout.presentedInFormSheet)
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(innerLayout, navigationBarHeight: searchNavigationHeight, transition: transition)
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
    }

    // MARK: Pull to refresh

    /// The model's input for `page` (spec §1.1-1.2), in this node's coordinates. The lists fill the node vertically,
    /// so a list's y is the node's y.
    private func refreshInput(page: Int) -> NewsRefreshInput? {
        guard let (layout, _) = self.validLayout, let geometry = self.headerView.geometry else {
            return nil
        }
        let list = page == 0 ? self.forYouList : self.addedList
        let hasPosts = page == 0 ? self.forYouHasPosts : self.addedHasPosts
        let canPull = page == self.selectedSegment && hasPosts && !self.isSearchActive && self.tappedSegment == nil && self.pagerFraction == 0.0 && !self.isPagerDragging
        var firstPostTop: CGFloat?
        if let frame = list.firstRowFrame, frame.maxY > self.headerView.currentBottom, frame.minY < layout.size.height {
            firstPostTop = frame.minY
        }
        return NewsRefreshInput(
            gap: list.pullDistance,
            isDragging: list.isDragging,
            atEdge: list.isAtTopEdge,
            canPull: canPull,
            islandFrame: geometry.island,
            restingSearchFieldTop: geometry.topRow.maxY + NewsHeaderMetrics.searchFieldGap,
            firstPostTop: firstPostTop
        )
    }

    /// The refresh's result may be shown: the held-back posts become rows and lens in. `slides`: the list rests at its
    /// top, and they go in there while the old posts slide down on `NewsSpring.spread`; otherwise they arrive without
    /// moving what is being read (spec §1.6-1.7, §3).
    private func revealPullRefresh(page: Int, slides: Bool) {
        let now = CACurrentMediaTime()
        let transition: CoreListTransition = slides ? NewsFeedListView.refreshInsertTransition : .immediate
        // At the top the new posts go above the old first one and stay in view; scrolled into the list, they arrive
        // above without moving what is being read.
        let list = page == 0 ? self.forYouList : self.addedList
        let anchorMode: CoreListAnchorMode = slides || list.isAtTopEdge ? .automatic : .preserveVisibleContent
        if page == 0 {
            self.forYou.revealPullRefresh(now: now)
            self.updateForYouList(transition: transition, anchorMode: anchorMode, animatesInsertions: false)
        } else {
            self.added.revealPullRefresh(now: now)
            self.updateAddedList(transition: transition, anchorMode: anchorMode, animatesInsertions: false)
        }
    }

    // MARK: Search (as ContactsControllerNode, with the posts the feeds hold as its results)

    func activateSearch(placeholderNode: SearchBarPlaceholderNode?) {
        guard let (layout, navigationBarHeight) = self.validLayout, self.searchDisplayController == nil else {
            return
        }
        self.refreshController.detach()
        self.closeSwipedRows(animated: false)
        self.isSearchActive = true

        let contentNode = NewsSearchContentNode(presentationData: self.presentationData, corpus: { [weak self] in
            guard let self else {
                return NewsSearchCorpus()
            }
            var corpus = self.forYou.searchCorpus
            corpus.append(self.added.searchCorpus)
            return corpus
        }, itemEnvironment: { [weak self] list in
            return self?.itemEnvironment(list: list)
        })
        self.searchContentNode = contentNode

        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .navigation, contentNode: contentNode, cancel: { [weak self] in
            self?.requestDeactivateSearch?()
        }, fieldStyle: placeholderNode?.fieldStyle ?? .modern)
        self.searchDisplayController?.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self] subnode, isSearchBar in
            guard let self else {
                return
            }
            if isSearchBar {
                self.headerView.searchContentNode?.addSubnode(subnode)
            } else {
                self.insertSubnode(subnode, aboveSubnode: self.listsContainerNode)
            }
        }, placeholder: placeholderNode)
        self.updatePill(transition: .immediate)
    }

    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode?, animated: Bool) {
        self.isSearchActive = false
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
            self.searchDisplayController = nil
        }
        self.searchContentNode = nil
        self.updatePill(transition: .immediate)
    }
}
