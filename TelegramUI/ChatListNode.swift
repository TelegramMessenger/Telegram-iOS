import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox

enum ChatListNodeMode {
    case chatList
    case peers
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
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let setPeerPinned: (PeerId, Bool) -> Void
    let setPeerMuted: (PeerId, Bool) -> Void
    let deletePeer: (PeerId) -> Void
    
    init(activateSearch: @escaping () -> Void, peerSelected: @escaping (Peer) -> Void, messageSelected: @escaping (Message) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, setPeerPinned: @escaping (PeerId, Bool) -> Void, setPeerMuted: @escaping (PeerId, Bool) -> Void, deletePeer: @escaping (PeerId) -> Void) {
        self.activateSearch = activateSearch
        self.peerSelected = peerSelected
        self.messageSelected = messageSelected
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.setPeerPinned = setPeerPinned
        self.setPeerMuted = setPeerMuted
        self.deletePeer = deletePeer
    }
}

struct ChatListNodeState: Equatable {
    let editing: Bool
    let peerIdWithRevealedOptions: PeerId?
    
    func withUpdatedEditing(_ editing: Bool) -> ChatListNodeState {
        return ChatListNodeState(editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChatListNodeState {
        return ChatListNodeState(editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions)
    }
    
    static func ==(lhs: ChatListNodeState, rhs: ChatListNodeState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        return true
    }
}

private func mappedInsertEntries(account: Account, nodeInteraction: ChatListNodeInteraction, mode: ChatListNodeMode, entries: [ChatListNodeViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case .SearchEntry:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(placeholder: "Search for messages or users", activate: {
                    nodeInteraction.activateSearch()
                }), directionHint: entry.directionHint)
            case let .PeerEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, editing, hasActiveRevealControls):
                switch mode {
                    case .chatList:
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(account: account, index: index, message: message, peer: peer, combinedReadState: combinedReadState, notificationSettings: notificationSettings, embeddedState: embeddedState, editing: editing, hasActiveRevealControls: hasActiveRevealControls, header: nil, interaction: nodeInteraction), directionHint: entry.directionHint)
                    case .peers:
                        var peer: Peer?
                        var chatPeer: Peer?
                        if let message = message {
                            peer = messageMainPeer(message)
                            chatPeer = message.peers[message.id.peerId]
                        }
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item:  ContactsPeerItem(account: account, peer: peer, chatPeer: chatPeer, status: .none, selection: .none, index: nil, header: nil, action: { _ in
                            if let chatPeer = chatPeer {
                                nodeInteraction.peerSelected(chatPeer)
                            }
                        }), directionHint: entry.directionHint)
                }
            case .HoleEntry:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(), directionHint: entry.directionHint)
            case .Nothing:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListEmptyItem(), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(account: Account, nodeInteraction: ChatListNodeInteraction, mode: ChatListNodeMode, entries: [ChatListNodeViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case .SearchEntry:
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(placeholder: "Search for messages or users", activate: {
                    nodeInteraction.activateSearch()
                }), directionHint: entry.directionHint)
            case let .PeerEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, editing, hasActiveRevealControls):
                switch mode {
                    case .chatList:
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(account: account, index: index, message: message, peer: peer, combinedReadState: combinedReadState, notificationSettings: notificationSettings, embeddedState: embeddedState, editing: editing, hasActiveRevealControls: hasActiveRevealControls, header: nil, interaction: nodeInteraction), directionHint: entry.directionHint)
                    case .peers:
                        var peer: Peer?
                        var chatPeer: Peer?
                        if let message = message {
                            peer = messageMainPeer(message)
                            chatPeer = message.peers[message.id.peerId]
                        }
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(account: account, peer: peer, chatPeer: chatPeer, status: .none, selection: .none, index: nil, header: nil, action: { _ in
                            if let chatPeer = chatPeer {
                                nodeInteraction.peerSelected(chatPeer)
                            }
                        }), directionHint: entry.directionHint)
                }
            case .HoleEntry:
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(), directionHint: entry.directionHint)
            case .Nothing:
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListEmptyItem(), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatListNodeViewListTransition(account: Account, nodeInteraction: ChatListNodeInteraction, mode: ChatListNodeMode, transition: ChatListNodeViewTransition) -> ChatListNodeListViewTransition {
    return ChatListNodeListViewTransition(chatListView: transition.chatListView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(account: account, nodeInteraction: nodeInteraction, mode: mode, entries: transition.insertEntries), updateItems: mappedUpdateEntries(account: account, nodeInteraction: nodeInteraction, mode: mode, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange)
}

private final class ChatListOpaqueTransactionState {
    let chatListView: ChatListNodeView
    
    init(chatListView: ChatListNodeView) {
        self.chatListView = chatListView
    }
}

final class ChatListNode: ListView {
    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    var peerSelected: ((PeerId) -> Void)?
    var activateSearch: (() -> Void)?
    
    private let viewProcessingQueue = Queue()
    private var chatListView: ChatListNodeView?
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedTransition: (ChatListNodeListViewTransition, () -> Void)?
    
    private var currentState = ChatListNodeState(editing: false, peerIdWithRevealedOptions: nil)
    private let statePromise = ValuePromise(ChatListNodeState(editing: false, peerIdWithRevealedOptions: nil), ignoreRepeated: true)
    
    private var currentLocation: ChatListNodeLocation?
    private let chatListLocation = ValuePromise<ChatListNodeLocation>()
    private let chatListDisposable = MetaDisposable()
    
    init(account: Account, mode: ChatListNodeMode) {
        super.init()
        
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
        }, setPeerPinned: { _ in
        }, setPeerMuted: { _ in
        }, deletePeer: { peerId in
            let _ = removePeerChat(postbox: account.postbox, peerId: peerId).start()
        })
        
        let viewProcessingQueue = self.viewProcessingQueue
        
        let chastListViewUpdate = self.chatListLocation.get()
            |> distinctUntilChanged
            |> mapToSignal { location in
                return chatListViewForLocation(location, account: account)
            }
        
        let previousView = Atomic<ChatListNodeView?>(value: nil)
        
        let chatListNodeViewTransition = combineLatest(chastListViewUpdate, self.statePromise.get()) |> mapToQueue { (update, state) -> Signal<ChatListNodeListViewTransition, NoError> in
            let processedView = ChatListNodeView(originalView: update.view, filteredEntries: chatListNodeEntriesForView(update.view, state: state))
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
            
            if previousWasEmptyOrSingleHole {
                reason = .initial
                if previous == nil {
                    prepareOnMainQueue = true
                }
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
            
            return preparedChatListNodeViewTransition(from: previous, to: processedView, reason: reason, account: account, scrollPosition: update.scrollPosition)
                |> map({ mappedChatListNodeViewListTransition(account: account, nodeInteraction: nodeInteraction, mode: mode, transition: $0) })
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
            }
        }
        
        self.chatListDisposable.set(appliedTransition.start())
        
        let initialLocation: ChatListNodeLocation = .initial(count: 50)
        self.currentLocation = initialLocation
        self.chatListLocation.set(initialLocation)
    }
    
    deinit {
        self.chatListDisposable.dispose()
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
                    
                    /*if let range = visibleRange.loadedRange {
                        strongSelf.account.postbox.updateMessageHistoryViewVisibleRange(transition.historyView.originalView.id, earliestVisibleIndex: transition.historyView.filteredEntries[transition.historyView.filteredEntries.count - 1 - range.lastIndex].index, latestVisibleIndex: transition.historyView.filteredEntries[transition.historyView.filteredEntries.count - 1 - range.firstIndex].index)
                        
                        if let visible = visibleRange.visibleRange {
                            if let messageId = maxIncomingMessageIdForEntries(transition.historyView.filteredEntries, indexRange: (transition.historyView.filteredEntries.count - 1 - visible.lastIndex, transition.historyView.filteredEntries.count - 1 - visible.firstIndex)) {
                                strongSelf.updateMaxVisibleReadIncomingMessageId(messageId)
                            }
                        }
                    }*/
                    
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                    
                    completion()
                }
            }
            
            self.transaction(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, updateOpaqueState: ChatListOpaqueTransactionState(chatListView: transition.chatListView), completion: completion)
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
            self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: ListViewScrollToItem(index: 0, position: .Top, animated: true, curve: .Default, directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        } else {
            let location: ChatListNodeLocation = .scroll(index: ChatListIndex.absoluteUpperBound, sourceIndex: ChatListIndex.absoluteLowerBound
                , scrollPosition: .Top, animated: true)
            self.currentLocation = location
            self.chatListLocation.set(location)
        }
    }
}
