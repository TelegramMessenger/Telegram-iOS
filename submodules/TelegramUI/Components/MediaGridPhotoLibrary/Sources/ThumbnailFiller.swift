import Foundation
import CoreGraphics
import UIKit
import Photos
import MediaGrid

struct ThumbnailCatalog {
    let ids: [String]
    let versions: [String]
    let indexById: [String: Int]

    static let empty = ThumbnailCatalog(ids: [], versions: [])

    init(ids: [String], versions: [String]) {
        self.ids = ids
        self.versions = versions
        var indexById: [String: Int] = [:]
        indexById.reserveCapacity(ids.count)
        for (index, id) in ids.enumerated() {
            indexById[id] = index
        }
        self.indexById = indexById
    }

    var count: Int {
        return self.ids.count
    }

    func id(at index: Int) -> String? {
        guard index >= 0, index < self.ids.count else {
            return nil
        }
        return self.ids[index]
    }

    static func build(count: Int, entry: (Int) -> (id: String, version: String)) -> ThumbnailCatalog {
        var ids: [String] = []
        var versions: [String] = []
        ids.reserveCapacity(count)
        versions.reserveCapacity(count)
        for index in 0 ..< count {
            let item = entry(index)
            ids.append(item.id)
            versions.append(item.version)
        }
        return ThumbnailCatalog(ids: ids, versions: versions)
    }

    func applying(_ changes: MediaGridChanges, newCount: Int, entry: (Int) -> (id: String, version: String)) -> ThumbnailCatalog {
        var ids: [String] = []
        var versions: [String] = []
        ids.reserveCapacity(newCount)
        versions.reserveCapacity(newCount)
        var old = 0
        for index in 0 ..< newCount {
            if changes.inserted.contains(index) {
                let item = entry(index)
                ids.append(item.id)
                versions.append(item.version)
                continue
            }
            while changes.removed.contains(old) {
                old += 1
            }
            if changes.changed.contains(index) || old >= self.ids.count {
                let item = entry(index)
                ids.append(item.id)
                versions.append(item.version)
            } else {
                ids.append(self.ids[old])
                versions.append(self.versions[old])
            }
            old += 1
        }
        return ThumbnailCatalog(ids: ids, versions: versions)
    }
}

enum ThumbnailFillState: UInt8 {
    case missing = 0
    case filled = 1
    case unavailable = 2
    case inFlight = 3
}

struct ThumbnailFillPlan {
    var catalog: ThumbnailCatalog
    var states: [ThumbnailFillState]
    var filled: Int
    var unavailable: Int
    var missing: IndexSet
    var unavailableIndices: IndexSet
    var failures: [(index: Int, failures: Int)]
    var orphans: [String]
    var retryOrphans: [String]

    static func make(catalog: ThumbnailCatalog, isFilled: (String, String) -> Bool, retryFailures: (String, String) -> Int?, storedIds: [String], retryIds: [String] = []) -> ThumbnailFillPlan {
        var states: [ThumbnailFillState] = []
        states.reserveCapacity(catalog.count)
        var filled = 0
        var missing = IndexSet()
        var unavailableIndices = IndexSet()
        var failures: [(index: Int, failures: Int)] = []
        for index in 0 ..< catalog.count {
            let id = catalog.ids[index]
            let version = catalog.versions[index]
            if isFilled(id, version) {
                states.append(.filled)
                filled += 1
            } else if let count = retryFailures(id, version) {
                states.append(.unavailable)
                unavailableIndices.insert(index)
                failures.append((index, count))
            } else {
                states.append(.missing)
                missing.insert(index)
            }
        }
        let orphans = storedIds.filter { catalog.indexById[$0] == nil }
        let retryOrphans = retryIds.filter { catalog.indexById[$0] == nil }
        return ThumbnailFillPlan(catalog: catalog, states: states, filled: filled, unavailable: unavailableIndices.count, missing: missing, unavailableIndices: unavailableIndices, failures: failures, orphans: orphans, retryOrphans: retryOrphans)
    }
}

enum ThumbnailImageResult {
    case image(CGImage)
    case unavailable
    case cancelled
}

protocol ThumbnailRequest: AnyObject {
    func cancel()
}

protocol ThumbnailImageSource: AnyObject {
    func requestThumbnail(index: Int, id: String, network: Bool, completion: @escaping (ThumbnailImageResult) -> Void) -> ThumbnailRequest?
}

final class ThumbnailRetryRegistry {
    private struct Entry: Codable {
        var version: String
        var failures: Int
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var isLoaded = false
    private let url: URL?
    private var isSaveScheduled = false
    private let queue = DispatchQueue(label: "org.telegram.MediaGridPhotoLibrary.thumbnailRetries", qos: .utility)

    init(url: URL?) {
        self.url = url
    }

    private func loadIfNeeded() {
        if self.isLoaded {
            return
        }
        self.isLoaded = true
        if let url = self.url, let data = try? Data(contentsOf: url), let entries = try? PropertyListDecoder().decode([String: Entry].self, from: data) {
            self.entries = entries
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.loadIfNeeded()
        return body()
    }

    func failures(id: String, version: String) -> Int? {
        return self.locked {
            guard let entry = self.entries[id], entry.version == version else {
                return nil
            }
            return entry.failures
        }
    }

    var count: Int {
        return self.locked { self.entries.count }
    }

    func ids() -> [String] {
        return self.locked { Array(self.entries.keys) }
    }

    func recordFailure(id: String, version: String) -> Int {
        let failures: Int = self.locked {
            var entry = self.entries[id] ?? Entry(version: version, failures: 0)
            if entry.version != version {
                entry = Entry(version: version, failures: 0)
            }
            entry.failures += 1
            self.entries[id] = entry
            return entry.failures
        }
        self.scheduleSave()
        return failures
    }

    func remove(ids: [String]) {
        let changed: Bool = self.locked {
            var changed = false
            for id in ids where self.entries.removeValue(forKey: id) != nil {
                changed = true
            }
            return changed
        }
        if changed {
            self.scheduleSave()
        }
    }

    private func scheduleSave() {
        guard let url = self.url else {
            return
        }
        self.lock.lock()
        let isScheduled = self.isSaveScheduled
        self.isSaveScheduled = true
        self.lock.unlock()
        if isScheduled {
            return
        }
        self.queue.asyncAfter(deadline: .now() + 2.0) {
            self.lock.lock()
            let entries = self.entries
            self.isSaveScheduled = false
            self.lock.unlock()
            if let data = try? PropertyListEncoder().encode(entries) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}

final class ThumbnailFiller {
    static let idleLimit = 16
    static let fastLimit = 4
    static let networkLimit = 2
    static let backoff: [Double] = [30.0, 120.0, 600.0]
    static let launchRetryDelay: Double = 30.0
    static let launchRetryBatch = 256
    static let launchRetryInterval: Double = 1.0

    private struct PendingRetry {
        let due: Double
        let id: String
        let version: String
        let failures: Int
    }

    private struct NetworkRequest {
        let version: String
        let serial: Int
        let request: ThumbnailRequest?
    }

    let store: MediaGridThumbnailStore
    private let source: ThumbnailImageSource
    let registry: ThumbnailRetryRegistry
    private let clock: () -> Double
    private let schedule: (Double, @escaping () -> Void) -> Void

    private(set) var catalog = ThumbnailCatalog.empty
    private var states: [ThumbnailFillState] = []
    private var missing = IndexSet()
    private var networkEligible = IndexSet()
    private var networkTried = Set<String>()
    private(set) var filledCount = 0
    private(set) var unavailableCount = 0
    private(set) var hasPlan = false
    private(set) var isComplete = false
    private(set) var probeCount = 0
    private var inFlight: [String: String] = [:]
    private var networkInFlight: [String: NetworkRequest] = [:]
    private var networkSerial = 0
    private var urgent: [String] = []
    private var ranges: [Range<Int>] = []
    private var center = 0
    private var outwardRadius = 0
    private var retryQueues: [[PendingRetry]] = Array(repeating: [], count: ThumbnailFiller.backoff.count + 1)
    private var retryHeads: [Int] = Array(repeating: 0, count: ThumbnailFiller.backoff.count + 1)
    private var scheduledRetryTime: Double?
    private var hasScheduledLaunchRetries = false
    private var launchPending: [String: String] = [:]
    private var launchPendingIndices = IndexSet()
    private var launchReleaseTime: Double?
    private var retryDue = Set<String>()
    private(set) var launchRetriesReleased = 0
    var networkGate: () -> Bool = { false }
    var onProgress: (() -> Void)?
    var onNetworkFill: ((String) -> Void)?

    var isMovingFast = false {
        didSet {
            if self.isMovingFast != oldValue {
                if !self.isMovingFast, self.launchReleaseTime != nil {
                    self.processRetries()
                }
                self.pump()
            }
        }
    }

    var isPaused = false {
        didSet {
            if self.isPaused != oldValue {
                self.pump()
            }
        }
    }

    var inFlightCount: Int {
        return self.inFlight.count
    }

    var networkInFlightCount: Int {
        return self.networkInFlight.count
    }

    var missingCount: Int {
        return self.missing.count
    }

    var limit: Int {
        return self.isMovingFast ? ThumbnailFiller.fastLimit : ThumbnailFiller.idleLimit
    }

    init(store: MediaGridThumbnailStore, source: ThumbnailImageSource, registry: ThumbnailRetryRegistry, clock: @escaping () -> Double = { CACurrentMediaTime() }, schedule: @escaping (Double, @escaping () -> Void) -> Void = { delay, body in DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: body) }) {
        self.store = store
        self.source = source
        self.registry = registry
        self.clock = clock
        self.schedule = schedule
        self.isPaused = !store.isWritable
    }

    func makePlan(for catalog: ThumbnailCatalog) -> ThumbnailFillPlan {
        let store = self.store
        let registry = self.registry
        return ThumbnailFillPlan.make(catalog: catalog, isFilled: { id, version in
            return store.version(for: id) == version
        }, retryFailures: { id, version in
            return registry.failures(id: id, version: version)
        }, storedIds: store.storedIds(), retryIds: registry.ids())
    }

    func install(_ plan: ThumbnailFillPlan, removed: [String] = [], urgent: [String] = []) {
        let orphans = removed + plan.orphans
        if !orphans.isEmpty {
            self.store.remove(ids: orphans)
        }
        let catalog = plan.catalog
        if !removed.isEmpty || !plan.retryOrphans.isEmpty {
            self.registry.remove(ids: removed + plan.retryOrphans)
        }
        self.catalog = catalog
        self.states = plan.states
        self.filledCount = plan.filled
        self.unavailableCount = plan.unavailable
        self.missing = plan.missing
        self.networkEligible = plan.unavailableIndices
        for id in self.networkTried {
            if let index = catalog.indexById[id] {
                self.networkEligible.remove(index)
            }
        }
        for id in self.inFlight.keys {
            if let index = catalog.indexById[id] {
                self.setState(.inFlight, at: index)
            }
        }
        for id in self.networkInFlight.keys {
            if let index = catalog.indexById[id] {
                self.networkEligible.remove(index)
            }
        }
        for id in self.retryDue {
            if let index = catalog.indexById[id], self.states[index] == .unavailable {
                self.setState(.missing, at: index)
            }
        }
        if !self.hasScheduledLaunchRetries {
            self.hasScheduledLaunchRetries = true
            for (index, _) in plan.failures {
                self.launchPending[catalog.ids[index]] = catalog.versions[index]
            }
            if !self.launchPending.isEmpty {
                self.launchReleaseTime = self.clock() + ThumbnailFiller.launchRetryDelay
            }
        }
        self.launchPendingIndices = IndexSet(self.launchPending.keys.compactMap { catalog.indexById[$0] })
        self.scheduleRetryTimer()
        self.urgent.append(contentsOf: urgent)
        self.hasPlan = true
        self.isComplete = false
        self.pump()
        self.onProgress?()
    }

    func setPriority(ranges: [Range<Int>]) {
        guard ranges != self.ranges else {
            return
        }
        self.ranges = ranges
        if let first = ranges.first {
            self.center = (first.lowerBound + first.upperBound) / 2
            self.outwardRadius = max(512, first.count * 4)
        }
        self.pump()
    }

    func networkConditionsChanged() {
        self.pump()
    }

    func harvestVersion(for id: String) -> String? {
        guard let index = self.catalog.indexById[id] else {
            return nil
        }
        let version = self.catalog.versions[index]
        return self.store.version(for: id) == version ? nil : version
    }

    func harvest(id: String, version: String, image: CGImage) {
        guard let index = self.catalog.indexById[id], self.catalog.versions[index] == version else {
            return
        }
        if self.store.version(for: id) != version {
            self.store.write(image, id: id, version: version)
        }
        guard self.store.version(for: id) == version else {
            return
        }
        self.registry.remove(ids: [id])
        self.retryDue.remove(id)
        if let network = self.networkInFlight.removeValue(forKey: id) {
            network.request?.cancel()
        }
        if self.states[index] != .inFlight {
            self.setState(.filled, at: index)
        }
        self.pump()
        self.onProgress?()
    }

    func retryNow(ids: [String]) {
        var changed = false
        for id in ids {
            guard let index = self.catalog.indexById[id], self.states[index] == .unavailable, self.networkInFlight[id] == nil else {
                continue
            }
            self.networkTried.remove(id)
            self.retryDue.insert(id)
            self.setState(.missing, at: index)
            changed = true
        }
        if changed {
            self.isComplete = false
            self.pump()
        }
    }

    func storeChanged(ids: Set<String>) {
        var changed = false
        for id in ids {
            guard let index = self.catalog.indexById[id] else {
                continue
            }
            let isCurrent = self.store.version(for: id) == self.catalog.versions[index]
            if self.states[index] == .filled && !isCurrent {
                self.setState(.missing, at: index)
                changed = true
            } else if self.states[index] == .unavailable && isCurrent {
                self.registry.remove(ids: [id])
                self.setState(.filled, at: index)
            }
        }
        if changed {
            self.isComplete = false
            self.pump()
        }
    }

    func processRetries() {
        let now = self.clock()
        var changed = false
        for level in 0 ..< self.retryQueues.count {
            while self.retryHeads[level] < self.retryQueues[level].count, self.retryQueues[level][self.retryHeads[level]].due <= now {
                let retry = self.retryQueues[level][self.retryHeads[level]]
                self.retryHeads[level] += 1
                guard let index = self.catalog.indexById[retry.id], self.catalog.versions[index] == retry.version, self.states[index] == .unavailable, self.networkInFlight[retry.id] == nil, self.registry.failures(id: retry.id, version: retry.version) == retry.failures else {
                    continue
                }
                self.networkTried.remove(retry.id)
                self.retryDue.insert(retry.id)
                self.setState(.missing, at: index)
                changed = true
            }
            if self.retryHeads[level] > 256 && self.retryHeads[level] * 2 > self.retryQueues[level].count {
                self.retryQueues[level].removeFirst(self.retryHeads[level])
                self.retryHeads[level] = 0
            }
        }
        if let release = self.launchReleaseTime, release <= now, !self.isMovingFast {
            changed = self.releaseLaunchRetries() || changed
            self.launchReleaseTime = self.launchPending.isEmpty ? nil : now + ThumbnailFiller.launchRetryInterval
        }
        self.scheduledRetryTime = nil
        self.scheduleRetryTimer()
        if changed {
            self.isComplete = false
            self.pump()
        }
    }

    private func releaseLaunchRetries() -> Bool {
        var released = 0
        var changed = false
        while released < ThumbnailFiller.launchRetryBatch, let index = self.nearest(in: self.launchPendingIndices, radius: nil) {
            self.launchPendingIndices.remove(index)
            let id = self.catalog.ids[index]
            let version = self.launchPending.removeValue(forKey: id)
            released += 1
            guard version == self.catalog.versions[index], self.states[index] == .unavailable, self.networkInFlight[id] == nil, self.registry.failures(id: id, version: self.catalog.versions[index]) != nil else {
                continue
            }
            self.networkTried.remove(id)
            self.retryDue.insert(id)
            self.setState(.missing, at: index)
            self.launchRetriesReleased += 1
            changed = true
        }
        if self.launchPendingIndices.isEmpty {
            self.launchPending.removeAll()
        }
        return changed
    }

    private func scheduleRetryTimer() {
        var earliest: Double? = self.isMovingFast ? nil : self.launchReleaseTime
        for level in 0 ..< self.retryQueues.count where self.retryHeads[level] < self.retryQueues[level].count {
            let due = self.retryQueues[level][self.retryHeads[level]].due
            earliest = min(earliest ?? due, due)
        }
        guard let earliest else {
            return
        }
        if let scheduled = self.scheduledRetryTime, scheduled <= earliest {
            return
        }
        self.scheduledRetryTime = earliest
        self.schedule(max(0.0, earliest - self.clock()), { [weak self] in
            guard let self, let scheduled = self.scheduledRetryTime, scheduled <= self.clock() + 0.001 else {
                return
            }
            self.processRetries()
        })
    }

    private func recordFailure(id: String, version: String) {
        let failures = self.registry.recordFailure(id: id, version: version)
        guard failures <= ThumbnailFiller.backoff.count else {
            return
        }
        let level = failures - 1
        self.retryQueues[level].append(PendingRetry(due: self.clock() + ThumbnailFiller.backoff[level], id: id, version: version, failures: failures))
        self.scheduleRetryTimer()
    }

    private func setState(_ state: ThumbnailFillState, at index: Int) {
        let previous = self.states[index]
        if previous == state {
            return
        }
        switch previous {
        case .filled:
            self.filledCount -= 1
        case .unavailable:
            self.unavailableCount -= 1
            self.networkEligible.remove(index)
        case .missing:
            self.missing.remove(index)
        case .inFlight:
            break
        }
        switch state {
        case .filled:
            self.filledCount += 1
        case .unavailable:
            self.unavailableCount += 1
            if !self.networkTried.contains(self.catalog.ids[index]) && self.networkInFlight[self.catalog.ids[index]] == nil {
                self.networkEligible.insert(index)
            }
        case .missing:
            self.missing.insert(index)
        case .inFlight:
            break
        }
        self.states[index] = state
    }

    private func nearest(in set: IndexSet, radius: Int?) -> Int? {
        self.probeCount += 1
        for range in self.ranges {
            guard !range.isEmpty, let index = set.integerGreaterThanOrEqualTo(range.lowerBound), index < range.upperBound else {
                continue
            }
            return index
        }
        if !self.ranges.isEmpty {
            let up = set.integerGreaterThanOrEqualTo(self.center)
            let down = set.integerLessThan(self.center)
            let upDistance = up.map { $0 - self.center }
            let downDistance = down.map { self.center - $0 }
            var best: Int?
            if let up, let upDistance, let downDistance {
                best = upDistance < downDistance ? up : down
            } else {
                best = up ?? down
            }
            if let best, radius.map({ abs(best - self.center) <= $0 }) ?? true {
                return best
            }
        }
        return set.first
    }

    private func nextCandidate() -> Int? {
        if self.missing.isEmpty {
            self.urgent.removeAll()
            return nil
        }
        while let id = self.urgent.first {
            self.urgent.removeFirst()
            self.probeCount += 1
            if let index = self.catalog.indexById[id], self.states[index] == .missing {
                return index
            }
        }
        return self.nearest(in: self.missing, radius: self.outwardRadius)
    }

    func pump() {
        guard self.hasPlan else {
            return
        }
        self.pumpNetwork()
        guard !self.isPaused else {
            return
        }
        var exhausted = false
        while self.inFlight.count < self.limit {
            guard let index = self.nextCandidate() else {
                exhausted = true
                break
            }
            let id = self.catalog.ids[index]
            let version = self.catalog.versions[index]
            if self.store.version(for: id) == version {
                self.retryDue.remove(id)
                self.setState(.filled, at: index)
                continue
            }
            if self.inFlight[id] != nil {
                self.setState(.inFlight, at: index)
                continue
            }
            self.inFlight[id] = version
            self.retryDue.remove(id)
            self.setState(.inFlight, at: index)
            _ = self.source.requestThumbnail(index: index, id: id, network: false, completion: { [weak self] result in
                self?.complete(id: id, version: version, result: result)
            })
        }
        if exhausted && self.inFlight.isEmpty && !self.isComplete {
            self.isComplete = true
            self.onProgress?()
        }
        self.pumpNetwork()
    }

    private func pumpNetwork() {
        guard !self.isPaused, !self.isMovingFast, self.networkGate() else {
            if !self.networkInFlight.isEmpty {
                let running = self.networkInFlight
                self.networkInFlight.removeAll()
                for (id, network) in running {
                    network.request?.cancel()
                    if let index = self.catalog.indexById[id], self.states[index] == .unavailable {
                        self.networkEligible.insert(index)
                    }
                }
            }
            return
        }
        while self.networkInFlight.count < ThumbnailFiller.networkLimit, let index = self.nearest(in: self.networkEligible, radius: nil) {
            let id = self.catalog.ids[index]
            let version = self.catalog.versions[index]
            self.networkEligible.remove(index)
            self.networkSerial += 1
            let serial = self.networkSerial
            self.networkInFlight[id] = NetworkRequest(version: version, serial: serial, request: nil)
            let request = self.source.requestThumbnail(index: index, id: id, network: true, completion: { [weak self] result in
                self?.completeNetwork(id: id, version: version, serial: serial, result: result)
            })
            if self.networkInFlight[id]?.serial == serial {
                self.networkInFlight[id] = NetworkRequest(version: version, serial: serial, request: request)
            }
        }
    }

    private func complete(id: String, version: String, result: ThumbnailImageResult) {
        self.inFlight.removeValue(forKey: id)
        if let index = self.catalog.indexById[id] {
            let isCurrent = self.catalog.versions[index] == version
            switch result {
            case let .image(image):
                if isCurrent {
                    self.writeAndMark(image, index: index, id: id, version: version)
                } else {
                    self.setState(.missing, at: index)
                }
            case .unavailable:
                if isCurrent {
                    if self.store.version(for: id) == version {
                        self.registry.remove(ids: [id])
                        self.setState(.filled, at: index)
                    } else if self.states[index] == .inFlight {
                        self.recordFailure(id: id, version: version)
                        self.setState(.unavailable, at: index)
                    }
                } else {
                    self.setState(.missing, at: index)
                }
            case .cancelled:
                if self.states[index] == .inFlight {
                    self.setState(.missing, at: index)
                }
            }
        }
        if !self.missing.isEmpty {
            self.isComplete = false
        }
        self.pump()
        self.onProgress?()
    }

    @discardableResult
    private func writeAndMark(_ image: CGImage, index: Int, id: String, version: String) -> Bool {
        self.store.write(image, id: id, version: version)
        guard self.store.version(for: id) == version else {
            if self.states[index] == .unavailable {
                self.networkTried.insert(id)
                self.networkEligible.remove(index)
            } else {
                self.recordFailure(id: id, version: version)
                self.setState(.unavailable, at: index)
                self.networkTried.insert(id)
                self.networkEligible.remove(index)
            }
            return false
        }
        self.registry.remove(ids: [id])
        self.retryDue.remove(id)
        self.setState(.filled, at: index)
        return true
    }

    private func completeNetwork(id: String, version: String, serial: Int, result: ThumbnailImageResult) {
        guard self.networkInFlight[id]?.serial == serial else {
            return
        }
        self.networkInFlight.removeValue(forKey: id)
        guard let index = self.catalog.indexById[id], self.catalog.versions[index] == version, self.states[index] == .unavailable else {
            self.pump()
            return
        }
        switch result {
        case let .image(image):
            if self.writeAndMark(image, index: index, id: id, version: version) {
                self.onNetworkFill?(id)
            }
        case .unavailable:
            if self.store.version(for: id) == version {
                self.registry.remove(ids: [id])
                self.setState(.filled, at: index)
            } else {
                self.networkTried.insert(id)
                self.setState(.unavailable, at: index)
            }
        case .cancelled:
            self.networkEligible.insert(index)
        }
        self.pump()
        self.onProgress?()
    }
}

final class ThumbnailFormatPolicy {
    enum Attempt {
        case fastFormat
        case highQuality
    }

    static let fallbackLimit = 32

    var onLog: ((String) -> Void)?
    private(set) var usesFastFormat = true
    private(set) var fastFormatSuccesses = 0
    private(set) var fastFormatFailures = 0

    func run(attempt: @escaping (Attempt, @escaping (CGImage?, Bool) -> Void) -> Void, completion: @escaping (ThumbnailImageResult) -> Void) {
        let highQuality = {
            attempt(.highQuality, { image, _ in
                if let image {
                    completion(.image(image))
                } else {
                    completion(.unavailable)
                }
            })
        }
        guard self.usesFastFormat else {
            highQuality()
            return
        }
        attempt(.fastFormat, { [weak self] image, _ in
            if let image {
                self?.fastFormatSuccesses += 1
                completion(.image(image))
                return
            }
            if let self {
                self.fastFormatFailures += 1
                if self.usesFastFormat && self.fastFormatSuccesses == 0 && self.fastFormatFailures >= ThumbnailFormatPolicy.fallbackLimit {
                    self.usesFastFormat = false
                    self.onLog?("THUMBS fastFormat unavailable after \(self.fastFormatFailures) failures, using highQualityFormat")
                }
            }
            highQuality()
        })
    }
}

struct ThumbnailLaunchSnapshot: Codable, Equatable {
    struct Segment: Codable, Equatable {
        var start: Int
        var ids: [String]
    }

    var count: Int
    var segments: [Segment]

    func id(at index: Int) -> String? {
        for segment in self.segments where index >= segment.start && index < segment.start + segment.ids.count {
            return segment.ids[index - segment.start]
        }
        return nil
    }

    var indices: IndexSet {
        var result = IndexSet()
        for segment in self.segments {
            result.insert(integersIn: segment.start ..< segment.start + segment.ids.count)
        }
        return result
    }

    func encode() -> Data {
        return (try? PropertyListEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data) -> ThumbnailLaunchSnapshot? {
        return try? PropertyListDecoder().decode(ThumbnailLaunchSnapshot.self, from: data)
    }

    static func make(catalog: ThumbnailCatalog, head: Int, ranges: [Range<Int>]) -> ThumbnailLaunchSnapshot {
        var covered = IndexSet(integersIn: 0 ..< min(head, catalog.count))
        for range in ranges {
            let clamped = range.clamped(to: 0 ..< catalog.count)
            if !clamped.isEmpty {
                covered.insert(integersIn: clamped)
            }
        }
        let segments = covered.rangeView.map { Segment(start: $0.lowerBound, ids: Array(catalog.ids[$0])) }
        return ThumbnailLaunchSnapshot(count: catalog.count, segments: segments)
    }
}

enum ThumbnailDownscaler {
    static let maxPixelSize: CGFloat = 96.0

    static func image(from image: UIImage) -> CGImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let longest = max(width, height)
        if image.imageOrientation == .up && longest <= ThumbnailDownscaler.maxPixelSize {
            return cgImage
        }
        let pixelSize = CGSize(width: round(image.size.width * image.scale), height: round(image.size.height * image.scale))
        guard pixelSize.width > 0.0, pixelSize.height > 0.0 else {
            return nil
        }
        let scale = min(1.0, ThumbnailDownscaler.maxPixelSize / max(pixelSize.width, pixelSize.height))
        let size = CGSize(width: max(1.0, round(pixelSize.width * scale)), height: max(1.0, round(pixelSize.height * scale)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}

final class PhotoKitThumbnailSource: ThumbnailImageSource {
    static let targetSize = CGSize(width: 96.0, height: 96.0)

    final class Request: ThumbnailRequest {
        private let lock = NSLock()
        private var cancelled = false
        private var token: PHImageRequestID?
        private let manager: PHImageManager

        init(manager: PHImageManager) {
            self.manager = manager
        }

        var isCancelled: Bool {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.cancelled
        }

        func setToken(_ token: PHImageRequestID) {
            self.lock.lock()
            self.token = token
            let cancelled = self.cancelled
            self.lock.unlock()
            if cancelled {
                self.manager.cancelImageRequest(token)
            }
        }

        func cancel() {
            self.lock.lock()
            self.cancelled = true
            let token = self.token
            self.lock.unlock()
            if let token {
                self.manager.cancelImageRequest(token)
            }
        }
    }

    var fetchResult: PHFetchResult<PHAsset>
    var reversed: Bool
    var onNetworkDelivery: ((Int, Int) -> Void)?
    private let manager = PHImageManager.default()
    private let queue = DispatchQueue(label: "org.telegram.MediaGridPhotoLibrary.thumbnailRequests", qos: .utility)
    let policy = ThumbnailFormatPolicy()

    init(fetchResult: PHFetchResult<PHAsset>, reversed: Bool) {
        self.fetchResult = fetchResult
        self.reversed = reversed
    }

    func requestThumbnail(index: Int, id: String, network: Bool, completion: @escaping (ThumbnailImageResult) -> Void) -> ThumbnailRequest? {
        let fetchResult = self.fetchResult
        let reversed = self.reversed
        let request = Request(manager: self.manager)
        let finish: (ThumbnailImageResult) -> Void = { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
        self.queue.async {
            if request.isCancelled {
                finish(.cancelled)
                return
            }
            let count = fetchResult.count
            var asset: PHAsset?
            if index >= 0, index < count {
                let candidate = fetchResult.object(at: MediaGridPhotoLibraryDataSource.fetchIndex(index, count: count, reversed: reversed))
                if candidate.localIdentifier == id {
                    asset = candidate
                }
            }
            if asset == nil {
                asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
            }
            guard let asset else {
                finish(.unavailable)
                return
            }
            if network {
                self.perform(asset, attempt: .highQuality, network: true, request: request, done: { image, _ in
                    if request.isCancelled {
                        finish(.cancelled)
                    } else if let image {
                        finish(.image(image))
                    } else {
                        finish(.unavailable)
                    }
                })
            } else {
                self.policy.run(attempt: { attempt, done in
                    self.perform(asset, attempt: attempt, network: false, request: request, done: done)
                }, completion: finish)
            }
        }
        return request
    }

    private func perform(_ asset: PHAsset, attempt: ThumbnailFormatPolicy.Attempt, network: Bool, request: Request, done: @escaping (CGImage?, Bool) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = attempt == .fastFormat ? .fastFormat : .highQualityFormat
        options.resizeMode = network ? .fast : .exact
        options.isNetworkAccessAllowed = network
        options.isSynchronous = false
        let token = self.manager.requestImage(for: asset, targetSize: PhotoKitThumbnailSource.targetSize, contentMode: .aspectFit, options: options, resultHandler: { image, info in
            let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
            self.queue.async {
                if network, let cgImage = image?.cgImage {
                    self.onNetworkDelivery?(cgImage.width, cgImage.height)
                }
                done(image.flatMap(ThumbnailDownscaler.image(from:)), isInCloud)
            }
        })
        request.setToken(token)
    }
}
