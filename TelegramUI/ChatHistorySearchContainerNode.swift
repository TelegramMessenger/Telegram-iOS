import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private enum ChatHistorySearchEntryStableId: Hashable {
    case messageId(MessageId)
    
    static func ==(lhs: ChatHistorySearchEntryStableId, rhs: ChatHistorySearchEntryStableId) -> Bool {
        switch lhs {
            case let .messageId(messageId):
                if case .messageId(messageId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .messageId(messageId):
                return messageId.hashValue
        }
    }
}


private enum ChatHistorySearchEntry: Comparable, Identifiable {
    case message(Message, PresentationTheme, PresentationStrings, PresentationDateTimeFormat)
    
    var stableId: ChatHistorySearchEntryStableId {
        switch self {
            case let .message(message, _, _, _):
                return .messageId(message.id)
        }
    }
    
    static func ==(lhs: ChatHistorySearchEntry, rhs: ChatHistorySearchEntry) -> Bool {
        switch lhs {
            case let .message(lhsMessage, lhsTheme, lhsStrings, lhsDateTimeFormat):
                if case let .message(rhsMessage, rhsTheme, rhsStrings, rhsDateTimeFormat) = rhs {
                    if lhsMessage.id != rhsMessage.id {
                        return false
                    }
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatHistorySearchEntry, rhs: ChatHistorySearchEntry) -> Bool {
        switch lhs {
            case let .message(lhsMessage, _, _, _):
                if case let .message(rhsMessage, _, _, _) = rhs {
                    return MessageIndex(lhsMessage) < MessageIndex(rhsMessage)
                } else {
                    return false
                }
        }
    }
    
    func item(account: Account, peerId: PeerId, interaction: ChatControllerInteraction) -> ListViewItem {
        switch self {
            case let .message(message, theme, strings, dateTimeFormat):
                return ListMessageItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, account: account, chatLocation: .peer(peerId), controllerInteraction: interaction, message: message, selection: .none, displayHeader: true)
        }
    }
}

private struct ChatHistorySearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let displayingResults: Bool
}

private func chatHistorySearchContainerPreparedTransition(from fromEntries: [ChatHistorySearchEntry], to toEntries: [ChatHistorySearchEntry], displayingResults: Bool, account: Account, peerId: PeerId, interaction: ChatControllerInteraction) -> ChatHistorySearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, peerId: peerId, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, peerId: peerId, interaction: interaction), directionHint: nil) }
    
    return ChatHistorySearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, displayingResults: displayingResults)
}

final class ChatHistorySearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var currentEntries: [ChatHistorySearchEntry]?
    
    private let searchQuery = Promise<String?>()
    private let searchQueryDisposable = MetaDisposable()
    private let searchDisposable = MetaDisposable()
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    override var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    private var presentationData: PresentationData
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings, PresentationDateTimeFormat)>
    
    private var enqueuedTransitions: [(ChatHistorySearchContainerTransition, Bool)] = []
    
    init(account: Account, peerId: PeerId, tagMask: MessageTags, interfaceInteraction: ChatControllerInteraction) {
        self.account = account
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings, self.presentationData.dateTimeFormat))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.listNode = ListView()
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        self.listNode.isHidden = true
        
        let themeAndStringsPromise = self.themeAndStringsPromise
        
        let previousEntriesValue = Atomic<[ChatHistorySearchEntry]?>(value: nil)
        
        self.searchQueryDisposable.set((searchQuery.get()
        |> deliverOnMainQueue).start(next: { [weak self] query in
            if let strongSelf = self {
                let signal: Signal<[ChatHistorySearchEntry]?, NoError>
                if let query = query, !query.isEmpty {
                    let foundRemoteMessages: Signal<[Message], NoError> = searchMessages(account: account, location: .peer(peerId: peerId, fromId: nil, tags: tagMask), query: query) |> map {$0.0}
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                    
                    signal = combineLatest(foundRemoteMessages, themeAndStringsPromise.get())
                        |> map { messages, themeAndStrings -> [ChatHistorySearchEntry]? in
                            if messages.isEmpty {
                                return nil
                            } else {
                                return messages.map { message -> ChatHistorySearchEntry in
                                    return .message(message, themeAndStrings.0, themeAndStrings.1, themeAndStrings.2)
                                }
                            }
                    }
                    
                    strongSelf._isSearching.set(true)
                } else {
                    signal = .single(nil)
                    strongSelf._isSearching.set(false)
                }
                
                strongSelf.searchDisposable.set((signal
                    |> deliverOnMainQueue).start(next: { entries in
                        if let strongSelf = self {
                            let previousEntries = previousEntriesValue.swap(entries)
                            
                            let firstTime = previousEntries == nil
                            let transition = chatHistorySearchContainerPreparedTransition(from: previousEntries ?? [], to: entries ?? [], displayingResults: entries != nil, account: account, peerId: peerId, interaction: interfaceInteraction)
                            strongSelf.currentEntries = entries
                            strongSelf.enqueueTransition(transition, firstTime: firstTime)
                            strongSelf._isSearching.set(false)
                        }
                    }))
            }
        }))
        
        self.listNode.beganInteractiveDragging = { [weak self] in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchQueryDisposable.dispose()
        self.searchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let firstValidLayout = self.containerLayout == nil
        self.containerLayout = (layout, navigationBarHeight)
        
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: 0.0, right: 0.0), duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        
        if firstValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func enqueueTransition(_ transition: ChatHistorySearchContainerTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.containerLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            if firstTime {
            } else {
            }
            
            let displayingResults = transition.displayingResults
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    if displayingResults != !strongSelf.listNode.isHidden {
                        strongSelf.listNode.isHidden = !displayingResults
                        strongSelf.dimNode.isHidden = displayingResults
                        strongSelf.backgroundColor = displayingResults ? strongSelf.presentationData.theme.list.plainBackgroundColor : nil
                    }
                }
            })
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    func messageForGallery(_ id: MessageId) -> Message? {
        if let currentEntries = self.currentEntries {
            for entry in currentEntries {
                switch entry {
                    case let .message(message, _, _, _):
                        if message.id == id {
                            return message
                        }
                }
            }
        }
        return nil
    }
    
    func updateHiddenMedia() {
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateHiddenMedia()
            } else if let itemNode = itemNode as? ListMessageNode {
                itemNode.updateHiddenMedia()
            } else if let itemNode = itemNode as? GridMessageItemNode {
                itemNode.updateHiddenMedia()
            }
        }
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, () -> UIView?)? {
        var transitionNode: (ASDisplayNode, () -> UIView?)?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    transitionNode = result
                }
            } else if let itemNode = itemNode as? ListMessageNode {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    transitionNode = result
                }
            } else if let itemNode = itemNode as? GridMessageItemNode {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    transitionNode = result
                }
            }
        }
        return transitionNode
    }
}

