import Foundation
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

final class HashtagSearchController: TelegramController {
    private let queue = Queue()
    
    private let account: Account
    private var transitionDisposable: Disposable?
    private let openMessageFromSearchDisposable = MetaDisposable()
    
    private var controllerNode: HashtagSearchControllerNode {
        return self.displayNode as! HashtagSearchControllerNode
    }
    
    init(account: Account, peerName: String?, query: String) {
        self.account = account
        
        super.init(account: account)
        
        if let peerName = peerName {
            self.title = query + "@" + peerName
        } else {
            self.title = query
        }
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        
        let peerId: Signal<PeerId?, NoError>
        if let peerName = peerName {
            peerId = resolvePeerByName(account: account, name: peerName)
                |> take(1)
        } else {
            peerId = .single(nil)
        }
        
        let foundMessages: Signal<[ChatListSearchEntry], NoError> = peerId
            |> mapToSignal { peerId -> Signal<[ChatListSearchEntry], NoError> in
                return searchMessages(account: account, peerId: peerId, query: query)
                    |> map { return $0.map({ .message($0) }) }
            }
        
        let previousSearchItems = Atomic<[ChatListSearchEntry]?>(value: nil)
        self.transitionDisposable = (foundMessages |> deliverOn(self.queue)).start(next: { [weak self] entries in
            if let strongSelf = self {
                let previousEntries = previousSearchItems.swap(entries)
                
                let firstTime = previousEntries == nil
                let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: entries ?? [], displayingResults: entries != nil, account: account, enableHeaders: false, openPeer: { peer in
                }, openMessage: { message in
                    if let peer = message.peers[message.id.peerId] {
                        strongSelf.openMessageFromSearchDisposable.set((storedMessageFromSearchPeer(account: strongSelf.account, peer: peer) |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                            if let strongSelf = strongSelf {
                                (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: message.id.peerId, messageId: message.id))
                            }
                        }))
                    }
                    strongSelf.controllerNode.listNode.clearHighlightAnimated(true)
                })
                strongSelf.controllerNode.enqueueTransition(transition, firstTime: firstTime)
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.transitionDisposable?.dispose()
        self.openMessageFromSearchDisposable.dispose()
    }
    
    override func loadDisplayNode() {
        self.displayNode = HashtagSearchControllerNode(account: self.account)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
