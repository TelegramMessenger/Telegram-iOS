import Foundation
import CoreGraphics

public final class MediaGridAspectIndex {
    private final class Cancellation {
        private let lock = NSLock()
        private var cancelled = false

        var isCancelled: Bool {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            return self.cancelled
        }

        func cancel() {
            self.lock.lock()
            self.cancelled = true
            self.lock.unlock()
        }
    }

    private let count: Int
    private let aspectRatio: (Int) -> CGFloat
    private let aspects: [Float]?
    private let cancellation = Cancellation()

    public init(count: Int, aspectRatio: @escaping (Int) -> CGFloat) {
        self.count = max(0, count)
        self.aspectRatio = aspectRatio
        self.aspects = nil
    }

    public init(aspects: [Float]) {
        self.count = aspects.count
        self.aspectRatio = { index in
            return CGFloat(aspects[index])
        }
        self.aspects = aspects
    }

    public func apply(_ changes: MediaGridChanges, aspectRatio: (Int) -> CGFloat) -> [Float] {
        return self.apply([changes], aspectRatio: aspectRatio)
    }

    public func apply(_ changes: [MediaGridChanges], aspectRatio: (Int) -> CGFloat) -> [Float] {
        var aspects = self.aspects ?? (0 ..< self.count).map { Float(MediaGridAspectIndex.clamp(self.aspectRatio($0))) }
        for change in changes {
            aspects = MediaGridAspectIndex.marking(change, in: aspects)
        }
        for index in aspects.indices where aspects[index].isNaN {
            aspects[index] = Float(MediaGridAspectIndex.clamp(aspectRatio(index)))
        }
        return aspects
    }

    public func build(applying changes: [MediaGridChanges], aspectRatio: @escaping (Int) -> CGFloat, completion: @escaping ([Float]) -> Void) {
        let cancellation = self.cancellation
        DispatchQueue.global(qos: .userInitiated).async {
            if cancellation.isCancelled {
                return
            }
            let aspects = self.apply(changes, aspectRatio: aspectRatio)
            DispatchQueue.main.async {
                if !cancellation.isCancelled {
                    completion(aspects)
                }
            }
        }
    }

    private static func marking(_ changes: MediaGridChanges, in aspects: [Float]) -> [Float] {
        let newCount = aspects.count - changes.removed.count + changes.inserted.count
        precondition(changes.isValid(oldCount: aspects.count, newCount: newCount))
        var result: [Float] = []
        result.reserveCapacity(newCount)
        var removed = changes.removed.rangeView.makeIterator()
        var nextRemoved = removed.next()
        var inserted = changes.inserted.rangeView.makeIterator()
        var nextInserted = inserted.next()
        var oldIndex = 0
        while result.count < newCount {
            if let range = nextInserted, range.lowerBound == result.count {
                result.append(contentsOf: repeatElement(Float.nan, count: range.count))
                nextInserted = inserted.next()
                continue
            }
            if let range = nextRemoved, range.lowerBound == oldIndex {
                oldIndex = range.upperBound
                nextRemoved = removed.next()
                continue
            }
            let upper = min(nextRemoved?.lowerBound ?? aspects.count, oldIndex + (nextInserted?.lowerBound ?? newCount) - result.count)
            precondition(upper > oldIndex)
            result.append(contentsOf: aspects[oldIndex ..< upper])
            oldIndex = upper
        }
        for index in changes.changed {
            result[index] = .nan
        }
        return result
    }

    public func build(completion: @escaping ([Float]) -> Void) {
        let count = self.count
        let aspectRatio = self.aspectRatio
        let cancellation = self.cancellation
        DispatchQueue.global(qos: .userInitiated).async {
            var aspects = [Float](repeating: 1.0, count: count)
            for index in 0 ..< count {
                if index % 256 == 0 && cancellation.isCancelled {
                    return
                }
                aspects[index] = Float(MediaGridAspectIndex.clamp(aspectRatio(index)))
            }
            DispatchQueue.main.async {
                if !cancellation.isCancelled {
                    completion(aspects)
                }
            }
        }
    }

    public func cancel() {
        self.cancellation.cancel()
    }

    public static let minAspect: CGFloat = 0.5
    public static let maxAspect: CGFloat = 2.0

    public static func clamp(_ aspect: CGFloat) -> CGFloat {
        guard aspect.isFinite, aspect > 0.0 else {
            return 1.0
        }
        return min(MediaGridAspectIndex.maxAspect, max(MediaGridAspectIndex.minAspect, aspect))
    }
}
