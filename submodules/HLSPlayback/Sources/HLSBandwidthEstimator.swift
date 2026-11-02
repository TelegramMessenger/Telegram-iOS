// Ported from hls.js v1.7.3 (src/utils/ewma.ts, src/utils/ewma-bandwidth-estimator.ts), Copyright (c) Dailymotion and hls.js contributors, Apache License 2.0.

import Foundation

// An exponentially weighted moving average whose half-life is measured in weight units, with the zero-factor
// correction that makes the first sample the estimate exactly whatever its weight.
public struct HLSEWMA: Equatable {
    public let halfLife: Double
    private let alpha: Double
    private var rawEstimate: Double
    public private(set) var totalWeight: Double
    
    public init(halfLife: Double, estimate: Double = 0.0, totalWeight: Double = 0.0) {
        self.halfLife = halfLife
        self.alpha = halfLife != 0.0 ? exp(log(0.5) / halfLife) : 0.0
        self.rawEstimate = estimate
        self.totalWeight = totalWeight
    }
    
    public mutating func sample(weight: Double, value: Double) {
        let adjustedAlpha = pow(self.alpha, weight)
        self.rawEstimate = value * (1.0 - adjustedAlpha) + adjustedAlpha * self.rawEstimate
        self.totalWeight += weight
    }
    
    public var estimate: Double {
        if self.alpha != 0.0 {
            let zeroFactor = 1.0 - pow(self.alpha, self.totalWeight)
            if zeroFactor != 0.0 {
                return self.rawEstimate / zeroFactor
            }
        }
        return self.rawEstimate
    }
    
    // The same estimate, carried by `weight`: as if one sample of that weight and value had been taken.
    public func withTotalWeight(_ weight: Double) -> HLSEWMA {
        let estimate = self.estimate
        let rawEstimate = self.alpha != 0.0 ? estimate * (1.0 - pow(self.alpha, weight)) : estimate
        return HLSEWMA(halfLife: self.halfLife, estimate: rawEstimate, totalWeight: weight)
    }
}

// Bandwidth in bits per second, as hls.js estimates it: the minimum of a fast and a slow EWMA over download time.
// Deviation D2: there is no time-to-first-byte EWMA; the fetch-time model uses the fixed hls.js default instead.
public struct HLSBandwidthEstimator: Equatable {
    public static let defaultTTFBMs: Double = 100.0
    
    // hls.js's VoD half-lives, in seconds of downloading.
    private static let fastHalfLife: Double = 3.0
    private static let slowHalfLife: Double = 9.0
    private static let minWeight: Double = 0.001
    private static let minDelayMs: Double = 50.0
    
    public private(set) var defaultEstimate: Double
    private var fast: HLSEWMA
    private var slow: HLSEWMA
    
    public init(defaultEstimate: Double) {
        self.defaultEstimate = defaultEstimate
        self.fast = HLSEWMA(halfLife: HLSBandwidthEstimator.fastHalfLife)
        self.slow = HLSEWMA(halfLife: HLSBandwidthEstimator.slowHalfLife)
    }
    
    public mutating func sample(durationMs: Double, bytes: Int64) {
        if bytes <= 0 {
            return
        }
        // The duration floor caps one sample at 800 Mbit/s below 5 MB.
        let minDelay = min(HLSBandwidthEstimator.minDelayMs, Double(bytes) / 100_000.0)
        let bits = 8.0 * Double(bytes)
        let durationSeconds = max(durationMs, minDelay) / 1000.0
        let bitsPerSecond = bits / durationSeconds
        self.fast.sample(weight: durationSeconds, value: bitsPerSecond)
        self.slow.sample(weight: durationSeconds, value: bitsPerSecond)
    }
    
    public var canEstimate: Bool {
        return self.fast.totalWeight >= HLSBandwidthEstimator.minWeight
    }
    
    public var estimate: Double {
        if self.canEstimate {
            // Adapts down quickly and up slowly.
            return min(self.fast.estimate, self.slow.estimate)
        } else {
            return self.defaultEstimate
        }
    }
    
    // Seconds of downloading behind the estimate.
    public var totalWeight: Double {
        return self.fast.totalWeight
    }
    
    // The same estimate with each average's weight capped at `weight` and then multiplied by `decay`: a prior that the
    // next samples move more than the history it summarizes would have let them.
    public func withMaximumWeight(_ weight: Double, decay: Double) -> HLSBandwidthEstimator {
        var result = self
        result.fast = self.fast.withTotalWeight(min(weight, self.fast.totalWeight) * decay)
        result.slow = self.slow.withTotalWeight(min(weight, self.slow.totalWeight) * decay)
        return result
    }
    
    // hls.js's `resetEstimator(value)`.
    public mutating func reset(defaultEstimate: Double) {
        self.defaultEstimate = defaultEstimate
        self.fast = HLSEWMA(halfLife: HLSBandwidthEstimator.fastHalfLife)
        self.slow = HLSEWMA(halfLife: HLSBandwidthEstimator.slowHalfLife)
    }
}
