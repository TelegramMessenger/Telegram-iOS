// Ported from hls.js v1.7.3 (src/controller/abr-controller.ts), Copyright (c) Dailymotion and hls.js contributors, Apache License 2.0.

import Foundation

// What the quality rules read about the player. Our levels carry no CODECS, FRAME-RATE or VIDEO-RANGE and their
// BANDWIDTH is both the peak and the average, so hls.js's codec, range, frame-rate and media-capabilities filters
// are inert and are not ported.
public struct HLSAbrContext: Equatable {
    // Sorted with `HLSLevels.sorted`.
    public var levels: [HLSLevel]
    // Per level; nil while that level's playlist is not loaded.
    public var averageSegmentDuration: [Double?]
    public var levelErrors: [Int]
    public var minAutoLevel: Int
    // The cap.
    public var maxAutoLevel: Int
    // The level of the last appended segment, from disk or network: the quality on screen.
    public var lastLoadedLevel: Int?
    public var currentSegmentDuration: Double?
    // Forward buffer seconds / |playback rate|.
    public var bufferStarvationDelay: Double
    public var ttfbSeconds: Double
    public var lastLevelLoadSeconds: Double
    
    public init(levels: [HLSLevel], averageSegmentDuration: [Double?], levelErrors: [Int], minAutoLevel: Int, maxAutoLevel: Int, lastLoadedLevel: Int?, currentSegmentDuration: Double?, bufferStarvationDelay: Double, ttfbSeconds: Double, lastLevelLoadSeconds: Double) {
        self.levels = levels
        self.averageSegmentDuration = averageSegmentDuration
        self.levelErrors = levelErrors
        self.minAutoLevel = minAutoLevel
        self.maxAutoLevel = maxAutoLevel
        self.lastLoadedLevel = lastLoadedLevel
        self.currentSegmentDuration = currentSegmentDuration
        self.bufferStarvationDelay = bufferStarvationDelay
        self.ttfbSeconds = ttfbSeconds
        self.lastLevelLoadSeconds = lastLevelLoadSeconds
    }
}

public struct HLSAbandonInput: Equatable {
    public var fragmentLevel: Int
    public var fragmentDuration: Double
    // The bytes the network still owed when the load started (D1): what was on disk then is not expected.
    public var expectedBytes: Int64
    // Network bytes of the in-flight load so far.
    public var loadedBytes: Int64
    public var elapsedMs: Double
    public var estimator: HLSBandwidthEstimator
    // The rate `context.bufferStarvationDelay` was divided by.
    public var playbackRate: Double
    public var isPaused: Bool
    public var context: HLSAbrContext
    
    public init(fragmentLevel: Int, fragmentDuration: Double, expectedBytes: Int64, loadedBytes: Int64, elapsedMs: Double, estimator: HLSBandwidthEstimator, playbackRate: Double, isPaused: Bool, context: HLSAbrContext) {
        self.fragmentLevel = fragmentLevel
        self.fragmentDuration = fragmentDuration
        self.expectedBytes = expectedBytes
        self.loadedBytes = loadedBytes
        self.elapsedMs = elapsedMs
        self.estimator = estimator
        self.playbackRate = playbackRate
        self.isPaused = isPaused
        self.context = context
    }
}

public struct HLSAbandonDecision: Equatable {
    public var level: Int
    // For the log: the default the estimator was reset to, when the estimate after sampling the abandoned load's
    // progress was still too optimistic. `estimator` already carries it.
    public var resetEstimateTo: Double?
    // The caller's estimator with that sample and any reset applied; the caller replaces its own with it.
    public var estimator: HLSBandwidthEstimator
    
    public init(level: Int, resetEstimateTo: Double?, estimator: HLSBandwidthEstimator) {
        self.level = level
        self.resetEstimateTo = resetEstimateTo
        self.estimator = estimator
    }
}

public enum HLSAbr {
    public static let bandwidthFactor: Double = 0.95
    public static let bandwidthUpFactor: Double = 0.7
    public static let maxStarvationDelay: Double = 4.0
    
    // JavaScript's `value || fallback` for numbers: 0 and NaN fall through.
    private static func truthy(_ value: Double?) -> Double? {
        guard let value, value != 0.0, !value.isNaN else {
            return nil
        }
        return value
    }
    
    private static func timeToLoadSegment(ttfbSeconds: Double, bandwidth: Double, bits: Double, isSwitch: Bool, lastLevelLoadSeconds: Double) -> Double {
        let segmentLoadSeconds = ttfbSeconds + bits / bandwidth
        let playlistLoadSeconds = isSwitch ? ttfbSeconds + lastLevelLoadSeconds : 0.0
        return segmentLoadSeconds + playlistLoadSeconds
    }
    
    // The highest level in maxAutoLevel...minAutoLevel whose bandwidth fits the adjusted estimate (`upFactor` above
    // the level on screen, `bandwidthFactor` at or below it) and whose next segment loads within
    // bufferStarvationDelay + maxStarvationDelay. Deviation: a level without a playlist is never selected (unless it is
    // the level on screen), because there is no segment to fetch; hls.js would select it and load its playlist. Only this
    // loop skips such levels: callers map other results (step 3, targetLevel's fallbacks, an abandon) to a level with one.
    // The abandon rule passes `includingLevelsWithoutPlaylist` to keep hls.js's rule inside its own steps, whose
    // outcome (a further drop and reset) depends on the level found there; the controller maps its result.
    public static func findBestLevel(_ context: HLSAbrContext, bandwidth: Double, minAutoLevel: Int, maxAutoLevel: Int, bufferStarvationDelay: Double, maxStarvationDelay: Double, bandwidthFactor: Double, upFactor: Double, includingLevelsWithoutPlaylist: Bool = false) -> Int? {
        let levels = context.levels
        if levels.count == 1 {
            return 0
        }
        let maxFetchDuration = bufferStarvationDelay + maxStarvationDelay
        // hls.js judges the first selection against `firstLevel`, the first level the master lists: the top one.
        let selectionBaseLevel = context.lastLoadedLevel ?? (levels.count - 1)
        let currentSegmentDuration = context.currentSegmentDuration ?? 0.0
        let ttfbSeconds = context.ttfbSeconds
        
        if maxAutoLevel < minAutoLevel {
            return nil
        }
        for i in stride(from: maxAutoLevel, through: minAutoLevel, by: -1) {
            if i < 0 || i >= levels.count {
                continue
            }
            let levelSegmentDuration = context.averageSegmentDuration[i]
            if levelSegmentDuration == nil && i != context.lastLoadedLevel && !includingLevelsWithoutPlaylist {
                continue
            }
            let upSwitch = i > selectionBaseLevel
            let averageDuration = truthy(levelSegmentDuration) ?? truthy(currentSegmentDuration) ?? 1.0
            let adjustedBandwidth = (upSwitch ? upFactor : bandwidthFactor) * bandwidth
            let bitrate = Double(levels[i].bandwidth)
            let fetchDuration = timeToLoadSegment(ttfbSeconds: ttfbSeconds, bandwidth: adjustedBandwidth, bits: bitrate * averageDuration, isSwitch: levelSegmentDuration == nil, lastLevelLoadSeconds: context.lastLevelLoadSeconds)
            let errorsAllow = i == context.lastLoadedLevel || context.levelErrors[i] == 0
            let fetchAllows = fetchDuration <= ttfbSeconds || !fetchDuration.isFinite || fetchDuration < maxFetchDuration
            if adjustedBandwidth >= bitrate && errorsAllow && fetchAllows {
                return i
            }
        }
        return nil
    }
    
    // hls.js's `getNextABRAutoLevel`, without the bitrate-test branch.
    public static func nextAutoLevel(_ context: HLSAbrContext, estimate: Double, currentLoadLevel: Int) -> Int {
        let levels = context.levels
        if levels.count <= 1 {
            return currentLoadLevel
        }
        let currentSegmentDuration = context.currentSegmentDuration ?? 0.0
        let bufferStarvationDelay = context.bufferStarvationDelay
        
        // Step 1: a level that never rebuffers.
        if truthy(bufferStarvationDelay) != nil {
            if let bestLevel = findBestLevel(context, bandwidth: estimate, minAutoLevel: context.minAutoLevel, maxAutoLevel: context.maxAutoLevel, bufferStarvationDelay: bufferStarvationDelay, maxStarvationDelay: 0.0, bandwidthFactor: HLSAbr.bandwidthFactor, upFactor: HLSAbr.bandwidthUpFactor) {
                return bestLevel
            }
        }
        // Step 2: tolerate up to maxStarvationDelay of rebuffering.
        let maxStarvationDelay = truthy(currentSegmentDuration).flatMap { min($0, HLSAbr.maxStarvationDelay) } ?? HLSAbr.maxStarvationDelay
        if let bestLevel = findBestLevel(context, bandwidth: estimate, minAutoLevel: context.minAutoLevel, maxAutoLevel: context.maxAutoLevel, bufferStarvationDelay: bufferStarvationDelay, maxStarvationDelay: maxStarvationDelay, bandwidthFactor: HLSAbr.bandwidthFactor, upFactor: HLSAbr.bandwidthUpFactor) {
            return bestLevel
        }
        // Step 3: nothing fits; the lowest level if it is cheaper than the current one.
        if currentLoadLevel >= 0 && currentLoadLevel < levels.count && context.minAutoLevel < levels.count && levels[context.minAutoLevel].bandwidth < levels[currentLoadLevel].bandwidth {
            return context.minAutoLevel
        }
        return currentLoadLevel
    }
    
    // The ABR target for the next segment (deviation D12). With a network sample, hls.js's rule. Before one, the seed
    // through hls.js's first-level rule (`firstAutoLevel`), falling to the lowest level rather than the top when
    // nothing fits. With neither, the preload quality: hls.js would pick max(500 kbit/s, min(top, 5 Mbit/s)), which for
    // our playlists is always the top level.
    public static func targetLevel(_ context: HLSAbrContext, estimator: HLSBandwidthEstimator, seed: Double?, preloadLevel: Int) -> Int {
        if estimator.canEstimate {
            return nextAutoLevel(context, estimate: estimator.estimate, currentLoadLevel: context.lastLoadedLevel ?? preloadLevel)
        } else if let seed {
            return findBestLevel(context, bandwidth: seed, minAutoLevel: context.minAutoLevel, maxAutoLevel: context.maxAutoLevel, bufferStarvationDelay: context.bufferStarvationDelay / 2.0, maxStarvationDelay: HLSAbr.maxStarvationDelay, bandwidthFactor: 1.0, upFactor: 1.0) ?? context.minAutoLevel
        } else {
            return min(preloadLevel, context.maxAutoLevel)
        }
    }
    
    // Deviation D4: play the highest level at or above the target, within the cap, whose segment
    // is on disk; otherwise fetch the target. A target above the cap is clamped to it.
    public static func cacheAwareLevel(target: Int, maxAutoLevel: Int, isOnDisk: (Int) -> Bool) -> (level: Int, fromDisk: Bool) {
        let target = min(target, maxAutoLevel)
        if target >= 0 {
            for level in stride(from: maxAutoLevel, through: target, by: -1) {
                if isOnDisk(level) {
                    return (level, true)
                }
            }
        }
        return (target, false)
    }
    
    // hls.js's `_abandonRulesCheck` for one poll of an in-flight network load in auto mode (manual mode is the caller's
    // check). Returns nil to keep loading. The first byte's arrival cannot be observed through MediaBox (D2), so
    // progress counts from the fixed TTFB, and the sample of the abandoned load is the whole elapsed time.
    public static func abandonDecision(_ input: HLSAbandonInput) -> HLSAbandonDecision? {
        let context = input.context
        let levels = context.levels
        let minAutoLevel = context.minAutoLevel
        let duration = input.fragmentDuration
        
        if input.fragmentLevel <= minAutoLevel || input.fragmentLevel >= levels.count || (input.loadedBytes > 0 && input.loadedBytes >= input.expectedBytes) {
            return nil
        }
        if input.isPaused || input.playbackRate == 0.0 {
            return nil
        }
        let ttfbEstimateMs = context.ttfbSeconds * 1000.0
        let playbackRate = abs(input.playbackRate)
        // Only after half of the segment's playback duration has passed.
        if input.elapsedMs <= max(ttfbEstimateMs, 1000.0 * (duration / (playbackRate * 2.0))) {
            return nil
        }
        
        let bufferStarvationDelay = context.bufferStarvationDelay
        let loadedFirstByte = input.loadedBytes > 0
        let bandwidthEstimate = input.estimator.estimate
        let loadedBytes = Double(input.loadedBytes)
        let expectedLength = Double(max(input.loadedBytes, input.expectedBytes))
        var timeStreaming = loadedFirstByte ? input.elapsedMs - ttfbEstimateMs : input.elapsedMs
        if timeStreaming < 1.0 && loadedFirstByte {
            timeStreaming = min(input.elapsedMs, loadedBytes * 8.0 / bandwidthEstimate)
        }
        // Bytes per second.
        let loadRate = loadedFirstByte ? loadedBytes * 1000.0 / timeStreaming : 0.0
        let ttfbSeconds = context.ttfbSeconds
        // Seconds to finish the in-flight segment.
        let segmentLoadedDelay = loadRate != 0.0 ? (expectedLength - loadedBytes) / loadRate : expectedLength * 8.0 / bandwidthEstimate + ttfbSeconds
        if segmentLoadedDelay <= bufferStarvationDelay {
            return nil
        }
        
        // The highest lower level whose segment would load before the buffer runs out.
        let downSwitchBandwidth = loadRate != 0.0 ? loadRate * 8.0 : bandwidthEstimate
        var nextLevelLoadedDelay = Double.infinity
        var nextLoadLevel = input.fragmentLevel - 1
        while nextLoadLevel > minAutoLevel {
            let requiresLevelLoad = context.averageSegmentDuration[nextLoadLevel] == nil
            nextLevelLoadedDelay = timeToLoadSegment(ttfbSeconds: ttfbSeconds, bandwidth: downSwitchBandwidth, bits: duration * Double(levels[nextLoadLevel].bandwidth), isSwitch: requiresLevelLoad, lastLevelLoadSeconds: context.lastLevelLoadSeconds)
            if nextLevelLoadedDelay < min(bufferStarvationDelay, duration + ttfbSeconds) {
                break
            }
            nextLoadLevel -= 1
        }
        // Not faster than finishing the current load, or an unreasonable estimate.
        if nextLevelLoadedDelay >= segmentLoadedDelay {
            return nil
        }
        if nextLevelLoadedDelay > duration * 10.0 {
            return nil
        }
        
        var estimator = input.estimator
        if loadedFirstByte {
            estimator.sample(durationMs: input.elapsedMs, bytes: input.loadedBytes)
        }
        let nextLoadLevelBitrate = Double(levels[nextLoadLevel].bandwidth)
        var resetEstimateTo: Double?
        if estimator.estimate * HLSAbr.bandwidthUpFactor > nextLoadLevelBitrate {
            resetEstimateTo = nextLoadLevelBitrate
            estimator.reset(defaultEstimate: nextLoadLevelBitrate)
        }
        // Keep that level only if its segment fits in the remaining buffer at its own bitrate, else go lower.
        if let bestSwitchLevel = findBestLevel(context, bandwidth: nextLoadLevelBitrate, minAutoLevel: minAutoLevel, maxAutoLevel: nextLoadLevel, bufferStarvationDelay: 0.0, maxStarvationDelay: bufferStarvationDelay, bandwidthFactor: 1.0, upFactor: 1.0, includingLevelsWithoutPlaylist: true) {
            nextLoadLevel = bestSwitchLevel
        }
        // hls.js's `abortAndSwitch` runs at once when the current load is more than twice as slow as the down level's,
        // and then falls further, to what fits at the lowest level's bitrate, resetting the estimate to it. (Otherwise it
        // waits on a timer, and the replacement load aborts the request first.)
        if segmentLoadedDelay > nextLevelLoadedDelay * 2.0 && nextLoadLevel > 0 && nextLoadLevel > minAutoLevel {
            let lowestSwitchLevel = findBestLevel(context, bandwidth: Double(levels[minAutoLevel].bandwidth), minAutoLevel: minAutoLevel, maxAutoLevel: nextLoadLevel, bufferStarvationDelay: 0.0, maxStarvationDelay: bufferStarvationDelay, bandwidthFactor: 1.0, upFactor: 1.0, includingLevelsWithoutPlaylist: true) ?? minAutoLevel
            nextLoadLevel = lowestSwitchLevel
            let lowestBitrate = Double(levels[lowestSwitchLevel].bandwidth)
            resetEstimateTo = lowestBitrate
            estimator.reset(defaultEstimate: lowestBitrate)
        }
        return HLSAbandonDecision(level: nextLoadLevel, resetEstimateTo: resetEstimateTo, estimator: estimator)
    }
}
