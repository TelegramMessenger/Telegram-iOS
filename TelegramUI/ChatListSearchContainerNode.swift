import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

enum ChatListRecentEntryStableId: Hashable {
    case topPeers
    case peerId(PeerId)
    
    static func ==(lhs: ChatListRecentEntryStableId, rhs: ChatListRecentEntryStableId) -> Bool {
        switch lhs {
            case .topPeers:
                if case .topPeers = rhs {
                    return true
                } else {
                    return false
            }
            case let .peerId(peerId):
                if case .peerId(peerId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case .topPeers:
                return 0
            case let .peerId(peerId):
                return peerId.hashValue
        }
    }
}

enum ChatListRecentEntry: Comparable, Identifiable {
    case topPeers([Peer])
    case peer(index: Int, peer: Peer)
    
    var stableId: ChatListRecentEntryStableId {
        switch self {
            case .topPeers:
                return .topPeers
            case let .peer(_, peer):
                return .peerId(peer.id)
        }
    }
    
    static func ==(lhs: ChatListRecentEntry, rhs: ChatListRecentEntry) -> Bool {
        switch lhs {
            case let .topPeers(lhsPeers):
                if case let .topPeers(rhsPeers) = rhs {
                    if lhsPeers.count != rhsPeers.count {
                        return false
                    }
                    for i in 0 ..< lhsPeers.count {
                        if !lhsPeers[i].isEqual(rhsPeers[i]) {
                            return false
                        }
                    }
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsPeer):
                if case let .peer(rhsIndex, rhsPeer) = rhs, lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatListRecentEntry, rhs: ChatListRecentEntry) -> Bool {
        switch lhs {
            case .topPeers:
                return true
            case let .peer(lhsIndex, _):
                switch rhs {
                    case .topPeers:
                        return false
                    case let .peer(rhsIndex, _):
                        return lhsIndex <= rhsIndex
                }
        }
    }
    
    func item(account: Account, peerSelected: @escaping (Peer) -> Void) -> ListViewItem {
        switch self {
            case let .topPeers(peers):
                return ChatListRecentPeersListItem(account: account, peers: peers, peerSelected: { peer in
                    peerSelected(peer)
                })
            case let .peer(_, peer):
                return ContactsPeerItem(account: account, peer: peer, chatPeer: peer, status: .none, selection: .none, index: nil, header: ChatListSearchItemHeader(type: .recentPeers), action: { _ in
                    peerSelected(peer)
                })
        }
    }
}


enum ChatListSearchEntryStableId: Hashable {
    case localPeerId(PeerId)
    case globalPeerId(PeerId)
    case messageId(MessageId)
    
    static func ==(lhs: ChatListSearchEntryStableId, rhs: ChatListSearchEntryStableId) -> Bool {
        switch lhs {
            case let .localPeerId(peerId):
                if case .localPeerId(peerId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .globalPeerId(peerId):
                if case .globalPeerId(peerId) = rhs {
                    return true
                } else {
                    return false
                }
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
            case let .localPeerId(peerId):
                return peerId.hashValue
            case let .globalPeerId(peerId):
                return peerId.hashValue
            case let .messageId(messageId):
                return messageId.hashValue
        }
    }
}


enum ChatListSearchEntry: Comparable, Identifiable {
    case localPeer(Peer, Int)
    case globalPeer(Peer, Int)
    case message(Message)
    
    var stableId: ChatListSearchEntryStableId {
        switch self {
            case let .localPeer(peer, _):
                return .localPeerId(peer.id)
            case let .globalPeer(peer, _):
                return .globalPeerId(peer.id)
            case let .message(message):
                return .messageId(message.id)
        }
    }
    
    static func ==(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .localPeer(lhsPeer, lhsIndex):
                if case let .localPeer(rhsPeer, rhsIndex) = rhs, lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
            case let .globalPeer(lhsPeer, lhsIndex):
                if case let .globalPeer(rhsPeer, rhsIndex) = rhs, lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
            case let .message(lhsMessage):
                if case let .message(rhsMessage) = rhs {
                    if lhsMessage.id != rhsMessage.id {
                        return false
                    }
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
        
    static func <(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .localPeer(_, lhsIndex):
                if case let .localPeer(_, rhsIndex) = rhs {
                    return lhsIndex <= rhsIndex
                } else {
                    return true
                }
            case let .globalPeer(_, lhsIndex):
                switch rhs {
                    case .localPeer:
                        return false
                    case let .globalPeer(_, rhsIndex):
                        return lhsIndex <= rhsIndex
                    case .message:
                        return true
                }
            case let .message(lhsMessage):
                if case let .message(rhsMessage) = rhs {
                    return MessageIndex(lhsMessage) < MessageIndex(rhsMessage)
                } else {
                    return false
                }
        }
    }
    
    func item(account: Account, enableHeaders: Bool, interaction: ChatListNodeInteraction) -> ListViewItem {
        switch self {
            case let .localPeer(peer, _):
                return ContactsPeerItem(account: account, peer: peer, chatPeer: peer, status: .none, selection: .none, index: nil, header: ChatListSearchItemHeader(type: .localPeers), action: { _ in
                    interaction.peerSelected(peer)
                })
            case let .globalPeer(peer, _):
                return ContactsPeerItem(account: account, peer: peer, chatPeer: peer, status: .addressName, selection: .none, index: nil, header: ChatListSearchItemHeader(type: .globalPeers), action: { _ in
                    interaction.peerSelected(peer)
                })
            case let .message(message):
                return ChatListItem(account: account, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(message)), message: message, peer: RenderedPeer(message: message), combinedReadState: nil, notificationSettings: nil, embeddedState: nil, editing: false, hasActiveRevealControls: false, header: enableHeaders ? ChatListSearchItemHeader(type: .messages) : nil, interaction: interaction)
        }
    }
}

struct ChatListSearchContainerRecentTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

struct ChatListSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let displayingResults: Bool
}

func chatListSearchContainerPreparedRecentTransition(from fromEntries: [ChatListRecentEntry], to toEntries: [ChatListRecentEntry], account: Account, peerSelected: @escaping (Peer) -> Void) -> ChatListSearchContainerRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, peerSelected: peerSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, peerSelected: peerSelected), directionHint: nil) }
    
    return ChatListSearchContainerRecentTransition(deletions: deletions, insertions: insertions, updates: updates)
}

func chatListSearchContainerPreparedTransition(from fromEntries: [ChatListSearchEntry], to toEntries: [ChatListSearchEntry], displayingResults: Bool, account: Account, enableHeaders: Bool, interaction: ChatListNodeInteraction) -> ChatListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, enableHeaders: enableHeaders, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, enableHeaders: enableHeaders, interaction: interaction), directionHint: nil) }
    
    return ChatListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, displayingResults: displayingResults)
}

final class ChatListSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    private let openMessage: (Peer, MessageId) -> Void
    
    //private let recentPeersNode: ChatListSearchRecentPeersNode
    private let recentListNode: ListView
    private let listNode: ListView
    
    private var enqueuedRecentTransitions: [(ChatListSearchContainerRecentTransition, Bool)] = []
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    private var hasValidLayout = false
    
    private let recentDisposable = MetaDisposable()
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    init(account: Account, openPeer: @escaping (Peer) -> Void, openMessage: @escaping (Peer, MessageId) -> Void) {
        self.account = account
        self.openMessage = openMessage
        
        //self.recentPeersNode = ChatListSearchRecentPeersNode(account: account, peerSelected: openPeer)
        self.recentListNode = ListView()
        
        self.listNode = ListView()
        
        super.init()
        
        self.backgroundColor = UIColor.white
        
        //self.addSubnode(self.recentPeersNode)
        self.addSubnode(self.recentListNode)
        self.addSubnode(self.listNode)
        
        self.listNode.isHidden = true
    
        let foundItems = searchQuery.get()
            |> mapToSignal { query -> Signal<[ChatListSearchEntry]?, NoError> in
                if let query = query, !query.isEmpty {
                    let foundLocalPeers = account.postbox.searchPeers(query: query.lowercased())
                        |> map { peers -> [ChatListSearchEntry] in
                            var entries: [ChatListSearchEntry] = []
                            var index = 0
                            for peer in peers {
                                entries.append(.localPeer(peer, index))
                                index += 1
                            }
                            return entries
                        }
                    
                    let foundRemotePeers: Signal<[ChatListSearchEntry], NoError> = .single([]) |> then(searchPeers(account: account, query: query)
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                        |> map { peers -> [ChatListSearchEntry] in
                            var entries: [ChatListSearchEntry] = []
                            var index = 0
                            for peer in peers {
                                entries.append(.globalPeer(peer, index))
                                index += 1
                            }
                            return entries
                        })
                    
                    let foundRemoteMessages: Signal<[ChatListSearchEntry], NoError> = .single([]) |> then(searchMessages(account: account, peerId: nil, query: query)
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                        |> map { messages -> [ChatListSearchEntry] in
                            return messages.map({ .message($0) })
                        })
                    
                    return combineLatest(foundLocalPeers, foundRemotePeers, foundRemoteMessages)
                        |> map { localPeers, remotePeers, remoteMessages -> [ChatListSearchEntry]? in
                            return localPeers + remotePeers + remoteMessages
                        }
                } else {
                    return .single(nil)
                }
            }
        
        let previousSearchItems = Atomic<[ChatListSearchEntry]?>(value: nil)
        
        let interaction = ChatListNodeInteraction(activateSearch: {
        }, peerSelected: { [weak self] peer in
            openPeer(peer)
            let _ = addRecentlySearchedPeer(postbox: account.postbox, peerId: peer.id).start()
            self?.listNode.clearHighlightAnimated(true)
        }, messageSelected: { [weak self] message in
            if let peer = message.peers[message.id.peerId] {
                openMessage(peer, message.id)
            }
            self?.listNode.clearHighlightAnimated(true)
        }, setPeerIdWithRevealedOptions: { _ in
        }, setPeerPinned: { _ in
        }, setPeerMuted: { _ in
        }, deletePeer: { _ in
        })
        
        let previousRecentItems = Atomic<[ChatListRecentEntry]?>(value: nil)
        let recentItemsTransition = recentlySearchedPeers(postbox: account.postbox)
            |> mapToSignal { [weak self] peers -> Signal<(ChatListSearchContainerRecentTransition, Bool), NoError> in
                var entries: [ChatListRecentEntry] = []
                entries.append(.topPeers([]))
                for i in 0 ..< peers.count {
                    entries.append(.peer(index: i, peer: peers[i]))
                }
                let previousEntries = previousRecentItems.swap(entries)
                
                let transition = chatListSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries, account: account, peerSelected: { peer in
                    self?.recentListNode.clearHighlightAnimated(true)
                    openPeer(peer)
                })
                return .single((transition, previousEntries == nil))
        }
        
        self.recentDisposable.set((recentItemsTransition |> deliverOnMainQueue).start(next: { [weak self] (transition, firstTime) in
            if let strongSelf = self {
                strongSelf.enqueueRecentTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.searchDisposable.set((foundItems
            |> deliverOnMainQueue).start(next: { [weak self] entries in
                if let strongSelf = self {
                    let previousEntries = previousSearchItems.swap(entries)
                    
                    let firstTime = previousEntries == nil
                    let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: entries ?? [], displayingResults: entries != nil, account: account, enableHeaders: true, interaction: interaction)
                    strongSelf.enqueueTransition(transition, firstTime: firstTime)
                }
            }))
    }
    
    deinit {
        self.recentDisposable.dispose()
        self.searchDisposable.dispose()
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueRecentTransition(_ transition: ChatListSearchContainerRecentTransition, firstTime: Bool) {
        enqueuedRecentTransitions.append((transition, firstTime))
        
        if self.hasValidLayout {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
        }
    }
    
    private func dequeueRecentTransition() {
        if let (transition, firstTime) = self.enqueuedRecentTransitions.first {
            self.enqueuedRecentTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            if firstTime {
            } else {
            }
            
            self.recentListNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
    }
    
    private func enqueueTransition(_ transition: ChatListSearchContainerTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.hasValidLayout {
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
                //options.insert(.AnimateAlpha)
            }
            
            let displayingResults = transition.displayingResults
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    if displayingResults != !strongSelf.listNode.isHidden {
                        strongSelf.listNode.isHidden = !displayingResults
                        strongSelf.recentListNode.isHidden = displayingResults
                    }
                }
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        //let recentPeersSize = self.recentPeersNode.measure(CGSize(width: layout.size.width, height: CGFloat.infinity))
        //self.recentPeersNode.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: recentPeersSize)
        //self.recentPeersNode.layout()
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                case .easeInOut:
                    break
                case .spring:
                    curve = 7
                }
        }
        
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default
        }
        
        self.recentListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: 0.0, bottom: layout.insets(options: [.input]).bottom, right: 0.0), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: 0.0, bottom: layout.insets(options: [.input]).bottom, right: 0.0), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hasValidLayout {
            hasValidLayout = true
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    override func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, Any)? {
        var selectedItemNode: ASDisplayNode?
        if !self.recentListNode.isHidden {
            let adjustedLocation = self.convert(location, to: self.recentListNode)
            self.recentListNode.forEachItemNode { itemNode in
                if itemNode.frame.contains(adjustedLocation) {
                    selectedItemNode = itemNode
                }
            }
        } else {
            let adjustedLocation = self.convert(location, to: self.listNode)
            self.listNode.forEachItemNode { itemNode in
                if itemNode.frame.contains(adjustedLocation) {
                    selectedItemNode = itemNode
                }
            }
        }
        if let selectedItemNode = selectedItemNode as? ChatListRecentPeersListItemNode {
            if let result = selectedItemNode.viewAndPeerAtPoint(self.convert(location, to: selectedItemNode)) {
                return (result.0, result.1)
            }
        } else if let selectedItemNode = selectedItemNode as? ContactsPeerItemNode, let peer = selectedItemNode.peer {
            return (selectedItemNode.view, peer.id)
        } else if let selectedItemNode = selectedItemNode as? ChatListItemNode, let peerId = selectedItemNode.item?.peer.peerId {
            return (selectedItemNode.view, peerId)
        }
        return nil
    }
}
