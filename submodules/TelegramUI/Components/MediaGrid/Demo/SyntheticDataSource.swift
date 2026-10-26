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

    func aspectRatio(at index: Int) -> CGFloat {
        guard index >= 0, index < self.count else {
            return 1.0
        }
        return self.aspects[index]
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
