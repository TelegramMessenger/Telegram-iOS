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
import TelegramUIPreferences
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

/// What a post row's context menu offers: For you's votes, and opening or forwarding the post.
struct NewsPostMenu {
    let hasFeedbackActions: Bool
    let interesting: () -> Void
    let notInterested: () -> Void
    let showInChat: () -> Void
    let forward: () -> Void
}

/// A page's layer above the header's edges: it takes no touch of its own, so the touches it does not give a child
/// reach the header and the list beneath.
private final class NewsPageOverlayView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }
}

final class NewsScreenNode: ASDisplayNode, ASGestureRecognizerDelegate {
    private let context: AccountContext
    private weak var controller: NewsScreen?
    private var presentationData: PresentationData

    let headerView = NewsHeaderView()
    private let listsContainerNode = ASDisplayNode()
    private let forYouList = NewsFeedListView()
    /// Replaced by a jump to the newest posts, which slides a new list in over the old one's way out.
    private var addedList = NewsFeedListView()
    /// The Added page's layer above the header's edges, laid out as the page is: the pill is pinned under the header
    /// and never overlaps it, so it is drawn over the edge effect rather than through it.
    private let addedOverlayView = NewsPageOverlayView()
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
    /// The jump to the newest posts the Added list last showed.
    private var appliedAddedJump: NewsAddedFeedBinding.Jump?
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
    /// For you's "Post hidden" flow, for the screen's lifetime (spec §2). Added has none: its rows swipe only for
    /// Expand / Collapse.
    private let forYouFeedback = NewsPostFeedbackController(tab: .forYou)
    /// Likes and dislikes, sent one at a time in the order they were cast.
    private var voteQueue = NewsPostVoteQueue()
    private var skeletonRowLayoutCache: (width: CGFloat, theme: PresentationTheme, strings: PresentationStrings, layout: NewsSkeletonModelRow)?
    private var foregroundDisposable: Disposable?
    var isScreenVisible = false

    /// Compact rows or expanded posts: the "…" menu's choice, kept across launches (`NewsFeedSettings`).
    private(set) var displayMode: NewsFeedDisplayMode = .compact
    private var hasReceivedDisplayMode = false
    /// Posts whose row a swipe switched to the other mode (Expand on the left of a compact row, Collapse of an
    /// expanded one), per tab (0 For you, 1 Added: a post in both expands in one); a change of the feed's mode
    /// forgets them.
    private var rowModeOverrides: [Int: Set<AnyHashable>] = [:]
    /// Pinching the feed switches the modes (`NewsFeedPinch`): the lists' container scales about its centre.
    private var pinchRecognizer: UIPinchGestureRecognizer?
    private var pinchState = NewsFeedPinchState()
    /// The list whose open search the pinch folded under the top row while the list rested at its top. The fold was the
    /// pinch's, not the user's: once the pinch is over and the list rests, a search still within its fold opens again
    /// (`openSearchFoldedByPinch`).
    private weak var searchFoldedByPinch: NewsFeedListView?
    /// A tap of haptics with every switch between the modes, of the feed or of one row.
    private let modeHaptic = HapticFeedback()
    /// Posts whose Show more was tapped: their whole text rather than its first lines.
    private var expandedTextPosts = Set<AnyHashable>()
    /// For the expanded rows' bubble.
    private var accountPeer: EnginePeer?
    private var settingsDisposable: Disposable?
    private var accountPeerDisposable: Disposable?

    private var searchDisplayController: SearchDisplayController?
    private var searchContentNode: NewsSearchContentNode?
    private var isSearchActive = false

    var requestActivateSearch: (() -> Void)?
    var requestDeactivateSearch: (() -> Void)?
    var openMoreMenu: ((UIView) -> Void)?
    /// A post row's context menu, lifting the row's content out of the list.
    var openPostMenu: ((ContextExtractedContentContainingView, ContextGesture, NewsPostMenu) -> Void)?

    /// VoiceOver: the header (More, For you / Added, Search) first, then the feed and the search results. The header
    /// view spans the whole screen from the top as the lists do, so the frame sort would keep subview order and read
    /// the feed first.
    override var accessibilityElements: [Any]? {
        get {
            guard var elements = super.accessibilityElements else {
                return nil
            }
            if let index = elements.firstIndex(where: { ($0 as AnyObject) === self.headerView }) {
                elements.insert(elements.remove(at: index), at: 0)
            }
            return elements
        } set(value) {
            super.accessibilityElements = value
        }
    }

    init(context: AccountContext, controller: NewsScreen) {
        self.context = context
        self.controller = controller
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.forYou = NewsForYouFeedBinding(context: context)
        self.added = NewsAddedFeedBinding(context: context)
        // For you is the server's; without it the tab opens on Added, which is built on the device.
        if !isNewsFeedServerAvailable(appConfiguration: context.currentAppConfiguration.with { $0 }) {
            self.selectedSegment = 1
        }

        super.init()

        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor

        self.addSubnode(self.listsContainerNode)
        self.listsContainerNode.view.addSubview(self.forYouList)
        self.listsContainerNode.view.addSubview(self.addedList)
        self.forYouList.isHidden = self.selectedSegment != 0
        self.addedList.isHidden = self.selectedSegment != 1
        self.addedOverlayView.isHidden = self.addedList.isHidden
        self.view.addSubview(self.edgeEffectView)
        self.view.addSubview(self.headerView)
        self.headerView.addPageOverlay(self.addedOverlayView)
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
        self.forYouList.accentColor = self.presentationData.theme.list.itemAccentColor

        self.forYouList.onEdgeReached = { [weak self] edge in
            if edge == .bottom {
                self?.forYou.feed.loadMore()
            }
        }
        self.bindScrolling(of: self.forYouList)
        self.bindAddedList(self.addedList)

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
            self.headerView.segmentNode.updateRefreshDrop(pose: pose, theme: self.presentationData.theme)
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
        self.forYouFeedback.vote = { [weak self] vote, messageId in
            self?.castVote(vote, messageId: messageId)
        }

        self.foregroundDisposable = (context.sharedContext.applicationBindings.applicationInForeground
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] inForeground in
            // Only while News is on screen; didAppear revalidates when the user comes back to it.
            if inForeground, let self, self.isScreenVisible {
                self.added.feed.revalidate()
            }
        })

        self.settingsDisposable = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.newsFeedSettings])
        |> map { sharedData -> NewsFeedDisplayMode in
            return (sharedData.entries[ApplicationSpecificSharedDataKeys.newsFeedSettings]?.get(NewsFeedSettings.self) ?? .defaultSettings).displayMode
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] displayMode in
            guard let self else {
                return
            }
            // The stored choice is applied as it is read; a later change (the menu, another screen) morphs the rows.
            self.applyDisplayMode(displayMode, animated: self.hasReceivedDisplayMode)
            self.hasReceivedDisplayMode = true
        })
        self.accountPeerDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self, self.accountPeer != peer else {
                return
            }
            self.accountPeer = peer
            if self.displayMode == .expanded {
                self.updateLists(transition: .immediate)
            }
        })
    }

    deinit {
        self.foregroundDisposable?.dispose()
        self.settingsDisposable?.dispose()
        self.accountPeerDisposable?.dispose()
    }

    // MARK: Display mode (the "…" menu's Compact / Expanded)

    /// The rows morph between the two layouts on the spring a scroll to top runs, so the height changes and the moving
    /// avatars ride one motion.
    private static let displayModeTransition: CoreListTransition = .spring(duration: NewsMorphMotion.duration)

    func setDisplayMode(_ displayMode: NewsFeedDisplayMode) {
        self.applyDisplayMode(displayMode, animated: true)
        let _ = updateNewsFeedSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { settings in
            return settings.withUpdatedDisplayMode(displayMode)
        }).start()
    }

    private func applyDisplayMode(_ displayMode: NewsFeedDisplayMode, animated: Bool) {
        guard displayMode != self.displayMode else {
            return
        }
        self.displayMode = displayMode
        self.rowModeOverrides.removeAll()
        guard animated else {
            self.closeSwipedRows(animated: false)
            self.updateLists(transition: .immediate)
            return
        }
        self.modeHaptic.impact(.medium)
        // An open row the switch morphs closes at once, its content springing back on the morph's spring, in one
        // commit with the passes below: the swipe control renders in explicit transactions of its own, and one of them
        // alone could show the closed row ahead of its morph (the menu's switch runs in a turn of its own).
        CATransaction.begin()
        defer {
            CATransaction.commit()
        }
        self.closeSwipedRowsForMorph(to: displayMode)
        // Read before any pass. A list resting at its top stays there: its first row keeps its place and the rows below
        // grow or shrink downward (`.preserveVisibleContent`, whose witness is that row). Anywhere else the row through
        // the visible area's centre keeps its midpoint while every row changes height (`.preserveCentredContent`), and
        // CoreList keeps the list's ends: no gap opens above the first row or below the last.
        let forYouRestsAtTop = self.restsAtTop(self.forYouList)
        let addedRestsAtTop = self.restsAtTop(self.addedList)
        // Every row the switch carries across the screen morphs, not only the few loaded in both layouts: the rows a
        // taller layout pushes away stay loaded, the rows a shorter one pulls in are laid out first. A list kept at its
        // top changes height below its first row only, so its rows travel up to twice as far as around the centre.
        let shrinks = displayMode == .compact
        let activeRestsAtTop = self.activeList === self.forYouList ? forYouRestsAtTop : addedRestsAtTop
        self.activeList.prepareHeightChange(screens: shrinks || activeRestsAtTop ? 4.0 : 3.0, preloadsRows: shrinks, duration: NewsScreenNode.displayModeTransition.duration)
        // One pass per list: on the page on screen every row's position and height ride one spring; the page off
        // screen switches at once (its morph would be unseen work, and would hold its rows' touches for its length).
        let forYouTransition: CoreListTransition = self.activeList === self.forYouList ? NewsScreenNode.displayModeTransition : .immediate
        let addedTransition: CoreListTransition = self.activeList === self.addedList ? NewsScreenNode.displayModeTransition : .immediate
        self.updateForYouList(transition: forYouTransition, anchorMode: forYouRestsAtTop ? .preserveVisibleContent : .preserveCentredContent)
        self.updateAddedList(transition: addedTransition, anchorMode: addedRestsAtTop ? .preserveVisibleContent : .preserveCentredContent)
        if self.activeList === self.addedList {
            // A pass without a scroll target reports no programmatic scroll (`onProgrammaticScroll`): the read mark
            // and the pill read where the rows will rest.
            self.trackAddedReading(settled: true)
            self.updatePill(transition: .immediate, settled: true)
        }
    }

    /// Whether a switch of the feed's mode keeps `list` at its top (a switch never scrolls a feed resting at its top
    /// away from it, either way): it has no rows, or its first post rests under the open search, or under the tabs with
    /// the search folded.
    private func restsAtTop(_ list: NewsFeedListView) -> Bool {
        if list.items.isEmpty {
            return true
        }
        guard let offset = list.scrollOffset(settled: true).knownValue else {
            return false
        }
        return offset <= (self.headerView.geometry?.blockHeight ?? 0.0) + 0.5
    }

    private func toggleTextExpanded(_ identity: AnyHashable) {
        let expands = !self.expandedTextPosts.contains(identity)
        if expands {
            self.expandedTextPosts.insert(identity)
        } else {
            self.expandedTextPosts.remove(identity)
        }
        let transition = NewsScreenNode.displayModeTransition
        if self.isSearchActive, let searchContentNode = self.searchContentNode {
            // A search result's Show more: its list grows; the feeds under the search take the change at once.
            searchContentNode.textExpansionChanged(identity: identity, expands: expands, transition: transition)
            self.updateLists(transition: .immediate)
            return
        }
        // The post grows by its hidden lines: the rows under it stay loaded and slide down instead of leaving in the
        // pass's first frame (a pass that only reconfigures rows carries nothing out of CoreList's window).
        let list = self.activeList
        if expands, let growth = list.postRow(identity: identity)?.textExpansionGrowth {
            list.prepareHeightChange(travel: growth, preloadsRows: false, duration: transition.duration)
        }
        // Only the list on screen animates.
        self.updateForYouList(transition: list === self.forYouList ? transition : .immediate)
        self.updateAddedList(transition: list === self.addedList ? transition : .immediate)
    }

    private func expandedContent(message: EngineMessage, identity: AnyHashable) -> NewsFeedPostExpandedContent {
        return NewsFeedPostExpandedContent(
            presentationData: self.presentationData,
            accountPeer: self.accountPeer,
            isTextExpanded: self.expandedTextPosts.contains(identity),
            toggleTextExpanded: { [weak self] in
                self?.toggleTextExpanded(identity)
            },
            openUrl: { [weak self] url in
                self?.openUrl(url)
            },
            openMedia: { [weak self] message, _, transition in
                return self?.openMedia(message: message, transition: transition) ?? false
            },
            openPeer: { [weak self] peer in
                self?.openPeer(peer)
            },
            openInstantPage: { [weak self] message in
                self?.openInstantPage(message: message)
            },
            openMessage: { [weak self] messageId in
                self?.openPost(messageId: messageId)
            }
        )
    }

    /// A post by its id (a reply header's target): opened in its chat once the chat's peer is known.
    private func openPost(messageId: EngineMessage.Id) {
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId))
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self, let peer else {
                return
            }
            self.openPost(peer: peer, messageId: messageId)
        })
    }

    private func openUrl(_ url: String) {
        guard let controller = self.controller else {
            return
        }
        let context = self.context
        let navigationController = controller.navigationController as? NavigationController
        let _ = (context.sharedContext.resolveUrl(context: context, peerId: nil, url: url, skipUrlAuth: true)
        |> deliverOnMainQueue).start(next: { [weak self, weak controller] resolved in
            guard let self, let controller else {
                return
            }
            context.sharedContext.openResolvedUrl(resolved, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, forceUpdate: false, openPeer: { [weak self] peer, _ in
                self?.openPeer(peer)
            }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { [weak controller] c, a in
                controller?.present(c, in: .window(.root), with: a)
            }, dismissInput: {
            }, contentContext: nil, progress: nil, completion: nil)
        })
    }

    private func openPeer(_ peer: EnginePeer) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
    }

    /// A photo of the gallery, or media the bubble shows: the media viewer, as a tap in the chat opens it, zooming
    /// out of the row's photo (`transition`) and back into it.
    private func openMedia(message: EngineMessage, transition: NewsGalleryTransition?) -> Bool {
        guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
            return false
        }
        return self.context.sharedContext.openChatMessage(OpenChatMessageParams(context: self.context, chatLocation: .peer(id: message.id.peerId), chatFilterTag: nil, chatLocationContextHolder: nil, message: message._asMessage(), standalone: false, reverseMessageGalleryOrder: false, navigationController: navigationController, dismissInput: {
        }, present: { [weak controller] c, a, _ in
            controller?.present(c, in: .window(.root), with: a)
        }, transitionNode: { _, _, _ in
            return transition.map { ($0.node, $0.bounds, $0.snapshot) }
        }, addToTransitionSurface: { [weak self] view in
            self?.view.addSubview(view)
        }, openUrl: { [weak self] url in
            self?.openUrl(url)
        }, openPeer: { [weak self] peer, _ in
            self?.openPeer(EnginePeer(peer))
        }, callPeer: { _, _ in
        }, openConferenceCall: { _ in
        }, enqueueMessage: { _ in
        }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in
        }, chatAvatarHiddenMedia: { _, _ in
        }))
    }

    /// Forward: the share sheet with the post's messages, as the media viewer forwards.
    private func forward(messages: [EngineMessage]) {
        guard let controller = self.controller else {
            return
        }
        controller.present(self.context.sharedContext.makeShareScreen(context: self.context, params: ShareControllerParams(subject: .messages(messages.map { $0._asMessage() }), showInChat: nil, externalShare: true, immediateExternalShare: false)), in: .window(.root))
    }

    private func openInstantPage(message: EngineMessage) {
        guard let navigationController = self.controller?.navigationController as? NavigationController, let pageController = self.context.sharedContext.makeInstantPageController(context: self.context, message: message, sourcePeerType: nil) else {
            return
        }
        navigationController.pushViewController(pageController)
    }

    override func didLoad() {
        super.didLoad()

        // Swiping between the lists, set up as Peer Info's panes (PeerInfoPaneContainerNode).
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.pagerPanGesture(_:)), allowedDirections: { [weak self] point in
            guard let self, !self.isSearchActive, self.tappedSegment == nil else {
                return []
            }
            // An expanded post's gallery scrolls sideways itself: a swipe on it is the gallery's.
            let activeList = self.activeList
            if activeList.hasHorizontalScrollingRow(at: activeList.convert(point, from: self.listsContainerNode.view)) {
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
            // Added mirrors it: a swipe from a post row's left edge reveals Expand, one from the middle pages back.
            let list = self.addedList
            let pointInList = list.convert(point, from: self.listsContainerNode.view)
            if newsPagerDefersToRowLeftReveal(touchX: pointInList.x, width: list.bounds.width, leftInset: list.insets.left, rightInset: list.insets.right, isOnRevealableRow: list.hasLeftSwipeableRow(at: pointInList)) {
                return []
            }
            return .right
        })
        panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        self.listsContainerNode.view.addGestureRecognizer(panRecognizer)

        // Pinching the feed switches Compact and Expanded. The pager takes one touch, so the two never meet.
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.pinchGesture(_:)))
        pinchRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        self.listsContainerNode.view.addGestureRecognizer(pinchRecognizer)
        self.pinchRecognizer = pinchRecognizer
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.pinchRecognizer {
            return !self.isSearchActive && self.tappedSegment == nil && !self.isPagerDragging && self.pagerFraction == 0.0
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // The pinch rides the list's scroll, as a pinch on Photos' grid does; the pager stays exclusive.
        if gestureRecognizer === self.pinchRecognizer {
            return !(otherGestureRecognizer is InteractiveTransitionGestureRecognizer)
        }
        return false
    }

    // The lists' scrolling waits for the swipe to fail, as it waits for the navigation back swipe. Not for the pinch:
    // a single finger would then scroll only once the pinch gave up on a second one.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.pinchRecognizer || otherGestureRecognizer is InteractiveTransitionGestureRecognizer {
            return false
        }
        return otherGestureRecognizer is UIPanGestureRecognizer
    }

    // MARK: Pinch (Compact ↔ Expanded)

    @objc private func pinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.refreshController.detach()
            self.closeSwipedRows(animated: true)
            // A finger resting on a row while the other lands is a long press until here: the pinch has it now.
            self.activeList.cancelContextGestures()
            self.pinchState = NewsFeedPinchState()
            self.modeHaptic.prepareImpact(.medium)
            // The search block folds under the top row first, so the scaled feed does not pass through it. A list that
            // rested at its top with the search open gets it back once the pinch is over.
            self.searchFoldedByPinch = nil
            if let geometry = self.headerView.geometry, self.headerView.blockOffset < geometry.blockHeight {
                if let offset = self.activeList.scrollOffset(settled: true).knownValue, offset <= 0.5 {
                    self.searchFoldedByPinch = self.activeList
                }
                self.activeList.scroll(toIndex: 0, pointOffset: -geometry.blockHeight, transition: CoreListTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))
            }
            self.setFeedScale(newsFeedPinchScale(progress: newsFeedPinchProgress(ratio: recognizer.scale)), transition: .immediate)
        case .changed:
            let progress = newsFeedPinchProgress(ratio: recognizer.scale)
            self.setFeedScale(newsFeedPinchScale(progress: progress), transition: .immediate)
            if self.pinchState.update(progress: progress) {
                // Out expands, in compacts, as Photos zooms its grid; toward the mode on screen the feed only gives.
                // The rows morph while the feed is still held scaled: the switch is seen where the fingers are.
                let displayMode: NewsFeedDisplayMode = progress > 0.0 ? .expanded : .compact
                if displayMode != self.displayMode {
                    self.setDisplayMode(displayMode)
                }
            }
        case .ended, .cancelled, .failed:
            self.setFeedScale(1.0, transition: .animated(duration: 0.5, curve: .spring))
            self.openSearchFoldedByPinch()
        default:
            break
        }
    }

    private var isPinching: Bool {
        switch self.pinchRecognizer?.state {
        case .began?, .changed?:
            return true
        default:
            return false
        }
    }

    /// Opens a search the pinch folded once the pinch is over and the list rests: no finger on it (the list's pan rides
    /// the pinch and can outlive it) and no momentum, or `onScrollingEnded` asks again when they end. A list still
    /// within the fold goes back to its top on the 0.5 s spring, as a scroll to top does, and the header unfolds with
    /// it; one the user scrolled on past the fold keeps its place. Returns whether it scrolled.
    @discardableResult
    private func openSearchFoldedByPinch() -> Bool {
        guard let list = self.searchFoldedByPinch, !self.isPinching, !list.isDragging, !list.coreList.isScrollDecelerating else {
            return false
        }
        self.searchFoldedByPinch = nil
        guard list === self.activeList, !self.isSearchActive, let geometry = self.headerView.geometry, let offset = list.scrollOffset(settled: true).knownValue, offset > 0.5, offset <= geometry.blockHeight + 0.5 else {
            return false
        }
        list.scrollToTop()
        return true
    }

    /// Scales the lists' container about its centre (a sublayer transform is applied about the layer's anchor point),
    /// so the feed shrinks evenly from every edge.
    private func setFeedScale(_ scale: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateSublayerTransformScale(node: self.listsContainerNode, scale: scale, beginWithCurrentState: true)
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
            self.addedOverlayView.isHidden = false
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
            // The header followed a blend of both lists during the swipe: back to the selected list's own offset,
            // whatever the blend ended on.
            self.updateNavigationScrolling(offset: self.navigationScrollOffset(settled: true), transition: ComponentTransition(transition))
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
        self.forYouList.accentColor = presentationData.theme.list.itemAccentColor
        self.addedList.accentColor = presentationData.theme.list.itemAccentColor
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

    /// The tab bar's scroll to top, and a tap on the selected tab.
    func scrollToTop() {
        if self.selectedSegment == 1 {
            self.goToTopOfAdded()
        } else {
            self.activeList.scrollToTop()
        }
    }

    /// Added's way to its top is the New posts pill's: a scroll when the newest post is loaded, otherwise a jump to
    /// the newest page.
    private func goToTopOfAdded() {
        if self.added.jump != nil || self.added.beginJump() {
            return
        }
        self.addedList.scrollToTop()
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
                self.scrollToTop()
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
        // A search the pinch folded on the page being left stays folded.
        self.searchFoldedByPinch = nil
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
        let pages: [[UIView]] = [[self.forYouList], [self.addedList, self.addedOverlayView]]
        for (index, views) in pages.enumerated() {
            let frame = CGRect(origin: CGPoint(x: (CGFloat(index - self.selectedSegment) + self.pagerFraction) * layout.size.width, y: 0.0), size: layout.size)
            for view in views {
                if view.bounds.size != frame.size {
                    // Only the position animates.
                    view.frame = CGRect(origin: view.frame.origin, size: frame.size)
                }
                if index == self.selectedSegment || isPaging {
                    view.isHidden = false
                }
                transition.updateFrame(view: view, frame: frame, completion: { [weak self, weak view] _ in
                    guard let self, let view else {
                        return
                    }
                    if index != self.selectedSegment && !self.isPagerDragging && self.pagerFraction == 0.0 {
                        view.isHidden = true
                    }
                })
            }
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
        // For you's rows swipe both ways and have the "Post hidden" flow; Added's swipe for Expand only; search
        // results do neither.
        let segment: Int? = list === self.forYouList ? 0 : (list === self.addedList ? 1 : nil)
        let feedbackController: NewsPostFeedbackController? = segment == 0 ? self.forYouFeedback : nil
        var postSwipe: ((EnginePeer, EngineMessage.Id, AnyHashable) -> NewsPostSwipe)?
        var feedback: NewsFeedItemFeedback?
        if let segment {
            postSwipe = { [weak self, weak list, weak feedbackController] peer, messageId, post in
                return NewsPostSwipe(hasFeedbackActions: segment == 0, action: { action in
                    self?.postSwipeAction(action, peer: peer, messageId: messageId, post: post, segment: segment, feedback: feedbackController)
                }, opened: { row in
                    list?.closeSwipedRows(except: row, animated: true)
                }, separatorAlphaChanged: { _ in
                    list?.updateSwipeSeparators()
                })
            }
        }
        if let feedbackController {
            feedback = NewsFeedItemFeedback(state: feedbackController.state, tab: feedbackController.tab, postAppearTimes: feedbackController.postAppearTimes, panelAppearTimes: feedbackController.panelAppearTimes, undo: { [weak feedbackController] post, channel in
                feedbackController?.undo(post: post, channel: channel)
            }, choose: { [weak feedbackController] post, channel, choice in
                feedbackController?.choose(post: post, channel: channel, choice: choice)
            })
        }
        // A long press: For you's votes (the swipe's actions), then opening the post in its chat and forwarding it.
        let postContextMenu: (NewsFeedPostComponent.View, ContextGesture, EnginePeer, [EngineMessage], AnyHashable) -> Void = { [weak self, weak feedbackController] row, gesture, peer, messages, post in
            guard let self, let first = messages.first else {
                return
            }
            self.openPostMenu?(row.contextContentView, gesture, NewsPostMenu(hasFeedbackActions: segment == 0, interesting: { [weak self] in
                self?.castVote(.like, messageId: first.id)
            }, notInterested: { [weak feedbackController] in
                feedbackController?.notInterested(post: post, messageId: first.id)
            }, showInChat: { [weak self] in
                self?.openPost(peer: peer, messageId: first.id)
            }, forward: { [weak self] in
                self?.forward(messages: messages)
            }))
        }
        return NewsFeedItemEnvironment(context: self.context, presentationData: self.presentationData, skeletonRowLayout: self.skeletonRowLayout(), rowLoading: list.rowLoading, openPost: { [weak self] peer, messageId in
            self?.openPost(peer: peer, messageId: messageId)
        }, postSwipe: postSwipe, feedback: feedback, postContextMenu: postContextMenu, floatingAvatarsChanged: { [weak self] in
            self?.updateHeaderHoles()
        }, displayMode: self.displayMode, rowModeOverrides: segment.flatMap { self.rowModeOverrides[$0] } ?? [], expandedContent: { [weak self] message, identity in
            return self?.expandedContent(message: message, identity: identity)
        })
    }

    /// A post row's swipe action (spec §3). Interesting likes the post; Not Interested starts the tab's "Post hidden"
    /// flow, which dislikes it. Expand and Collapse (the left side) switch that one row's mode, morphing it as the
    /// feed's switch does.
    private func postSwipeAction(_ action: NewsPostSwipeAction, peer: EnginePeer, messageId: EngineMessage.Id, post: AnyHashable, segment: Int, feedback: NewsPostFeedbackController?) {
        switch action {
        case .notInterested:
            feedback?.notInterested(post: post, messageId: messageId)
        case .interesting:
            self.castVote(.like, messageId: messageId)
        case .expand, .collapse:
            var overrides = self.rowModeOverrides[segment] ?? []
            if overrides.contains(post) {
                overrides.remove(post)
            } else {
                overrides.insert(post)
            }
            self.rowModeOverrides[segment] = overrides
            self.modeHaptic.impact(.medium)
            // The rows the swiped one pushes away stay loaded and the rows it pulls in are laid out first, so every row
            // it moves slides.
            let list = segment == 0 ? self.forYouList : self.addedList
            list.prepareHeightChange(screens: 1.5, preloadsRows: action == .collapse, duration: NewsScreenNode.displayModeTransition.duration)
            let anchorMode = self.rowModeAnchor(post: post, in: list)
            // Only the swiped list's rows change height, so the other list keeps its own anchor.
            self.updateForYouList(transition: NewsScreenNode.displayModeTransition, anchorMode: segment == 0 ? anchorMode : .automatic)
            self.updateAddedList(transition: NewsScreenNode.displayModeTransition, anchorMode: segment == 1 ? anchorMode : .preserveVisibleContent)
        }
    }

    /// How one row's Expand / Collapse keeps its list in place: the swiped row keeps its top, so it grows or shrinks
    /// downward where it was swiped, and one partly under the header lands on the list's top inset, in view
    /// (`.preserveItem`). That inset is the resting header's edge, the search's height below the header's while the
    /// search is folded: a row whose top shows between the two edges would drop onto the lower one, so it keeps its top
    /// as the row crossing the inset edge instead (`.preserveVisibleContent`'s witness).
    private func rowModeAnchor(post: AnyHashable, in list: NewsFeedListView) -> CoreListAnchorMode {
        let headerBottom = list.insets.top - self.headerView.blockOffset
        if let index = list.items.firstIndex(where: { $0.identity == post }), let row = list.visibleRowFrames(settled: true).first(where: { $0.index == index }), row.frame.minY >= headerBottom - 0.5, row.frame.minY < list.insets.top {
            return .preserveVisibleContent
        }
        return .preserveItem(post)
    }

    private func castVote(_ vote: NewsPostVote, messageId: EngineMessage.Id) {
        if let request = self.voteQueue.cast(vote, messageId: messageId) {
            self.sendVote(request)
        }
    }

    private func sendVote(_ request: NewsPostVoteRequest) {
        let feed = self.context.engine.feed
        let signal: Signal<Never, NoError>
        switch request.vote {
        case .like:
            signal = feed.likePost(id: request.messageId)
        case .dislike:
            signal = feed.dislikePost(id: request.messageId)
        }
        // Not tied to the screen: a vote that was cast goes out.
        let _ = (signal
        |> deliverOnMainQueue).start(completed: { [weak self] in
            guard let self, let next = self.voteQueue.finished() else {
                return
            }
            self.sendVote(next)
        })
    }

    /// The header follows the selected list's scrolling.
    private func bindScrolling(of list: NewsFeedListView) {
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
            // Where the list rests, in case a programmatic pass landed short of what it reported (a list too
            // short to fold the search away): the header never stays folded over an unfolded list.
            self.updateNavigationScrolling(offset: self.navigationScrollOffset(settled: false), transition: .immediate)
            // A search the pinch folded opens once the list rests after it; otherwise a half-hidden one snaps.
            if !self.openSearchFoldedByPinch() {
                self.snapNavigationBar()
            }
        }
    }

    private func bindAddedList(_ list: NewsFeedListView) {
        list.reduceMotion = self.presentationData.reduceMotion
        list.accentColor = self.presentationData.theme.list.itemAccentColor
        list.onEdgeReached = { [weak self] edge in
            switch edge {
            case .top:
                self?.added.feed.loadNewer()
            case .bottom:
                self?.added.feed.loadOlder()
            }
        }
        self.bindScrolling(of: list)
        list.onVisibleRowsChanged = { [weak self] in
            guard let self else {
                return
            }
            self.trackAddedReading()
            self.updatePill(transition: .immediate)
        }
        list.onProgrammaticScroll = { [weak self] in
            guard let self else {
                return
            }
            self.trackAddedReading(settled: true)
            self.updatePill(transition: .immediate, settled: true)
        }
        list.onWillBeginDragging = { [weak self] in
            self?.addedUserScrolledSinceReposition = true
        }
    }

    /// Closes an open swipe in either feed (spec §5).
    private func closeSwipedRows(animated: Bool) {
        self.forYouList.closeSwipedRows(animated: animated)
        self.addedList.closeSwipedRows(animated: animated)
    }

    /// Closes an open swipe in either feed for a switch to `displayMode`: at once on a row the switch morphs.
    private func closeSwipedRowsForMorph(to displayMode: NewsFeedDisplayMode) {
        self.forYouList.closeSwipedRowsForMorph(to: displayMode)
        self.addedList.closeSwipedRowsForMorph(to: displayMode)
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
        if self.added.jump == .loading && self.appliedAddedJump == nil {
            self.replaceAddedListForJump()
        }
        let environment = self.itemEnvironment(list: self.addedList)
        self.addedRows = self.added.rows(environment: environment)
        self.addedHasPosts = !self.addedRows.isLoading && self.addedRows.hasPostRows
        var listTransition = transition
        var scrollTo: CoreListScrollTarget?
        // The newest posts fade and rise in as after a reload; the posts the feed had come back without.
        let jump = self.added.jump
        self.addedList.setShowsSkeleton(self.addedRows.isLoading, revealCascades: jump != .localTop, theme: environment.presentationData.theme, rowLayout: environment.skeletonRowLayout)
        if jump == .localTop {
            // At their top, under the skeleton fading out.
            scrollTo = CoreListScrollTarget(index: 0, pointOffset: 0.0)
        }
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
        if scrollTo != nil {
            listTransition = .immediate
        }
        if jump == .loading && self.appliedAddedJump == nil {
            // The header unfolds with the slide.
            listTransition = NewsScreenNode.addedJumpCoreListTransition
        }
        self.addedList.update(size: layout.size, insets: self.listInsets, items: self.addedRows.items, scrollTo: scrollTo, anchorMode: anchorMode, animatesInsertions: animatesInsertions, transition: listTransition)
        if jump == .loading {
            self.appliedAddedJump = jump
        } else {
            if jump != nil {
                self.added.endJump()
            }
            self.appliedAddedJump = nil
        }

        self.recheckAddedEdgesIfGrown(count: self.addedRows.items.count)
        self.updatePill(transition: .immediate)
        self.trackAddedReading()
    }

    /// The jump's slide, on the spring a scroll to top runs (CoreList and ComponentFlow emit the same one at 0.5 s), so
    /// the header unfolds with it.
    private static let addedJumpTransition: ComponentTransition = .spring(duration: 0.5)
    private static let addedJumpCoreListTransition: CoreListTransition = .spring(duration: 0.5)

    /// A jump to the newest posts: the list being read stops updating and slides down out of the screen, cut at its
    /// topmost post's top edge so only the posts on screen leave, while a new list slides in on top of it, with its
    /// skeleton, to the top. The new list is the Added list from now on.
    private func replaceAddedListForJump() {
        let oldList = self.addedList
        let newList = NewsFeedListView()
        newList.frame = oldList.frame
        newList.isHidden = oldList.isHidden
        self.listsContainerNode.view.insertSubview(newList, aboveSubview: oldList)
        oldList.detach()
        self.addedList = newList
        self.bindAddedList(newList)

        let height = oldList.bounds.height
        // The topmost post showing below the header; rows wholly under the header stay behind.
        let headerBottom = self.headerView.currentBottom
        let clipY = oldList.visibleRowFrames().filter({ $0.frame.maxY > headerBottom }).map(\.frame.minY).min() ?? self.listInsets.top
        let mask = CALayer()
        mask.backgroundColor = UIColor.black.cgColor
        mask.frame = CGRect(x: 0.0, y: clipY, width: oldList.bounds.width, height: max(0.0, height - clipY))
        oldList.layer.mask = mask

        // Both travel the same distance, so the new list's bottom stays on the old one's cut: the old one leaves at the
        // bottom of the screen as the new one lands. The skeleton reaches below the new list's bounds by the top inset,
        // so the list is clipped while it slides.
        let distance = height - clipY
        let transition = NewsScreenNode.addedJumpTransition
        oldList.center = CGPoint(x: oldList.center.x, y: oldList.center.y + distance)
        transition.animatePosition(view: oldList, from: CGPoint(x: 0.0, y: -distance), to: CGPoint(), additive: true, completion: { [weak oldList] _ in
            oldList?.removeFromSuperview()
        })
        newList.clipsToBounds = true
        transition.animatePosition(view: newList, from: CGPoint(x: 0.0, y: -distance), to: CGPoint(), additive: true, completion: { [weak newList] _ in
            newList?.clipsToBounds = false
        })
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
        // Debug Settings' Skip Read History, as chats and stories follow it.
        guard self.isScreenVisible, self.selectedSegment == 1, !self.isSearchActive, !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory else {
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
        // The pill lives on the Added page, so it shows only where that page does, and slides with it. A jump in
        // progress is its action already under way.
        if !self.isSearchActive, self.added.jump == nil, let state = self.added.state {
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
                self.addedOverlayView.addSubview(view)
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
        self.goToTopOfAdded()
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
        // Blended up to the search's full fold, so mid-swipe it can still be scrolled entirely away.
        return .known(newsPagerHeaderOffset(current: current.knownValue, next: next.knownValue, progress: abs(self.pagerFraction), foldHeight: geometry.blockHeight))
    }

    private func updateNavigationScrolling(offset scrollOffset: NewsFeedListView.ScrollOffset, transition: ComponentTransition) {
        var offset: CGFloat
        switch scrollOffset {
        case let .known(value):
            offset = value
        case .unknown:
            // The first row is not loaded: the list is scrolled well past the search, which is folded away.
            offset = self.headerView.geometry?.blockHeight ?? 0.0
        }
        if self.isSearchActive {
            offset = 0.0
        }
        self.headerView.applyScroll(listOffset: offset, transition: transition)
        self.updatePillPosition(transition: transition)
        // The floating avatars follow the header's edge, which the search block's travel has just moved.
        let floatingTop = self.headerView.currentBottom
        self.forYouList.setFloatingTopInset(floatingTop)
        self.addedList.setFloatingTopInset(floatingTop)
        self.updateHeaderHoles()
    }

    /// The header's edge effects leave the avatars stuck at its edge crisp: a hole for each (an avatar riding its
    /// run under the header passes beneath them, as content does).
    private func updateHeaderHoles() {
        guard !self.isSearchActive else {
            self.headerView.updateEdgeHoles([])
            return
        }
        let list = self.activeList
        self.headerView.updateEdgeHoles(list.stuckFloatingAvatarFrames().map { list.convert($0, to: self.headerView) })
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

    // MARK: Search (as ContactsControllerNode, with the server's For you search as its results)

    func activateSearch(placeholderNode: SearchBarPlaceholderNode?) {
        guard let (layout, navigationBarHeight) = self.validLayout, self.searchDisplayController == nil else {
            return
        }
        self.refreshController.detach()
        self.closeSwipedRows(animated: false)
        self.isSearchActive = true

        let contentNode = NewsSearchContentNode(context: self.context, presentationData: self.presentationData, itemEnvironment: { [weak self] list in
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
