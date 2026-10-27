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
    var holdsDeliveries = false
    var deliversAfterCancel = false
    var imageForIndex: ((Int) -> UIImage)?
    var aspectRatios: [CGFloat]?
    var providesThumbnails = false
    var thumbnailAvailable: ((Int) -> Bool)?
    private(set) var preparedRanges: [Range<Int>] = []
    private(set) var events: [String] = []
    private(set) var requests: [(index: Int, pixelSize: CGSize)] = []
    private(set) var startedCachingOrder: [[Int]] = []
    private(set) var pixelSizes: [(index: Int, size: CGSize)] = []
    private(set) var batchDepth = 0
    private(set) var batchedRequests = 0
    private(set) var cachingPixelSizes: [CGSize] = []
    private var held: [(index: Int, deliver: () -> Void)] = []

    static let thumbnailPageSide = 16
    static let thumbnailSlotPixelSize = 48

    static let thumbnailPage: CGImage = {
        let size = TestDataSource.thumbnailPageSide * TestDataSource.thumbnailSlotPixelSize
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        context.setFillColor(UIColor.red.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return context.makeImage()!
    }()

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

    func aspectRatioReader() -> MediaGridAspectRatioReader {
        let aspectRatios = self.aspectRatios
        return { index in
            guard let aspectRatios, index >= 0, index < aspectRatios.count else {
                return 1.0
            }
            return aspectRatios[index]
        }
    }

    func thumbnail(at index: Int) -> MediaGridThumbnail? {
        guard self.providesThumbnails, index >= 0, index < self.count, self.thumbnailAvailable?(index) ?? true else {
            return nil
        }
        let side = CGFloat(TestDataSource.thumbnailSlotPixelSize)
        let pageSize = CGFloat(TestDataSource.thumbnailPageSide) * side
        let slot = index % (TestDataSource.thumbnailPageSide * TestDataSource.thumbnailPageSide)
        var aspect: CGFloat = 1.0
        if let aspectRatios = self.aspectRatios, index < aspectRatios.count {
            aspect = min(2.0, max(0.5, aspectRatios[index]))
        }
        let width = aspect >= 1.0 ? side : (side * aspect).rounded()
        let height = aspect >= 1.0 ? (side / aspect).rounded() : side
        let x = CGFloat(slot % TestDataSource.thumbnailPageSide) * side + ((side - width) / 2.0).rounded(.down)
        let y = CGFloat(slot / TestDataSource.thumbnailPageSide) * side + ((side - height) / 2.0).rounded(.down)
        return MediaGridThumbnail(image: TestDataSource.thumbnailPage, contentsRect: CGRect(x: x / pageSize, y: y / pageSize, width: width / pageSize, height: height / pageSize))
    }

    func prepareThumbnails(indices: Range<Int>) {
        self.preparedRanges.append(indices)
    }

    func resetPreparedRanges() {
        self.preparedRanges = []
    }

    func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        self.requestCount += 1
        self.requests.append((index, pixelSize))
        self.pixelSizes.append((index, pixelSize))
        if self.batchDepth > 0 {
            self.batchedRequests += 1
        }
        self.events.append("request \(index)")
        var deliveries = self.deliveries ?? [(TestDataSource.image, false)]
        if let imageForIndex = self.imageForIndex {
            deliveries = [(imageForIndex(index), false)]
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
            self.held.append((index, deliver))
        } else {
            deliver()
        }
        return request
    }

    func flushHeldDeliveries(where predicate: (Int) -> Bool = { _ in true }) {
        let held = self.held
        self.held = held.filter { !predicate($0.index) }
        for entry in held where predicate(entry.index) {
            entry.deliver()
        }
    }

    static func distinctImage(_ value: Int, side: CGFloat = 2.0) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor(white: CGFloat(value % 256) / 255.0, alpha: 1.0).setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: side, height: side))
        }
    }

    func performBatch(_ updates: () -> Void) {
        self.batchDepth += 1
        updates()
        self.batchDepth -= 1
    }

    func startCaching(indices: [Int], pixelSize: CGSize) {
        self.cachingPixelSizes.append(pixelSize)
        self.startedCachingOrder.append(indices)
        self.cachedIndices.formUnion(indices)
    }

    func stopCaching(indices: [Int], pixelSize: CGSize) {
        self.cachedIndices.subtract(indices)
    }

    static var sampleImage: UIImage {
        return TestDataSource.image
    }
}
