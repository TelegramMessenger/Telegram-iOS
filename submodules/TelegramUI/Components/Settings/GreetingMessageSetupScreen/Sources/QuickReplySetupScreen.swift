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

final class QuickReplySetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext

    init(
        context: AccountContext
    ) {
        self.context = context
    }

    static func ==(lhs: QuickReplySetupScreenComponent, rhs: QuickReplySetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }

        return true
    }
    
    private struct ShortcutItem: Equatable {
        var shortcut: String
        var messages: [EngineMessage]
        
        init(shortcut: String, messages: [EngineMessage]) {
            self.shortcut = shortcut
            self.messages = messages
        }
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
            case let .item(item, _, _):
                return .item(item.shortcut)
            }
        }
        
        case add
        case item(item: ShortcutItem, accountPeer: EnginePeer, sortIndex: Int)
        
        static func <(lhs: ContentEntry, rhs: ContentEntry) -> Bool {
            switch lhs {
            case .add:
                return false
            case let .item(lhsItem, _, lhsSortIndex):
                switch rhs {
                case .add:
                    return false
                case let .item(rhsItem, _, rhsSortIndex):
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
            case let .item(item, accountPeer, _):
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
                            messageCount: nil
                        )
                    )),
                    editing: false,
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
            
            self.transaction(
                deleteIndices: deletions,
                insertIndicesAndItems: insertions,
                updateIndicesAndItems: updates,
                options: [.Synchronous, .LowLatency],
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
        
        private var isUpdating: Bool = false
        
        private var component: QuickReplySetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var items: [ShortcutItem] = []
        private var messagesDisposable: Disposable?

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
            return true
        }
        
        func openQuickReplyChat(shortcut: String?) {
            guard let component = self.component else {
                return
            }
            
            if let shortcut {
                let contents = GreetingMessageSetupChatContents(
                    context: component.context,
                    messages: self.items.first(where: { $0.shortcut == shortcut })?.messages ?? [],
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
                    let messages = messages.map(EngineMessage.init)
                    
                    if messages.isEmpty {
                        if let index = self.items.firstIndex(where: { $0.shortcut == shortcut }) {
                            self.items.remove(at: index)
                        }
                    } else {
                        if let index = self.items.firstIndex(where: { $0.shortcut == shortcut }) {
                            self.items[index].messages = messages
                        } else {
                            self.items.insert(ShortcutItem(
                                shortcut: shortcut,
                                messages: messages
                            ), at: 0)
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
        
        func update(component: QuickReplySetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                let _ = (component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self else {
                        return
                    }
                    self.accountPeer = peer
                })
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
            
            let contentListNode: ContentListNode
            if let current = self.contentListNode {
                contentListNode = current
            } else {
                contentListNode = ContentListNode(parentView: self, context: component.context)
                self.contentListNode = contentListNode
                self.addSubview(contentListNode.view)
            }
            
            transition.setFrame(view: contentListNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
            contentListNode.update(size: availableSize, insets: UIEdgeInsets(top: environment.navigationHeight, left: environment.safeInsets.left, bottom: environment.safeInsets.bottom, right: environment.safeInsets.right), transition: transition)
            
            var entries: [ContentEntry] = []
            if let accountPeer = self.accountPeer {
                entries.append(.add)
                for item in self.items {
                    entries.append(.item(item: item, accountPeer: accountPeer, sortIndex: entries.count))
                }
            }
            contentListNode.setEntries(entries: entries, animated: false)
            
            contentListNode.isHidden = self.items.isEmpty
            
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
    private let context: AccountContext
    
    public init(context: AccountContext) {
        self.context = context
        
        super.init(context: context, component: QuickReplySetupScreenComponent(
            context: context
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        //TODO:localize
        self.title = "Quick Replies"
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
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
}
