import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit

private enum ChatControllerScrollPosition {
    case Unread(index: MessageIndex)
    case Index(index: MessageIndex, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool)
}

private enum ChatHistoryViewUpdateType {
    case Initial(fadeIn: Bool)
    case Generic(type: ViewUpdateType)
}

private enum ChatHistoryViewUpdate {
    case Loading
    case HistoryView(view: MessageHistoryView, type: ChatHistoryViewUpdateType, scrollPosition: ChatControllerScrollPosition?)
}

private struct ChatHistoryView {
    let originalView: MessageHistoryView
    let filteredEntries: [ChatHistoryEntry]
}

private enum ChatHistoryViewTransitionReason {
    case Initial(fadeIn: Bool)
    case InteractiveChanges
    case HoleChanges(filledHoleDirections: [MessageIndex: HoleFillDirection], removeHoleDirections: [MessageIndex: HoleFillDirection])
    case Reload
}

private struct ChatHistoryViewTransition {
    let historyView: ChatHistoryView
    let deleteItems: [ListViewDeleteItem]
    let insertItems: [ListViewInsertItem]
    let updateItems: [ListViewUpdateItem]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
}

private func messageHistoryViewForLocation(_ location: ChatHistoryLocation, account: Account, peerId: PeerId, fixedCombinedReadState: CombinedPeerReadState?, tagMask: MessageTags?) -> Signal<ChatHistoryViewUpdate, NoError> {
    switch location {
        case let .Initial(count):
            var preloaded = false
            var fadeIn = false
            return account.viewTracker.aroundUnreadMessageHistoryViewForPeerId(peerId, count: count, tagMask: tagMask) |> map { view, updateType -> ChatHistoryViewUpdate in
                if preloaded {
                    return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil)
                } else {
                    if let maxReadIndex = view.maxReadIndex {
                        var targetIndex = 0
                        for i in 0 ..< view.entries.count {
                            if view.entries[i].index >= maxReadIndex {
                                targetIndex = i
                                break
                            }
                        }
                        
                        let maxIndex = min(view.entries.count, targetIndex + count / 2)
                        if maxIndex >= targetIndex {
                            for i in targetIndex ..< maxIndex {
                                if case .HoleEntry = view.entries[i] {
                                    fadeIn = true
                                    return .Loading
                                }
                            }
                        }
                        
                        preloaded = true
                        return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: .Unread(index: maxReadIndex))
                    } else {
                        preloaded = true
                        return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: nil)
                    }
                }
            }
        case let .InitialSearch(messageId, count):
            var preloaded = false
            var fadeIn = false
            return account.viewTracker.aroundIdMessageHistoryViewForPeerId(peerId, count: count, messageId: messageId, tagMask: tagMask) |> map { view, updateType -> ChatHistoryViewUpdate in
                if preloaded {
                    return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil)
                } else {
                    let anchorIndex = view.anchorIndex
                    
                    var targetIndex = 0
                    for i in 0 ..< view.entries.count {
                        if view.entries[i].index >= anchorIndex {
                            targetIndex = i
                            break
                        }
                    }
                    
                    let maxIndex = min(view.entries.count, targetIndex + count / 2)
                    if maxIndex >= targetIndex {
                        for i in targetIndex ..< maxIndex {
                            if case .HoleEntry = view.entries[i] {
                                fadeIn = true
                                return .Loading
                            }
                        }
                    }
                    
                    preloaded = true
                    //case Index(index: MessageIndex, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool)
                    return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: .Index(index: anchorIndex, position: .Center(.Bottom), directionHint: .Down, animated: false))
                }
            }
        case let .Navigation(index, anchorIndex):
            trace("messageHistoryViewForLocation navigation \(index.id.id)")
            var first = true
            return account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: index, count: 140, anchorIndex: anchorIndex, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask) |> map { view, updateType -> ChatHistoryViewUpdate in
                let genericType: ViewUpdateType
                if first {
                    first = false
                    genericType = ViewUpdateType.UpdateVisible
                } else {
                    genericType = updateType
                }
                return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: nil)
            }
        case let .Scroll(index, anchorIndex, sourceIndex, scrollPosition, animated):
            let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
            let chatScrollPosition = ChatControllerScrollPosition.Index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
            var first = true
            return account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: index, count: 140, anchorIndex: anchorIndex, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask) |> map { view, updateType -> ChatHistoryViewUpdate in
                let genericType: ViewUpdateType
                let scrollPosition: ChatControllerScrollPosition? = first ? chatScrollPosition : nil
                if first {
                    first = false
                    genericType = ViewUpdateType.UpdateVisible
                } else {
                    genericType = updateType
                }
                return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: scrollPosition)
            }
    }
}

private func historyEntriesForView(_ view: MessageHistoryView) -> [ChatHistoryEntry] {
    var entries: [ChatHistoryEntry] = []
    
    for entry in view.entries {
        switch entry {
        case let .HoleEntry(hole, _):
            entries.append(.HoleEntry(hole))
        case let .MessageEntry(message, _):
            entries.append(.MessageEntry(message))
        }
    }
    
    if let maxReadIndex = view.maxReadIndex {
        var inserted = false
        var i = 0
        let unreadEntry: ChatHistoryEntry = .UnreadEntry(maxReadIndex)
        for entry in entries {
            if entry > unreadEntry {
                entries.insert(unreadEntry, at: i)
                inserted = true
                
                break
            }
            i += 1
        }
        if !inserted {
            //entries.append(.UnreadEntry(maxReadIndex))
        }
    }
    
    return entries
}

private func preparedHistoryViewTransition(from fromView: ChatHistoryView?, to toView: ChatHistoryView, reason: ChatHistoryViewTransitionReason, account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, scrollPosition: ChatControllerScrollPosition?) -> Signal<ChatHistoryViewTransition, NoError> {
    return Signal { subscriber in
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromView?.filteredEntries ?? [], rightList: toView.filteredEntries)
        
        var adjustedDeleteIndices: [ListViewDeleteItem] = []
        let previousCount: Int
        if let fromView = fromView {
            previousCount = fromView.filteredEntries.count
        } else {
            previousCount = 0;
        }
        for index in deleteIndices {
            adjustedDeleteIndices.append(ListViewDeleteItem(index: previousCount - 1 - index, directionHint: nil))
        }
        
        var adjustedIndicesAndItems: [ListViewInsertItem] = []
        var adjustedUpdateItems: [ListViewUpdateItem] = []
        let updatedCount = toView.filteredEntries.count
        
        var options: ListViewDeleteAndInsertOptions = []
        var maxAnimatedInsertionIndex = -1
        var stationaryItemRange: (Int, Int)?
        var scrollToItem: ListViewScrollToItem?
        
        switch reason {
            case let .Initial(fadeIn):
                if fadeIn {
                    let _ = options.insert(.AnimateAlpha)
                } else {
                    let _ = options.insert(.LowLatency)
                    let _ = options.insert(.Synchronous)
                }
            case .InteractiveChanges:
                let _ = options.insert(.AnimateAlpha)
                let _ = options.insert(.AnimateInsertion)
                
                for (index, _, _) in indicesAndItems.sorted(by: { $0.0 > $1.0 }) {
                    let adjustedIndex = updatedCount - 1 - index
                    if adjustedIndex == maxAnimatedInsertionIndex + 1 {
                        maxAnimatedInsertionIndex += 1
                    }
                }
            case .Reload:
                break
            case let .HoleChanges(filledHoleDirections, removeHoleDirections):
                if let (_, removeDirection) = removeHoleDirections.first {
                    switch removeDirection {
                    case .LowerToUpper:
                        var holeIndex: MessageIndex?
                        for (index, _) in filledHoleDirections {
                            if holeIndex == nil || index < holeIndex! {
                                holeIndex = index
                            }
                        }
                        
                        if let holeIndex = holeIndex {
                            for i in 0 ..< toView.filteredEntries.count {
                                if toView.filteredEntries[i].index >= holeIndex {
                                    let index = toView.filteredEntries.count - 1 - (i - 1)
                                    stationaryItemRange = (index, Int.max)
                                    break
                                }
                            }
                        }
                    case .UpperToLower:
                        break
                    case .AroundIndex:
                        break
                    }
                }
        }
        
        for (index, entry, previousIndex) in indicesAndItems {
            let adjustedIndex = updatedCount - 1 - index
            
            let adjustedPrevousIndex: Int?
            if let previousIndex = previousIndex {
                adjustedPrevousIndex = previousCount - 1 - previousIndex
            } else {
                adjustedPrevousIndex = nil
            }
            
            var directionHint: ListViewItemOperationDirectionHint?
            if maxAnimatedInsertionIndex >= 0 && adjustedIndex <= maxAnimatedInsertionIndex {
                directionHint = .Down
            }
            
            switch entry {
                case let .MessageEntry(message):
                    adjustedIndicesAndItems.append(ListViewInsertItem(index: adjustedIndex, previousIndex: adjustedPrevousIndex, item: ChatMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message), directionHint: directionHint))
                case .HoleEntry:
                    adjustedIndicesAndItems.append(ListViewInsertItem(index: adjustedIndex, previousIndex: adjustedPrevousIndex, item: ChatHoleItem(), directionHint: directionHint))
                case .UnreadEntry:
                    adjustedIndicesAndItems.append(ListViewInsertItem(index: adjustedIndex, previousIndex: adjustedPrevousIndex, item: ChatUnreadItem(), directionHint: directionHint))
            }
        }
        
        for (index, entry) in updateIndices {
            let adjustedIndex = updatedCount - 1 - index
            
            let directionHint: ListViewItemOperationDirectionHint? = nil
            
            switch entry {
                case let .MessageEntry(message):
                    adjustedUpdateItems.append(ListViewUpdateItem(index: adjustedIndex, item: ChatMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: message), directionHint: directionHint))
                case .HoleEntry:
                    adjustedUpdateItems.append(ListViewUpdateItem(index: adjustedIndex, item: ChatHoleItem(), directionHint: directionHint))
                case .UnreadEntry:
                    adjustedUpdateItems.append(ListViewUpdateItem(index: adjustedIndex, item: ChatUnreadItem(), directionHint: directionHint))
            }
        }
        
        if let scrollPosition = scrollPosition {
            switch scrollPosition {
            case let .Unread(unreadIndex):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if case .UnreadEntry = entry {
                        scrollToItem = ListViewScrollToItem(index: index, position: .Bottom, animated: false, curve: .Default, directionHint: .Down)
                        break
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    var index = toView.filteredEntries.count - 1
                    for entry in toView.filteredEntries {
                        if entry.index >= unreadIndex {
                            scrollToItem = ListViewScrollToItem(index: index, position: .Bottom, animated: false, curve: .Default,  directionHint: .Down)
                            break
                        }
                        index -= 1
                    }
                }
                
                if scrollToItem == nil {
                    var index = 0
                    for entry in toView.filteredEntries.reversed() {
                        if entry.index < unreadIndex {
                            scrollToItem = ListViewScrollToItem(index: index, position: .Bottom, animated: false, curve: .Default, directionHint: .Down)
                            break
                        }
                        index += 1
                    }
                }
            case let .Index(scrollIndex, position, directionHint, animated):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if entry.index >= scrollIndex {
                        scrollToItem = ListViewScrollToItem(index: index, position: position, animated: animated, curve: .Default, directionHint: directionHint)
                        break
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    var index = 0
                    for entry in toView.filteredEntries.reversed() {
                        if entry.index < scrollIndex {
                            scrollToItem = ListViewScrollToItem(index: index, position: position, animated: animated, curve: .Default, directionHint: directionHint)
                            break
                        }
                        index += 1
                    }
                }
            }
        }
        
        subscriber.putNext(ChatHistoryViewTransition(historyView: toView, deleteItems: adjustedDeleteIndices, insertItems: adjustedIndicesAndItems, updateItems: adjustedUpdateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: stationaryItemRange))
        subscriber.putCompletion()
        
        return EmptyDisposable
    }
}

private func maxIncomingMessageIdForEntries(_ entries: [ChatHistoryEntry], indexRange: (Int, Int)) -> MessageId? {
    for i in (indexRange.0 ... indexRange.1).reversed() {
        if case let .MessageEntry(message) = entries[i], message.flags.contains(.Incoming) {
            return message.id
        }
    }
    return nil
}

private var useDarkMode = false

class ChatController: ViewController {
    private var containerLayout = ContainerViewLayout()
    
    private let account: Account
    private let peerId: PeerId
    private let messageId: MessageId?

    private var historyView: ChatHistoryView?
    
    private let peerDisposable = MetaDisposable()
    private let historyDisposable = MetaDisposable()
    private let readHistoryDisposable = MetaDisposable()
    
    private let messageViewQueue = Queue()
    
    private let messageIndexDisposable = MetaDisposable()
    
    private var enqueuedHistoryViewTransition: (ChatHistoryViewTransition, () -> Void)?
    private var layoutActionOnViewTransition: (() -> Void)?
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let maxVisibleIncomingMessageId = Promise<MessageId>()
    private let canReadHistory = Promise<Bool>()
    
    private let _chatHistoryLocation = Promise<ChatHistoryLocation>()
    private var chatHistoryLocation: Signal<ChatHistoryLocation, NoError> {
        return self._chatHistoryLocation.get()
    }
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    private var controllerInteraction: ChatControllerInteraction?
    
    init(account: Account, peerId: PeerId, messageId: MessageId? = nil) {
        self.account = account
        self.peerId = peerId
        self.messageId = messageId
        
        super.init()
        
        self.setupThemeWithDarkMode(useDarkMode)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf._chatHistoryLocation.set(.single(ChatHistoryLocation.Scroll(index: MessageIndex.lowerBound(peerId: strongSelf.peerId), anchorIndex: MessageIndex.lowerBound(peerId: strongSelf.peerId), sourceIndex: MessageIndex.upperBound(peerId: strongSelf.peerId), scrollPosition: .Bottom, animated: true)))
            }
        }
        
        let controllerInteraction = ChatControllerInteraction(openMessage: { [weak self] id in
            if let strongSelf = self, let historyView = strongSelf.historyView {
                var galleryMedia: Media?
                for case let .MessageEntry(message) in historyView.filteredEntries where message.id == id {
                    for media in message.media {
                        if let file = media as? TelegramMediaFile {
                            galleryMedia = file
                        } else if let image = media as? TelegramMediaImage {
                            galleryMedia = image
                        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                            if let file = content.file {
                                galleryMedia = file
                            } else if let image = content.image {
                                galleryMedia = image
                            }
                        }
                    }
                    break
                }
                
                if let galleryMedia = galleryMedia {
                    if let file = galleryMedia as? TelegramMediaFile, file.mimeType == "audio/mpeg" {
                        debugPlayMedia(account: strongSelf.account, file: file)
                    } else {
                        let gallery = GalleryController(account: strongSelf.account, messageId: id)
                        
                        strongSelf.galleryHiddenMesageAndMediaDisposable.set(gallery.hiddenMedia.start(next: { [weak strongSelf] messageIdAndMedia in
                            if let strongSelf = strongSelf {
                                if let messageIdAndMedia = messageIdAndMedia {
                                    strongSelf.controllerInteraction?.hiddenMedia = [messageIdAndMedia.0: [messageIdAndMedia.1]]
                                } else {
                                    strongSelf.controllerInteraction?.hiddenMedia = [:]
                                }
                                strongSelf.chatDisplayNode.listView.forEachItemNode { itemNode in
                                    if let itemNode = itemNode as? ChatMessageItemView {
                                        itemNode.updateHiddenMedia()
                                    }
                                }
                            }
                        }))
                        
                        strongSelf.present(gallery, in: .window, with: GalleryControllerPresentationArguments(transitionNode: { [weak self] messageId, media in
                            if let strongSelf = self {
                                var transitionNode: ASDisplayNode?
                                strongSelf.chatDisplayNode.listView.forEachItemNode { itemNode in
                                    if let itemNode = itemNode as? ChatMessageItemView {
                                        if let result = itemNode.transitionNode(id: messageId, media: media) {
                                            transitionNode = result
                                        }
                                    }
                                }
                                return transitionNode
                            }
                            return nil
                        }))
                    }
                }
            }
        }, testNavigateToMessage: { [weak self] fromId, id in
            if let strongSelf = self, let historyView = strongSelf.historyView {
                var fromIndex: MessageIndex?
                
                for case let .MessageEntry(message) in historyView.filteredEntries where message.id == fromId {
                    fromIndex = MessageIndex(message)
                    break
                }
                
                if let fromIndex = fromIndex {
                    var found = false
                    for case let .MessageEntry(message) in historyView.filteredEntries where message.id == id {
                        found = true
                        
                        strongSelf._chatHistoryLocation.set(.single(ChatHistoryLocation.Scroll(index: MessageIndex(message), anchorIndex: MessageIndex(message), sourceIndex: fromIndex, scrollPosition: .Center(.Bottom), animated: true)))
                    }
                    
                    if !found {
                        strongSelf.messageIndexDisposable.set((strongSelf.account.postbox.messageIndexAtId(id) |> deliverOnMainQueue).start(next: { [weak strongSelf] index in
                            if let strongSelf = strongSelf, let index = index {
                                strongSelf._chatHistoryLocation.set(.single(ChatHistoryLocation.Scroll(index:index, anchorIndex: index, sourceIndex: fromIndex, scrollPosition: .Center(.Bottom), animated: true)))
                            }
                        }))
                    }
                }
            }
        })
        
        self.controllerInteraction = controllerInteraction
        
        let messageViewQueue = self.messageViewQueue
        
        peerDisposable.set((account.postbox.peerWithId(peerId)
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                if let strongSelf = self {
                    strongSelf.title = peer.displayTitle
                }
            }))
        
        let fixedCombinedReadState = Atomic<CombinedPeerReadState?>(value: nil)
        
        let historyViewUpdate = self.chatHistoryLocation
            |> distinctUntilChanged
            |> mapToSignal { location in
                return messageHistoryViewForLocation(location, account: account, peerId: peerId, fixedCombinedReadState: fixedCombinedReadState.with { $0 }, tagMask: nil) |> beforeNext { viewUpdate in
                    switch viewUpdate {
                        case let .HistoryView(view, _, _):
                            let _ = fixedCombinedReadState.swap(view.combinedReadState)
                        default:
                            break
                    }
                }
            }
        
        let previousView = Atomic<ChatHistoryView?>(value: nil)
        
        let historyViewTransition = historyViewUpdate |> mapToQueue { [weak self] update -> Signal<ChatHistoryViewTransition, NoError> in
            switch update {
                case .Loading:
                    Queue.mainQueue().async { [weak self] in
                        if let strongSelf = self {
                            if !strongSelf.didSetReady {
                                strongSelf.didSetReady = true
                                strongSelf._ready.set(.single(true))
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
                    
                    let processedView = ChatHistoryView(originalView: view, filteredEntries: historyEntriesForView(view))
                    let previous = previousView.swap(processedView)
                    
                    return preparedHistoryViewTransition(from: previous, to: processedView, reason: reason, account: account, peerId: peerId, controllerInteraction: controllerInteraction, scrollPosition: scrollPosition) |> runOn( prepareOnMainQueue ? Queue.mainQueue() : messageViewQueue)
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
                        if previousId < messageId {
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
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.historyDisposable.dispose()
        self.readHistoryDisposable.dispose()
        self.messageIndexDisposable.dispose()
        self.galleryHiddenMesageAndMediaDisposable.dispose()
    }
    
    private func setupThemeWithDarkMode(_ darkMode: Bool) {
        if darkMode {
            self.statusBar.style = .White
            self.navigationBar.backgroundColor = UIColor(white: 0.0, alpha: 0.9)
            self.navigationBar.foregroundColor = UIColor.white
            self.navigationBar.accentColor = UIColor.white
            self.navigationBar.stripeColor = UIColor.black
        } else {
            self.statusBar.style = .Black
            self.navigationBar.backgroundColor = UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0)
            self.navigationBar.foregroundColor = UIColor.black
            self.navigationBar.accentColor = UIColor(0x1195f2)
            self.navigationBar.stripeColor = UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
        }
    }
    
    var chatDisplayNode: ChatControllerNode {
        get {
            return super.displayNode as! ChatControllerNode
        }
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChatControllerNode(account: self.account, peerId: self.peerId)
        
        self.chatDisplayNode.listView.displayedItemRangeChanged = { [weak self] displayedRange in
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
        
        self.chatDisplayNode.listView.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self {
                if let offset = offset, offset < 40.0 {
                    if strongSelf.chatDisplayNode.navigateToLatestButton.alpha == 1.0 {
                        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.beginFromCurrentState], animations: {
                            strongSelf.chatDisplayNode.navigateToLatestButton.alpha = 0.0
                        }, completion: nil)
                    }
                } else {
                    if strongSelf.chatDisplayNode.navigateToLatestButton.alpha == 0.0 {
                        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.beginFromCurrentState], animations: {
                            strongSelf.chatDisplayNode.navigateToLatestButton.alpha = 1.0
                        }, completion: nil)
                    }
                }
            }
        }
        
        self.chatDisplayNode.requestLayout = { [weak self] animated in
            self?.requestLayout(transition: animated ? .animated(duration: 0.1, curve: .easeInOut) : .immediate)
        }
        
        self.chatDisplayNode.setupSendActionOnViewUpdate = { [weak self] f in
            self?.layoutActionOnViewTransition = f
        }
        
        self.chatDisplayNode.displayAttachmentMenu = { [weak self] in
            if let strongSelf = self {
                let controller = ChatMediaActionSheetController()
                controller.location = { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        let mapInputController = MapInputController()
                        strongSelf.present(mapInputController, in: .window)
                    }
                }
                controller.contacts = { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        useDarkMode = !useDarkMode
                        strongSelf.setupThemeWithDarkMode(useDarkMode)
                    }
                }
                strongSelf.present(controller, in: .window)
            }
        }
        
        self.chatDisplayNode.navigateToLatestButton.tapped = { [weak self] in
            if let strongSelf = self {
                strongSelf._chatHistoryLocation.set(.single(ChatHistoryLocation.Scroll(index: MessageIndex.upperBound(peerId: strongSelf.peerId), anchorIndex: MessageIndex.upperBound(peerId: strongSelf.peerId), sourceIndex: MessageIndex.lowerBound(peerId: strongSelf.peerId), scrollPosition: .Top, animated: true)))
            }
        }
        
        self.displayNodeDidLoad()
        
        self.dequeueHistoryViewTransition()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.chatDisplayNode.listView.preloadPages = true
        self.canReadHistory.set(.single(true))
    }
    
    private func enqueueHistoryViewTransition(_ transition: ChatHistoryViewTransition) -> Signal<Void, NoError> {
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
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(.single(true))
                    }
                }
            } else {
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        } |> runOn(Queue.mainQueue())
    }
    
    private func updateMaxVisibleReadIncomingMessageId(_ id: MessageId) {
        self.maxVisibleIncomingMessageId.set(.single(id))
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
                    
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(.single(true))
                    }
                    
                    completion()
                }
            }
            
            if let layoutActionOnViewTransition = self.layoutActionOnViewTransition {
                self.layoutActionOnViewTransition = nil
                layoutActionOnViewTransition()
                
                self.chatDisplayNode.containerLayoutUpdated(self.containerLayout, navigationBarHeight: self.navigationBar.frame.maxY, transition: .animated(duration: 0.5 * 1.3, curve: .spring), listViewTransaction: { updateSizeAndInsets in
                    var options = transition.options
                    let _ = options.insert(.Synchronous)
                    let _ = options.insert(.LowLatency)
                    options.remove(.AnimateInsertion)
                    
                    let deleteItems = transition.deleteItems.map({ item in
                        return ListViewDeleteItem(index: item.index, directionHint: nil)
                    })
                    
                    var maxInsertedItem: Int?
                    var insertItems: [ListViewInsertItem] = []
                    for i in 0 ..< transition.insertItems.count {
                        let item = transition.insertItems[i]
                        if item.directionHint == .Down && (maxInsertedItem == nil || maxInsertedItem! < item.index) {
                            maxInsertedItem = item.index
                        }
                        insertItems.append(ListViewInsertItem(index: item.index, previousIndex: item.previousIndex, item: item.item, directionHint: item.directionHint == .Down ? .Up : nil))
                    }
                    
                    let scrollToItem = ListViewScrollToItem(index: 0, position: .Top, animated: true, curve: .Spring(speed: 1.3), directionHint: .Up)
                    
                    var stationaryItemRange: (Int, Int)?
                    if let maxInsertedItem = maxInsertedItem {
                        stationaryItemRange = (maxInsertedItem + 1, Int.max)
                    }
                    
                    self.chatDisplayNode.listView.deleteAndInsertItems(deleteIndices: deleteItems, insertIndicesAndItems: insertItems, updateIndicesAndItems: transition.updateItems, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: stationaryItemRange, completion: completion)
                })
            } else {
                self.chatDisplayNode.listView.deleteAndInsertItems(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, completion: completion)
            }
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.containerLayout = layout
        
        self.chatDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationBar.frame.maxY, transition: transition,  listViewTransaction: { updateSizeAndInsets in
            self.chatDisplayNode.listView.deleteAndInsertItems(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, completion: { _ in })
        })
    }
}
