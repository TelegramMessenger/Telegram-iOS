import Foundation
import AsyncDisplayKit
import SwiftSignalKit

private final class UniversalVideoContentSubscriber {
    let id: Int32
    let priority: UniversalVideoPriority
    let update: ((UniversalVideoContentNode & ASDisplayNode)?) -> Void
    var active: Bool = false
    
    init(id: Int32, priority: UniversalVideoPriority, update: @escaping ((UniversalVideoContentNode & ASDisplayNode)?) -> Void) {
        self.id = id
        self.priority = priority
        self.update = update
    }
}

private final class UniversalVideoContentHolder {
    private var nextId: Int32 = 0
    private var subscribers: [UniversalVideoContentSubscriber] = []
    let content: UniversalVideoContentNode & ASDisplayNode
    
    var statusDisposable: Disposable?
    var statusValue: MediaPlayerStatus?
    
    init(content: UniversalVideoContentNode & ASDisplayNode, statusUpdated: @escaping (MediaPlayerStatus?) -> Void) {
        self.content = content
        
        self.statusDisposable = (content.status |> deliverOn(Queue.mainQueue())).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.statusValue = value
                statusUpdated(value)
            }
        })
    }
    
    deinit {
        self.statusDisposable?.dispose()
    }
    
    var isEmpty: Bool {
        return self.subscribers.isEmpty
    }
    
    func addSubscriber(priority: UniversalVideoPriority, update: @escaping ((UniversalVideoContentNode & ASDisplayNode)?) -> Void) -> Int32 {
        let id = self.nextId
        self.nextId += 1
        
        self.subscribers.append(UniversalVideoContentSubscriber(id: id, priority: priority, update: update))
        self.subscribers.sort(by: { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.id < rhs.id
        })
        
        return id
    }
    
    func removeSubscriberAndUpdate(id: Int32) {
        for i in 0 ..< self.subscribers.count {
            if self.subscribers[i].id == id {
                let subscriber = self.subscribers[i]
                self.subscribers.remove(at: i)
                if subscriber.active {
                    subscriber.update(nil)
                    self.update()
                }
                break
            }
        }
    }
    
    func update() {
        for i in (0 ..< self.subscribers.count) {
            if i == self.subscribers.count - 1 {
                if !self.subscribers[i].active {
                    self.subscribers[i].active = true
                    self.subscribers[i].update(self.content)
                }
            } else {
                if self.subscribers[i].active {
                    self.subscribers[i].active = false
                    self.subscribers[i].update(nil)
                }
            }
        }
    }
}

private final class UniversalVideoContentHolderCallbacks {
    let playbackCompleted = Bag<() -> Void>()
    let status = Bag<(MediaPlayerStatus?) -> Void>()
    
    var isEmpty: Bool {
        return self.playbackCompleted.isEmpty && self.status.isEmpty
    }
}

final class UniversalVideoContentManager {
    private var holders: [AnyHashable: UniversalVideoContentHolder] = [:]
    private var holderCallbacks: [AnyHashable: UniversalVideoContentHolderCallbacks] = [:]
    
    func attachUniversalVideoContent(id: AnyHashable, priority: UniversalVideoPriority, create: () -> UniversalVideoContentNode & ASDisplayNode, update: @escaping ((UniversalVideoContentNode & ASDisplayNode)?) -> Void) -> Int32 {
        assert(Queue.mainQueue().isCurrent())
        
        let holder: UniversalVideoContentHolder
        if let current = self.holders[id] {
            holder = current
        } else {
            holder = UniversalVideoContentHolder(content: create(), statusUpdated: { [weak self] value in
                if let strongSelf = self {
                    if let current = strongSelf.holderCallbacks[id] {
                        for subscriber in current.status.copyItems() {
                            subscriber(value)
                        }
                    }
                }
            })
            self.holders[id] = holder
        }
        
        let id = holder.addSubscriber(priority: priority, update: update)
        holder.update()
        return id
    }
    
    func detachUniversalVideoContent(id: AnyHashable, index: Int32) {
        assert(Queue.mainQueue().isCurrent())
        
        if let holder = self.holders[id] {
            holder.removeSubscriberAndUpdate(id: index)
            if holder.isEmpty {
                //holder.content.dispose()
                self.holders.removeValue(forKey: id)
                
                if let current = self.holderCallbacks[id] {
                    for subscriber in current.status.copyItems() {
                        subscriber(nil)
                    }
                }
            }
        }
    }
    
    func withUniversalVideoContent(id: AnyHashable, _ f: ((UniversalVideoContentNode & ASDisplayNode)?) -> Void) {
        if let holder = self.holders[id] {
            f(holder.content)
        } else {
            f(nil)
        }
    }
    
    func addPlaybackCompleted(id: AnyHashable, _ f: @escaping () -> Void) -> Int {
        var callbacks: UniversalVideoContentHolderCallbacks
        if let current = self.holderCallbacks[id] {
            callbacks = current
        } else {
            callbacks = UniversalVideoContentHolderCallbacks()
            self.holderCallbacks[id] = callbacks
        }
        return callbacks.playbackCompleted.add(f)
    }
    
    func removePlaybackCompleted(id: AnyHashable, index: Int) {
        if let current = self.holderCallbacks[id] {
            current.playbackCompleted.remove(index)
            if current.playbackCompleted.isEmpty {
                self.holderCallbacks.removeValue(forKey: id)
            }
        }
    }
    
    func statusSignal(content: UniversalVideoContent) -> Signal<MediaPlayerStatus?, NoError> {
        return Signal { subscriber in
            var callbacks: UniversalVideoContentHolderCallbacks
            if let current = self.holderCallbacks[content.id] {
                callbacks = current
            } else {
                callbacks = UniversalVideoContentHolderCallbacks()
                self.holderCallbacks[content.id] = callbacks
            }
            
            let index = callbacks.status.add({ value in
                subscriber.putNext(value)
            })
            
            if let current = self.holders[content.id] {
                subscriber.putNext(current.statusValue)
            } else {
                subscriber.putNext(nil)
            }
            
            return ActionDisposable {
                Queue.mainQueue().async {
                    if let current = self.holderCallbacks[content.id] {
                        current.status.remove(index)
                        if current.playbackCompleted.isEmpty {
                            self.holderCallbacks.removeValue(forKey: content.id)
                        }
                    }
                }
            }
        } |> runOn(Queue.mainQueue())
    }
}
