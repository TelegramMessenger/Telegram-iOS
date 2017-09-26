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
    case unread(index: MessageIndex)
    case positionRestoration(index: MessageIndex, relativeOffset: CGFloat)
    case index(index: MessageIndex, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool)
}

enum ChatHistoryViewUpdateType {
    case Initial(fadeIn: Bool)
    case Generic(type: ViewUpdateType)
}

public struct ChatHistoryCombinedInitialReadStateData {
    public let unreadCount: Int32
    public let totalUnreadCount: Int32
    public let notificationSettings: PeerNotificationSettings?
}

public struct ChatHistoryCombinedInitialData {
    let initialData: InitialMessageHistoryData?
    let buttonKeyboardMessage: Message?
    let cachedData: CachedPeerData?
    let cachedDataMessages: [MessageId: Message]?
    let readStateData: ChatHistoryCombinedInitialReadStateData?
}

enum ChatHistoryViewUpdate {
    case Loading(initialData: ChatHistoryCombinedInitialData?)
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
    let cachedDataMessages: [MessageId: Message]?
    let readStateData: ChatHistoryCombinedInitialReadStateData?
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
    let cachedDataMessages: [MessageId: Message]?
    let readStateData: ChatHistoryCombinedInitialReadStateData?
    let scrolledToIndex: MessageIndex?
}

private func maxMessageIndexForEntries(_ entries: [ChatHistoryEntry], indexRange: (Int, Int)) -> (incoming: MessageIndex?, overall: MessageIndex?) {
    var overall: MessageIndex?
    for i in (indexRange.0 ... indexRange.1).reversed() {
        if case let .MessageEntry(message, _, _, _, _) = entries[i] {
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
            case let .MessageEntry(message, theme, strings, read, _):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(theme: theme, strings: strings, account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message, read: read)
                    case .list:
                        item = ListMessageItem(theme: theme, account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .HoleEntry(_, theme, strings):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatHoleItem(index: entry.entry.index, theme: theme, strings: strings)
                    case .list:
                        item = ListMessageHoleItem()
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .UnreadEntry(_, theme, strings):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index, theme: theme, strings: strings), directionHint: entry.directionHint)
            case let .ChatInfoEntry(text, theme, strings):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatBotInfoItem(text: text, controllerInteraction: controllerInteraction, theme: theme, strings: strings), directionHint: entry.directionHint)
            case let .EmptyChatInfoEntry(theme, strings, tagMask):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatEmptyItem(theme: theme, strings: strings, tagMask: tagMask), directionHint: entry.directionHint)
            case let .SearchEntry(theme, strings):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    controllerInteraction.openSearch()
                }), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, entries: [ChatHistoryViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .MessageEntry(message, theme, strings, read, _):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(theme: theme, strings: strings, account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message, read: read)
                    case .list:
                        item = ListMessageItem(theme: theme, account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .HoleEntry(_, theme, strings):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatHoleItem(index: entry.entry.index, theme: theme, strings: strings)
                    case .list:
                        item = ListMessageHoleItem()
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .UnreadEntry(_, theme, strings):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index, theme: theme, strings: strings), directionHint: entry.directionHint)
            case let .ChatInfoEntry(text, theme, strings):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatBotInfoItem(text: text, controllerInteraction: controllerInteraction, theme: theme, strings: strings), directionHint: entry.directionHint)
            case let .EmptyChatInfoEntry(theme, strings, tagMask):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatEmptyItem(theme: theme, strings: strings, tagMask: tagMask), directionHint: entry.directionHint)
            case let .SearchEntry(theme, strings):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    controllerInteraction.openSearch()
                }), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatHistoryViewListTransition(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, transition: ChatHistoryViewTransition) -> ChatHistoryListViewTransition {
    return ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, entries: transition.insertEntries), updateItems: mappedUpdateEntries(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, initialData: transition.initialData, keyboardButtonsMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData, scrolledToIndex: transition.scrolledToIndex)
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
    private let tagMask: MessageTags?
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
    
    private let _cachedPeerDataAndMessages = Promise<(CachedPeerData?, [MessageId: Message]?)>()
    public var cachedPeerDataAndMessages: Signal<(CachedPeerData?, [MessageId: Message]?), NoError> {
        return self._cachedPeerDataAndMessages.get()
    }
    
    private var _buttonKeyboardMessage = Promise<Message?>(nil)
    private var currentButtonKeyboardMessage: Message?
    public var buttonKeyboardMessage: Signal<Message?, NoError> {
        return self._buttonKeyboardMessage.get()
    }
    
    private let maxVisibleIncomingMessageIndex = ValuePromise<MessageIndex>(ignoreRepeated: true)
    let canReadHistory = Promise<Bool>()
    private var canReadHistoryValue: Bool = false
    private var canReadHistoryDisposable: Disposable?
    
    private let _chatHistoryLocation = ValuePromise<ChatHistoryLocation>()
    private var chatHistoryLocation: Signal<ChatHistoryLocation, NoError> {
        return self._chatHistoryLocation.get()
    }
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    private let messageProcessingManager = ChatMessageThrottledProcessingManager()
    private let messageMentionProcessingManager = ChatMessageThrottledProcessingManager(delay: 0.2)
    
    private var maxVisibleMessageIndexReported: MessageIndex?
    var maxVisibleMessageIndexUpdated: ((MessageIndex) -> Void)?
    
    var scrolledToIndex: ((MessageIndex) -> Void)?
    
    private var currentPresentationData: PresentationData
    private var themeAndStrings: Promise<(PresentationTheme, PresentationStrings)>
    private var presentationDataDisposable: Disposable?
    
    private var isScrollAtBottomPosition = false
    private var interactiveReadActionDisposable: Disposable?
    
    public var contentPositionChanged: (ListViewVisibleContentOffset) -> Void = { _ in }
    
    public private(set) var loadState: ChatHistoryNodeLoadState?
    private var loadStateUpdated: ((ChatHistoryNodeLoadState) -> Void)?
    
    private var loadedMessagesFromCachedDataDisposable: Disposable?
    
    public init(account: Account, peerId: PeerId, tagMask: MessageTags?, messageId: MessageId?, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode = .bubbles) {
        self.account = account
        self.peerId = peerId
        self.messageId = messageId
        self.tagMask = tagMask
        self.controllerInteraction = controllerInteraction
        self.mode = mode
        
        self.currentPresentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.themeAndStrings = Promise((self.currentPresentationData.theme, self.currentPresentationData.strings))
        
        super.init()
        
        //self.stackFromBottom = true
        
        //self.debugInfo = true
        
        self.messageProcessingManager.process = { [weak account] messageIds in
            account?.viewTracker.updateViewCountForMessageIds(messageIds: messageIds)
        }
        self.messageMentionProcessingManager.process = { [weak account] messageIds in
            account?.viewTracker.updateMarkMentionsSeenForMessageIds(messageIds: messageIds)
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
        additionalData.append(.cachedPeerDataMessages(peerId))
        additionalData.append(.totalUnreadCount)
        additionalData.append(.peerNotificationSettings(peerId))
        
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
        
        let historyViewTransition = combineLatest(historyViewUpdate, self.themeAndStrings.get()) |> mapToQueue { [weak self] update, themeAndStrings -> Signal<ChatHistoryListViewTransition, NoError> in
            let initialData: ChatHistoryCombinedInitialData?
            switch update {
                case let .Loading(combinedInitialData):
                    initialData = combinedInitialData
                    Queue.mainQueue().async { [weak self] in
                        if let strongSelf = self {
                            if !strongSelf.didSetInitialData {
                                strongSelf.didSetInitialData = true
                                strongSelf._initialData.set(.single(combinedInitialData))
                            }
                            
                            strongSelf._cachedPeerDataAndMessages.set(.single((nil, nil)))
                            
                            let loadState: ChatHistoryNodeLoadState = .loading
                            if strongSelf.loadState != loadState {
                                strongSelf.loadState = loadState
                                strongSelf.loadStateUpdated?(loadState)
                            }
                            
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
                    
                    let processedView = ChatHistoryView(originalView: view, filteredEntries: chatHistoryEntriesForView(view, includeUnreadEntry: mode == .bubbles, includeEmptyEntry: mode == .bubbles && tagMask == nil, includeChatInfoEntry: mode == .bubbles, includeSearchEntry: mode == .list && tagMask == nil, theme: themeAndStrings.0, strings: themeAndStrings.1))
                    let previous = previousView.swap(processedView)
                    
                    return preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, account: account, peerId: peerId, controllerInteraction: controllerInteraction, scrollPosition: scrollPosition, initialData: initialData?.initialData, keyboardButtonsMessage: view.topTaggedMessages.first, cachedData: initialData?.cachedData, cachedDataMessages: initialData?.cachedDataMessages, readStateData: initialData?.readStateData) |> map({ mappedChatHistoryViewListTransition(account: account, peerId: peerId, controllerInteraction: controllerInteraction, mode: mode, transition: $0) }) |> runOn(prepareOnMainQueue ? Queue.mainQueue() : messageViewQueue)
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
        
        self.canReadHistoryDisposable = (self.canReadHistory.get() |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                if strongSelf.canReadHistoryValue != value {
                    strongSelf.canReadHistoryValue = value
                    strongSelf.updateReadHistoryActions()
                }
            }
        })
        
        if let messageId = messageId {
            self._chatHistoryLocation.set(ChatHistoryLocation.InitialSearch(location: .id(messageId), count: 60))
        } else {
            self._chatHistoryLocation.set(ChatHistoryLocation.Initial(count: 60))
        }
        
        self.displayedItemRangeChanged = { [weak self] displayedRange, opaqueTransactionState in
            if let strongSelf = self {
                if let historyView = (opaqueTransactionState as? ChatHistoryTransactionOpaqueState)?.historyView {
                    if let visible = displayedRange.visibleRange {
                        let indexRange = (historyView.filteredEntries.count - 1 - visible.lastIndex, historyView.filteredEntries.count - 1 - visible.firstIndex)
                        
                        var messageIdsWithViewCount: [MessageId] = []
                        var messageIdsWithUnseenPersonalMention: [MessageId] = []
                        for i in (indexRange.0 ... indexRange.1) {
                            if case let .MessageEntry(message, _, _, _, _) = historyView.filteredEntries[i] {
                                var hasUnconsumedMention = false
                                var hasUnsonsumedContent = false
                                if message.tags.contains(.unseenPersonalMessage) {
                                    for attribute in message.attributes {
                                        if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.pending {
                                            hasUnconsumedMention = true
                                        }
                                    }
                                }
                                for attribute in message.attributes {
                                    if attribute is ViewCountMessageAttribute {
                                        messageIdsWithViewCount.append(message.id)
                                    } else if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                                        hasUnsonsumedContent = true
                                    }
                                }
                                if hasUnconsumedMention && !hasUnsonsumedContent {
                                    messageIdsWithUnseenPersonalMention.append(message.id)
                                }
                            }
                        }
                        
                        if !messageIdsWithViewCount.isEmpty {
                            strongSelf.messageProcessingManager.add(messageIdsWithViewCount)
                        }
                        
                        if !messageIdsWithUnseenPersonalMention.isEmpty {
                            strongSelf.messageMentionProcessingManager.add(messageIdsWithUnseenPersonalMention)
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
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.currentPresentationData.theme
                    let previousStrings = strongSelf.currentPresentationData.strings
                    
                    strongSelf.currentPresentationData = presentationData
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.forEachItemHeaderNode { itemHeaderNode in
                            if let dateNode = itemHeaderNode as? ChatMessageDateHeaderNode {
                                dateNode.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                            }
                        }
                        strongSelf.themeAndStrings.set(.single((presentationData.theme, presentationData.strings)))
                    }
                }
            })
        
        self.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self {
                strongSelf.contentPositionChanged(offset)
                
                if strongSelf.tagMask == nil {
                    var atBottom = false
                    switch offset {
                        case let .known(offsetValue):
                            if offsetValue.isLessThanOrEqualTo(0.0) {
                                atBottom = true
                            }
                        default:
                            break
                    }
                    
                    if atBottom != strongSelf.isScrollAtBottomPosition {
                        strongSelf.isScrollAtBottomPosition = atBottom
                        strongSelf.updateReadHistoryActions()
                    }
                }
            }
        }
        
        self.loadedMessagesFromCachedDataDisposable = (self._cachedPeerDataAndMessages.get() |> map { dataAndMessages -> MessageId? in
            return dataAndMessages.0?.messageIds.first
        } |> distinctUntilChanged(isEqual: { $0 == $1 })
        |> mapToSignal { messageId -> Signal<Void, NoError> in
            if let messageId = messageId {
                return getMessagesLoadIfNecessary([messageId], postbox: account.postbox, network: account.network) |> map { _ -> Void in return Void() }
            } else {
                return .complete()
            }
        }).start()
    }
    
    deinit {
        self.historyDisposable.dispose()
        self.readHistoryDisposable.dispose()
        self.interactiveReadActionDisposable?.dispose()
        self.canReadHistoryDisposable?.dispose()
        self.loadedMessagesFromCachedDataDisposable?.dispose()
    }
    
    public func setLoadStateUpdated(_ f: @escaping (ChatHistoryNodeLoadState) -> Void) {
        self.loadStateUpdated = f
    }
    
    public func scrollToStartOfHistory() {
        self._chatHistoryLocation.set(ChatHistoryLocation.Scroll(index: MessageIndex.lowerBound(peerId: self.peerId), anchorIndex: MessageIndex.lowerBound(peerId: self.peerId), sourceIndex: MessageIndex.upperBound(peerId: self.peerId), scrollPosition: .bottom(0.0), animated: true))
    }
    
    public func scrollToEndOfHistory() {
        switch self.visibleContentOffset() {
            case .known(0.0):
                break
            default:
                self._chatHistoryLocation.set(ChatHistoryLocation.Scroll(index: MessageIndex.upperBound(peerId: self.peerId), anchorIndex: MessageIndex.upperBound(peerId: self.peerId), sourceIndex: MessageIndex.lowerBound(peerId: self.peerId), scrollPosition: .top(0.0), animated: true))
        }
    }
    
    public func scrollToMessage(from fromIndex: MessageIndex, to toIndex: MessageIndex) {
        self._chatHistoryLocation.set(ChatHistoryLocation.Scroll(index: toIndex, anchorIndex: toIndex, sourceIndex: fromIndex, scrollPosition: .center(.bottom), animated: true))
    }
    
    public func anchorMessageInCurrentHistoryView() -> Message? {
        if let historyView = self.historyView {
            if let visibleRange = self.displayedItemRange.visibleRange {
                var index = 0
                for entry in historyView.filteredEntries.reversed() {
                    if index >= visibleRange.firstIndex && index <= visibleRange.lastIndex {
                        if case let .MessageEntry(message, _, _, _, _) = entry {
                            return message
                        }
                    }
                    index += 1
                }
            }
            
            for case let .MessageEntry(message, _, _, _, _) in historyView.filteredEntries {
                return message
            }
        }
        return nil
    }
    
    public func messageInCurrentHistoryView(_ id: MessageId) -> Message? {
        if let historyView = self.historyView {
            for case let .MessageEntry(message, _, _, _, _) in historyView.filteredEntries where message.id == id {
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
                    strongSelf._initialData.set(.single(ChatHistoryCombinedInitialData(initialData: transition.initialData, buttonKeyboardMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData)))
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
                    strongSelf._cachedPeerDataAndMessages.set(.single((transition.cachedData, transition.cachedDataMessages)))
                    
                    let loadState: ChatHistoryNodeLoadState
                    if transition.historyView.filteredEntries.isEmpty {
                        loadState = .empty
                    } else {
                        loadState = .messages
                    }
                    if strongSelf.loadState != loadState {
                        strongSelf.loadState = loadState
                        strongSelf.loadStateUpdated?(loadState)
                    }
                    
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
                    
                    let loadState: ChatHistoryNodeLoadState
                    if let historyView = strongSelf.historyView {
                        if historyView.filteredEntries.isEmpty {
                            loadState = .empty
                        } else {
                            loadState = .messages
                        }
                    } else {
                        loadState = .loading
                    }
                    
                    if strongSelf.loadState != loadState {
                        strongSelf.loadState = loadState
                        strongSelf.loadStateUpdated?(loadState)
                    }
                    
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
                        strongSelf._initialData.set(.single(ChatHistoryCombinedInitialData(initialData: transition.initialData, buttonKeyboardMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData)))
                    }
                    strongSelf._cachedPeerDataAndMessages.set(.single((transition.cachedData, transition.cachedDataMessages)))
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
    
    private func updateReadHistoryActions() {
        let canRead = self.canReadHistoryValue && self.isScrollAtBottomPosition
        if canRead != (self.interactiveReadActionDisposable != nil) {
            if let interactiveReadActionDisposable = self.interactiveReadActionDisposable {
                if !canRead {
                    interactiveReadActionDisposable.dispose()
                    self.interactiveReadActionDisposable = nil
                }
            } else if self.interactiveReadActionDisposable == nil {
                self.interactiveReadActionDisposable = installInteractiveReadMessagesAction(postbox: self.account.postbox, peerId: self.peerId)
            }
        }
    }
    
    func immediateScrollState() -> ChatInterfaceHistoryScrollState? {
        var currentMessage: Message?
        if let historyView = self.historyView {
            if let visibleRange = self.displayedItemRange.visibleRange {
                var index = 0
                loop: for entry in historyView.filteredEntries.reversed() {
                    if index >= visibleRange.firstIndex && index <= visibleRange.lastIndex {
                        if case let .MessageEntry(message, _, _, _, _) = entry {
                            if index != 0 || historyView.originalView.laterId != nil {
                                currentMessage = message
                            }
                            break loop
                        }
                    }
                    index += 1
                }
            }
        }
        
        if let message = currentMessage {
            var relativeOffset: CGFloat = 0.0
            self.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item, item.message.id == message.id {
                    if let offsetValue = self.itemNodeRelativeOffset(itemNode) {
                        relativeOffset = offsetValue
                    }
                }
            }
            return ChatInterfaceHistoryScrollState(messageIndex: MessageIndex(message), relativeOffset: Double(relativeOffset))
        }
        return nil
    }
}
