import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

private class ChatGridLiveSelectorRecognizer: UIPanGestureRecognizer {
    private let selectionGestureActivationThreshold: CGFloat = 2.0
    private let selectionGestureVerticalFailureThreshold: CGFloat = 5.0
    
    var validatedGesture: Bool? = nil
    var firstLocation: CGPoint = CGPoint()
    
    var shouldBegin: (() -> Bool)?
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override func reset() {
        super.reset()
        
        self.validatedGesture = nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let shouldBegin = self.shouldBegin, !shouldBegin() {
            self.state = .failed
        } else {
            let touch = touches.first!
            self.firstLocation = touch.location(in: self.view)
        }
    }
    
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - self.firstLocation.x, y: location.y - self.firstLocation.y)
        
        if self.validatedGesture == nil {
            if (fabs(translation.y) >= selectionGestureVerticalFailureThreshold) {
                self.validatedGesture = false
            }
            else if (fabs(translation.x) >= selectionGestureActivationThreshold) {
                self.validatedGesture = true
            }
        }
        
        if let validatedGesture = self.validatedGesture {
            if validatedGesture {
                super.touchesMoved(touches, with: event)
            }
        }
    }
}

struct ChatHistoryGridViewTransition {
    let historyView: ChatHistoryView
    let topOffsetWithinMonth: Int
    let deleteItems: [Int]
    let insertItems: [GridNodeInsertItem]
    let updateItems: [GridNodeUpdateItem]
    let scrollToItem: GridNodeScrollToItem?
    let stationaryItems: GridNodeStationaryItems
}

private func mappedInsertEntries(context: AccountContext, peerId: PeerId, controllerInteraction: ChatControllerInteraction, entries: [ChatHistoryViewTransitionInsertEntry], theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) -> [GridNodeInsertItem] {
    return entries.map { entry -> GridNodeInsertItem in
        switch entry.entry {
            case let .MessageEntry(message, _, _, _, _, _):
                return GridNodeInsertItem(index: entry.index, item: GridMessageItem(theme: theme, strings: strings, fontSize: fontSize, context: context, message: message, controllerInteraction: controllerInteraction), previousIndex: entry.previousIndex)
            case .MessageGroupEntry:
                return GridNodeInsertItem(index: entry.index, item: GridHoleItem(), previousIndex: entry.previousIndex)
            case .UnreadEntry:
                assertionFailure()
                return GridNodeInsertItem(index: entry.index, item: GridHoleItem(), previousIndex: entry.previousIndex)
            case .ChatInfoEntry, .SearchEntry:
                assertionFailure()
                return GridNodeInsertItem(index: entry.index, item: GridHoleItem(), previousIndex: entry.previousIndex)
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, peerId: PeerId, controllerInteraction: ChatControllerInteraction, entries: [ChatHistoryViewTransitionUpdateEntry], theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) -> [GridNodeUpdateItem] {
    return entries.map { entry -> GridNodeUpdateItem in
        switch entry.entry {
            case let .MessageEntry(message, _, _, _, _, _):
                return GridNodeUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: GridMessageItem(theme: theme, strings: strings, fontSize: fontSize, context: context, message: message, controllerInteraction: controllerInteraction))
            case .MessageGroupEntry:
                return GridNodeUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: GridHoleItem())
            case .UnreadEntry:
                assertionFailure()
                return GridNodeUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: GridHoleItem())
            case .ChatInfoEntry, .SearchEntry:
                assertionFailure()
                return GridNodeUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: GridHoleItem())
        }
    }
}

private func mappedChatHistoryViewListTransition(context: AccountContext, peerId: PeerId, controllerInteraction: ChatControllerInteraction, transition: ChatHistoryViewTransition, from: ChatHistoryView?, presentationData: ChatPresentationData) -> ChatHistoryGridViewTransition {
    var mappedScrollToItem: GridNodeScrollToItem?
    if let scrollToItem = transition.scrollToItem {
        let mappedPosition: GridNodeScrollToItemPosition
        switch scrollToItem.position {
            case .top:
                mappedPosition = .top(0.0)
            case .center:
                mappedPosition = .center(0.0)
            case .bottom:
                mappedPosition = .bottom(0.0)
            case .visible:
                mappedPosition = .bottom(0.0)
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
        mappedScrollToItem = GridNodeScrollToItem(index: scrollToItem.index, position: mappedPosition, transition: scrollTransition, directionHint: directionHint, adjustForSection: true, adjustForTopInset: true)
    }
    
    var stationaryItems: GridNodeStationaryItems = .none
    if let previousView = from {
        if let stationaryRange = transition.stationaryItemRange {
            var fromStableIds = Set<UInt64>()
            for i in 0 ..< previousView.filteredEntries.count {
                if i >= stationaryRange.0 && i <= stationaryRange.1 {
                    fromStableIds.insert(previousView.filteredEntries[i].stableId)
                }
            }
            var index = 0
            var indices = Set<Int>()
            for entry in transition.historyView.filteredEntries {
                if fromStableIds.contains(entry.stableId) {
                    indices.insert(transition.historyView.filteredEntries.count - 1 - index)
                }
                index += 1
            }
            stationaryItems = .indices(indices)
        } else {
            var fromStableIds = Set<UInt64>()
            for i in 0 ..< previousView.filteredEntries.count {
                fromStableIds.insert(previousView.filteredEntries[i].stableId)
            }
            var index = 0
            var indices = Set<Int>()
            for entry in transition.historyView.filteredEntries {
                if fromStableIds.contains(entry.stableId) {
                    indices.insert(transition.historyView.filteredEntries.count - 1 - index)
                }
                index += 1
            }
            stationaryItems = .indices(indices)
        }
    }
    
    var topOffsetWithinMonth: Int = 0
    if let lastEntry = transition.historyView.filteredEntries.last {
        switch lastEntry {
            case let .MessageEntry(_, _, _,  monthLocation, _, _):
                if let monthLocation = monthLocation {
                    topOffsetWithinMonth = Int(monthLocation.indexInMonth)
                }
            default:
                break
        }
    }
    
    return ChatHistoryGridViewTransition(historyView: transition.historyView, topOffsetWithinMonth: topOffsetWithinMonth, deleteItems: transition.deleteItems.map { $0.index }, insertItems: mappedInsertEntries(context: context, peerId: peerId, controllerInteraction: controllerInteraction, entries: transition.insertEntries, theme: presentationData.theme.theme, strings: presentationData.strings, fontSize: presentationData.fontSize), updateItems: mappedUpdateEntries(context: context, peerId: peerId, controllerInteraction: controllerInteraction, entries: transition.updateEntries, theme: presentationData.theme.theme, strings: presentationData.strings, fontSize: presentationData.fontSize), scrollToItem: mappedScrollToItem, stationaryItems: stationaryItems)
}

private func gridNodeLayoutForContainerLayout(size: CGSize) -> GridNodeLayoutType {
    let side = floorToScreenPixels((size.width - 3.0) / 4.0)
    return .fixed(itemSize: CGSize(width: side, height: side), fillWidth: true, lineSpacing: 1.0, itemSpacing: 1.0)
}

public final class ChatHistoryGridNode: GridNode, ChatHistoryNode {
    private let context: AccountContext
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
    
    private let _chatHistoryLocation = ValuePromise<ChatHistoryLocation>(ignoreRepeated: true)
    private var chatHistoryLocation: Signal<ChatHistoryLocation, NoError> {
        return self._chatHistoryLocation.get()
    }
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private let chatPresentationDataPromise = Promise<ChatPresentationData>()
    
    public private(set) var loadState: ChatHistoryNodeLoadState?
    private var loadStateUpdated: ((ChatHistoryNodeLoadState, Bool) -> Void)?
    private let controllerInteraction: ChatControllerInteraction
    
    public init(context: AccountContext, peerId: PeerId, messageId: MessageId?, tagMask: MessageTags?, controllerInteraction: ChatControllerInteraction) {
        self.context = context
        self.peerId = peerId
        self.messageId = messageId
        self.tagMask = tagMask
        self.controllerInteraction = controllerInteraction
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init()
        
        self.chatPresentationDataPromise.set(context.sharedContext.presentationData
        |> map { presentationData in
            return ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations, largeEmoji: presentationData.largeEmoji)
        })
        
        self.floatingSections = true
        
        let messageViewQueue = self.messageViewQueue
        
        let historyViewUpdate = self.chatHistoryLocation
        |> distinctUntilChanged
        |> mapToSignal { location in
            return chatHistoryViewForLocation(ChatHistoryLocationInput(content: location, id: 0), account: context.account, chatLocation: .peer(peerId), scheduled: false, fixedCombinedReadStates: nil, tagMask: tagMask, additionalData: [], orderStatistics: [.locationWithinMonth])
        }
        
        let previousView = Atomic<ChatHistoryView?>(value: nil)
        
        let historyViewTransition = combineLatest(queue: messageViewQueue, historyViewUpdate, self.chatPresentationDataPromise.get())
        |> mapToQueue { [weak self] update, chatPresentationData -> Signal<ChatHistoryGridViewTransition, NoError> in
            switch update {
                case .Loading:
                    Queue.mainQueue().async { [weak self] in
                        if let strongSelf = self {
                            let loadState: ChatHistoryNodeLoadState = .loading
                            if strongSelf.loadState != loadState {
                                strongSelf.loadState = loadState
                                strongSelf.loadStateUpdated?(loadState, false)
                            }
                            
                            let historyState: ChatHistoryNodeHistoryState = .loading
                            if strongSelf.currentHistoryState != historyState {
                                strongSelf.currentHistoryState = historyState
                                strongSelf.historyState.set(historyState)
                            }
                        }
                    }
                    return .complete()
                case let .HistoryView(view, type, scrollPosition, flashIndicators, _, _, id):
                    let reason: ChatHistoryViewTransitionReason
                    switch type {
                        case let .Initial(fadeIn):
                            reason = ChatHistoryViewTransitionReason.Initial(fadeIn: fadeIn)
                        case let .Generic(genericType):
                            switch genericType {
                                case .InitialUnread, .Initial:
                                    reason = ChatHistoryViewTransitionReason.Initial(fadeIn: false)
                                case .Generic:
                                    reason = ChatHistoryViewTransitionReason.InteractiveChanges
                                case .UpdateVisible:
                                    reason = ChatHistoryViewTransitionReason.Reload
                                case .FillHole:
                                    reason = ChatHistoryViewTransitionReason.Reload
                            }
                    }
                    
                    let associatedData = ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadNetworkType: .cellular, isRecentActions: false)
                    let processedView = ChatHistoryView(originalView: view, filteredEntries: chatHistoryEntriesForView(location: .peer(peerId), view: view, includeUnreadEntry: false, includeEmptyEntry: false, includeChatInfoEntry: false, includeSearchEntry: false, reverse: false, groupMessages: false, selectedMessages: nil, presentationData: chatPresentationData, historyAppearsCleared: false, associatedData: associatedData), associatedData: associatedData, id: id)
                    let previous = previousView.swap(processedView)
                    
                    let rawTransition = preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, reverse: false, chatLocation: .peer(peerId), controllerInteraction: controllerInteraction, scrollPosition: scrollPosition, initialData: nil, keyboardButtonsMessage: nil, cachedData: nil, cachedDataMessages: nil, readStateData: nil, flashIndicators: flashIndicators, updatedMessageSelection: false)
                    let mappedTransition = mappedChatHistoryViewListTransition(context: context, peerId: peerId, controllerInteraction: controllerInteraction, transition: rawTransition, from: previous, presentationData: chatPresentationData)
                    return .single(mappedTransition)
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
            self._chatHistoryLocation.set(ChatHistoryLocation.InitialSearch(location: .id(messageId), count: 100))
        } else {
            self._chatHistoryLocation.set(ChatHistoryLocation.Initial(count: 100))
        }
        
        self.visibleItemsUpdated = { [weak self] visibleItems in
            if let strongSelf = self, let historyView = strongSelf.historyView, let top = visibleItems.top, let bottom = visibleItems.bottom, let visibleTop = visibleItems.topVisible, let visibleBottom = visibleItems.bottomVisible {
                if top.0 < 5 && historyView.originalView.laterId != nil {
                    let lastEntry = historyView.filteredEntries[historyView.filteredEntries.count - 1 - visibleTop.0]
                    strongSelf._chatHistoryLocation.set(ChatHistoryLocation.Navigation(index: .message(lastEntry.index), anchorIndex: .message(lastEntry.index), count: 100))
                } else if bottom.0 >= historyView.filteredEntries.count - 5 && historyView.originalView.earlierId != nil {
                    let firstEntry = historyView.filteredEntries[historyView.filteredEntries.count - 1 - visibleBottom.0]
                    strongSelf._chatHistoryLocation.set(ChatHistoryLocation.Navigation(index: .message(firstEntry.index), anchorIndex: .message(firstEntry.index), count: 100))
                }
            }
        }
        
        let selectorRecogizner = ChatGridLiveSelectorRecognizer(target: self, action: #selector(self.panGesture(_:)))
        selectorRecogizner.shouldBegin = { [weak controllerInteraction] in
            return controllerInteraction?.selectionState != nil
        }
        self.view.addGestureRecognizer(selectorRecogizner)
    }
    
    public override func didLoad() {
        super.didLoad()
    }
        
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.historyDisposable.dispose()
    }
    
    public func setLoadStateUpdated(_ f: @escaping (ChatHistoryNodeLoadState, Bool) -> Void) {
        self.loadStateUpdated = f
    }
    
    public func scrollToStartOfHistory() {
        self._chatHistoryLocation.set(ChatHistoryLocation.Scroll(index: .lowerBound, anchorIndex: .lowerBound, sourceIndex: .upperBound, scrollPosition: .bottom(0.0), animated: true))
    }
    
    public func scrollToEndOfHistory() {
        self._chatHistoryLocation.set(ChatHistoryLocation.Scroll(index: .upperBound, anchorIndex: .upperBound, sourceIndex: .lowerBound, scrollPosition: .top(0.0), animated: true))
    }
    
    public func scrollToMessage(from fromIndex: MessageIndex, to toIndex: MessageIndex, scrollPosition: ListViewScrollPosition = .center(.bottom)) {
        self._chatHistoryLocation.set(ChatHistoryLocation.Scroll(index: .message(toIndex), anchorIndex: .message(toIndex), sourceIndex: .message(fromIndex), scrollPosition: .center(.bottom), animated: true))
    }
    
    public func messageInCurrentHistoryView(_ id: MessageId) -> Message? {
        if let historyView = self.historyView {
            for case let .MessageEntry(message, _, _, _, _, _) in historyView.filteredEntries where message.id == id {
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
                    let loadState: ChatHistoryNodeLoadState
                    if transition.historyView.filteredEntries.isEmpty {
                        loadState = .empty
                    } else {
                        loadState = .messages
                    }
                    if strongSelf.loadState != loadState {
                        strongSelf.loadState = loadState
                        strongSelf.loadStateUpdated?(loadState, false)
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
            
            let completion: (GridNodeDisplayedItemRange) -> Void = { [weak self] visibleRange in
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
                        strongSelf.loadStateUpdated?(loadState, false)
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
                    updateLayout = GridNodeUpdateLayout(layout: GridNodeLayout(size: updateSizeAndInsets.size, insets: updateSizeAndInsets.insets, preloadSize: 400.0, type: .fixed(itemSize: CGSize(width: 200.0, height: 200.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: .immediate)
                }
                
                self.transaction(GridNodeTransaction(deleteItems: mappedTransition.deleteItems, insertItems: mappedTransition.insertItems, updateItems: mappedTransition.updateItems, scrollToItem: mappedTransition.scrollToItem, updateLayout: updateLayout, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: mappedTransition.topOffsetWithinMonth), completion: completion)
            } else {
                self.transaction(GridNodeTransaction(deleteItems: transition.deleteItems, insertItems: transition.insertItems, updateItems: transition.updateItems, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.topOffsetWithinMonth, synchronousLoads: true), completion: completion)
            }
        }
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets) {
        self.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: updateSizeAndInsets.size, insets: updateSizeAndInsets.insets, preloadSize: 400.0, type: gridNodeLayoutForContainerLayout(size: updateSizeAndInsets.size)), transition: .immediate), itemTransition: .immediate, stationaryItems: .none,updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueHistoryViewTransition()
        }
        
    }
    
    public func disconnect() {
        self.historyDisposable.set(nil)
    }
    
    private var selectionPanState: (selecting: Bool, currentMessageId: MessageId)?
    
    @objc private func panGesture(_ recognizer: UIGestureRecognizer) -> Void {
        guard let selectionState = self.controllerInteraction.selectionState else {return}
        
        switch recognizer.state {
            case .began:
                if let itemNode = self.itemNodeAtPoint(recognizer.location(in: self.view)) as? GridMessageItemNode, let messageId = itemNode.messageId {
                    self.selectionPanState = (selecting: !selectionState.selectedIds.contains(messageId), currentMessageId: messageId)
                    self.controllerInteraction.toggleMessagesSelection([messageId], !selectionState.selectedIds.contains(messageId))
                }
            case .changed:
                if let selectionPanState = self.selectionPanState, let itemNode = self.itemNodeAtPoint(recognizer.location(in: self.view)) as? GridMessageItemNode, let messageId = itemNode.messageId, messageId != selectionPanState.currentMessageId {
                    self.controllerInteraction.toggleMessagesSelection([messageId], selectionPanState.selecting)
                    self.selectionPanState?.currentMessageId = messageId
                }
            case .ended, .failed, .cancelled:
                self.selectionPanState = nil
            case .possible:
                break
        }
    }
}
