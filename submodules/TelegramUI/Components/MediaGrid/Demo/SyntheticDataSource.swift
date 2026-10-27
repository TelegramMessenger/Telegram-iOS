import UIKit
import MediaGrid

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        self.state = self.state &+ 0x9E3779B97F4A7C15
        var z = self.state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private final class SyntheticImageRequest: MediaGridImageRequest {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.cancelled
    }

    func cancel() {
        self.lock.lock()
        self.cancelled = true
        self.lock.unlock()
    }
}

final class SyntheticDataSource: MediaGridDataSource {
    let count: Int
    private let dates: [Date]
    private let aspects: [CGFloat]
    private let queue = DispatchQueue(label: "org.telegram.MediaGridDemo.SyntheticDataSource", qos: .userInitiated)
    private let cache = NSCache<NSString, UIImage>()
    var onThumbnailsChanged: ((IndexSet) -> Void)?
    var providesThumbnails = true
    private static let slotPixelSize = 48
    private static let pageSide = 16
    private static let slotsPerPage = SyntheticDataSource.pageSide * SyntheticDataSource.pageSide
    private static let pagePixelSize = SyntheticDataSource.pageSide * SyntheticDataSource.slotPixelSize
    private static let pageBudget = 32
    private static let maxConcurrentRenders = 2
    private let pageQueue = DispatchQueue(label: "org.telegram.MediaGridDemo.SyntheticPages", qos: .userInitiated, attributes: .concurrent)
    private var pages: [Int: CGImage] = [:]
    private var pageUses: [Int: Int] = [:]
    private var useTick = 0
    private var renderStack: [Int] = []
    private var rendersInFlight = Set<Int>()
    private var preparedPageList: [Int] = []
    private var lastPage: (page: Int, image: CGImage)?
    private var lastTouchedPage: Int?

    init(count: Int = 100_000, seed: UInt64 = 1) {
        self.count = count
        var generator = SeededGenerator(state: seed)
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 1
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var time = calendar.date(from: components)!.timeIntervalSince1970
        let choices: [CGFloat] = [0.3, 0.5, 0.75, 1.0, 1.33, 1.78, 3.0]
        var dates: [Date] = []
        var aspects: [CGFloat] = []
        dates.reserveCapacity(count)
        aspects.reserveCapacity(count)
        for _ in 0 ..< count {
            dates.append(Date(timeIntervalSince1970: time))
            time -= Double.random(in: 0.0 ... 36.0 * 3600.0, using: &generator)
            aspects.append(choices[Int.random(in: 0 ..< choices.count, using: &generator)])
        }
        self.dates = dates
        self.aspects = aspects
        self.cache.countLimit = 2000
    }

    func date(at index: Int) -> Date? {
        guard index >= 0, index < self.count else {
            return nil
        }
        return self.dates[index]
    }

    func aspectRatioReader() -> MediaGridAspectRatioReader {
        let aspects = self.aspects
        return { index in
            guard index >= 0, index < aspects.count else {
                return 1.0
            }
            return aspects[index]
        }
    }

    func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        let key = "\(index)-\(Int(pixelSize.width))x\(Int(pixelSize.height))" as NSString
        if let image = self.cache.object(forKey: key) {
            completion(image, false)
            return nil
        }
        let request = SyntheticImageRequest()
        self.queue.async { [weak self] in
            guard let self, !request.isCancelled else {
                return
            }
            let image = SyntheticDataSource.render(index: index, pixelSize: pixelSize)
            self.cache.setObject(image, forKey: key)
            DispatchQueue.main.async {
                if !request.isCancelled {
                    completion(image, false)
                }
            }
        }
        return request
    }

    func startCaching(indices: [Int], pixelSize: CGSize) {
    }

    func stopCaching(indices: [Int], pixelSize: CGSize) {
    }

    func thumbnail(at index: Int) -> MediaGridThumbnail? {
        guard self.providesThumbnails, index >= 0, index < self.count else {
            return nil
        }
        let page = index / SyntheticDataSource.slotsPerPage
        let image: CGImage
        if let lastPage = self.lastPage, lastPage.page == page {
            image = lastPage.image
        } else {
            guard let found = self.pages[page] else {
                return nil
            }
            image = found
            self.lastPage = (page, found)
        }
        self.touch(page: page)
        let rect = SyntheticDataSource.drawnRect(slot: index % SyntheticDataSource.slotsPerPage, aspect: self.aspects[index])
        let size = CGFloat(SyntheticDataSource.pagePixelSize)
        return MediaGridThumbnail(image: image, contentsRect: CGRect(x: rect.minX / size, y: rect.minY / size, width: rect.width / size, height: rect.height / size))
    }

    func prepareThumbnails(ranges: [Range<Int>]) {
        guard self.providesThumbnails else {
            return
        }
        var seen = Set<Int>()
        var pages: [Int] = []
        outer: for range in ranges {
            let clamped = range.clamped(to: 0 ..< self.count)
            guard !clamped.isEmpty else {
                continue
            }
            for page in clamped.lowerBound / SyntheticDataSource.slotsPerPage ... (clamped.upperBound - 1) / SyntheticDataSource.slotsPerPage where seen.insert(page).inserted {
                pages.append(page)
                if pages.count >= SyntheticDataSource.pageBudget {
                    break outer
                }
            }
        }
        if pages == self.preparedPageList && pages.allSatisfy({ self.pages[$0] != nil || self.rendersInFlight.contains($0) || self.renderStack.contains($0) }) {
            return
        }
        self.preparedPageList = pages
        for page in pages.reversed() where self.pages[page] != nil {
            self.touch(page: page)
        }
        self.renderStack = pages.reversed().filter { self.pages[$0] == nil && !self.rendersInFlight.contains($0) }
        self.startRenders()
    }

    private func touch(page: Int) {
        if self.lastTouchedPage == page {
            return
        }
        self.lastTouchedPage = page
        self.useTick += 1
        self.pageUses[page] = self.useTick
    }

    private func startRenders() {
        while self.rendersInFlight.count < SyntheticDataSource.maxConcurrentRenders, let page = self.renderStack.popLast() {
            if self.pages[page] != nil || self.rendersInFlight.contains(page) {
                continue
            }
            self.rendersInFlight.insert(page)
            let aspects = self.aspects
            let count = self.count
            self.pageQueue.async { [weak self] in
                let image = SyntheticDataSource.renderPage(page, aspects: aspects, count: count)
                DispatchQueue.main.async {
                    self?.install(page: page, image: image)
                }
            }
        }
    }

    private func install(page: Int, image: CGImage?) {
        self.rendersInFlight.remove(page)
        if let image {
            self.pages[page] = image
            self.touch(page: page)
            if self.pages.count > SyntheticDataSource.pageBudget {
                let victims = self.pages.keys.filter { $0 != page }.sorted { (self.pageUses[$0] ?? 0) < (self.pageUses[$1] ?? 0) }
                for victim in victims.prefix(self.pages.count - SyntheticDataSource.pageBudget) {
                    self.pages.removeValue(forKey: victim)
                    self.pageUses.removeValue(forKey: victim)
                    if self.lastPage?.page == victim {
                        self.lastPage = nil
                    }
                    if self.lastTouchedPage == victim {
                        self.lastTouchedPage = nil
                    }
                }
            }
            let lower = page * SyntheticDataSource.slotsPerPage
            self.onThumbnailsChanged?(IndexSet(integersIn: lower ..< min(self.count, lower + SyntheticDataSource.slotsPerPage)))
        }
        self.startRenders()
    }

    private static func drawnRect(slot: Int, aspect: CGFloat) -> CGRect {
        let side = CGFloat(SyntheticDataSource.slotPixelSize)
        let clamped = min(2.0, max(0.5, aspect))
        let width = clamped >= 1.0 ? side : (side * clamped).rounded()
        let height = clamped >= 1.0 ? (side / clamped).rounded() : side
        let x = CGFloat(slot % SyntheticDataSource.pageSide) * side + ((side - width) / 2.0).rounded(.down)
        let y = CGFloat(slot / SyntheticDataSource.pageSide) * side + ((side - height) / 2.0).rounded(.down)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func renderPage(_ page: Int, aspects: [CGFloat], count: Int) -> CGImage? {
        let size = SyntheticDataSource.pagePixelSize
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }
        context.translateBy(x: 0.0, y: CGFloat(size))
        context.scaleBy(x: 1.0, y: -1.0)
        let side = CGFloat(SyntheticDataSource.slotPixelSize)
        for slot in 0 ..< SyntheticDataSource.slotsPerPage {
            let index = page * SyntheticDataSource.slotsPerPage + slot
            guard index < count else {
                break
            }
            let hue = CGFloat((Double(index) * 0.618033988749895).truncatingRemainder(dividingBy: 1.0))
            context.setFillColor(UIColor(hue: hue, saturation: 0.5, brightness: 0.85, alpha: 1.0).cgColor)
            context.fill(CGRect(x: CGFloat(slot % SyntheticDataSource.pageSide) * side, y: CGFloat(slot / SyntheticDataSource.pageSide) * side, width: side, height: side))
            let rect = SyntheticDataSource.drawnRect(slot: slot, aspect: aspects[index])
            context.setFillColor(UIColor(white: 1.0, alpha: 0.5).cgColor)
            context.fill(CGRect(x: rect.midX - 6.0, y: rect.midY - 3.0, width: 12.0, height: 6.0))
        }
        return context.makeImage()
    }

    private static func render(index: Int, pixelSize: CGSize) -> UIImage {
        let size = CGSize(width: max(1.0, pixelSize.width), height: max(1.0, pixelSize.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let hue = CGFloat((Double(index) * 0.618033988749895).truncatingRemainder(dividingBy: 1.0))
        let color = UIColor(hue: hue, saturation: 0.5, brightness: 0.85, alpha: 1.0)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let text = "\(index)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: max(6.0, size.width / 6.0), weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2.0, y: (size.height - textSize.height) / 2.0), withAttributes: attributes)
        }
    }
}
