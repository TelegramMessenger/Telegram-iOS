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
    private let cancellation = Cancellation()

    public init(count: Int, aspectRatio: @escaping (Int) -> CGFloat) {
        self.count = max(0, count)
        self.aspectRatio = aspectRatio
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
