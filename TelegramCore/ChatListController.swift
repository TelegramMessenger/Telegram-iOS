import UIKit
import Postbox
import SwiftSignalKit
import Display

enum ChatListMessageViewPosition: Equatable {
    case Tail(count: Int)
    case Around(index: MessageIndex, anchorIndex: MessageIndex, scrollPosition: ListViewScrollPosition?)
}

func ==(lhs: ChatListMessageViewPosition, rhs: ChatListMessageViewPosition) -> Bool {
    switch lhs {
        case let .Tail(lhsCount):
            switch rhs {
                case let .Tail(rhsCount) where lhsCount == rhsCount:
                    return true
                default:
                    return false
            }
        case let .Around(lhsId, lhsAnchorIndex, lhsScrollPosition):
            switch rhs {
                case let .Around(rhsId, rhsAnchorIndex, rhsScrollPosition) where lhsId == rhsId && lhsAnchorIndex == rhsAnchorIndex && lhsScrollPosition == rhsScrollPosition:
                    return true
                default:
                    return false
            }
    }
}

private enum ChatListControllerEntryId: Hashable {
    case Search
    case PeerId(Int64)
    
    var hashValue: Int {
        switch self {
            case .Search:
                return 0
            case let .PeerId(peerId):
                return peerId.hashValue
        }
    }
}

private func <(lhs: ChatListControllerEntryId, rhs: ChatListControllerEntryId) -> Bool {
    return lhs.hashValue < rhs.hashValue
}

private func ==(lhs: ChatListControllerEntryId, rhs: ChatListControllerEntryId) -> Bool {
    switch lhs {
        case .Search:
            switch rhs {
                case .Search:
                    return true
                default:
                    return false
            }
        case let .PeerId(lhsId):
            switch rhs {
                case let .PeerId(rhsId):
                    return lhsId == rhsId
                default:
                    return false
            }
    }
}

private enum ChatListControllerEntry: Comparable, Identifiable {
    case SearchEntry
    case MessageEntry(Message, Int)
    case HoleEntry(ChatListHole)
    case Nothing(MessageIndex)
    
    var index: MessageIndex {
        switch self {
            case .SearchEntry:
                return MessageIndex.absoluteUpperBound()
            case let .MessageEntry(message, _):
                return MessageIndex(message)
            case let .HoleEntry(hole):
                return hole.index
            case let .Nothing(index):
                return index
        }
    }
    
    var stableId: ChatListControllerEntryId {
        switch self {
            case .SearchEntry:
                return .Search
            default:
                return .PeerId(self.index.id.peerId.toInt64())
        }
    }
}

private func <(lhs: ChatListControllerEntry, rhs: ChatListControllerEntry) -> Bool {
    return lhs.index < rhs.index
}

private func ==(lhs: ChatListControllerEntry, rhs: ChatListControllerEntry) -> Bool {
    switch lhs {
        case .SearchEntry:
            switch rhs {
                case .SearchEntry:
                    return true
                default:
                    return false
            }
        case let .MessageEntry(lhsMessage, lhsUnreadCount):
            switch rhs {
                case let .MessageEntry(rhsMessage, rhsUnreadCount):
                    return lhsMessage.id == rhsMessage.id && lhsMessage.flags == rhsMessage.flags && lhsUnreadCount == rhsUnreadCount
                default:
                    break
            }
        case let .HoleEntry(lhsHole):
            switch rhs {
                case let .HoleEntry(rhsHole):
                    return lhsHole == rhsHole
                default:
                    return false
            }
        case let .Nothing(lhsIndex):
            switch rhs {
                case let .Nothing(rhsIndex):
                    return lhsIndex == rhsIndex
                default:
                    return false
            }
    }
    return false
}

extension ChatListEntry: Identifiable {
    var stableId: Int64 {
        return self.index.id.peerId.toInt64()
    }
}

class ChatListController: ViewController {
    let account: Account
    
    private var chatListViewAndEntries: (ChatListView, [ChatListControllerEntry])?
    
    var chatListPosition: ChatListMessageViewPosition?
    let chatListDisposable: MetaDisposable = MetaDisposable()
    
    let messageViewQueue = Queue()
    let messageViewTransactionQueue = ListViewTransactionQueue()
    var settingView = false
    
    let openMessageFromSearchDisposable: MetaDisposable = MetaDisposable()
    
    var chatListDisplayNode: ChatListControllerNode {
        get {
            return super.displayNode as! ChatListControllerNode
        }
    }
    
    init(account: Account) {
        self.account = account
        
        super.init()
        
        self.title = "Chats"
        self.tabBarItem.title = "Chats"
        self.tabBarItem.image = UIImage(named: "Chat List/Tabs/IconChats")
        self.tabBarItem.selectedImage = UIImage(named: "Chat List/Tabs/IconChatsSelected")
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(self.editPressed))
        //self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Compose, target: self, action: Selector("composePressed"))
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let (view, _) = strongSelf.chatListViewAndEntries, view.laterIndex == nil {
                    strongSelf.chatListDisplayNode.listView.deleteAndInsertItems(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: ListViewScrollToItem(index: 0, position: .Top, animated: true, curve: .Default, directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, completion: { _ in })
                } else {
                    strongSelf.setMessageViewPosition(.Around(index: MessageIndex.absoluteUpperBound(), anchorIndex: MessageIndex.absoluteUpperBound(), scrollPosition: .Top), hint: "later", force: true)
                }
            }
        }
        
        self.setMessageViewPosition(.Tail(count: 50), hint: "initial", force: false)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.chatListDisposable.dispose()
        self.openMessageFromSearchDisposable.dispose()
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChatListControllerNode(account: self.account)
        
        self.chatListDisplayNode.listView.displayedItemRangeChanged = { [weak self] range in
            if let strongSelf = self, !strongSelf.settingView {
                if let range = range.loadedRange, let (view, _) = strongSelf.chatListViewAndEntries {
                    if range.firstIndex < 5 && view.laterIndex != nil {
                        strongSelf.setMessageViewPosition(.Around(index: view.entries[view.entries.count - 1].index, anchorIndex: MessageIndex.absoluteUpperBound(), scrollPosition: nil), hint: "later", force: false)
                    } else if range.firstIndex >= 5 && range.lastIndex >= view.entries.count - 5 && view.earlierIndex != nil {
                        strongSelf.setMessageViewPosition(.Around(index: view.entries[0].index, anchorIndex: MessageIndex.absoluteUpperBound(), scrollPosition: nil), hint: "earlier", force: false)
                    }
                }
            }
        }
        
        self.chatListDisplayNode.navigationBar = self.navigationBar
        
        self.chatListDisplayNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.chatListDisplayNode.requestOpenMessageFromSearch = { [weak self] peer, messageId in
            if let strongSelf = self {
                let storedPeer = strongSelf.account.postbox.modify { modifier -> Void in
                    if modifier.getPeer(peer.id) == nil {
                        modifier.updatePeers([peer], update: { previousPeer, updatedPeer in
                            return updatedPeer
                        })
                    }
                }
                strongSelf.openMessageFromSearchDisposable.set((storedPeer |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: messageId.peerId, messageId: messageId))
                    }
                }))
            }
        }
        
        self.chatListDisplayNode.requestOpenPeerFromSearch = { [weak self] peerId in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peerId))
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    private func setMessageViewPosition(_ position: ChatListMessageViewPosition, hint: String, force: Bool) {
        if self.chatListPosition == nil || self.chatListPosition! != position || force {
            let signal: Signal<(ChatListView, ViewUpdateType), NoError>
            self.chatListPosition = position
            var scrollPosition: (MessageIndex, ListViewScrollPosition, ListViewScrollToItemDirectionHint)?
            switch position {
                case let .Tail(count):
                    signal = self.account.postbox.tailChatListView(count)
                case let .Around(index, _, position):
                    trace("request around \(index.id.id) \(hint)")
                    signal = self.account.postbox.aroundChatListView(index, count: 80)
                    if let position = position {
                        var directionHint: ListViewScrollToItemDirectionHint = .Up
                        if let visibleItemRange = self.chatListDisplayNode.listView.displayedItemRange.loadedRange, let (_, entries) = self.chatListViewAndEntries {
                            if visibleItemRange.firstIndex >= 0 && visibleItemRange.firstIndex < entries.count {
                                if entries[visibleItemRange.firstIndex].index < index {
                                    directionHint = .Up
                                } else {
                                    directionHint = .Down
                                }
                            }
                        }
                        scrollPosition = (index, position, directionHint)
                    }
            }
            
            var firstTime = true
            chatListDisposable.set((
                signal |> deliverOnMainQueue
            ).start(next: {[weak self] (view, updateType) in
                if let strongSelf = self {
                    let animated: Bool
                    switch updateType {
                        case .Generic:
                            animated = !firstTime
                        case .FillHole:
                            animated = false
                        case .InitialUnread:
                            animated = false
                        case .UpdateVisible:
                            animated = false
                    }
                    
                    strongSelf.setPeerView(view, firstTime: strongSelf.chatListViewAndEntries == nil, scrollPosition: firstTime ?scrollPosition : nil, animated: animated)
                    firstTime = false
                }
            }))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    private func chatListControllerEntries(_ view: ChatListView) -> [ChatListControllerEntry] {
        var result: [ChatListControllerEntry] = []
        for entry in view.entries {
            switch entry {
                case let .MessageEntry(message, unreadCount):
                    result.append(.MessageEntry(message, unreadCount))
                case let .HoleEntry(hole):
                    result.append(.HoleEntry(hole))
                case let .Nothing(index):
                    result.append(.Nothing(index))
            }
        }
        if view.laterIndex == nil {
            result.append(.SearchEntry)
        }
        return result
    }
    
    private func setPeerView(_ view: ChatListView, firstTime: Bool, scrollPosition: (MessageIndex, ListViewScrollPosition, ListViewScrollToItemDirectionHint)?, animated: Bool) {
        self.messageViewTransactionQueue.addTransaction { [weak self] completed in
            if let strongSelf = self {
                strongSelf.settingView = true
                let currentEntries = strongSelf.chatListViewAndEntries?.1 ?? []
                let viewEntries = strongSelf.chatListControllerEntries(view)
                
                strongSelf.messageViewQueue.async {
                    //let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: currentEntries, rightList: viewEntries)
                    let (deleteIndices, indicesAndItems) = mergeListsStable(leftList: currentEntries, rightList: viewEntries)
                    let updateIndices: [(Int, ChatListControllerEntry)] = []
                    
                    Queue.mainQueue().async {
                        var adjustedDeleteIndices: [ListViewDeleteItem] = []
                        let previousCount = currentEntries.count
                        if deleteIndices.count != 0 {
                            for index in deleteIndices {
                                adjustedDeleteIndices.append(ListViewDeleteItem(index: previousCount - 1 - index, directionHint: nil))
                            }
                        }
                        
                        let updatedCount = viewEntries.count
                        
                        var maxAnimatedInsertionIndex = -1
                        if animated {
                            for (index, _, _) in indicesAndItems.sorted(by: { $0.0 > $1.0 }) {
                                let adjustedIndex = updatedCount - 1 - index
                                if adjustedIndex == maxAnimatedInsertionIndex + 1 {
                                    maxAnimatedInsertionIndex += 1
                                }
                            }
                        }
                            
                        var adjustedIndicesAndItems: [ListViewInsertItem] = []
                        for (index, entry, previousIndex) in indicesAndItems {
                            let adjustedIndex = updatedCount - 1 - index
                            
                            var adjustedPreviousIndex: Int?
                            if let previousIndex = previousIndex {
                                adjustedPreviousIndex = previousCount - 1 - previousIndex
                            }
                            
                            var directionHint: ListViewItemOperationDirectionHint?
                            if maxAnimatedInsertionIndex >= 0 && adjustedIndex <= maxAnimatedInsertionIndex {
                                directionHint = .Down
                            }
                            
                            switch entry {
                                case .SearchEntry:
                                    adjustedIndicesAndItems.append(ListViewInsertItem(index: updatedCount - 1 - index, previousIndex: adjustedPreviousIndex, item: ChatListSearchItem(placeholder: "Search for messages or users", activate: { [weak self] in
                                        self?.activateSearch()
                                    }), directionHint: directionHint))
                                case let .MessageEntry(message, unreadCount):
                                    adjustedIndicesAndItems.append(ListViewInsertItem(index: adjustedIndex, previousIndex: adjustedPreviousIndex, item: ChatListItem(account: strongSelf.account, message: message, unreadCount: unreadCount, action: { [weak self] message in
                                        if let strongSelf = self {
                                            strongSelf.entrySelected(entry)
                                            strongSelf.chatListDisplayNode.listView.clearHighlightAnimated(true)
                                        }
                                    }), directionHint: directionHint))
                                case .HoleEntry:
                                    adjustedIndicesAndItems.append(ListViewInsertItem(index: updatedCount - 1 - index, previousIndex: adjustedPreviousIndex, item: ChatListHoleItem(), directionHint: directionHint))
                                case .Nothing:
                                    adjustedIndicesAndItems.append(ListViewInsertItem(index: updatedCount - 1 - index, previousIndex: adjustedPreviousIndex, item: ChatListEmptyItem(), directionHint: directionHint))
                            }
                        }
                        
                        var adjustedUpdateItems: [ListViewUpdateItem] = []
                        for (index, entry) in updateIndices {
                            let adjustedIndex = updatedCount - 1 - index
                            
                            let directionHint: ListViewItemOperationDirectionHint? = nil
                            
                            switch entry {
                                case .SearchEntry:
                                    adjustedUpdateItems.append(ListViewUpdateItem(index: updatedCount - 1 - index, item: ChatListSearchItem(placeholder: "Search for messages or users", activate: { [weak self] in
                                        self?.activateSearch()
                                    }), directionHint: directionHint))
                                case let .MessageEntry(message, unreadCount):
                                    adjustedUpdateItems.append(ListViewUpdateItem(index: adjustedIndex, item: ChatListItem(account: strongSelf.account, message: message, unreadCount: unreadCount, action: { [weak self] message in
                                        if let strongSelf = self {
                                            strongSelf.entrySelected(entry)
                                            strongSelf.chatListDisplayNode.listView.clearHighlightAnimated(true)
                                        }
                                        }), directionHint: directionHint))
                                case .HoleEntry:
                                    adjustedUpdateItems.append(ListViewUpdateItem(index: updatedCount - 1 - index, item: ChatListHoleItem(), directionHint: directionHint))
                                case .Nothing:
                                    adjustedUpdateItems.append(ListViewUpdateItem(index: updatedCount - 1 - index, item: ChatListEmptyItem(), directionHint: directionHint))
                            }
                        }
                        
                        if !adjustedDeleteIndices.isEmpty || !adjustedIndicesAndItems.isEmpty || !adjustedUpdateItems.isEmpty || scrollPosition != nil {
                            var options: ListViewDeleteAndInsertOptions = []
                            if firstTime {
                            } else {
                                let _ = options.insert(.AnimateAlpha)
                                
                                if animated {
                                    let _ = options.insert(.AnimateInsertion)
                                }
                            }
                            
                            var scrollToItem: ListViewScrollToItem?
                            if let (itemIndex, itemPosition, directionHint) = scrollPosition {
                                var index = viewEntries.count - 1
                                for entry in viewEntries {
                                    if entry.index >= itemIndex {
                                        scrollToItem = ListViewScrollToItem(index: index, position: itemPosition, animated: true, curve: .Default, directionHint: directionHint)
                                        break
                                    }
                                    index -= 1
                                }
                                
                                if scrollToItem == nil {
                                    var index = 0
                                    for entry in viewEntries.reversed() {
                                        if entry.index < itemIndex {
                                            scrollToItem = ListViewScrollToItem(index: index, position: itemPosition, animated: true, curve: .Default, directionHint: directionHint)
                                            break
                                        }
                                        index += 1
                                    }
                                }
                            }
                            
                            strongSelf.chatListDisplayNode.listView.deleteAndInsertItems(deleteIndices: adjustedDeleteIndices, insertIndicesAndItems: adjustedIndicesAndItems, updateIndicesAndItems: adjustedUpdateItems, options: options, scrollToItem: scrollToItem, completion: { [weak self] _ in
                                if let strongSelf = self {
                                    strongSelf.ready.set(single(true, NoError.self))
                                    strongSelf.settingView = false
                                    completed()
                                }
                            })
                        } else {
                            strongSelf.ready.set(single(true, NoError.self))
                            strongSelf.settingView = false
                            completed()
                        }
                        
                        strongSelf.chatListViewAndEntries = (view, viewEntries)
                    }
                }
            } else {
                completed()
            }
        }
    }
    
    private func entrySelected(_ entry: ChatListControllerEntry) {
        if case let .MessageEntry(message, _) = entry {
            (self.navigationController as? NavigationController)?.pushViewController(ChatController(account: self.account, peerId: message.id.peerId))
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.chatListDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationBar.frame.maxY, transition: transition)
    }
    
    @objc func editPressed() {
        
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.chatListDisplayNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.chatListDisplayNode.deactivateSearch()
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
}

