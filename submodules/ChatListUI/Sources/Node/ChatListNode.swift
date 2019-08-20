import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import TelegramNotices
import ContactsPeerItem

public enum ChatListNodeMode {
    case chatList
    case peers(filter: ChatListNodePeersFilter)
}

struct ChatListNodeListViewTransition {
    let chatListView: ChatListNodeView
    let deleteItems: [ListViewDeleteItem]
    let insertItems: [ListViewInsertItem]
    let updateItems: [ListViewUpdateItem]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
}

final class ChatListHighlightedLocation {
    let location: ChatLocation
    let progress: CGFloat
    
    init(location: ChatLocation, progress: CGFloat) {
        self.location = location
        self.progress = progress
    }
    
    func withUpdatedProgress(_ progress: CGFloat) -> ChatListHighlightedLocation {
        return ChatListHighlightedLocation(location: location, progress: progress)
    }
}

public final class ChatListNodeInteraction {
    let activateSearch: () -> Void
    let peerSelected: (Peer) -> Void
    let togglePeerSelected: (PeerId) -> Void
    let messageSelected: (Peer, Message, Bool) -> Void
    let groupSelected: (PeerGroupId) -> Void
    let addContact: (String) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let setItemPinned: (PinnedItemId, Bool) -> Void
    let setPeerMuted: (PeerId, Bool) -> Void
    let deletePeer: (PeerId) -> Void
    let updatePeerGrouping: (PeerId, Bool) -> Void
    let togglePeerMarkedUnread: (PeerId, Bool) -> Void
    let toggleArchivedFolderHiddenByDefault: () -> Void
    
    var highlightedChatLocation: ChatListHighlightedLocation?
    
    public init(activateSearch: @escaping () -> Void, peerSelected: @escaping (Peer) -> Void, togglePeerSelected: @escaping (PeerId) -> Void, messageSelected: @escaping (Peer, Message, Bool) -> Void, groupSelected: @escaping (PeerGroupId) -> Void, addContact: @escaping (String) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, setItemPinned: @escaping (PinnedItemId, Bool) -> Void, setPeerMuted: @escaping (PeerId, Bool) -> Void, deletePeer: @escaping (PeerId) -> Void, updatePeerGrouping: @escaping (PeerId, Bool) -> Void, togglePeerMarkedUnread: @escaping (PeerId, Bool) -> Void, toggleArchivedFolderHiddenByDefault: @escaping () -> Void) {
        self.activateSearch = activateSearch
        self.peerSelected = peerSelected
        self.togglePeerSelected = togglePeerSelected
        self.messageSelected = messageSelected
        self.groupSelected = groupSelected
        self.addContact = addContact
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.setItemPinned = setItemPinned
        self.setPeerMuted = setPeerMuted
        self.deletePeer = deletePeer
        self.updatePeerGrouping = updatePeerGrouping
        self.togglePeerMarkedUnread = togglePeerMarkedUnread
        self.toggleArchivedFolderHiddenByDefault = toggleArchivedFolderHiddenByDefault
    }
}

public final class ChatListNodePeerInputActivities {
    public let activities: [PeerId: [(Peer, PeerInputActivity)]]
    
    public init(activities: [PeerId: [(Peer, PeerInputActivity)]]) {
        self.activities = activities
    }
}

public struct ChatListNodeState: Equatable {
    public var presentationData: ChatListPresentationData
    public var editing: Bool
    public var peerIdWithRevealedOptions: PeerId?
    public var selectedPeerIds: Set<PeerId>
    public var peerInputActivities: ChatListNodePeerInputActivities?
    public var pendingRemovalPeerIds: Set<PeerId>
    public var pendingClearHistoryPeerIds: Set<PeerId>
    public var archiveShouldBeTemporaryRevealed: Bool
    
    public init(presentationData: ChatListPresentationData, editing: Bool, peerIdWithRevealedOptions: PeerId?, selectedPeerIds: Set<PeerId>, peerInputActivities: ChatListNodePeerInputActivities?, pendingRemovalPeerIds: Set<PeerId>, pendingClearHistoryPeerIds: Set<PeerId>, archiveShouldBeTemporaryRevealed: Bool) {
        self.presentationData = presentationData
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.selectedPeerIds = selectedPeerIds
        self.peerInputActivities = peerInputActivities
        self.pendingRemovalPeerIds = pendingRemovalPeerIds
        self.pendingClearHistoryPeerIds = pendingClearHistoryPeerIds
        self.archiveShouldBeTemporaryRevealed = archiveShouldBeTemporaryRevealed
    }
    
    public static func ==(lhs: ChatListNodeState, rhs: ChatListNodeState) -> Bool {
        if lhs.presentationData !== rhs.presentationData {
            return false
        }
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.selectedPeerIds != rhs.selectedPeerIds {
            return false
        }
        if lhs.peerInputActivities !== rhs.peerInputActivities {
            return false
        }
        if lhs.pendingRemovalPeerIds != rhs.pendingRemovalPeerIds {
            return false
        }
        if lhs.pendingClearHistoryPeerIds != rhs.pendingClearHistoryPeerIds {
            return false
        }
        if lhs.archiveShouldBeTemporaryRevealed != rhs.archiveShouldBeTemporaryRevealed {
            return false
        }
        return true
    }
}

private func mappedInsertEntries(context: AccountContext, nodeInteraction: ChatListNodeInteraction, peerGroupId: PeerGroupId, mode: ChatListNodeMode, entries: [ChatListNodeViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case let .PeerEntry(index, presentationData, message, combinedReadState, notificationSettings, embeddedState, peer, presence, summaryInfo, editing, hasActiveRevealControls, selected, inputActivities, isAd):
                switch mode {
                    case .chatList:
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, context: context, peerGroupId: peerGroupId, index: index, content: .peer(message: message, peer: peer, combinedReadState: combinedReadState, notificationSettings: notificationSettings, presence: presence, summaryInfo: summaryInfo, embeddedState: embeddedState, inputActivities: inputActivities, isAd: isAd, ignoreUnreadBadge: false), editing: editing, hasActiveRevealControls: hasActiveRevealControls, selected: selected, header: nil, enableContextActions: true, hiddenOffset: false, interaction: nodeInteraction), directionHint: entry.directionHint)
                    case let .peers(filter):
                        let itemPeer = peer.chatMainPeer
                        var chatPeer: Peer?
                        if let peer = peer.peers[peer.peerId] {
                            chatPeer = peer
                        }
                        var enabled = true
                        if filter.contains(.onlyWriteable) {
                            if let peer = peer.peers[peer.peerId] {
                                if !canSendMessagesToPeer(peer) {
                                    enabled = false
                                }
                            } else {
                                enabled = false
                            }
                        }
                        if filter.contains(.onlyPrivateChats) {
                            if let peer = peer.peers[peer.peerId] {
                                if !(peer is TelegramUser || peer is TelegramSecretChat) {
                                    enabled = false
                                }
                            } else {
                                enabled = false
                            }
                        }
                        if filter.contains(.onlyGroups) {
                            if let peer = peer.peers[peer.peerId] {
                                if let _ = peer as? TelegramGroup {
                                } else if let peer = peer as? TelegramChannel, case .group = peer.info {
                                } else {
                                    enabled = false
                                }
                            } else {
                                enabled = false
                            }
                        }
                        if filter.contains(.onlyManageable) {
                            if let peer = peer.peers[peer.peerId] {
                                var canManage = false
                                if let peer = peer as? TelegramGroup {
                                    switch peer.role {
                                        case .creator, .admin:
                                            canManage = true
                                        default:
                                            break
                                    }
                                }
                                
                                if canManage {
                                } else if let peer = peer as? TelegramChannel, case .group = peer.info, peer.hasPermission(.inviteMembers) {
                                } else {
                                    enabled = false
                                }
                            } else {
                                enabled = false
                            }
                        }

                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(theme: presentationData.theme, strings: presentationData.strings, sortOrder: presentationData.nameSortOrder, displayOrder: presentationData.nameDisplayOrder, account: context.account, peerMode: .generalSearch, peer: .peer(peer: itemPeer, chatPeer: chatPeer), status: .none, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { _ in
                            if let chatPeer = chatPeer {
                                nodeInteraction.peerSelected(chatPeer)
                            }
                        }), directionHint: entry.directionHint)
                }
            case let .HoleEntry(_, theme):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(theme: theme), directionHint: entry.directionHint)
            case let .GroupReferenceEntry(index, presentationData, groupId, peers, message, editing, unreadState, revealed, hiddenByDefault):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, context: context, peerGroupId: peerGroupId, index: index, content: .groupReference(groupId: groupId, peers: peers, message: message, unreadState: unreadState, hiddenByDefault: hiddenByDefault), editing: editing, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: true, hiddenOffset: hiddenByDefault && !revealed, interaction: nodeInteraction), directionHint: entry.directionHint)
            case let .ArchiveIntro(presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListArchiveInfoItem(theme: presentationData.theme, strings: presentationData.strings), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, nodeInteraction: ChatListNodeInteraction, peerGroupId: PeerGroupId, mode: ChatListNodeMode, entries: [ChatListNodeViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .PeerEntry(index, presentationData, message, combinedReadState, notificationSettings, embeddedState, peer, presence, summaryInfo, editing, hasActiveRevealControls, selected, inputActivities, isAd):
                switch mode {
                    case .chatList:
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, context: context, peerGroupId: peerGroupId, index: index, content: .peer(message: message, peer: peer, combinedReadState: combinedReadState, notificationSettings: notificationSettings, presence: presence, summaryInfo: summaryInfo, embeddedState: embeddedState, inputActivities: inputActivities, isAd: isAd, ignoreUnreadBadge: false), editing: editing, hasActiveRevealControls: hasActiveRevealControls, selected: selected, header: nil, enableContextActions: true, hiddenOffset: false, interaction: nodeInteraction), directionHint: entry.directionHint)
                    case let .peers(filter):
                        let itemPeer = peer.chatMainPeer
                        var chatPeer: Peer?
                        if let peer = peer.peers[peer.peerId] {
                            chatPeer = peer
                        }
                        var enabled = true
                        if filter.contains(.onlyWriteable) {
                            if let peer = peer.peers[peer.peerId] {
                                if !canSendMessagesToPeer(peer) {
                                    enabled = false
                                }
                            } else {
                                enabled = false
                            }
                        }
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(theme: presentationData.theme, strings: presentationData.strings, sortOrder: presentationData.nameSortOrder, displayOrder: presentationData.nameDisplayOrder, account: context.account, peerMode: .generalSearch, peer: .peer(peer: itemPeer, chatPeer: chatPeer), status: .none, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { _ in
                            if let chatPeer = chatPeer {
                                nodeInteraction.peerSelected(chatPeer)
                            }
                        }), directionHint: entry.directionHint)
                }
            case let .HoleEntry(_, theme):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(theme: theme), directionHint: entry.directionHint)
            case let .GroupReferenceEntry(index, presentationData, groupId, peers, message, editing, unreadState, revealed, hiddenByDefault):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, context: context, peerGroupId: peerGroupId, index: index, content: .groupReference(groupId: groupId, peers: peers, message: message, unreadState: unreadState, hiddenByDefault: hiddenByDefault), editing: editing, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: true, hiddenOffset: hiddenByDefault && !revealed, interaction: nodeInteraction), directionHint: entry.directionHint)
            case let .ArchiveIntro(presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListArchiveInfoItem(theme: presentationData.theme, strings: presentationData.strings), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatListNodeViewListTransition(context: AccountContext, nodeInteraction: ChatListNodeInteraction, peerGroupId: PeerGroupId, mode: ChatListNodeMode, transition: ChatListNodeViewTransition) -> ChatListNodeListViewTransition {
    return ChatListNodeListViewTransition(chatListView: transition.chatListView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(context: context, nodeInteraction: nodeInteraction, peerGroupId: peerGroupId, mode: mode, entries: transition.insertEntries), updateItems: mappedUpdateEntries(context: context, nodeInteraction: nodeInteraction, peerGroupId: peerGroupId, mode: mode, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange)
}

private final class ChatListOpaqueTransactionState {
    let chatListView: ChatListNodeView
    
    init(chatListView: ChatListNodeView) {
        self.chatListView = chatListView
    }
}

public enum ChatListSelectionOption {
    case previous(unread: Bool)
    case next(unread: Bool)
    case peerId(PeerId)
    case index(Int)
}

public enum ChatListGlobalScrollOption {
    case none
    case top
    case unread
}

private struct ChatListVisibleUnreadCounts: Equatable {
    var raw: Int32 = 0
    var filtered: Int32 = 0
}

public enum ChatListNodeScrollPosition {
    case auto
    case autoUp
    case top
}

public enum ChatListNodeEmptyState: Equatable {
    case notEmpty(containsChats: Bool)
    case empty(isLoading: Bool)
}

public final class ChatListNode: ListView {
    private let controlsHistoryPreload: Bool
    private let context: AccountContext
    private let groupId: PeerGroupId
    private let mode: ChatListNodeMode
    
    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    public var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    public var peerSelected: ((PeerId, Bool, Bool) -> Void)?
    public var groupSelected: ((PeerGroupId) -> Void)?
    public var addContact: ((String) -> Void)?
    public var activateSearch: (() -> Void)?
    public var deletePeerChat: ((PeerId) -> Void)?
    public var updatePeerGrouping: ((PeerId, Bool) -> Void)?
    public var presentAlert: ((String) -> Void)?
    public var toggleArchivedFolderHiddenByDefault: (() -> Void)?
    
    private var theme: PresentationTheme
    
    private let viewProcessingQueue = Queue()
    private var chatListView: ChatListNodeView?
    private var interaction: ChatListNodeInteraction?
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedTransition: (ChatListNodeListViewTransition, () -> Void)?
    
    private(set) var currentState: ChatListNodeState
    private let statePromise: ValuePromise<ChatListNodeState>
    public var state: Signal<ChatListNodeState, NoError> {
        return self.statePromise.get()
    }
    
    private var currentLocation: ChatListNodeLocation?
    private let chatListLocation = ValuePromise<ChatListNodeLocation>()
    private let chatListDisposable = MetaDisposable()
    private var activityStatusesDisposable: Disposable?
    
    private let scrollToTopOptionPromise = Promise<ChatListGlobalScrollOption>(.none)
    public var scrollToTopOption: Signal<ChatListGlobalScrollOption, NoError> {
        return self.scrollToTopOptionPromise.get()
    }
    
    private let scrolledAtTop = ValuePromise<Bool>(true)
    private var scrolledAtTopValue: Bool = true {
        didSet {
            if self.scrolledAtTopValue != oldValue {
                self.scrolledAtTop.set(self.scrolledAtTopValue)
            }
        }
    }
    
    public var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    public var contentScrollingEnded: ((ListView) -> Bool)?
    
    private let visibleUnreadCounts = ValuePromise<ChatListVisibleUnreadCounts>(ChatListVisibleUnreadCounts())
    private var visibleUnreadCountsValue = ChatListVisibleUnreadCounts() {
        didSet {
            if self.visibleUnreadCountsValue != oldValue {
                self.visibleUnreadCounts.set(self.visibleUnreadCountsValue)
            }
        }
    }
    
    public var isEmptyUpdated: ((ChatListNodeEmptyState) -> Void)?
    private var currentIsEmptyState: ChatListNodeEmptyState?
    
    public var addedVisibleChatsWithPeerIds: (([PeerId]) -> Void)?
    
    private let currentRemovingPeerId = Atomic<PeerId?>(value: nil)
    public func setCurrentRemovingPeerId(_ peerId: PeerId?) {
        let _ = self.currentRemovingPeerId.swap(peerId)
    }
    
    private var hapticFeedback: HapticFeedback?
    
    public init(context: AccountContext, groupId: PeerGroupId, controlsHistoryPreload: Bool, mode: ChatListNodeMode, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        self.context = context
        self.groupId = groupId
        self.controlsHistoryPreload = controlsHistoryPreload
        self.mode = mode
        
        self.currentState = ChatListNodeState(presentationData: ChatListPresentationData(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, disableAnimations: disableAnimations), editing: false, peerIdWithRevealedOptions: nil, selectedPeerIds: Set(), peerInputActivities: nil, pendingRemovalPeerIds: Set(), pendingClearHistoryPeerIds: Set(), archiveShouldBeTemporaryRevealed: false)
        self.statePromise = ValuePromise(self.currentState, ignoreRepeated: true)
        
        self.theme = theme
        
        super.init()
        
        self.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
        self.verticalScrollIndicatorFollowsOverscroll = true
        
        let nodeInteraction = ChatListNodeInteraction(activateSearch: { [weak self] in
            if let strongSelf = self, let activateSearch = strongSelf.activateSearch {
                activateSearch()
            }
        }, peerSelected: { [weak self] peer in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(peer.id, true, false)
            }
        }, togglePeerSelected: { [weak self] peerId in
            self?.updateState { state in
                var state = state
                if state.selectedPeerIds.contains(peerId) {
                    state.selectedPeerIds.remove(peerId)
                } else {
                    if state.selectedPeerIds.count < 100 {
                        state.selectedPeerIds.insert(peerId)
                    }
                }
                return state
            }
        }, messageSelected: { [weak self] peer, message, isAd in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(peer.id, true, isAd)
            }
        }, groupSelected: { [weak self] groupId in
            if let strongSelf = self, let groupSelected = strongSelf.groupSelected {
                groupSelected(groupId)
            }
        }, addContact: { _ in
        }, setPeerIdWithRevealedOptions: { [weak self] peerId, fromPeerId in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) || (peerId == nil && fromPeerId == nil) {
                        var state = state
                        state.peerIdWithRevealedOptions = peerId
                        return state
                    } else {
                        return state
                    }
                }
            }
        }, setItemPinned: { [weak self] itemId, _ in
            let _ = (toggleItemPinned(postbox: context.account.postbox, groupId: groupId, itemId: itemId)
            |> deliverOnMainQueue).start(next: { result in
                if let strongSelf = self {
                    switch result {
                        case .done:
                            break
                        case let .limitExceeded(maxCount):
                            strongSelf.presentAlert?(strongSelf.currentState.presentationData.strings.DialogList_PinLimitError("\(maxCount)").0)
                    }
                }
            })
        }, setPeerMuted: { [weak self] peerId, _ in
            let _ = (togglePeerMuted(account: context.account, peerId: peerId)
            |> deliverOnMainQueue).start(completed: {
                self?.updateState { state in
                    var state = state
                    state.peerIdWithRevealedOptions = nil
                    return state
                }
            })
        }, deletePeer: { [weak self] peerId in
            self?.deletePeerChat?(peerId)
        }, updatePeerGrouping: { [weak self] peerId, group in
            self?.updatePeerGrouping?(peerId, group)
        }, togglePeerMarkedUnread: { [weak self, weak context] peerId, animated in
            guard let context = context else {
                return
            }
                        
            let _ = (togglePeerUnreadMarkInteractively(postbox: context.account.postbox, viewTracker: context.account.viewTracker, peerId: peerId)
            |> deliverOnMainQueue).start(completed: {
                self?.updateState { state in
                    var state = state
                    state.peerIdWithRevealedOptions = nil
                    return state
                }
            })
        }, toggleArchivedFolderHiddenByDefault: { [weak self] in
            self?.toggleArchivedFolderHiddenByDefault?()
        })
        
        let viewProcessingQueue = self.viewProcessingQueue
        
        let chatListViewUpdate = self.chatListLocation.get()
        |> distinctUntilChanged
        |> mapToSignal { location in
            return chatListViewForLocation(groupId: groupId, location: location, account: context.account)
        }
        
        let previousState = Atomic<ChatListNodeState>(value: self.currentState)
        let previousView = Atomic<ChatListNodeView?>(value: nil)
        let previousHideArchivedFolderByDefault = Atomic<Bool?>(value: nil)
        let currentRemovingPeerId = self.currentRemovingPeerId
        
        let savedMessagesPeer: Signal<Peer?, NoError>
        if case let .peers(filter) = mode, filter.contains(.onlyWriteable) {
            savedMessagesPeer = context.account.postbox.loadedPeerWithId(context.account.peerId)
            |> map(Optional.init)
        } else {
            savedMessagesPeer = .single(nil)
        }
        
        let hideArchivedFolderByDefault = context.account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.chatArchiveSettings])
        |> map { view -> Bool in
            let settings: ChatArchiveSettings = view.values[ApplicationSpecificPreferencesKeys.chatArchiveSettings] as? ChatArchiveSettings ?? .default
            return settings.isHiddenByDefault
        }
        |> distinctUntilChanged
        
        let displayArchiveIntro: Signal<Bool, NoError>
        if Namespaces.PeerGroup.archive == groupId {
            displayArchiveIntro = context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.archiveIntroDismissedKey())
            |> map { entry -> Bool in
                if let value = entry.value as? ApplicationSpecificVariantNotice {
                    return !value.value
                } else {
                    return true
                }
            }
            |> take(1)
            |> afterNext { value in
                Queue.mainQueue().async {
                    if value {
                        let _ = (context.sharedContext.accountManager.transaction { transaction -> Void in
                            ApplicationSpecificNotice.setArchiveIntroDismissed(transaction: transaction, value: true)
                        }).start()
                    }
                }
            }
        } else {
            displayArchiveIntro = .single(false)
        }
        
        let currentPeerId: PeerId = context.account.peerId
        
        let chatListNodeViewTransition = combineLatest(queue: viewProcessingQueue, hideArchivedFolderByDefault, displayArchiveIntro, savedMessagesPeer, chatListViewUpdate, self.statePromise.get())
        |> mapToQueue { (hideArchivedFolderByDefault, displayArchiveIntro, savedMessagesPeer, update, state) -> Signal<ChatListNodeListViewTransition, NoError> in
            
            let previousHideArchivedFolderByDefaultValue = previousHideArchivedFolderByDefault.swap(hideArchivedFolderByDefault)
            
            let (rawEntries, isLoading) = chatListNodeEntriesForView(update.view, state: state, savedMessagesPeer: savedMessagesPeer, hideArchivedFolderByDefault: hideArchivedFolderByDefault, displayArchiveIntro: displayArchiveIntro, mode: mode)
            let entries = rawEntries.filter { entry in
                switch entry {
                case let .PeerEntry(_, _, _, _, _, _, peer, _, _, _, _, _, _, _):
                    switch mode {
                        case .chatList:
                            return true
                        case let .peers(filter):
                            guard !filter.contains(.excludeSavedMessages) || peer.peerId != currentPeerId else { return false }
                            guard !filter.contains(.excludeSecretChats) || peer.peerId.namespace != Namespaces.Peer.SecretChat else { return false }
                            guard !filter.contains(.onlyPrivateChats) || peer.peerId.namespace == Namespaces.Peer.CloudUser else { return false }

                            if filter.contains(.onlyGroups) {
                                var isGroup: Bool = false
                                if let peer = peer.chatMainPeer as? TelegramChannel, case .group = peer.info {
                                    isGroup = true
                                } else if peer.peerId.namespace == Namespaces.Peer.CloudGroup {
                                    isGroup = true
                                }
                                if !isGroup {
                                    return false
                                }
                            }
                            
                            if filter.contains(.onlyChannels) {
                                if let peer = peer.chatMainPeer as? TelegramChannel, case .broadcast = peer.info {
                                    return true
                                } else {
                                    return false
                                }
                            }
                            
                            if filter.contains(.onlyWriteable) && filter.contains(.excludeDisabled) {
                                if let peer = peer.peers[peer.peerId] {
                                    if !canSendMessagesToPeer(peer) {
                                        return false
                                    }
                                } else {
                                    return false
                                }
                            }
                            
                            return true
                        }
                    default:
                        return true
                }
            }
            
            let processedView = ChatListNodeView(originalView: update.view, filteredEntries: entries, isLoading: isLoading)
            let previousView = previousView.swap(processedView)
            let previousState = previousState.swap(state)
            
            let reason: ChatListNodeViewTransitionReason
            var prepareOnMainQueue = false
            
            var previousWasEmptyOrSingleHole = false
            if let previous = previousView {
                if previous.filteredEntries.count == 1 {
                    if case .HoleEntry = previous.filteredEntries[0] {
                        previousWasEmptyOrSingleHole = true
                    }
                } else if previous.filteredEntries.isEmpty && previous.isLoading {
                    previousWasEmptyOrSingleHole = true
                }
            } else {
                previousWasEmptyOrSingleHole = true
            }
            
            var updatedScrollPosition = update.scrollPosition
            
            if previousWasEmptyOrSingleHole {
                reason = .initial
                if previousView == nil {
                    prepareOnMainQueue = true
                }
            } else {
                if previousView?.originalView === update.view {
                    reason = .interactiveChanges
                    updatedScrollPosition = nil
                } else {
                    switch update.type {
                        case .InitialUnread, .Initial:
                            reason = .initial
                            prepareOnMainQueue = true
                        case .Generic:
                            reason = .interactiveChanges
                        case .UpdateVisible:
                            reason = .reload
                        case .FillHole:
                            reason = .reload
                    }
                }
            }
            
            let removingPeerId = currentRemovingPeerId.with { $0 }
            
            var disableAnimations = state.presentationData.disableAnimations
            if previousState.editing != state.editing {
                disableAnimations = false
            } else {
                var previousPinnedChats: [PeerId] = []
                var updatedPinnedChats: [PeerId] = []
                
                var didIncludeRemovingPeerId = false
                var didIncludeHiddenByDefaultArchive = false
                if let previous = previousView {
                    for entry in previous.filteredEntries {
                        if case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _) = entry {
                            if index.pinningIndex != nil {
                                previousPinnedChats.append(index.messageIndex.id.peerId)
                            }
                            if index.messageIndex.id.peerId == removingPeerId {
                                didIncludeRemovingPeerId = true
                            }
                        } else if case let .GroupReferenceEntry(entry) = entry {
                            didIncludeHiddenByDefaultArchive = entry.hiddenByDefault
                        }
                    }
                }
                var doesIncludeRemovingPeerId = false
                var doesIncludeArchive = false
                var doesIncludeHiddenByDefaultArchive = false
                for entry in processedView.filteredEntries {
                    if case let .PeerEntry(index, _, _, _, _, _, _, _, _ , _, _, _, _, _) = entry {
                        if index.pinningIndex != nil {
                            updatedPinnedChats.append(index.messageIndex.id.peerId)
                        }
                        if index.messageIndex.id.peerId == removingPeerId {
                            doesIncludeRemovingPeerId = true
                        }
                    } else if case let .GroupReferenceEntry(entry) = entry {
                        doesIncludeArchive = true
                        doesIncludeHiddenByDefaultArchive = entry.hiddenByDefault
                    }
                }
                if previousPinnedChats != updatedPinnedChats {
                    disableAnimations = false
                }
                if previousState.selectedPeerIds != state.selectedPeerIds {
                    disableAnimations = false
                }
                if doesIncludeRemovingPeerId != didIncludeRemovingPeerId {
                    disableAnimations = false
                }
                if hideArchivedFolderByDefault && previousState.archiveShouldBeTemporaryRevealed != state.archiveShouldBeTemporaryRevealed && doesIncludeArchive {
                    disableAnimations = false
                }
                if didIncludeHiddenByDefaultArchive != doesIncludeHiddenByDefaultArchive {
                    disableAnimations = false
                }
            }
            
            if let _ = previousHideArchivedFolderByDefaultValue, previousHideArchivedFolderByDefaultValue != hideArchivedFolderByDefault {
                disableAnimations = false
            }
            
            var searchMode = false
            if case .peers = mode {
                searchMode = true
            }
            
            return preparedChatListNodeViewTransition(from: previousView, to: processedView, reason: reason, disableAnimations: disableAnimations, account: context.account, scrollPosition: updatedScrollPosition, searchMode: searchMode)
            |> map({ mappedChatListNodeViewListTransition(context: context, nodeInteraction: nodeInteraction, peerGroupId: groupId, mode: mode, transition: $0) })
            |> runOn(prepareOnMainQueue ? Queue.mainQueue() : viewProcessingQueue)
        }
        
        let appliedTransition = chatListNodeViewTransition |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            if let strongSelf = self {
                return strongSelf.enqueueTransition(transition)
            }
            return .complete()
        }
        
        self.displayedItemRangeChanged = { [weak self] range, transactionOpaqueState in
            if let strongSelf = self, let chatListView = (transactionOpaqueState as? ChatListOpaqueTransactionState)?.chatListView {
                let originalView = chatListView.originalView
                if let range = range.loadedRange {
                    var location: ChatListNodeLocation?
                    if range.firstIndex < 5 && originalView.laterIndex != nil {
                        location = .navigation(index: originalView.entries[originalView.entries.count - 1].index)
                    } else if range.firstIndex >= 5 && range.lastIndex >= originalView.entries.count - 5 && originalView.earlierIndex != nil {
                        location = .navigation(index: originalView.entries[0].index)
                    }
                    
                    if let location = location, location != strongSelf.currentLocation {
                        strongSelf.setChatListLocation(location)
                    }
                    
                    strongSelf.enqueueHistoryPreloadUpdate()
                }
                
                var rawUnreadCount: Int32 = 0
                var filteredUnreadCount: Int32 = 0
                var archiveVisible = false
                if let range = range.visibleRange {
                    let entryCount = chatListView.filteredEntries.count
                    for i in range.firstIndex ..< range.lastIndex {
                        if i < 0 || i >= entryCount {
                            assertionFailure()
                            continue
                        }
                        switch chatListView.filteredEntries[entryCount - i - 1] {
                            case let .PeerEntry(_, _, _, readState, notificationSettings, _, _, _, _, _, _, _, _, _):
                                if let readState = readState {
                                    let count = readState.count
                                    rawUnreadCount += count
                                    if let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                                        filteredUnreadCount += count
                                    }
                                }
                            case .GroupReferenceEntry:
                                archiveVisible = true
                            default:
                                break
                        }
                    }
                }
                var visibleUnreadCountsValue = strongSelf.visibleUnreadCountsValue
                visibleUnreadCountsValue.raw = rawUnreadCount
                visibleUnreadCountsValue.filtered = filteredUnreadCount
                strongSelf.visibleUnreadCountsValue = visibleUnreadCountsValue
                if !archiveVisible && strongSelf.currentState.archiveShouldBeTemporaryRevealed {
                    strongSelf.updateState { state in
                        var state = state
                        state.archiveShouldBeTemporaryRevealed = false
                        return state
                    }
                }
            }
        }
        
        self.interaction = nodeInteraction
        
        self.chatListDisposable.set(appliedTransition.start())
        
        let initialLocation: ChatListNodeLocation
        switch mode {
            case .chatList:
                initialLocation = .initial(count: 50)
            case .peers:
                initialLocation = .initial(count: 200)
        }
        self.setChatListLocation(initialLocation)
        
        let postbox = context.account.postbox
        let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
        let previousActivities = Atomic<ChatListNodePeerInputActivities?>(value: nil)
        self.activityStatusesDisposable = (context.account.allPeerInputActivities()
        |> mapToSignal { activitiesByPeerId -> Signal<[PeerId: [(Peer, PeerInputActivity)]], NoError> in
            var foundAllPeers = true
            var cachedResult: [PeerId: [(Peer, PeerInputActivity)]] = [:]
            previousPeerCache.with { dict -> Void in
                for (chatPeerId, activities) in activitiesByPeerId {
                    var cachedChatResult: [(Peer, PeerInputActivity)] = []
                    for (peerId, activity) in activities {
                        if let peer = dict[peerId] {
                            cachedChatResult.append((peer, activity))
                        } else {
                            foundAllPeers = false
                            break
                        }
                        cachedResult[chatPeerId] = cachedChatResult
                    }
                }
            }
            if foundAllPeers {
                return .single(cachedResult)
            } else {
                return postbox.transaction { transaction -> [PeerId: [(Peer, PeerInputActivity)]] in
                    var result: [PeerId: [(Peer, PeerInputActivity)]] = [:]
                    var peerCache: [PeerId: Peer] = [:]
                    for (chatPeerId, activities) in activitiesByPeerId {
                        var chatResult: [(Peer, PeerInputActivity)] = []
                        
                        for (peerId, activity) in activities {
                            if let peer = transaction.getPeer(peerId) {
                                chatResult.append((peer, activity))
                                peerCache[peerId] = peer
                            }
                        }
                        
                        result[chatPeerId] = chatResult
                    }
                    let _ = previousPeerCache.swap(peerCache)
                    return result
                }
            }
        }
        |> map { activities -> ChatListNodePeerInputActivities? in
            return previousActivities.modify { current in
                var updated = false
                let currentList: [PeerId: [(Peer, PeerInputActivity)]] = current?.activities ?? [:]
                if currentList.count != activities.count {
                    updated = true
                } else {
                    outer: for (peerId, currentValue) in currentList {
                        if let value = activities[peerId] {
                            if currentValue.count != value.count {
                                updated = true
                                break outer
                            } else {
                                for i in 0 ..< currentValue.count {
                                    if !arePeersEqual(currentValue[i].0, value[i].0) {
                                        updated = true
                                        break outer
                                    }
                                    if currentValue[i].1 != value[i].1 {
                                        updated = true
                                        break outer
                                    }
                                }
                            }
                        } else {
                            updated = true
                            break outer
                        }
                    }
                }
                if updated {
                    if activities.isEmpty {
                        return nil
                    } else {
                        return ChatListNodePeerInputActivities(activities: activities)
                    }
                } else {
                    return current
                }
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] activities in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    var state = state
                    state.peerInputActivities = activities
                    return state
                }
            }
        })
        
        self.reorderItem = { [weak self] fromIndex, toIndex, transactionOpaqueState -> Signal<Bool, NoError> in
            if let strongSelf = self, let filteredEntries = (transactionOpaqueState as? ChatListOpaqueTransactionState)?.chatListView.filteredEntries {
                if fromIndex >= 0 && fromIndex < filteredEntries.count && toIndex >= 0 && toIndex < filteredEntries.count {
                    let fromEntry = filteredEntries[filteredEntries.count - 1 - fromIndex]
                    let toEntry = filteredEntries[filteredEntries.count - 1 - toIndex]
                    
                    var referenceId: PinnedItemId?
                    var beforeAll = false
                    switch toEntry {
                        case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, isAd):
                            if isAd {
                                beforeAll = true
                            } else {
                                referenceId = .peer(index.messageIndex.id.peerId)
                            }
                        /*case let .GroupReferenceEntry(_, _, groupId, _, _, _, _):
                            referenceId = .group(groupId)*/
                        default:
                            break
                    }
                    
                    if let _ = fromEntry.sortIndex.pinningIndex {
                        return strongSelf.context.account.postbox.transaction { transaction -> Bool in
                            var itemIds = transaction.getPinnedItemIds(groupId: groupId)
                            
                            var itemId: PinnedItemId?
                            switch fromEntry {
                                case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _):
                                    itemId = .peer(index.messageIndex.id.peerId)
                                /*case let .GroupReferenceEntry(_, _, groupId, _, _, _, _):
                                    itemId = .group(groupId)*/
                                default:
                                    break
                            }
                            
                            if let itemId = itemId {
                                itemIds = itemIds.filter({ $0 != itemId })
                                if let referenceId = referenceId {
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
                                return reorderPinnedItemIds(transaction: transaction, groupId: groupId, itemIds: itemIds)
                            } else {
                                return false
                            }
                        }
                    }
                }
            }
            return .single(false)
        }
        var startedScrollingAtUpperBound = false
        
        self.beganInteractiveDragging = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.visibleContentOffset() {
                case .none, .unknown:
                    startedScrollingAtUpperBound = false
                case let .known(value):
                    startedScrollingAtUpperBound = value <= 0.0
            }
            if strongSelf.currentState.peerIdWithRevealedOptions != nil {
                strongSelf.updateState { state in
                    var state = state
                    state.peerIdWithRevealedOptions = nil
                    return state
                }
            }
        }
        
        self.didEndScrolling = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            startedScrollingAtUpperBound = false
            let _ = strongSelf.contentScrollingEnded?(strongSelf)
            let revealHiddenItems: Bool
            switch strongSelf.visibleContentOffset() {
                case .none, .unknown:
                    revealHiddenItems = false
                case let .known(value):
                    revealHiddenItems = value <= 54.0
            }
            if !revealHiddenItems && strongSelf.currentState.archiveShouldBeTemporaryRevealed {
                strongSelf.updateState { state in
                    var state = state
                    state.archiveShouldBeTemporaryRevealed = false
                    return state
                }
            }
        }
        
        self.scrollToTopOptionPromise.set(combineLatest(
            renderedTotalUnreadCount(accountManager: self.context.sharedContext.accountManager, postbox: self.context.account.postbox) |> deliverOnMainQueue,
            self.visibleUnreadCounts.get(),
            self.scrolledAtTop.get()
        ) |> map { badge, visibleUnreadCounts, scrolledAtTop -> ChatListGlobalScrollOption in
            if scrolledAtTop {
                if badge.0 != 0 {
                    switch badge.1 {
                        case .raw:
                            if visibleUnreadCounts.raw < badge.0 {
                                return .unread
                            }
                        case .filtered:
                            if visibleUnreadCounts.filtered < badge.0 {
                                return .unread
                            }
                    }
                    return .none
                } else {
                    return .none
                }
            } else {
                return .top
            }
        })
        
        self.visibleContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self else {
                return
            }
            let atTop: Bool
            var revealHiddenItems: Bool = false
            switch offset {
                case .none, .unknown:
                    atTop = false
                case let .known(value):
                    atTop = value <= 0.0
                    if startedScrollingAtUpperBound && strongSelf.isTracking {
                        revealHiddenItems = value <= -60.0
                    }
            }
            strongSelf.scrolledAtTopValue = atTop
            strongSelf.contentOffsetChanged?(offset)
            if revealHiddenItems && !strongSelf.currentState.archiveShouldBeTemporaryRevealed {
                var isHiddenArchiveVisible = false
                strongSelf.forEachItemNode({ itemNode in
                    if let itemNode = itemNode as? ChatListItemNode, let item = itemNode.item {
                        if case let .groupReference(groupReference) = item.content {
                            if groupReference.hiddenByDefault {
                                isHiddenArchiveVisible = true
                            }
                        }
                    }
                })
                if isHiddenArchiveVisible {
                    if strongSelf.hapticFeedback == nil {
                        strongSelf.hapticFeedback = HapticFeedback()
                    }
                    strongSelf.hapticFeedback?.impact(.medium)
                    strongSelf.updateState { state in
                        var state = state
                        state.archiveShouldBeTemporaryRevealed = true
                        return state
                    }
                }
            }
        }
    }
    
    deinit {
        self.chatListDisposable.dispose()
        self.activityStatusesDisposable?.dispose()
    }
    
    public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        if theme !== self.currentState.presentationData.theme || strings !== self.currentState.presentationData.strings || dateTimeFormat != self.currentState.presentationData.dateTimeFormat || disableAnimations != self.currentState.presentationData.disableAnimations {
            self.theme = theme
            if self.keepTopItemOverscrollBackground != nil {
                self.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color:  theme.chatList.pinnedItemBackgroundColor, direction: true)
            }
            self.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
            
            self.updateState { state in
                var state = state
                state.presentationData = ChatListPresentationData(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, disableAnimations: disableAnimations)
                return state
            }
        }
    }
    
    public func updateState(_ f: (ChatListNodeState) -> ChatListNodeState) {
        let state = f(self.currentState)
        if state != self.currentState {
            self.currentState = state
            self.statePromise.set(state)
        }
    }
    
    private func enqueueTransition(_ transition: ChatListNodeListViewTransition) -> Signal<Void, NoError> {
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                if let _ = strongSelf.enqueuedTransition {
                    preconditionFailure()
                }
                
                strongSelf.enqueuedTransition = (transition, {
                    subscriber.putCompletion()
                })
                
                if strongSelf.isNodeLoaded, strongSelf.dequeuedInitialTransitionOnLayout {
                    strongSelf.dequeueTransition()
                } else {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                }
            } else {
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        } |> runOn(Queue.mainQueue())
    }
    
    private func dequeueTransition() {
        if let (transition, completion) = self.enqueuedTransition {
            self.enqueuedTransition = nil
            
            let completion: (ListViewDisplayedItemRange) -> Void = { [weak self] visibleRange in
                if let strongSelf = self {
                    strongSelf.chatListView = transition.chatListView
                    
                    var pinnedOverscroll = false
                    if case .chatList = strongSelf.mode {
                        let entryCount = transition.chatListView.filteredEntries.count
                        if entryCount >= 1 {
                            if transition.chatListView.filteredEntries[entryCount - 1].sortIndex.pinningIndex != nil {
                                pinnedOverscroll = true
                            }
                        }
                    }
                    
                    if pinnedOverscroll != (strongSelf.keepTopItemOverscrollBackground != nil) {
                        if pinnedOverscroll {
                            strongSelf.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: strongSelf.theme.chatList.pinnedItemBackgroundColor, direction: true)
                        } else {
                            strongSelf.keepTopItemOverscrollBackground = nil
                        }
                    }
                    
                    if let scrollToItem = transition.scrollToItem, case .center = scrollToItem.position {
                        if let itemNode = strongSelf.itemNodeAtIndex(scrollToItem.index) as? ChatListItemNode {
                            itemNode.flashHighlight()
                        }
                    }
                    
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                    
                    var isEmpty = false
                    if transition.chatListView.filteredEntries.isEmpty {
                        isEmpty = true
                    } else {
                        if transition.chatListView.filteredEntries.count == 1 {
                            if case .GroupReferenceEntry = transition.chatListView.filteredEntries[0] {
                                isEmpty = true
                            }
                        }
                    }
                
                    let isEmptyState: ChatListNodeEmptyState
                    if transition.chatListView.isLoading {
                        isEmptyState = .empty(isLoading: true)
                    } else if isEmpty {
                        isEmptyState = .empty(isLoading: false)
                    } else {
                        var containsChats = false
                        loop: for entry in transition.chatListView.filteredEntries {
                            switch entry {
                                case .GroupReferenceEntry, .HoleEntry, .PeerEntry:
                                    containsChats = true
                                    break loop
                                case .ArchiveIntro:
                                    break
                            }
                        }
                        isEmptyState = .notEmpty(containsChats: containsChats)
                    }
                    if strongSelf.currentIsEmptyState != isEmptyState {
                        strongSelf.currentIsEmptyState = isEmptyState
                        strongSelf.isEmptyUpdated?(isEmptyState)
                    }
                    
                    var insertedPeerIds: [PeerId] = []
                    for item in transition.insertItems {
                        if let item = item.item as? ChatListItem {
                            switch item.content {
                                case let .peer(peer):
                                    insertedPeerIds.append(peer.peer.peerId)
                                case .groupReference:
                                    break
                            }
                        }
                    }
                    if !insertedPeerIds.isEmpty {
                        strongSelf.addedVisibleChatsWithPeerIds?(insertedPeerIds)
                    }
                    
                    completion()
                }
            }
            
            var options = transition.options
            if !options.contains(.AnimateInsertion) {
                options.insert(.PreferSynchronousDrawing)
                options.insert(.PreferSynchronousResourceLoading)
            }
            if options.contains(.AnimateCrossfade) && !self.isDeceleratingAfterTracking {
                options.insert(.PreferSynchronousDrawing)
            }
            
            self.transaction(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, updateOpaqueState: ChatListOpaqueTransactionState(chatListView: transition.chatListView), completion: completion)
        }
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets) {
        self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueTransition()
        }
    }
    
    public func scrollToPosition(_ position: ChatListNodeScrollPosition) {
        if let view = self.chatListView?.originalView {
            if case .auto = position {
                switch self.visibleContentOffset() {
                    case .none, .unknown:
                        if let maxVisibleChatListIndex = self.currentlyVisibleLatestChatListIndex() {
                            self.scrollToEarliestUnread(earlierThan: maxVisibleChatListIndex)
                            return
                        }
                    case let .known(offset):
                        if offset <= 0.0 {
                            self.scrollToEarliestUnread(earlierThan: nil)
                            return
                        } else {
                            if let maxVisibleChatListIndex = self.currentlyVisibleLatestChatListIndex() {
                                self.scrollToEarliestUnread(earlierThan: maxVisibleChatListIndex)
                                return
                            }
                        }
                }
            } else if case .autoUp = position, let maxVisibleChatListIndex = self.currentlyVisibleLatestChatListIndex() {
                self.scrollToEarliestUnread(earlierThan: maxVisibleChatListIndex)
                return
            }
            
            if view.laterIndex == nil {
                self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            } else {
                let location: ChatListNodeLocation = .scroll(index: .absoluteUpperBound, sourceIndex: .absoluteLowerBound
                    , scrollPosition: .top(0.0), animated: true)
                self.setChatListLocation(location)
            }
        } else {
            let location: ChatListNodeLocation = .scroll(index: .absoluteUpperBound, sourceIndex: .absoluteLowerBound
                , scrollPosition: .top(0.0), animated: true)
            self.setChatListLocation(location)
        }
    }
    
    private func setChatListLocation(_ location: ChatListNodeLocation) {
        self.currentLocation = location
        self.chatListLocation.set(location)
    }
    
    private func relativeUnreadChatListIndex(position: ChatListRelativePosition) -> Signal<ChatListIndex?, NoError> {
        let groupId = self.groupId
        let postbox = self.context.account.postbox
        return self.context.sharedContext.accountManager.transaction { transaction -> Signal<ChatListIndex?, NoError> in
            var filter = true
            if let inAppNotificationSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.inAppNotificationSettings) as? InAppNotificationSettings {
                switch inAppNotificationSettings.totalUnreadCountDisplayStyle {
                    case .raw:
                        filter = false
                    case .filtered:
                        filter = true
                }
            }
            return postbox.transaction { transaction -> ChatListIndex? in
                return transaction.getRelativeUnreadChatListIndex(filtered: filter, position: position, groupId: groupId)
            }
        }
        |> switchToLatest
    }
    
    public func scrollToEarliestUnread(earlierThan: ChatListIndex?) {
        let _ = (relativeUnreadChatListIndex(position: .earlier(than: earlierThan)) |> deliverOnMainQueue).start(next: { [weak self] index in
            guard let strongSelf = self else {
                return
            }
            
            if let index = index {
                let location: ChatListNodeLocation = .scroll(index: index, sourceIndex: self?.currentlyVisibleLatestChatListIndex() ?? .absoluteUpperBound
                    , scrollPosition: .center(.top), animated: true)
                strongSelf.setChatListLocation(location)
            } else {
                let location: ChatListNodeLocation = .scroll(index: .absoluteUpperBound, sourceIndex: .absoluteLowerBound
                    , scrollPosition: .top(0.0), animated: true)
                strongSelf.setChatListLocation(location)
            }
        })
    }
    
    public func selectChat(_ option: ChatListSelectionOption) {
        guard let interaction = self.interaction else {
            return
        }
        
        guard let chatListView = (self.opaqueTransactionState as? ChatListOpaqueTransactionState)?.chatListView else {
            return
        }
        
        guard let range = self.displayedItemRange.loadedRange else {
            return
        }
        
        let entryCount = chatListView.filteredEntries.count
        var current: (ChatListIndex, PeerId, Int)? = nil
        var previous: (ChatListIndex, PeerId)? = nil
        var next: (ChatListIndex, PeerId)? = nil
        
        outer: for i in range.firstIndex ..< range.lastIndex {
            if i < 0 || i >= entryCount {
                assertionFailure()
                continue
            }
            switch chatListView.filteredEntries[entryCount - i - 1] {
                case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _, _, _):
                    if interaction.highlightedChatLocation?.location == ChatLocation.peer(peer.peerId) {
                        current = (index, peer.peerId, entryCount - i - 1)
                        break outer
                    }
                default:
                    break
            }
        }
        
        switch option {
            case .previous(unread: true), .next(unread: true):
                let position: ChatListRelativePosition
                if let current = current {
                    if case .previous = option {
                        position = .earlier(than: current.0)
                    } else {
                        position = .later(than: current.0)
                    }
                } else {
                    position = .later(than: nil)
                }
                let _ = (relativeUnreadChatListIndex(position: position) |> deliverOnMainQueue).start(next: { [weak self] index in
                    guard let strongSelf = self, let index = index else {
                        return
                    }
                    let location: ChatListNodeLocation = .scroll(index: index, sourceIndex: strongSelf.currentlyVisibleLatestChatListIndex() ?? .absoluteUpperBound, scrollPosition: .center(.top), animated: true)
                    strongSelf.setChatListLocation(location)
                    strongSelf.peerSelected?(index.messageIndex.id.peerId, false, false)
                })
            case .previous(unread: false), .next(unread: false):
                var target: (ChatListIndex, PeerId)? = nil
                if let current = current, entryCount > 1 {
                    if current.2 > 0, case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _, _, _) = chatListView.filteredEntries[current.2 - 1] {
                        next = (index, peer.peerId)
                    }
                    if current.2 <= entryCount - 2, case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _, _, _) = chatListView.filteredEntries[current.2 + 1] {
                        previous = (index, peer.peerId)
                    }
                    if case .previous = option {
                        target = previous
                    } else {
                        target = next
                    }
                } else if entryCount > 0 {
                    if case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _, _, _) = chatListView.filteredEntries[entryCount - 1] {
                        target = (index, peer.peerId)
                    }
                }
                if let target = target {
                    let location: ChatListNodeLocation = .scroll(index: target.0, sourceIndex: .absoluteLowerBound, scrollPosition: .center(.top), animated: true)
                    self.setChatListLocation(location)
                    self.peerSelected?(target.1, false, false)
                }
            case let .peerId(peerId):
                self.peerSelected?(peerId, false, false)
            case let .index(index):
                guard index < 10 else {
                    return
                }
                let _ = (chatListViewForLocation(groupId: self.groupId, location: .initial(count: 10), account: self.context.account)
                |> take(1)
                |> deliverOnMainQueue).start(next: { update in
                    let entries = update.view.entries
                    if entries.count > index, case let .MessageEntry(index, _, _, _, _, renderedPeer, _, _) = entries[10 - index - 1] {
                        let location: ChatListNodeLocation = .scroll(index: index, sourceIndex: .absoluteLowerBound, scrollPosition: .center(.top), animated: true)
                        self.setChatListLocation(location)
                        self.peerSelected?(renderedPeer.peerId, false, false)
                    }
                })
                break
        }
    }
    
    private func enqueueHistoryPreloadUpdate() {
    }
    
    public func updateSelectedChatLocation(_ chatLocation: ChatLocation?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let interaction = self.interaction else {
            return
        }
        
        if let chatLocation = chatLocation {
            interaction.highlightedChatLocation = ChatListHighlightedLocation(location: chatLocation, progress: progress)
        } else {
            interaction.highlightedChatLocation = nil
        }
        
        self.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatListItemNode {
                itemNode.updateIsHighlighted(transition: transition)
            }
        }
    }
    
    private func currentlyVisibleLatestChatListIndex() -> ChatListIndex? {
        guard let chatListView = (self.opaqueTransactionState as? ChatListOpaqueTransactionState)?.chatListView else {
            return nil
        }
        if let range = self.displayedItemRange.visibleRange {
            let entryCount = chatListView.filteredEntries.count
            for i in range.firstIndex ..< range.lastIndex {
                if i < 0 || i >= entryCount {
                    assertionFailure()
                    continue
                }
                switch chatListView.filteredEntries[entryCount - i - 1] {
                    case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _):
                        return index
                    default:
                        break
                }
            }
        }
        return nil
    }
}
