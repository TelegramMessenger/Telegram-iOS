import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox

enum ChatListNodeMode {
    case chatList
    case peers(onlyWriteable: Bool)
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
    
    init(activateSearch: @escaping () -> Void, peerSelected: @escaping (Peer) -> Void, messageSelected: @escaping (Message) -> Void, groupSelected: @escaping (PeerGroupId) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, setItemPinned: @escaping (PinnedItemId, Bool) -> Void, setPeerMuted: @escaping (PeerId, Bool) -> Void, deletePeer: @escaping (PeerId) -> Void, updatePeerGrouping: @escaping (PeerId, Bool) -> Void) {
        self.activateSearch = activateSearch
        self.peerSelected = peerSelected
        self.messageSelected = messageSelected
        self.groupSelected = groupSelected
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.setItemPinned = setItemPinned
        self.setPeerMuted = setPeerMuted
        self.deletePeer = deletePeer
        self.updatePeerGrouping = updatePeerGrouping
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
            case let .PeerEntry(index, presentationData, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo, editing, hasActiveRevealControls, inputActivities):
                switch mode {
                    case .chatList:
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, account: account, peerGroupId: peerGroupId, index: index, content: .peer(message: message, peer: peer, combinedReadState: combinedReadState, notificationSettings: notificationSettings, summaryInfo: summaryInfo, embeddedState: embeddedState, inputActivities: inputActivities), editing: editing, hasActiveRevealControls: hasActiveRevealControls, header: nil, interaction: nodeInteraction), directionHint: entry.directionHint)
                    case let .peers(onlyWriteable):
                        let itemPeer = peer.chatMainPeer
                        var chatPeer: Peer?
                        if let peer = peer.peers[peer.peerId] {
                            chatPeer = peer
                        }
                        var enabled = true
                        if onlyWriteable {
                            if let peer = peer.peers[peer.peerId] {
                                enabled = canSendMessagesToPeer(peer)
                            } else {
                                enabled = false
                            }
                        }
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(theme: presentationData.theme, strings: presentationData.strings, account: account, peer: itemPeer, chatPeer: chatPeer, status: .none, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { _ in
                            if let chatPeer = chatPeer {
                                nodeInteraction.peerSelected(chatPeer)
                            }
                        }), directionHint: entry.directionHint)
                }
            case let .HoleEntry(_, theme):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(theme: theme), directionHint: entry.directionHint)
            case let .GroupReferenceEntry(index, presentationData, groupId, message, topPeers, counters, editing):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, account: account, peerGroupId: peerGroupId, index: index, content: .groupReference(groupId: groupId, message: message, topPeers: topPeers, counters: counters), editing: editing, hasActiveRevealControls: false, header: nil, interaction: nodeInteraction), directionHint: entry.directionHint)
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
            case let .PeerEntry(index, presentationData, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo, editing, hasActiveRevealControls, inputActivities):
                switch mode {
                    case .chatList:
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, account: account, peerGroupId: peerGroupId, index: index, content: .peer(message: message, peer: peer, combinedReadState: combinedReadState, notificationSettings: notificationSettings, summaryInfo: summaryInfo, embeddedState: embeddedState, inputActivities: inputActivities), editing: editing, hasActiveRevealControls: hasActiveRevealControls, header: nil, interaction: nodeInteraction), directionHint: entry.directionHint)
                    case let .peers(onlyWriteable):
                        let itemPeer = peer.chatMainPeer
                        var chatPeer: Peer?
                        if let peer = peer.peers[peer.peerId] {
                            chatPeer = peer
                        }
                        var enabled = true
                        if onlyWriteable {
                            if let peer = peer.peers[peer.peerId] {
                                enabled = canSendMessagesToPeer(peer)
                            } else {
                                enabled = false
                            }
                        }
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(theme: presentationData.theme, strings: presentationData.strings, account: account, peer: itemPeer, chatPeer: chatPeer, status: .none, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { _ in
                            if let chatPeer = chatPeer {
                                nodeInteraction.peerSelected(chatPeer)
                            }
                        }), directionHint: entry.directionHint)
                }
            case let .HoleEntry(_, theme):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(theme: theme), directionHint: entry.directionHint)
            case let .GroupReferenceEntry(index, presentationData, groupId, message, topPeers, counters, editing):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(presentationData: presentationData, account: account, peerGroupId: peerGroupId, index: index, content: .groupReference(groupId: groupId, message: message, topPeers: topPeers, counters: counters), editing: editing, hasActiveRevealControls: false, header: nil, interaction: nodeInteraction), directionHint: entry.directionHint)
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

final class ChatListNode: ListView {
    private let controlsHistoryPreload: Bool
    private let account: Account
    private let mode: ChatListNodeMode
    
    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    var peerSelected: ((PeerId) -> Void)?
    var groupSelected: ((PeerGroupId) -> Void)?
    var activateSearch: (() -> Void)?
    var deletePeerChat: ((PeerId) -> Void)?
    var updatePeerGrouping: ((PeerId, Bool) -> Void)?
    var presentAlert: ((String) -> Void)?
    
    private var theme: PresentationTheme
    
    private let viewProcessingQueue = Queue()
    private var chatListView: ChatListNodeView?
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedTransition: (ChatListNodeListViewTransition, () -> Void)?
    
    private var currentState: ChatListNodeState
    private let statePromise: ValuePromise<ChatListNodeState>
    
    private var currentLocation: ChatListNodeLocation?
    private let chatListLocation = ValuePromise<ChatListNodeLocation>()
    private let chatListDisposable = MetaDisposable()
    private var activityStatusesDisposable: Disposable?
    
    init(account: Account, groupId: PeerGroupId?, controlsHistoryPreload: Bool, mode: ChatListNodeMode, theme: PresentationTheme, strings: PresentationStrings, timeFormat: PresentationTimeFormat) {
        self.account = account
        self.controlsHistoryPreload = controlsHistoryPreload
        self.mode = mode
        
        self.currentState = ChatListNodeState(presentationData: ChatListPresentationData(theme: theme, strings: strings, timeFormat: timeFormat), editing: false, peerIdWithRevealedOptions: nil, peerInputActivities: nil)
        self.statePromise = ValuePromise(self.currentState, ignoreRepeated: true)
        
        self.theme = theme
        
        super.init()
        
        self.backgroundColor = theme.chatList.backgroundColor
        
        let nodeInteraction = ChatListNodeInteraction(activateSearch: { [weak self] in
            if let strongSelf = self, let activateSearch = strongSelf.activateSearch {
                activateSearch()
            }
        }, peerSelected: { [weak self] peer in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(peer.id)
            }
        }, messageSelected: { [weak self] message in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(message.id.peerId)
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
            let _ = togglePeerMuted(account: account, peerId: peerId).start(completed: {
                self?.updateState {
                    return $0.withUpdatedPeerIdWithRevealedOptions(nil)
                }
            })
        }, deletePeer: { [weak self] peerId in
            self?.deletePeerChat?(peerId)
        }, updatePeerGrouping: { [weak self] peerId, group in
            self?.updatePeerGrouping?(peerId, group)
        })
        
        let viewProcessingQueue = self.viewProcessingQueue
        
        let chastListViewUpdate = self.chatListLocation.get()
            |> distinctUntilChanged
            |> mapToSignal { location in
                return chatListViewForLocation(groupId: groupId, location: location, account: account)
            }
        
        let previousView = Atomic<ChatListNodeView?>(value: nil)
        
        let savedMessagesPeer: Signal<Peer?, NoError>
        if case .peers(onlyWriteable: true) = mode {
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
            
            return preparedChatListNodeViewTransition(from: previous, to: processedView, reason: reason, account: account, scrollPosition: updatedScrollPosition)
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
            if let strongSelf = self, let range = range.loadedRange, let view = (transactionOpaqueState as? ChatListOpaqueTransactionState)?.chatListView.originalView {
                var location: ChatListNodeLocation?
                if range.firstIndex < 5 && view.laterIndex != nil {
                    location = .navigation(index: view.entries[view.entries.count - 1].index)
                } else if range.firstIndex >= 5 && range.lastIndex >= view.entries.count - 5 && view.earlierIndex != nil {
                    location = .navigation(index: view.entries[0].index)
                }
                
                if let location = location, location != strongSelf.currentLocation {
                    strongSelf.currentLocation = location
                    strongSelf.chatListLocation.set(location)
                }
                
                strongSelf.enqueueHistoryPreloadUpdate()
            }
        }
        
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
                    return postbox.modify { modifier -> [PeerId: [(Peer, PeerInputActivity)]] in
                        var result: [PeerId: [(Peer, PeerInputActivity)]] = [:]
                        var peerCache: [PeerId: Peer] = [:]
                        for (chatPeerId, activities) in activitiesByPeerId {
                            var chatResult: [(Peer, PeerInputActivity)] = []
                            
                            for (peerId, activity) in activities {
                                if let peer = modifier.getPeer(peerId) {
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
    }
    
    deinit {
        self.chatListDisposable.dispose()
        self.activityStatusesDisposable?.dispose()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, timeFormat: PresentationTimeFormat) {
        if theme !== self.currentState.presentationData.theme || strings !== self.currentState.presentationData.strings || timeFormat != self.currentState.presentationData.timeFormat {
            self.theme = theme
            self.backgroundColor = theme.chatList.backgroundColor
            
            if self.keepTopItemOverscrollBackground != nil {
                self.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color:  theme.chatList.pinnedItemBackgroundColor, direction: true)
            }
            
            self.updateState {
                return $0.withUpdatedPresentationData(ChatListPresentationData(theme: theme, strings: strings, timeFormat: timeFormat))
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
                    
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
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
    
    func scrollToLatest() {
        if let view = self.chatListView?.originalView, view.laterIndex == nil {
            self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default, directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        } else {
            let location: ChatListNodeLocation = .scroll(index: ChatListIndex.absoluteUpperBound, sourceIndex: ChatListIndex.absoluteLowerBound
                , scrollPosition: .top(0.0), animated: true)
            self.currentLocation = location
            self.chatListLocation.set(location)
        }
    }
    
    private func enqueueHistoryPreloadUpdate() {
        
    }
}
