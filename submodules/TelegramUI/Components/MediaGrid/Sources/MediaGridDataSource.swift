import Foundation
import UIKit

public protocol MediaGridImageRequest: AnyObject {
    func cancel()
}

public typealias MediaGridAspectRatioReader = @Sendable (Int) -> CGFloat

public protocol MediaGridDataSource: AnyObject {
    var count: Int { get }
    func date(at index: Int) -> Date?
    func aspectRatioReader() -> MediaGridAspectRatioReader
    func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, _ isDegraded: Bool) -> Void) -> MediaGridImageRequest?
    func startCaching(indices: [Int], pixelSize: CGSize)
    func stopCaching(indices: [Int], pixelSize: CGSize)
    func performBatch(_ updates: () -> Void)
    func thumbnail(at index: Int) -> MediaGridThumbnail?
    func prepareThumbnails(ranges: [Range<Int>])
    func launchImage(at index: Int) -> MediaGridLaunchImage?
    func waitForLaunchImages(timeout: TimeInterval)
}

public extension MediaGridDataSource {
    func performBatch(_ updates: () -> Void) {
        updates()
    }

    func thumbnail(at index: Int) -> MediaGridThumbnail? {
        return nil
    }

    func prepareThumbnails(ranges: [Range<Int>]) {
    }

    func launchImage(at index: Int) -> MediaGridLaunchImage? {
        return nil
    }

    func waitForLaunchImages(timeout: TimeInterval) {
    }
}

public struct MediaGridChanges {
    public var removed: IndexSet
    public var inserted: IndexSet
    public var changed: IndexSet

    public init(removed: IndexSet, inserted: IndexSet, changed: IndexSet) {
        self.removed = removed
        self.inserted = inserted
        self.changed = changed
    }

    public var isEmpty: Bool {
        return self.removed.isEmpty && self.inserted.isEmpty && self.changed.isEmpty
    }

    public func isValid(oldCount: Int, newCount: Int) -> Bool {
        if oldCount < 0 || newCount < 0 || oldCount - self.removed.count + self.inserted.count != newCount {
            return false
        }
        if let first = self.removed.first, first < 0 {
            return false
        }
        if let last = self.removed.last, last >= oldCount {
            return false
        }
        if let first = self.inserted.first, first < 0 {
            return false
        }
        if let last = self.inserted.last, last >= newCount {
            return false
        }
        if let first = self.changed.first, first < 0 {
            return false
        }
        if let last = self.changed.last, last >= newCount {
            return false
        }
        return true
    }

    public func newIndex(forOld index: Int) -> Int? {
        if index < 0 || self.removed.contains(index) {
            return nil
        }
        var result = index - self.removed.count(in: 0 ..< index)
        for range in self.inserted.rangeView {
            if range.lowerBound <= result {
                result += range.count
            } else {
                break
            }
        }
        return result
    }

    func nearestSurvivor(toOld index: Int, oldCount: Int) -> Int? {
        guard index >= 0, index < oldCount else {
            return nil
        }
        guard let range = self.removed.rangeView.first(where: { $0.contains(index) }) else {
            return index
        }
        let before = range.lowerBound - 1
        let after = range.upperBound
        let hasBefore = before >= 0
        let hasAfter = after < oldCount
        if hasBefore && hasAfter {
            return index - before < after - index ? before : after
        }
        if hasAfter {
            return after
        }
        return hasBefore ? before : nil
    }
}
