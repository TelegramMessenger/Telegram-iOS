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
    let peerContextAction: (EnginePeer, ContextExtractedContentContainingView, ContextGesture) -> Void
    let openPeerStories: (EnginePeer, AvatarNode) -> Void
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
        peerContextAction: @escaping (EnginePeer, ContextExtractedContentContainingView, ContextGesture) -> Void,
        openPeerStories: @escaping (EnginePeer, AvatarNode) -> Void,
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
        self.peerContextAction = peerContextAction
        self.openPeerStories = openPeerStories
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
        var bottomInset: CGFloat
        var topInset: CGFloat
        var sideInset: CGFloat
        var itemHeight: CGFloat
        var itemCount: Int
        var premiumFooterSize: CGSize?
        
        var contentSize: CGSize
        
        init(containerSize: CGSize, bottomInset: CGFloat, topInset: CGFloat, sideInset: CGFloat, itemHeight: CGFloat, itemCount: Int, premiumFooterSize: CGSize?) {
            self.containerSize = containerSize
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.sideInset = sideInset
            self.itemHeight = itemHeight
            self.itemCount = itemCount
            self.premiumFooterSize = premiumFooterSize
            
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
        case reactionsFirst = 0
        case recentFirst = 1
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
        
        var component: StoryItemSetViewListComponent?
        weak var state: EmptyComponentState?
        
        let measureItem = ComponentView<Empty>()
        var placeholderImage: UIImage?
        
        var visibleItems: [EnginePeer.Id: ComponentView<Empty>] = [:]
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
        
        var eventCycleState: EventCycleState?
        
        var totalCount: Int? {
            return self.viewListState?.totalCount
        }
        
        var hasContent: Bool = false
        var hasContentUpdated: ((Bool) -> Void)?
        
        var contentLoaded: Bool = false
        var contentLoadedUpdated: ((Bool) -> Void)?
        
        var dismissInput: (() -> Void)?
        
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
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            cancelContextGestures(view: scrollView)
            
            self.dismissInput?()
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -200.0)
            
            var synchronousLoad = false
            if let hint = transition.userData(PeerListItemComponent.TransitionHint.self) {
                synchronousLoad = hint.synchronousLoad
            }
            
            var validIds: [EnginePeer.Id] = []
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
                    validIds.append(item.peer.id)
                    
                    let visibleItem: ComponentView<Empty>
                    if let current = self.visibleItems[item.peer.id] {
                        visibleItem = current
                    } else {
                        if !transition.animation.isImmediate {
                            itemTransition = .immediate
                        }
                        visibleItem = ComponentView()
                        self.visibleItems[item.peer.id] = visibleItem
                    }
                    
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    let dateText = humanReadableStringForTimestamp(strings: component.strings, dateTimeFormat: presentationData.dateTimeFormat, timestamp: item.timestamp, alwaysShowTime: true, allowYesterday: true, format: HumanReadableStringFormat(
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
                            subtitle: dateText,
                            subtitleAccessory: .checks,
                            presence: nil,
                            reaction: item.reaction.flatMap { reaction -> PeerListItemComponent.Reaction in
                                var animationFileId: Int64?
                                var animationFile: TelegramMediaFile?
                                switch reaction {
                                case .builtin:
                                    if let availableReactions = component.availableReactions {
                                        for availableReaction in availableReactions.reactionItems {
                                            if availableReaction.reaction.rawValue == reaction {
                                                animationFile = availableReaction.listAnimation
                                                break
                                            }
                                        }
                                    }
                                case let .custom(fileId):
                                    animationFileId = fileId
                                    animationFile = item.reactionFile
                                }
                                return PeerListItemComponent.Reaction(
                                    reaction: reaction,
                                    file: animationFile,
                                    animationFileId: animationFileId
                                )
                            },
                            selectionState: .none,
                            hasNext: index != viewListState.totalCount - 1 || itemLayout.premiumFooterSize != nil,
                            action: { [weak self] peer in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.openPeer(peer)
                            },
                            contextAction: { peer, view, gesture in
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
                    if let itemView = visibleItem.view {
                        var animateIn = false
                        if itemView.superview == nil {
                            animateIn = true
                            self.scrollView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                        
                        if animateIn, synchronousLoad {
                            itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    }
                }
            }
            
            var removeIds: [EnginePeer.Id] = []
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
        }
        
        func update(component: StoryItemSetViewListComponent, state: EmptyComponentState?, baseContentView: ContentView?, query: String?, availableSize: CGSize, visualHeight: CGFloat, sideInset: CGFloat, navigationHeight: CGFloat, transition: Transition) {
            let themeUpdated = self.component?.theme !== component.theme
            let itemUpdated = self.component?.storyItem.id != component.storyItem.id
            let viewsNilUpdated = (self.component?.storyItem.views == nil) != (component.storyItem.views == nil)
            let queryUpdated = self.query != query
            
            self.component = component
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
                            let mappedSortMode: EngineStoryViewListContext.SortMode
                            switch self.configuration.sortMode {
                            case .reactionsFirst:
                                mappedSortMode = .reactionsFirst
                            case .recentFirst:
                                mappedSortMode = .recentFirst
                            }
                            
                            var parentSource: EngineStoryViewListContext?
                            if let baseContentView, baseContentView.configuration == self.configuration, baseContentView.query == nil {
                                parentSource = baseContentView.viewList
                            }
                            if component.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
                                parentSource = nil
                            }
                            
                            self.viewList = component.context.engine.messages.storyViewList(id: component.storyItem.id, views: views, listMode: mappedListMode, sortMode: mappedSortMode, searchQuery: query, parentSource: parentSource)
                        }
                    }
                } else {
                    if self.configuration == ContentConfigurationKey(listMode: .everyone, sortMode: .reactionsFirst) {
                        let viewList: EngineStoryViewListContext
                        if let current = component.sharedListsContext.viewLists[StoryId(peerId: component.peerId, id: component.storyItem.id)] {
                            viewList = current
                        } else {
                            viewList = component.context.engine.messages.storyViewList(id: component.storyItem.id, views: views, listMode: .everyone, sortMode: .reactionsFirst)
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
                        let mappedSortMode: EngineStoryViewListContext.SortMode
                        switch self.configuration.sortMode {
                        case .reactionsFirst:
                            mappedSortMode = .reactionsFirst
                        case .recentFirst:
                            mappedSortMode = .recentFirst
                        }
                        self.viewList = component.context.engine.messages.storyViewList(id: component.storyItem.id, views: views, listMode: mappedListMode, sortMode: mappedSortMode, parentSource: component.sharedListsContext.viewLists[StoryId(peerId: component.peerId, id: component.storyItem.id)])
                    }
                }
            }
            
            var synchronous = false
            if let animationHint = transition.userData(AnimationHint.self) {
                synchronous = animationHint.synchronous
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
                            self.state?.updated(transition: Transition.immediate.withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: true)))
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
                    let _ = synchronous
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
                        self.contentLoaded = true
                    }
                }
            }
            
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
                    subtitle: "BBBBBBB",
                    subtitleAccessory: .checks,
                    presence: nil,
                    selectionState: .none,
                    hasNext: true,
                    action: { _ in
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
            if self.configuration.listMode == .everyone, let viewListState = self.viewListState, viewListState.loadMoreToken == nil, !viewListState.items.isEmpty, let views = component.storyItem.views, views.seenCount > viewListState.totalCount, component.storyItem.expirationTimestamp <= Int32(Date().timeIntervalSince1970) {
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
                bottomInset: component.safeInsets.bottom,
                topInset: navigationHeight,
                sideInset: sideInset,
                itemHeight: measureItemSize.height,
                itemCount: self.viewListState?.items.count ?? 0,
                premiumFooterSize: premiumFooterSize
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
            if self.scrollView.scrollIndicatorInsets != scrollIndicatorInsets {
                self.scrollView.scrollIndicatorInsets = scrollIndicatorInsets
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
                if self.query == nil, !component.hasPremium, let views = component.storyItem.views, views.seenCount != 0 {
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
                if self.configuration.listMode == .everyone && (self.query == nil || self.query == "") {
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
                        text = component.strings.Story_Views_NoViews
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
                            text = component.strings.Story_Views_NoViews
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
        
        override init(frame: CGRect) {
            self.navigationContainerView = UIView()
            self.navigationContainerView.clipsToBounds = true
            
            self.navigationBarBackground = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationSeparator = SimpleLayer()
            
            self.backgroundView = UIView()

            super.init(frame: frame)

            self.addSubview(self.backgroundView)
            
            self.addSubview(self.navigationBarBackground)
            self.layer.addSublayer(self.navigationSeparator)
            self.addSubview(self.navigationContainerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.backgroundView.frame.contains(point) && !self.navigationBarBackground.frame.contains(point) {
                return nil
            }
            
            return super.hitTest(point, with: event)
        }
        
        func animateIn(transition: Transition) {
            let offset = self.bounds.height - self.navigationBarBackground.frame.minY
            Transition.immediate.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: -offset))
            transition.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: 0.0))
        }
        
        func animateOut(transition: Transition, completion: @escaping () -> Void) {
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
            items.append(.action(ContextMenuActionItem(text: component.strings.Story_ViewList_ContextSortInfo, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction)))
            
            let contextItems = ContextController.Items(content: .list(items))
            
            let contextController = ContextController(account: component.context.account, presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView, position: .bottom)), items: .single(contextItems), gesture: nil)
            
            sourceView.alpha = 0.5
            contextController.dismissed = { [weak self, weak sourceView] in
                guard let self else {
                    return
                }
                let _ = self
                
                if let sourceView {
                    let transition = Transition(animation: .curve(duration: 0.25, curve: .easeInOut))
                    transition.setAlpha(view: sourceView, alpha: 1.0)
                }
            }
            controller.present(contextController, in: .window(.root))
        }
        
        func update(component: StoryItemSetViewListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
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
            
            let sideInset: CGFloat = 16.0
            
            let visualHeight: CGFloat = max(component.minHeight, component.effectiveHeight)
            
            let tabSelectorSize = self.tabSelector.update(
                transition: transition,
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
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.35, curve: .spring)))
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 10.0 * 2.0, height: 50.0)
            )
            
            let titleText: String
            if let views = component.storyItem.views, views.seenCount != 0 {
                if component.storyItem.expirationTimestamp <= Int32(Date().timeIntervalSince1970) {
                    titleText = component.strings.Story_Footer_Views(Int32(views.seenCount))
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
            
            let orderSelectorSize = self.orderSelector.update(
                transition: transition,
                component: AnyComponent(OptionButtonComponent(
                    colors: OptionButtonComponent.Colors(
                        background: UIColor(rgb: 0xffffff, alpha: 0.09),
                        foreground: .white
                    ),
                    icon: self.sortMode == .recentFirst ? "Chat/Context Menu/Time" : "Chat/Context Menu/Reactions",
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
            
            let navigationSearchSize = self.navigationSearch.update(
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
                    collapseFraction: 1.0,
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
                        if self.currentSearchQuery != query {
                            self.currentSearchQuery = query
                            self.state?.updated(transition: .immediate)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - component.safeInsets.left - component.safeInsets.right, height: 100.0)
            )
            
            var displayModeSelector = false
            var displaySearchBar = false
            var displaySortSelector = false
            
            if !component.hasPremium, component.storyItem.expirationTimestamp <= Int32(Date().timeIntervalSince1970) {
            } else {
                if let views = component.storyItem.views, views.hasList {
                    if let currentContentView = self.currentContentView, let totalCount = currentContentView.totalCount {
                        if totalCount >= 20 || component.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
                            displayModeSelector = true
                            displaySearchBar = true
                        }
                        if (views.reactedCount >= 10 && totalCount >= 20) || component.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
                            displaySortSelector = true
                        }
                    } else {
                        if views.seenCount >= 20 || component.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
                            displayModeSelector = true
                            displaySearchBar = true
                        }
                        if (views.reactedCount >= 10 && views.seenCount >= 20) || component.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
                            displaySortSelector = true
                        }
                    }
                }
                if let privacy = component.storyItem.privacy, case .everyone = privacy.base {
                } else {
                    displayModeSelector = false
                }
            }
            
            let navigationHeight: CGFloat
            if component.isSearchActive {
                navigationHeight = navigationSearchSize.height
            } else if displaySearchBar {
                navigationHeight = 56.0 + navigationSearchSize.height - 6.0
            } else {
                navigationHeight = 56.0
            }
            
            let navigationBarFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - visualHeight + 12.0), size: CGSize(width: availableSize.width, height: navigationHeight))
            transition.setFrame(view: self.navigationBarBackground, frame: navigationBarFrame)
            self.navigationBarBackground.update(size: navigationBarFrame.size, cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            
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
            
            if let navigationSearchView = self.navigationSearch.view {
                if navigationSearchView.superview == nil {
                    self.navigationContainerView.addSubview(navigationSearchView)
                }
                transition.setFrame(view: navigationSearchView, frame: CGRect(origin: CGPoint(x: component.safeInsets.left, y: component.isSearchActive ? 0.0 : 50.0), size: navigationSearchSize))
                transition.setAlpha(view: navigationSearchView, alpha: (displaySearchBar || component.isSearchActive) ? 1.0 : 0.0)
            }
            
            transition.setFrame(view: self.navigationContainerView, frame: navigationBarFrame)
            transition.setFrame(layer: self.navigationSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarFrame.maxY), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarFrame.maxY), size: CGSize(width: availableSize.width, height: availableSize.height)))
            
            let currentConfiguration = ContentConfigurationKey(listMode: self.listMode, sortMode: self.sortMode)
            if self.currentContentView?.configuration != currentConfiguration {
                let previousContentView = self.currentContentView
                self.disappearingCurrentContentView?.removeFromSuperview()
                self.disappearingCurrentContentView = self.currentContentView
                self.currentContentView = nil
                
                let currentContentView = ContentView(configuration: currentConfiguration)
                self.currentContentView = currentContentView
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
                }
            }
            
            if let currentContentView = self.currentContentView {
                var contentViewTransition = transition
                if currentContentView.superview == nil {
                    contentViewTransition = contentViewTransition.withAnimation(.none)
                    self.insertSubview(currentContentView, belowSubview: self.navigationBarBackground)
                }
                
                contentViewTransition.setFrame(view: currentContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                currentContentView.update(
                    component: component,
                    state: state,
                    baseContentView: nil,
                    query: nil,
                    availableSize: availableSize,
                    visualHeight: visualHeight,
                    sideInset: sideInset,
                    navigationHeight: navigationHeight,
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
                    self.insertSubview(currentSearchContentView, belowSubview: self.navigationBarBackground)
                }
                
                currentSearchContentView.hasContentUpdated = { [weak self] hasContent in
                    guard let self else {
                        return
                    }
                    self.currentContentView?.isHidden = hasContent
                    self.currentSearchContentView?.isHidden = !hasContent
                }
                contentViewTransition.setFrame(view: currentSearchContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                currentSearchContentView.update(
                    component: component,
                    state: state,
                    baseContentView: self.currentContentView,
                    query: self.currentSearchQuery,
                    availableSize: availableSize,
                    visualHeight: visualHeight,
                    sideInset: sideInset,
                    navigationHeight: navigationHeight,
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
                    state: state,
                    baseContentView: nil,
                    query: disappearingCurrentContentView.query,
                    availableSize: availableSize,
                    visualHeight: visualHeight,
                    sideInset: sideInset,
                    navigationHeight: navigationHeight,
                    transition: transition
                )
            }
            if let disappearingSearchContentView = self.disappearingSearchContentView {
                transition.setFrame(view: disappearingSearchContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                disappearingSearchContentView.update(
                    component: component,
                    state: state,
                    baseContentView: nil,
                    query: disappearingSearchContentView.query,
                    availableSize: availableSize,
                    visualHeight: visualHeight,
                    sideInset: sideInset,
                    navigationHeight: navigationHeight,
                    transition: transition
                )
            }
            
            transition.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: -max(0.0, visualHeight - component.effectiveHeight)))
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
