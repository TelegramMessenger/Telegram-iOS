import Foundation
import XCTest
@testable import HLSPlayback

// A manual clock, a disk per level and a network of fixed bandwidth and latency, for the controller tests.
//
// Loads fetch only the bytes missing when they start (as MediaBox does), deliver them after
// `latency + missingBytes * 8 / bandwidth` (in `progressChunk` steps when that is set, else all at completion, as
// MultipartFetch lands whole parts), and mark them on disk as they land. Appends succeed synchronously with the
// nominal times, minus `probedEndShortfall` at the end.
final class SimulatedEnvironment: HLSPlaybackEnvironment {
    final class Token: HLSCancellable {
        var onCancel: (() -> Void)?
        
        func cancel() {
            let onCancel = self.onCancel
            self.onCancel = nil
            onCancel?()
        }
    }
    
    struct LoadRecord: Equatable {
        var level: Int
        var range: Range<Int64>
        var priority: HLSLoadPriority
        var startTime: Double
        var completionTime: Double = 0.0
        // When the load completed, failed or was cancelled.
        var endTime: Double?
        var networkBytes: Int64 = 0
        var cancelled: Bool = false
        var completed: Bool = false
        var failed: Bool = false
    }
    
    private struct Scheduled {
        let id: Int
        let time: Double
        let action: () -> Void
    }
    
    private(set) var now: Double = 0.0
    private var scheduled: [Scheduled] = []
    private var nextScheduledId = 0
    
    var bandwidth: Double = 10_000_000.0
    var latency: Double = 0.05
    // When set, network loads are delivered by this link, in parts, instead of by `bandwidth` and `latency`.
    var link: SimulatedLink?
    var progressChunk: Int64?
    // The next this many loads (matching `failingLoadFilter`, when set) fail after `latency`.
    var failingLoads: Int = 0
    var failingLoadFilter: ((_ level: Int, _ range: Range<Int64>) -> Bool)?
    // The next this many loads, and the loads at these indices of `loads`, never deliver anything, and never complete.
    var stalledLoads: Int = 0
    var stalledLoadIndices: Set<Int> = []
    // Per-level bandwidth, in place of `bandwidth`.
    var bandwidthForLevel: [Int: Double] = [:]
    // The next this many appends fail.
    var failingAppends: Int = 0
    var probedEndShortfall: Double = 0.0
    // Loads on these levels join a fetch already under way, so their timing is not a sample.
    var externallyFetchedLevels: Set<Int> = []
    // A load of a range that is already on disk completes inside `load()`, as MediaBox's status signal can.
    var completesPresentRangesSynchronously = false
    // What `missingBytes` reports instead of the truth, for a disk view that lags behind loads.
    var missingBytesOverride: ((_ level: Int, _ range: Range<Int64>) -> Int64?)?
    // Appends complete after this delay instead of inside `append()`, as the FFmpeg probe does.
    var appendDelay: Double?
    
    private(set) var onDisk: [Int: [Range<Int64>]] = [:]
    private(set) var loads: [LoadRecord] = []
    private(set) var appends: [(level: Int, request: HLSAppendRequest)] = []
    private(set) var removedKeys: [HLSSegmentKey] = []
    
    private var deliveredOverNetwork: [Int: [Range<Int64>]] = [:]
    private(set) var networkRedeliveries: [String] = []
    private(set) var diskSampleViolations: [String] = []
    private(set) var appendViolations: [String] = []
    private(set) var loadViolations: [String] = []
    private var loadDepth = 0
    
    weak var controller: HLSPlaybackController?
    // Told of every load as it is issued.
    var onLoad: ((_ level: Int, _ range: Range<Int64>) -> Void)?
    
    // MARK: Disk
    
    // A cache clear, for the part of it that covers `range`.
    func removeFromDisk(level: Int, range: Range<Int64>) {
        var remaining: [Range<Int64>] = []
        for present in self.onDisk[level] ?? [] {
            if present.upperBound <= range.lowerBound || present.lowerBound >= range.upperBound {
                remaining.append(present)
                continue
            }
            if present.lowerBound < range.lowerBound {
                remaining.append(present.lowerBound ..< range.lowerBound)
            }
            if present.upperBound > range.upperBound {
                remaining.append(range.upperBound ..< present.upperBound)
            }
        }
        self.onDisk[level] = remaining
        // Fetching those bytes again is not a redelivery.
        self.deliveredOverNetwork[level] = (self.deliveredOverNetwork[level] ?? []).flatMap { delivered -> [Range<Int64>] in
            if delivered.upperBound <= range.lowerBound || delivered.lowerBound >= range.upperBound {
                return [delivered]
            }
            var kept: [Range<Int64>] = []
            if delivered.lowerBound < range.lowerBound {
                kept.append(delivered.lowerBound ..< range.lowerBound)
            }
            if delivered.upperBound > range.upperBound {
                kept.append(range.upperBound ..< delivered.upperBound)
            }
            return kept
        }
    }
    
    func markOnDisk(level: Int, range: Range<Int64>) {
        var ranges = self.onDisk[level] ?? []
        ranges.append(range)
        ranges.sort(by: { $0.lowerBound < $1.lowerBound })
        var merged: [Range<Int64>] = []
        for range in ranges where !range.isEmpty {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound ..< max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        self.onDisk[level] = merged
    }
    
    func missingRanges(level: Int, range: Range<Int64>) -> [Range<Int64>] {
        var result: [Range<Int64>] = []
        var cursor = range.lowerBound
        for present in self.onDisk[level] ?? [] {
            if present.upperBound <= cursor {
                continue
            }
            if present.lowerBound >= range.upperBound {
                break
            }
            if present.lowerBound > cursor {
                result.append(cursor ..< present.lowerBound)
            }
            cursor = max(cursor, present.upperBound)
            if cursor >= range.upperBound {
                break
            }
        }
        if cursor < range.upperBound {
            result.append(cursor ..< range.upperBound)
        }
        return result
    }
    
    func isOnDisk(level: Int, range: Range<Int64>) -> Bool {
        return self.missingRanges(level: level, range: range).isEmpty
    }
    
    func missingBytes(level: Int, range: Range<Int64>) -> Int64 {
        if let override = self.missingBytesOverride?(level, range) {
            return override
        }
        return self.missingRanges(level: level, range: range).reduce(Int64(0), { $0 + Int64($1.count) })
    }
    
    // MARK: Clock
    
    func schedule(after delay: Double, _ action: @escaping () -> Void) -> HLSCancellable {
        let id = self.nextScheduledId
        self.nextScheduledId += 1
        self.scheduled.append(Scheduled(id: id, time: self.now + max(0.0, delay), action: action))
        let token = Token()
        token.onCancel = { [weak self] in
            self?.scheduled.removeAll(where: { $0.id == id })
        }
        return token
    }
    
    // Runs every action due within `seconds`, in time order, including actions they schedule.
    func advance(by seconds: Double) {
        let target = self.now + seconds
        while let next = self.scheduled.filter({ $0.time <= target }).min(by: { ($0.time, $0.id) < ($1.time, $1.id) }) {
            self.scheduled.removeAll(where: { $0.id == next.id })
            self.now = max(self.now, next.time)
            next.action()
        }
        self.now = target
    }
    
    // MARK: Network
    
    private static func slice(_ ranges: [Range<Int64>], from: Int64, to: Int64) -> [Range<Int64>] {
        var result: [Range<Int64>] = []
        var offset: Int64 = 0
        for range in ranges {
            let length = Int64(range.count)
            let lower = max(from, offset)
            let upper = min(to, offset + length)
            if lower < upper {
                result.append((range.lowerBound + lower - offset) ..< (range.lowerBound + upper - offset))
            }
            offset += length
        }
        return result
    }
    
    private func deliver(level: Int, ranges: [Range<Int64>]) {
        for range in ranges {
            for previous in self.deliveredOverNetwork[level] ?? [] where previous.overlaps(range) {
                self.networkRedeliveries.append("level \(level): \(range) again (first \(previous))")
            }
            self.deliveredOverNetwork[level, default: []].append(range)
            self.markOnDisk(level: level, range: range)
        }
    }
    
    func load(level: Int, range: Range<Int64>, priority: HLSLoadPriority, progress: @escaping (Int64) -> Void, completion: @escaping (HLSLoadOutcome) -> Void) -> HLSCancellable {
        let index = self.loads.count
        self.onLoad?(level, range)
        self.loads.append(LoadRecord(level: level, range: range, priority: priority, startTime: self.now))
        
        if self.loadDepth > 20 {
            self.loadViolations.append("load() re-entered more than 20 times")
            return Token()
        }
        let isSampleable = !self.externallyFetchedLevels.contains(level)
        if self.isOnDisk(level: level, range: range) && self.missingBytesOverride == nil {
            self.loadViolations.append("load of level \(level) \(range), already on disk")
        }
        if self.completesPresentRangesSynchronously && self.isOnDisk(level: level, range: range) {
            self.loads[index].completed = true
            self.loadDepth += 1
            completion(.completed(networkBytes: 0, isSampleable: isSampleable))
            self.loadDepth -= 1
            return Token()
        }
        
        var pending: [HLSCancellable] = []
        var usesLink = false
        if self.stalledLoads > 0 || self.stalledLoadIndices.contains(index) {
            if self.stalledLoads > 0 {
                self.stalledLoads -= 1
            }
        } else if self.failingLoads > 0 && (self.failingLoadFilter?(level, range) ?? true) {
            self.failingLoads -= 1
            pending.append(self.schedule(after: self.latency, { [weak self] in
                guard let self else {
                    return
                }
                self.loads[index].failed = true
                self.loads[index].endTime = self.now
                completion(.failed)
            }))
        } else if let link = self.link, !self.missingRanges(level: level, range: range).isEmpty {
            // Delivered by the shared link, part by part.
            usesLink = true
            let missing = self.missingRanges(level: level, range: range)
            let missingBytes = missing.reduce(Int64(0), { $0 + Int64($1.count) })
            var deliveredBytes: Int64 = 0
            link.enqueue(loadId: index, level: level, bytes: missingBytes, environment: self, landed: { [weak self] size in
                guard let self else {
                    return
                }
                let from = deliveredBytes
                deliveredBytes += size
                self.deliver(level: level, ranges: SimulatedEnvironment.slice(missing, from: from, to: deliveredBytes))
                self.loads[index].networkBytes = deliveredBytes
                if deliveredBytes >= missingBytes {
                    self.loads[index].completed = true
                    self.loads[index].completionTime = self.now
                    self.loads[index].endTime = self.now
                    completion(.completed(networkBytes: missingBytes, isSampleable: isSampleable))
                } else {
                    progress(deliveredBytes)
                }
            })
        } else {
            let missing = self.missingRanges(level: level, range: range)
            let missingBytes = missing.reduce(Int64(0), { $0 + Int64($1.count) })
            var steps: [Int64] = []
            if let chunk = self.progressChunk, chunk > 0 {
                var step = chunk
                while step < missingBytes {
                    steps.append(step)
                    step += chunk
                }
            }
            steps.append(missingBytes)
            var deliveredBytes: Int64 = 0
            for step in steps {
                let bandwidth = self.bandwidthForLevel[level] ?? self.bandwidth
                let delay = missingBytes == 0 ? 0.0 : self.latency + Double(step) * 8.0 / bandwidth
                let isLast = step == missingBytes
                pending.append(self.schedule(after: delay, { [weak self] in
                    guard let self else {
                        return
                    }
                    self.deliver(level: level, ranges: SimulatedEnvironment.slice(missing, from: deliveredBytes, to: step))
                    deliveredBytes = step
                    self.loads[index].networkBytes = step
                    if isLast {
                        self.loads[index].completed = true
                        self.loads[index].completionTime = self.now
                    self.loads[index].endTime = self.now
                        let estimateBefore = self.controller?.estimate
                        completion(.completed(networkBytes: missingBytes, isSampleable: isSampleable))
                        if missingBytes == 0 && self.controller?.estimate != estimateBefore {
                            self.diskSampleViolations.append("load \(index) (level \(level), \(range)) sampled with no network bytes")
                        }
                    } else {
                        progress(step)
                    }
                }))
            }
        }
        
        let token = Token()
        token.onCancel = { [weak self] in
            for item in pending {
                item.cancel()
            }
            if let self, !self.loads[index].completed, !self.loads[index].failed {
                self.loads[index].cancelled = true
                self.loads[index].endTime = self.now
                if usesLink {
                    self.link?.cancel(loadId: index, environment: self)
                }
            }
        }
        return token
    }
    
    // MARK: Player
    
    func append(level: Int, request: HLSAppendRequest, completion: @escaping (HLSAppendOutcome) -> Void) {
        self.appends.append((level, request))
        if !self.isOnDisk(level: level, range: request.dataRange) || !(request.initRange.flatMap({ self.isOnDisk(level: level, range: $0) }) ?? true) {
            self.appendViolations.append("append of \(request.key) before its bytes are on disk")
            completion(.failed)
            return
        }
        let shouldFail = self.failingAppends > 0
        if shouldFail {
            self.failingAppends -= 1
        }
        let finish: () -> Void = { [weak self] in
            guard let self else {
                return
            }
            if shouldFail {
                completion(.failed)
                return
            }
            let estimateBefore = self.controller?.estimate
            completion(.appended(start: request.nominalStart, end: request.nominalEnd - self.probedEndShortfall))
            if self.controller?.estimate != estimateBefore {
                self.diskSampleViolations.append("append of \(request.key) changed the estimate")
            }
        }
        if let appendDelay = self.appendDelay {
            let _ = self.schedule(after: appendDelay, finish)
        } else {
            finish()
        }
    }
    
    func remove(keys: [HLSSegmentKey]) {
        self.removedKeys.append(contentsOf: keys)
    }
    
    // MARK: Invariants
    
    var networkLoads: [LoadRecord] {
        return self.loads.filter({ !$0.cancelled && !$0.failed })
    }
    
    func assertNoRangeLoadedTwiceFromNetwork(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(self.networkRedeliveries, [], file: file, line: line)
    }
    
    func assertNoSampleFromDisk(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(self.diskSampleViolations, [], file: file, line: line)
        XCTAssertEqual(self.appendViolations, [], file: file, line: line)
    }
    
    func assertInvariants(file: StaticString = #filePath, line: UInt = #line) {
        self.assertNoRangeLoadedTwiceFromNetwork(file: file, line: line)
        self.assertNoSampleFromDisk(file: file, line: line)
        XCTAssertEqual(self.loadViolations, [], file: file, line: line)
    }
}

// Levels and playlists shaped like the server's.
enum TestStreams {
    static let fourLevels: [HLSLevel] = [
        HLSLevel(key: 360, width: 640, height: 360, bandwidth: 290_000),
        HLSLevel(key: 480, width: 854, height: 480, bandwidth: 600_000),
        HLSLevel(key: 720, width: 1280, height: 720, bandwidth: 1_200_000),
        HLSLevel(key: 1080, width: 1920, height: 1080, bandwidth: 1_650_000),
    ]
    
    static func playlist(level: HLSLevel, durations: [Double], initLength: Int64 = 1000, gap: Int64 = 100) -> HLSMediaPlaylist {
        var offset = initLength + gap
        var start = 0.0
        var segments: [HLSMediaPlaylist.Segment] = []
        for (index, duration) in durations.enumerated() {
            let size = Int64(Double(level.bandwidth) * duration / 8.0)
            segments.append(HLSMediaPlaylist.Segment(index: index, start: start, duration: duration, byteRange: offset ..< (offset + size)))
            offset += size
            start += duration
        }
        return HLSMediaPlaylist(targetDuration: Int((durations.max() ?? 1.0).rounded(.up)), mediaSequence: 0, initSegment: 0 ..< initLength, resourceURI: "mtproto:\(level.key)", segments: segments, totalDuration: start)
    }
    
    static func uniform(level: HLSLevel, seconds: Double, segmentDuration: Double = 5.0) -> HLSMediaPlaylist {
        let count = Int((seconds / segmentDuration).rounded(.up))
        var durations = Array(repeating: segmentDuration, count: count)
        durations[count - 1] = seconds - segmentDuration * Double(count - 1)
        return self.playlist(level: level, durations: durations)
    }
}

// A controller over a simulated environment, with every level's playlist set unless told otherwise.
final class ControllerHarness {
    let levels: [HLSLevel]
    let environment = SimulatedEnvironment()
    let store: HLSBandwidthStore
    let networkClass: HLSNetworkClass
    let controller: HLSPlaybackController
    var playlists: [HLSMediaPlaylist]
    private(set) var bufferUpdates: [[HLSBufferedPart]] = []
    private(set) var logLines: [String] = []
    private(set) var position: Double = 0.0
    
    // `priorEstimate`: what a previous player measured on this network class, as one 4 s sample at that rate, 20 s
    // before this one starts.
    // The controller tests that pin load order, ranges and timings run one segment load at a time, the order they
    // were written for; the pipeline tests and the lab run the production configuration (two in flight, D13).
    static var oneLoadAtATime: HLSPlaybackController.Configuration {
        var configuration = HLSPlaybackController.Configuration()
        configuration.maxSegmentLoadsInFlight = 1
        return configuration
    }

    init(levels: [HLSLevel] = TestStreams.fourLevels, seconds: Double = 120.0, preloadLevel: Int = 2, playlists: [HLSMediaPlaylist]? = nil, configuration: HLSPlaybackController.Configuration = ControllerHarness.oneLoadAtATime, store: HLSBandwidthStore = HLSBandwidthStore(), priorEstimate: Double? = nil, networkClass: HLSNetworkClass = .unknown) {
        self.levels = levels
        self.playlists = playlists ?? levels.map { TestStreams.uniform(level: $0, seconds: seconds) }
        self.store = store
        self.networkClass = networkClass
        if let priorEstimate {
            let _ = store.sample(durationMs: 4000.0, bytes: Int64(priorEstimate * 4.0 / 8.0), networkClass: networkClass, defaultEstimate: priorEstimate, now: -20.0)
        }
        self.controller = HLSPlaybackController(levels: levels, preloadLevel: preloadLevel, configuration: configuration, environment: self.environment, bandwidthStore: store)
        self.controller.setNetworkClass(networkClass)
        self.environment.controller = self.controller
        self.controller.onBufferChanged = { [weak self] parts, _ in
            self?.bufferUpdates.append(parts)
        }
        self.environment.onLoad = { [weak self] level, range in
            self?.checkLoadIsNotBuffered(level: level, range: range)
        }
        self.controller.onLog = { [weak self] line in
            self?.logLines.append(line)
        }
    }
    
    func setPlaylists(except missing: Set<Int> = []) {
        for (level, playlist) in self.playlists.enumerated() where !missing.contains(level) {
            self.controller.setPlaylist(playlist, level: level)
        }
    }
    
    // The bytes a level needs on disk to play [0, seconds).
    func cache(level: Int, seconds: Double) {
        let playlist = self.playlists[level]
        guard let range = playlist.prefixRange(seconds: seconds) else {
            return
        }
        self.environment.markOnDisk(level: level, range: range)
    }
    
    func cacheAll(level: Int) {
        self.cache(level: level, seconds: .infinity)
    }
    
    // A user seek: the playhead moves there, then the controller hears of it.
    func seek(to position: Double) {
        self.position = position
        self.controller.seek(to: position)
        self.controller.updatePlayback(position: position, isPlaying: true, rate: 1.0)
    }
    
    // Plays from the current position to `target` in steps, letting loads land in between.
    func play(to target: Double, step: Double = 0.5) {
        while self.position < target - 1e-9 {
            let delta = min(step, target - self.position)
            self.environment.advance(by: delta)
            self.position += delta
            self.controller.updatePlayback(position: self.position, isPlaying: true, rate: 1.0)
        }
    }
    
    // Every bandwidth sample the controller logged, as (bytes, milliseconds).
    var loggedSamples: [(bytes: Int64, durationMs: Double)] {
        return self.logLines.compactMap { line -> (bytes: Int64, durationMs: Double)? in
            guard line.hasPrefix("sample ") else {
                return nil
            }
            var bytes: Int64?
            var durationMs: Double?
            for field in line.split(separator: " ") {
                if field.hasPrefix("bytes=") {
                    bytes = Int64(field.dropFirst("bytes=".count))
                } else if field.hasPrefix("ms=") {
                    durationMs = Double(field.dropFirst("ms=".count))
                }
            }
            guard let bytes, let durationMs else {
                return nil
            }
            return (bytes, durationMs)
        }
    }
    
    // Each sample is one completed, sampleable network load's network bytes (D1), over busy time of the link (D2): the
    // samples together are never charged more time than the network loads spanned, and a load that overlapped no other
    // is charged exactly its own duration.
    func assertSamplesMatchNetworkLoads(file: StaticString = #filePath, line: UInt = #line) {
        let networkLoads = self.environment.loads.filter { $0.endTime != nil && ($0.networkBytes > 0 || $0.cancelled || $0.failed) }
        var candidates = self.environment.loads.filter { $0.completed && $0.networkBytes > 0 && !self.environment.externallyFetchedLevels.contains($0.level) && $0.range != self.playlists[$0.level].initSegment }
        var sampledMs = 0.0
        for sample in self.loggedSamples {
            sampledMs += sample.durationMs
            let index = candidates.firstIndex(where: { $0.networkBytes == sample.bytes && abs(($0.completionTime - $0.startTime) * 1000.0 - sample.durationMs) < 0.01 }) ?? candidates.firstIndex(where: { $0.networkBytes == sample.bytes })
            guard let index else {
                XCTFail("sample of \(sample.bytes) bytes in \(sample.durationMs) ms matches no network load", file: file, line: line)
                continue
            }
            let load = candidates.remove(at: index)
            let overlapsAnother = networkLoads.contains(where: { other in
                return !(other.startTime == load.startTime && other.range == load.range && other.level == load.level) && (other.startTime < load.completionTime && (other.endTime ?? 0.0) > load.startTime)
            })
            if !overlapsAnother {
                XCTAssertEqual(sample.durationMs, (load.completionTime - load.startTime) * 1000.0, accuracy: 0.01, "a load alone on the link is charged its own duration", file: file, line: line)
            }
        }
        // The union of the network loads' intervals.
        var unionMs = 0.0
        var current: (start: Double, end: Double)?
        for interval in networkLoads.map({ ($0.startTime, $0.endTime ?? $0.startTime) }).sorted(by: { $0.0 < $1.0 }) {
            if let value = current, interval.0 <= value.end {
                current = (value.start, max(value.end, interval.1))
            } else {
                if let value = current {
                    unionMs += (value.end - value.start) * 1000.0
                }
                current = interval
            }
        }
        if let value = current {
            unionMs += (value.end - value.start) * 1000.0
        }
        XCTAssertLessThanOrEqual(sampledMs, unionMs + 0.01 * Double(self.loggedSamples.count), "samples charged more time than the network loads spanned", file: file, line: line)
        XCTAssertEqual(candidates.count, 0, "network segment loads that were never sampled: \(candidates)", file: file, line: line)
    }
    
    // A segment whose time span is already buffered, at any level, is never loaded again.
    private(set) var bufferedRefetches: [String] = []
    
    private func checkLoadIsNotBuffered(level: Int, range: Range<Int64>) {
        guard level >= 0 && level < self.playlists.count, range != self.playlists[level].initSegment, let segment = self.playlists[level].segments.first(where: { $0.byteRange.upperBound == range.upperBound }) else {
            return
        }
        var model = HLSBufferModel()
        for part in self.buffered {
            model.insert(part)
        }
        if model.bufferedRanges.contains(where: { $0.lowerBound <= segment.start + 0.01 && $0.upperBound >= segment.end - 0.01 }) {
            self.bufferedRefetches.append("level \(level) index \(segment.index) [\(segment.start), \(segment.end)) loaded while buffered")
        }
    }
    
    func assertInvariants(file: StaticString = #filePath, line: UInt = #line) {
        self.environment.assertInvariants(file: file, line: line)
        self.assertSamplesMatchNetworkLoads(file: file, line: line)
        XCTAssertEqual(self.bufferedRefetches, [], file: file, line: line)
    }
    
    var appendedKeys: [HLSSegmentKey] {
        return self.environment.appends.map(\.request.key)
    }
    
    // Loads of segment data, leaving out the separate loads of a level's init.
    var segmentLoads: [SimulatedEnvironment.LoadRecord] {
        return self.environment.loads.filter { $0.range != self.playlists[$0.level].initSegment }
    }
    
    var buffered: [HLSBufferedPart] {
        return self.bufferUpdates.last ?? []
    }
}
