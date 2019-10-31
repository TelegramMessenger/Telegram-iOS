import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AccountContext

private final class LiveLocationSummaryContext {
    private let queue: Queue
    private let postbox: Postbox
    private var subscribers = Bag<([MessageId: Message]) -> Void>()
    
    var messageIds = Set<MessageId>() {
        didSet {
            assert(self.queue.isCurrent())
            
            if self.messageIds != oldValue {
                if self.messageIds.isEmpty {
                    self.disposable.set(nil)
                    self.messages = [:]
                } else {
                    let key = PostboxViewKey.messages(self.messageIds)
                    self.disposable.set((self.postbox.combinedView(keys: [key]) |> deliverOn(self.queue)).start(next: { [weak self] view in
                        if let strongSelf = self {
                            strongSelf.messages = (view.views[key] as? MessagesView)?.messages ?? [:]
                        }
                    }))
                }
            }
        }
    }
    
    private var messages: [MessageId: Message] = [:] {
        didSet {
            assert(self.queue.isCurrent())
            
            for f in self.subscribers.copyItems() {
                f(self.messages)
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
    
    func subscribe() -> Signal<[MessageId: Message], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let index = strongSelf.subscribers.add({ next in
                        subscriber.putNext(next)
                    })
                    
                    subscriber.putNext(strongSelf.messages)
                    
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
    
    private var peersAndMessages: [(Peer, Message)]? = nil {
        didSet {
            assert(self.queue.isCurrent())
            
            for f in self.subscribers.copyItems() {
                f(self.peersAndMessages)
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
    private var subscribers = Bag<([(Peer, Message)]?) -> Void>()
    
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
    
    func subscribe(_ f: @escaping ([(Peer, Message)]?) -> Void) -> Disposable {
        let wasEmpty = self.subscribers.isEmpty
        let index = self.subscribers.add({ next in
            f(next)
        })
        
        f(self.peersAndMessages)
        
        if self.subscribers.isEmpty != wasEmpty {
            self.updateSubscription()
        }
        
        let queue = self.queue
        return ActionDisposable { [weak self] in
            queue.async {
                if let strongSelf = self {
                    let wasEmpty = strongSelf.subscribers.isEmpty
                    strongSelf.subscribers.remove(index)
                    
                    if strongSelf.subscribers.isEmpty != wasEmpty {
                        strongSelf.updateSubscription()
                    }
                    if strongSelf.isEmpty {
                        strongSelf.becameEmpty()
                    }
                }
            }
        }
    }
    
    private func updateSubscription() {
        if self.isActive || !self.subscribers.isEmpty {
            self.peerDisposable.set((topPeerActiveLiveLocationMessages(viewTracker: self.viewTracker, accountPeerId: self.accountPeerId, peerId: self.peerId)
                |> deliverOn(self.queue)).start(next: { [weak self] accountPeer, messages in
                    if let strongSelf = self {
                        var peersAndMessages: [(Peer, Message)] = []
                        for message in messages {
                            if let author = message.author {
                                if author.id != strongSelf.accountPeerId && message.flags.contains(.Incoming) {
                                    peersAndMessages.append((author, message))
                                }
                            }
                        }
                        if peersAndMessages.isEmpty {
                            strongSelf.peersAndMessages = nil
                        } else {
                            strongSelf.peersAndMessages = peersAndMessages
                        }
                    }
                }))
        } else {
            self.peerDisposable.set(nil)
            self.peersAndMessages = nil
        }
    }
}

public final class LiveLocationSummaryManagerImpl: LiveLocationSummaryManager {
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
        
        self.globalContext.messageIds = messageIds
    }
    
    public func broadcastingToMessages() -> Signal<[MessageId: Message], NoError> {
        return self.globalContext.subscribe()
    }
    
    public func peersBroadcastingTo(peerId: PeerId) -> Signal<[(Peer, Message)]?, NoError> {
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
                        strongSelf.peerContexts[peerId] = context
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
