import Foundation
import UIKit
import Photos
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
import ItemListPeerActionItem
import ItemListUI
import ChatListUI
import QuickReplyNameAlertController
import ChatListHeaderComponent

final class QuickReplySetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: QuickReplySetupScreen.InitialData

    init(
        context: AccountContext,
        initialData: QuickReplySetupScreen.InitialData
    ) {
        self.context = context
        self.initialData = initialData
    }

    static func ==(lhs: QuickReplySetupScreenComponent, rhs: QuickReplySetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }

        return true
    }
    
    private enum ContentEntry: Comparable, Identifiable {
        enum Id: Hashable {
            case add
            case item(String)
        }
        
        var stableId: Id {
            switch self {
            case .add:
                return .add
            case let .item(item, _, _, _):
                return .item(item.shortcut)
            }
        }
        
        case add
        case item(item: QuickReplyMessageShortcut, accountPeer: EnginePeer, sortIndex: Int, isEditing: Bool)
        
        static func <(lhs: ContentEntry, rhs: ContentEntry) -> Bool {
            switch lhs {
            case .add:
                return false
            case let .item(lhsItem, _, lhsSortIndex, _):
                switch rhs {
                case .add:
                    return false
                case let .item(rhsItem, _, rhsSortIndex, _):
                    if lhsSortIndex != rhsSortIndex {
                        return lhsSortIndex < rhsSortIndex
                    }
                    return lhsItem.shortcut < rhsItem.shortcut
                }
            }
        }
        
        func item(listNode: ContentListNode) -> ListViewItem {
            switch self {
            case .add:
                //TODO:localize
                return ItemListPeerActionItem(
                    presentationData: ItemListPresentationData(listNode.presentationData),
                    icon: PresentationResourcesItemList.plusIconImage(listNode.presentationData.theme),
                    iconSignal: nil,
                    title: "New Quick Reply",
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
                        parentView.openQuickReplyChat(shortcut: nil)
                    }
                )
            case let .item(item, accountPeer, _, isEditing):
                let chatListNodeInteraction = ChatListNodeInteraction(
                    context: listNode.context,
                    animationCache: listNode.context.animationCache,
                    animationRenderer: listNode.context.animationRenderer,
                    activateSearch: {
                    },
                    peerSelected: { [weak listNode] _, _, _, _ in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        parentView.openQuickReplyChat(shortcut: item.shortcut)
                    },
                    disabledPeerSelected: { _, _, _ in
                    },
                    togglePeerSelected: { _, _ in
                    },
                    togglePeersSelection: { _, _ in
                    },
                    additionalCategorySelected: { _ in
                    },
                    messageSelected: { [weak listNode] _, _, _, _ in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        parentView.openQuickReplyChat(shortcut: item.shortcut)
                    },
                    groupSelected: { _ in
                    },
                    addContact: { _ in
                    },
                    setPeerIdWithRevealedOptions: { _, _ in
                    },
                    setItemPinned: { _, _ in
                    },
                    setPeerMuted: { _, _ in
                    },
                    setPeerThreadMuted: { _, _, _ in
                    },
                    deletePeer: { _, _ in
                    },
                    deletePeerThread: { _, _ in
                    },
                    setPeerThreadStopped: { _, _, _ in
                    },
                    setPeerThreadPinned: { _, _, _ in
                    },
                    setPeerThreadHidden: { _, _, _ in
                    },
                    updatePeerGrouping: { _, _ in
                    },
                    togglePeerMarkedUnread: { _, _ in
                    },
                    toggleArchivedFolderHiddenByDefault: {
                    },
                    toggleThreadsSelection: { _, _ in
                    },
                    hidePsa: { _ in
                    },
                    activateChatPreview: { _, _, _, _, _ in
                    },
                    present: { _ in
                    },
                    openForumThread: { _, _ in
                    },
                    openStorageManagement: {
                    },
                    openPasswordSetup: {
                    },
                    openPremiumIntro: {
                    },
                    openPremiumGift: {
                    },
                    openActiveSessions: {
                    },
                    performActiveSessionAction: { _, _ in
                    },
                    openChatFolderUpdates: {
                    },
                    hideChatFolderUpdates: {
                    },
                    openStories: { _, _ in
                    },
                    dismissNotice: { _ in
                    }
                )
                
                let presentationData = listNode.context.sharedContext.currentPresentationData.with({ $0 })
                let chatListPresentationData = ChatListPresentationData(
                    theme: presentationData.theme,
                    fontSize: presentationData.listsFontSize,
                    strings: presentationData.strings,
                    dateTimeFormat: presentationData.dateTimeFormat,
                    nameSortOrder: presentationData.nameSortOrder,
                    nameDisplayOrder: presentationData.nameDisplayOrder,
                    disableAnimations: false
                )
                
                return ChatListItem(
                    presentationData: chatListPresentationData,
                    context: listNode.context,
                    chatListLocation: .chatList(groupId: .root),
                    filterData: nil,
                    index: EngineChatList.Item.Index.chatList(ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: listNode.context.account.peerId, namespace: 0, id: 0), timestamp: 0))),
                    content: .peer(ChatListItemContent.PeerData(
                        messages: item.messages.first.flatMap({ [$0] }) ?? [],
                        peer: EngineRenderedPeer(peer: accountPeer),
                        threadInfo: nil,
                        combinedReadState: nil,
                        isRemovedFromTotalUnreadCount: false,
                        presence: nil,
                        hasUnseenMentions: false,
                        hasUnseenReactions: false,
                        draftState: nil,
                        mediaDraftContentType: nil,
                        inputActivities: nil,
                        promoInfo: nil,
                        ignoreUnreadBadge: false,
                        displayAsMessage: false,
                        hasFailedMessages: false,
                        forumTopicData: nil,
                        topForumTopicItems: [],
                        autoremoveTimeout: nil,
                        storyState: nil,
                        requiresPremiumForMessaging: false,
                        displayAsTopicList: false,
                        tags: [],
                        customMessageListData: ChatListItemContent.CustomMessageListData(
                            commandPrefix: "/\(item.shortcut)",
                            searchQuery: nil,
                            messageCount: nil
                        )
                    )),
                    editing: isEditing,
                    hasActiveRevealControls: false,
                    selected: false,
                    header: nil,
                    enableContextActions: false,
                    hiddenOffset: false,
                    interaction: chatListNodeInteraction
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
        
        func update(size: CGSize, insets: UIEdgeInsets, transition: Transition) {
            let (listViewDuration, listViewCurve) = listViewAnimationDurationAndCurve(transition: transition.containedViewLayoutTransition)
            self.transaction(
                deleteIndices: [],
                insertIndicesAndItems: [],
                updateIndicesAndItems: [],
                options: [.Synchronous, .LowLatency],
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
        
        private let navigationBarView = ComponentView<Empty>()
        private var navigationHeight: CGFloat?
        
        private var isUpdating: Bool = false
        
        private var component: QuickReplySetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var items: [QuickReplyMessageShortcut] = []
        private var messagesDisposable: Disposable?
        
        private var isEditing: Bool = false
        private var isSearchDisplayControllerActive: Bool = false

        private var accountPeer: EnginePeer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.messagesDisposable?.dispose()
        }

        func scrollToTop() {
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            guard let component = self.component else {
                return true
            }
            component.context.engine.accountData.updateShortcutMessages(state: QuickReplyMessageShortcutsState(shortcuts: self.items))
            return true
        }
        
        func openQuickReplyChat(shortcut: String?) {
            guard let component = self.component else {
                return
            }
            
            if let shortcut {
                var mappedMessages: [EngineMessage] = []
                if let messages = self.items.first(where: { $0.shortcut == shortcut })?.messages {
                    var nextId: Int32 = 1
                    for message in messages {
                        var mappedMessage = message._asMessage()
                        mappedMessage = mappedMessage.withUpdatedId(id: MessageId(peerId: component.context.account.peerId, namespace: 0, id: nextId))
                        mappedMessage = mappedMessage.withUpdatedStableId(stableId: UInt32(nextId))
                        mappedMessage = mappedMessage.withUpdatedTimestamp(nextId)
                        mappedMessages.append(EngineMessage(mappedMessage))
                        
                        nextId += 1
                    }
                }
                let contents = AutomaticBusinessMessageSetupChatContents(
                    context: component.context,
                    messages: mappedMessages,
                    kind: .quickReplyMessageInput(shortcut: shortcut)
                )
                let chatController = component.context.sharedContext.makeChatController(
                    context: component.context,
                    chatLocation: .customChatContents,
                    subject: .customChatContents(contents: contents),
                    botStart: nil,
                    mode: .standard(.default)
                )
                chatController.navigationPresentation = .modal
                self.environment?.controller()?.push(chatController)
                self.messagesDisposable?.dispose()
                self.messagesDisposable = (contents.messages
                |> deliverOnMainQueue).startStrict(next: { [weak self] messages in
                    guard let self else {
                        return
                    }
                    let messages = messages.reversed().map(EngineMessage.init)
                    
                    if messages.isEmpty {
                        if let index = self.items.firstIndex(where: { $0.shortcut == shortcut }) {
                            self.items.remove(at: index)
                        }
                    } else {
                        if let index = self.items.firstIndex(where: { $0.shortcut == shortcut }) {
                            self.items[index] = QuickReplyMessageShortcut(id: self.items[index].id, shortcut: self.items[index].shortcut, messages: messages)
                        } else {
                            self.items.insert(QuickReplyMessageShortcut(id: Int32.random(in: Int32.min ... Int32.max), shortcut: shortcut, messages: messages), at: 0)
                        }
                    }
                    
                    self.state?.updated(transition: .immediate)
                })
            } else {
                var completion: ((String?) -> Void)?
                let alertController = quickReplyNameAlertController(
                    context: component.context,
                    text: "New Quick Reply",
                    subtext: "Add a shortcut for your quick reply.",
                    value: "",
                    characterLimit: 32,
                    apply: { value in
                        completion?(value)
                    }
                )
                completion = { [weak self, weak alertController] value in
                    guard let self else {
                        alertController?.dismissAnimated()
                        return
                    }
                    if let value, !value.isEmpty {
                        alertController?.dismissAnimated()
                        self.openQuickReplyChat(shortcut: value)
                    }
                }
                self.environment?.controller()?.present(alertController, in: .window(.root))
            }
            
            self.contentListNode?.clearHighlightAnimated(true)
        }
        
        private func updateNavigationBar(
            component: QuickReplySetupScreenComponent,
            theme: PresentationTheme,
            strings: PresentationStrings,
            size: CGSize,
            insets: UIEdgeInsets,
            statusBarHeight: CGFloat,
            transition: Transition,
            deferScrollApplication: Bool
        ) -> CGFloat {
            var rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = []
            if self.isEditing {
                rightButtons.append(AnyComponentWithIdentity(id: "done", component: AnyComponent(NavigationButtonComponent(
                    content: .text(title: strings.Common_Done, isBold: true),
                    pressed: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.isEditing = false
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                ))))
            } else {
                rightButtons.append(AnyComponentWithIdentity(id: "edit", component: AnyComponent(NavigationButtonComponent(
                    content: .text(title: strings.Common_Edit, isBold: false),
                    pressed: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.isEditing = true
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                ))))
            }
            let headerContent: ChatListHeaderComponent.Content? = ChatListHeaderComponent.Content(
                title: "Quick Replies",
                navigationBackTitle: nil,
                titleComponent: nil,
                chatListTitle: nil,
                leftButton: nil,
                rightButtons: rightButtons,
                backTitle: "Back",
                backPressed: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.environment?.controller()?.dismiss()
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
                    isSearchEnabled: !self.isEditing,
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
                    activateSearch: { [weak self] searchContentNode in
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
        
        private func updateNavigationScrolling(navigationHeight: CGFloat, transition: Transition) {
            var mainOffset: CGFloat
            if self.items.isEmpty {
                mainOffset = navigationHeight
            } else {
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
        }
        
        func update(component: QuickReplySetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.accountPeer = component.initialData.accountPeer
                self.items = component.initialData.shortcutMessages.shortcuts
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let alphaTransition: Transition = transition.animation.isImmediate ? transition : transition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
            let _ = alphaTransition
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.plainBackgroundColor
            }
            
            if self.items.isEmpty {
                let emptyState: ComponentView<Empty>
                var emptyStateTransition = transition
                if let current = self.emptyState {
                    emptyState = current
                } else {
                    emptyState = ComponentView()
                    self.emptyState = emptyState
                    emptyStateTransition = emptyStateTransition.withAnimation(.none)
                }
                
                let emptyStateFrame = CGRect(origin: CGPoint(x: 0.0, y: environment.navigationHeight), size: CGSize(width: availableSize.width, height: availableSize.height - environment.navigationHeight))
                let _ = emptyState.update(
                    transition: emptyStateTransition,
                    component: AnyComponent(QuickReplyEmptyStateComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        insets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: environment.safeInsets.bottom, right: environment.safeInsets.right),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.openQuickReplyChat(shortcut: nil)
                        }
                    )),
                    environment: {},
                    containerSize: emptyStateFrame.size
                )
                if let emptyStateView = emptyState.view {
                    if emptyStateView.superview == nil {
                        self.addSubview(emptyStateView)
                    }
                    emptyStateTransition.setFrame(view: emptyStateView, frame: emptyStateFrame)
                }
            } else {
                if let emptyState = self.emptyState {
                    self.emptyState = nil
                    emptyState.view?.removeFromSuperview()
                }
            }
            
            let navigationHeight = self.updateNavigationBar(
                component: component,
                theme: environment.theme,
                strings: environment.strings,
                size: availableSize,
                insets: environment.safeInsets,
                statusBarHeight: environment.statusBarHeight,
                transition: transition,
                deferScrollApplication: true
            )
            self.navigationHeight = navigationHeight
            
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
            contentListNode.update(size: availableSize, insets: UIEdgeInsets(top: navigationHeight, left: environment.safeInsets.left, bottom: environment.safeInsets.bottom, right: environment.safeInsets.right), transition: transition)
            
            var entries: [ContentEntry] = []
            if let accountPeer = self.accountPeer {
                entries.append(.add)
                for item in self.items {
                    entries.append(.item(item: item, accountPeer: accountPeer, sortIndex: entries.count, isEditing: self.isEditing))
                }
            }
            contentListNode.setEntries(entries: entries, animated: !transition.animation.isImmediate)
            
            contentListNode.isHidden = self.items.isEmpty
            
            self.updateNavigationScrolling(navigationHeight: navigationHeight, transition: transition)
            
            if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                navigationBarComponentView.deferScrollApplication = false
                navigationBarComponentView.applyCurrentScroll(transition: transition)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class QuickReplySetupScreen: ViewControllerComponentContainer {
    public final class InitialData: QuickReplySetupScreenInitialData {
        let accountPeer: EnginePeer?
        let shortcutMessages: QuickReplyMessageShortcutsState
        
        init(
            accountPeer: EnginePeer?,
            shortcutMessages: QuickReplyMessageShortcutsState
        ) {
            self.accountPeer = accountPeer
            self.shortcutMessages = shortcutMessages
        }
    }
    
    private let context: AccountContext
    
    public init(context: AccountContext, initialData: InitialData) {
        self.context = context
        
        super.init(context: context, component: QuickReplySetupScreenComponent(
            context: context,
            initialData: initialData
        ), navigationBarAppearance: .none, theme: .default, updatedPresentationData: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? QuickReplySetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? QuickReplySetupScreenComponent.View else {
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
    
    public static func initialData(context: AccountContext) -> Signal<QuickReplySetupScreenInitialData, NoError> {
        return combineLatest(
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
            ),
            context.engine.accountData.shortcutMessages()
            |> take(1)
        )
        |> map { accountPeer, shortcutMessages -> QuickReplySetupScreenInitialData in
            return InitialData(
                accountPeer: accountPeer,
                shortcutMessages: shortcutMessages
            )
        }
    }
}
