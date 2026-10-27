import Foundation
import CoreGraphics

public struct MediaGridPrefetchPlan: Equatable {
    public var start: [Int]
    public var stop: [Int]

    public init(start: [Int], stop: [Int]) {
        self.start = start
        self.stop = stop
    }
}

public struct MediaGridPrefetchPlanner {
    public var screensAhead: CGFloat
    private var cached: [Range<Int>] = []
    private var previousOffset: CGFloat?
    private var movingUp = false

    public init(screensAhead: CGFloat = 2.0) {
        self.screensAhead = screensAhead
    }

    public var cachedIndices: [Int] {
        return MediaGridPrefetchPlanner.flatten(self.cached)
    }

    public mutating func reset() -> [Int] {
        let stale = self.cachedIndices
        self.cached = []
        self.previousOffset = nil
        self.movingUp = false
        return stale
    }

    public mutating func apply(_ changes: MediaGridChanges) {
        var ranges: [Range<Int>] = []
        for index in self.cachedIndices {
            guard let newIndex = changes.newIndex(forOld: index), !changes.changed.contains(newIndex) else {
                continue
            }
            if let last = ranges.last, last.upperBound == newIndex {
                ranges[ranges.count - 1] = last.lowerBound ..< newIndex + 1
            } else {
                ranges.append(newIndex ..< newIndex + 1)
            }
        }
        self.cached = ranges
        self.previousOffset = nil
    }

    public mutating func update(layout: MediaGridLayout, viewportHeight: CGFloat, offset: CGFloat, settledOffset: CGFloat?) -> MediaGridPrefetchPlan {
        guard offset.isFinite, viewportHeight.isFinite, viewportHeight > 0.0, layout.count > 0 else {
            let stale = self.reset()
            return MediaGridPrefetchPlan(start: [], stop: stale)
        }
        if let previous = self.previousOffset, offset != previous {
            self.movingUp = offset < previous
        }
        self.previousOffset = offset
        let movingUp = self.movingUp

        let ahead = max(0.0, self.screensAhead) * viewportHeight
        var windows: [Range<Int>] = []
        let mainY = movingUp ? offset - ahead : offset
        windows.append(layout.indexRange(intersecting: CGRect(x: 0.0, y: mainY, width: 1.0, height: viewportHeight + ahead)))
        if let settledOffset, settledOffset.isFinite {
            windows.append(layout.indexRange(intersecting: CGRect(x: 0.0, y: settledOffset - viewportHeight, width: 1.0, height: viewportHeight * 3.0)))
        }
        let window = MediaGridPrefetchPlanner.normalize(windows)

        let start = MediaGridPrefetchPlanner.subtract(window, minus: self.cached)
        let stop = MediaGridPrefetchPlanner.subtract(self.cached, minus: window)
        self.cached = window
        return MediaGridPrefetchPlan(start: MediaGridPrefetchPlanner.flatten(start), stop: MediaGridPrefetchPlanner.flatten(stop))
    }

    private static func normalize(_ ranges: [Range<Int>]) -> [Range<Int>] {
        let sorted = ranges.filter { !$0.isEmpty }.sorted { $0.lowerBound < $1.lowerBound }
        var result: [Range<Int>] = []
        for range in sorted {
            if let last = result.last, range.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound ..< max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }

    private static func subtract(_ ranges: [Range<Int>], minus: [Range<Int>]) -> [Range<Int>] {
        var result: [Range<Int>] = []
        for range in ranges {
            var lower = range.lowerBound
            for cut in minus {
                if cut.upperBound <= lower {
                    continue
                }
                if cut.lowerBound >= range.upperBound {
                    break
                }
                if cut.lowerBound > lower {
                    result.append(lower ..< cut.lowerBound)
                }
                lower = max(lower, cut.upperBound)
                if lower >= range.upperBound {
                    break
                }
            }
            if lower < range.upperBound {
                result.append(lower ..< range.upperBound)
            }
        }
        return result
    }

    private static func flatten(_ ranges: [Range<Int>]) -> [Int] {
        var result: [Int] = []
        for range in ranges {
            result.append(contentsOf: range)
        }
        return result
    }
}
