import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private enum ChatListSearchEntry {
    case message(Message)
}

final class ChatListSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    private let openMessage: (Peer, MessageId) -> Void
    
    private let recentPeersNode: ChatListSearchRecentPeersNode
    private let listNode: ListView
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    init(account: Account, openPeer: @escaping (PeerId) -> Void, openMessage: @escaping (Peer, MessageId) -> Void) {
        self.account = account
        self.openMessage = openMessage
        
        self.recentPeersNode = ChatListSearchRecentPeersNode(account: account, peerSelected: openPeer)
        self.listNode = ListView()
        
        super.init()
        
        self.backgroundColor = UIColor.white
        self.addSubnode(self.recentPeersNode)
        self.addSubnode(self.listNode)
        
        self.listNode.isHidden = true
        
        let searchItems = searchQuery.get()
            |> mapToSignal { query -> Signal<[ChatListSearchEntry], NoError> in
                if let query = query, !query.isEmpty {
                    return searchMessages(account: account, query: query)
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                        |> map { messages -> [ChatListSearchEntry] in
                            return messages.map({ .message($0) })
                        }
                } else {
                    return .single([])
                }
            }
        
        let previousSearchItems = Atomic<[ChatListSearchEntry]>(value: [])
        
        self.searchDisposable.set((searchItems
            |> deliverOnMainQueue).start(next: { [weak self] items in
                if let strongSelf = self {
                    let previousItems = previousSearchItems.swap(items)
                    
                    var listItems: [ListViewItem] = []
                    for item in items {
                        switch item {
                            case let .message(message):
                                listItems.append(ChatListItem(account: account, message: message, unreadCount: 0, action: { [weak strongSelf] _ in
                                    if let strongSelf = strongSelf, let peer = message.peers[message.id.peerId] {
                                        strongSelf.listNode.clearHighlightAnimated(true)
                                        strongSelf.openMessage(peer, message.id)
                                    }
                                }))
                        }
                    }
                    
                    strongSelf.listNode.deleteAndInsertItems(deleteIndices: (0 ..< previousItems.count).map({ ListViewDeleteItem(index: $0, directionHint: nil) }), insertIndicesAndItems: (0 ..< listItems.count).map({ ListViewInsertItem(index: $0, previousIndex: nil, item: listItems[$0], directionHint: .Down) }), updateIndicesAndItems: [], options: [])
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
        var speedFactor: CGFloat = 1.0
        if curve == 7 {
            speedFactor = CGFloat(duration) / 0.5
            listViewCurve = .Spring(speed: CGFloat(speedFactor))
        } else {
            listViewCurve = .Default
        }
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.deleteAndInsertItems(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: 0.0, bottom: layout.insets(options: [.input]).bottom, right: 0.0), duration: duration, curve: listViewCurve), stationaryItemRange: nil, completion: { _ in })
    }
}
