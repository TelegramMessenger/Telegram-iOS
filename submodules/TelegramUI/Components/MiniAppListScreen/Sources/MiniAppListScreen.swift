import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MergeLists
import ComponentDisplayAdapters
import ItemListPeerItem
import ItemListUI
import ChatListHeaderComponent
import PlainButtonComponent
import MultilineTextComponent
import SearchBarNode
import BalancedTextComponent
import ChatListSearchItemHeader

final class MiniAppListScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: MiniAppListScreen.InitialData
    
    init(
        context: AccountContext,
        initialData: MiniAppListScreen.InitialData
    ) {
        self.context = context
        self.initialData = initialData
    }

    static func ==(lhs: MiniAppListScreenComponent, rhs: MiniAppListScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }

        return true
    }
    
    private enum ContentEntry: Comparable, Identifiable {
        enum Id: Hashable {
            case item(EnginePeer.Id)
        }
        
        var stableId: Id {
            switch self {
            case let .item(peer, _):
                return .item(peer.id)
            }
        }
        
        case item(peer: EnginePeer, sortIndex: Int)
        
        static func <(lhs: ContentEntry, rhs: ContentEntry) -> Bool {
            switch lhs {
            case let .item(lhsPeer, lhsSortIndex):
                switch rhs {
                case let .item(rhsPeer, rhsSortIndex):
                    if lhsSortIndex != rhsSortIndex {
                        return lhsSortIndex < rhsSortIndex
                    }
                    return lhsPeer.id < rhsPeer.id
                }
            }
        }
        
        func item(listNode: ContentListNode) -> ListViewItem {
            switch self {
            case let .item(peer, _):
                let text: ItemListPeerItemText
                if case let .user(user) = peer, let subscriberCount = user.subscriberCount {
                    text = .text(listNode.presentationData.strings.Conversation_StatusBotSubscribers(subscriberCount), .secondary)
                } else {
                    text = .none
                }
                
                return ItemListPeerItem(
                    presentationData: ItemListPresentationData(listNode.presentationData),
                    dateTimeFormat: listNode.presentationData.dateTimeFormat,
                    nameDisplayOrder: listNode.presentationData.nameDisplayOrder,
                    context: listNode.context,
                    peer: peer,
                    presence: nil,
                    text: text,
                    label: .none,
                    editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: nil),
                    enabled: true,
                    selectable: true,
                    sectionId: 0,
                    action: { [weak listNode] in
                        guard let listNode else {
                            return
                        }
                        if let view = listNode.parentView {
                            view.openItem(peer: peer)
                        }
                    },
                    setPeerIdWithRevealedOptions: { _, _ in
                    },
                    removePeer: { _ in
                    },
                    noInsets: true,
                    header: nil
                )
            }
        }
    }
    
    private final class ContentListNode: ListView {
        weak var parentView: View?
        let context: AccountContext
        var presentationData: PresentationData
        private var currentEntries: [ContentEntry] = []
        private var originalEntries: [ContentEntry] = []
        
        init(parentView: View, context: AccountContext) {
            self.parentView = parentView
            self.context = context
            self.presentationData = context.sharedContext.currentPresentationData.with({ $0 })
            
            super.init()
        }
        
        func update(size: CGSize, insets: UIEdgeInsets, transition: ComponentTransition) {
            let (listViewDuration, listViewCurve) = listViewAnimationDurationAndCurve(transition: transition.containedViewLayoutTransition)
            self.transaction(
                deleteIndices: [],
                insertIndicesAndItems: [],
                updateIndicesAndItems: [],
                options: [.Synchronous, .LowLatency, .PreferSynchronousResourceLoading],
                additionalScrollDistance: 0.0,
                updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: listViewDuration, curve: listViewCurve),
                updateOpaqueState: nil
            )
        }
        
        func setEntries(entries: [ContentEntry], animated: Bool) {
            self.originalEntries = entries
            
            let entries = entries
            
            let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.currentEntries, rightList: entries)
            self.currentEntries = entries
            
            let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
            let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(listNode: self), directionHint: nil) }
            let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(listNode: self), directionHint: nil) }
            
            var options: ListViewDeleteAndInsertOptions = [.Synchronous, .LowLatency]
            if animated {
                options.insert(.AnimateInsertion)
            } else {
                options.insert(.PreferSynchronousResourceLoading)
            }
            
            self.transaction(
                deleteIndices: deletions,
                insertIndicesAndItems: insertions,
                updateIndicesAndItems: updates,
                options: options,
                scrollToItem: nil,
                stationaryItemRange: nil,
                updateOpaqueState: nil,
                completion: { _ in
                }
            )
        }
    }
    
    final class View: UIView {
        private var contentListNode: ContentListNode?
        private var ignoreVisibleContentOffsetChanged: Bool = false
        private var emptySearchState: ComponentView<Empty>?
        
        private let navigationBarView = ComponentView<Empty>()
        private var navigationHeight: CGFloat?
        
        private let sectionHeader = ComponentView<Empty>()
        
        private var searchBarNode: SearchBarNode?
        
        private var isUpdating: Bool = false
        
        private var component: MiniAppListScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var recommendedAppPeers: [EnginePeer]?
        private var recommendedAppPeersDisposable: Disposable?
        private var keepUpdatedDisposable: Disposable?
        
        private var isSearchDisplayControllerActive: Bool = false
        private var searchQuery: String = ""
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.recommendedAppPeersDisposable?.dispose()
            self.keepUpdatedDisposable?.dispose()
        }

        func scrollToTop() {
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            return true
        }
        
        func openItem(peer: EnginePeer) {
            guard let component = self.component else {
                return
            }
            guard let environment = self.environment, let controller = environment.controller() else {
                return
            }
            
            if let peerInfoScreen = component.context.sharedContext.makePeerInfoController(context: component.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                peerInfoScreen.navigationPresentation = .modal
                controller.push(peerInfoScreen)
            }
        }
        
        private func updateNavigationBar(
            component: MiniAppListScreenComponent,
            theme: PresentationTheme,
            strings: PresentationStrings,
            size: CGSize,
            insets: UIEdgeInsets,
            statusBarHeight: CGFloat,
            isModal: Bool,
            transition: ComponentTransition,
            deferScrollApplication: Bool
        ) -> CGFloat {
            let rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = []
            
            let titleText: String = strings.MiniAppList_Title
            
            let closeTitle: String = strings.Common_Close
            let headerContent: ChatListHeaderComponent.Content? = ChatListHeaderComponent.Content(
                title: titleText,
                navigationBackTitle: nil,
                titleComponent: nil,
                chatListTitle: nil,
                leftButton: isModal ? AnyComponentWithIdentity(id: "close", component: AnyComponent(NavigationButtonComponent(
                    content: .text(title: closeTitle, isBold: false),
                    pressed: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if self.attemptNavigation(complete: {}) {
                            self.environment?.controller()?.dismiss()
                        }
                    }
                ))) : nil,
                rightButtons: rightButtons,
                backTitle: isModal ? nil : strings.Common_Back,
                backPressed: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    if self.attemptNavigation(complete: {}) {
                        self.environment?.controller()?.dismiss()
                    }
                }
            )
            
            let navigationBarSize = self.navigationBarView.update(
                transition: transition,
                component: AnyComponent(ChatListNavigationBar(
                    context: component.context,
                    theme: theme,
                    strings: strings,
                    statusBarHeight: statusBarHeight,
                    sideInset: insets.left,
                    isSearchActive: self.isSearchDisplayControllerActive,
                    isSearchEnabled: true,
                    primaryContent: headerContent,
                    secondaryContent: nil,
                    secondaryTransition: 0.0,
                    storySubscriptions: nil,
                    storiesIncludeHidden: false,
                    uploadProgress: [:],
                    tabsNode: nil,
                    tabsNodeIsSearch: false,
                    accessoryPanelContainer: nil,
                    accessoryPanelContainerHeight: 0.0,
                    activateSearch: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        self.isSearchDisplayControllerActive = true
                        self.state?.updated(transition: .spring(duration: 0.4))
                    },
                    openStatusSetup: { _ in
                    },
                    allowAutomaticOrder: {
                    }
                )),
                environment: {},
                containerSize: size
            )
            
            let sectionHeaderSize = self.sectionHeader.update(
                transition: transition,
                component: AnyComponent(ListHeaderComponent(
                    theme: theme,
                    title: strings.MiniAppList_ListSectionHeader
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: 1000.0)
            )
            if let sectionHeaderView = self.sectionHeader.view {
                if sectionHeaderView.superview == nil {
                    sectionHeaderView.layer.anchorPoint = CGPoint()
                    self.addSubview(sectionHeaderView)
                }
                transition.setBounds(view: sectionHeaderView, bounds: CGRect(origin: CGPoint(), size: sectionHeaderSize))
            }
            
            if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                if deferScrollApplication {
                    navigationBarComponentView.deferScrollApplication = true
                }
                
                if navigationBarComponentView.superview == nil {
                    self.addSubview(navigationBarComponentView)
                }
                transition.setFrame(view: navigationBarComponentView, frame: CGRect(origin: CGPoint(), size: navigationBarSize))
                
                return navigationBarSize.height
            } else {
                return 0.0
            }
        }
        
        private func updateNavigationScrolling(navigationHeight: CGFloat, transition: ComponentTransition) {
            var mainOffset: CGFloat
            if let recommendedAppPeers = self.recommendedAppPeers, !recommendedAppPeers.isEmpty {
                if let contentListNode = self.contentListNode {
                    switch contentListNode.visibleContentOffset() {
                    case .none:
                        mainOffset = 0.0
                    case .unknown:
                        mainOffset = navigationHeight
                    case let .known(value):
                        mainOffset = value
                    }
                } else {
                    mainOffset = navigationHeight
                }
            } else {
                mainOffset = navigationHeight
            }
            
            mainOffset = min(mainOffset, ChatListNavigationBar.searchScrollHeight)
            if abs(mainOffset) < 0.1 {
                mainOffset = 0.0
            }
            
            let resultingOffset = mainOffset
            
            var offset = resultingOffset
            if self.isSearchDisplayControllerActive {
                offset = 0.0
            }
            
            if let sectionHeaderView = self.sectionHeader.view {
                transition.setPosition(view: sectionHeaderView, position: CGPoint(x: 0.0, y: navigationHeight - offset))
            }
            
            if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                navigationBarComponentView.applyScroll(offset: offset, allowAvatarsExpansion: false, forceUpdate: false, transition: transition.withUserData(ChatListNavigationBar.AnimationHint(
                    disableStoriesAnimations: false,
                    crossfadeStoryPeers: false
                )))
            }
        }
        
        func update(component: MiniAppListScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.recommendedAppPeers = component.initialData.recommendedAppPeers
                
                /*self.shortcutMessageListDisposable = (component.context.engine.accountData.shortcutMessageList(onlyRemote: false)
                |> deliverOnMainQueue).startStrict(next: { [weak self] shortcutMessageList in
                    guard let self else {
                        return
                    }
                    self.shortcutMessageList = shortcutMessageList
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                })*/
                
                self.keepUpdatedDisposable = component.context.engine.peers.requestRecommendedAppsIfNeeded().startStrict()
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.plainBackgroundColor
            }
            
            var isModal = false
            if let controller = environment.controller(), controller.navigationPresentation == .modal {
                isModal = true
            }
            
            var statusBarHeight = environment.statusBarHeight
            if isModal {
                statusBarHeight = max(statusBarHeight, 1.0)
            }
            
            let listBottomInset = environment.safeInsets.bottom + environment.additionalInsets.bottom
            let navigationHeight = self.updateNavigationBar(
                component: component,
                theme: environment.theme,
                strings: environment.strings,
                size: availableSize,
                insets: environment.safeInsets,
                statusBarHeight: statusBarHeight,
                isModal: isModal,
                transition: transition,
                deferScrollApplication: true
            )
            self.navigationHeight = navigationHeight
            
            var removedSearchBar: SearchBarNode?
            if self.isSearchDisplayControllerActive {
                let searchBarNode: SearchBarNode
                var searchBarTransition = transition
                if let current = self.searchBarNode {
                    searchBarNode = current
                } else {
                    searchBarTransition = .immediate
                    let searchBarTheme = SearchBarNodeTheme(theme: environment.theme, hasSeparator: false)
                    searchBarNode = SearchBarNode(
                        theme: searchBarTheme,
                        strings: environment.strings,
                        fieldStyle: .modern,
                        displayBackground: false
                    )
                    searchBarNode.placeholderString = NSAttributedString(string: environment.strings.Common_Search, font: Font.regular(17.0), textColor: searchBarTheme.placeholder)
                    self.searchBarNode = searchBarNode
                    searchBarNode.cancel = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.isSearchDisplayControllerActive = false
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                    searchBarNode.textUpdated = { [weak self] query, _ in
                        guard let self else {
                            return
                        }
                        if self.searchQuery != query {
                            self.searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                            self.state?.updated(transition: .immediate)
                        }
                    }
                    DispatchQueue.main.async { [weak self, weak searchBarNode] in
                        guard let self, let searchBarNode, self.searchBarNode === searchBarNode else {
                            return
                        }
                        searchBarNode.activate()
                    }
                }
                
                var searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight - 54.0 + 2.0), size: CGSize(width: availableSize.width, height: 54.0))
                if isModal {
                    searchBarFrame.origin.y += 2.0
                }
                searchBarNode.updateLayout(boundingSize: searchBarFrame.size, leftInset: environment.safeInsets.left + 6.0, rightInset: environment.safeInsets.right, transition: searchBarTransition.containedViewLayoutTransition)
                searchBarTransition.setFrame(view: searchBarNode.view, frame: searchBarFrame)
                if searchBarNode.view.superview == nil {
                    self.addSubview(searchBarNode.view)
                    
                    if case let .curve(duration, curve) = transition.animation, let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View, let placeholderNode = navigationBarView.searchContentNode?.placeholderNode {
                        let timingFunction: String
                        switch curve {
                        case .easeInOut:
                            timingFunction = CAMediaTimingFunctionName.easeOut.rawValue
                        case .linear:
                            timingFunction = CAMediaTimingFunctionName.linear.rawValue
                        case .spring:
                            timingFunction = kCAMediaTimingFunctionSpring
                        case .custom:
                            timingFunction = kCAMediaTimingFunctionSpring
                        }
                        
                        searchBarNode.animateIn(from: placeholderNode, duration: duration, timingFunction: timingFunction)
                    }
                }
            } else {
                self.searchQuery = ""
                if let searchBarNode = self.searchBarNode {
                    self.searchBarNode = nil
                    removedSearchBar = searchBarNode
                }
            }
            
            let contentListNode: ContentListNode
            if let current = self.contentListNode {
                contentListNode = current
            } else {
                contentListNode = ContentListNode(parentView: self, context: component.context)
                self.contentListNode = contentListNode
                
                contentListNode.visibleContentOffsetChanged = { [weak self] offset in
                    guard let self else {
                        return
                    }
                    guard let navigationHeight = self.navigationHeight else {
                        return
                    }
                    if self.ignoreVisibleContentOffsetChanged {
                        return
                    }
                    self.updateNavigationScrolling(navigationHeight: navigationHeight, transition: .immediate)
                }
                
                if let sectionHeaderView = self.sectionHeader.view {
                    self.insertSubview(contentListNode.view, belowSubview: sectionHeaderView)
                } else if let navigationBarComponentView = self.navigationBarView.view {
                    self.insertSubview(contentListNode.view, belowSubview: navigationBarComponentView)
                } else {
                    self.addSubview(contentListNode.view)
                }
            }
            
            var contentTopInset = navigationHeight
            if let sectionHeaderView = self.sectionHeader.view {
                contentTopInset += sectionHeaderView.bounds.height
            }
            transition.setFrame(view: contentListNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.ignoreVisibleContentOffsetChanged = true
            contentListNode.update(size: availableSize, insets: UIEdgeInsets(top: contentTopInset, left: environment.safeInsets.left, bottom: listBottomInset, right: environment.safeInsets.right), transition: transition)
            self.ignoreVisibleContentOffsetChanged = false
            
            var entries: [ContentEntry] = []
            if let recommendedAppPeers = self.recommendedAppPeers {
                let normalizedSearchQuery = self.searchQuery.lowercased().trimmingTrailingSpaces()
                for peer in recommendedAppPeers {
                    if !self.searchQuery.isEmpty {
                        var matches = false
                        if peer.indexName.matchesByTokens(normalizedSearchQuery) {
                            matches = true
                        }
                        if !matches {
                            continue
                        }
                    }
                    entries.append(.item(peer: peer, sortIndex: entries.count))
                }
            }
            contentListNode.setEntries(entries: entries, animated: !transition.animation.isImmediate)
            if let sectionHeaderView = self.sectionHeader.view {
                sectionHeaderView.isHidden = entries.isEmpty
            }
            
            if !self.searchQuery.isEmpty && entries.isEmpty {
                var emptySearchStateTransition = transition
                let emptySearchState: ComponentView<Empty>
                if let current = self.emptySearchState {
                    emptySearchState = current
                } else {
                    emptySearchStateTransition = emptySearchStateTransition.withAnimation(.none)
                    emptySearchState = ComponentView()
                    self.emptySearchState = emptySearchState
                }
                let emptySearchStateSize = emptySearchState.update(
                    transition: .immediate,
                    component: AnyComponent(BalancedTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.Conversation_SearchNoResults, font: Font.regular(17.0), textColor: environment.theme.list.freeTextColor, paragraphAlignment: .center)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: availableSize.height)
                )
                var emptySearchStateBottomInset = listBottomInset
                emptySearchStateBottomInset = max(emptySearchStateBottomInset, environment.inputHeight)
                let emptySearchStateFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - emptySearchStateSize.width) * 0.5), y: navigationHeight + floor((availableSize.height - emptySearchStateBottomInset - navigationHeight) * 0.5)), size: emptySearchStateSize)
                if let emptySearchStateView = emptySearchState.view {
                    if emptySearchStateView.superview == nil {
                        if let navigationBarComponentView = self.navigationBarView.view {
                            self.insertSubview(emptySearchStateView, belowSubview: navigationBarComponentView)
                        } else {
                            self.addSubview(emptySearchStateView)
                        }
                    }
                    emptySearchStateTransition.containedViewLayoutTransition.updatePosition(layer: emptySearchStateView.layer, position: emptySearchStateFrame.center)
                    emptySearchStateView.bounds = CGRect(origin: CGPoint(), size: emptySearchStateFrame.size)
                }
            } else if let emptySearchState = self.emptySearchState {
                self.emptySearchState = nil
                emptySearchState.view?.removeFromSuperview()
            }
            
            if let recommendedAppPeers = self.recommendedAppPeers, !recommendedAppPeers.isEmpty {
                contentListNode.isHidden = false
            } else {
                contentListNode.isHidden = true
            }
            
            self.updateNavigationScrolling(navigationHeight: navigationHeight, transition: transition)
            
            if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                navigationBarComponentView.deferScrollApplication = false
                navigationBarComponentView.applyCurrentScroll(transition: transition)
            }
            
            if let removedSearchBar {
                if !transition.animation.isImmediate, let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View, let placeholderNode =
                    navigationBarView.searchContentNode?.placeholderNode {
                    removedSearchBar.transitionOut(to: placeholderNode, transition: transition.containedViewLayoutTransition, completion: { [weak removedSearchBar] in
                        removedSearchBar?.view.removeFromSuperview()
                    })
                } else {
                    removedSearchBar.view.removeFromSuperview()
                }
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class MiniAppListScreen: ViewControllerComponentContainer {
    public final class InitialData: MiniAppListScreenInitialData {
        let recommendedAppPeers: [EnginePeer]
        
        init(
            recommendedAppPeers: [EnginePeer]
        ) {
            self.recommendedAppPeers = recommendedAppPeers
        }
    }
    
    private let context: AccountContext
    
    public init(context: AccountContext, initialData: InitialData) {
        self.context = context
        
        super.init(context: context, component: MiniAppListScreenComponent(
            context: context,
            initialData: initialData
        ), navigationBarAppearance: .none, theme: .default, updatedPresentationData: nil)
        
        self.navigationPresentation = .modal
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? MiniAppListScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? MiniAppListScreenComponent.View else {
                return true
            }
            
            return componentView.attemptNavigation(complete: complete)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    public static func initialData(context: AccountContext) -> Signal<MiniAppListScreenInitialData, NoError> {
        let recommendedAppPeers = context.engine.peers.recommendedAppPeerIds()
        |> take(1)
        |> mapToSignal { peerIds -> Signal<[EnginePeer], NoError> in
            guard let peerIds else {
                return .single([])
            }
            return context.engine.data.get(
                EngineDataList(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
            )
            |> map { peers -> [EnginePeer] in
                return peers.compactMap { $0 }
            }
        }
        
        return recommendedAppPeers
        |> map { recommendedAppPeers -> MiniAppListScreenInitialData in
            return InitialData(
                recommendedAppPeers: recommendedAppPeers
            )
        }
    }
}

private final class ListHeaderComponent: Component {
    let theme: PresentationTheme
    let title: String
    
    init(
        theme: PresentationTheme,
        title: String
    ) {
        self.theme = theme
        self.title = title
    }
    
    static func ==(lhs: ListHeaderComponent, rhs: ListHeaderComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let title = ComponentView<Empty>()
        
        private var component: ListHeaderComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ListHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component?.theme !== component.theme {
                self.backgroundColor = component.theme.chatList.sectionHeaderFillColor
            }
            
            let insets = UIEdgeInsets(top: 7.0, left: 16.0, bottom: 7.0, right: 16.0)
            
            let titleString = component.title
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.regular(13.0), textColor: component.theme.chatList.sectionHeaderTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - insets.left - insets.right, height: 100.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: titleSize)
            }
            
            return CGSize(width: availableSize.width, height: titleSize.height + insets.top + insets.bottom)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
