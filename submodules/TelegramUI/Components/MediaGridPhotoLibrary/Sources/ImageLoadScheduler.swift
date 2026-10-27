import Foundation
import UIKit
import MediaGrid

final class ImageLoadScheduler<Key: Hashable, PrefetchKey: Hashable, Payload> {
    enum JobState {
        case pending
        case running
        case finished
    }

    final class Consumer {
        let completion: (UIImage?, Bool) -> Void

        init(completion: @escaping (UIImage?, Bool) -> Void) {
            self.completion = completion
        }
    }

    final class Job {
        let key: Key
        let payload: Payload
        fileprivate(set) var consumers: [ObjectIdentifier: Consumer] = [:] {
            didSet {
                self.publish()
            }
        }
        fileprivate(set) var isPrefetched = false
        fileprivate(set) var usesNetwork = false
        fileprivate(set) var state: JobState = .pending {
            didSet {
                self.publish()
            }
        }
        fileprivate(set) var attempt = 0 {
            didSet {
                self.publish()
            }
        }
        fileprivate var restarts = 0
        var token: Int32?
        private let lock = NSLock()
        private var deliverableAttempt: Int?

        init(key: Key, payload: Payload) {
            self.key = key
            self.payload = payload
        }

        private func publish() {
            let attempt = self.state == .running && !self.consumers.isEmpty ? self.attempt : nil
            self.lock.lock()
            self.deliverableAttempt = attempt
            self.lock.unlock()
        }

        func hasConsumers(running attempt: Int) -> Bool {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            return self.deliverableAttempt == attempt
        }

        var isWanted: Bool {
            return !self.consumers.isEmpty || self.isPrefetched
        }
    }

    final class Lane {
        let limit: Int
        let prefetchLimit: Int
        fileprivate(set) var running = 0
        fileprivate var visible: [Job] = []
        fileprivate var compactionThreshold = ImageLoadScheduler.minimumCompactionThreshold
        fileprivate var staleCount = 0

        init(limit: Int, prefetchLimit: Int) {
            self.limit = limit
            self.prefetchLimit = prefetchLimit
        }

        var queuedCount: Int {
            return self.visible.count
        }
    }

    private final class Handle: MediaGridImageRequest {
        weak var scheduler: ImageLoadScheduler?
        let job: Job
        let consumer: Consumer

        init(scheduler: ImageLoadScheduler, job: Job, consumer: Consumer) {
            self.scheduler = scheduler
            self.job = job
            self.consumer = consumer
        }

        func cancel() {
            self.scheduler?.remove(self.consumer, from: self.job)
        }
    }

    static var minimumCompactionThreshold: Int {
        return 256
    }

    static var maximumRestarts: Int {
        return 2
    }

    let localLane: Lane
    let networkLane: Lane
    var startJob: (Job) -> Void = { _ in }
    var cancelJob: (Job) -> Void = { _ in }
    var resolvePrefetch: (PrefetchKey) -> (key: Key, payload: Payload)? = { _ in nil }
    var isCached: (Key) -> Bool = { _ in false }
    var scheduleFlush: (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    var networkLaneDidChange: () -> Void = {}

    var isNetworkLaneIdle: Bool {
        return self.networkLane.running == 0 && !self.networkLane.visible.contains(where: { $0.state == .pending && $0.isWanted })
    }

    private(set) var jobs: [Key: Job] = [:]
    private var prefetchQueue: [PrefetchKey] = []
    private var prefetchHead = 0
    private var prefetchWanted = Set<PrefetchKey>()
    private var prefetchJobs: [PrefetchKey: Job] = [:]
    private var pendingDrops: [PrefetchKey] = []
    private var isFlushScheduled = false
    private var isBatching = false
    private var isPumping = false
    private var needsPump = false

    init(localLimit: Int, localPrefetchLimit: Int, networkLimit: Int) {
        self.localLane = Lane(limit: localLimit, prefetchLimit: localPrefetchLimit)
        self.networkLane = Lane(limit: networkLimit, prefetchLimit: 0)
    }

    var queuedPrefetchCount: Int {
        return self.prefetchQueue.count - self.prefetchHead
    }

    var wantedPrefetchCount: Int {
        return self.prefetchWanted.count
    }

    func request(key: Key, payload: @autoclosure () -> Payload, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest {
        let job: Job
        if let existing = self.jobs[key] {
            job = existing
        } else {
            job = Job(key: key, payload: payload())
            self.jobs[key] = job
        }
        let consumer = Consumer(completion: completion)
        job.consumers[ObjectIdentifier(consumer)] = consumer
        if job.state == .pending {
            self.push(job)
            self.pump()
        }
        return Handle(scheduler: self, job: job, consumer: consumer)
    }

    func batch(_ body: () -> Void) {
        let wasBatching = self.isBatching
        self.isBatching = true
        body()
        self.isBatching = wasBatching
        if !wasBatching {
            self.pump()
        }
    }

    func startPrefetching(_ keys: [PrefetchKey]) {
        for key in keys {
            if self.prefetchWanted.insert(key).inserted && self.prefetchJobs[key] == nil {
                self.prefetchQueue.append(key)
            }
        }
        self.compactPrefetchQueueIfNeeded()
        self.pump()
    }

    func stopPrefetching(_ keys: [PrefetchKey]) {
        for key in keys {
            guard self.prefetchWanted.remove(key) != nil, self.prefetchJobs[key] != nil else {
                continue
            }
            self.pendingDrops.append(key)
        }
        self.compactPrefetchQueueIfNeeded()
        if !self.pendingDrops.isEmpty && !self.isFlushScheduled {
            self.isFlushScheduled = true
            self.scheduleFlush { [weak self] in
                self?.flushPendingDrops()
            }
        }
    }

    func remapPrefetching(_ transform: (PrefetchKey) -> PrefetchKey?, update: () -> Void) {
        var wanted = Set<PrefetchKey>()
        for key in self.prefetchWanted {
            if let mapped = transform(key) {
                wanted.insert(mapped)
            }
        }
        var queue: [PrefetchKey] = []
        for index in self.prefetchHead ..< self.prefetchQueue.count {
            if let mapped = transform(self.prefetchQueue[index]) {
                queue.append(mapped)
            }
        }
        var jobs: [PrefetchKey: Job] = [:]
        var dropped: [Job] = []
        for (key, job) in self.prefetchJobs {
            if let mapped = transform(key) {
                jobs[mapped] = job
            } else {
                dropped.append(job)
            }
        }
        self.pendingDrops = self.pendingDrops.compactMap(transform)
        self.prefetchWanted = wanted
        self.prefetchQueue = queue
        self.prefetchHead = 0
        self.prefetchJobs = jobs
        let wasBatching = self.isBatching
        self.isBatching = true
        for job in dropped {
            job.isPrefetched = false
            self.dropIfUnwanted(job)
        }
        update()
        self.isBatching = wasBatching
        if !wasBatching {
            self.pump()
        }
    }

    func flushPendingDrops() {
        self.isFlushScheduled = false
        let drops = self.pendingDrops
        self.pendingDrops = []
        self.isBatching = true
        for key in drops where !self.prefetchWanted.contains(key) {
            guard let job = self.prefetchJobs.removeValue(forKey: key) else {
                continue
            }
            job.isPrefetched = false
            self.dropIfUnwanted(job)
        }
        self.isBatching = false
        self.pump()
    }

    func deliverDegraded(_ job: Job, attempt: Int, image: UIImage) {
        guard job.state == .running, job.attempt == attempt else {
            return
        }
        for consumer in job.consumers.values {
            consumer.completion(image, true)
        }
    }

    func finish(_ job: Job, attempt: Int, image: UIImage?) {
        guard job.state == .running, job.attempt == attempt else {
            return
        }
        job.state = .finished
        self.lane(for: job).running -= 1
        if self.jobs[job.key] === job {
            self.jobs.removeValue(forKey: job.key)
        }
        if job.usesNetwork {
            self.networkLaneDidChange()
        }
        let consumers = Array(job.consumers.values)
        job.consumers.removeAll()
        for consumer in consumers {
            consumer.completion(image, false)
        }
        self.pump()
    }

    func moveToNetwork(_ job: Job, attempt: Int) -> Bool {
        guard job.state == .running, job.attempt == attempt, !job.usesNetwork, !job.consumers.isEmpty else {
            return false
        }
        self.localLane.running -= 1
        job.state = .pending
        job.token = nil
        job.usesNetwork = true
        self.push(job)
        self.pump()
        self.networkLaneDidChange()
        return true
    }

    func cancelledExternally(_ job: Job, attempt: Int) {
        guard job.state == .running, job.attempt == attempt else {
            return
        }
        guard job.isWanted, job.restarts < ImageLoadScheduler.maximumRestarts else {
            self.finish(job, attempt: attempt, image: nil)
            return
        }
        job.restarts += 1
        self.lane(for: job).running -= 1
        job.state = .pending
        job.token = nil
        self.push(job)
        self.pump()
    }

    private func lane(for job: Job) -> Lane {
        return job.usesNetwork ? self.networkLane : self.localLane
    }

    private func push(_ job: Job) {
        let lane = self.lane(for: job)
        if lane.visible.count >= lane.compactionThreshold {
            self.compact(lane)
        }
        lane.visible.append(job)
    }

    private func compact(_ lane: Lane) {
        lane.visible.removeAll(where: { $0.state != .pending || !$0.isWanted })
        lane.staleCount = 0
        lane.compactionThreshold = max(ImageLoadScheduler.minimumCompactionThreshold, lane.visible.count * 2)
    }

    private func compactPrefetchQueueIfNeeded() {
        let queued = self.prefetchQueue.count - self.prefetchHead
        guard queued > 2 * self.prefetchWanted.count + ImageLoadScheduler.minimumCompactionThreshold else {
            return
        }
        var seen = Set<PrefetchKey>()
        var compacted: [PrefetchKey] = []
        compacted.reserveCapacity(self.prefetchWanted.count)
        for index in self.prefetchHead ..< self.prefetchQueue.count {
            let key = self.prefetchQueue[index]
            if self.prefetchWanted.contains(key) && self.prefetchJobs[key] == nil && seen.insert(key).inserted {
                compacted.append(key)
            }
        }
        self.prefetchQueue = compacted
        self.prefetchHead = 0
    }

    private func remove(_ consumer: Consumer, from job: Job) {
        job.consumers.removeValue(forKey: ObjectIdentifier(consumer))
        self.dropIfUnwanted(job)
    }

    private func dropIfUnwanted(_ job: Job) {
        guard !job.isWanted, job.state != .finished else {
            return
        }
        let wasRunning = job.state == .running
        job.state = .finished
        if self.jobs[job.key] === job {
            self.jobs.removeValue(forKey: job.key)
        }
        if !wasRunning {
            let lane = self.lane(for: job)
            lane.staleCount += 1
            if lane.staleCount > max(ImageLoadScheduler.minimumCompactionThreshold, lane.visible.count / 2) {
                self.compact(lane)
            }
        }
        if wasRunning {
            self.cancelJob(job)
            self.lane(for: job).running -= 1
            self.pump()
        }
        if job.usesNetwork {
            self.networkLaneDidChange()
        }
    }

    func pump() {
        if self.isBatching {
            return
        }
        if self.isPumping {
            self.needsPump = true
            return
        }
        self.isPumping = true
        repeat {
            self.needsPump = false
            for lane in [self.localLane, self.networkLane] {
                while lane.running < lane.limit, let job = self.nextJob(in: lane) {
                    job.state = .running
                    job.attempt += 1
                    lane.running += 1
                    self.startJob(job)
                }
            }
        } while self.needsPump
        self.isPumping = false
    }

    private func nextJob(in lane: Lane) -> Job? {
        while let job = lane.visible.popLast() {
            if job.state == .pending && job.isWanted {
                return job
            }
            lane.staleCount = max(0, lane.staleCount - 1)
        }
        guard lane === self.localLane, lane.running < lane.prefetchLimit else {
            return nil
        }
        while self.prefetchHead < self.prefetchQueue.count {
            let prefetchKey = self.prefetchQueue[self.prefetchHead]
            self.prefetchHead += 1
            guard self.prefetchWanted.contains(prefetchKey), self.prefetchJobs[prefetchKey] == nil, let resolved = self.resolvePrefetch(prefetchKey) else {
                continue
            }
            if let job = self.jobs[resolved.key] {
                job.isPrefetched = true
                self.prefetchJobs[prefetchKey] = job
                continue
            }
            if self.isCached(resolved.key) {
                continue
            }
            let job = Job(key: resolved.key, payload: resolved.payload)
            job.isPrefetched = true
            self.jobs[resolved.key] = job
            self.prefetchJobs[prefetchKey] = job
            return job
        }
        self.prefetchQueue.removeAll(keepingCapacity: true)
        self.prefetchHead = 0
        return nil
    }
}
