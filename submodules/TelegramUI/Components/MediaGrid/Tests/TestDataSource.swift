import UIKit
@testable import MediaGrid

final class TestImageRequest: MediaGridImageRequest {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        self.onCancel()
    }
}

final class TestDataSource: MediaGridDataSource {
    var count: Int
    private(set) var requestCount = 0
    private(set) var cancelCount = 0
    private(set) var cachedIndices: Set<Int> = []
    var deliveries: [(UIImage?, Bool)]?

    private static let image: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: CGSize(width: 1.0, height: 1.0), format: format).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
        }
    }()

    init(count: Int) {
        self.count = count
    }

    func date(at index: Int) -> Date? {
        return Date(timeIntervalSince1970: 1_600_000_000 - Double(index) * 3600.0)
    }

    func aspectRatio(at index: Int) -> CGFloat {
        return 1.0
    }

    func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        self.requestCount += 1
        if let deliveries = self.deliveries {
            for (image, isDegraded) in deliveries {
                completion(image, isDegraded)
            }
        } else {
            completion(TestDataSource.image, false)
        }
        return TestImageRequest(onCancel: { [weak self] in
            self?.cancelCount += 1
        })
    }

    func startCaching(indices: [Int], pixelSize: CGSize) {
        self.cachedIndices.formUnion(indices)
    }

    func stopCaching(indices: [Int], pixelSize: CGSize) {
        self.cachedIndices.subtract(indices)
    }

    static var sampleImage: UIImage {
        return TestDataSource.image
    }
}
