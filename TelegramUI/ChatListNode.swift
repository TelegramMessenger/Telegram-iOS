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
    let peerSelected: (PeerId) -> Void
    
    init(activateSearch: @escaping () -> Void, peerSelected: @escaping (PeerId) -> Void) {
        self.activateSearch = activateSearch
        self.peerSelected = peerSelected
    }
}

private func mappedInsertEntries(account: Account, nodeInteraction: ChatListNodeInteraction, mode: ChatListNodeMode, entries: [ChatListNodeViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case .SearchEntry:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(placeholder: "Search for messages or users", activate: {
                    nodeInteraction.activateSearch()
                }), directionHint: entry.directionHint)
            case let .MessageEntry(message, combinedReadState, notificationSettings):
                switch mode {
                    case .chatList:
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(account: account, message: message, combinedReadState: combinedReadState, notificationSettings: notificationSettings, action: { _ in
                            nodeInteraction.peerSelected(message.id.peerId)
                        }), directionHint: entry.directionHint)
                    case .peers:
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item:  ContactsPeerItem(account: account, peer: message.peers[message.id.peerId], presence: nil, index: nil, action: { _ in
                            nodeInteraction.peerSelected(message.id.peerId)
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
            case let .MessageEntry(message, combinedReadState, notificationSettings):
                switch mode {
                    case .chatList:
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(account: account, message: message, combinedReadState: combinedReadState, notificationSettings: notificationSettings, action: { _ in
                            nodeInteraction.peerSelected(message.id.peerId)
                        }), directionHint: entry.directionHint)
                    case .peers:
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(account: account, peer: message.peers[message.id.peerId], presence: nil, index: nil, action: { _ in
                            nodeInteraction.peerSelected(message.id.peerId)
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
    
    private var currentLocation: ChatListNodeLocation?
    private let chatListLocation = ValuePromise<ChatListNodeLocation>()
    private let chatListDisposable = MetaDisposable()
    
    init(account: Account, mode: ChatListNodeMode) {
        super.init()
        
        let nodeInteraction = ChatListNodeInteraction(activateSearch: { [weak self] in
            if let strongSelf = self, let activateSearch = strongSelf.activateSearch {
                activateSearch()
            }
        }, peerSelected: { [weak self] peerId in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(peerId)
            }
        })
        
        let viewProcessingQueue = self.viewProcessingQueue
        
        let chastListViewUpdate = self.chatListLocation.get()
            |> distinctUntilChanged
            |> mapToSignal { location in
                return chatListViewForLocation(location, account: account)
            }
        
        let previousView = Atomic<ChatListNodeView?>(value: nil)
        
        let chatListNodeViewTransition = chastListViewUpdate |> mapToQueue { [weak self] update -> Signal<ChatListNodeListViewTransition, NoError> in
            let processedView = ChatListNodeView(originalView: update.view, filteredEntries: chatListNodeEntriesForView(update.view))
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
            let location: ChatListNodeLocation = .scroll(index: MessageIndex.absoluteUpperBound(), sourceIndex: MessageIndex.absoluteLowerBound(), scrollPosition: .Top, animated: true)
            self.currentLocation = location
            self.chatListLocation.set(location)
        }
    }
}
