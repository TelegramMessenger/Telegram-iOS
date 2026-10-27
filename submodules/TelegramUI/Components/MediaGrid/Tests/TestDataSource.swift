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
    var deliversAfterCancel = false
    var imageForIndex: ((Int, MediaGridImageQuality) -> UIImage)?
    private(set) var events: [String] = []
    private(set) var requests: [(index: Int, quality: MediaGridImageQuality)] = []
    private(set) var cachingQualities: [MediaGridImageQuality] = []
    private(set) var startedCachingOrder: [[Int]] = []
    private var held: [(index: Int, quality: MediaGridImageQuality, deliver: () -> Void)] = []

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
        self.events.append("request \(index)")
        var deliveries = self.deliveriesByQuality[quality] ?? self.deliveries ?? [(TestDataSource.image, false)]
        if let imageForIndex = self.imageForIndex {
            deliveries = [(imageForIndex(index, quality), quality == .fast)]
        }
        var cancelled = false
        let request = TestImageRequest(onCancel: { [weak self] in
            cancelled = true
            self?.cancelCount += 1
            self?.events.append("cancel \(index)")
        })
        let deliversAfterCancel = self.deliversAfterCancel
        let deliver = {
            if cancelled && !deliversAfterCancel {
                return
            }
            for (image, isDegraded) in deliveries {
                completion(image, isDegraded)
            }
        }
        if self.holdsDeliveries {
            self.held.append((index, quality, deliver))
        } else {
            deliver()
        }
        return request
    }

    func flushHeldDeliveries(where predicate: (Int, MediaGridImageQuality) -> Bool = { _, _ in true }) {
        let held = self.held
        self.held = held.filter { !predicate($0.index, $0.quality) }
        for entry in held where predicate(entry.index, entry.quality) {
            entry.deliver()
        }
    }

    static func distinctImage(_ value: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: CGSize(width: 2.0, height: 2.0), format: format).image { context in
            UIColor(white: CGFloat(value % 256) / 255.0, alpha: 1.0).setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 2.0, height: 2.0))
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
