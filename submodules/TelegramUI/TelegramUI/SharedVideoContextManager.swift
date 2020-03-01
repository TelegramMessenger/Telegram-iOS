import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

class SharedVideoContext {
    func dispose() {
    }
}

private final class SharedVideoContextSubscriber {
    let id: Int32
    let priority: Int32
    let update: (SharedVideoContext?) -> Void
    var active: Bool = false
    
    init(id: Int32, priority: Int32, update: @escaping (SharedVideoContext?) -> Void) {
        self.id = id
        self.priority = priority
        self.update = update
    }
}

private final class SharedVideoContextHolder {
    private var nextId: Int32 = 0
    private var subscribers: [SharedVideoContextSubscriber] = []
    let context: SharedVideoContext
    
    init(context: SharedVideoContext) {
        self.context = context
    }
    
    var isEmpty: Bool {
        return self.subscribers.isEmpty
    }
    
    func addSubscriber(priority: Int32, update: @escaping (SharedVideoContext?) -> Void) -> Int32 {
        let id = self.nextId
        self.nextId += 1
        
        self.subscribers.append(SharedVideoContextSubscriber(id: id, priority: priority, update: update))
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
                    self.subscribers[i].update(self.context)
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

final class SharedVideoContextManager {
    private var holders: [AnyHashable: SharedVideoContextHolder] = [:]
    
    func attachSharedVideoContext(id: AnyHashable, priority: Int32, create: () -> SharedVideoContext, update: @escaping (SharedVideoContext?) -> Void) -> Int32 {
        assert(Queue.mainQueue().isCurrent())
        
        let holder: SharedVideoContextHolder
        if let current = self.holders[id] {
            holder = current
        } else {
            holder = SharedVideoContextHolder(context: create())
            self.holders[id] = holder
        }
        
        let id = holder.addSubscriber(priority: priority, update: update)
        holder.update()
        return id
    }
    
    func detachSharedVideoContext(id: AnyHashable, index: Int32) {
        assert(Queue.mainQueue().isCurrent())
        
        if let holder = self.holders[id] {
            holder.removeSubscriberAndUpdate(id: index)
            if holder.isEmpty {
                holder.context.dispose()
                self.holders.removeValue(forKey: id)
            }
        }
    }
    
    func withSharedVideoContext(id: AnyHashable, _ f: (SharedVideoContext?) -> Void) {
        if let holder = self.holders[id] {
            f(holder.context)
        } else {
            f(nil)
        }
    }
}
