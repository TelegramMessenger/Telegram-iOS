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

public struct ChatHistoryCombinedInitialData {
    let initialData: InitialMessageHistoryData?
    let buttonKeyboardMessage: Message?
    let cachedData: CachedPeerData?
}

enum ChatHistoryViewUpdate {
    case Loading(initialData: InitialMessageHistoryData?)
    case HistoryView(view: MessageHistoryView, type: ChatHistoryViewUpdateType, scrollPosition: ChatHistoryViewScrollPosition?, initialData: ChatHistoryCombinedInitialData)
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
    let keyboardButtonsMessage: Message?
    let cachedData: CachedPeerData?
    let scrolledToIndex: MessageIndex?
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
    let keyboardButtonsMessage: Message?
    let cachedData: CachedPeerData?
    let scrolledToIndex: MessageIndex?
}

private func maxMessageIndexForEntries(_ entries: [ChatHistoryEntry], indexRange: (Int, Int)) -> (incoming: MessageIndex?, overall: MessageIndex?) {
    var overall: MessageIndex?
    for i in (indexRange.0 ... indexRange.1).reversed() {
        if case let .MessageEntry(message, _, _) = entries[i] {
            if overall == nil {
                overall = MessageIndex(message)
            }
            if message.flags.contains(.Incoming) {
                return (MessageIndex(message), overall)
            }
        }
    }
    return (nil, overall)
}

private func mappedInsertEntries(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, entries: [ChatHistoryViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case let .MessageEntry(message, read, _):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message, read: read)
                    case .list:
                        item = ListMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case .HoleEntry:
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatHoleItem(index: entry.entry.index)
                    case .list:
                        item = ListMessageHoleItem()
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case .UnreadEntry:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index), directionHint: entry.directionHint)
            case let .ChatInfoEntry(text):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatBotInfoItem(text: text, controllerInteraction: controllerInteraction), directionHint: entry.directionHint)
            case .EmptyChatInfoEntry:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatEmptyItem(), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, entries: [ChatHistoryViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .MessageEntry(message, read, _):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message, read: read)
                    case .list:
                        item = ListMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case .HoleEntry:
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatHoleItem(index: entry.entry.index)
                    case .list:
                        item = ListMessageHoleItem()
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case .UnreadEntry:
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index), directionHint: entry.directionHint)
            case let .ChatInfoEntry(text):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatBotInfoItem(text: text, controllerInteraction: controllerInteraction), directionHint: entry.directionHint)
            case .EmptyChatInfoEntry:
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatEmptyItem(), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatHistoryViewListTransition(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, transition: ChatHistoryViewTransition) -> ChatHistoryListViewTransition {
    return ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, entries: transition.insertEntries), updateItems: mappedUpdateEntries(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, initialData: transition.initialData, keyboardButtonsMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, scrolledToIndex: transition.scrolledToIndex)
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
    
    public let historyState = ValuePromise<ChatHistoryNodeHistoryState>()
    public var currentHistoryState: ChatHistoryNodeHistoryState?
    
    private let _initialData = Promise<ChatHistoryCombinedInitialData?>()
    private var didSetInitialData = false
    public var initialData: Signal<ChatHistoryCombinedInitialData?, NoError> {
        return self._initialData.get()
    }
    
    private let _cachedPeerData = Promise<CachedPeerData?>()
    public var cachedPeerData: Signal<CachedPeerData?, NoError> {
        return self._cachedPeerData.get()
    }
    
    private var _buttonKeyboardMessage = Promise<Message?>(nil)
    private var currentButtonKeyboardMessage: Message?
    public var buttonKeyboardMessage: Signal<Message?, NoError> {
        return self._buttonKeyboardMessage.get()
    }
    
    private let maxVisibleIncomingMessageIndex = ValuePromise<MessageIndex>(ignoreRepeated: true)
    let canReadHistory = Promise<Bool>()
    
    private let _chatHistoryLocation = ValuePromise<ChatHistoryLocation>()
    private var chatHistoryLocation: Signal<ChatHistoryLocation, NoError> {
        return self._chatHistoryLocation.get()
    }
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    private let messageProcessingManager = ChatMessageThrottledProcessingManager()
    
    private var maxVisibleMessageIndexReported: MessageIndex?
    var maxVisibleMessageIndexUpdated: ((MessageIndex) -> Void)?
    
    var scrolledToIndex: ((MessageIndex) -> Void)?
    
    public init(account: Account, peerId: PeerId, tagMask: MessageTags?, messageId: MessageId?, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode = .bubbles) {
        self.account = account
        self.peerId = peerId
        self.messageId = messageId
        self.controllerInteraction = controllerInteraction
        self.mode = mode
        
        super.init()
        
        //self.stackFromBottom = true
        
        //self.debugInfo = true
        
        self.messageProcessingManager.process = { [weak account] messageIds in
            account?.viewTracker.updateViewCountForMessageIds(messageIds: messageIds)
        }
        
        self.preloadPages = false
        switch self.mode {
            case .bubbles:
                self.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
            case .list:
                break
        }
        //self.snapToBottomInsetUntilFirstInteraction = true
        
        let messageViewQueue = self.messageViewQueue
        
        let fixedCombinedReadState = Atomic<CombinedPeerReadState?>(value: nil)
        
        var additionalData: [AdditionalMessageHistoryViewData] = []
        additionalData.append(.cachedPeerData(peerId))
        
        let historyViewUpdate = self.chatHistoryLocation
            |> distinctUntilChanged
            |> mapToSignal { location in
                return chatHistoryViewForLocation(location, account: account, peerId: peerId, fixedCombinedReadState: fixedCombinedReadState.with { $0 }, tagMask: tagMask, additionalData: additionalData) |> beforeNext { viewUpdate in
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
            let initialData: ChatHistoryCombinedInitialData?
            switch update {
                case let .Loading(data):
                    let combinedInitialData = ChatHistoryCombinedInitialData(initialData: data, buttonKeyboardMessage: nil, cachedData: nil)
                    initialData = combinedInitialData
                    Queue.mainQueue().async { [weak self] in
                        if let strongSelf = self {
                            if !strongSelf.didSetInitialData {
                                strongSelf.didSetInitialData = true
                                strongSelf._initialData.set(.single(combinedInitialData))
                            }
                            
                            strongSelf._cachedPeerData.set(.single(nil))
                            
                            let historyState: ChatHistoryNodeHistoryState = .loading
                            if strongSelf.currentHistoryState != historyState {
                                strongSelf.currentHistoryState = historyState
                                strongSelf.historyState.set(historyState)
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
                    
                    let processedView = ChatHistoryView(originalView: view, filteredEntries: chatHistoryEntriesForView(view, includeUnreadEntry: mode == .bubbles, includeChatInfoEntry: true))
                    let previous = previousView.swap(processedView)
                    
                    return preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, account: account, peerId: peerId, controllerInteraction: controllerInteraction, scrollPosition: scrollPosition, initialData: initialData?.initialData, keyboardButtonsMessage: view.topTaggedMessages.first, cachedData: initialData?.cachedData) |> map({ mappedChatHistoryViewListTransition(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, transition: $0) }) |> runOn(prepareOnMainQueue ? Queue.mainQueue() : messageViewQueue)
            }
        }
        
        let appliedTransition = historyViewTransition |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            if let strongSelf = self {
                return strongSelf.enqueueHistoryViewTransition(transition)
            }
            return .complete()
        }
        
        self.historyDisposable.set(appliedTransition.start())
        
        let previousMaxIncomingMessageIndexByNamespace = Atomic<[MessageId.Namespace: MessageIndex]>(value: [:])
        let readHistory = combineLatest(self.maxVisibleIncomingMessageIndex.get(), self.canReadHistory.get())
            |> map { messageIndex, canRead in
                if canRead {
                    var apply = false
                    let _ = previousMaxIncomingMessageIndexByNamespace.modify { dict in
                        let previousIndex = dict[messageIndex.id.namespace]
                        if previousIndex == nil || previousIndex! < messageIndex {
                            apply = true
                            var dict = dict
                            dict[messageIndex.id.namespace] = messageIndex
                            return dict
                        }
                        return dict
                    }
                    if apply {
                        let _ = applyMaxReadIndexInteractively(postbox: account.postbox, network: account.network, index: messageIndex).start()
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
                        let indexRange = (historyView.filteredEntries.count - 1 - visible.lastIndex, historyView.filteredEntries.count - 1 - visible.firstIndex)
                        
                        var messageIdsWithViewCount: [MessageId] = []
                        for i in (indexRange.0 ... indexRange.1) {
                            if case let .MessageEntry(message, _, _) = historyView.filteredEntries[i] {
                                inner: for attribute in message.attributes {
                                    if attribute is ViewCountMessageAttribute {
                                        messageIdsWithViewCount.append(message.id)
                                        break inner
                                    }
                                }
                            }
                        }
                        
                        if !messageIdsWithViewCount.isEmpty {
                            strongSelf.messageProcessingManager.add(messageIdsWithViewCount)
                        }
                        
                        let (maxIncomingIndex, maxOverallIndex) = maxMessageIndexForEntries(historyView.filteredEntries, indexRange: indexRange)
                        
                        if let maxIncomingIndex = maxIncomingIndex {
                            strongSelf.updateMaxVisibleReadIncomingMessageIndex(maxIncomingIndex)
                        }
                        
                        if let maxOverallIndex = maxOverallIndex, maxOverallIndex != strongSelf.maxVisibleMessageIndexReported {
                            strongSelf.maxVisibleMessageIndexReported = maxOverallIndex
                            strongSelf.maxVisibleMessageIndexUpdated?(maxOverallIndex)
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
    
    public func anchorMessageInCurrentHistoryView() -> Message? {
        if let historyView = self.historyView {
            if let visibleRange = self.displayedItemRange.visibleRange {
                var index = 0
                for entry in historyView.filteredEntries.reversed() {
                    if index >= visibleRange.firstIndex && index <= visibleRange.lastIndex {
                        if case let .MessageEntry(message, _, _) = entry {
                            return message
                        }
                    }
                    index += 1
                }
            }
            
            for case let .MessageEntry(message, _, _) in historyView.filteredEntries {
                return message
            }
        }
        return nil
    }
    
    public func messageInCurrentHistoryView(_ id: MessageId) -> Message? {
        if let historyView = self.historyView {
            for case let .MessageEntry(message, _, _) in historyView.filteredEntries where message.id == id {
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
                
                if !strongSelf.didSetInitialData {
                    strongSelf.didSetInitialData = true
                    strongSelf._initialData.set(.single(ChatHistoryCombinedInitialData(initialData: transition.initialData, buttonKeyboardMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData)))
                }
                
                strongSelf.enqueuedHistoryViewTransition = (transition, {
                    if let scrolledToIndex = transition.scrolledToIndex {
                        if let strongSelf = self {
                            strongSelf.scrolledToIndex?(scrolledToIndex)
                        }
                    }
                    subscriber.putCompletion()
                })
                
                if strongSelf.isNodeLoaded {
                    strongSelf.dequeueHistoryViewTransition()
                } else {
                    /*if !strongSelf.didSetInitialData {
                        strongSelf.didSetInitialData = true
                        strongSelf._initialData.set(.single(ChatHistoryCombinedInitialData(initialData: transition.initialData, buttonKeyboardMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData)))
                    }*/
                    strongSelf._cachedPeerData.set(.single(transition.cachedData))
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
            
            let completion: (ListViewDisplayedItemRange) -> Void = { [weak self] visibleRange in
                if let strongSelf = self {
                    strongSelf.historyView = transition.historyView
                    
                    if let range = visibleRange.loadedRange {
                        strongSelf.account.postbox.updateMessageHistoryViewVisibleRange(transition.historyView.originalView.id, earliestVisibleIndex: transition.historyView.filteredEntries[transition.historyView.filteredEntries.count - 1 - range.lastIndex].index, latestVisibleIndex: transition.historyView.filteredEntries[transition.historyView.filteredEntries.count - 1 - range.firstIndex].index)
                        
                        if let visible = visibleRange.visibleRange {
                            let (messageIndex, _) = maxMessageIndexForEntries(transition.historyView.filteredEntries, indexRange: (transition.historyView.filteredEntries.count - 1 - visible.lastIndex, transition.historyView.filteredEntries.count - 1 - visible.firstIndex))
                            if let messageIndex = messageIndex {
                                strongSelf.updateMaxVisibleReadIncomingMessageIndex(messageIndex)
                            }
                        }
                    }
                    if !strongSelf.didSetInitialData {
                        strongSelf.didSetInitialData = true
                        strongSelf._initialData.set(.single(ChatHistoryCombinedInitialData(initialData: transition.initialData, buttonKeyboardMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData)))
                    }
                    strongSelf._cachedPeerData.set(.single(transition.cachedData))
                    let historyState: ChatHistoryNodeHistoryState = .loaded(isEmpty: transition.historyView.originalView.entries.isEmpty)
                    if strongSelf.currentHistoryState != historyState {
                        strongSelf.currentHistoryState = historyState
                        strongSelf.historyState.set(historyState)
                    }
                    
                    var buttonKeyboardMessageUpdated = false
                    if let currentButtonKeyboardMessage = strongSelf.currentButtonKeyboardMessage, let buttonKeyboardMessage = transition.keyboardButtonsMessage {
                        if currentButtonKeyboardMessage.id != buttonKeyboardMessage.id || currentButtonKeyboardMessage.stableVersion != buttonKeyboardMessage.stableVersion {
                            buttonKeyboardMessageUpdated = true
                        }
                    } else if (strongSelf.currentButtonKeyboardMessage != nil) != (transition.keyboardButtonsMessage != nil) {
                        buttonKeyboardMessageUpdated = true
                    }
                    if buttonKeyboardMessageUpdated {
                        strongSelf.currentButtonKeyboardMessage = transition.keyboardButtonsMessage
                        strongSelf._buttonKeyboardMessage.set(.single(transition.keyboardButtonsMessage))
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
    
    public func disconnect() {
        self.historyDisposable.set(nil)
    }
}
