import Foundation
import TelegramCore
import SwiftSignalKit
import AccountContext

private final class LiveLocationSummaryContext {
    private let queue: Queue
    private let engine: TelegramEngine
    private var subscribers = Bag<([EngineMessage.Id: EngineMessage]) -> Void>()
    
    var messageIds = Set<EngineMessage.Id>() {
        didSet {
            assert(self.queue.isCurrent())
            
            if self.messageIds != oldValue {
                if self.messageIds.isEmpty {
                    self.disposable.set(nil)
                    self.messages = [:]
                } else {
                    self.disposable.set((self.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Messages.Messages(ids: self.messageIds)
                    )
                    |> deliverOn(self.queue)).start(next: { [weak self] messages in
                        if let strongSelf = self {
                            strongSelf.messages = messages
                        }
                    }))
                }
            }
        }
    }
    
    private var messages: [EngineMessage.Id: EngineMessage] = [:] {
        didSet {
            assert(self.queue.isCurrent())
            
            for f in self.subscribers.copyItems() {
                f(self.messages)
            }
        }
    }
    
    private let disposable = MetaDisposable()
    
    init(queue: Queue, engine: TelegramEngine) {
        self.queue = queue
        self.engine = engine
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func subscribe() -> Signal<[EngineMessage.Id: EngineMessage], NoError> {
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
    private let engine: TelegramEngine
    private let accountPeerId: EnginePeer.Id
    private let peerId: EnginePeer.Id
    private let becameEmpty: () -> Void
    
    private var peersAndMessages: [(EnginePeer, EngineMessage)]? = nil {
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
    private var subscribers = Bag<([(EnginePeer, EngineMessage)]?) -> Void>()
    
    var isEmpty: Bool {
        return !self.isActive && self.subscribers.isEmpty
    }
    
    private let peerDisposable = MetaDisposable()
    
    init(queue: Queue, engine: TelegramEngine, accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id, becameEmpty: @escaping () -> Void) {
        self.queue = queue
        self.engine = engine
        self.accountPeerId = accountPeerId
        self.peerId = peerId
        self.becameEmpty = becameEmpty
    }
    
    deinit {
        self.peerDisposable.dispose()
    }
    
    func subscribe(_ f: @escaping ([(EnginePeer, EngineMessage)]?) -> Void) -> Disposable {
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
            self.peerDisposable.set((self.engine.messages.topPeerActiveLiveLocationMessages(peerId: self.peerId)
                |> deliverOn(self.queue)).start(next: { [weak self] accountPeer, messages in
                    if let strongSelf = self {
                        var peersAndMessages: [(EnginePeer, EngineMessage)] = []
                        for message in messages {
                            if let author = message.author {
                                if author.id != strongSelf.accountPeerId && message.flags.contains(.Incoming) {
                                    peersAndMessages.append((EnginePeer(author), EngineMessage(message)))
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
    private let engine: TelegramEngine
    private let accountPeerId: EnginePeer.Id
    
    private let globalContext: LiveLocationSummaryContext
    private var peerContexts: [EnginePeer.Id: LiveLocationPeerSummaryContext] = [:]
    
    init(queue: Queue, engine: TelegramEngine, accountPeerId: EnginePeer.Id) {
        assert(queue.isCurrent())
        self.queue = queue
        self.engine = engine
        self.accountPeerId = accountPeerId
        
        self.globalContext = LiveLocationSummaryContext(queue: queue, engine: engine)
    }
    
    func update(messageIds: Set<EngineMessage.Id>) {
        var peerIds = Set<EnginePeer.Id>()
        for id in messageIds {
            peerIds.insert(id.peerId)
        }
        
        for peerId in peerIds {
            if self.peerContexts[peerId] == nil {
                let context = LiveLocationPeerSummaryContext(queue: self.queue, engine: self.engine, accountPeerId: self.accountPeerId, peerId: peerId, becameEmpty: { [weak self] in
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
    
    public func broadcastingToMessages() -> Signal<[EngineMessage.Id: EngineMessage], NoError> {
        return self.globalContext.subscribe()
    }
    
    public func peersBroadcastingTo(peerId: EnginePeer.Id) -> Signal<[(EnginePeer, EngineMessage)]?, NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let context: LiveLocationPeerSummaryContext
                    if let current = strongSelf.peerContexts[peerId] {
                        context = current
                    } else {
                        context = LiveLocationPeerSummaryContext(queue: strongSelf.queue, engine: strongSelf.engine, accountPeerId: strongSelf.accountPeerId, peerId: peerId, becameEmpty: {
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
