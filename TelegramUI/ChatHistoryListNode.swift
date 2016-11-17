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
    case Loading(initialData: InitialMessageHistoryData?)
    case HistoryView(view: MessageHistoryView, type: ChatHistoryViewUpdateType, scrollPosition: ChatHistoryViewScrollPosition?, initialData: InitialMessageHistoryData?)
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
    let initialData: InitialMessageHistoryData?
}

struct ChatHistoryListViewTransition {
    let historyView: ChatHistoryView
    let deleteItems: [ListViewDeleteItem]
    let insertItems: [ListViewInsertItem]
    let updateItems: [ListViewUpdateItem]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
    let initialData: InitialMessageHistoryData?
}

private func maxIncomingMessageIndexForEntries(_ entries: [ChatHistoryEntry], indexRange: (Int, Int)) -> MessageIndex? {
    for i in (indexRange.0 ... indexRange.1).reversed() {
        if case let .MessageEntry(message, _) = entries[i], message.flags.contains(.Incoming) {
            return MessageIndex(message)
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
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatHoleItem(index: entry.entry.index), directionHint: entry.directionHint)
            case .UnreadEntry:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index), directionHint: entry.directionHint)
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
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatHoleItem(index: entry.entry.index), directionHint: entry.directionHint)
            case .UnreadEntry:
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatHistoryViewListTransition(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, transition: ChatHistoryViewTransition) -> ChatHistoryListViewTransition {
    return ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, entries: transition.insertEntries), updateItems: mappedUpdateEntries(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, initialData: transition.initialData)
}

private final class ChatHistoryTransactionOpaqueState {
    let historyView: ChatHistoryView
    
    init(historyView: ChatHistoryView) {
        self.historyView = historyView
    }
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
    
    private let _initialData = Promise<InitialMessageHistoryData?>()
    private var didSetInitialData = false
    public var initialData: Signal<InitialMessageHistoryData?, NoError> {
        return self._initialData.get()
    }
    
    private let maxVisibleIncomingMessageIndex = ValuePromise<MessageIndex>(ignoreRepeated: true)
    let canReadHistory = ValuePromise<Bool>()
    
    private let _chatHistoryLocation = ValuePromise<ChatHistoryLocation>()
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
        
        //self.debugInfo = true
        
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
                        case let .HistoryView(view, _, _, _):
                            let _ = fixedCombinedReadState.swap(view.combinedReadState)
                        default:
                            break
                    }
                }
        }
        
        let previousView = Atomic<ChatHistoryView?>(value: nil)
        
        let historyViewTransition = historyViewUpdate |> mapToQueue { [weak self] update -> Signal<ChatHistoryListViewTransition, NoError> in
            let initialData: InitialMessageHistoryData?
            switch update {
            case let .Loading(data):
                initialData = data
                Queue.mainQueue().async { [weak self] in
                    if let strongSelf = self {
                        if !strongSelf.didSetInitialData {
                            strongSelf.didSetInitialData = true
                            strongSelf._initialData.set(.single(data))
                        }
                        if !strongSelf.didSetHistoryReady {
                            strongSelf.didSetHistoryReady = true
                            strongSelf.historyReady.set(.single(true))
                        }
                    }
                }
                return .complete()
            case let .HistoryView(view, type, scrollPosition, data):
                initialData = data
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
                
                return preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, account: account, peerId: peerId, controllerInteraction: controllerInteraction, scrollPosition: scrollPosition, initialData: initialData) |> map({ mappedChatHistoryViewListTransition(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, transition: $0) }) |> runOn(prepareOnMainQueue ? Queue.mainQueue() : messageViewQueue)
            }
        }
        
        let appliedTransition = historyViewTransition |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            if let strongSelf = self {
                return strongSelf.enqueueHistoryViewTransition(transition)
            }
            return .complete()
        }
        
        self.historyDisposable.set(appliedTransition.start())
        
        let previousMaxIncomingMessageIdByNamespace = Atomic<[MessageId.Namespace: MessageId]>(value: [:])
        let readHistory = combineLatest(self.maxVisibleIncomingMessageIndex.get(), self.canReadHistory.get())
            |> map { messageIndex, canRead in
                if canRead {
                    var apply = false
                    let _ = previousMaxIncomingMessageIdByNamespace.modify { dict in
                        let previousIndex = dict[messageIndex.id.namespace]
                        if previousIndex == nil || previousIndex!.id < messageIndex.id.id {
                            apply = true
                            var dict = dict
                            dict[messageIndex.id.namespace] = messageIndex.id
                            return dict
                        }
                        return dict
                    }
                    if apply {
                        let _ = account.postbox.modify({ modifier in
                            modifier.applyInteractiveReadMaxId(messageIndex.id)
                        }).start()
                    }
                }
        }
        
        self.readHistoryDisposable.set(readHistory.start())
        
        if let messageId = messageId {
            self._chatHistoryLocation.set(ChatHistoryLocation.InitialSearch(messageId: messageId, count: 60))
        } else {
            self._chatHistoryLocation.set(ChatHistoryLocation.Initial(count: 60))
        }
        
        self.displayedItemRangeChanged = { [weak self] displayedRange, opaqueTransactionState in
            if let strongSelf = self {
                if let historyView = (opaqueTransactionState as? ChatHistoryTransactionOpaqueState)?.historyView {
                    if let visible = displayedRange.visibleRange {
                        if let messageIndex = maxIncomingMessageIndexForEntries(historyView.filteredEntries, indexRange: (historyView.filteredEntries.count - 1 - visible.lastIndex, historyView.filteredEntries.count - 1 - visible.firstIndex)) {
                            strongSelf.updateMaxVisibleReadIncomingMessageIndex(messageIndex)
                        }
                    }
                    
                    if let loaded = displayedRange.loadedRange, let firstEntry = historyView.filteredEntries.first, let lastEntry = historyView.filteredEntries.last {
                        if loaded.firstIndex < 5 && historyView.originalView.laterId != nil {
                            strongSelf._chatHistoryLocation.set(ChatHistoryLocation.Navigation(index: lastEntry.index, anchorIndex: historyView.originalView.anchorIndex))
                        } else if loaded.lastIndex >= historyView.filteredEntries.count - 5 && historyView.originalView.earlierId != nil {
                            strongSelf._chatHistoryLocation.set(ChatHistoryLocation.Navigation(index: firstEntry.index, anchorIndex: historyView.originalView.anchorIndex))
                        }
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
        self._chatHistoryLocation.set(ChatHistoryLocation.Scroll(index: MessageIndex.lowerBound(peerId: self.peerId), anchorIndex: MessageIndex.lowerBound(peerId: self.peerId), sourceIndex: MessageIndex.upperBound(peerId: self.peerId), scrollPosition: .Bottom, animated: true))
    }
    
    public func scrollToEndOfHistory() {
        self._chatHistoryLocation.set(ChatHistoryLocation.Scroll(index: MessageIndex.upperBound(peerId: self.peerId), anchorIndex: MessageIndex.upperBound(peerId: self.peerId), sourceIndex: MessageIndex.lowerBound(peerId: self.peerId), scrollPosition: .Top, animated: true))
    }
    
    public func scrollToMessage(from fromIndex: MessageIndex, to toIndex: MessageIndex) {
        self._chatHistoryLocation.set(ChatHistoryLocation.Scroll(index: toIndex, anchorIndex: toIndex, sourceIndex: fromIndex, scrollPosition: .Center(.Bottom), animated: true))
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
    
    private func updateMaxVisibleReadIncomingMessageIndex(_ index: MessageIndex) {
        self.maxVisibleIncomingMessageIndex.set(index)
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
                    if !strongSelf.didSetInitialData {
                        strongSelf.didSetInitialData = true
                        strongSelf._initialData.set(.single(transition.initialData))
                    }
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
                            if let messageIndex = maxIncomingMessageIndexForEntries(transition.historyView.filteredEntries, indexRange: (transition.historyView.filteredEntries.count - 1 - visible.lastIndex, transition.historyView.filteredEntries.count - 1 - visible.firstIndex)) {
                                strongSelf.updateMaxVisibleReadIncomingMessageIndex(messageIndex)
                            }
                        }
                    }
                    if !strongSelf.didSetInitialData {
                        strongSelf.didSetInitialData = true
                        strongSelf._initialData.set(.single(transition.initialData))
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
                
                self.transaction(deleteIndices: mappedTransition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: mappedTransition.options, scrollToItem: mappedTransition.scrollToItem, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: mappedTransition.stationaryItemRange, updateOpaqueState: ChatHistoryTransactionOpaqueState(historyView: transition.historyView), completion: completion)
            } else {
                self.transaction(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, updateOpaqueState: ChatHistoryTransactionOpaqueState(historyView: transition.historyView), completion: completion)
            }
        }
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets) {
        self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueHistoryViewTransition()
        }
    }
}
