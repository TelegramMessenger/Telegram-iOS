import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox

public struct ChatListNodePeersFilter: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let onlyWriteable = ChatListNodePeersFilter(rawValue: 1 << 0)
    public static let onlyUsers = ChatListNodePeersFilter(rawValue: 1 << 1)
    public static let onlyGroups = ChatListNodePeersFilter(rawValue: 1 << 2)
}

enum ChatListNodeMode {
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

final class ChatListNodeInteraction {
    let activateSearch: () -> Void
    let peerSelected: (Peer) -> Void
    let messageSelected: (Message) -> Void
    let groupSelected: (PeerGroupId) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let setItemPinned: (PinnedItemId, Bool) -> Void
    let setPeerMuted: (PeerId, Bool) -> Void
    let deletePeer: (PeerId) -> Void
    let updatePeerGrouping: (PeerId, Bool) -> Void
    let togglePeerMarkedUnread: (PeerId, Bool) -> Void
    
    var highlightedChatLocation: ChatListHighlightedLocation?
    
    init(activateSearch: @escaping () -> Void, peerSelected: @escaping (Peer) -> Void, messageSelected: @escaping (Message) -> Void, groupSelected: @escaping (PeerGroupId) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, setItemPinned: @escaping (PinnedItemId, Bool) -> Void, setPeerMuted: @escaping (PeerId, Bool) -> Void, deletePeer: @escaping (PeerId) -> Void, updatePeerGrouping: @escaping (PeerId, Bool) -> Void, togglePeerMarkedUnread: @escaping (PeerId, Bool) -> Void) {
        self.activateSearch = activateSearch
        self.peerSelected = peerSelected
        self.messageSelected = messageSelected
        self.groupSelected = groupSelected
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.setItemPinned = setItemPinned
        self.setPeerMuted = setPeerMuted
        self.deletePeer = deletePeer
        self.updatePeerGrouping = updatePeerGrouping
        self.togglePeerMarkedUnread = togglePeerMarkedUnread
    }
}

final class ChatListNodePeerInputActivities {
    let activities: [PeerId: [(Peer, PeerInputActivity)]]
    
    init(activities: [PeerId: [(Peer, PeerInputActivity)]]) {
        self.activities = activities
    }
}

struct ChatListNodeState: Equatable {
    let presentationData: ChatListPresentationData
    let editing: Bool
    let peerIdWithRevealedOptions: PeerId?
    let peerInputActivities: ChatListNodePeerInputActivities?
    
    func withUpdatedPresentationData(_ presentationData: ChatListPresentationData) -> ChatListNodeState {
        return ChatListNodeState(presentationData: presentationData, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, peerInputActivities: self.peerInputActivities)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChatListNodeState {
        return ChatListNodeState(presentationData: self.presentationData, editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, peerInputActivities: self.peerInputActivities)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChatListNodeState {
        return ChatListNodeState(presentationData: self.presentationData, editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, peerInputActivities: self.peerInputActivities)
    }
    
    func withUpdatedPeerInputActivities(_ peerInputActivities: ChatListNodePeerInputActivities?) -> ChatListNodeState {
        return ChatListNodeState(presentationData: self.presentationData, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, peerInputActivities: peerInputActivities)
    }
    
    static func ==(lhs: ChatListNodeState, rhs: ChatListNodeState) -> Bool {
        if lhs.presentationData !== rhs.presentationData {
            return false
        }
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.peerInputActivities !== rhs.peerInputActivities {
            return false
        }
        return true
    }
}

private func mappedInsertEntries(account: Account, nodeInteraction: ChatListNodeInteraction, peerGroupId: PeerGroupId?, mode: ChatListNodeMode, entries: [ChatListNodeViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case let .SearchEntry(theme, text):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(theme: theme, placeholder: text, activate: {
                    nodeInteraction.activateSearch()
                }), directionHint: entry.directionHint)
            case let .PeerEntry(index, presentationData, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo, editing, hasActiveRevealControls, inputActivities, isAd):
                switch mode {
                    case .chatList:
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, account: account, peerGroupId: peerGroupId, index: index, content: .peer(message: message, peer: peer, combinedReadState: combinedReadState, notificationSettings: notificationSettings, summaryInfo: summaryInfo, embeddedState: embeddedState, inputActivities: inputActivities, isAd: isAd, ignoreUnreadBadge: false), editing: editing, hasActiveRevealControls: hasActiveRevealControls, header: nil, enableContextActions: true, interaction: nodeInteraction), directionHint: entry.directionHint)
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
                        if filter.contains(.onlyUsers) {
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
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(theme: presentationData.theme, strings: presentationData.strings, sortOrder: presentationData.nameSortOrder, displayOrder: presentationData.nameDisplayOrder, account: account, peerMode: .generalSearch, peer: .peer(peer: itemPeer, chatPeer: chatPeer), status: .none, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { _ in
                            if let chatPeer = chatPeer {
                                nodeInteraction.peerSelected(chatPeer)
                            }
                        }), directionHint: entry.directionHint)
                }
            case let .HoleEntry(_, theme):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(theme: theme), directionHint: entry.directionHint)
            case let .GroupReferenceEntry(index, presentationData, groupId, message, topPeers, counters, editing):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, account: account, peerGroupId: peerGroupId, index: index, content: .groupReference(groupId: groupId, message: message, topPeers: topPeers, counters: counters), editing: editing, hasActiveRevealControls: false, header: nil, enableContextActions: true, interaction: nodeInteraction), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(account: Account, nodeInteraction: ChatListNodeInteraction, peerGroupId: PeerGroupId?, mode: ChatListNodeMode, entries: [ChatListNodeViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .SearchEntry(theme, text):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(theme: theme, placeholder: text, activate: {
                    nodeInteraction.activateSearch()
                }), directionHint: entry.directionHint)
            case let .PeerEntry(index, presentationData, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo, editing, hasActiveRevealControls, inputActivities, isAd):
                switch mode {
                    case .chatList:
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, account: account, peerGroupId: peerGroupId, index: index, content: .peer(message: message, peer: peer, combinedReadState: combinedReadState, notificationSettings: notificationSettings, summaryInfo: summaryInfo, embeddedState: embeddedState, inputActivities: inputActivities, isAd: isAd, ignoreUnreadBadge: false), editing: editing, hasActiveRevealControls: hasActiveRevealControls, header: nil, enableContextActions: true, interaction: nodeInteraction), directionHint: entry.directionHint)
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
                        if filter.contains(.onlyUsers) {
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
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(theme: presentationData.theme, strings: presentationData.strings, sortOrder: presentationData.nameSortOrder, displayOrder: presentationData.nameDisplayOrder, account: account, peerMode: .generalSearch, peer: .peer(peer: itemPeer, chatPeer: chatPeer), status: .none, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { _ in
                            if let chatPeer = chatPeer {
                                nodeInteraction.peerSelected(chatPeer)
                            }
                        }), directionHint: entry.directionHint)
                }
            case let .HoleEntry(_, theme):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(theme: theme), directionHint: entry.directionHint)
            case let .GroupReferenceEntry(index, presentationData, groupId, message, topPeers, counters, editing):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, account: account, peerGroupId: peerGroupId, index: index, content: .groupReference(groupId: groupId, message: message, topPeers: topPeers, counters: counters), editing: editing, hasActiveRevealControls: false, header: nil, enableContextActions: true, interaction: nodeInteraction), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatListNodeViewListTransition(account: Account, nodeInteraction: ChatListNodeInteraction, peerGroupId: PeerGroupId?, mode: ChatListNodeMode, transition: ChatListNodeViewTransition) -> ChatListNodeListViewTransition {
    return ChatListNodeListViewTransition(chatListView: transition.chatListView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(account: account, nodeInteraction: nodeInteraction, peerGroupId: peerGroupId, mode: mode, entries: transition.insertEntries), updateItems: mappedUpdateEntries(account: account, nodeInteraction: nodeInteraction, peerGroupId: peerGroupId, mode: mode, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange)
}

private final class ChatListOpaqueTransactionState {
    let chatListView: ChatListNodeView
    
    init(chatListView: ChatListNodeView) {
        self.chatListView = chatListView
    }
}

enum ChatListSelectionOption {
    case previous(unread: Bool)
    case next(unread: Bool)
}

enum ChatListGlobalScrollOption {
    case none
    case top
    case unread
}

private struct ChatListVisibleUnreadCounts: Equatable {
    var raw: Int32 = 0
    var filtered: Int32 = 0
}

enum ChatListNodeScrollPosition {
    case auto
    case autoUp
    case top
}

final class ChatListNode: ListView {
    private let controlsHistoryPreload: Bool
    private let account: Account
    private let mode: ChatListNodeMode
    
    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    var peerSelected: ((PeerId, Bool) -> Void)?
    var groupSelected: ((PeerGroupId) -> Void)?
    var activateSearch: (() -> Void)?
    var deletePeerChat: ((PeerId) -> Void)?
    var updatePeerGrouping: ((PeerId, Bool) -> Void)?
    var presentAlert: ((String) -> Void)?
    
    private var theme: PresentationTheme
    
    private let viewProcessingQueue = Queue()
    private var chatListView: ChatListNodeView?
    private var interaction: ChatListNodeInteraction?
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedTransition: (ChatListNodeListViewTransition, () -> Void)?
    
    private var currentState: ChatListNodeState
    private let statePromise: ValuePromise<ChatListNodeState>
    
    private var currentLocation: ChatListNodeLocation?
    private let chatListLocation = ValuePromise<ChatListNodeLocation>()
    private let chatListDisposable = MetaDisposable()
    private var activityStatusesDisposable: Disposable?
    
    private let scrollToTopOptionPromise = Promise<ChatListGlobalScrollOption>(.none)
    var scrollToTopOption: Signal<ChatListGlobalScrollOption, NoError> {
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
    
    private let visibleUnreadCounts = ValuePromise<ChatListVisibleUnreadCounts>(ChatListVisibleUnreadCounts())
    private var visibleUnreadCountsValue = ChatListVisibleUnreadCounts() {
        didSet {
            if self.visibleUnreadCountsValue != oldValue {
                self.visibleUnreadCounts.set(self.visibleUnreadCountsValue)
            }
        }
    }
    
    var isEmptyUpdated: ((Bool) -> Void)?
    private var wasEmpty: Bool?
    
    init(account: Account, groupId: PeerGroupId?, controlsHistoryPreload: Bool, mode: ChatListNodeMode, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        self.account = account
        self.controlsHistoryPreload = controlsHistoryPreload
        self.mode = mode
        
        self.currentState = ChatListNodeState(presentationData: ChatListPresentationData(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, disableAnimations: disableAnimations), editing: false, peerIdWithRevealedOptions: nil, peerInputActivities: nil)
        self.statePromise = ValuePromise(self.currentState, ignoreRepeated: true)
        
        self.theme = theme
        
        super.init()
        
        let nodeInteraction = ChatListNodeInteraction(activateSearch: { [weak self] in
            if let strongSelf = self, let activateSearch = strongSelf.activateSearch {
                activateSearch()
            }
        }, peerSelected: { [weak self] peer in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(peer.id, true)
            }
        }, messageSelected: { [weak self] message in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(message.id.peerId, true)
            }
        }, groupSelected: { [weak self] groupId in
            if let strongSelf = self, let groupSelected = strongSelf.groupSelected {
                groupSelected(groupId)
            }
        }, setPeerIdWithRevealedOptions: { [weak self] peerId, fromPeerId in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                        return state.withUpdatedPeerIdWithRevealedOptions(peerId)
                    } else {
                        return state
                    }
                }
            }
        }, setItemPinned: { [weak self] itemId, _ in
            let _ = (toggleItemPinned(postbox: account.postbox, itemId: itemId) |> deliverOnMainQueue).start(next: { result in
                if let strongSelf = self {
                    switch result {
                        case .done:
                            break
                        case .limitExceeded:
                            strongSelf.presentAlert?(strongSelf.currentState.presentationData.strings.DialogList_PinLimitError("5").0)
                    }
                }
            })
        }, setPeerMuted: { [weak self] peerId, _ in
            let _ = (togglePeerMuted(account: account, peerId: peerId)
            |> deliverOnMainQueue).start(completed: {
                self?.updateState {
                    return $0.withUpdatedPeerIdWithRevealedOptions(nil)
                }
            })
        }, deletePeer: { [weak self] peerId in
            self?.deletePeerChat?(peerId)
        }, updatePeerGrouping: { [weak self] peerId, group in
            self?.updatePeerGrouping?(peerId, group)
        }, togglePeerMarkedUnread: { [weak self, weak account] peerId, animated in
            guard let account = account else {
                return
            }
            
            if false && animated {
                self?.updateState {
                    return $0.withUpdatedPeerIdWithRevealedOptions(nil)
                }
            }
            
            let _ = (togglePeerUnreadMarkInteractively(postbox: account.postbox, viewTracker: account.viewTracker, peerId: peerId)
            |> deliverOnMainQueue).start(completed: {
                if true || animated {
                    self?.updateState {
                        return $0.withUpdatedPeerIdWithRevealedOptions(nil)
                    }
                }
            })
        })
        
        let viewProcessingQueue = self.viewProcessingQueue
        
        let chastListViewUpdate = self.chatListLocation.get()
            |> distinctUntilChanged
            |> mapToSignal { location in
                return chatListViewForLocation(groupId: groupId, location: location, account: account)
            }
        
        let previousView = Atomic<ChatListNodeView?>(value: nil)
        
        let savedMessagesPeer: Signal<Peer?, NoError>
        if case let .peers(filter) = mode, filter == [.onlyWriteable] {
            savedMessagesPeer = account.postbox.loadedPeerWithId(account.peerId) |> map(Optional.init)
        } else {
            savedMessagesPeer = .single(nil)
        }
        
        let chatListNodeViewTransition = combineLatest(savedMessagesPeer, chastListViewUpdate, self.statePromise.get()) |> mapToQueue { (savedMessagesPeer, update, state) -> Signal<ChatListNodeListViewTransition, NoError> in
            let processedView = ChatListNodeView(originalView: update.view, filteredEntries: chatListNodeEntriesForView(update.view, state: state, savedMessagesPeer: savedMessagesPeer, mode: mode))
            let previous = previousView.swap(processedView)
            
            let reason: ChatListNodeViewTransitionReason
            var prepareOnMainQueue = false
            
            var previousWasEmptyOrSingleHole = false
            if let previous = previous {
                if previous.filteredEntries.count == 1 {
                    if case .HoleEntry = previous.filteredEntries[0] {
                        previousWasEmptyOrSingleHole = true
                    }
                }
            } else {
                previousWasEmptyOrSingleHole = true
            }
            
            var updatedScrollPosition = update.scrollPosition
            
            if previousWasEmptyOrSingleHole {
                reason = .initial
                if previous == nil {
                    prepareOnMainQueue = true
                }
            } else {
                if previous?.originalView === update.view {
                    reason = .interactiveChanges
                    updatedScrollPosition = nil
                } else {
                    switch update.type {
                        case .InitialUnread:
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
            
            return preparedChatListNodeViewTransition(from: previous, to: processedView, reason: reason, disableAnimations: state.presentationData.disableAnimations, account: account, scrollPosition: updatedScrollPosition)
                |> map({ mappedChatListNodeViewListTransition(account: account, nodeInteraction: nodeInteraction, peerGroupId: groupId, mode: mode, transition: $0) })
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
                        strongSelf.currentLocation = location
                        strongSelf.chatListLocation.set(location)
                    }
                    
                    strongSelf.enqueueHistoryPreloadUpdate()
                }
                
                var rawUnreadCount: Int32 = 0
                var filteredUnreadCount: Int32 = 0
                if let range = range.visibleRange {
                    let entryCount = chatListView.filteredEntries.count
                    for i in range.firstIndex ..< range.lastIndex {
                        if i < 0 || i >= entryCount {
                            assertionFailure()
                            continue
                        }
                        switch chatListView.filteredEntries[entryCount - i - 1] {
                            case let .PeerEntry(_, _, _, readState, notificationSettings, _, _, _, _, _, _, _):
                                if let readState = readState {
                                    let count = readState.count
                                    rawUnreadCount += count
                                    if let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                                        filteredUnreadCount += count
                                    }
                                }
                            default:
                                break
                        }
                    }
                }
                var visibleUnreadCountsValue = strongSelf.visibleUnreadCountsValue
                visibleUnreadCountsValue.raw = rawUnreadCount
                visibleUnreadCountsValue.filtered = filteredUnreadCount
                strongSelf.visibleUnreadCountsValue = visibleUnreadCountsValue
            }
        }
        
        self.interaction = nodeInteraction
        
        self.chatListDisposable.set(appliedTransition.start())
        
        let initialLocation: ChatListNodeLocation = .initial(count: 50)
        self.currentLocation = initialLocation
        self.chatListLocation.set(initialLocation)
        
        let postbox = account.postbox
        let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
        let previousActivities = Atomic<ChatListNodePeerInputActivities?>(value: nil)
        self.activityStatusesDisposable = (account.allPeerInputActivities()
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
                    strongSelf.updateState { current in
                        return current.withUpdatedPeerInputActivities(activities)
                    }
                }
            })
        
        self.beganInteractiveDragging = { [weak self] in
            if let strongSelf = self {
                if strongSelf.currentState.peerIdWithRevealedOptions != nil {
                    strongSelf.updateState {
                        return $0.withUpdatedPeerIdWithRevealedOptions(nil)
                    }
                }
            }
        }
        self.reorderItem = { [weak self] fromIndex, toIndex, transactionOpaqueState -> Signal<Bool, NoError> in
            if let strongSelf = self, let filteredEntries = (transactionOpaqueState as? ChatListOpaqueTransactionState)?.chatListView.filteredEntries {
                if fromIndex >= 0 && fromIndex < filteredEntries.count && toIndex >= 0 && toIndex < filteredEntries.count {
                    let fromEntry = filteredEntries[filteredEntries.count - 1 - fromIndex]
                    let toEntry = filteredEntries[filteredEntries.count - 1 - toIndex]
                    
                    var referenceId: PinnedItemId?
                    var beforeAll = false
                    switch toEntry {
                        case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, isAd):
                            if isAd {
                                beforeAll = true
                            } else {
                                referenceId = .peer(index.messageIndex.id.peerId)
                            }
                        case let .GroupReferenceEntry(_, _, groupId, _, _, _, _):
                            referenceId = .group(groupId)
                        case .SearchEntry:
                            beforeAll = true
                        default:
                            break
                    }
                    
                    if let _ = fromEntry.index.pinningIndex {
                        return strongSelf.account.postbox.transaction { transaction -> Bool in
                            var itemIds = transaction.getPinnedItemIds()
                            
                            var itemId: PinnedItemId?
                            switch fromEntry {
                                case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _):
                                    itemId = .peer(index.messageIndex.id.peerId)
                                case let .GroupReferenceEntry(_, _, groupId, _, _, _, _):
                                    itemId = .group(groupId)
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
                                return reorderPinnedItemIds(transaction: transaction, itemIds: itemIds)
                            } else {
                                return false
                            }
                        }
                    }
                }
            }
            return .single(false)
        }
        self.didEndScrolling = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            fixSearchableListNodeScrolling(strongSelf)
        }
        
        self.scrollToTopOptionPromise.set(combineLatest(
            renderedTotalUnreadCount(postbox: account.postbox) |> deliverOnMainQueue,
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
            if let strongSelf = self {
                let atTop: Bool
                switch offset {
                    case .none, .unknown:
                        atTop = false
                    case let .known(value):
                        atTop = value <= 0.0
                }
                strongSelf.scrolledAtTopValue = atTop
            }
        }
    }
    
    deinit {
        self.chatListDisposable.dispose()
        self.activityStatusesDisposable?.dispose()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        if theme !== self.currentState.presentationData.theme || strings !== self.currentState.presentationData.strings || dateTimeFormat != self.currentState.presentationData.dateTimeFormat || disableAnimations != self.currentState.presentationData.disableAnimations {
            self.theme = theme
            if self.keepTopItemOverscrollBackground != nil {
                self.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color:  theme.chatList.pinnedItemBackgroundColor, direction: true)
            }
            
            self.updateState {
                return $0.withUpdatedPresentationData(ChatListPresentationData(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, disableAnimations: disableAnimations))
            }
        }
    }
    
    func updateState(_ f: (ChatListNodeState) -> ChatListNodeState) {
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
                
                if strongSelf.isNodeLoaded {
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
                        if entryCount >= 2 {
                            if case .SearchEntry = transition.chatListView.filteredEntries[entryCount - 1] {
                                if transition.chatListView.filteredEntries[entryCount - 2].index.pinningIndex != nil {
                                    pinnedOverscroll = true
                                }
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
                    if transition.chatListView.filteredEntries.count == 1, case .SearchEntry = transition.chatListView.filteredEntries[0] {
                        isEmpty = true
                    }
                    if strongSelf.wasEmpty != isEmpty {
                        strongSelf.wasEmpty = isEmpty
                    strongSelf.isEmptyUpdated?(isEmpty)
                    }
                    
                    completion()
                }
            }
            
            var options = transition.options
            if options.contains(.AnimateCrossfade) && !self.isDeceleratingAfterTracking {
                options.insert(.PreferSynchronousDrawing)
            }
            
            self.transaction(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, updateOpaqueState: ChatListOpaqueTransactionState(chatListView: transition.chatListView), completion: completion)
        }
    }
    
    func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets) {
        self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueTransition()
        }
    }
    
    func scrollToPosition(_ position: ChatListNodeScrollPosition) {
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
                self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default, directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            } else {
                let location: ChatListNodeLocation = .scroll(index: ChatListIndex.absoluteUpperBound, sourceIndex: ChatListIndex.absoluteLowerBound
                    , scrollPosition: .top(0.0), animated: true)
                self.currentLocation = location
                self.chatListLocation.set(location)
            }
        } else {
            let location: ChatListNodeLocation = .scroll(index: ChatListIndex.absoluteUpperBound, sourceIndex: ChatListIndex.absoluteLowerBound
                , scrollPosition: .top(0.0), animated: true)
            self.currentLocation = location
            self.chatListLocation.set(location)
        }
    }
    
    private func relativeUnreadChatListIndex(position: ChatListRelativePosition) -> Signal<ChatListIndex?, NoError> {
        return self.account.postbox.transaction { transaction -> ChatListIndex? in
            var filter = true
            if let inAppNotificationSettings = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.inAppNotificationSettings) as? InAppNotificationSettings {
                switch inAppNotificationSettings.totalUnreadCountDisplayStyle {
                case .raw:
                    filter = false
                case .filtered:
                    filter = true
                }
            }
            return transaction.getRelativeUnreadChatListIndex(filtered: filter, position: position)
        }
    }
    
    func scrollToEarliestUnread(earlierThan: ChatListIndex?) {
        let _ = (relativeUnreadChatListIndex(position: .earlier(than: earlierThan)) |> deliverOnMainQueue).start(next: { [weak self] index in
            guard let strongSelf = self else {
                return
            }
            
            if let index = index {
                let location: ChatListNodeLocation = .scroll(index: index, sourceIndex: self?.currentlyVisibleLatestChatListIndex() ?? ChatListIndex.absoluteUpperBound
                    , scrollPosition: .center(.top), animated: true)
                strongSelf.currentLocation = location
                strongSelf.chatListLocation.set(location)
            } else {
                let location: ChatListNodeLocation = .scroll(index: ChatListIndex.absoluteUpperBound, sourceIndex: ChatListIndex.absoluteLowerBound
                    , scrollPosition: .top(0.0), animated: true)
                strongSelf.currentLocation = location
                strongSelf.chatListLocation.set(location)
            }
        })
    }
    
    func selectChat(_ option: ChatListSelectionOption) {
        guard let interaction = self.interaction else {
            return
        }
        
        guard let chatListView = (self.opaqueTransactionState as? ChatListOpaqueTransactionState)?.chatListView else {
            return
        }
        
        guard let range = self.displayedItemRange.loadedRange else {
            return
        }
        
        if interaction.highlightedChatLocation == nil {
            let location: ChatListNodeLocation = .scroll(index: ChatListIndex.absoluteUpperBound, sourceIndex: ChatListIndex.absoluteLowerBound
                , scrollPosition: .top(0.0), animated: true)
            self.currentLocation = location
            self.chatListLocation.set(location)
            //interaction.highlightedChatLocation = ChatListHighlightedLocation(location: .peer(0), progress: 1.0)
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
                case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _):
                    if interaction.highlightedChatLocation?.location == ChatLocation.peer(peer.peerId) {
                        current = (index, peer.peerId, entryCount - i - 1)
                        break outer
                    }
                default:
                    break
            }
        }
        
        if let current = current {
            switch option {
                case .previous(unread: true), .next(unread: true):
                    let position: ChatListRelativePosition
                    if case .previous = option {
                        position = .earlier(than: current.0)
                    } else {
                        position = .later(than: current.0)
                    }
                    let _ = (relativeUnreadChatListIndex(position: position) |> deliverOnMainQueue).start(next: { [weak self] index in
                        guard let strongSelf = self, let index = index else {
                            return
                        }

                        let location: ChatListNodeLocation = .scroll(index: index, sourceIndex: self?.currentlyVisibleLatestChatListIndex() ?? ChatListIndex.absoluteUpperBound
                            , scrollPosition: .center(.top), animated: true)
                        strongSelf.currentLocation = location
                        strongSelf.chatListLocation.set(location)
                        strongSelf.peerSelected?(index.messageIndex.id.peerId, false)
                    })
                    break
                case .previous(unread: false), .next(unread: false):
                    if current.2 != entryCount - range.firstIndex - 1 && entryCount > 2 {
                        if case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _) = chatListView.filteredEntries[current.2 - 1] {
                            next = (index, peer.peerId)
                        }
                    }
                    if current.2 != entryCount - range.lastIndex - 2 && entryCount > 2 {
                        if case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _) = chatListView.filteredEntries[current.2 + 1] {
                            previous = (index, peer.peerId)
                        }
                    }
                    
                    var target: (ChatListIndex, PeerId)? = nil
                    switch option {
                        case .previous:
                            target = previous
                        case .next:
                            target = next
                    }
                    
                    if let target = target {
                        let location: ChatListNodeLocation = .scroll(index: target.0, sourceIndex: ChatListIndex.absoluteLowerBound
                            , scrollPosition: .center(.top), animated: true)
                        self.currentLocation = location
                        self.chatListLocation.set(location)
                        self.peerSelected?(target.1, false)
                    }
                    break
            }
        }
    }
    
    private func enqueueHistoryPreloadUpdate() {
        
    }
    
    func updateSelectedChatLocation(_ chatLocation: ChatLocation?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let interaction = self.interaction else {
            return
        }
        
        if let chatLocation = chatLocation {
            interaction.highlightedChatLocation = ChatListHighlightedLocation(location: chatLocation, progress: 1.0)
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
                    case let .PeerEntry(index, _, _, readState, notificationSettings, _, _, _, _, _, _, _):
                        return index
                    default:
                        break
                }
            }
        }
        return nil
    }
}
