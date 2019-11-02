import Foundation
import Postbox
import SwiftSignalKit

private typealias SignalKitTimer = SwiftSignalKit.Timer

private struct ActivityRecord {
    let peerId: PeerId
    let activity: PeerInputActivity
    let id: Int32
    let timer: SignalKitTimer
    let episodeId: Int32?
    let timestamp: Double
    let updateId: Int32
}

private final class PeerInputActivityContext {
    private let queue: Queue
    private let notifyEmpty: () -> Void
    private let notifyUpdated: () -> Void
    
    private var nextId: Int32 = 0
    private var activities: [ActivityRecord] = []
    
    private let subscribers = Bag<([(PeerId, PeerInputActivityRecord)]) -> Void>()
    
    private var scheduledUpdateSubscribers = false
    
    init(queue: Queue, notifyEmpty: @escaping () -> Void, notifyUpdated: @escaping () -> Void) {
        self.queue = queue
        self.notifyEmpty = notifyEmpty
        self.notifyUpdated = notifyUpdated
    }
    
    func addActivity(peerId: PeerId, activity: PeerInputActivity, timeout: Double, episodeId: Int32?, nextUpdateId: inout Int32) {
        assert(self.queue.isCurrent())
        
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        var updated = false
        var found = false
        for i in 0 ..< self.activities.count {
            let record = self.activities[i]
            if record.peerId == peerId && record.activity.key == activity.key && record.episodeId == episodeId {
                found = true
                record.timer.invalidate()
                var updateId = record.updateId
                var recordTimestamp = record.timestamp
                if record.activity != activity || record.timestamp + 4.0 < timestamp {
                    updated = true
                    updateId = nextUpdateId
                    recordTimestamp = timestamp
                    nextUpdateId += 1
                }
                let currentId = record.id
                let timer = SignalKitTimer(timeout: timeout, repeat: false, completion: { [weak self] in
                    if let strongSelf = self {
                        for currentActivity in strongSelf.activities {
                            if currentActivity.id == currentId {
                                strongSelf.removeActivity(peerId: currentActivity.peerId, activity: currentActivity.activity, episodeId: currentActivity.episodeId)
                            }
                        }
                    }
                }, queue: self.queue)
                self.activities[i] = ActivityRecord(peerId: peerId, activity: activity, id: currentId, timer: timer, episodeId: episodeId, timestamp: recordTimestamp, updateId: updateId)
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
                        if currentActivity.id == activityId {
                            strongSelf.removeActivity(peerId: currentActivity.peerId, activity: currentActivity.activity, episodeId: currentActivity.episodeId)
                        }
                    }
                }
            }, queue: self.queue)
            let updateId = nextUpdateId
            nextUpdateId += 1
            self.activities.insert(ActivityRecord(peerId: peerId, activity: activity, id: activityId, timer: timer, episodeId: episodeId, timestamp: timestamp, updateId: updateId), at: 0)
            timer.start()
        }
        
        if updated {
            self.scheduleUpdateSubscribers()
        }
    }
    
    func removeActivity(peerId: PeerId, activity: PeerInputActivity, episodeId: Int32?) {
        assert(self.queue.isCurrent())
        
        for i in 0 ..< self.activities.count {
            let record = self.activities[i]
            if record.peerId == peerId && record.activity.key == activity.key && record.episodeId == episodeId {
                self.activities.remove(at: i)
                record.timer.invalidate()
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
            if record.peerId == peerId {
                record.timer.invalidate()
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
    
    func topActivities() -> [(PeerId, PeerInputActivityRecord)] {
        var peerIds = Set<PeerId>()
        var result: [(PeerId, PeerInputActivityRecord)] = []
        for record in self.activities {
            if !peerIds.contains(record.peerId) {
                peerIds.insert(record.peerId)
                result.append((record.peerId, PeerInputActivityRecord(activity: record.activity, updateId: record.updateId)))
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
    
    func addSubscriber(_ subscriber: @escaping ([(PeerId, PeerInputActivityRecord)]) -> Void) -> Int {
        return self.subscribers.add(subscriber)
    }
    
    func removeSubscriber(_ index: Int) {
        self.subscribers.remove(index)
    }
}

private final class PeerGlobalInputActivityContext {
    private let subscribers = Bag<([PeerId: [PeerId: PeerInputActivityRecord]]) -> Void>()
    
    func addSubscriber(_ subscriber: @escaping ([PeerId: [PeerId: PeerInputActivityRecord]]) -> Void) -> Int {
        return self.subscribers.add(subscriber)
    }
    
    func removeSubscriber(_ index: Int) {
        self.subscribers.remove(index)
    }
    
    var isEmpty: Bool {
        return self.subscribers.isEmpty
    }
    
    func notify(_ activities: [PeerId: [PeerId: PeerInputActivityRecord]]) {
        for subscriber in self.subscribers.copyItems() {
            subscriber(activities)
        }
    }
}

final class PeerInputActivityManager {
    private let queue = Queue()
    
    private var nextEpisodeId: Int32 = 0
    private var nextUpdateId: Int32 = 0
    private var contexts: [PeerId: PeerInputActivityContext] = [:]
    private var globalContext: PeerGlobalInputActivityContext?
    
    func activities(peerId: PeerId) -> Signal<[(PeerId, PeerInputActivityRecord)], NoError> {
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
    
    private func collectActivities() -> [PeerId: [PeerId: PeerInputActivityRecord]] {
        assert(self.queue.isCurrent())
        
        var dict: [PeerId: [PeerId: PeerInputActivityRecord]] = [:]
        for (chatPeerId, context) in self.contexts {
            var chatDict: [PeerId: PeerInputActivityRecord] = [:]
            for (peerId, activity) in context.topActivities() {
                chatDict[peerId] = activity
            }
            dict[chatPeerId] = chatDict
        }
        return dict
    }
    
    func allActivities() -> Signal<[PeerId: [PeerId: PeerInputActivityRecord]], NoError> {
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
    
    func addActivity(chatPeerId: PeerId, peerId: PeerId, activity: PeerInputActivity, episodeId: Int32? = nil) {
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
            context.addActivity(peerId: peerId, activity: activity, timeout: 8.0, episodeId: episodeId, nextUpdateId: &self.nextUpdateId)
            
            if let globalContext = self.globalContext {
                let activities = self.collectActivities()
                globalContext.notify(activities)
            }
        }
    }
    
    func removeActivity(chatPeerId: PeerId, peerId: PeerId, activity: PeerInputActivity, episodeId: Int32? = nil) {
        self.queue.async {
            if let context = self.contexts[chatPeerId] {
                context.removeActivity(peerId: peerId, activity: activity, episodeId: episodeId)
                
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
    
    func acquireActivity(chatPeerId: PeerId, peerId: PeerId, activity: PeerInputActivity) -> Disposable {
        let disposable = MetaDisposable()
        let queue = self.queue
        queue.async {
            let episodeId = self.nextEpisodeId
            self.nextEpisodeId += 1
            
            let update: () -> Void = { [weak self] in
                self?.addActivity(chatPeerId: chatPeerId, peerId: peerId, activity: activity, episodeId: episodeId)
            }
            
            let timer = SignalKitTimer(timeout: 5.0, repeat: true, completion: {
                update()
            }, queue: queue)
            timer.start()
            update()
            
            disposable.set(ActionDisposable { [weak self] in
                queue.async {
                    timer.invalidate()
                    guard let strongSelf = self else {
                        return
                    }
                    
                    strongSelf.removeActivity(chatPeerId: chatPeerId, peerId: peerId, activity: activity, episodeId: episodeId)
                }
            })
        }
        return disposable
    }
}
