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
import StoryFooterPanelComponent
import PeerListItemComponent
import AnimatedStickerComponent
import AvatarNode
import Markdown
import ButtonComponent

final class StoryItemSetViewListComponent: Component {
    final class AnimationHint {
        let synchronous: Bool
        
        init(synchronous: Bool) {
            self.synchronous = synchronous
        }
    }
    
    final class ExternalState {
        fileprivate(set) var minimizedHeight: CGFloat = 0.0
        fileprivate(set) var defaultHeight: CGFloat = 0.0
        fileprivate(set) var minimizationFraction: CGFloat = 0.0
        
        init() {
        }
    }
    
    final class SharedListsContext {
        var viewLists: [StoryId: EngineStoryViewListContext] = [:]
        
        init() {
        }
    }
    
    let externalState: ExternalState
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let sharedListsContext: SharedListsContext
    let peerId: EnginePeer.Id
    let safeInsets: UIEdgeInsets
    let storyItem: EngineStoryItem
    let minimizedContentHeight: CGFloat
    let outerExpansionFraction: CGFloat
    let outerExpansionDirection: Bool
    let close: () -> Void
    let expandViewStats: () -> Void
    let deleteAction: () -> Void
    let moreAction: (UIView, ContextGesture?) -> Void
    let openPeer: (EnginePeer) -> Void
    let openPeerStories: (EnginePeer, AvatarNode) -> Void
    let openPremiumIntro: () -> Void
    
    init(
        externalState: ExternalState,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        sharedListsContext: SharedListsContext,
        peerId: EnginePeer.Id,
        safeInsets: UIEdgeInsets,
        storyItem: EngineStoryItem,
        minimizedContentHeight: CGFloat,
        outerExpansionFraction: CGFloat,
        outerExpansionDirection: Bool,
        close: @escaping () -> Void,
        expandViewStats: @escaping () -> Void,
        deleteAction: @escaping () -> Void,
        moreAction: @escaping (UIView, ContextGesture?) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openPeerStories: @escaping (EnginePeer, AvatarNode) -> Void,
        openPremiumIntro: @escaping () -> Void
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.strings = strings
        self.sharedListsContext = sharedListsContext
        self.peerId = peerId
        self.safeInsets = safeInsets
        self.storyItem = storyItem
        self.minimizedContentHeight = minimizedContentHeight
        self.outerExpansionFraction = outerExpansionFraction
        self.outerExpansionDirection = outerExpansionDirection
        self.close = close
        self.expandViewStats = expandViewStats
        self.deleteAction = deleteAction
        self.moreAction = moreAction
        self.openPeer = openPeer
        self.openPeerStories = openPeerStories
        self.openPremiumIntro = openPremiumIntro
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
        if lhs.minimizedContentHeight != rhs.minimizedContentHeight {
            return false
        }
        if lhs.outerExpansionFraction != rhs.outerExpansionFraction {
            return false
        }
        if lhs.outerExpansionDirection != rhs.outerExpansionDirection {
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
        
        var contentSize: CGSize
        
        init(containerSize: CGSize, bottomInset: CGFloat, topInset: CGFloat, sideInset: CGFloat, itemHeight: CGFloat, itemCount: Int) {
            self.containerSize = containerSize
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.sideInset = sideInset
            self.itemHeight = itemHeight
            self.itemCount = itemCount
            
            self.contentSize = CGSize(width: containerSize.width, height: topInset + CGFloat(itemCount) * itemHeight + bottomInset)
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
    
    private final class PanState {
        var startContentOffsetY: CGFloat = 0.0
        var fraction: CGFloat = 0.0
        var accumulatedOffset: CGFloat = 0.0
        
        init() {
            
        }
    }
    
    private final class EventCycleState {
        var ignoreScrolling: Bool = false
        
        init() {
        }
    }

    final class View: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private let navigationBarBackground: BlurredBackgroundView
        private let navigationSeparator: SimpleLayer
        
        private let navigationPanel = ComponentView<Empty>()
        
        private let navigationLeftButton = ComponentView<Empty>()
        
        private let backgroundView: UIView
        private let scrollView: UIScrollView
        
        private var itemLayout: ItemLayout?
        
        private let measureItem = ComponentView<Empty>()
        private var placeholderImage: UIImage?
        
        private var visibleItems: [EnginePeer.Id: ComponentView<Empty>] = [:]
        private var visiblePlaceholderViews: [Int: UIImageView] = [:]
        
        private var emptyIcon: ComponentView<Empty>?
        private var emptyText: ComponentView<Empty>?

        private var component: StoryItemSetViewListComponent?
        private weak var state: EmptyComponentState?
        
        private var ignoreScrolling: Bool = false
        
        private var viewListDisposable: Disposable?
        private var viewListState: EngineStoryViewListContext.State?
        private var requestedLoadMoreToken: EngineStoryViewListContext.LoadMoreToken?
        
        private var dismissPanState: PanState?
        private var eventCycleState: EventCycleState?
        
        override init(frame: CGRect) {
            self.navigationBarBackground = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationSeparator = SimpleLayer()
            
            self.backgroundView = UIView()
            
            self.scrollView = ScrollView()
            self.scrollView.canCancelContentTouches = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.indicatorStyle = .white

            super.init(frame: frame)
            
            self.scrollView.delegate = self

            self.addSubview(self.backgroundView)
            self.addSubview(self.scrollView)
            
            self.addSubview(self.navigationBarBackground)
            self.layer.addSublayer(self.navigationSeparator)
            
            let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { _ in
                return [.down]
            })
            panRecognizer.delegate = self
            self.addGestureRecognizer(panRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.viewListDisposable?.dispose()
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if otherGestureRecognizer === self.scrollView.panGestureRecognizer {
                return true
            } else {
                return false
            }
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                if case .began = recognizer.state {
                    let dismissPanState = PanState()
                    dismissPanState.startContentOffsetY = 0.0
                    self.dismissPanState = dismissPanState
                }
                
                if let dismissPanState = self.dismissPanState {
                    let relativeTranslationY = recognizer.translation(in: self).y - dismissPanState.startContentOffsetY
                    let overflowY = self.scrollView.contentOffset.y - relativeTranslationY
                    
                    dismissPanState.accumulatedOffset += -overflowY
                    dismissPanState.accumulatedOffset = max(0.0, dismissPanState.accumulatedOffset)
                    
                    if dismissPanState.accumulatedOffset > 0.0 {
                        self.scrollView.contentOffset = CGPoint()
                        
                        let eventCycleState = EventCycleState()
                        eventCycleState.ignoreScrolling = true
                        self.eventCycleState = eventCycleState
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self else {
                                return
                            }
                            self.eventCycleState = nil
                        }
                    }
                    
                    dismissPanState.startContentOffsetY = recognizer.translation(in: self).y
                    
                    self.state?.updated(transition: .immediate)
                }
            case .cancelled, .ended:
                if let dismissPanState = self.dismissPanState {
                    self.dismissPanState = nil
                    
                    let relativeTranslationY = recognizer.translation(in: self).y - dismissPanState.startContentOffsetY
                    let overflowY = self.scrollView.contentOffset.y - relativeTranslationY
                    
                    dismissPanState.accumulatedOffset += -overflowY
                    dismissPanState.accumulatedOffset = max(0.0, dismissPanState.accumulatedOffset)
                    
                    if dismissPanState.accumulatedOffset > 0.0 {
                        self.scrollView.contentOffset = CGPoint()
                        
                        let eventCycleState = EventCycleState()
                        eventCycleState.ignoreScrolling = true
                        self.eventCycleState = eventCycleState
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self else {
                                return
                            }
                            self.eventCycleState = nil
                        }
                    }
                    
                    let velocityY = recognizer.velocity(in: self).y
                    if dismissPanState.accumulatedOffset > 150.0 || (dismissPanState.accumulatedOffset > 0.0 && velocityY > 300.0) {
                        self.component?.close()
                    } else {
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.2, curve: .easeInOut)))
                    }
                }
            default:
                break
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let navigationPanelView = self.navigationPanel.view as? StoryFooterPanelComponent.View {
                if navigationPanelView.frame.contains(point), let result = navigationPanelView.externalContainerView.hitTest(self.convert(point, to: navigationPanelView.externalContainerView), with: event), result !== navigationPanelView.externalContainerView {
                    return result
                }
                if let result = navigationPanelView.hitTest(self.convert(point, to: navigationPanelView), with: event) {
                    if result !== navigationPanelView {
                        return result
                    }
                }
            }
            if let navigationLeftButtonView = self.navigationLeftButton.view {
                if let result = navigationLeftButtonView.hitTest(self.convert(point, to: navigationLeftButtonView), with: event) {
                    return result
                }
            }
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
                    guard let viewListState = self.viewListState, index < viewListState.totalCount else {
                        continue
                    }
                    
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
                    
                    var itemTransition = transition
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
                            selectionState: .none,
                            hasNext: index != viewListState.totalCount - 1,
                            action: { [weak self] peer in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.openPeer(peer)
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
            
            if let viewList = component.sharedListsContext.viewLists[StoryId(peerId: component.peerId, id: component.storyItem.id)], let viewListState = self.viewListState, viewListState.loadMoreToken != nil, visibleBounds.maxY >= self.scrollView.contentSize.height - 200.0 {
                if self.requestedLoadMoreToken != viewListState.loadMoreToken {
                    self.requestedLoadMoreToken = viewListState.loadMoreToken
                    viewList.loadMore()
                }
            }
        }
        
        func update(component: StoryItemSetViewListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            let itemUpdated = self.component?.storyItem.id != component.storyItem.id
            let viewsNilUpdated = (self.component?.storyItem.views == nil) != (component.storyItem.views == nil)
            
            self.component = component
            self.state = state
            
            var synchronous = false
            if let animationHint = transition.userData(AnimationHint.self) {
                synchronous = animationHint.synchronous
            }
            
            let minimizedHeight = max(100.0, availableSize.height - (component.minimizedContentHeight + 12.0))
            
            if themeUpdated {
                self.backgroundView.backgroundColor = component.theme.rootController.navigationBar.blurredBackgroundColor
                self.navigationBarBackground.updateColor(color: component.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.navigationSeparator.backgroundColor = component.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            if itemUpdated || viewsNilUpdated {
                self.viewListDisposable?.dispose()
                
                if let views = component.storyItem.views {
                    self.viewListState = nil
                    
                    let viewList: EngineStoryViewListContext
                    if let current = component.sharedListsContext.viewLists[StoryId(peerId: component.peerId, id: component.storyItem.id)] {
                        viewList = current
                    } else {
                        viewList = component.context.engine.messages.storyViewList(id: component.storyItem.id, views: views)
                        component.sharedListsContext.viewLists[StoryId(peerId: component.peerId, id: component.storyItem.id)] = viewList
                    }
                    
                    var applyState = false
                    var firstTime = true
                    self.viewListDisposable = (viewList.state
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
                            self.state?.updated(transition: Transition.immediate.withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: false)))
                        }
                    })
                    applyState = true
                    let _ = synchronous
                } else {
                    self.viewListState = EngineStoryViewListContext.State(totalCount: 0, items: [], loadMoreToken: nil)
                }
            }
            
            let sideInset: CGFloat = 16.0
            
            let navigationHeight: CGFloat = 56.0
            let navigationBarFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - minimizedHeight + 12.0), size: CGSize(width: availableSize.width, height: navigationHeight))
            transition.setFrame(view: self.navigationBarBackground, frame: navigationBarFrame)
            self.navigationBarBackground.update(size: navigationBarFrame.size, cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            
            transition.setFrame(layer: self.navigationSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarFrame.maxY), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            let navigationLeftButtonSize = self.navigationLeftButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: component.strings.Common_Close, font: Font.regular(17.0), color: component.theme.rootController.navigationBar.accentTextColor)),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.close()
                    }
                ).minSize(CGSize(width: 44.0, height: 56.0))),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            let navigationLeftButtonFrame = CGRect(origin: CGPoint(x: 16.0, y: navigationBarFrame.minY + 1.0), size: navigationLeftButtonSize)
            if let navigationLeftButtonView = self.navigationLeftButton.view {
                if navigationLeftButtonView.superview == nil {
                    self.addSubview(navigationLeftButtonView)
                }
                transition.setFrame(view: navigationLeftButtonView, frame: navigationLeftButtonFrame)
            }
            
            let expansionOffset = availableSize.height - self.navigationBarBackground.frame.minY
            
            var dismissOffsetY: CGFloat = 0.0
            if let dismissPanState = self.dismissPanState {
                dismissOffsetY = -dismissPanState.accumulatedOffset
            }
            
            let selfFraction = expansionOffset / availableSize.height
            
            var mappedOuterExpansionFraction: CGFloat
            if component.outerExpansionDirection {
                mappedOuterExpansionFraction = component.outerExpansionFraction / (1.0 - selfFraction)
            } else {
                mappedOuterExpansionFraction = 1.0 - (1.0 - component.outerExpansionFraction) / (1.0 - selfFraction)
            }
            mappedOuterExpansionFraction = max(0.0, min(1.0, mappedOuterExpansionFraction))
            
            dismissOffsetY -= (1.0 - mappedOuterExpansionFraction) * expansionOffset
            
            let dismissFraction: CGFloat = 1.0 - max(0.0, min(1.0, -dismissOffsetY / expansionOffset))
            
            var externalViews: EngineStoryItem.Views? = component.storyItem.views
            if let viewListState = self.viewListState, !viewListState.items.isEmpty {
                externalViews = EngineStoryItem.Views(seenCount: viewListState.totalCount, seenPeers: viewListState.items.prefix(3).map(\.peer))
            }
            
            let navigationPanelSize = self.navigationPanel.update(
                transition: transition,
                component: AnyComponent(StoryFooterPanelComponent(
                    context: component.context,
                    strings: component.strings,
                    storyItem: component.storyItem,
                    externalViews: externalViews,
                    expandFraction: dismissFraction,
                    expandViewStats: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.expandViewStats()
                    },
                    deleteAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.deleteAction()
                    },
                    moreAction: { [weak self] sourceView, gesture in
                        guard let self, let component = self.component else {
                            return
                        } 
                        component.moreAction(sourceView, gesture)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 200.0)
            )
            if let navigationPanelView = self.navigationPanel.view as? StoryFooterPanelComponent.View {
                if navigationPanelView.superview == nil {
                    self.addSubview(navigationPanelView)
                    self.insertSubview(navigationPanelView.externalContainerView, belowSubview: self.navigationBarBackground)
                }
                
                let expandedNavigationPanelFrame = CGRect(origin: CGPoint(x: navigationBarFrame.minX, y: navigationBarFrame.minY + 4.0), size: navigationPanelSize)
                let collapsedNavigationPanelFrame = CGRect(origin: CGPoint(x: navigationBarFrame.minX, y: navigationBarFrame.minY - navigationPanelSize.height - component.safeInsets.bottom - 1.0), size: navigationPanelSize)
                
                transition.setFrame(view: navigationPanelView, frame: collapsedNavigationPanelFrame.interpolate(to: expandedNavigationPanelFrame, amount: dismissFraction))
                transition.setFrame(view: navigationPanelView.externalContainerView, frame: collapsedNavigationPanelFrame.interpolate(to: expandedNavigationPanelFrame, amount: dismissFraction))
            }
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarFrame.maxY), size: CGSize(width: availableSize.width, height: availableSize.height)))
            
            let measureItemSize = self.measureItem.update(
                transition: .immediate,
                component: AnyComponent(PeerListItemComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    style: .generic,
                    sideInset: sideInset,
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
            
            let itemLayout = ItemLayout(
                containerSize: CGSize(width: availableSize.width, height: minimizedHeight),
                bottomInset: component.safeInsets.bottom,
                topInset: navigationHeight,
                sideInset: sideInset,
                itemHeight: measureItemSize.height,
                itemCount: self.viewListState?.items.count ?? 0
            )
            self.itemLayout = itemLayout
            
            let scrollContentSize = itemLayout.contentSize
            
            self.ignoreScrolling = true
            
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarFrame.minY), size: CGSize(width: availableSize.width, height: minimizedHeight)))
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
            
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            if let viewListState = self.viewListState, viewListState.loadMoreToken == nil, viewListState.items.isEmpty, viewListState.totalCount == 0 {
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
                
                let emptyIconSize = emptyIcon.update(
                    transition: emptyTransition,
                    component: AnyComponent(AnimatedStickerComponent(
                        account: component.context.account,
                        animation: AnimatedStickerComponent.Animation(source: .bundle(name: "Burn"), loop: true),
                        size: CGSize(width: 140.0, height: 140.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 140.0, height: 140.0)
                )
                
                let fontSize: CGFloat = 16.0
                let body = MarkdownAttributeSet(font: Font.regular(fontSize), textColor: component.theme.list.itemSecondaryTextColor)
                let bold = MarkdownAttributeSet(font: Font.semibold(fontSize), textColor: component.theme.list.itemSecondaryTextColor)
                let link = MarkdownAttributeSet(font: Font.semibold(fontSize), textColor: component.theme.list.itemAccentColor)
                let attributes = MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in nil })
                
                let text: String
                if component.storyItem.expirationTimestamp <= Int32(Date().timeIntervalSince1970) {
                    text = component.strings.Story_Views_ViewsExpired
                } else {
                    text = component.strings.Story_Views_NoViews
                }
                let textSize = emptyText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(text: text, attributes: attributes),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: min(330.0, availableSize.width - 16.0 * 2.0), height: 1000.0)
                )
                 
                let emptyContentSpacing: CGFloat = 20.0
                let emptyContentHeight = emptyIconSize.height + emptyContentSpacing + textSize.height
                var emptyContentY = navigationBarFrame.minY + floor((availableSize.height - navigationBarFrame.minY - emptyContentHeight) * 0.5)
                
                if let emptyIconView = emptyIcon.view {
                    if emptyIconView.superview == nil {
                        self.insertSubview(emptyIconView, belowSubview: self.scrollView)
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
            } else {
                if let emptyIcon = self.emptyIcon {
                    self.emptyIcon = nil
                    emptyIcon.view?.removeFromSuperview()
                }
                if let emptyText = self.emptyText {
                    self.emptyText = nil
                    emptyText.view?.removeFromSuperview()
                }
            }
            
            transition.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: dismissOffsetY))
            
            component.externalState.minimizedHeight = minimizedHeight
            component.externalState.defaultHeight = 60.0 + component.safeInsets.bottom + 1.0
            
            //let effectiveHeight: CGFloat = minimizedHeight * dismissFraction + (1.0 - dismissFraction) * (60.0 + component.safeInsets.bottom + 1.0)
            //component.externalState.effectiveHeight = min(minimizedHeight, max(0.0, effectiveHeight))
            component.externalState.minimizationFraction = dismissFraction
            
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
