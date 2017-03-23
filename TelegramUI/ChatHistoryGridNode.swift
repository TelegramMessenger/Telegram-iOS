import Foundation
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore

struct ChatHistoryGridViewTransition {
    let historyView: ChatHistoryView
    let deleteItems: [Int]
    let insertItems: [GridNodeInsertItem]
    let updateItems: [GridNodeUpdateItem]
    let scrollToItem: GridNodeScrollToItem?
    let stationaryItemRange: (Int, Int)?
}

private func mappedInsertEntries(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, entries: [ChatHistoryViewTransitionInsertEntry]) -> [GridNodeInsertItem] {
    return entries.map { entry -> GridNodeInsertItem in
        switch entry.entry {
            case let .MessageEntry(message, _):
                return GridNodeInsertItem(index: entry.index, item: GridMessageItem(account: account, message: message, controllerInteraction: controllerInteraction), previousIndex: entry.previousIndex)
            case .HoleEntry:
                return GridNodeInsertItem(index: entry.index, item: GridHoleItem(), previousIndex: entry.previousIndex)
            case .UnreadEntry:
                assertionFailure()
                return GridNodeInsertItem(index: entry.index, item: GridHoleItem(), previousIndex: entry.previousIndex)
            case .ChatInfoEntry, .EmptyChatInfoEntry:
                assertionFailure()
                return GridNodeInsertItem(index: entry.index, item: GridHoleItem(), previousIndex: entry.previousIndex)
        }
    }
}

private func mappedUpdateEntries(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, entries: [ChatHistoryViewTransitionUpdateEntry]) -> [GridNodeUpdateItem] {
    return entries.map { entry -> GridNodeUpdateItem in
        switch entry.entry {
            case let .MessageEntry(message, _):
                return GridNodeUpdateItem(index: entry.index, item: GridMessageItem(account: account, message: message, controllerInteraction: controllerInteraction))
            case .HoleEntry:
                return GridNodeUpdateItem(index: entry.index, item: GridHoleItem())
            case .UnreadEntry:
                assertionFailure()
                return GridNodeUpdateItem(index: entry.index, item: GridHoleItem())
            case .ChatInfoEntry, .EmptyChatInfoEntry:
                assertionFailure()
                return GridNodeUpdateItem(index: entry.index, item: GridHoleItem())
        }
    }
}

private func mappedChatHistoryViewListTransition(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, transition: ChatHistoryViewTransition) -> ChatHistoryGridViewTransition {
    var mappedScrollToItem: GridNodeScrollToItem?
    if let scrollToItem = transition.scrollToItem {
        let mappedPosition: GridNodeScrollToItemPosition
        switch scrollToItem.position {
            case .Top:
                mappedPosition = .top
            case .Center:
                mappedPosition = .center
            case .Bottom:
                mappedPosition = .bottom
        }
        let scrollTransition: ContainedViewLayoutTransition
        if scrollToItem.animated {
            switch scrollToItem.curve {
                case .Default:
                    scrollTransition = .animated(duration: 0.3, curve: .easeInOut)
                case let .Spring(duration):
                    scrollTransition = .animated(duration: duration, curve: .spring)
            }
        } else {
            scrollTransition = .immediate
        }
        let directionHint: GridNodePreviousItemsTransitionDirectionHint
        switch scrollToItem.directionHint {
            case .Up:
                directionHint = .up
            case .Down:
                directionHint = .down
        }
        mappedScrollToItem = GridNodeScrollToItem(index: scrollToItem.index, position: mappedPosition, transition: scrollTransition, directionHint: directionHint, adjustForSection: true)
    }
    
    return ChatHistoryGridViewTransition(historyView: transition.historyView, deleteItems: transition.deleteItems.map { $0.index }, insertItems: mappedInsertEntries(account: account, peerId: peerId, controllerInteraction: controllerInteraction, entries: transition.insertEntries), updateItems: mappedUpdateEntries(account: account, peerId: peerId, controllerInteraction: controllerInteraction, entries: transition.updateEntries), scrollToItem: mappedScrollToItem, stationaryItemRange: transition.stationaryItemRange)
}

private func itemSizeForContainerLayout(size: CGSize) -> CGSize {
    let side = floor(size.width / 4.0)
    return CGSize(width: side, height: side)
}

public final class ChatHistoryGridNode: GridNode, ChatHistoryNode {
    private let account: Account
    private let peerId: PeerId
    private let messageId: MessageId?
    private let tagMask: MessageTags?
    
    private var historyView: ChatHistoryView?
    
    private let historyDisposable = MetaDisposable()
    
    private let messageViewQueue = Queue()
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedHistoryViewTransition: (ChatHistoryGridViewTransition, () -> Void)?
    var layoutActionOnViewTransition: ((ChatHistoryGridViewTransition) -> (ChatHistoryGridViewTransition, ListViewUpdateSizeAndInsets?))?
    
    public let historyState = ValuePromise<ChatHistoryNodeHistoryState>()
    private var currentHistoryState: ChatHistoryNodeHistoryState?
    
    public var preloadPages: Bool = true {
        didSet {
            if self.preloadPages != oldValue {
                
            }
        }
    }
    
    private let _chatHistoryLocation = Promise<ChatHistoryLocation>()
    private var chatHistoryLocation: Signal<ChatHistoryLocation, NoError> {
        return self._chatHistoryLocation.get()
    }
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    public init(account: Account, peerId: PeerId, messageId: MessageId?, tagMask: MessageTags?, controllerInteraction: ChatControllerInteraction) {
        self.account = account
        self.peerId = peerId
        self.messageId = messageId
        self.tagMask = tagMask
        
        super.init()
        
        //self.preloadPages = false
        
        let messageViewQueue = self.messageViewQueue
        
        let historyViewUpdate = self.chatHistoryLocation
            |> distinctUntilChanged
            |> mapToSignal { location in
                return chatHistoryViewForLocation(location, account: account, peerId: peerId, fixedCombinedReadState: nil, tagMask: tagMask, additionalData: [])
        }
        
        let previousView = Atomic<ChatHistoryView?>(value: nil)
        
        let historyViewTransition = historyViewUpdate |> mapToQueue { [weak self] update -> Signal<ChatHistoryGridViewTransition, NoError> in
            switch update {
                case .Loading:
                    Queue.mainQueue().async { [weak self] in
                        if let strongSelf = self {
                            let historyState: ChatHistoryNodeHistoryState = .loading
                            if strongSelf.currentHistoryState != historyState {
                                strongSelf.currentHistoryState = historyState
                                strongSelf.historyState.set(historyState)
                            }
                        }
                    }
                    return .complete()
                case let .HistoryView(view, type, scrollPosition, _):
                    let reason: ChatHistoryViewTransitionReason
                    var prepareOnMainQueue = false
                    switch type {
                        case let .Initial(fadeIn):
                            reason = ChatHistoryViewTransitionReason.Initial(fadeIn: fadeIn)
                            prepareOnMainQueue = !fadeIn
                        case let .Generic(genericType):
                            switch genericType {
                                case .InitialUnread:
                                    reason = ChatHistoryViewTransitionReason.Initial(fadeIn: false)
                                case .Generic:
                                    reason = ChatHistoryViewTransitionReason.InteractiveChanges
                                case .UpdateVisible:
                                    reason = ChatHistoryViewTransitionReason.Reload
                                case let .FillHole(insertions, deletions):
                                    reason = ChatHistoryViewTransitionReason.HoleChanges(filledHoleDirections: insertions, removeHoleDirections: deletions)
                            }
                    }
                    
                    let processedView = ChatHistoryView(originalView: view, filteredEntries: chatHistoryEntriesForView(view, includeUnreadEntry: false, includeChatInfoEntry: false))
                    let previous = previousView.swap(processedView)
                    
                    return preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, account: account, peerId: peerId, controllerInteraction: controllerInteraction, scrollPosition: scrollPosition, initialData: nil, keyboardButtonsMessage: nil, cachedData: nil) |> map({ mappedChatHistoryViewListTransition(account: account, peerId: peerId, controllerInteraction: controllerInteraction, transition: $0) }) |> runOn(prepareOnMainQueue ? Queue.mainQueue() : messageViewQueue)
            }
        }
        
        let appliedTransition = historyViewTransition |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            if let strongSelf = self {
                return strongSelf.enqueueHistoryViewTransition(transition)
            }
            return .complete()
        }
        
        self.historyDisposable.set(appliedTransition.start())
        
        if let messageId = messageId {
            self._chatHistoryLocation.set(.single(ChatHistoryLocation.InitialSearch(messageId: messageId, count: 100)))
        } else {
            self._chatHistoryLocation.set(.single(ChatHistoryLocation.Initial(count: 100)))
        }
        
        /*self.displayedItemRangeChanged = { [weak self] displayedRange in
            if let strongSelf = self {
                /*if let transactionTag = strongSelf.listViewTransactionTag {
                 strongSelf.messageViewQueue.dispatch {
                 if transactionTag == strongSelf.historyViewTransactionTag {
                 if let range = range, historyView = strongSelf.historyView, firstEntry = historyView.filteredEntries.first, lastEntry = historyView.filteredEntries.last {
                 if range.firstIndex < 5 && historyView.originalView.laterId != nil {
                 strongSelf._chatHistoryLocation.set(.single(ChatHistoryLocation.Navigation(index: lastEntry.index, anchorIndex: historyView.originalView.anchorIndex)))
                 } else if range.lastIndex >= historyView.filteredEntries.count - 5 && historyView.originalView.earlierId != nil {
                 strongSelf._chatHistoryLocation.set(.single(ChatHistoryLocation.Navigation(index: firstEntry.index, anchorIndex: historyView.originalView.anchorIndex)))
                 } else {
                 //strongSelf.account.postbox.updateMessageHistoryViewVisibleRange(messageView.id, earliestVisibleIndex: viewEntries[viewEntries.count - 1 - range.lastIndex].index, latestVisibleIndex: viewEntries[viewEntries.count - 1 - range.firstIndex].index)
                 }
                 }
                 }
                 }
                 }*/
                
                if let visible = displayedRange.visibleRange, let historyView = strongSelf.historyView {
                    if let messageId = maxIncomingMessageIdForEntries(historyView.filteredEntries, indexRange: (historyView.filteredEntries.count - 1 - visible.lastIndex, historyView.filteredEntries.count - 1 - visible.firstIndex)) {
                        strongSelf.updateMaxVisibleReadIncomingMessageId(messageId)
                    }
                }
            }
        }*/
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.historyDisposable.dispose()
    }
    
    public func scrollToStartOfHistory() {
        self._chatHistoryLocation.set(.single(ChatHistoryLocation.Scroll(index: MessageIndex.lowerBound(peerId: self.peerId), anchorIndex: MessageIndex.lowerBound(peerId: self.peerId), sourceIndex: MessageIndex.upperBound(peerId: self.peerId), scrollPosition: .Bottom, animated: true)))
    }
    
    public func scrollToEndOfHistory() {
        self._chatHistoryLocation.set(.single(ChatHistoryLocation.Scroll(index: MessageIndex.upperBound(peerId: self.peerId), anchorIndex: MessageIndex.upperBound(peerId: self.peerId), sourceIndex: MessageIndex.lowerBound(peerId: self.peerId), scrollPosition: .Top, animated: true)))
    }
    
    public func scrollToMessage(from fromIndex: MessageIndex, to toIndex: MessageIndex) {
        self._chatHistoryLocation.set(.single(ChatHistoryLocation.Scroll(index: toIndex, anchorIndex: toIndex, sourceIndex: fromIndex, scrollPosition: .Center(.Bottom), animated: true)))
    }
    
    public func messageInCurrentHistoryView(_ id: MessageId) -> Message? {
        if let historyView = self.historyView {
            var galleryMedia: Media?
            for case let .MessageEntry(message, _) in historyView.filteredEntries where message.id == id {
                return message
            }
        }
        return nil
    }
    
    private func enqueueHistoryViewTransition(_ transition: ChatHistoryGridViewTransition) -> Signal<Void, NoError> {
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                if let _ = strongSelf.enqueuedHistoryViewTransition {
                    preconditionFailure()
                }
                
                strongSelf.enqueuedHistoryViewTransition = (transition, {
                    subscriber.putCompletion()
                })
                
                if strongSelf.isNodeLoaded {
                    strongSelf.dequeueHistoryViewTransition()
                } else {
                    let historyState: ChatHistoryNodeHistoryState = .loaded(isEmpty: transition.historyView.originalView.entries.isEmpty)
                    if strongSelf.currentHistoryState != historyState {
                        strongSelf.currentHistoryState = historyState
                        strongSelf.historyState.set(historyState)
                    }
                }
            } else {
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        } |> runOn(Queue.mainQueue())
    }
    
    private func dequeueHistoryViewTransition() {
        if let (transition, completion) = self.enqueuedHistoryViewTransition {
            self.enqueuedHistoryViewTransition = nil
            
            let completion: (GridNodeDisplayedItemRange) -> Void = { [weak self] visibleRange in
                if let strongSelf = self {
                    strongSelf.historyView = transition.historyView
                    
                    if let range = visibleRange.loadedRange {
                        strongSelf.account.postbox.updateMessageHistoryViewVisibleRange(transition.historyView.originalView.id, earliestVisibleIndex: transition.historyView.filteredEntries[transition.historyView.filteredEntries.count - 1 - range.upperBound].index, latestVisibleIndex: transition.historyView.filteredEntries[transition.historyView.filteredEntries.count - 1 - range.lowerBound].index)
                    }
                    
                    let historyState: ChatHistoryNodeHistoryState = .loaded(isEmpty: transition.historyView.originalView.entries.isEmpty)
                    if strongSelf.currentHistoryState != historyState {
                        strongSelf.currentHistoryState = historyState
                        strongSelf.historyState.set(historyState)
                    }
                    
                    completion()
                }
            }
            
            if let layoutActionOnViewTransition = self.layoutActionOnViewTransition {
                self.layoutActionOnViewTransition = nil
                let (mappedTransition, updateSizeAndInsets) = layoutActionOnViewTransition(transition)
                
                var updateLayout: GridNodeUpdateLayout?
                if let updateSizeAndInsets = updateSizeAndInsets {
                    updateLayout = GridNodeUpdateLayout(layout: GridNodeLayout(size: updateSizeAndInsets.size, insets: updateSizeAndInsets.insets, preloadSize: 400.0, itemSize: CGSize(width: 200.0, height: 200.0)), transition: .immediate)
                }
                
                self.transaction(GridNodeTransaction(deleteItems: mappedTransition.deleteItems, insertItems: mappedTransition.insertItems, updateItems: mappedTransition.updateItems, scrollToItem: mappedTransition.scrollToItem, updateLayout: updateLayout, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: completion)
            } else {
                self.transaction(GridNodeTransaction(deleteItems: transition.deleteItems, insertItems: transition.insertItems, updateItems: transition.updateItems, scrollToItem: transition.scrollToItem, updateLayout: nil, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: completion)
            }
        }
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets) {
        self.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: updateSizeAndInsets.size, insets: updateSizeAndInsets.insets, preloadSize: 400.0, itemSize: itemSizeForContainerLayout(size: updateSizeAndInsets.size)), transition: .immediate), stationaryItems: .none,updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueHistoryViewTransition()
        }
    }
    
    public func disconnect() {
        self.historyDisposable.set(nil)
    }
}
