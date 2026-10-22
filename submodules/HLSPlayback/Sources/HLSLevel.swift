// Ported from hls.js v1.7.3 (src/controller/level-controller.ts), Copyright (c) Dailymotion and hls.js contributors, Apache License 2.0.

import Foundation

public struct HLSLevel: Equatable {
    // The quality key the app uses everywhere: min(width, height).
    public var key: Int
    public var width: Int
    public var height: Int
    // Bits per second: the quality file's size over the video's duration.
    public var bandwidth: Int
    
    public init(key: Int, width: Int, height: Int, bandwidth: Int) {
        self.key = key
        self.width = width
        self.height = height
        self.bandwidth = bandwidth
    }
}

public enum HLSLevels {
    // hls.js's level order for levels that carry RESOLUTION and BANDWIDTH only: ascending height, ties by ascending
    // bandwidth, otherwise stable. Every level index in this module is into this order.
    public static func sorted(_ levels: [HLSLevel]) -> [HLSLevel] {
        return levels.enumerated().sorted(by: { lhs, rhs in
            if lhs.element.height != rhs.element.height {
                return lhs.element.height < rhs.element.height
            }
            if lhs.element.bandwidth != rhs.element.bandwidth {
                return lhs.element.bandwidth < rhs.element.bandwidth
            }
            return lhs.offset < rhs.offset
        }).map(\.element)
    }
    
    // The quality the chat preloads and the player starts with: the smallest key of at least 600, else the smallest.
    public static func preloadQualityKey(keys: [Int]) -> Int? {
        let sortedKeys = keys.sorted()
        return sortedKeys.first(where: { $0 >= 600 }) ?? sortedKeys.first
    }
    
    // The start rule: the manual level; else the highest level within the cap whose opening is on disk; else the level
    // the network class's estimate picks, when the caller takes it, else the preload level, clamped to the cap.
    public static func startLevel(cap: Int, preloadLevel: Int, manualLevel: Int?, estimateLevel: Int? = nil, isOpeningOnDisk: (Int) -> Bool) -> Int {
        if let manualLevel {
            return manualLevel
        }
        if cap >= 0 {
            for level in stride(from: cap, through: 0, by: -1) {
                if isOpeningOnDisk(level) {
                    return level
                }
            }
        }
        return min(estimateLevel ?? preloadLevel, cap)
    }
}
