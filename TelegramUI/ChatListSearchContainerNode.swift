import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private enum ChatListSearchEntryStableId: Hashable {
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


private enum ChatListSearchEntry: Comparable, Identifiable {
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
            case let .localPeer(lhsPeer, lhsIndex):
                if case let .localPeer(rhsPeer, rhsIndex) = rhs {
                    return lhsIndex < rhsIndex
                } else {
                    return true
                }
            case let .globalPeer(lhsPeer, lhsIndex):
                switch rhs {
                    case .localPeer:
                        return false
                    case let .globalPeer(rhsPeer, rhsIndex):
                        return lhsIndex < rhsIndex
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
    
    func item(account: Account, openPeer: @escaping (Peer) -> Void, openMessage: @escaping (Message) -> Void) -> ListViewItem {
        switch self {
            case let .localPeer(peer, _):
                return ContactsPeerItem(account: account, peer: peer, status: .none, index: nil, header: ChatListSearchItemHeader(type: .localPeers), action: { _ in
                    openPeer(peer)
                })
            case let .globalPeer(peer, _):
                return ContactsPeerItem(account: account, peer: peer, status: .addressName, index: nil, header: ChatListSearchItemHeader(type: .globalPeers), action: { _ in
                    openPeer(peer)
                })
            case let .message(message):
                return ChatListItem(account: account, message: message, combinedReadState: nil, notificationSettings: nil, embeddedState: nil, header: ChatListSearchItemHeader(type: .messages), action: { _ in
                    openMessage(message)
                })
        }
    }
}

private struct ChatListSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [ChatListSearchEntry], to toEntries: [ChatListSearchEntry], account: Account, openPeer: @escaping (Peer) -> Void, openMessage: @escaping (Message) -> Void) -> ChatListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, openPeer: openPeer, openMessage: openMessage), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, openPeer: openPeer, openMessage: openMessage), directionHint: nil) }
    
    return ChatListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class ChatListSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    private let openMessage: (Peer, MessageId) -> Void
    
    private let recentPeersNode: ChatListSearchRecentPeersNode
    private let listNode: ListView
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    init(account: Account, openPeer: @escaping (Peer) -> Void, openMessage: @escaping (Peer, MessageId) -> Void) {
        self.account = account
        self.openMessage = openMessage
        
        self.recentPeersNode = ChatListSearchRecentPeersNode(account: account, peerSelected: openPeer)
        self.listNode = ListView()
        
        super.init()
        
        self.backgroundColor = UIColor.white
        
        self.addSubnode(self.recentPeersNode)
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
                    
                    let foundRemoteMessages: Signal<[ChatListSearchEntry], NoError> = .single([]) |> then(searchMessages(account: account, query: query)
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
        let processingQueue = Queue()
        
        self.searchDisposable.set((foundItems
            |> deliverOnMainQueue).start(next: { [weak self] entries in
                if let strongSelf = self {
                    let previousEntries = previousSearchItems.swap(entries)
                    
                    let firstTime = previousEntries == nil
                    let transition = preparedTransition(from: previousEntries ?? [], to: entries ?? [], account: account, openPeer: { peer in
                        openPeer(peer)
                        self?.listNode.clearHighlightAnimated(true)
                    }, openMessage: { message in
                        if let peer = message.peers[message.id.peerId] {
                            openMessage(peer, message.id)
                        }
                        self?.listNode.clearHighlightAnimated(true)
                    })
                    strongSelf.enqueueTransition(transition, firstTime: firstTime)
                    if let _ = entries {
                        strongSelf.listNode.isHidden = false
                        strongSelf.recentPeersNode.isHidden = true
                    } else {
                        strongSelf.listNode.isHidden = true
                        strongSelf.recentPeersNode.isHidden = false
                    }
                }
            }))
    }
    
    deinit {
        self.searchDisposable.dispose()
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
            self.recentPeersNode.isHidden = false
            self.listNode.isHidden = true
        } else {
            self.searchQuery.set(.single(text))
            self.recentPeersNode.isHidden = true
            self.listNode.isHidden = false
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
            if firstTime {
            } else {
                //options.insert(.AnimateAlpha)
            }
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self, firstTime {
                }
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let recentPeersSize = self.recentPeersNode.measure(CGSize(width: layout.size.width, height: CGFloat.infinity))
        self.recentPeersNode.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: recentPeersSize)
        self.recentPeersNode.layout()
        
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
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: 0.0, bottom: layout.insets(options: [.input]).bottom, right: 0.0), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hasValidLayout {
            hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
}
