import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

#if os(macOS)
    private typealias SignalKitTimer = SwiftSignalKitMac.Timer
#else
    private typealias SignalKitTimer = SwiftSignalKit.Timer
#endif

private final class PeerInputActivityContext {
    private let queue: Queue
    private let notifyEmpty: () -> Void
    private let notifyUpdated: () -> Void
    
    private var nextId: Int32 = 0
    private var activities: [(PeerId, PeerInputActivity, Int32, SignalKitTimer)] = []
    
    private let subscribers = Bag<([(PeerId, PeerInputActivity)]) -> Void>()
    
    private var scheduledUpdateSubscribers = false
    
    init(queue: Queue, notifyEmpty: @escaping () -> Void, notifyUpdated: @escaping () -> Void) {
        self.queue = queue
        self.notifyEmpty = notifyEmpty
        self.notifyUpdated = notifyUpdated
    }
    
    func addActivity(peerId: PeerId, activity: PeerInputActivity, timeout: Double) {
        assert(self.queue.isCurrent())
        
        var updated = false
        var found = false
        for i in 0 ..< self.activities.count {
            let record = self.activities[i]
            if record.0 == peerId && record.1.key == activity.key {
                found = true
                record.3.invalidate()
                if record.1 != activity {
                    updated = true
                }
                let currentId = record.2
                let timer = SignalKitTimer(timeout: timeout, repeat: false, completion: { [weak self] in
                    if let strongSelf = self {
                        for currentActivity in strongSelf.activities {
                            if currentActivity.2 == currentId {
                                strongSelf.removeActivity(peerId: currentActivity.0, activity: currentActivity.1)
                            }
                        }
                    }
                }, queue: self.queue)
                self.activities[i] = (peerId, activity, currentId, timer)
                timer.start()
                break
            }
        }
        
        if !found {
            updated = true
            let activityId = self.nextId
            self.nextId += 1
            let timer = SignalKitTimer(timeout: timeout, repeat: false, completion: { [weak self] in
                if let strongSelf = self {
                    for currentActivity in strongSelf.activities {
                        if currentActivity.2 == activityId {
                            strongSelf.removeActivity(peerId: currentActivity.0, activity: currentActivity.1)
                        }
                    }
                }
            }, queue: self.queue)
            self.activities.insert((peerId, activity, activityId, timer), at: 0)
            timer.start()
        }
        
        if updated {
            self.scheduleUpdateSubscribers()
        }
    }
    
    func removeActivity(peerId: PeerId, activity: PeerInputActivity) {
        assert(self.queue.isCurrent())
        
        for i in 0 ..< self.activities.count {
            let record = self.activities[i]
            if record.0 == peerId && record.1.key == activity.key {
                self.activities.remove(at: i)
                self.scheduleUpdateSubscribers()
                break
            }
        }
    }
    
    func removeAllActivities(peerId: PeerId) {
        assert(self.queue.isCurrent())
        
        var updated = false
        for i in (0 ..< self.activities.count).reversed() {
            let record = self.activities[i]
            if record.0 == peerId {
                self.activities.remove(at: i)
                updated = true
            }
        }
        
        if updated {
            self.scheduleUpdateSubscribers()
        }
    }
    
    func scheduleUpdateSubscribers() {
        if !self.scheduledUpdateSubscribers {
            self.scheduledUpdateSubscribers = true
            
            self.queue.async { [weak self] in
                self?.updateSubscribers()
            }
        }
    }
    
    func isEmpty() -> Bool {
        return self.activities.isEmpty && self.subscribers.isEmpty
    }
    
    func topActivities() -> [(PeerId, PeerInputActivity)] {
        var peerIds = Set<PeerId>()
        var result: [(PeerId, PeerInputActivity)] = []
        for (peerId, activity, _, _) in self.activities {
            if !peerIds.contains(peerId) {
                peerIds.insert(peerId)
                result.append((peerId, activity))
                if result.count == 10 {
                    break
                }
            }
        }
        return result
    }
    
    func updateSubscribers() {
        self.scheduledUpdateSubscribers = false
        
        if self.isEmpty() {
            self.notifyEmpty()
        } else {
            let topActivities = self.topActivities()
            for subscriber in self.subscribers.copyItems() {
                subscriber(topActivities)
            }
            
            self.notifyUpdated()
        }
    }
    
    func addSubscriber(_ subscriber: @escaping ([(PeerId, PeerInputActivity)]) -> Void) -> Int {
        return self.subscribers.add(subscriber)
    }
    
    func removeSubscriber(_ index: Int) {
        self.subscribers.remove(index)
    }
}

private final class PeerGlobalInputActivityContext {
    private let subscribers = Bag<([PeerId: [PeerId: PeerInputActivity]]) -> Void>()
    
    func addSubscriber(_ subscriber: @escaping ([PeerId: [PeerId: PeerInputActivity]]) -> Void) -> Int {
        return self.subscribers.add(subscriber)
    }
    
    func removeSubscriber(_ index: Int) {
        self.subscribers.remove(index)
    }
    
    var isEmpty: Bool {
        return self.subscribers.isEmpty
    }
    
    func notify(_ activities: [PeerId: [PeerId: PeerInputActivity]]) {
        for subscriber in self.subscribers.copyItems() {
            subscriber(activities)
        }
    }
}

final class PeerInputActivityManager {
    private let queue = Queue()
    
    private var contexts: [PeerId: PeerInputActivityContext] = [:]
    private var globalContext: PeerGlobalInputActivityContext?
    
    func activities(peerId: PeerId) -> Signal<[(PeerId, PeerInputActivity)], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let context: PeerInputActivityContext
                    if let currentContext = strongSelf.contexts[peerId] {
                        context = currentContext
                    } else {
                        context = PeerInputActivityContext(queue: queue, notifyEmpty: {
                            if let strongSelf = self {
                                strongSelf.contexts.removeValue(forKey: peerId)
                                
                                if let globalContext = strongSelf.globalContext {
                                    let activities = strongSelf.collectActivities()
                                    globalContext.notify(activities)
                                }
                            }
                        }, notifyUpdated: {
                            if let strongSelf = self, let globalContext = strongSelf.globalContext {
                                let activities = strongSelf.collectActivities()
                                globalContext.notify(activities)
                            }
                        })
                        strongSelf.contexts[peerId] = context
                    }
                    let index = context.addSubscriber({ next in
                        subscriber.putNext(next)
                    })
                    subscriber.putNext(context.topActivities())
                    disposable.set(ActionDisposable {
                        queue.async {
                            if let strongSelf = self {
                                if let currentContext = strongSelf.contexts[peerId] {
                                    currentContext.removeSubscriber(index)
                                    if currentContext.isEmpty() {
                                        strongSelf.contexts.removeValue(forKey: peerId)
                                    }
                                }
                            }
                        }
                    })
                }
            }
            return disposable
        }
    }
    
    private func collectActivities() -> [PeerId: [PeerId: PeerInputActivity]] {
        assert(self.queue.isCurrent())
        
        var dict: [PeerId: [PeerId: PeerInputActivity]] = [:]
        for (chatPeerId, context) in self.contexts {
            var chatDict: [PeerId: PeerInputActivity] = [:]
            for (peerId, activity) in context.topActivities() {
                chatDict[peerId] = activity
            }
            dict[chatPeerId] = chatDict
        }
        return dict
    }
    
    func allActivities() -> Signal<[PeerId: [PeerId: PeerInputActivity]], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let context: PeerGlobalInputActivityContext
                    if let current = strongSelf.globalContext {
                        context = current
                    } else {
                        context = PeerGlobalInputActivityContext()
                        strongSelf.globalContext = context
                    }
                    let index = context.addSubscriber({ next in
                        subscriber.putNext(next)
                    })
                    subscriber.putNext(strongSelf.collectActivities())
                    
                    disposable.set(ActionDisposable {
                        queue.async {
                            if let strongSelf = self {
                                if let currentContext = strongSelf.globalContext {
                                    currentContext.removeSubscriber(index)
                                    if currentContext.isEmpty {
                                        strongSelf.globalContext = nil
                                    }
                                }
                            }
                        }
                    })
                }
            }
            return disposable
        }
    }
    
    func addActivity(chatPeerId: PeerId, peerId: PeerId, activity: PeerInputActivity) {
        self.queue.async {
            let context: PeerInputActivityContext
            if let currentContext = self.contexts[chatPeerId] {
                context = currentContext
            } else {
                context = PeerInputActivityContext(queue: self.queue, notifyEmpty: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.contexts.removeValue(forKey: chatPeerId)
                        
                        if let globalContext = strongSelf.globalContext {
                            let activities = strongSelf.collectActivities()
                            globalContext.notify(activities)
                        }
                    }
                }, notifyUpdated: { [weak self] in
                    if let strongSelf = self, let globalContext = strongSelf.globalContext {
                        let activities = strongSelf.collectActivities()
                        globalContext.notify(activities)
                    }
                })
                self.contexts[chatPeerId] = context
            }
            context.addActivity(peerId: peerId, activity: activity, timeout: 8.0)
            
            if let globalContext = self.globalContext {
                let activities = self.collectActivities()
                globalContext.notify(activities)
            }
        }
    }
    
    func removeActivity(chatPeerId: PeerId, peerId: PeerId, activity: PeerInputActivity) {
        self.queue.async {
            if let context = self.contexts[chatPeerId] {
                context.removeActivity(peerId: peerId, activity: activity)
                
                if let globalContext = self.globalContext {
                    let activities = self.collectActivities()
                    globalContext.notify(activities)
                }
            }
        }
    }
    
    func removeAllActivities(chatPeerId: PeerId, peerId: PeerId) {
        self.queue.async {
            if let currentContext = self.contexts[chatPeerId] {
                currentContext.removeAllActivities(peerId: peerId)
                
                if let globalContext = self.globalContext {
                    let activities = self.collectActivities()
                    globalContext.notify(activities)
                }
            }
        }
    }
    
    func transaction(_ f: @escaping (PeerInputActivityManager) -> Void) {
        self.queue.async {
            f(self)
        }
    }
}
