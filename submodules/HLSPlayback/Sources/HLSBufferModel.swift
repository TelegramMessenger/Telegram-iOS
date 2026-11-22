// Ported from hls.js v1.7.3 (src/utils/buffer-helper.ts, src/controller/buffer-controller.ts), Copyright (c) Dailymotion and hls.js contributors, Apache License 2.0.

import Foundation

public struct HLSSegmentKey: Hashable {
    public var level: Int
    public var index: Int
    
    public init(level: Int, index: Int) {
        self.level = level
        self.index = index
    }
}

public struct HLSBufferedPart: Equatable {
    public var key: HLSSegmentKey
    // Probed media times of the part.
    public var start: Double
    public var end: Double
    
    public init(key: HLSSegmentKey, start: Double, end: Double) {
        self.key = key
        self.start = start
        self.end = end
    }
}

// The parts handed to the player, in place of hls.js's SourceBuffer ranges and fragment tracker.
public struct HLSBufferModel: Equatable {
    // Gaps shorter than this count as buffered. hls.js uses 0.1 s (`maxBufferHole`), because MSE stalls on a hole;
    // ChunkMediaPlayerV2 plays through gaps of up to 0.5 s and re-anchors within 0.2 s after a seek.
    public static let maxHole: Double = 0.2
    
    // Sorted by start; ties keep insertion order.
    public private(set) var parts: [HLSBufferedPart] = []
    
    public init() {
    }
    
    public mutating func insert(_ part: HLSBufferedPart) {
        self.parts.removeAll(where: { $0.key == part.key })
        let index = self.parts.firstIndex(where: { $0.start > part.start }) ?? self.parts.count
        self.parts.insert(part, at: index)
    }
    
    public func contains(_ key: HLSSegmentKey) -> Bool {
        return self.parts.contains(where: { $0.key == key })
    }
    
    // Parts merged into ranges, joining gaps shorter than `maxHole` (hls.js's `bufferedInfo`).
    public var bufferedRanges: [Range<Double>] {
        var result: [Range<Double>] = []
        for part in self.parts {
            if part.end <= part.start {
                continue
            }
            if let last = result.last, part.start - last.upperBound < HLSBufferModel.maxHole {
                result[result.count - 1] = last.lowerBound ..< max(last.upperBound, part.end)
            } else {
                result.append(part.start ..< part.end)
            }
        }
        return result
    }
    
    // The end of the merged range containing `position`, which may sit up to `maxHole` before the range's start.
    public func forwardEnd(from position: Double) -> Double? {
        for range in self.bufferedRanges {
            if position + HLSBufferModel.maxHole >= range.lowerBound && position < range.upperBound {
                return range.upperBound
            }
        }
        return nil
    }
    
    public func forwardLength(from position: Double) -> Double {
        guard let end = self.forwardEnd(from: position) else {
            return 0.0
        }
        return max(0.0, end - position)
    }
    
    // The latest-starting part that contains `position`: after an overlap, the newer level's part is the one on screen.
    public func part(at position: Double) -> HLSBufferedPart? {
        return self.parts.last(where: { $0.start <= position && position < $0.end })
    }
    
    public mutating func removeAll() -> [HLSSegmentKey] {
        let keys = self.parts.map(\.key)
        self.parts.removeAll()
        return keys
    }
    
    // Parts that end after `position`, the part at the playhead included.
    public mutating func removeForward(from position: Double) -> [HLSSegmentKey] {
        let removed = self.parts.filter({ $0.end > position }).map(\.key)
        self.parts.removeAll(where: { $0.end > position })
        return removed
    }
    
    // hls.js's back-buffer trim: everything ending before floor(position / td) * td - max(backBuffer, td), so the
    // boundary moves once per segment rather than with every position update.
    public mutating func trimBackBuffer(position: Double, segmentDuration: Double, backBuffer: Double) -> [HLSSegmentKey] {
        if segmentDuration <= 0.0 || !segmentDuration.isFinite {
            return []
        }
        let target = floor(position / segmentDuration) * segmentDuration - max(backBuffer, segmentDuration)
        if target <= 0.0 {
            return []
        }
        let removed = self.parts.filter({ $0.end <= target }).map(\.key)
        self.parts.removeAll(where: { $0.end <= target })
        return removed
    }
}
