import Foundation
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore

public enum ChatHistoryListMode {
    case bubbles
    case list
}

enum ChatHistoryViewScrollPosition {
    case Unread(index: MessageIndex)
    case Index(index: MessageIndex, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool)
}

enum ChatHistoryViewUpdateType {
    case Initial(fadeIn: Bool)
    case Generic(type: ViewUpdateType)
}

enum ChatHistoryViewUpdate {
    case Loading
    case HistoryView(view: MessageHistoryView, type: ChatHistoryViewUpdateType, scrollPosition: ChatHistoryViewScrollPosition?)
}

struct ChatHistoryView {
    let originalView: MessageHistoryView
    let filteredEntries: [ChatHistoryEntry]
}

enum ChatHistoryViewTransitionReason {
    case Initial(fadeIn: Bool)
    case InteractiveChanges
    case HoleChanges(filledHoleDirections: [MessageIndex: HoleFillDirection], removeHoleDirections: [MessageIndex: HoleFillDirection])
    case Reload
}

struct ChatHistoryViewTransitionInsertEntry {
    let index: Int
    let previousIndex: Int?
    let entry: ChatHistoryEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct ChatHistoryViewTransitionUpdateEntry {
    let index: Int
    let previousIndex: Int
    let entry: ChatHistoryEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct ChatHistoryViewTransition {
    let historyView: ChatHistoryView
    let deleteItems: [ListViewDeleteItem]
    let insertEntries: [ChatHistoryViewTransitionInsertEntry]
    let updateEntries: [ChatHistoryViewTransitionUpdateEntry]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
}

struct ChatHistoryListViewTransition {
    let historyView: ChatHistoryView
    let deleteItems: [ListViewDeleteItem]
    let insertItems: [ListViewInsertItem]
    let updateItems: [ListViewUpdateItem]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
}

private func maxIncomingMessageIdForEntries(_ entries: [ChatHistoryEntry], indexRange: (Int, Int)) -> MessageId? {
    for i in (indexRange.0 ... indexRange.1).reversed() {
        if case let .MessageEntry(message, _) = entries[i], message.flags.contains(.Incoming) {
            return message.id
        }
    }
    return nil
}

private func mappedInsertEntries(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, entries: [ChatHistoryViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case let .MessageEntry(message, read):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message, read: read)
                    case .list:
                        item = ListMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case .HoleEntry:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatHoleItem(), directionHint: entry.directionHint)
            case .UnreadEntry:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, entries: [ChatHistoryViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .MessageEntry(message, read):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message, read: read)
                    case .list:
                        item = ListMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case .HoleEntry:
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatHoleItem(), directionHint: entry.directionHint)
            case .UnreadEntry:
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatHistoryViewListTransition(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, transition: ChatHistoryViewTransition) -> ChatHistoryListViewTransition {
    return ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, entries: transition.insertEntries), updateItems: mappedUpdateEntries(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange)
}

public final class ChatHistoryListNode: ListView, ChatHistoryNode {
    private let account: Account
    private let peerId: PeerId
    private let messageId: MessageId?
    private let controllerInteraction: ChatControllerInteraction
    private let mode: ChatHistoryListMode
    
    private var historyView: ChatHistoryView?
    
    private let historyDisposable = MetaDisposable()
    private let readHistoryDisposable = MetaDisposable()
    
    private let messageViewQueue = Queue()
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedHistoryViewTransition: (ChatHistoryListViewTransition, () -> Void)?
    var layoutActionOnViewTransition: ((ChatHistoryListViewTransition) -> (ChatHistoryListViewTransition, ListViewUpdateSizeAndInsets?))?
    
    public let historyReady = Promise<Bool>()
    private var didSetHistoryReady = false
    
    private let maxVisibleIncomingMessageId = Promise<MessageId>()
    let canReadHistory = Promise<Bool>()
    
    private let _chatHistoryLocation = Promise<ChatHistoryLocation>()
    private var chatHistoryLocation: Signal<ChatHistoryLocation, NoError> {
        return self._chatHistoryLocation.get()
    }
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    public init(account: Account, peerId: PeerId, tagMask: MessageTags?, messageId: MessageId?, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode = .bubbles) {
        self.account = account
        self.peerId = peerId
        self.messageId = messageId
        self.controllerInteraction = controllerInteraction
        self.mode = mode
        
        super.init()
        
        self.preloadPages = false
        switch self.mode {
            case .bubbles:
                self.transform = CATransform3DMakeRotation(CGFloat(M_PI), 0.0, 0.0, 1.0)
            case .list:
                break
        }
        
        let messageViewQueue = self.messageViewQueue
        
        let fixedCombinedReadState = Atomic<CombinedPeerReadState?>(value: nil)
        
        let historyViewUpdate = self.chatHistoryLocation
            |> distinctUntilChanged
            |> mapToSignal { location in
                return chatHistoryViewForLocation(location, account: account, peerId: peerId, fixedCombinedReadState: fixedCombinedReadState.with { $0 }, tagMask: tagMask) |> beforeNext { viewUpdate in
                    switch viewUpdate {
                        case let .HistoryView(view, _, _):
                            let _ = fixedCombinedReadState.swap(view.combinedReadState)
                        default:
                            break
                    }
                }
        }
        
        let previousView = Atomic<ChatHistoryView?>(value: nil)
        
        let historyViewTransition = historyViewUpdate |> mapToQueue { [weak self] update -> Signal<ChatHistoryListViewTransition, NoError> in
            switch update {
            case .Loading:
                Queue.mainQueue().async { [weak self] in
                    if let strongSelf = self {
                        if !strongSelf.didSetHistoryReady {
                            strongSelf.didSetHistoryReady = true
                            strongSelf.historyReady.set(.single(true))
                        }
                    }
                }
                return .complete()
            case let .HistoryView(view, type, scrollPosition):
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
                
                let processedView = ChatHistoryView(originalView: view, filteredEntries: chatHistoryEntriesForView(view, includeUnreadEntry: mode == .bubbles))
                let previous = previousView.swap(processedView)
                
                return preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, account: account, peerId: peerId, controllerInteraction: controllerInteraction, scrollPosition: scrollPosition) |> map({ mappedChatHistoryViewListTransition(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, transition: $0) }) |> runOn(prepareOnMainQueue ? Queue.mainQueue() : messageViewQueue)
            }
        }
        
        let appliedTransition = historyViewTransition |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            if let strongSelf = self {
                return strongSelf.enqueueHistoryViewTransition(transition)
            }
            return .complete()
        }
        
        self.historyDisposable.set(appliedTransition.start())
        
        let previousMaxIncomingMessageId = Atomic<MessageId?>(value: nil)
        let readHistory = combineLatest(self.maxVisibleIncomingMessageId.get(), self.canReadHistory.get())
            |> map { messageId, canRead in
                if canRead {
                    var apply = false
                    let _ = previousMaxIncomingMessageId.modify { previousId in
                        if previousId == nil || previousId! < messageId {
                            apply = true
                            return messageId
                        } else {
                            return previousId
                        }
                    }
                    if apply {
                        let _ = account.postbox.modify({ modifier in
                            modifier.applyInteractiveReadMaxId(messageId)
                        }).start()
                    }
                }
        }
        
        self.readHistoryDisposable.set(readHistory.start())
        
        if let messageId = messageId {
            self._chatHistoryLocation.set(.single(ChatHistoryLocation.InitialSearch(messageId: messageId, count: 60)))
        } else {
            self._chatHistoryLocation.set(.single(ChatHistoryLocation.Initial(count: 60)))
        }
        
        self.displayedItemRangeChanged = { [weak self] displayedRange in
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
        }
    }
    
    deinit {
        self.historyDisposable.dispose()
        self.readHistoryDisposable.dispose()
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
    
    private func updateMaxVisibleReadIncomingMessageId(_ id: MessageId) {
        self.maxVisibleIncomingMessageId.set(.single(id))
    }
    
    private func enqueueHistoryViewTransition(_ transition: ChatHistoryListViewTransition) -> Signal<Void, NoError> {
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
                    if !strongSelf.didSetHistoryReady {
                        strongSelf.didSetHistoryReady = true
                        strongSelf.historyReady.set(.single(true))
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
            
            let completion: (ListViewDisplayedItemRange) -> Void = { [weak self] visibleRange in
                if let strongSelf = self {
                    strongSelf.historyView = transition.historyView
                    
                    if let range = visibleRange.loadedRange {
                        strongSelf.account.postbox.updateMessageHistoryViewVisibleRange(transition.historyView.originalView.id, earliestVisibleIndex: transition.historyView.filteredEntries[transition.historyView.filteredEntries.count - 1 - range.lastIndex].index, latestVisibleIndex: transition.historyView.filteredEntries[transition.historyView.filteredEntries.count - 1 - range.firstIndex].index)
                        
                        if let visible = visibleRange.visibleRange {
                            if let messageId = maxIncomingMessageIdForEntries(transition.historyView.filteredEntries, indexRange: (transition.historyView.filteredEntries.count - 1 - visible.lastIndex, transition.historyView.filteredEntries.count - 1 - visible.firstIndex)) {
                                strongSelf.updateMaxVisibleReadIncomingMessageId(messageId)
                            }
                        }
                    }
                    
                    if !strongSelf.didSetHistoryReady {
                        strongSelf.didSetHistoryReady = true
                        strongSelf.historyReady.set(.single(true))
                    }
                    
                    completion()
                }
            }
            
            if let layoutActionOnViewTransition = self.layoutActionOnViewTransition {
                self.layoutActionOnViewTransition = nil
                let (mappedTransition, updateSizeAndInsets) = layoutActionOnViewTransition(transition)
                
                self.deleteAndInsertItems(deleteIndices: mappedTransition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: mappedTransition.options, scrollToItem: mappedTransition.scrollToItem, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: mappedTransition.stationaryItemRange, completion: completion)
            } else {
                self.deleteAndInsertItems(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, completion: completion)
            }
        }
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets) {
        self.deleteAndInsertItems(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, completion: { _ in })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueHistoryViewTransition()
        }
    }
}
