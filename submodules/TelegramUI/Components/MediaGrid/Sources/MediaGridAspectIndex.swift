import Foundation
import CoreGraphics

public final class MediaGridAspectIndex {
    private let count: Int
    private let aspectRatio: (Int) -> CGFloat

    public init(count: Int, aspectRatio: @escaping (Int) -> CGFloat) {
        self.count = max(0, count)
        self.aspectRatio = aspectRatio
    }

    public func build(completion: @escaping ([Float]) -> Void) {
        let count = self.count
        let aspectRatio = self.aspectRatio
        DispatchQueue.global(qos: .userInitiated).async {
            var aspects = [Float](repeating: 1.0, count: count)
            for index in 0 ..< count {
                aspects[index] = Float(MediaGridAspectIndex.clamp(aspectRatio(index)))
            }
            DispatchQueue.main.async {
                completion(aspects)
            }
        }
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
