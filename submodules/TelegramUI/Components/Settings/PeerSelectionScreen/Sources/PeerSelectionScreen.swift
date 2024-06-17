import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import ItemListUI
import PresentationDataUtils
import AccountContext
import ChatListHeaderComponent
import SearchBarNode
import ContactsPeerItem
import ViewControllerComponent
import ComponentFlow
import BalancedTextComponent
import MultilineTextComponent
import ItemListPeerActionItem
import ComponentDisplayAdapters

final class PeerSelectionScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: PeerSelectionScreen.InitialData
    let completion: (PeerSelectionScreen.ChannelInfo?) -> Void
    
    init(
        context: AccountContext,
        initialData: PeerSelectionScreen.InitialData,
        completion: @escaping (PeerSelectionScreen.ChannelInfo?) -> Void
    ) {
        self.context = context
        self.initialData = initialData
        self.completion = completion
    }

    static func ==(lhs: PeerSelectionScreenComponent, rhs: PeerSelectionScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }

        return true
    }
    
    private enum ContentEntry: Comparable, Identifiable {
        enum Id: Hashable {
            case hide
            case item(EnginePeer.Id)
        }
        
        var stableId: Id {
            switch self {
            case .hide:
                return .hide
            case let .item(peer, _, _):
                return .item(peer.id)
            }
        }
        
        case hide
        case item(peer: EnginePeer, subscriberCount: Int?, sortIndex: Int)
        
        static func <(lhs: ContentEntry, rhs: ContentEntry) -> Bool {
            switch lhs {
            case .hide:
                return false
            case let .item(lhsPeer, _, lhsSortIndex):
                switch rhs {
                case .hide:
                    return false
                case let .item(rhsPeer, _, rhsSortIndex):
                    if lhsSortIndex != rhsSortIndex {
                        return lhsSortIndex < rhsSortIndex
                    }
                    return lhsPeer.id < rhsPeer.id
                }
            }
        }
        
        func item(listNode: ContentListNode) -> ListViewItem {
            switch self {
            case .hide:
                return ItemListPeerActionItem(
                    presentationData: ItemListPresentationData(listNode.presentationData),
                    icon: PresentationResourcesItemList.hideIconImage(listNode.presentationData.theme),
                    iconSignal: nil,
                    title: listNode.presentationData.strings.Settings_PersonalChannelRemove,
                    additionalBadgeIcon: nil,
                    alwaysPlain: true,
                    hasSeparator: true,
                    sectionId: 0,
                    height: .generic,
                    color: .accent,
                    editing: false,
                    action: { [weak listNode] in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        parentView.peerSelected(peer: nil)
                    }
                )
            case let .item(peer, subscriberCount, _):
                let statusText: String
                if let subscriberCount, subscriberCount != 0 {
                    statusText = listNode.presentationData.strings.Conversation_StatusSubscribers(Int32(subscriberCount))
                } else {
                    statusText = listNode.presentationData.strings.Channel_Status
                }
                
                return ContactsPeerItem(
                    presentationData: ItemListPresentationData(listNode.presentationData),
                    style: .plain,
                    sectionId: 0,
                    sortOrder: listNode.presentationData.nameSortOrder,
                    displayOrder: listNode.presentationData.nameDisplayOrder,
                    context: listNode.context,
                    peerMode: .peer,
                    peer: .peer(peer: peer, chatPeer: peer),
                    status: .custom(string: statusText, multiline: false, isActive: false, icon: nil),
                    badge: nil,
                    requiresPremiumForMessaging: false,
                    enabled: true,
                    selection: .none,
                    selectionPosition: .left,
                    editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                    options: [],
                    additionalActions: [],
                    actionIcon: .none,
                    index: nil,
                    header: nil,
                    action: { [weak listNode] _ in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        parentView.peerSelected(peer: peer)
                    }
                )
            }
        }
    }
    
    private final class ContentListNode: ListView {
        weak var parentView: View?
        let context: AccountContext
        var presentationData: PresentationData
        private var currentEntries: [ContentEntry] = []
        
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
        private var emptyState: ComponentView<Empty>?
        private var contentListNode: ContentListNode?
        private var emptySearchState: ComponentView<Empty>?
        private var loadingView: PeerSelectionLoadingView?
        
        private let navigationBarView = ComponentView<Empty>()
        private var navigationHeight: CGFloat?
        
        private var searchBarNode: SearchBarNode?
        
        private var isUpdating: Bool = false
        
        private var component: PeerSelectionScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var channels: [PeerSelectionScreen.ChannelInfo]?
        private var channelsDisposable: Disposable?
        
        private var isSearchDisplayControllerActive: Bool = false
        private var searchQuery: String = ""
        private let searchQueryComponentSeparationCharacterSet: CharacterSet
        
        override init(frame: CGRect) {
            self.searchQueryComponentSeparationCharacterSet = CharacterSet(charactersIn: " _.:/")
            
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.channelsDisposable?.dispose()
        }

        func scrollToTop() {
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            return true
        }
        
        func peerSelected(peer: EnginePeer?) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            if let peer {
                guard let channel = self.channels?.first(where: { $0.peer.id == peer.id }) else {
                    return
                }
                component.completion(channel)
            } else {
                component.completion(nil)
            }
            environment.controller()?.dismiss()
        }
        
        private func updateNavigationBar(
            component: PeerSelectionScreenComponent,
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
            
            let closeTitle: String = strings.Common_Cancel
            
            let headerContent: ChatListHeaderComponent.Content? = ChatListHeaderComponent.Content(
                title: "",
                navigationBackTitle: nil,
                titleComponent: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: strings.Settings_PersonalChannelSelectTitle, font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor))
                    ))),
                    AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: strings.Settings_PersonalChannelSelectSubtitle, font: Font.regular(12.0), textColor: theme.rootController.navigationBar.secondaryTextColor))
                    )))
                ], spacing: 2.0)),
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
            
            mainOffset = min(mainOffset, ChatListNavigationBar.searchScrollHeight)
            if abs(mainOffset) < 0.1 {
                mainOffset = 0.0
            }
            
            let resultingOffset = mainOffset
            
            var offset = resultingOffset
            if self.isSearchDisplayControllerActive {
                offset = 0.0
            }
            
            if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                navigationBarComponentView.applyScroll(offset: offset, allowAvatarsExpansion: false, forceUpdate: false, transition: transition.withUserData(ChatListNavigationBar.AnimationHint(
                    disableStoriesAnimations: false,
                    crossfadeStoryPeers: false
                )))
            }
            
            if let contentListNode = self.contentListNode, let loadingView = self.loadingView {
                transition.setFrame(view: loadingView, frame: contentListNode.frame.offsetBy(dx: 0.0, dy: -offset + contentListNode.insets.top))
            }
        }
        
        func update(component: PeerSelectionScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                if let channels = component.initialData.channels, !channels.isEmpty {
                    self.channels = channels.map { peer in
                        return PeerSelectionScreen.ChannelInfo(peer: peer.peer, subscriberCount: peer.subscriberCount)
                    }
                } else {
                    self.channelsDisposable = (component.context.engine.peers.adminedPublicChannels(scope: .forPersonalProfile)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
                        guard let self else {
                            return
                        }
                        self.channels = peers.map { peer in
                            return PeerSelectionScreen.ChannelInfo(peer: peer.peer, subscriberCount: peer.subscriberCount)
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    })
                }
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? transition : transition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
            let _ = alphaTransition
            
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
            
            var listBottomInset = environment.safeInsets.bottom + environment.additionalInsets.bottom
            listBottomInset = max(listBottomInset, environment.inputHeight)
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
                    
                    self.updateNavigationScrolling(navigationHeight: navigationHeight, transition: .immediate)
                }
                
                if let navigationBarComponentView = self.navigationBarView.view {
                    self.insertSubview(contentListNode.view, belowSubview: navigationBarComponentView)
                } else {
                    self.addSubview(contentListNode.view)
                }
            }
            
            transition.setFrame(view: contentListNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
            contentListNode.update(size: availableSize, insets: UIEdgeInsets(top: navigationHeight, left: environment.safeInsets.left, bottom: listBottomInset, right: environment.safeInsets.right), transition: transition)
            
            var entries: [ContentEntry] = []
            if component.initialData.channelId != nil && self.searchQuery.isEmpty {
                entries.append(.hide)
            }
            if let channels = self.channels {
                for channel in channels {
                    if !self.searchQuery.isEmpty {
                        var matches = false
                    inner: for nameComponent in channel.peer.compactDisplayTitle.lowercased().components(separatedBy: self.searchQueryComponentSeparationCharacterSet) {
                        if nameComponent.lowercased().hasPrefix(self.searchQuery) {
                            matches = true
                            break inner
                        }
                    }
                        if !matches {
                            continue
                        }
                    }
                    entries.append(.item(peer: channel.peer, subscriberCount: channel.subscriberCount, sortIndex: entries.count))
                }
            }
            contentListNode.setEntries(entries: entries, animated: !transition.animation.isImmediate)
            
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
            
            if self.channels == nil, let contentListNode = self.contentListNode {
                let loadingView: PeerSelectionLoadingView
                if let current = self.loadingView {
                    loadingView = current
                } else {
                    loadingView = PeerSelectionLoadingView()
                    self.loadingView = loadingView
                    contentListNode.view.superview?.insertSubview(loadingView, aboveSubview: contentListNode.view)
                }
                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                loadingView.update(
                    context: component.context,
                    size: CGSize(width: contentListNode.bounds.size.width, height: floor(contentListNode.bounds.size.height * 1.2)),
                    presentationData: presentationData,
                    transition: transition.containedViewLayoutTransition
                )
            } else {
                if let loadingView = self.loadingView {
                    self.loadingView = nil
                    let removeTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    removeTransition.setAlpha(view: loadingView, alpha: 0.0, completion: { [weak loadingView] _ in
                        loadingView?.removeFromSuperview()
                    })
                }
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

public final class PeerSelectionScreen: ViewControllerComponentContainer {
    public final class InitialData {
        public let channelId: EnginePeer.Id?
        public let channels: [TelegramAdminedPublicChannel]?
        
        init(channelId: EnginePeer.Id?, channels: [TelegramAdminedPublicChannel]?) {
            self.channelId = channelId
            self.channels = channels
        }
    }
    
    public struct ChannelInfo: Equatable {
        public var peer: EnginePeer
        public var subscriberCount: Int?
        
        public init(peer: EnginePeer, subscriberCount: Int?) {
            self.peer = peer
            self.subscriberCount = subscriberCount
        }
    }
    
    private let context: AccountContext
    
    public init(context: AccountContext, initialData: InitialData, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, completion: @escaping (ChannelInfo?) -> Void) {
        self.context = context
        
        super.init(context: context, component: PeerSelectionScreenComponent(
            context: context,
            initialData: initialData,
            completion: completion
        ), navigationBarAppearance: .none, theme: .default, updatedPresentationData: updatedPresentationData)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? PeerSelectionScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? PeerSelectionScreenComponent.View else {
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
    
    public static func initialData(context: AccountContext, channels: [TelegramAdminedPublicChannel]?) -> Signal<InitialData, NoError> {
        return context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.PersonalChannel(id: context.account.peerId)
        )
        |> map { personalChannel -> InitialData in
            var channelId: EnginePeer.Id?
            if case let .known(value) = personalChannel, let value {
                channelId = value.peerId
            }
            return InitialData(channelId: channelId, channels: channels)
        }
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
}
