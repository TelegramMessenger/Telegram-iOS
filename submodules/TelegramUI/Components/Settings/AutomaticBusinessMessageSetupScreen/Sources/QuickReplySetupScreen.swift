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
import PlainButtonComponent
import MultilineTextComponent
import AttachmentUI
import SearchBarNode
import BalancedTextComponent

final class QuickReplySetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: QuickReplySetupScreen.InitialData
    let mode: QuickReplySetupScreen.Mode
    
    init(
        context: AccountContext,
        initialData: QuickReplySetupScreen.InitialData,
        mode: QuickReplySetupScreen.Mode
    ) {
        self.context = context
        self.initialData = initialData
        self.mode = mode
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
            case item(Int32)
            case pendingItem(String)
        }
        
        var stableId: Id {
            switch self {
            case .add:
                return .add
            case let .item(item, _, _, _, _):
                if let itemId = item.id {
                    return .item(itemId)
                } else {
                    return .pendingItem(item.shortcut)
                }
            }
        }
        
        case add
        case item(item: ShortcutMessageList.Item, accountPeer: EnginePeer, sortIndex: Int, isEditing: Bool, isSelected: Bool)
        
        static func <(lhs: ContentEntry, rhs: ContentEntry) -> Bool {
            switch lhs {
            case .add:
                return false
            case let .item(lhsItem, _, lhsSortIndex, _, _):
                switch rhs {
                case .add:
                    return false
                case let .item(rhsItem, _, rhsSortIndex, _, _):
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
                return ItemListPeerActionItem(
                    presentationData: ItemListPresentationData(listNode.presentationData),
                    icon: PresentationResourcesItemList.plusIconImage(listNode.presentationData.theme),
                    iconSignal: nil,
                    title: listNode.presentationData.strings.QuickReply_InlineCreateAction,
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
                        parentView.openQuickReplyChat(shortcut: nil, shortcutId: nil)
                    }
                )
            case let .item(item, accountPeer, _, isEditing, isSelected):
                let chatListNodeInteraction = ChatListNodeInteraction(
                    context: listNode.context,
                    animationCache: listNode.context.animationCache,
                    animationRenderer: listNode.context.animationRenderer,
                    activateSearch: {
                    },
                    peerSelected: { [weak listNode] _, _, _, _, _ in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        parentView.openQuickReplyChat(shortcut: item.shortcut, shortcutId: item.id)
                    },
                    disabledPeerSelected: { _, _, _ in
                    },
                    togglePeerSelected: { [weak listNode] _, _ in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        if let itemId = item.id {
                            parentView.toggleShortcutSelection(id: itemId)
                        }
                    },
                    togglePeersSelection: { [weak listNode] _, _ in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        if let itemId = item.id {
                            parentView.toggleShortcutSelection(id: itemId)
                        }
                    },
                    additionalCategorySelected: { _ in
                    },
                    messageSelected: { [weak listNode] _, _, _, _ in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        parentView.openQuickReplyChat(shortcut: item.shortcut, shortcutId: item.id)
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
                    deletePeer: { [weak listNode] _, _ in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        if let itemId = item.id {
                            parentView.openDeleteShortcuts(ids: [itemId])
                        }
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
                    openPremiumGift: { _, _ in
                    },
                    openPremiumManagement: {
                    },
                    openActiveSessions: {
                    },
                    openBirthdaySetup: {
                    },
                    performActiveSessionAction: { _, _ in
                    },
                    openChatFolderUpdates: {
                    },
                    hideChatFolderUpdates: {
                    },
                    openStories: { _, _ in
                    },
                    openStarsTopup: { _ in
                    },
                    dismissNotice: { _ in
                    },
                    editPeer: { [weak listNode] _ in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        if let itemId = item.id {
                            parentView.openEditShortcut(id: itemId, currentValue: item.shortcut)
                        }
                    },
                    openWebApp: { _ in
                    },
                    openPhotoSetup: {
                    },
                    openAdInfo: { _, _ in
                    },
                    openAccountFreezeInfo: {
                    },
                    openUrl: { _ in
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
                        messages: [item.topMessage],
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
                            messageCount: item.totalCount,
                            hideSeparator: false,
                            hideDate: true,
                            hidePeerStatus: true
                        )
                    )),
                    editing: isEditing,
                    hasActiveRevealControls: false,
                    selected: isSelected,
                    header: nil,
                    enabledContextActions: .auto,
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
        private var originalEntries: [ContentEntry] = []
        private var tempOrder: [Int32]?
        private var pendingRemoveItems: [Int32]?
        private var resetTempOrderOnNextUpdate: Bool = false
        
        init(parentView: View, context: AccountContext) {
            self.parentView = parentView
            self.context = context
            self.presentationData = context.sharedContext.currentPresentationData.with({ $0 })
            
            super.init()
            
            self.reorderBegan = { [weak self] in
                guard let self else {
                    return
                }
                self.tempOrder = nil
            }
            self.reorderCompleted = { [weak self] _ in
                guard let self, let tempOrder = self.tempOrder else {
                    return
                }
                self.resetTempOrderOnNextUpdate = true
                self.context.engine.accountData.reorderMessageShortcuts(ids: tempOrder, completion: {})
            }
            self.reorderItem = { [weak self] fromIndex, toIndex, transactionOpaqueState -> Signal<Bool, NoError> in
                guard let self else {
                    return .single(false)
                }
                guard fromIndex >= 0 && fromIndex < self.currentEntries.count && toIndex >= 0 && toIndex < self.currentEntries.count else {
                    return .single(false)
                }
                
                let fromEntry = self.currentEntries[fromIndex]
                let toEntry = self.currentEntries[toIndex]
                    
                var referenceId: Int32?
                var beforeAll = false
                switch toEntry {
                case let .item(item, _, _, _, _):
                    referenceId = item.id
                case .add:
                    beforeAll = true
                }
                
                if case let .item(item, _, _, _, _) = fromEntry {
                    var itemIds = self.currentEntries.compactMap { entry -> Int32? in
                        switch entry {
                        case .add:
                            return nil
                        case let .item(item, _, _, _, _):
                            return item.id
                        }
                    }
                    let itemId: Int32? = item.id
                    
                    if let itemId {
                        itemIds = itemIds.filter({ $0 != itemId })
                        if let referenceId {
                            var inserted = false
                            for i in 0 ..< itemIds.count {
                                if itemIds[i] == referenceId {
                                    if fromIndex < toIndex {
                                        itemIds.insert(itemId, at: i + 1)
                                    } else {
                                        itemIds.insert(itemId, at: i)
                                    }
                                    inserted = true
                                    break
                                }
                            }
                            if !inserted {
                                itemIds.append(itemId)
                            }
                        } else if beforeAll {
                            itemIds.insert(itemId, at: 0)
                        } else {
                            itemIds.append(itemId)
                        }
                        if self.tempOrder != itemIds {
                            self.tempOrder = itemIds
                            self.setEntries(entries: self.originalEntries, animated: true)
                        }
                        
                        return .single(true)
                    } else {
                        return .single(false)
                    }
                } else {
                    return .single(false)
                }
            }
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
        
        func setPendingRemoveItems(itemIds: [Int32]) {
            self.pendingRemoveItems = itemIds
            self.setEntries(entries: self.originalEntries, animated: true)
        }
        
        func setEntries(entries: [ContentEntry], animated: Bool) {
            if self.resetTempOrderOnNextUpdate {
                self.resetTempOrderOnNextUpdate = false
                self.tempOrder = nil
            }
            let pendingRemoveItems = self.pendingRemoveItems
            self.pendingRemoveItems = nil
            
            self.originalEntries = entries
            
            var entries = entries
            if let pendingRemoveItems {
                entries = entries.filter { entry in
                    switch entry.stableId {
                    case .add:
                        return true
                    case let .item(id):
                        return !pendingRemoveItems.contains(id)
                    case .pendingItem:
                        return true
                    }
                }
            }
            
            if let tempOrder = self.tempOrder {
                let originalList = entries
                entries.removeAll()
                
                if let entry = originalList.first(where: { entry in
                    if case .add = entry {
                        return true
                    } else {
                        return false
                    }
                }) {
                    entries.append(entry)
                }
                
                for id in tempOrder {
                    if let entry = originalList.first(where: { entry in
                        if case let .item(listId) = entry.stableId, listId == id {
                            return true
                        } else {
                            return false
                        }
                    }) {
                        entries.append(entry)
                    }
                }
                for entry in originalList {
                    if !entries.contains(where: { listEntry in
                        listEntry.stableId == entry.stableId
                    }) {
                        entries.append(entry)
                    }
                }
            }
            
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
        
        private let navigationBarView = ComponentView<Empty>()
        private var navigationHeight: CGFloat?
        
        private var searchBarNode: SearchBarNode?
        
        private var selectionPanel: ComponentView<Empty>?
        
        private var isUpdating: Bool = false
        
        private var component: QuickReplySetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var shortcutMessageList: ShortcutMessageList?
        private var shortcutMessageListDisposable: Disposable?
        private var keepUpdatedDisposable: Disposable?
        
        private var selectedIds = Set<Int32>()
        
        private var isEditing: Bool = false
        private var isSearchDisplayControllerActive: Bool = false
        private var searchQuery: String = ""
        private let searchQueryComponentSeparationCharacterSet: CharacterSet

        private var accountPeer: EnginePeer?
        
        override init(frame: CGRect) {
            self.searchQueryComponentSeparationCharacterSet = CharacterSet(charactersIn: " _.:/")
            
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.shortcutMessageListDisposable?.dispose()
            self.keepUpdatedDisposable?.dispose()
        }

        func scrollToTop() {
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            return true
        }
        
        func openQuickReplyChat(shortcut: String?, shortcutId: Int32?) {
            guard let component = self.component, let environment = self.environment, let controller = self.environment?.controller() as? QuickReplySetupScreen else {
                return
            }
        
            self.contentListNode?.clearHighlightAnimated(true)
            
            if let shortcut {
                if let shortcutId, case let .select(completion) = component.mode {
                    completion(shortcutId)
                    return
                }
                    
                let shortcutType: ChatQuickReplyShortcutType
                if shortcut == "hello" {
                    shortcutType = .greeting
                } else if shortcut == "away" {
                    shortcutType = .away
                } else {
                    shortcutType = .generic
                }
                
                let contents = AutomaticBusinessMessageSetupChatContents(
                    context: component.context,
                    kind: .quickReplyMessageInput(shortcut: shortcut, shortcutType: shortcutType),
                    shortcutId: shortcutId
                )
                let chatController = component.context.sharedContext.makeChatController(
                    context: component.context,
                    chatLocation: .customChatContents,
                    subject: .customChatContents(contents: contents),
                    botStart: nil,
                    mode: .standard(.default),
                    params: nil
                )
                chatController.navigationPresentation = .modal
                
                if controller.navigationController != nil {
                    controller.push(chatController)
                } else if let attachmentContainer = controller.parentController() {
                    attachmentContainer.push(chatController)
                }
            } else {
                var completion: ((String?) -> Void)?
                let alertController = quickReplyNameAlertController(
                    context: component.context,
                    text: environment.strings.QuickReply_CreateShortcutTitle,
                    subtext: environment.strings.QuickReply_CreateShortcutText,
                    value: "",
                    characterLimit: 32,
                    apply: { value in
                        completion?(value)
                    }
                )
                completion = { [weak self, weak alertController] value in
                    guard let self, let environment = self.environment else {
                        alertController?.dismissAnimated()
                        return
                    }
                    if let value, !value.isEmpty {
                        guard let shortcutMessageList = self.shortcutMessageList else {
                            alertController?.dismissAnimated()
                            return
                        }
                        
                        if shortcutMessageList.items.contains(where: { $0.shortcut.lowercased() == value.lowercased() }) {
                            if let contentNode = alertController?.contentNode as? QuickReplyNameAlertContentNode {
                                contentNode.setErrorText(errorText: environment.strings.QuickReply_ShortcutExistsInlineError)
                            }
                            return
                        }
                        
                        alertController?.view.endEditing(true)
                        alertController?.dismissAnimated()
                        self.openQuickReplyChat(shortcut: value, shortcutId: nil)
                    }
                }
                self.environment?.controller()?.present(alertController, in: .window(.root))
            }
        }
        
        func openEditShortcut(id: Int32, currentValue: String) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            var completion: ((String?) -> Void)?
            let alertController = quickReplyNameAlertController(
                context: component.context,
                text: environment.strings.QuickReply_EditShortcutTitle,
                subtext: environment.strings.QuickReply_EditShortcutText,
                value: currentValue,
                characterLimit: 32,
                apply: { value in
                    completion?(value)
                }
            )
            completion = { [weak self, weak alertController] value in
                guard let self, let component = self.component, let environment = self.environment else {
                    alertController?.dismissAnimated()
                    return
                }
                if let value, !value.isEmpty {
                    if value == currentValue {
                        alertController?.dismissAnimated()
                        return
                    }
                    guard let shortcutMessageList = self.shortcutMessageList else {
                        alertController?.dismissAnimated()
                        return
                    }
                    
                    if shortcutMessageList.items.contains(where: { $0.shortcut.lowercased() == value.lowercased() }) {
                        if let contentNode = alertController?.contentNode as? QuickReplyNameAlertContentNode {
                            contentNode.setErrorText(errorText: environment.strings.QuickReply_ShortcutExistsInlineError)
                        }
                    } else {
                        component.context.engine.accountData.editMessageShortcut(id: id, shortcut: value)
                        
                        alertController?.view.endEditing(true)
                        alertController?.dismissAnimated()
                    }
                }
            }
            self.environment?.controller()?.present(alertController, in: .window(.root))
        }
        
        func toggleShortcutSelection(id: Int32) {
            if self.selectedIds.contains(id) {
                self.selectedIds.remove(id)
            } else {
                self.selectedIds.insert(id)
            }
            self.state?.updated(transition: .spring(duration: 0.4))
        }
        
        func openDeleteShortcuts(ids: [Int32]) {
            guard let component = self.component else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = []
            
            items.append(ActionSheetButtonItem(title: ids.count == 1 ? presentationData.strings.QuickReply_DeleteConfirmationSingle : presentationData.strings.QuickReply_DeleteConfirmationMultiple, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                guard let self, let component = self.component else {
                    return
                }
                
                for id in ids {
                    self.selectedIds.remove(id)
                }
                self.contentListNode?.setPendingRemoveItems(itemIds: ids)
                component.context.engine.accountData.deleteMessageShortcuts(ids: ids)
                self.state?.updated(transition: .spring(duration: 0.4))
            }))
                
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            self.environment?.controller()?.present(actionSheet, in: .window(.root))
        }
        
        private func updateNavigationBar(
            component: QuickReplySetupScreenComponent,
            theme: PresentationTheme,
            strings: PresentationStrings,
            size: CGSize,
            insets: UIEdgeInsets,
            statusBarHeight: CGFloat,
            isModal: Bool,
            transition: ComponentTransition,
            deferScrollApplication: Bool
        ) -> CGFloat {
            var rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = []
            if let shortcutMessageList = self.shortcutMessageList, !shortcutMessageList.items.isEmpty {
                if self.isEditing {
                    rightButtons.append(AnyComponentWithIdentity(id: "done", component: AnyComponent(NavigationButtonComponent(
                        content: .text(title: strings.Common_Done, isBold: true),
                        pressed: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.isEditing = false
                            self.selectedIds.removeAll()
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
            }
            
            let titleText: String
            if !self.selectedIds.isEmpty {
                titleText = strings.QuickReply_SelectedTitle(Int32(self.selectedIds.count))
            } else {
                titleText = strings.QuickReply_Title
            }
            
            let closeTitle: String
            switch component.mode {
            case .manage:
                closeTitle = strings.Common_Close
            case .select:
                closeTitle = strings.Common_Cancel
            }
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
            if let shortcutMessageList = self.shortcutMessageList, !shortcutMessageList.items.isEmpty {
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
            
            if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                navigationBarComponentView.applyScroll(offset: offset, allowAvatarsExpansion: false, forceUpdate: false, transition: transition.withUserData(ChatListNavigationBar.AnimationHint(
                    disableStoriesAnimations: false,
                    crossfadeStoryPeers: false
                )))
            }
        }
        
        func update(component: QuickReplySetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.accountPeer = component.initialData.accountPeer
                self.shortcutMessageList = component.initialData.shortcutMessageList
                
                self.shortcutMessageListDisposable = (component.context.engine.accountData.shortcutMessageList(onlyRemote: false)
                |> deliverOnMainQueue).startStrict(next: { [weak self] shortcutMessageList in
                    guard let self else {
                        return
                    }
                    self.shortcutMessageList = shortcutMessageList
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                })
                
                self.keepUpdatedDisposable = component.context.engine.accountData.keepShortcutMessageListUpdated().startStrict()
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
            
            if let shortcutMessageList = self.shortcutMessageList, !shortcutMessageList.items.isEmpty {
                if let emptyState = self.emptyState {
                    self.emptyState = nil
                    emptyState.view?.removeFromSuperview()
                }
            } else {
                let emptyState: ComponentView<Empty>
                var emptyStateTransition = transition
                if let current = self.emptyState {
                    emptyState = current
                } else {
                    emptyState = ComponentView()
                    self.emptyState = emptyState
                    emptyStateTransition = emptyStateTransition.withAnimation(.none)
                }
                
                let emptyStateFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height))
                let _ = emptyState.update(
                    transition: emptyStateTransition,
                    component: AnyComponent(QuickReplyEmptyStateComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        insets: UIEdgeInsets(top: environment.navigationHeight, left: environment.safeInsets.left, bottom: environment.safeInsets.bottom + environment.additionalInsets.bottom, right: environment.safeInsets.right),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.openQuickReplyChat(shortcut: nil, shortcutId: nil)
                        }
                    )),
                    environment: {},
                    containerSize: emptyStateFrame.size
                )
                if let emptyStateView = emptyState.view {
                    if emptyStateView.superview == nil {
                        if let navigationBarComponentView = self.navigationBarView.view {
                            self.insertSubview(emptyStateView, belowSubview: navigationBarComponentView)
                        } else {
                            self.addSubview(emptyStateView)
                        }
                    }
                    emptyStateTransition.setFrame(view: emptyStateView, frame: emptyStateFrame)
                }
            }
            
            var isModal = false
            if let controller = environment.controller(), controller.navigationPresentation == .modal {
                isModal = true
            }
            if case .select = component.mode {
                isModal = true
            }
            
            var statusBarHeight = environment.statusBarHeight
            if isModal {
                statusBarHeight = max(statusBarHeight, 1.0)
            }
            
            var listBottomInset = environment.safeInsets.bottom + environment.additionalInsets.bottom
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
                        
                        if let controller = self.environment?.controller() as? QuickReplySetupScreen {
                            controller.requestAttachmentMenuExpansion()
                        }
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
            
            if !self.selectedIds.isEmpty {
                let selectionPanel: ComponentView<Empty>
                var selectionPanelTransition = transition
                if let current = self.selectionPanel {
                    selectionPanel = current
                } else {
                    selectionPanelTransition = selectionPanelTransition.withAnimation(.none)
                    selectionPanel = ComponentView()
                    self.selectionPanel = selectionPanel
                }
                
                let buttonTitle: String = environment.strings.QuickReply_DeleteAction(Int32(self.selectedIds.count))
                
                let selectionPanelSize = selectionPanel.update(
                    transition: selectionPanelTransition,
                    component: AnyComponent(BottomPanelComponent(
                        theme: environment.theme,
                        content: AnyComponentWithIdentity(id: 0, component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: buttonTitle, font: Font.regular(17.0), textColor: environment.theme.list.itemDestructiveColor))
                            )),
                            background: nil,
                            effectAlignment: .center,
                            minSize: CGSize(width: availableSize.width - environment.safeInsets.left - environment.safeInsets.right, height: 44.0),
                            contentInsets: UIEdgeInsets(),
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                if self.selectedIds.isEmpty {
                                    return
                                }
                                self.openDeleteShortcuts(ids: Array(self.selectedIds))
                            },
                            animateAlpha: true,
                            animateScale: false,
                            animateContents: false
                        ))),
                        insets: UIEdgeInsets(top: 4.0, left: environment.safeInsets.left, bottom: environment.safeInsets.bottom + environment.additionalInsets.bottom, right: environment.safeInsets.right)
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                let selectionPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - selectionPanelSize.height), size: selectionPanelSize)
                listBottomInset = selectionPanelSize.height
                if let selectionPanelView = selectionPanel.view {
                    var animateIn = false
                    if selectionPanelView.superview == nil {
                        animateIn = true
                        self.addSubview(selectionPanelView)
                    }
                    selectionPanelTransition.setFrame(view: selectionPanelView, frame: selectionPanelFrame)
                    if animateIn {
                        transition.animatePosition(view: selectionPanelView, from: CGPoint(x: 0.0, y: selectionPanelFrame.height), to: CGPoint(), additive: true)
                    }
                }
            } else {
                if let selectionPanel = self.selectionPanel {
                    self.selectionPanel = nil
                    if let selectionPanelView = selectionPanel.view {
                        transition.setPosition(view: selectionPanelView, position: CGPoint(x: selectionPanelView.center.x, y: availableSize.height + selectionPanelView.bounds.height * 0.5), completion: { [weak selectionPanelView] _ in
                            selectionPanelView?.removeFromSuperview()
                        })
                    }
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
                
                if let selectionPanelView = self.selectionPanel?.view {
                    self.insertSubview(contentListNode.view, belowSubview: selectionPanelView)
                } else if let navigationBarComponentView = self.navigationBarView.view {
                    self.insertSubview(contentListNode.view, belowSubview: navigationBarComponentView)
                } else {
                    self.addSubview(contentListNode.view)
                }
            }
            
            transition.setFrame(view: contentListNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
            contentListNode.update(size: availableSize, insets: UIEdgeInsets(top: navigationHeight, left: environment.safeInsets.left, bottom: listBottomInset, right: environment.safeInsets.right), transition: transition)
            
            var entries: [ContentEntry] = []
            if let shortcutMessageList = self.shortcutMessageList, let accountPeer = self.accountPeer {
                if self.searchQuery.isEmpty {
                    entries.append(.add)
                }
                for item in shortcutMessageList.items {
                    if !self.searchQuery.isEmpty {
                        var matches = false
                        inner: for nameComponent in item.shortcut.lowercased().components(separatedBy: self.searchQueryComponentSeparationCharacterSet) {
                            if nameComponent.lowercased().hasPrefix(self.searchQuery) {
                                matches = true
                                break inner
                            }
                        }
                        if !matches {
                            continue
                        }
                    }
                    var isItemSelected = false
                    if let itemId = item.id {
                        isItemSelected = self.selectedIds.contains(itemId)
                    }
                    entries.append(.item(item: item, accountPeer: accountPeer, sortIndex: entries.count, isEditing: self.isEditing, isSelected: isItemSelected))
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
            
            if let shortcutMessageList = self.shortcutMessageList, !shortcutMessageList.items.isEmpty {
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

public final class QuickReplySetupScreen: ViewControllerComponentContainer, AttachmentContainable {
    public final class InitialData: QuickReplySetupScreenInitialData {
        let accountPeer: EnginePeer?
        let shortcutMessageList: ShortcutMessageList
        
        init(
            accountPeer: EnginePeer?,
            shortcutMessageList: ShortcutMessageList
        ) {
            self.accountPeer = accountPeer
            self.shortcutMessageList = shortcutMessageList
        }
    }
    
    public enum Mode {
        case manage
        case select(completion: (Int32) -> Void)
    }
    
    private let context: AccountContext
    
    public var requestAttachmentMenuExpansion: () -> Void = {
    }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in
    }
    public var parentController: () -> ViewController? = {
        return nil
    }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in
    }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in
    }
    public var cancelPanGesture: () -> Void = {
    }
    public var isContainerPanning: () -> Bool = {
        return false
    }
    public var isContainerExpanded: () -> Bool = {
        return false
    }
    public var isMinimized: Bool = false
    public var mediaPickerContext: AttachmentMediaPickerContext?
    
    public init(context: AccountContext, initialData: InitialData, mode: Mode) {
        self.context = context
        
        super.init(context: context, component: QuickReplySetupScreenComponent(
            context: context,
            initialData: initialData,
            mode: mode
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
            context.engine.accountData.shortcutMessageList(onlyRemote: false)
            |> take(1)
        )
        |> map { accountPeer, shortcutMessageList -> QuickReplySetupScreenInitialData in
            return InitialData(
                accountPeer: accountPeer,
                shortcutMessageList: shortcutMessageList
            )
        }
    }
    
    public func isContainerPanningUpdated(_ panning: Bool) {
    }
    
    public func resetForReuse() {
    }
    
    public func prepareForReuse() {
    }
    
    public func requestDismiss(completion: @escaping () -> Void) {
        completion()
    }
    
    public func shouldDismissImmediately() -> Bool {
        return true
    }
}
