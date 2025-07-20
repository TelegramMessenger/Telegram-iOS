import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramCore
import Postbox
import TelegramPresentationData
import ComponentDisplayAdapters
import AccountContext
import SwiftSignalKit
import TelegramStringFormatting
import ShimmerEffect
import PeerListItemComponent
import AnimatedStickerComponent
import AvatarNode
import Markdown
import ButtonComponent
import NavigationSearchComponent
import TabSelectorComponent
import OptionButtonComponent
import ContextUI
import BalancedTextComponent
import LottieComponent

private func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? ContextGesture {
                gesture.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelContextGestures(view: subview)
    }
}

final class StoryItemSetViewListComponent: Component {
    final class AnimationHint {
        let synchronous: Bool
        
        init(synchronous: Bool) {
            self.synchronous = synchronous
        }
    }
    
    final class SharedListsContext {
        var viewLists: [StoryId: EngineStoryViewListContext] = [:]
        
        init() {
        }
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let sharedListsContext: SharedListsContext
    let peerId: EnginePeer.Id
    let safeInsets: UIEdgeInsets
    let storyItem: EngineStoryItem
    let hasPremium: Bool
    let effectiveHeight: CGFloat
    let minHeight: CGFloat
    let availableReactions: StoryAvailableReactions?
    let isSearchActive: Bool
    let close: () -> Void
    let expandViewStats: () -> Void
    let deleteAction: () -> Void
    let moreAction: (UIView, ContextGesture?) -> Void
    let openPeer: (EnginePeer) -> Void
    let openMessage: (EnginePeer, EngineMessage.Id) -> Void
    let peerContextAction: (EnginePeer, ContextExtractedContentContainingView, ContextGesture) -> Void
    let openPeerStories: (EnginePeer, AvatarNode) -> Void
    let openReposts: (EnginePeer, Int32, UIView) -> Void
    let openPremiumIntro: () -> Void
    let setIsSearchActive: (Bool) -> Void
    let controller: () -> ViewController?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        sharedListsContext: SharedListsContext,
        peerId: EnginePeer.Id,
        safeInsets: UIEdgeInsets,
        storyItem: EngineStoryItem,
        hasPremium: Bool,
        effectiveHeight: CGFloat,
        minHeight: CGFloat,
        availableReactions: StoryAvailableReactions?,
        isSearchActive: Bool,
        close: @escaping () -> Void,
        expandViewStats: @escaping () -> Void,
        deleteAction: @escaping () -> Void,
        moreAction: @escaping (UIView, ContextGesture?) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openMessage: @escaping (EnginePeer, EngineMessage.Id) -> Void,
        peerContextAction: @escaping (EnginePeer, ContextExtractedContentContainingView, ContextGesture) -> Void,
        openPeerStories: @escaping (EnginePeer, AvatarNode) -> Void,
        openReposts: @escaping (EnginePeer, Int32, UIView) -> Void,
        openPremiumIntro: @escaping () -> Void,
        setIsSearchActive: @escaping (Bool) -> Void,
        controller: @escaping () -> ViewController?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.sharedListsContext = sharedListsContext
        self.peerId = peerId
        self.safeInsets = safeInsets
        self.storyItem = storyItem
        self.hasPremium = hasPremium
        self.effectiveHeight = effectiveHeight
        self.minHeight = minHeight
        self.availableReactions = availableReactions
        self.isSearchActive = isSearchActive
        self.close = close
        self.expandViewStats = expandViewStats
        self.deleteAction = deleteAction
        self.moreAction = moreAction
        self.openPeer = openPeer
        self.openMessage = openMessage
        self.peerContextAction = peerContextAction
        self.openPeerStories = openPeerStories
        self.openReposts = openReposts
        self.openPremiumIntro = openPremiumIntro
        self.setIsSearchActive = setIsSearchActive
        self.controller = controller
    }

    static func ==(lhs: StoryItemSetViewListComponent, rhs: StoryItemSetViewListComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.storyItem != rhs.storyItem {
            return false
        }
        if lhs.hasPremium != rhs.hasPremium {
            return false
        }
        if lhs.effectiveHeight != rhs.effectiveHeight {
            return false
        }
        if lhs.minHeight != rhs.minHeight {
            return false
        }
        if lhs.availableReactions !== rhs.availableReactions {
            return false
        }
        if lhs.isSearchActive != rhs.isSearchActive {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var availableSize: CGSize
        var bottomInset: CGFloat
        var topInset: CGFloat
        var sideInset: CGFloat
        var itemHeight: CGFloat
        var itemCount: Int
        var premiumFooterSize: CGSize?
        var isSearchActive: Bool
        
        var contentSize: CGSize
        
        init(containerSize: CGSize, availableSize: CGSize, bottomInset: CGFloat, topInset: CGFloat, sideInset: CGFloat, itemHeight: CGFloat, itemCount: Int, premiumFooterSize: CGSize?, isSearchActive: Bool) {
            self.containerSize = containerSize
            self.availableSize = availableSize
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.sideInset = sideInset
            self.itemHeight = itemHeight
            self.itemCount = itemCount
            self.premiumFooterSize = premiumFooterSize
            self.isSearchActive = isSearchActive
            
            self.contentSize = CGSize(width: containerSize.width, height: topInset + CGFloat(itemCount) * itemHeight + bottomInset)
            if let premiumFooterSize {
                self.contentSize.height += 13.0 + premiumFooterSize.height + 12.0
            }
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: 0.0, dy: -self.topInset)
            var minVisibleRow = Int(floor((offsetRect.minY) / (self.itemHeight)))
            minVisibleRow = max(0, minVisibleRow)
            let maxVisibleRow = Int(ceil((offsetRect.maxY) / (self.itemHeight)))
            
            let minVisibleIndex = minVisibleRow
            let maxVisibleIndex = maxVisibleRow
            
            if maxVisibleIndex >= minVisibleIndex {
                return minVisibleIndex ..< (maxVisibleIndex + 1)
            } else {
                return nil
            }
        }
        
        func itemFrame(for index: Int) -> CGRect {
            return CGRect(origin: CGPoint(x: 0.0, y: self.topInset + CGFloat(index) * self.itemHeight), size: CGSize(width: self.containerSize.width, height: self.itemHeight))
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class EventCycleState {
        var ignoreScrolling: Bool = false
        
        init() {
        }
    }
    
    private enum ListMode: Int {
        case everyone = 0
        case contacts = 1
    }
    
    private enum SortMode: Int {
        case repostsFirst = 0
        case reactionsFirst = 1
        case recentFirst = 2
        
        var sortMode: EngineStoryViewListContext.SortMode {
            switch self {
            case .repostsFirst:
                return .repostsFirst
            case .reactionsFirst:
                return .reactionsFirst
            case .recentFirst:
                return .recentFirst
            }
        }
    }
    
    private struct ContentConfigurationKey: Equatable {
        var listMode: ListMode
        var sortMode: SortMode
        
        init(listMode: ListMode, sortMode: SortMode) {
            self.listMode = listMode
            self.sortMode = sortMode
        }
    }
    
    private final class ContentView: UIView, UIScrollViewDelegate {
        let configuration: ContentConfigurationKey
        var query: String?
        
        var stateComponent: StoryItemSetViewListComponent?
        var component: StoryItemSetViewListComponent?
        weak var state: EmptyComponentState?
        
        let measureItem = ComponentView<Empty>()
        var placeholderImage: UIImage?
        
        var visibleItems: [EngineStoryViewListContext.Item.ItemHash: ComponentView<Empty>] = [:]
        var visiblePlaceholderViews: [Int: UIImageView] = [:]
        
        var emptyIcon: ComponentView<Empty>?
        var emptyText: ComponentView<Empty>?
        var emptyButton: ComponentView<Empty>?
        
        var premiumFooterText: ComponentView<Empty>?
        
        let scrollView: UIScrollView
        var itemLayout: ItemLayout?
        
        var ignoreScrolling: Bool = false
        
        var viewListDisposable: Disposable?
        var viewList: EngineStoryViewListContext?
        var viewListState: EngineStoryViewListContext.State?
        var requestedLoadMoreToken: EngineStoryViewListContext.LoadMoreToken?
        
        private var previewedItemDisposable: Disposable?
        private var previewedItemId: StoryId?
        
        var eventCycleState: EventCycleState?
        
        var totalCount: Int? {
            return self.viewListState?.totalCount
        }
        
        var hasContent: Bool = false
        var hasContentUpdated: ((Bool) -> Void)?
        
        var contentLoaded: Bool = false
        var contentLoadedUpdated: ((Bool) -> Void)?
        
        var dismissInput: (() -> Void)?
        
        var navigationSearch: ComponentView<Empty>?
        var updateQuery: ((String) -> Void)?
        var navigationBarBackground: BlurredBackgroundView?
        var navigationSeparator: SimpleLayer?
        var backgroundView: UIView?
        
        var navigationHeight: CGFloat?
        var navigationSearchPartHeight: CGFloat?
        
        init(configuration: ContentConfigurationKey) {
            self.configuration = configuration
            
            self.scrollView = ScrollView()
            self.scrollView.canCancelContentTouches = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.indicatorStyle = .white
            
            super.init(frame: CGRect())
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.viewListDisposable?.dispose()
            self.previewedItemDisposable?.dispose()
        }
        
        func setPreviewedItem(signal: Signal<StoryId?, NoError>) {
            self.previewedItemDisposable?.dispose()
            self.previewedItemDisposable = (signal |> distinctUntilChanged |> deliverOnMainQueue).start(next: { [weak self] previewedItemId in
                guard let self else {
                    return
                }
                self.previewedItemId = previewedItemId
                
                for (itemId, visibleItem) in self.visibleItems {
                    if let itemView = visibleItem.view as? PeerListItemComponent.View {
                        let isPreviewing = itemId.peerId == previewedItemId?.peerId && itemId.storyId == previewedItemId?.id
                        itemView.updateIsPreviewing(isPreviewing: isPreviewing)
                        
                        if isPreviewing {
                            let itemFrame = itemView.frame.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                            if !self.scrollView.bounds.intersects(itemFrame.insetBy(dx: 0.0, dy: 20.0)) {
                                self.scrollView.scrollRectToVisible(itemFrame.insetBy(dx: 0.0, dy: -40.0), animated: false)
                            }
                        }
                    }
                }
            })
        }
        
        func sourceView(storyId: StoryId) -> UIView? {
            for (itemId, visibleItem) in self.visibleItems {
                if let itemView = visibleItem.view as? PeerListItemComponent.View {
                    if itemId.peerId == storyId.peerId && itemId.storyId == storyId.id {
                        return itemView.imageNode?.view
                    }
                }
            }
            return nil
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                if let eventCycleState = self.eventCycleState {
                    if eventCycleState.ignoreScrolling {
                        self.ignoreScrolling = true
                        scrollView.contentOffset = CGPoint()
                        self.ignoreScrolling = false
                        return
                    }
                }
                
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            if let eventCycleState = self.eventCycleState {
                if eventCycleState.ignoreScrolling {
                    targetContentOffset.pointee.y = 0.0
                }
            } else {
                if let navigationSearchPartHeight = self.navigationSearchPartHeight, navigationSearchPartHeight > 0.0 {
                    if targetContentOffset.pointee.y < navigationSearchPartHeight {
                        if targetContentOffset.pointee.y < navigationSearchPartHeight * 0.5 {
                            targetContentOffset.pointee.y = 0.0
                        } else {
                            targetContentOffset.pointee.y = navigationSearchPartHeight
                        }
                    }
                }
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            if let navigationSearchPartHeight = self.navigationSearchPartHeight, navigationSearchPartHeight > 0.0 {
                if scrollView.contentOffset.y < navigationSearchPartHeight {
                    if scrollView.contentOffset.y < navigationSearchPartHeight * 0.5 {
                        scrollView.setContentOffset(CGPoint(), animated: true)
                    } else {
                        scrollView.setContentOffset(CGPoint(x: 0.0, y: navigationSearchPartHeight), animated: true)
                    }
                }
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            cancelContextGestures(view: scrollView)
            
            self.dismissInput?()
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            let actualBounds = self.scrollView.bounds
            let visibleBounds = actualBounds//.insetBy(dx: 0.0, dy: -200.0)
            
            var synchronousLoad = false
            if let hint = transition.userData(PeerListItemComponent.TransitionHint.self) {
                synchronousLoad = hint.synchronousLoad
            }
            
            var validIds: [EngineStoryViewListContext.Item.ItemHash] = []
            var validPlaceholderIds: [Int] = []
            if let range = itemLayout.visibleItems(for: visibleBounds) {
                for index in range.lowerBound ..< range.upperBound {
                    guard let viewListState = self.viewListState else {
                        continue
                    }
                    
                    #if DEBUG && false
                    #else
                    if index >= viewListState.totalCount {
                        continue
                    }
                    #endif
                    
                    /*if "".isEmpty {
                        if index > range.lowerBound - 1 {
                            break
                        }
                    }*/
                    
                    let itemFrame = itemLayout.itemFrame(for: index)
                    
                    if index >= viewListState.items.count {
                        validPlaceholderIds.append(index)
                        
                        let placeholderView: UIImageView
                        if let current = self.visiblePlaceholderViews[index] {
                            placeholderView = current
                        } else {
                            placeholderView = UIImageView()
                            self.visiblePlaceholderViews[index] = placeholderView
                            self.scrollView.addSubview(placeholderView)
                            
                            placeholderView.image = self.placeholderImage
                        }
                        
                        placeholderView.frame = itemFrame
                        
                        continue
                    }
                    
                    var itemTransition = transition.withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: true))
                    let item = viewListState.items[index]
                    validIds.append(item.uniqueId)
                    
                    let visibleItem: ComponentView<Empty>
                    if let current = self.visibleItems[item.uniqueId] {
                        visibleItem = current
                    } else {
                        if !transition.animation.isImmediate {
                            itemTransition = .immediate
                        }
                        visibleItem = ComponentView()
                        self.visibleItems[item.uniqueId] = visibleItem
                    }
                    
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    var dateText = humanReadableStringForTimestamp(strings: component.strings, dateTimeFormat: presentationData.dateTimeFormat, timestamp: item.timestamp, alwaysShowTime: true, allowYesterday: true, format: HumanReadableStringFormat(
                        dateFormatString: { value in
                            return PresentationStrings.FormattedString(string: component.strings.Chat_MessageSeenTimestamp_Date(value).string, ranges: [])
                        },
                        tomorrowFormatString: { value in
                            return PresentationStrings.FormattedString(string: component.strings.Chat_MessageSeenTimestamp_TodayAt(value).string, ranges: [])
                        },
                        todayFormatString: { value in
                            return PresentationStrings.FormattedString(string: component.strings.Chat_MessageSeenTimestamp_TodayAt(value).string, ranges: [])
                        },
                        yesterdayFormatString: { value in
                            return PresentationStrings.FormattedString(string: component.strings.Chat_MessageSeenTimestamp_YesterdayAt(value).string, ranges: [])
                        }
                    )).string
                    
                    if let story = item.story, !story.text.isEmpty {
                        dateText += component.strings.Story_Views_Commented
                    }
                    
                    let subtitleAccessory: PeerListItemComponent.SubtitleAccessory
                    if let _ = item.story {
                        subtitleAccessory = .repost
                    } else if let _ = item.message {
                        subtitleAccessory = .forward
                    } else {
                        subtitleAccessory = .checks
                    }
                    
                    var storyItem: EngineStoryItem?
                    if let story = item.story {
                        storyItem = story
                    } else if let _ = item.message {
                        storyItem = component.storyItem
                    }
                    
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(PeerListItemComponent(
                            context: component.context,
                            theme: component.theme,
                            strings: component.strings,
                            style: .generic,
                            sideInset: 0.0,
                            title: item.peer.displayTitle(strings: component.strings, displayOrder: .firstLast),
                            peer: item.peer,
                            storyStats: item.storyStats,
                            subtitle: PeerListItemComponent.Subtitle(text: dateText, color: .neutral),
                            subtitleAccessory: subtitleAccessory,
                            presence: nil,
                            reaction: item.reaction.flatMap { reaction -> PeerListItemComponent.Reaction in
                                var animationFileId: Int64?
                                var animationFile: TelegramMediaFile?
                                switch reaction {
                                case .builtin:
                                    if let availableReactions = component.availableReactions {
                                        for availableReaction in availableReactions.reactionItems {
                                            if availableReaction.reaction.rawValue == reaction {
                                                animationFile = availableReaction.listAnimation._parse()
                                                break
                                            }
                                        }
                                    }
                                case let .custom(fileId):
                                    animationFileId = fileId
                                    if case let .view(view) = item {
                                        animationFile = view.reactionFile
                                    }
                                case .stars:
                                    if let availableReactions = component.availableReactions {
                                        for availableReaction in availableReactions.reactionItems {
                                            if availableReaction.reaction.rawValue == reaction {
                                                animationFile = availableReaction.listAnimation._parse()
                                                break
                                            }
                                        }
                                    }
                                }
                                return PeerListItemComponent.Reaction(
                                    reaction: reaction,
                                    file: animationFile,
                                    animationFileId: animationFileId
                                )
                            },
                            story: storyItem,
                            message: item.message,
                            selectionState: .none,
                            hasNext: index != viewListState.totalCount - 1 || itemLayout.premiumFooterSize != nil,
                            action: { [weak self] peer, messageId, itemView in
                                guard let self, let component = self.component else {
                                    return
                                }
                                guard peer.id != component.context.account.peerId else {
                                    return
                                }
                                if let messageId {
                                    component.openMessage(peer, messageId)
                                } else if let storyItem, let sourceView = itemView.imageNode?.view {
                                    component.openReposts(peer, storyItem.id, sourceView)
                                } else {
                                    component.openPeer(peer)
                                }
                            },
                            contextAction: component.peerId.isGroupOrChannel || item.peer.id == component.context.account.peerId ? nil : { peer, view, gesture in
                                component.peerContextAction(peer, view, gesture)
                            },
                            openStories: { [weak self] peer, avatarNode in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.openPeerStories(peer, avatarNode)
                            }
                        )),
                        environment: {},
                        containerSize: itemFrame.size
                    )
                    if let itemView = visibleItem.view as? PeerListItemComponent.View {
                        var animateIn = false
                        if itemView.superview == nil {
                            animateIn = true
                            self.scrollView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                        
                        itemView.updateIsPreviewing(isPreviewing: self.previewedItemId?.peerId == item.peer.id && self.previewedItemId?.id == item.story?.id)
                        
                        if animateIn, synchronousLoad {
                            itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    }
                }
            }
            
            var removeIds: [EngineStoryViewListContext.Item.ItemHash] = []
            for (id, visibleItem) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = visibleItem.view {
                        itemView.removeFromSuperview()
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            var removePlaceholderIds: [Int] = []
            for (id, placeholderView) in self.visiblePlaceholderViews {
                if !validPlaceholderIds.contains(id) {
                    removePlaceholderIds.append(id)
                    
                    if synchronousLoad {
                        placeholderView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak placeholderView] _ in
                            placeholderView?.removeFromSuperview()
                        })
                    } else {
                        placeholderView.removeFromSuperview()
                    }
                }
            }
            for id in removePlaceholderIds {
                self.visiblePlaceholderViews.removeValue(forKey: id)
            }
            
            if let premiumFooterTextView = self.premiumFooterText?.view, let premiumFooterSize = itemLayout.premiumFooterSize {
                var premiumFooterTransition = transition
                if premiumFooterTextView.superview == nil {
                    premiumFooterTransition = premiumFooterTransition.withAnimation(.none)
                    self.scrollView.addSubview(premiumFooterTextView)
                }
                let premiumFooterFrame = CGRect(origin: CGPoint(x: floor((itemLayout.contentSize.width - premiumFooterSize.width) * 0.5), y: itemLayout.itemFrame(for: itemLayout.itemCount - 1).maxY + 13.0), size: premiumFooterSize)
                premiumFooterTransition.setPosition(view: premiumFooterTextView, position: premiumFooterFrame.center)
                premiumFooterTransition.setBounds(view: premiumFooterTextView, bounds: CGRect(origin: CGPoint(), size: premiumFooterFrame.size))
            }
            
            if let viewList = self.viewList, let viewListState = self.viewListState, viewListState.loadMoreToken != nil, visibleBounds.maxY >= self.scrollView.contentSize.height - 200.0 {
                if self.requestedLoadMoreToken != viewListState.loadMoreToken {
                    self.requestedLoadMoreToken = viewListState.loadMoreToken
                    viewList.loadMore()
                }
            }
            
            let navigationSearchCollapseFraction: CGFloat
            let navigationSearchFieldCollapseFraction: CGFloat
            if itemLayout.isSearchActive {
                navigationSearchCollapseFraction = 0.0
                navigationSearchFieldCollapseFraction = 0.0
            } else if let navigationSearchPartHeight = self.navigationSearchPartHeight, navigationSearchPartHeight > 8.0 {
                let searchCollapseDistance: CGFloat = navigationSearchPartHeight
                navigationSearchCollapseFraction = max(0.0, min(1.0, actualBounds.minY / searchCollapseDistance))
                
                let searchFieldCollapseDistance: CGFloat = navigationSearchPartHeight - 8.0
                navigationSearchFieldCollapseFraction = max(0.0, min(1.0, actualBounds.minY / searchFieldCollapseDistance))
            } else {
                navigationSearchCollapseFraction = 1.0
                navigationSearchFieldCollapseFraction = 1.0
            }
            
            if let navigationSearch = self.navigationSearch {
                let _ = navigationSearch.update(
                    transition: transition,
                    component: AnyComponent(NavigationSearchComponent(
                        colors: NavigationSearchComponent.Colors(
                            background: UIColor(white: 1.0, alpha: 0.05),
                            inactiveForeground: UIColor(rgb: 0x8E8E93),
                            foreground: .white,
                            button: component.theme.rootController.navigationBar.accentTextColor
                        ),
                        cancel: component.strings.Common_Cancel,
                        placeholder: component.strings.Common_Search,
                        isSearchActive: component.isSearchActive,
                        collapseFraction: navigationSearchFieldCollapseFraction,
                        activateSearch: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.setIsSearchActive(true)
                        },
                        deactivateSearch: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.setIsSearchActive(false)
                        },
                        updateQuery: { [weak self] query in
                            guard let self else {
                                return
                            }
                            self.updateQuery?(query)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: itemLayout.containerSize.width - component.safeInsets.left - component.safeInsets.right, height: 100.0)
                )
            }
            
            if let navigationHeight = self.navigationHeight, let navigationSearchPartHeight = self.navigationSearchPartHeight, let navigationBarBackground = self.navigationBarBackground, let navigationSeparator = self.navigationSeparator, let backgroundView = self.backgroundView {
                let effectiveNavigationHeight = navigationHeight - navigationSearchPartHeight * navigationSearchCollapseFraction
                let navigationBarBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: itemLayout.containerSize.width, height: effectiveNavigationHeight))
                
                transition.setFrame(view: navigationBarBackground, frame: navigationBarBackgroundFrame)
                navigationBarBackground.update(size: navigationBarBackgroundFrame.size, cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
                transition.setFrame(layer: navigationSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarBackgroundFrame.height - UIScreenPixel), size: CGSize(width: navigationBarBackgroundFrame.width, height: UIScreenPixel)))
                
                let navigationBarFrame = CGRect(origin: CGPoint(x: 0.0, y: itemLayout.availableSize.height - itemLayout.containerSize.height + 12.0), size: CGSize(width: itemLayout.availableSize.width, height: effectiveNavigationHeight))
                transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarFrame.maxY), size: CGSize(width: itemLayout.availableSize.width, height: itemLayout.availableSize.height)))
            }
        }
        
        func updateState(component: StoryItemSetViewListComponent, state: EmptyComponentState?, baseContentView: ContentView?, query: String?) {
            let itemUpdated = self.stateComponent?.storyItem.id != component.storyItem.id
            let viewsNilUpdated = (self.stateComponent?.storyItem.views == nil) != (component.storyItem.views == nil)
            let queryUpdated = self.query != query
            
            self.stateComponent = component
            self.state = state
            self.query = query
            
            if (self.viewList == nil || queryUpdated), let views = component.storyItem.views {
                if let query {
                    if queryUpdated {
                        if query.isEmpty {
                            self.viewListDisposable?.dispose()
                            self.viewListDisposable = nil
                            self.viewList = nil
                            
                            let listState = EngineStoryViewListContext.State(totalCount: 0, totalReactedCount: 0, items: [], loadMoreToken: nil)
                            self.viewListState = listState
                            
                            var hasContent = false
                            if !listState.items.isEmpty {
                                hasContent = true
                            }
                            if listState.loadMoreToken == nil {
                                hasContent = true
                            }
                            self.hasContent = hasContent
                            self.contentLoaded = true
                        } else {
                            let mappedListMode: EngineStoryViewListContext.ListMode
                            switch self.configuration.listMode {
                            case .everyone:
                                mappedListMode = .everyone
                            case .contacts:
                                mappedListMode = .contacts
                            }
                            
                            var parentSource: EngineStoryViewListContext?
                            if let baseContentView, baseContentView.configuration == self.configuration, baseContentView.query == nil {
                                parentSource = baseContentView.viewList
                            }
                            if component.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
                                parentSource = nil
                            }
                            
                            self.viewList = component.context.engine.messages.storyViewList(peerId: component.peerId, id: component.storyItem.id, views: views, listMode: mappedListMode, sortMode: self.configuration.sortMode.sortMode, searchQuery: query, parentSource: parentSource)
                        }
                    }
                } else {
                    let defaultSortMode: SortMode
                    if component.peerId.isGroupOrChannel {
                        defaultSortMode = .repostsFirst
                    } else {
                        defaultSortMode = .reactionsFirst
                    }
                    if self.configuration == ContentConfigurationKey(listMode: .everyone, sortMode: defaultSortMode) {
                        let viewList: EngineStoryViewListContext
                        if let current = component.sharedListsContext.viewLists[StoryId(peerId: component.peerId, id: component.storyItem.id)] {
                            viewList = current
                        } else {
                            viewList = component.context.engine.messages.storyViewList(peerId: component.peerId, id: component.storyItem.id, views: views, listMode: .everyone, sortMode: defaultSortMode.sortMode)
                            component.sharedListsContext.viewLists[StoryId(peerId: component.peerId, id: component.storyItem.id)] = viewList
                        }
                        self.viewList = viewList
                    } else {
                        let mappedListMode: EngineStoryViewListContext.ListMode
                        switch self.configuration.listMode {
                        case .everyone:
                            mappedListMode = .everyone
                        case .contacts:
                            mappedListMode = .contacts
                        }
                        self.viewList = component.context.engine.messages.storyViewList(peerId: component.peerId, id: component.storyItem.id, views: views, listMode: mappedListMode, sortMode: self.configuration.sortMode.sortMode, parentSource: component.sharedListsContext.viewLists[StoryId(peerId: component.peerId, id: component.storyItem.id)])
                    }
                }
            }
            
            if itemUpdated || viewsNilUpdated || queryUpdated {
                self.viewListDisposable?.dispose()
                
                if let _ = component.storyItem.views, let viewList = self.viewList {
                    var applyState = false
                    var firstTime = true
                    self.viewListDisposable = (viewList.state
                    |> mapToSignal { state in
                        #if DEBUG && false
                        if !state.items.isEmpty {
                            let otherItems: [EngineStoryViewListContext.Item] = Array(state.items.reversed().prefix(3))
                            let otherState = EngineStoryViewListContext.State(
                                totalCount: 3,
                                items: otherItems,
                                loadMoreToken: state.loadMoreToken
                            )
                            return .single(state)
                            |> then(.single(otherState) |> delay(1.0, queue: .mainQueue()))
                            |> then(.complete() |> delay(1.0, queue: .mainQueue()))
                            |> restart
                        } else {
                            return .single(state)
                        }
                        #else
                        return .single(state)
                        #endif
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] listState in
                        guard let self else {
                            return
                        }
                        if firstTime {
                            firstTime = false
                            self.ignoreScrolling = true
                            self.scrollView.setContentOffset(CGPoint(), animated: false)
                            self.ignoreScrolling = false
                        }
                        self.viewListState = listState
                        
                        if applyState {
                            //TODO:determine sync
                            self.state?.updated(transition: ComponentTransition.immediate.withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: true)))
                        }
                        
                        var hasContent = false
                        if !listState.items.isEmpty {
                            hasContent = true
                        }
                        if listState.loadMoreToken == nil {
                            hasContent = true
                        }
                        if self.hasContent != hasContent {
                            self.hasContent = hasContent
                            self.hasContentUpdated?(hasContent)
                        }
                        if self.contentLoaded != true {
                            self.contentLoaded = true
                            self.contentLoadedUpdated?(self.contentLoaded)
                        }
                    })
                    applyState = true
                } else {
                    if let _ = component.storyItem.views {
                    } else {
                        let listState = EngineStoryViewListContext.State(totalCount: 0, totalReactedCount: 0, items: [], loadMoreToken: nil)
                        self.viewListState = listState
                        
                        var hasContent = false
                        if !listState.items.isEmpty {
                            hasContent = true
                        }
                        if listState.loadMoreToken == nil {
                            hasContent = true
                        }
                        self.hasContent = hasContent
                        if self.contentLoaded != true {
                            self.contentLoaded = true
                            self.contentLoadedUpdated?(self.contentLoaded)
                        }
                    }
                }
            }
        }
        
        func update(component: StoryItemSetViewListComponent, availableSize: CGSize, visualHeight: CGFloat, sideInset: CGFloat, navigationHeight: CGFloat, navigationSearchPartHeight: CGFloat, isSearchActive: Bool, transition: ComponentTransition) {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component
            
            self.navigationHeight = navigationHeight
            self.navigationSearchPartHeight = navigationSearchPartHeight
            
            let measureItemSize = self.measureItem.update(
                transition: .immediate,
                component: AnyComponent(PeerListItemComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    style: .generic,
                    sideInset: 0.0,
                    title: "AAAAAAAAAAAA",
                    peer: nil,
                    subtitle: PeerListItemComponent.Subtitle(text: "BBBBBBB", color: .neutral),
                    subtitleAccessory: .checks,
                    presence: nil,
                    selectionState: .none,
                    hasNext: true,
                    action: { _, _, _ in
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            
            if self.placeholderImage == nil || themeUpdated {
                self.placeholderImage = generateImage(CGSize(width: 300.0, height: measureItemSize.height), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1).cgColor)
                    
                    if let measureItemView = self.measureItem.view as? PeerListItemComponent.View {
                        context.fillEllipse(in: measureItemView.avatarFrame)
                        let lineWidth: CGFloat = 8.0
                        
                        if let titleFrame = measureItemView.titleFrame {
                            context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: titleFrame.minX, y: floor(titleFrame.midY - lineWidth * 0.5)), size: CGSize(width: titleFrame.width, height: lineWidth)), cornerRadius: lineWidth * 0.5).cgPath)
                            context.fillPath()
                        }
                        if let labelFrame = measureItemView.labelFrame {
                            context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: labelFrame.minX, y: floor(labelFrame.midY - lineWidth * 0.5)), size: CGSize(width: labelFrame.width, height: lineWidth)), cornerRadius: lineWidth * 0.5).cgPath)
                            context.fillPath()
                        }
                    }
                })?.stretchableImage(withLeftCapWidth: 299, topCapHeight: 0)
                for (_, placeholderView) in self.visiblePlaceholderViews {
                    placeholderView.image = self.placeholderImage
                }
            }
            
            var premiumFooterSize: CGSize?
            if self.configuration.listMode == .everyone, let viewListState = self.viewListState, viewListState.loadMoreToken == nil, !viewListState.items.isEmpty, let views = component.storyItem.views, views.seenCount > viewListState.totalCount, component.storyItem.expirationTimestamp <= Int32(Date().timeIntervalSince1970), !component.peerId.isGroupOrChannel {
                let premiumFooterText: ComponentView<Empty>
                if let current = self.premiumFooterText {
                    premiumFooterText = current
                } else {
                    premiumFooterText = ComponentView()
                    self.premiumFooterText = premiumFooterText
                }
                
                let fontSize: CGFloat = 13.0
                let body = MarkdownAttributeSet(font: Font.regular(fontSize), textColor: component.theme.list.itemSecondaryTextColor)
                let bold = MarkdownAttributeSet(font: Font.semibold(fontSize), textColor: component.theme.list.itemSecondaryTextColor)
                let link = MarkdownAttributeSet(font: Font.semibold(fontSize), textColor: component.theme.list.itemAccentColor)
                let attributes = MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in return ("URL", "") })
                
                let text: String
                let fullWidth: Bool
                if component.hasPremium {
                    text = component.strings.Story_ViewList_NotFullyRecorded
                    fullWidth = true
                } else {
                    text = component.strings.Story_ViewList_PremiumUpgradeInlineText
                    fullWidth = false
                }
                premiumFooterSize = premiumFooterText.update(
                    transition: .immediate,
                    component: AnyComponent(BalancedTextComponent(
                        text: .markdown(text: text, attributes: attributes),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2,
                        highlightColor: component.theme.list.itemAccentColor.withMultipliedAlpha(0.5),
                        highlightAction: component.hasPremium ? nil : { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                                return NSAttributedString.Key(rawValue: "URL")
                            } else {
                                return nil
                            }
                        },
                        tapAction: component.hasPremium ? nil : { [weak self] _, _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.openPremiumIntro()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: min(fullWidth ? 500.0 : 320.0, availableSize.width - 16.0 * 2.0), height: 1000.0)
                )
            } else {
                if let premiumFooterText = self.premiumFooterText {
                    self.premiumFooterText = nil
                    premiumFooterText.view?.removeFromSuperview()
                }
            }
            
            let itemLayout = ItemLayout(
                containerSize: CGSize(width: availableSize.width, height: visualHeight),
                availableSize: availableSize,
                bottomInset: component.safeInsets.bottom,
                topInset: navigationHeight,
                sideInset: sideInset,
                itemHeight: measureItemSize.height,
                itemCount: self.viewListState?.items.count ?? 0,
                premiumFooterSize: premiumFooterSize,
                isSearchActive: isSearchActive
            )
            self.itemLayout = itemLayout
            
            let scrollContentSize = itemLayout.contentSize
            
            self.ignoreScrolling = true
            
            let navigationMinY: CGFloat = availableSize.height - visualHeight + 12.0
            
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationMinY), size: CGSize(width: availableSize.width, height: visualHeight)))
            let scrollContentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            let scrollIndicatorInsets = UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: component.safeInsets.bottom, right: 0.0)
            if self.scrollView.contentInset != scrollContentInsets {
                self.scrollView.contentInset = scrollContentInsets
            }
            if self.scrollView.verticalScrollIndicatorInsets != scrollIndicatorInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollIndicatorInsets
            }
            if self.scrollView.contentSize != scrollContentSize {
                self.scrollView.contentSize = scrollContentSize
            }
            
            if let viewListState = self.viewListState, viewListState.loadMoreToken == nil, viewListState.items.isEmpty, viewListState.totalCount == 0 {
                self.scrollView.isUserInteractionEnabled = false
                
                var emptyTransition = transition
                
                let emptyIcon: ComponentView<Empty>
                if let current = self.emptyIcon {
                    emptyIcon = current
                } else {
                    emptyTransition = emptyTransition.withAnimation(.none)
                    emptyIcon = ComponentView()
                    self.emptyIcon = emptyIcon
                }
                
                let emptyText: ComponentView<Empty>
                if let current = self.emptyText {
                    emptyText = current
                } else {
                    emptyText = ComponentView()
                    self.emptyText = emptyText
                }
                
                var emptyButtonTransition = transition
                let emptyButton: ComponentView<Empty>?
                if self.query == nil, !component.hasPremium && !component.peerId.isGroupOrChannel, let views = component.storyItem.views, views.seenCount != 0 {
                    if let current = self.emptyButton {
                        emptyButton = current
                    } else {
                        emptyButtonTransition = emptyButtonTransition.withAnimation(.none)
                        emptyButton = ComponentView()
                        self.emptyButton = emptyButton
                    }
                } else {
                    if let emptyButton = self.emptyButton {
                        self.emptyButton = nil
                        emptyButton.view?.removeFromSuperview()
                    }
                    
                    emptyButton = nil
                }
                
                let emptyIconSize = emptyIcon.update(
                    transition: emptyTransition,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "ChatListNoResults"),
                        color: nil,
                        startingPosition: .begin,
                        size: CGSize(width: 140.0, height: 140.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 140.0, height: 140.0)
                )
                
                let fontSize: CGFloat = 16.0
                let body = MarkdownAttributeSet(font: Font.regular(fontSize), textColor: component.theme.list.itemSecondaryTextColor)
                let bold = MarkdownAttributeSet(font: Font.semibold(fontSize), textColor: component.theme.list.itemSecondaryTextColor)
                let link = MarkdownAttributeSet(font: Font.semibold(fontSize), textColor: component.theme.list.itemAccentColor)
                let attributes = MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in return ("URL", "") })
                
                let text: String
                if self.configuration.listMode == .everyone && ((self.query ?? "") == "") {
                    if component.storyItem.expirationTimestamp <= Int32(Date().timeIntervalSince1970) {
                        if emptyButton == nil {
                            if let views = component.storyItem.views, views.seenCount > 0 {
                                text = component.peerId.isGroupOrChannel ? component.strings.Story_Views_NoReactions : component.strings.Story_Views_ViewsNotRecorded
                            } else {
                                text = component.strings.Story_Views_ViewsExpired
                            }
                        } else {
                            text = component.strings.Story_ViewList_PremiumUpgradeText
                        }
                    } else {
                        text = component.peerId.isGroupOrChannel ? component.strings.Story_Views_NoReactions : component.strings.Story_Views_NoViews
                    }
                } else {
                    if let query = self.query, !query.isEmpty {
                        text = component.strings.Story_ViewList_EmptyTextSearch
                    } else if self.configuration.listMode == .contacts {
                        text = component.strings.Story_ViewList_EmptyTextContacts
                    } else {
                        if component.storyItem.expirationTimestamp <= Int32(Date().timeIntervalSince1970) {
                            if emptyButton == nil {
                                if let views = component.storyItem.views, views.seenCount > 0 {
                                    text = component.strings.Story_Views_ViewsNotRecorded
                                } else {
                                    text = component.strings.Story_Views_ViewsExpired
                                }
                            } else {
                                text = component.strings.Story_ViewList_PremiumUpgradeText
                            }
                        } else {
                            text = component.peerId.isGroupOrChannel ? component.strings.Story_Views_NoReactions : component.strings.Story_Views_NoViews
                        }
                    }
                }
                let textSize = emptyText.update(
                    transition: .immediate,
                    component: AnyComponent(BalancedTextComponent(
                        text: .markdown(text: text, attributes: attributes),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        highlightColor: component.theme.list.itemAccentColor.withMultipliedAlpha(0.5),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                                return NSAttributedString.Key(rawValue: "URL")
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] _, _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.openPremiumIntro()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: min(320.0, availableSize.width - 16.0 * 2.0), height: 1000.0)
                )
                 
                let emptyContentSpacing: CGFloat = 20.0
                var emptyContentHeight = emptyIconSize.height + emptyContentSpacing + textSize.height
                
                var emptyButtonSize: CGSize?
                if let emptyButton {
                    emptyButtonSize = emptyButton.update(
                        transition: emptyButtonTransition,
                        component: AnyComponent(ButtonComponent(
                            background: ButtonComponent.Background(
                                color: component.theme.list.itemCheckColors.fillColor,
                                foreground: component.theme.list.itemCheckColors.foregroundColor,
                                pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            ),
                            content: AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(ButtonTextContentComponent(
                                    text: component.strings.Story_ViewList_PremiumUpgradeAction,
                                    badge: 0,
                                    textColor: component.theme.list.itemCheckColors.foregroundColor,
                                    badgeBackground: component.theme.list.itemCheckColors.foregroundColor,
                                    badgeForeground: component.theme.list.itemCheckColors.fillColor
                                ))
                            ),
                            isEnabled: true,
                            displaysProgress: false,
                            action: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.openPremiumIntro()
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: min(availableSize.width, 180.0), height: 50.0)
                    )
                }

                let emptyButtonSpacing: CGFloat = 32.0
                if let emptyButtonSize {
                    emptyContentHeight += emptyButtonSpacing
                    emptyContentHeight += emptyButtonSize.height
                }
                
                var emptyContentY = navigationMinY + floor((availableSize.height - component.safeInsets.bottom - navigationMinY - emptyContentHeight) * 0.5)
                
                if let emptyIconView = emptyIcon.view as? LottieComponent.View {
                    if emptyIconView.superview == nil {
                        self.insertSubview(emptyIconView, belowSubview: self.scrollView)
                        
                        /*var completionRecurse: (() -> Void)?
                        let completion: () -> Void = { [weak self, weak emptyIconView] in
                            guard let self, let emptyIconView else {
                                return
                            }
                            guard self.emptyIcon?.view === emptyIconView else {
                                return
                            }
                            emptyIconView.playOnce(completion: {
                                completionRecurse?()
                            })
                        }
                        completionRecurse = {
                            completion()
                        }
                        emptyIconView.playOnce(completion: {
                            completion()
                        })*/
                        
                        emptyIconView.playOnce()
                    }
                    emptyTransition.setFrame(view: emptyIconView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - emptyIconSize.width) * 0.5), y: emptyContentY), size: emptyIconSize))
                    emptyContentY += emptyIconSize.height + emptyContentSpacing
                }
                
                if let emptyTextView = emptyText.view {
                    if emptyTextView.superview == nil {
                        self.insertSubview(emptyTextView, belowSubview: self.scrollView)
                    }
                    emptyTransition.setFrame(view: emptyTextView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - textSize.width) * 0.5), y: emptyContentY), size: textSize))
                    emptyContentY += textSize.height + emptyContentSpacing * 2.0
                }
                
                if let emptyButtonSize, let emptyButton, let emptyButtonView = emptyButton.view {
                    if emptyButtonView.superview == nil {
                        self.insertSubview(emptyButtonView, belowSubview: self.scrollView)
                    }
                    emptyTransition.setFrame(view: emptyButtonView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - emptyButtonSize.width) * 0.5), y: emptyContentY), size: emptyButtonSize))
                    emptyContentY += emptyButtonSize.height + emptyButtonSpacing
                }
            } else {
                self.scrollView.isUserInteractionEnabled = true
                
                if let emptyIcon = self.emptyIcon {
                    self.emptyIcon = nil
                    emptyIcon.view?.removeFromSuperview()
                }
                if let emptyText = self.emptyText {
                    self.emptyText = nil
                    emptyText.view?.removeFromSuperview()
                }
                if let emptyButton = self.emptyButton {
                    self.emptyButton = nil
                    emptyButton.view?.removeFromSuperview()
                }
            }
            
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let navigationBarBackground: BlurredBackgroundView
        private let navigationSearch = ComponentView<Empty>()
        private let navigationSeparator: SimpleLayer
        
        private let navigationContainerView: UIView
        private let tabSelector = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let orderSelector = ComponentView<Empty>()
        
        private var mainViewListDisposable: Disposable?
        private var mainViewList: EngineStoryViewListContext?
        private var mainViewListState: EngineStoryViewListContext.State?
        
        private var currentContentView: ContentView?
        private weak var disappearingCurrentContentView: ContentView?
        
        private var currentSearchContentView: ContentView?
        private weak var disappearingSearchContentView: ContentView?
        
        private let backgroundView: UIView

        private var component: StoryItemSetViewListComponent?
        private weak var state: EmptyComponentState?
        
        private var listMode: ListMode = .everyone
        private var sortMode: SortMode = .reactionsFirst
        private var currentSearchQuery: String = ""
        
        public var currentViewList: EngineStoryViewListContext? {
            return self.currentContentView?.viewList
        }
        
        override init(frame: CGRect) {
            self.navigationContainerView = UIView()
            self.navigationContainerView.clipsToBounds = true
            
            self.navigationBarBackground = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationSeparator = SimpleLayer()
            
            self.backgroundView = UIView()

            super.init(frame: frame)

            self.addSubview(self.backgroundView)
            
            self.navigationContainerView.addSubview(self.navigationBarBackground)
            self.navigationContainerView.layer.addSublayer(self.navigationSeparator)
            self.addSubview(self.navigationContainerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.mainViewListDisposable?.dispose()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.backgroundView.frame.contains(point) && !self.navigationContainerView.frame.contains(point) {
                return nil
            }
            
            return super.hitTest(point, with: event)
        }
        
        public func setPreviewedItem(signal: Signal<StoryId?, NoError>) {
            self.currentContentView?.setPreviewedItem(signal: signal)
        }
        
        public func sourceView(storyId: StoryId) -> UIView? {
            self.currentContentView?.sourceView(storyId: storyId)
        }
        
        func animateIn(transition: ComponentTransition) {
            let offset = self.bounds.height - self.navigationBarBackground.frame.minY
            ComponentTransition.immediate.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: -offset))
            transition.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: 0.0))
        }
        
        func animateOut(transition: ComponentTransition, completion: @escaping () -> Void) {
            let offset = self.bounds.height - self.navigationBarBackground.frame.minY
            transition.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: -offset), completion: { _ in
                completion()
            })
        }
        
        func setEventCycleState(_ eventCycleState: EventCycleState?) {
            self.currentContentView?.eventCycleState = eventCycleState
        }
        
        private func openSortModeMenu() {
            guard let component = self.component else {
                return
            }
            guard let controller = component.controller() else {
                return
            }
            guard let sourceView = self.orderSelector.view else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
            var items: [ContextMenuItem] = []
            
            let sortMode = self.sortMode
            if component.peerId.isGroupOrChannel {
                items.append(.action(ContextMenuActionItem(text: component.strings.Story_ViewList_ContextSortReposts, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Stories/Context Menu/Repost"), color: theme.contextMenu.primaryColor)
                }, additionalLeftIcon: { theme in
                    if sortMode != .repostsFirst {
                        return nil
                    }
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self else {
                        return
                    }
                    if self.sortMode != .repostsFirst {
                        self.sortMode = .repostsFirst
                        self.state?.updated(transition: .immediate)
                    }
                })))
            } else {
                items.append(.action(ContextMenuActionItem(text: component.strings.Story_ViewList_ContextSortReactions, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reactions"), color: theme.contextMenu.primaryColor)
                }, additionalLeftIcon: { theme in
                    if sortMode != .reactionsFirst {
                        return nil
                    }
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self else {
                        return
                    }
                    if self.sortMode != .reactionsFirst {
                        self.sortMode = .reactionsFirst
                        self.state?.updated(transition: .immediate)
                    }
                })))
            }
            items.append(.action(ContextMenuActionItem(text: component.strings.Story_ViewList_ContextSortRecent, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Time"), color: theme.contextMenu.primaryColor)
            }, additionalLeftIcon: { theme in
                if sortMode != .recentFirst {
                    return nil
                }
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, a in
                a(.default)
                
                guard let self else {
                    return
                }
                if self.sortMode != .recentFirst {
                    self.sortMode = .recentFirst
                    self.state?.updated(transition: .immediate)
                }
            })))
            
            items.append(.separator)
                                        
            let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil
            
            items.append(.action(ContextMenuActionItem(text: component.peerId.isGroupOrChannel ? component.strings.Story_ViewList_ContextSortChannelInfo : component.strings.Story_ViewList_ContextSortInfo, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction)))
            
            let contextItems = ContextController.Items(content: .list(items))
            
            let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView, position: .bottom)), items: .single(contextItems), gesture: nil)
            
            sourceView.alpha = 0.5
            contextController.dismissed = { [weak self, weak sourceView] in
                guard let self else {
                    return
                }
                let _ = self
                
                if let sourceView {
                    let transition = ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut))
                    transition.setAlpha(view: sourceView, alpha: 1.0)
                }
            }
            controller.present(contextController, in: .window(.root))
        }
        
        func update(component: StoryItemSetViewListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.backgroundView.backgroundColor = component.theme.rootController.navigationBar.blurredBackgroundColor
                self.navigationBarBackground.updateColor(color: component.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.navigationSeparator.backgroundColor = component.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            if !component.isSearchActive {
                self.currentSearchQuery = ""
            }
            
            var updateSubState = false
            
            if self.mainViewList == nil {
                if component.peerId.isGroupOrChannel {
                    self.sortMode = .repostsFirst
                } else {
                    self.sortMode = .reactionsFirst
                }
                
                self.mainViewListDisposable?.dispose()
                self.mainViewListDisposable = nil
                
                if let views = component.storyItem.views {
                    let viewList: EngineStoryViewListContext
                    if let current = component.sharedListsContext.viewLists[StoryId(peerId: component.peerId, id: component.storyItem.id)] {
                        viewList = current
                    } else {
                        viewList = component.context.engine.messages.storyViewList(peerId: component.peerId, id: component.storyItem.id, views: views, listMode: .everyone, sortMode: .reactionsFirst)
                        component.sharedListsContext.viewLists[StoryId(peerId: component.peerId, id: component.storyItem.id)] = viewList
                    }
                    self.mainViewList = viewList
                    self.mainViewListDisposable = (viewList.state
                    |> deliverOnMainQueue).start(next: { [weak self] listState in
                        guard let self else {
                            return
                        }
                        self.mainViewListState = listState
                        
                        if updateSubState {
                            self.state?.updated(transition: .immediate)
                        }
                    })
                } else {
                    self.mainViewList = nil
                    self.mainViewListState = nil
                }
            }
            
            let currentConfiguration = ContentConfigurationKey(listMode: self.listMode, sortMode: self.sortMode)
            if self.currentContentView?.configuration != currentConfiguration {
                let previousContentView = self.currentContentView
                self.disappearingCurrentContentView?.removeFromSuperview()
                self.disappearingCurrentContentView = self.currentContentView
                self.currentContentView = nil
                
                let currentContentView = ContentView(configuration: currentConfiguration)
                self.currentContentView = currentContentView
                currentContentView.updateQuery = { [weak self] query in
                    guard let self else {
                        return
                    }
                    if self.currentSearchQuery != query {
                        self.currentSearchQuery = query
                        self.state?.updated(transition: .immediate)
                    }
                }
                currentContentView.isHidden = true
                currentContentView.contentLoadedUpdated = { [weak self, weak currentContentView, weak previousContentView] value in
                    guard value, let self, let currentContentView else {
                        return
                    }
                    currentContentView.isHidden = false
                    if let previousContentView {
                        previousContentView.removeFromSuperview()
                        if self.disappearingCurrentContentView === previousContentView {
                            self.disappearingCurrentContentView = nil
                        }
                    }
                    
                    currentContentView.navigationSearch = self.navigationSearch
                    currentContentView.navigationBarBackground = self.navigationBarBackground
                    currentContentView.navigationSeparator = self.navigationSeparator
                    currentContentView.backgroundView = self.backgroundView
                    if updateSubState {
                        self.state?.updated(transition: .immediate)
                    }
                }
            }
            
            if let currentContentView = self.currentContentView {
                var contentViewTransition = transition
                if currentContentView.superview == nil {
                    contentViewTransition = contentViewTransition.withAnimation(.none)
                    self.insertSubview(currentContentView, belowSubview: self.navigationContainerView)
                }
                
                contentViewTransition.setFrame(view: currentContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                currentContentView.updateState(
                    component: component,
                    state: state,
                    baseContentView: nil,
                    query: nil
                )
                if currentContentView.contentLoaded {
                    currentContentView.isHidden = false
                }
            }
            
            let sideInset: CGFloat = 16.0
            
            let visualHeight: CGFloat = max(component.minHeight, component.effectiveHeight)
            
            var tabSelectorTransition = transition
            if transition.animation.isImmediate, self.tabSelector.view != nil {
                tabSelectorTransition = ComponentTransition(animation: .curve(duration: 0.35, curve: .spring))
            }
            let tabSelectorSize = self.tabSelector.update(
                transition: tabSelectorTransition,
                component: AnyComponent(TabSelectorComponent(
                    colors: TabSelectorComponent.Colors(
                        foreground: .white,
                        selection: UIColor(rgb: 0xffffff, alpha: 0.09)
                    ),
                    items: [
                        TabSelectorComponent.Item(
                            id: AnyHashable(ListMode.everyone.rawValue),
                            title: component.strings.Story_ViewList_TabTitleAll
                        ),
                        TabSelectorComponent.Item(
                            id: AnyHashable(ListMode.contacts.rawValue),
                            title: component.strings.Story_ViewList_TabTitleContacts
                        )
                    ],
                    selectedId: AnyHashable(self.listMode == .everyone ? 0 : 1),
                    setSelectedId: { [weak self] id in
                        guard let self, let idValue = id.base as? Int, let listMode = ListMode(rawValue: idValue) else {
                            return
                        }
                        if self.listMode != listMode {
                            self.listMode = listMode
                            self.state?.updated(transition: .immediate)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 10.0 * 2.0, height: 50.0)
            )
            
            var currentTotalCount: Int?
            var currentTotalReactionCount: Int?
            if let mainViewListState = self.mainViewListState {
                currentTotalCount = mainViewListState.totalCount
                currentTotalReactionCount = mainViewListState.totalReactedCount
            } else {
                currentTotalCount = component.storyItem.views?.seenCount
                currentTotalReactionCount = component.storyItem.views?.reactedCount
            }
            
            let titleText: String
            if component.peerId.isGroupOrChannel {
                titleText = component.strings.Story_ViewList_TitleReactions
            } else if let totalCount = currentTotalCount, let currentTotalReactionCount {
                if totalCount > 0 && totalCount > currentTotalReactionCount {
                    titleText = component.strings.Story_ViewList_ViewerCount(Int32(totalCount))
                } else {
                    titleText = component.strings.Story_ViewList_TitleViewers
                }
            } else {
                titleText = component.strings.Story_ViewList_TitleEmpty
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(text: titleText, font: Font.semibold(17.0), color: .white)),
                environment: {},
                containerSize: CGSize(width: 260.0, height: 100.0)
            )
            
            let orderSelectorIconName: String
            switch self.sortMode {
            case .repostsFirst:
                orderSelectorIconName = "Stories/Context Menu/Repost"
            case .reactionsFirst:
                orderSelectorIconName = "Chat/Context Menu/Reactions"
            case .recentFirst:
                orderSelectorIconName = "Chat/Context Menu/Time"
            }
            let orderSelectorSize = self.orderSelector.update(
                transition: transition,
                component: AnyComponent(OptionButtonComponent(
                    colors: OptionButtonComponent.Colors(
                        background: UIColor(rgb: 0xffffff, alpha: 0.09),
                        foreground: .white
                    ),
                    icon: orderSelectorIconName,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        
                        self.openSortModeMenu()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let navigationSearchSize = CGSize(width: availableSize.width - component.safeInsets.left - component.safeInsets.right, height: 52.0)
            
            var displayModeSelector = false
            var displaySearchBar = false
            var displaySortSelector = false
            
            if component.peerId == component.context.account.peerId && !component.hasPremium, component.storyItem.expirationTimestamp <= Int32(Date().timeIntervalSince1970) {
            } else {
                if let views = component.storyItem.views, views.hasList || component.peerId.isGroupOrChannel {
                    if let totalCount = currentTotalCount {
                        if !component.peerId.isGroupOrChannel, totalCount >= 20 || component.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
                            displayModeSelector = true
                            displaySearchBar = true
                        }
                        if (((component.peerId.isGroupOrChannel && views.forwardCount >= 10 ) || (!component.peerId.isGroupOrChannel && views.reactedCount >= 10)) && totalCount >= 20) || component.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
                            displaySortSelector = true
                        }
                    } else {
                        /*if views.seenCount >= 20 || component.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
                            displayModeSelector = true
                            displaySearchBar = true
                        }
                        if (views.reactedCount >= 10 && views.seenCount >= 20) || component.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
                            displaySortSelector = true
                        }*/
                    }
                }
                if let privacy = component.storyItem.privacy, case .everyone = privacy.base {
                } else {
                    displayModeSelector = false
                }
            }
            
            let navigationHeight: CGFloat
            let navigationSearchPartHeight: CGFloat
            if component.isSearchActive {
                navigationHeight = navigationSearchSize.height
                navigationSearchPartHeight = 0.0
            } else if displaySearchBar {
                navigationHeight = 56.0 + navigationSearchSize.height - 6.0
                navigationSearchPartHeight = navigationSearchSize.height - 6.0
            } else {
                navigationHeight = 56.0
                navigationSearchPartHeight = 0.0
            }
            
            if let tabSelectorView = self.tabSelector.view {
                if tabSelectorView.superview == nil {
                    self.navigationContainerView.addSubview(tabSelectorView)
                }
                tabSelectorView.isHidden = !displayModeSelector
                transition.setFrame(view: tabSelectorView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - tabSelectorSize.width) * 0.5), y: floor((56.0 - tabSelectorSize.height) * 0.5) + (component.isSearchActive ? (-56.0) : 0.0)), size: tabSelectorSize))
                transition.setAlpha(view: tabSelectorView, alpha: component.isSearchActive ? 0.0 : 1.0)
            }
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.navigationContainerView.addSubview(titleView)
                }
                titleView.isHidden = displayModeSelector
                
                let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: floor((56.0 - titleSize.height) * 0.5) + (component.isSearchActive ? (-56.0) : 0.0)), size: titleSize)
                
                transition.setFrame(view: titleView, frame: titleFrame)
                transition.setAlpha(view: titleView, alpha: component.isSearchActive ? 0.0 : 1.0)
            }
            
            if let orderSelectorView = self.orderSelector.view {
                if orderSelectorView.superview == nil {
                    self.navigationContainerView.addSubview(orderSelectorView)
                }
                transition.setFrame(view: orderSelectorView, frame: CGRect(origin: CGPoint(x: availableSize.width - sideInset - orderSelectorSize.width, y: floor((56.0 - orderSelectorSize.height) * 0.5) + (component.isSearchActive ? (-56.0) : 0.0)), size: orderSelectorSize))
                transition.setAlpha(view: orderSelectorView, alpha: component.isSearchActive ? 0.0 : 1.0)
                
                orderSelectorView.isHidden = !displaySortSelector
            }
            
            let navigationBarFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - visualHeight + 12.0), size: CGSize(width: availableSize.width, height: navigationHeight))
            
            transition.setFrame(view: self.navigationContainerView, frame: navigationBarFrame)
            
            if let currentContentView = self.currentContentView {
                var contentViewTransition = transition
                if currentContentView.superview == nil {
                    contentViewTransition = contentViewTransition.withAnimation(.none)
                    self.insertSubview(currentContentView, belowSubview: self.navigationContainerView)
                }
                
                contentViewTransition.setFrame(view: currentContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                currentContentView.update(
                    component: component,
                    availableSize: availableSize,
                    visualHeight: visualHeight,
                    sideInset: sideInset,
                    navigationHeight: navigationHeight,
                    navigationSearchPartHeight: navigationSearchPartHeight,
                    isSearchActive: component.isSearchActive,
                    transition: contentViewTransition
                )
                if currentContentView.contentLoaded {
                    currentContentView.isHidden = false
                }
            }
            
            if !self.currentSearchQuery.isEmpty {
                let currentSearchContentView: ContentView
                if let current = self.currentSearchContentView {
                    currentSearchContentView = current
                } else {
                    currentSearchContentView = ContentView(configuration: currentConfiguration)
                    self.currentSearchContentView = currentSearchContentView
                    currentSearchContentView.isHidden = true
                    currentSearchContentView.dismissInput = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.navigationSearch.view?.endEditing(true)
                    }
                }
                
                var contentViewTransition = transition
                if currentSearchContentView.superview == nil {
                    contentViewTransition = contentViewTransition.withAnimation(.none)
                    self.insertSubview(currentSearchContentView, belowSubview: self.navigationContainerView)
                }
                
                currentSearchContentView.hasContentUpdated = { [weak self] hasContent in
                    guard let self else {
                        return
                    }
                    self.currentContentView?.isHidden = hasContent
                    self.currentSearchContentView?.isHidden = !hasContent
                }
                contentViewTransition.setFrame(view: currentSearchContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                currentSearchContentView.updateState(
                    component: component,
                    state: state,
                    baseContentView: self.currentContentView,
                    query: self.currentSearchQuery
                )
                currentSearchContentView.update(
                    component: component,
                    availableSize: availableSize,
                    visualHeight: visualHeight,
                    sideInset: sideInset,
                    navigationHeight: navigationHeight,
                    navigationSearchPartHeight: navigationSearchPartHeight,
                    isSearchActive: component.isSearchActive,
                    transition: contentViewTransition
                )
                
                self.currentContentView?.isHidden = currentSearchContentView.hasContent
                self.currentSearchContentView?.isHidden = !currentSearchContentView.hasContent
            } else {
                if let currentSearchContentView = self.currentSearchContentView {
                    self.currentSearchContentView = nil
                    
                    self.disappearingSearchContentView?.removeFromSuperview()
                    self.disappearingSearchContentView = currentSearchContentView
                    
                    if transition.animation.isImmediate {
                        currentSearchContentView.removeFromSuperview()
                    } else {
                        currentSearchContentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak currentSearchContentView] _ in
                            currentSearchContentView?.removeFromSuperview()
                        })
                        
                        if let currentContentView = self.currentContentView, currentContentView.isHidden {
                            currentContentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    }
                    
                    self.currentContentView?.isHidden = false
                }
            }
            
            if let disappearingCurrentContentView = self.disappearingCurrentContentView {
                transition.setFrame(view: disappearingCurrentContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                disappearingCurrentContentView.update(
                    component: component,
                    availableSize: availableSize,
                    visualHeight: visualHeight,
                    sideInset: sideInset,
                    navigationHeight: navigationHeight,
                    navigationSearchPartHeight: navigationSearchPartHeight,
                    isSearchActive: component.isSearchActive,
                    transition: transition
                )
            }
            if let disappearingSearchContentView = self.disappearingSearchContentView {
                transition.setFrame(view: disappearingSearchContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                disappearingSearchContentView.update(
                    component: component,
                    availableSize: availableSize,
                    visualHeight: visualHeight,
                    sideInset: sideInset,
                    navigationHeight: navigationHeight,
                    navigationSearchPartHeight: navigationSearchPartHeight,
                    isSearchActive: component.isSearchActive,
                    transition: transition
                )
            }
            
            if let navigationSearchView = self.navigationSearch.view {
                if navigationSearchView.superview == nil {
                    self.navigationContainerView.addSubview(navigationSearchView)
                }
                transition.setFrame(view: navigationSearchView, frame: CGRect(origin: CGPoint(x: component.safeInsets.left, y: component.isSearchActive ? 0.0 : 50.0), size: navigationSearchSize))
                transition.setAlpha(view: navigationSearchView, alpha: (displaySearchBar || component.isSearchActive) ? 1.0 : 0.0)
            }
            
            transition.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: -max(0.0, visualHeight - component.effectiveHeight)))
            
            updateSubState = true
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
