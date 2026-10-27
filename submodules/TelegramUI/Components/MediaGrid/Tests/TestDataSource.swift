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
    private(set) var dateCalls: [Int: Int] = [:]
    var deliveries: [(UIImage?, Bool)]?
    var deliveriesByQuality: [MediaGridImageQuality: [(UIImage?, Bool)]] = [:]
    var holdsDeliveries = false
    private(set) var requests: [(index: Int, quality: MediaGridImageQuality)] = []
    private(set) var cachingQualities: [MediaGridImageQuality] = []
    private(set) var startedCachingOrder: [[Int]] = []
    private var held: [(TestImageRequest, () -> Void)] = []

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
        self.dateCalls[index, default: 0] += 1
        return Date(timeIntervalSince1970: 1_600_000_000 - Double(index) * 3600.0)
    }

    func aspectRatio(at index: Int) -> CGFloat {
        return 1.0
    }

    func requestImage(at index: Int, pixelSize: CGSize, quality: MediaGridImageQuality, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        self.requestCount += 1
        self.requests.append((index, quality))
        let deliveries = self.deliveriesByQuality[quality] ?? self.deliveries ?? [(TestDataSource.image, false)]
        var cancelled = false
        let request = TestImageRequest(onCancel: { [weak self] in
            cancelled = true
            self?.cancelCount += 1
        })
        let deliver = {
            if cancelled {
                return
            }
            for (image, isDegraded) in deliveries {
                completion(image, isDegraded)
            }
        }
        if self.holdsDeliveries {
            self.held.append((request, deliver))
        } else {
            deliver()
        }
        return request
    }

    func flushHeldDeliveries() {
        let held = self.held
        self.held = []
        for (_, deliver) in held {
            deliver()
        }
    }

    func startCaching(indices: [Int], pixelSize: CGSize, quality: MediaGridImageQuality) {
        self.cachingQualities.append(quality)
        self.startedCachingOrder.append(indices)
        self.cachedIndices.formUnion(indices)
    }

    func stopCaching(indices: [Int], pixelSize: CGSize, quality: MediaGridImageQuality) {
        self.cachedIndices.subtract(indices)
    }

    static var sampleImage: UIImage {
        return TestDataSource.image
    }
}
