import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

private final class LiveLocationSummaryContext {
    private let queue: Queue
    private let postbox: Postbox
    private var subscribers = Bag<([Peer]) -> Void>()
    
    var peerIds = Set<PeerId>() {
        didSet {
            assert(self.queue.isCurrent())
            
            if self.peerIds != oldValue {
                if self.peerIds.isEmpty {
                    self.disposable.set(nil)
                    self.peers = []
                } else {
                    self.disposable.set((self.postbox.multiplePeersView(Array(self.peerIds)) |> deliverOn(self.queue)).start(next: { [weak self] view in
                        if let strongSelf = self {
                            let peers: [Peer] = Array(view.peers.values)
                            strongSelf.peers = peers
                        }
                    }))
                }
            }
        }
    }
    
    private var peers: [Peer] = [] {
        didSet {
            assert(self.queue.isCurrent())
            
            for f in self.subscribers.copyItems() {
                f(self.peers)
            }
        }
    }
    
    private let disposable = MetaDisposable()
    
    init(queue: Queue, postbox: Postbox) {
        self.queue = queue
        self.postbox = postbox
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func subscribe() -> Signal<[Peer], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let index = strongSelf.subscribers.add({ next in
                        subscriber.putNext(next)
                    })
                    
                    subscriber.putNext(strongSelf.peers)
                    
                    disposable.set(ActionDisposable { [weak self] in
                        queue.async {
                            if let strongSelf = self {
                                strongSelf.subscribers.remove(index)
                            }
                        }
                    })
                }
            }
            return disposable
        }
    }
}

private final class LiveLocationPeerSummaryContext {
    private let queue: Queue
    private let accountPeerId: PeerId
    private let viewTracker: AccountViewTracker
    private let peerId: PeerId
    private let becameEmpty: () -> Void
    
    private var peers: [Peer] = [] {
        didSet {
            assert(self.queue.isCurrent())
            
            for f in self.subscribers.copyItems() {
                f(self.peers)
            }
        }
    }
    
    private var _isActive: Bool = false
    var isActive: Bool {
        get {
            return self._isActive
        } set(value) {
            if value != self._isActive {
                let wasActive = self._isActive
                self._isActive = value
                if self._isActive != wasActive {
                    self.updateSubscription()
                }
            }
        }
    }
    private var subscribers = Bag<([Peer]) -> Void>()
    
    var isEmpty: Bool {
        return !self.isActive && self.subscribers.isEmpty
    }
    
    private let peerDisposable = MetaDisposable()
    
    init(queue: Queue, accountPeerId: PeerId, viewTracker: AccountViewTracker, peerId: PeerId, becameEmpty: @escaping () -> Void) {
        self.queue = queue
        self.accountPeerId = accountPeerId
        self.viewTracker = viewTracker
        self.peerId = peerId
        self.becameEmpty = becameEmpty
    }
    
    deinit {
        self.peerDisposable.dispose()
    }
    
    func subscribe(_ f: @escaping ([Peer]) -> Void) -> Disposable {
        let index = self.subscribers.add({ next in
            f(next)
        })
        
        f(self.peers)
        
        let queue = self.queue
        return ActionDisposable { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.subscribers.remove(index)
                    
                    if strongSelf.isEmpty {
                        strongSelf.becameEmpty()
                    }
                }
            }
        }
    }
    
    private func updateSubscription() {
        if self.isActive {
            self.peerDisposable.set((topPeerActiveLiveLocationMessages(viewTracker: self.viewTracker, peerId: self.peerId)
                |> deliverOn(self.queue)).start(next: { [weak self] messages in
                    if let strongSelf = self {
                        var peers: [Peer] = []
                        for message in messages {
                            if let author = message.author {
                                if author.id != strongSelf.accountPeerId && message.flags.contains(.Incoming) {
                                    peers.append(author)
                                }
                            }
                        }
                        strongSelf.peers = peers
                    }
                }))
        } else {
            self.peerDisposable.set(nil)
            self.peers = []
        }
    }
}

final class LiveLocationSummaryManager {
    private let queue: Queue
    private let postbox: Postbox
    private let accountPeerId: PeerId
    private let viewTracker: AccountViewTracker
    
    private let globalContext: LiveLocationSummaryContext
    private var peerContexts: [PeerId: LiveLocationPeerSummaryContext] = [:]
    
    init(queue: Queue, postbox: Postbox, accountPeerId: PeerId, viewTracker: AccountViewTracker) {
        assert(queue.isCurrent())
        self.queue = queue
        self.postbox = postbox
        self.accountPeerId = accountPeerId
        self.viewTracker = viewTracker
        
        self.globalContext = LiveLocationSummaryContext(queue: queue, postbox: postbox)
    }
    
    func update(messageIds: Set<MessageId>) {
        var peerIds = Set<PeerId>()
        for id in messageIds {
            peerIds.insert(id.peerId)
        }
        
        var removedPeerIds: [PeerId] = []
        for peerId in self.peerContexts.keys {
            if !peerIds.contains(peerId) {
                removedPeerIds.append(peerId)
            }
        }
        
        for peerId in removedPeerIds {
            if let _ = self.peerContexts[peerId] {
                self.peerContexts.removeValue(forKey: peerId)
            } else {
                assertionFailure()
            }
        }
        
        for peerId in peerIds {
            if self.peerContexts[peerId] == nil {
                let context = LiveLocationPeerSummaryContext(queue: self.queue, accountPeerId: self.accountPeerId, viewTracker: self.viewTracker, peerId: peerId, becameEmpty: { [weak self] in
                    if let strongSelf = self, let context = strongSelf.peerContexts[peerId], context.isEmpty {
                        strongSelf.peerContexts.removeValue(forKey: peerId)
                    }
                })
                self.peerContexts[peerId] = context
            }
        }
        
        for (peerId, context) in self.peerContexts {
            context.isActive = peerIds.contains(peerId)
        }
        
        self.globalContext.peerIds = peerIds
    }
    
    func broadcastingToPeers() -> Signal<[Peer], NoError> {
        return self.globalContext.subscribe()
    }
    
    func peersBroadcastingTo(peerId: PeerId) -> Signal<[Peer], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let context: LiveLocationPeerSummaryContext
                    if let current = strongSelf.peerContexts[peerId] {
                        context = current
                    } else {
                        context = LiveLocationPeerSummaryContext(queue: strongSelf.queue, accountPeerId: strongSelf.accountPeerId, viewTracker: strongSelf.viewTracker, peerId: peerId, becameEmpty: {
                            if let strongSelf = self, let context = strongSelf.peerContexts[peerId], context.isEmpty {
                                strongSelf.peerContexts.removeValue(forKey: peerId)
                            }
                        })
                    }
                    
                    disposable.set(context.subscribe({ next in
                        subscriber.putNext(next)
                    }))
                }
            }
            return disposable
        }
    }
}
