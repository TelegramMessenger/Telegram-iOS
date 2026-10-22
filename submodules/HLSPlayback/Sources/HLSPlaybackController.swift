// Ported from hls.js v1.7.3 (src/controller/stream-controller.ts, src/controller/base-stream-controller.ts, src/controller/fragment-tracker.ts, src/controller/error-controller.ts), Copyright (c) Dailymotion and hls.js contributors, Apache License 2.0.

import Foundation

public enum HLSLoadSource: Equatable {
    case disk
    case network
}

// Decides which segment of which quality the player gets next, and from where: disk first, network otherwise.
//
// Event-driven (D9): every state change runs the scheduler directly; timers exist only for retries, level cool-downs,
// the abandon check and the start's playlist wait. A load waits for the server for as long as it takes: it is never
// issued again for receiving nothing. At most one media segment is in flight. Not thread-safe: every call and every
// environment callback happens on one thread.
public final class HLSPlaybackController {
    public struct Configuration: Equatable {
        public var maxBufferAhead: Double = 60.0
        public var backBuffer: Double = 30.0
        // Then the last value forever.
        public var retryDelays: [Double] = [1.0, 2.0, 4.0, 8.0]
        public var levelErrorLimit: Int = 6
        // How long (while connected) an errored level is avoided, doubled each time it errors again, at most the
        // maximum. A network failure is never terminal: the level is then tried again.
        public var levelErrorCooldown: Double = 30.0
        public var maximumLevelErrorCooldown: Double = 300.0
        // Once another level's playlist is in, how long (while connected) the start waits for the preload level's.
        public var preloadPlaylistWait: Double = 5.0
        public var abandonPollInterval: Double = 0.1
        
        public init() {
        }
    }
    
    private final class SegmentLoad {
        let request: HLSAppendRequest
        // The bytes fetched: the segment's, or from byte 0 through the first segment when that also brings the init
        // (D5).
        let loadRange: Range<Int64>
        let level: Int
        let duration: Double
        let startTime: Double
        // Where the segment's data comes from: `.disk` when only its level's init is loading.
        let source: HLSLoadSource
        // The bytes the network owed when the load started (D1).
        let expectedNetworkBytes: Int64
        var dataLoad: HLSCancellable?
        var isDataDone = false
        var networkBytes: Int64 = 0
        
        init(request: HLSAppendRequest, loadRange: Range<Int64>, level: Int, duration: Double, startTime: Double, source: HLSLoadSource, expectedNetworkBytes: Int64) {
            self.request = request
            self.loadRange = loadRange
            self.level = level
            self.duration = duration
            self.startTime = startTime
            self.source = source
            self.expectedNetworkBytes = expectedNetworkBytes
        }
    }
    
    // A level's init, loaded once and shared by every segment of that level that waits for it (D8).
    private final class InitLoad {
        var cancellable: HLSCancellable?
        var isDone = false
    }
    
    // A one-shot timer whose clock runs only while the account's network is available (D10).
    private final class ConnectedTimer {
        private let environment: HLSPlaybackEnvironment
        private let action: () -> Void
        private var remaining: Double
        private var deadline: Double?
        private var token: HLSCancellable?
        
        init(environment: HLSPlaybackEnvironment, delay: Double, isRunning: Bool, action: @escaping () -> Void) {
            self.environment = environment
            self.action = action
            self.remaining = max(0.0, delay)
            if isRunning {
                self.resume()
            }
        }
        
        deinit {
            self.token?.cancel()
        }
        
        func resume() {
            if self.deadline != nil {
                return
            }
            self.deadline = self.environment.now + self.remaining
            self.token = self.environment.schedule(after: self.remaining, { [weak self] in
                guard let self else {
                    return
                }
                self.token = nil
                self.deadline = nil
                self.remaining = 0.0
                self.action()
            })
        }
        
        func pause() {
            guard let deadline = self.deadline else {
                return
            }
            self.remaining = max(0.0, deadline - self.environment.now)
            self.deadline = nil
            self.token?.cancel()
            self.token = nil
        }
        
        func cancel() {
            self.token?.cancel()
            self.token = nil
            self.deadline = nil
        }
    }
    
    private enum Pipeline {
        case idle
        case loading(SegmentLoad)
        case appending(HLSSegmentKey)
    }
    
    private let levels: [HLSLevel]
    private let preloadLevel: Int
    private let configuration: Configuration
    private let environment: HLSPlaybackEnvironment
    private let seed: HLSBandwidthSeed
    private let initialSeed: Double?
    
    private var playlists: [HLSMediaPlaylist?]
    // Levels whose playlist is not on disk: the start does not wait for them.
    private var unavailablePlaylists = Set<Int>()
    // Levels whose playlist the loader rejected: errored for good, and the start does not wait for them either.
    private var rejectedPlaylists = Set<Int>()
    // Levels whose init a load completed: trusted over the disk view, which may lag (D8).
    private var loadedInits = Set<Int>()
    private var buffer = HLSBufferModel()
    private var estimator: HLSBandwidthEstimator
    // A network sample, or an abandon's reset, decided the estimate: it, not the seed, feeds the next pick.
    private var hasNetworkSample = false
    private var levelErrors: [Int]
    private var cap: Int?
    private var manualLevel: Int?
    
    private var position: Double = 0.0
    private var isPlaying = false
    private var rate: Double = 1.0
    private var isNetworkAvailable = true
    
    private var isStartRequested = false
    private var isStarted = false
    private var preloadPlaylistTimer: ConnectedTimer?
    private var isPreloadPlaylistWaitOver = false
    private var isStopped = false
    private var lastLoadedLevel: Int?
    private var lastSegmentDuration: Double?
    private var pipeline: Pipeline = .idle
    private var initLoads: [Int: InitLoad] = [:]
    private var partAtPosition: HLSSegmentKey?
    private var lastLoggedLevelChoice: Int?
    
    // Failures (D10): consecutive ones per segment set its retry delay; consecutive ones per level error the level
    // for a cool-down.
    private var segmentFailures: [HLSSegmentKey: Int] = [:]
    private var levelFailures: [Int]
    // How many times each level errored since it last loaded, and the cool-down of each errored level.
    private var levelErrorTrips: [Int]
    private var levelCooldownTimers: [Int: ConnectedTimer] = [:]
    private var retryTimer: ConnectedTimer?
    private var abandonTimer: HLSCancellable?
    // After an abandon, the level the next segment loads at (hls.js's forced next auto level, D6).
    private var forcedLevel: Int?
    // A manual switch landed while a part was being made: flush forward once it lands.
    private var flushAfterAppend = false
    
    private var isScheduling = false
    private var needsSchedule = false
    
    public var onBufferChanged: ((_ parts: [HLSBufferedPart], _ duration: Double?) -> Void)?
    public var onLog: ((String) -> Void)?
    
    public private(set) var startLevel: Int?
    public private(set) var firstSegmentLevel: Int?
    public private(set) var firstSegmentSource: HLSLoadSource?
    
    // nil until this player has a network sample.
    public var estimate: Double? {
        return self.hasNetworkSample ? self.estimator.estimate : nil
    }
    
    public init(levels: [HLSLevel], preloadLevel: Int, configuration: Configuration = Configuration(), environment: HLSPlaybackEnvironment, seed: HLSBandwidthSeed = .shared) {
        self.levels = levels
        self.preloadLevel = max(0, min(preloadLevel, levels.count - 1))
        self.configuration = configuration
        self.environment = environment
        self.seed = seed
        self.initialSeed = seed.value
        self.playlists = Array(repeating: nil, count: levels.count)
        self.levelErrors = Array(repeating: 0, count: levels.count)
        self.levelFailures = Array(repeating: 0, count: levels.count)
        self.levelErrorTrips = Array(repeating: 0, count: levels.count)
        // D3: the seed is a default without weight; otherwise hls.js's manifest-derived default.
        let topBandwidth = Double(levels.last?.bandwidth ?? 0)
        self.estimator = HLSBandwidthEstimator(defaultEstimate: seed.value ?? max(500_000.0, min(topBandwidth, 5_000_000.0)))
    }
    
    deinit {
        self.stop()
    }
    
    // MARK: Inputs
    
    public func setPlaylist(_ playlist: HLSMediaPlaylist, level: Int) {
        if self.isStopped || level < 0 || level >= self.levels.count {
            return
        }
        self.playlists[level] = playlist
        self.unavailablePlaylists.remove(level)
        self.tryStart()
        self.scheduleNext()
    }
    
    // The level's playlist is not on disk and has to be fetched: the start does not wait for it.
    public func setPlaylistUnavailable(level: Int) {
        if self.isStopped || level < 0 || level >= self.levels.count || self.playlists[level] != nil {
            return
        }
        self.unavailablePlaylists.insert(level)
        self.tryStart()
        self.scheduleNext()
    }
    
    // The level's playlist will never arrive (it names another file, its ranges pass the file's end, it does not
    // parse): the level is errored, and the start does not wait for it, at the preload level either.
    public func setPlaylistRejected(level: Int) {
        if self.isStopped || level < 0 || level >= self.levels.count || self.playlists[level] != nil || self.rejectedPlaylists.contains(level) {
            return
        }
        self.unavailablePlaylists.insert(level)
        self.rejectedPlaylists.insert(level)
        self.levelErrors[level] = max(self.levelErrors[level], self.configuration.levelErrorLimit)
        self.log("playlist rejected level=\(self.levelKey(level))")
        self.tryStart()
        self.scheduleNext()
    }
    
    // nil: no cap. Neither flushes nor cancels: parts above a lowered cap play out (D11).
    public func setCap(_ level: Int?) {
        self.cap = level
        self.scheduleNext()
    }
    
    // nil, or a level out of range: Auto, which neither flushes nor cancels (D11). A manual level cancels the load in
    // flight or a pending retry, drops the buffer ahead of the playhead and loads again from there (hls.js's
    // immediateLevelSwitch).
    public func setManualLevel(_ level: Int?) {
        if self.isStopped {
            return
        }
        var manualLevel: Int?
        if let level, level >= 0, level < self.levels.count {
            manualLevel = level
        }
        // A rejected playlist never arrives: the nearest level with a playlist plays instead.
        if let requested = manualLevel, self.rejectedPlaylists.contains(requested), let playable = self.levelWithPlaylist(near: requested) {
            self.log("manual level=\(self.levelKey(requested)) plays level=\(self.levelKey(playable))")
            manualLevel = playable
        }
        if manualLevel == self.manualLevel {
            return
        }
        self.manualLevel = manualLevel
        self.forcedLevel = nil
        if let manualLevel {
            self.log("manual level=\(self.levelKey(manualLevel))")
            // hls.js's immediateLevelSwitch aborts a fragment waiting to retry too.
            self.retryTimer?.cancel()
            self.retryTimer = nil
            // When everything ahead is already at this level (back from Auto within one load), there is nothing to
            // replace.
            if !self.isEverythingAhead(atLevel: manualLevel) {
                if case let .loading(load) = self.pipeline {
                    self.cancelLoad(load)
                } else if case .appending = self.pipeline {
                    self.flushAfterAppend = true
                }
                self.flushForward()
            }
        } else {
            self.log("manual level=auto")
            // The load in flight started under a manual level, without the abandon check Auto loads get.
            if case let .loading(load) = self.pipeline, !load.isDataDone, self.abandonTimer == nil, load.level > 0, self.lastLoadedLevel != nil {
                self.scheduleAbandonCheck(load)
            }
        }
        self.scheduleNext()
    }
    
    // While unavailable, retry delays, level cool-downs and the start's playlist wait stand still.
    public func setNetworkAvailable(_ available: Bool) {
        if self.isStopped || available == self.isNetworkAvailable {
            return
        }
        self.isNetworkAvailable = available
        if available {
            self.retryTimer?.resume()
            self.preloadPlaylistTimer?.resume()
            for (_, timer) in self.levelCooldownTimers {
                timer.resume()
            }
        } else {
            self.retryTimer?.pause()
            self.preloadPlaylistTimer?.pause()
            for (_, timer) in self.levelCooldownTimers {
                timer.pause()
            }
        }
    }
    
    public func updatePlayback(position: Double, isPlaying: Bool, rate: Double) {
        if self.isStopped {
            return
        }
        self.position = position
        self.isPlaying = isPlaying
        self.rate = rate
        self.updatePartAtPosition()
        self.scheduleNext()
    }
    
    // Before `start()`, sets the start position. After it, keeps everything buffered; the load in flight goes on if it
    // holds the target, is contiguous with the buffer around it, or (before the target only) is nearly done
    // (hls.js's onMediaSeeking; D7 fixes the units of the nearly-done test).
    public func seek(to position: Double) {
        if self.isStopped {
            return
        }
        self.position = position
        if case let .loading(load) = self.pipeline {
            let start = load.request.nominalStart - 0.001
            let end = load.request.nominalEnd + 0.001
            let run = self.buffer.bufferedRanges.first(where: { position + HLSBufferModel.maxHole >= $0.lowerBound && position < $0.upperBound })
            let isContiguous = run.map({ !(end < $0.lowerBound || start > $0.upperBound + HLSBufferModel.maxHole) }) ?? false
            if !isContiguous {
                let isBefore = position < start
                let isPast = position > end
                if isPast || (isBefore && !self.isNearlyDownloaded(load)) {
                    self.log("seek to \(position) cancels level=\(self.levelKey(load.level)) index=\(load.request.key.index)")
                    self.cancelLoad(load)
                }
            }
        }
        self.updatePartAtPosition()
        self.scheduleNext()
    }
    
    // Starts once every level's playlist is set or known not to be on disk.
    public func start() {
        self.isStartRequested = true
        self.tryStart()
        self.scheduleNext()
    }
    
    // Cancels everything; no callbacks after.
    public func stop() {
        self.isStopped = true
        if case let .loading(load) = self.pipeline {
            load.dataLoad?.cancel()
        }
        self.pipeline = .idle
        for (_, initLoad) in self.initLoads {
            initLoad.cancellable?.cancel()
        }
        self.initLoads.removeAll()
        self.stopLoadTimers()
        self.retryTimer?.cancel()
        self.retryTimer = nil
        self.preloadPlaylistTimer?.cancel()
        self.preloadPlaylistTimer = nil
        for (_, timer) in self.levelCooldownTimers {
            timer.cancel()
        }
        self.levelCooldownTimers.removeAll()
        self.onBufferChanged = nil
        self.onLog = nil
    }
    
    // A rejected level is never played: a manual pick of it plays the nearest level with a playlist.
    public func isPlaylistRejected(level: Int) -> Bool {
        return self.rejectedPlaylists.contains(level)
    }
    
    public func level(at position: Double) -> Int? {
        return self.buffer.part(at: position)?.key.level
    }
    
    // MARK: State
    
    private var maxAutoLevel: Int {
        return max(0, min(self.cap ?? (self.levels.count - 1), self.levels.count - 1))
    }
    
    private var duration: Double? {
        return self.playlists.compactMap({ $0?.totalDuration }).max()
    }
    
    private func log(_ line: String) {
        self.onLog?(line)
    }
    
    private func levelKey(_ level: Int) -> Int {
        return level >= 0 && level < self.levels.count ? self.levels[level].key : -1
    }
    
    private func emitBufferChanged() {
        if self.isStopped {
            return
        }
        self.onBufferChanged?(self.buffer.parts, self.duration)
    }
    
    private var playbackRate: Double {
        return self.rate != 0.0 ? abs(self.rate) : 1.0
    }
    
    private func abrContext() -> HLSAbrContext {
        return HLSAbrContext(
            levels: self.levels,
            averageSegmentDuration: self.playlists.map { $0?.averageSegmentDuration },
            levelErrors: self.levelErrors,
            minAutoLevel: 0,
            maxAutoLevel: self.maxAutoLevel,
            lastLoadedLevel: self.lastLoadedLevel,
            currentSegmentDuration: self.lastSegmentDuration,
            bufferStarvationDelay: self.buffer.forwardLength(from: self.position) / self.playbackRate,
            ttfbSeconds: HLSBandwidthEstimator.defaultTTFBMs / 1000.0,
            lastLevelLoadSeconds: 0.0
        )
    }
    
    // hls.js's isFragmentNearlyDownloaded with the units fixed (D7): the rest arrives within 0.15 s.
    private func isNearlyDownloaded(_ load: SegmentLoad) -> Bool {
        if load.networkBytes <= 0 {
            return false
        }
        let remaining = Double(max(0, load.expectedNetworkBytes - load.networkBytes))
        return remaining * 8.0 / self.estimator.estimate <= 0.15
    }
    
    // MARK: Segments
    
    // The level's next segment after `bufferEnd` that is not buffered. A segment counts as covered when less than
    // `maxHole` of it lies beyond `bufferEnd`, so a probed end slightly short of the nominal one does not reload it.
    private func nextSegment(level: Int, after bufferEnd: Double) -> HLSMediaPlaylist.Segment? {
        guard level >= 0 && level < self.levels.count, let playlist = self.playlists[level] else {
            return nil
        }
        let threshold = bufferEnd + HLSBufferModel.maxHole
        // Within `maxHole` of the end, short of the player's end tolerance, the segment there is still needed.
        var index = playlist.segments.firstIndex(where: { $0.end > threshold }) ?? playlist.segments.firstIndex(where: { $0.end > bufferEnd }) ?? playlist.segments.count
        while index < playlist.segments.count && self.buffer.contains(HLSSegmentKey(level: level, index: index)) {
            index += 1
        }
        return index < playlist.segments.count ? playlist.segments[index] : nil
    }
    
    // A part is always the level's init and the segment: the bytes between the init and the first segment (sidx)
    // make FFmpeg report the whole video's duration for a video-only file.
    private func appendRequest(level: Int, segment: HLSMediaPlaylist.Segment) -> HLSAppendRequest? {
        guard let playlist = self.playlists[level] else {
            return nil
        }
        let key = HLSSegmentKey(level: level, index: segment.index)
        return HLSAppendRequest(key: key, initRange: playlist.initSegment, dataRange: segment.byteRange, nominalStart: segment.start, nominalEnd: segment.end)
    }
    
    // D5: the first segment of a level whose init is not ready is fetched from byte 0 in one range, init included.
    private func loadRange(for request: HLSAppendRequest, level: Int) -> (range: Range<Int64>, coversInit: Bool) {
        if request.key.index == 0, let initRange = request.initRange, initRange.lowerBound == 0, initRange.upperBound <= request.dataRange.lowerBound, !self.isInitReady(request, level: level) {
            return (0 ..< request.dataRange.upperBound, true)
        }
        return (request.dataRange, false)
    }
    
    private func isOnDisk(level: Int, range: Range<Int64>) -> Bool {
        return self.environment.missingBytes(level: level, range: range) == 0
    }
    
    private func isInitReady(_ request: HLSAppendRequest, level: Int) -> Bool {
        guard let initRange = request.initRange else {
            return true
        }
        return self.loadedInits.contains(level) || self.isOnDisk(level: level, range: initRange)
    }
    
    private func isOnDisk(_ request: HLSAppendRequest, level: Int) -> Bool {
        return self.isInitReady(request, level: level) && self.isOnDisk(level: level, range: request.dataRange)
    }
    
    private func isNextSegmentOnDisk(level: Int, after bufferEnd: Double) -> Bool {
        guard let segment = self.nextSegment(level: level, after: bufferEnd), let request = self.appendRequest(level: level, segment: segment) else {
            return false
        }
        return self.isOnDisk(request, level: level)
    }
    
    // A level with a playlist: the target if it has one, else the nearest lower one, else the nearest higher one.
    private func levelWithPlaylist(near target: Int) -> Int? {
        if target >= 0 && target < self.levels.count && self.playlists[target] != nil {
            return target
        }
        for level in stride(from: min(target, self.levels.count - 1), through: 0, by: -1) where self.playlists[level] != nil {
            return level
        }
        for level in max(target, 0) ..< self.levels.count where self.playlists[level] != nil {
            return level
        }
        return nil
    }
    
    // An errored level is avoided: a level without errors cached at the position first, at any level within the cap,
    // else the nearest level with a playlist and no errors, lower first.
    private func avoidingErroredLevel(_ level: Int, after bufferEnd: Double) -> Int {
        if level < 0 || level >= self.levels.count || self.levelErrors[level] == 0 {
            return level
        }
        for candidate in stride(from: self.maxAutoLevel, through: 0, by: -1) where self.levelErrors[candidate] == 0 && self.isNextSegmentOnDisk(level: candidate, after: bufferEnd) {
            return candidate
        }
        for candidate in stride(from: level - 1, through: 0, by: -1) where self.levelErrors[candidate] == 0 && self.playlists[candidate] != nil {
            return candidate
        }
        for candidate in (level + 1) ..< self.levels.count where candidate <= self.maxAutoLevel && self.levelErrors[candidate] == 0 && self.playlists[candidate] != nil {
            return candidate
        }
        return level
    }
    
    // MARK: Start
    
    // Waits for every level's playlist, or word that it is not on disk: a cached opening is judged from playlists, and
    // one that arrives late must not lose the start to the preload quality. The preload level's own playlist is waited
    // for, but not forever: a fetch can hang without failing, so once another level's playlist is in, the start gives it
    // `preloadPlaylistWait` and then goes ahead without it.
    private func tryStart() {
        if !self.isStartRequested || self.isStarted || self.isStopped {
            return
        }
        for level in 0 ..< self.levels.count where self.playlists[level] == nil && !self.unavailablePlaylists.contains(level) {
            return
        }
        if self.playlists[self.preloadLevel] == nil && !self.rejectedPlaylists.contains(self.preloadLevel) && !self.isPreloadPlaylistWaitOver {
            if self.preloadPlaylistTimer == nil && self.playlists.contains(where: { $0 != nil }) {
                self.preloadPlaylistTimer = ConnectedTimer(environment: self.environment, delay: self.configuration.preloadPlaylistWait, isRunning: self.isNetworkAvailable, action: { [weak self] in
                    guard let self, !self.isStopped else {
                        return
                    }
                    self.preloadPlaylistTimer = nil
                    self.isPreloadPlaylistWaitOver = true
                    self.log("start without the preload playlist level=\(self.levelKey(self.preloadLevel))")
                    self.tryStart()
                    self.scheduleNext()
                })
            }
            return
        }
        self.preloadPlaylistTimer?.cancel()
        self.preloadPlaylistTimer = nil
        self.isStarted = true
    }
    
    // The start rule (`HLSLevels.startLevel`), judged again for every segment until the first one is appended, so a seek or a cap change
    // before then is honoured.
    private func updateStartLevel(at position: Double) -> Int {
        let startLevel = HLSLevels.startLevel(cap: self.maxAutoLevel, preloadLevel: self.preloadLevel, manualLevel: self.manualLevel, isOpeningOnDisk: { level in
            return self.isNextSegmentOnDisk(level: level, after: position)
        })
        if startLevel != self.startLevel {
            let reason: String
            if self.manualLevel != nil {
                reason = "manual"
            } else if self.isNextSegmentOnDisk(level: startLevel, after: position) {
                reason = "cached opening"
            } else {
                reason = "preload"
            }
            self.startLevel = startLevel
            self.log("start level=\(self.levelKey(startLevel)) reason=\(reason) position=\(position)")
        }
        return startLevel
    }
    
    // MARK: Scheduling
    
    // Runs the scheduler, flattening re-entrant calls (environment callbacks may complete synchronously).
    private func scheduleNext() {
        if self.isScheduling {
            self.needsSchedule = true
            return
        }
        self.isScheduling = true
        repeat {
            self.needsSchedule = false
            self.scheduleOnce()
        } while self.needsSchedule && !self.isStopped
        self.isScheduling = false
    }
    
    private func scheduleOnce() {
        guard !self.isStopped, self.isStarted, self.retryTimer == nil, case .idle = self.pipeline else {
            return
        }
        let position = self.position
        if self.buffer.forwardLength(from: position) >= self.configuration.maxBufferAhead {
            return
        }
        let forwardEnd = self.buffer.forwardEnd(from: position)
        let bufferEnd = forwardEnd ?? position
        // The end of the stream: the buffer ahead ends with some level's last segment.
        if let forwardEnd, let endPart = self.buffer.part(at: max(position, forwardEnd - 0.001)), let endPlaylist = self.playlists[endPart.key.level], endPart.key.index == endPlaylist.segments.count - 1 {
            return
        }
        
        var level: Int
        if let manualLevel = self.manualLevel {
            level = manualLevel
        } else if self.lastLoadedLevel == nil {
            level = self.avoidingErroredLevel(self.updateStartLevel(at: bufferEnd), after: bufferEnd)
            // Started without the preload level's playlist: the nearest level with one, within the cap first.
            if self.playlists[level] == nil, let playable = self.levelWithPlaylist(near: min(level, self.maxAutoLevel)) {
                level = playable
            }
        } else if let forcedLevel = self.forcedLevel {
            self.forcedLevel = nil
            level = self.avoidingErroredLevel(min(forcedLevel, self.maxAutoLevel), after: bufferEnd)
        } else {
            let context = self.abrContext()
            let seedValue = self.hasNetworkSample ? self.estimator.estimate : self.initialSeed
            let target = HLSAbr.targetLevel(context, estimator: self.estimator, seed: seedValue, preloadLevel: self.preloadLevel)
            guard let playableTarget = self.levelWithPlaylist(near: target) else {
                return
            }
            let choice = HLSAbr.cacheAwareLevel(target: playableTarget, maxAutoLevel: self.maxAutoLevel, isOnDisk: { level in
                return self.isNextSegmentOnDisk(level: level, after: bufferEnd)
            })
            level = self.avoidingErroredLevel(choice.level, after: bufferEnd)
            if level != self.lastLoggedLevelChoice {
                self.lastLoggedLevelChoice = level
                let estimateString = self.estimate.map { "\(Int($0))" } ?? "none"
                self.log("level \(self.levelKey(level)) target=\(self.levelKey(target)) fromDisk=\(choice.fromDisk) estimate=\(estimateString) bufferEnd=\(bufferEnd)")
            }
        }
        
        guard let segment = self.nextSegment(level: level, after: bufferEnd), let request = self.appendRequest(level: level, segment: segment) else {
            // The end of the stream at this level, or its playlist has not arrived yet.
            return
        }
        // hls.js's exceedsMaxBuffer: past a hole, what is buffered between the position and the segment counts too.
        if segment.start > bufferEnd + HLSBufferModel.maxHole {
            let ahead = self.buffer.bufferedRanges.reduce(0.0, { sum, range in
                return sum + max(0.0, min(range.upperBound, segment.start) - max(range.lowerBound, position))
            })
            if ahead >= self.configuration.maxBufferAhead {
                return
            }
        }
        if self.isOnDisk(request, level: level) {
            self.append(request, level: level, duration: segment.duration, source: .disk)
        } else if self.isOnDisk(level: level, range: request.dataRange) {
            self.startInitOnlyLoad(request, level: level, duration: segment.duration)
        } else {
            self.startLoad(request, level: level, duration: segment.duration)
        }
    }
    
    // MARK: Loading
    
    private func startLoad(_ request: HLSAppendRequest, level: Int, duration: Double) {
        let (range, coversInit) = self.loadRange(for: request, level: level)
        let load = SegmentLoad(request: request, loadRange: range, level: level, duration: duration, startTime: self.environment.now, source: .network, expectedNetworkBytes: self.environment.missingBytes(level: level, range: range))
        self.pipeline = .loading(load)
        
        let dataLoad = self.environment.load(level: level, range: range, priority: .playback, progress: { [weak self, weak load] networkBytes in
            guard let self, let load, !self.isStopped else {
                return
            }
            self.loadProgressed(load, networkBytes: networkBytes)
        }, completion: { [weak self, weak load] outcome in
            guard let self, let load else {
                return
            }
            self.segmentLoadFinished(load, outcome: outcome)
        })
        if !load.isDataDone {
            load.dataLoad = dataLoad
            self.startLoadTimers(load)
        }
        if !coversInit, let initRange = request.initRange, !self.isInitReady(request, level: level) {
            self.startInitLoad(level: level, range: initRange)
        }
    }
    
    // The segment is on disk and only its level's init is not.
    private func startInitOnlyLoad(_ request: HLSAppendRequest, level: Int, duration: Double) {
        let load = SegmentLoad(request: request, loadRange: request.dataRange, level: level, duration: duration, startTime: self.environment.now, source: .disk, expectedNetworkBytes: 0)
        load.isDataDone = true
        self.pipeline = .loading(load)
        self.proceedAfterLoad(load)
    }
    
    private func startInitLoad(level: Int, range: Range<Int64>) {
        if self.initLoads[level] != nil {
            return
        }
        let initLoad = InitLoad()
        self.initLoads[level] = initLoad
        let cancellable = self.environment.load(level: level, range: range, priority: .playback, progress: { _ in
        }, completion: { [weak self, weak initLoad] outcome in
            guard let self, let initLoad else {
                return
            }
            self.initLoadFinished(initLoad, level: level, outcome: outcome)
        })
        if !initLoad.isDone {
            initLoad.cancellable = cancellable
        }
    }
    
    private func initLoadFinished(_ initLoad: InitLoad, level: Int, outcome: HLSLoadOutcome) {
        initLoad.isDone = true
        initLoad.cancellable = nil
        if self.initLoads[level] === initLoad {
            self.initLoads[level] = nil
        }
        if self.isStopped {
            return
        }
        switch outcome {
        case .completed:
            self.loadedInits.insert(level)
            if case let .loading(load) = self.pipeline, load.level == level, load.isDataDone {
                self.proceedAfterLoad(load)
            }
        case .failed:
            // The segment waiting for this init fails with it, and retries with the same backoff.
            self.log("init load failed level=\(self.levelKey(level))")
            if case let .loading(load) = self.pipeline, load.level == level, !self.coversInit(load) {
                self.cancelLoad(load)
                self.handleFailure(level: level, key: load.request.key)
            }
        }
    }
    
    private func segmentLoadFinished(_ load: SegmentLoad, outcome: HLSLoadOutcome) {
        guard !self.isStopped, case let .loading(current) = self.pipeline, current === load else {
            return
        }
        load.isDataDone = true
        load.dataLoad = nil
        self.stopLoadTimers()
        switch outcome {
        case let .completed(networkBytes, isSampleable):
            load.networkBytes = networkBytes
            if self.coversInit(load) {
                self.loadedInits.insert(load.level)
            }
            // D1: only network bytes sample, and not when the load joined a fetch already under way. D2: over the
            // whole request.
            if networkBytes > 0 && isSampleable {
                let durationMs = (self.environment.now - load.startTime) * 1000.0
                self.estimator.sample(durationMs: durationMs, bytes: networkBytes)
                self.hasNetworkSample = true
                self.seed.value = self.estimator.estimate
                self.log("sample bytes=\(networkBytes) ms=\(durationMs) estimate=\(Int(self.estimator.estimate))")
            }
            self.proceedAfterLoad(load)
        case .failed:
            self.pipeline = .idle
            self.handleFailure(level: load.level, key: load.request.key)
        }
    }
    
    // Appends once both the segment and its level's init are on disk.
    private func proceedAfterLoad(_ load: SegmentLoad) {
        self.stopLoadTimers()
        if let initRange = load.request.initRange, !self.isInitReady(load.request, level: load.level) {
            // Its completion proceeds with the load.
            self.startInitLoad(level: load.level, range: initRange)
            return
        }
        self.append(load.request, level: load.level, duration: load.duration, source: load.source)
    }
    
    private func coversInit(_ load: SegmentLoad) -> Bool {
        guard let initRange = load.request.initRange else {
            return false
        }
        return load.loadRange.lowerBound <= initRange.lowerBound && initRange.upperBound <= load.loadRange.upperBound
    }
    
    private func cancelLoad(_ load: SegmentLoad) {
        load.dataLoad?.cancel()
        load.dataLoad = nil
        self.stopLoadTimers()
        if case let .loading(current) = self.pipeline, current === load {
            self.pipeline = .idle
        }
    }
    
    // MARK: Failures
    
    // D10: never fatal. Retries after 1, 2, 4, 8 s, then every 8 s; the clock stands still while the network is
    // unavailable. After `levelErrorLimit` failures in a row the level is errored and the next pick avoids it at once,
    // for a cool-down: never for good, a network failure is never terminal.
    private func handleFailure(level: Int, key: HLSSegmentKey) {
        let failures = (self.segmentFailures[key] ?? 0) + 1
        self.segmentFailures[key] = failures
        if level >= 0 && level < self.levels.count {
            self.levelFailures[level] += 1
            if self.levelFailures[level] >= self.configuration.levelErrorLimit && self.levelErrors[level] == 0 {
                self.levelErrors[level] = self.levelFailures[level]
                self.levelErrorTrips[level] += 1
                let cooldown = min(self.configuration.maximumLevelErrorCooldown, self.configuration.levelErrorCooldown * pow(2.0, Double(self.levelErrorTrips[level] - 1)))
                self.log("level \(self.levelKey(level)) errored after \(self.levelFailures[level]) failures, tried again in \(cooldown) s")
                self.levelCooldownTimers[level] = ConnectedTimer(environment: self.environment, delay: cooldown, isRunning: self.isNetworkAvailable, action: { [weak self] in
                    self?.levelCooldownEnded(level: level)
                })
                self.scheduleNext()
                return
            }
        }
        let delays = self.configuration.retryDelays
        let delay = delays.isEmpty ? 0.0 : delays[min(failures - 1, delays.count - 1)]
        self.log("failure level=\(self.levelKey(level)) index=\(key.index) count=\(failures) retry in \(delay) s")
        self.retryTimer = ConnectedTimer(environment: self.environment, delay: delay, isRunning: self.isNetworkAvailable, action: { [weak self] in
            guard let self, !self.isStopped else {
                return
            }
            self.retryTimer = nil
            self.scheduleNext()
        })
    }
    
    // The level may be picked again. One more failure errors it again, for twice as long; a load resets both.
    private func levelCooldownEnded(level: Int) {
        self.levelCooldownTimers[level] = nil
        if self.isStopped || self.rejectedPlaylists.contains(level) {
            return
        }
        self.levelErrors[level] = 0
        self.levelFailures[level] = self.configuration.levelErrorLimit - 1
        self.log("level \(self.levelKey(level)) tried again")
        self.scheduleNext()
    }
    
    private func noteSuccess(level: Int, key: HLSSegmentKey) {
        self.segmentFailures.removeValue(forKey: key)
        if level >= 0 && level < self.levels.count {
            self.levelFailures[level] = 0
            self.levelErrorTrips[level] = 0
        }
    }
    
    // MARK: Load timers
    
    private func startLoadTimers(_ load: SegmentLoad) {
        self.stopLoadTimers()
        // hls.js's abandon check waits for media.readyState: the first segment is never abandoned.
        if self.manualLevel == nil && load.level > 0 && self.lastLoadedLevel != nil {
            self.scheduleAbandonCheck(load)
        }
    }
    
    private func stopLoadTimers() {
        self.abandonTimer?.cancel()
        self.abandonTimer = nil
    }
    
    private func loadProgressed(_ load: SegmentLoad, networkBytes: Int64) {
        guard case let .loading(current) = self.pipeline, current === load, networkBytes > load.networkBytes else {
            return
        }
        load.networkBytes = networkBytes
    }
    
    private func scheduleAbandonCheck(_ load: SegmentLoad) {
        self.abandonTimer = self.environment.schedule(after: self.configuration.abandonPollInterval, { [weak self, weak load] in
            guard let self, let load, !self.isStopped, case let .loading(current) = self.pipeline, current === load else {
                return
            }
            self.abandonTimer = nil
            if !self.checkAbandon(load) {
                self.scheduleAbandonCheck(load)
            }
        })
    }
    
    // hls.js's abandon rule (`_abandonRulesCheck`), in Auto only. D6: the replacement is a lower level cached at that position when
    // one is, else the rule's level.
    private func checkAbandon(_ load: SegmentLoad) -> Bool {
        if self.manualLevel != nil {
            return false
        }
        let input = HLSAbandonInput(
            fragmentLevel: load.level,
            fragmentDuration: load.duration,
            expectedBytes: load.expectedNetworkBytes,
            loadedBytes: load.networkBytes,
            elapsedMs: (self.environment.now - load.startTime) * 1000.0,
            estimator: self.estimator,
            playbackRate: self.rate,
            isPaused: !self.isPlaying,
            context: self.abrContext()
        )
        guard let decision = HLSAbr.abandonDecision(input) else {
            return false
        }
        self.cancelLoad(load)
        self.estimator = decision.estimator
        // Only a sample of the abandoned load's progress or a reset makes the estimate the network's.
        if input.loadedBytes > 0 || decision.resetEstimateTo != nil {
            self.hasNetworkSample = true
            self.seed.value = self.estimator.estimate
        }
        
        // Where loading continues, as the scheduler sees it.
        let bufferEnd = self.buffer.forwardEnd(from: self.position) ?? self.position
        var replacement: Int?
        for candidate in stride(from: min(load.level - 1, self.maxAutoLevel), through: 0, by: -1) where self.levelErrors[candidate] == 0 && self.isNextSegmentOnDisk(level: candidate, after: bufferEnd) {
            replacement = candidate
            break
        }
        let level = replacement ?? self.avoidingErroredLevel(self.levelWithPlaylist(near: decision.level) ?? decision.level, after: bufferEnd)
        self.forcedLevel = level
        self.log("abandon level=\(self.levelKey(load.level)) index=\(load.request.key.index) loaded=\(load.networkBytes)/\(load.expectedNetworkBytes) to level=\(self.levelKey(level)) fromDisk=\(replacement != nil) estimate=\(Int(self.estimator.estimate))")
        self.scheduleNext()
        return true
    }
    
    // MARK: Appending
    
    private func append(_ request: HLSAppendRequest, level: Int, duration: Double, source: HLSLoadSource) {
        self.pipeline = .appending(request.key)
        self.environment.append(level: level, request: request, completion: { [weak self] outcome in
            self?.appendFinished(request, level: level, duration: duration, source: source, outcome: outcome)
        })
    }
    
    private func appendFinished(_ request: HLSAppendRequest, level: Int, duration: Double, source: HLSLoadSource, outcome: HLSAppendOutcome) {
        guard !self.isStopped, case let .appending(key) = self.pipeline, key == request.key else {
            return
        }
        self.pipeline = .idle
        switch outcome {
        case let .appended(start, end):
            self.buffer.insert(HLSBufferedPart(key: request.key, start: start, end: end))
            self.lastLoadedLevel = level
            self.lastSegmentDuration = duration
            self.noteSuccess(level: level, key: request.key)
            if self.firstSegmentSource == nil {
                self.firstSegmentLevel = level
                self.firstSegmentSource = source
                self.log("first segment level=\(self.levelKey(level)) index=\(request.key.index) source=\(source == .disk ? "disk" : "network")")
            }
            if self.flushAfterAppend {
                self.flushAfterAppend = false
                self.flushForward()
            } else {
                self.emitBufferChanged()
            }
            self.updatePartAtPosition()
            self.scheduleNext()
        case .failed:
            // The bytes may be gone from disk (a cleared cache): judge the level's init from disk again.
            self.loadedInits.remove(level)
            self.flushAfterAppend = false
            self.log("append failed level=\(self.levelKey(level)) index=\(request.key.index)")
            self.handleFailure(level: level, key: request.key)
        }
    }
    
    // MARK: Buffer
    
    private func isEverythingAhead(atLevel level: Int) -> Bool {
        for part in self.buffer.parts where part.end > self.position && part.key.level != level {
            return false
        }
        switch self.pipeline {
        case let .loading(load):
            return load.level == level
        case let .appending(key):
            return key.level == level
        case .idle:
            return true
        }
    }
    
    private func flushForward() {
        let removed = self.buffer.removeForward(from: self.position)
        if !removed.isEmpty {
            self.environment.remove(keys: removed)
        }
        self.partAtPosition = nil
        self.emitBufferChanged()
    }
    
    // Trims the back buffer when the part at the playhead changes, as hls.js does on FRAG_CHANGED.
    private func updatePartAtPosition() {
        let key = self.buffer.part(at: self.position)?.key
        if key == self.partAtPosition {
            return
        }
        self.partAtPosition = key
        guard let key, let playlist = self.playlists[key.level] else {
            return
        }
        let removed = self.buffer.trimBackBuffer(position: self.position, segmentDuration: playlist.averageSegmentDuration, backBuffer: self.configuration.backBuffer)
        if !removed.isEmpty {
            self.environment.remove(keys: removed)
            self.emitBufferChanged()
        }
    }
}
