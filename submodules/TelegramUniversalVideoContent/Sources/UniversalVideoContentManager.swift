import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import UniversalMediaPlayer
import AccountContext
import RangeSet

private final class UniversalVideoContentSubscriber {
    let id: Int32
    let priority: UniversalVideoPriority
    let update: (((UniversalVideoContentNode & ASDisplayNode), Bool)?) -> Void
    var active: Bool = false
    
    init(id: Int32, priority: UniversalVideoPriority, update: @escaping (((UniversalVideoContentNode & ASDisplayNode), Bool)?) -> Void) {
        self.id = id
        self.priority = priority
        self.update = update
    }
}

private final class UniversalVideoContentHolder {
    private var nextId: Int32 = 0
    private var subscribers: [UniversalVideoContentSubscriber] = []
    let content: UniversalVideoContent
    let contentNode: UniversalVideoContentNode & ASDisplayNode
    
    var statusDisposable: Disposable?
    var statusValue: MediaPlayerStatus?
    
    var bufferingStatusDisposable: Disposable?
    var bufferingStatusValue: (RangeSet<Int64>, Int64)?
    
    var playbackCompletedIndex: Int?
    
    init(content: UniversalVideoContent, contentNode: UniversalVideoContentNode & ASDisplayNode, statusUpdated: @escaping (MediaPlayerStatus?) -> Void, bufferingStatusUpdated: @escaping ((RangeSet<Int64>, Int64)?) -> Void, playbackCompleted: @escaping () -> Void) {
        self.content = content
        self.contentNode = contentNode
        
        self.statusDisposable = (contentNode.status |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.statusValue = value
                statusUpdated(value)
            }
        })
        
        self.bufferingStatusDisposable = (contentNode.bufferingStatus |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.bufferingStatusValue = value
                bufferingStatusUpdated(value)
            }
        })
        
        self.playbackCompletedIndex = contentNode.addPlaybackCompleted {
            playbackCompleted()
        }
    }
    
    deinit {
        self.statusDisposable?.dispose()
        self.bufferingStatusDisposable?.dispose()
        if let playbackCompletedIndex = self.playbackCompletedIndex {
            self.contentNode.removePlaybackCompleted(playbackCompletedIndex)
        }
    }
    
    var isEmpty: Bool {
        return self.subscribers.isEmpty
    }
    
    func addSubscriber(priority: UniversalVideoPriority, update: @escaping (((UniversalVideoContentNode & ASDisplayNode), Bool)?) -> Void) -> Int32 {
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
                    self.update(removeSubscribers: [subscriber])
                }
                break
            }
        }
    }
    
    func update(forceUpdateId: Int32? = nil, initiatedCreation: Int32? = nil, removeSubscribers: [UniversalVideoContentSubscriber] = []) {
        var removeSubscribers = removeSubscribers
        for i in (0 ..< self.subscribers.count) {
            if i == self.subscribers.count - 1 {
                if !self.subscribers[i].active {
                    self.subscribers[i].active = true
                    self.subscribers[i].update((self.contentNode, initiatedCreation: initiatedCreation == self.subscribers[i].id))
                }
            } else {
                if self.subscribers[i].active {
                    self.subscribers[i].active = false
                    removeSubscribers.append(self.subscribers[i])
                }
            }
        }
        
        for subscriber in removeSubscribers {
            subscriber.update(nil)
        }
        
        if let forceUpdateId = forceUpdateId {
            for subscriber in self.subscribers {
                if subscriber.id == forceUpdateId {
                    if !subscriber.active {
                        subscriber.update(nil)
                    }
                    break
                }
            }
        }
    }
}

private final class UniversalVideoContentHolderCallbacks {
    let playbackCompleted = Bag<() -> Void>()
    let status = Bag<(MediaPlayerStatus?) -> Void>()
    let bufferingStatus = Bag<((RangeSet<Int64>, Int64)?) -> Void>()
    
    var isEmpty: Bool {
        return self.playbackCompleted.isEmpty && self.status.isEmpty && self.bufferingStatus.isEmpty
    }
}

public final class UniversalVideoManagerImpl: UniversalVideoManager {
    private var holders: [AnyHashable: UniversalVideoContentHolder] = [:]
    private var holderCallbacks: [AnyHashable: UniversalVideoContentHolderCallbacks] = [:]
    
    public init() {
    }
    
    public func attachUniversalVideoContent(content: UniversalVideoContent, priority: UniversalVideoPriority, create: () -> UniversalVideoContentNode & ASDisplayNode, update: @escaping (((UniversalVideoContentNode & ASDisplayNode), Bool)?) -> Void) -> (AnyHashable, Int32) {
        assert(Queue.mainQueue().isCurrent())
        
        var initiatedCreation = false
        
        let holder: UniversalVideoContentHolder
        if let current = self.holders[content.id] {
            holder = current
        } else {
            let foundHolder: UniversalVideoContentHolder? = nil
            for (_, current) in self.holders {
                if current.content.isEqual(to: content) {
                    //foundHolder = current
                    break
                }
            }
            if let foundHolder = foundHolder {
                holder = foundHolder
            } else {
                initiatedCreation = true
                holder = UniversalVideoContentHolder(content: content, contentNode: create(), statusUpdated: { [weak self] value in
                    if let strongSelf = self {
                        if let current = strongSelf.holderCallbacks[content.id] {
                            for subscriber in current.status.copyItems() {
                                subscriber(value)
                            }
                        }
                    }
                }, bufferingStatusUpdated: { [weak self] value in
                    if let strongSelf = self {
                        if let current = strongSelf.holderCallbacks[content.id] {
                            for subscriber in current.bufferingStatus.copyItems() {
                                subscriber(value)
                            }
                        }
                    }
                }, playbackCompleted: { [weak self] in
                    if let strongSelf = self {
                        if let current = strongSelf.holderCallbacks[content.id] {
                            for subscriber in current.playbackCompleted.copyItems() {
                                subscriber()
                            }
                        }
                    }
                })
                self.holders[content.id] = holder
            }
        }
        
        let id = holder.addSubscriber(priority: priority, update: update)
        holder.update(forceUpdateId: id, initiatedCreation: initiatedCreation ? id : nil)
        return (holder.content.id, id)
    }
    
    public func detachUniversalVideoContent(id: AnyHashable, index: Int32) {
        assert(Queue.mainQueue().isCurrent())
        
        if let holder = self.holders[id] {
            holder.removeSubscriberAndUpdate(id: index)
            if holder.isEmpty {
                self.holders.removeValue(forKey: id)
                
                if let current = self.holderCallbacks[id] {
                    for subscriber in current.status.copyItems() {
                        subscriber(nil)
                    }
                }
            }
        }
    }
    
    public func withUniversalVideoContent(id: AnyHashable, _ f: ((UniversalVideoContentNode & ASDisplayNode)?) -> Void) {
        if let holder = self.holders[id] {
            f(holder.contentNode)
        } else {
            f(nil)
        }
    }
    
    public func addPlaybackCompleted(id: AnyHashable, _ f: @escaping () -> Void) -> Int {
        assert(Queue.mainQueue().isCurrent())
        var callbacks: UniversalVideoContentHolderCallbacks
        if let current = self.holderCallbacks[id] {
            callbacks = current
        } else {
            callbacks = UniversalVideoContentHolderCallbacks()
            self.holderCallbacks[id] = callbacks
        }
        return callbacks.playbackCompleted.add(f)
    }
    
    public func removePlaybackCompleted(id: AnyHashable, index: Int) {
        if let current = self.holderCallbacks[id] {
            current.playbackCompleted.remove(index)
            if current.playbackCompleted.isEmpty {
                self.holderCallbacks.removeValue(forKey: id)
            }
        }
    }
    
    public func statusSignal(content: UniversalVideoContent) -> Signal<MediaPlayerStatus?, NoError> {
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
    
    public func bufferingStatusSignal(content: UniversalVideoContent) -> Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return Signal { subscriber in
            var callbacks: UniversalVideoContentHolderCallbacks
            if let current = self.holderCallbacks[content.id] {
                callbacks = current
            } else {
                callbacks = UniversalVideoContentHolderCallbacks()
                self.holderCallbacks[content.id] = callbacks
            }
            
            let index = callbacks.bufferingStatus.add({ value in
                subscriber.putNext(value)
            })
            
            if let current = self.holders[content.id] {
                subscriber.putNext(current.bufferingStatusValue)
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
