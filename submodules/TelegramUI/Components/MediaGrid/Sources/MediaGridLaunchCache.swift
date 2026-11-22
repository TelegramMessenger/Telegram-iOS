import Foundation
import CoreGraphics
import ImageIO
import UIKit

public struct MediaGridLaunchImage {
    public let image: CGImage
    public let coveredPixelWidth: Int

    public init(image: CGImage, coveredPixelWidth: Int? = nil) {
        self.image = image
        self.coveredPixelWidth = max(coveredPixelWidth ?? 0, min(image.width, image.height))
    }

    public var pixelWidth: Int {
        return min(self.image.width, self.image.height)
    }
}

public final class MediaGridLaunchCache {
    public struct Key: Hashable {
        public var id: String
        public var version: String

        public init(id: String, version: String) {
            self.id = id
            self.version = version
        }
    }

    public struct Delivered {
        public var version: String
        public var image: CGImage
        public var coverage: Int

        public init(version: String, image: CGImage, coverage: Int? = nil) {
            self.version = version
            self.image = image
            self.coverage = max(coverage ?? 0, min(image.width, image.height))
        }

        public func isBetter(than other: Delivered) -> Bool {
            if self.coverage != other.coverage {
                return self.coverage > other.coverage
            }
            return min(self.image.width, self.image.height) > min(other.image.width, other.image.height)
        }
    }

    public struct Coverage: Equatable {
        public var capacity: Int
        public var pixelSize: Int
    }

    private struct StoredEntry: Codable {
        var id: String
        var version: String
        var pixelWidth: Int
        var coverage: Int
        var data: Data
    }

    private struct Container: Codable {
        var formatVersion: Int
        var entries: [StoredEntry]
    }

    private final class Entry {
        let stored: StoredEntry
        var image: CGImage?

        init(stored: StoredEntry, image: CGImage?) {
            self.stored = stored
            self.image = image
        }
    }

    private enum LoadState {
        case idle
        case loading
        case loaded
    }

    static let fileName = "launch.cache"
    static let directoryName = "launch"
    static let formatVersion = 2
    static let quality: CGFloat = 0.85

    public let capacity: Int
    public let pixelSize: Int
    private let fileURL: URL?
    private let condition = NSCondition()
    private var state = LoadState.idle
    private var order: [StoredEntry] = []
    private var entries: [String: Entry] = [:]
    private let ioQueue = DispatchQueue(label: "org.telegram.MediaGrid.launchCache", qos: .utility)
    private var measuredLoadDuration: CFTimeInterval = 0.0
    var willDecode: (() -> Void)?
    var willInstall: (() -> Void)?

    public static var defaultDirectory: URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MediaGridThumbnails", isDirectory: true).appendingPathComponent(MediaGridLaunchCache.directoryName, isDirectory: true)
    }

    public init(directory: URL?, capacity: Int, pixelSize: Int) {
        self.fileURL = directory?.appendingPathComponent(MediaGridLaunchCache.fileName)
        self.capacity = capacity
        self.pixelSize = pixelSize
    }

    public static func coverage(screenSize: CGSize, scale: CGFloat, spacing: CGFloat = 1.0, cellAspect: CGFloat = 1.0) -> Coverage {
        let short = min(screenSize.width, screenSize.height)
        let long = max(screenSize.width, screenSize.height)
        var capacity = 0
        var pixelSize = 0
        for isLandscape in [false, true] {
            let width = isLandscape ? long : short
            let height = isLandscape ? short : long
            let columns = MediaGridLevel.defaultLevel(isLandscape: isLandscape).columns
            let geometry = MediaGridGeometry(width: width, sideInset: 0.0, topInset: 0.0, bottomInset: 0.0, spacing: spacing, scale: scale)
            let layout = MediaGridUniformLayout(geometry: geometry, columns: columns, cellAspect: cellAspect, reservedSlots: [], count: 1)
            let rowHeight = layout.itemSize.height + spacing
            guard rowHeight > 0.0 else {
                continue
            }
            let rows = Int((height / rowHeight).rounded(.up)) + 1
            capacity = max(capacity, rows * columns)
            let size = layout.pixelSize(at: 0)
            pixelSize = max(pixelSize, Int(max(size.width, size.height).rounded(.up)))
        }
        return Coverage(capacity: capacity, pixelSize: pixelSize)
    }

    public func startLoading() {
        self.condition.lock()
        let isIdle = self.state == .idle
        self.condition.unlock()
        guard isIdle else {
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            self.load()
        }
    }

    public func load() {
        self.condition.lock()
        while self.state == .loading {
            self.condition.wait()
        }
        if self.state == .loaded {
            self.condition.unlock()
            return
        }
        self.state = .loading
        self.condition.unlock()

        let start = CACurrentMediaTime()
        var stored: [StoredEntry] = []
        if let url = self.fileURL, let data = try? Data(contentsOf: url), let container = try? PropertyListDecoder().decode(Container.self, from: data), container.formatVersion == MediaGridLaunchCache.formatVersion {
            stored = Array(container.entries.prefix(self.capacity))
        }
        self.willDecode?()
        var images = [CGImage?](repeating: nil, count: stored.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: stored.count) { index in
            let image = MediaGridLaunchCache.decode(stored[index].data, pixelWidth: stored[index].pixelWidth)
            lock.lock()
            images[index] = image
            lock.unlock()
        }
        var entries: [String: Entry] = [:]
        var order: [StoredEntry] = []
        for (index, entry) in stored.enumerated() {
            guard let image = images[index] else {
                continue
            }
            entries[entry.id] = Entry(stored: entry, image: image)
            order.append(entry)
        }
        let duration = CACurrentMediaTime() - start

        self.condition.lock()
        self.entries = entries
        self.order = order
        self.measuredLoadDuration = duration
        self.state = .loaded
        self.condition.broadcast()
        self.condition.unlock()
    }

    @discardableResult
    public func waitUntilLoaded(timeout: TimeInterval) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        while self.state != .loaded {
            if !self.condition.wait(until: deadline) {
                return self.state == .loaded
            }
        }
        return true
    }

    public var loadDuration: CFTimeInterval {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.measuredLoadDuration
    }

    public var isLoaded: Bool {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.state == .loaded
    }

    public var storedKeys: [Key] {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.order.map { Key(id: $0.id, version: $0.version) }
    }

    public var decodedImageCount: Int {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.entries.values.filter { $0.image != nil }.count
    }

    public func image(for id: String, version: String) -> CGImage? {
        return self.launchImage(for: id, version: version)?.image
    }

    public func launchImage(for id: String, version: String) -> MediaGridLaunchImage? {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        guard let entry = self.entries[id], entry.stored.version == version, let image = entry.image else {
            return nil
        }
        return MediaGridLaunchImage(image: image, coveredPixelWidth: entry.stored.coverage)
    }

    public func images(matching head: [Key]) -> [Int: MediaGridLaunchImage] {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        var result: [Int: MediaGridLaunchImage] = [:]
        for (index, key) in head.prefix(self.capacity).enumerated() {
            if let entry = self.entries[key.id], entry.stored.version == key.version, let image = entry.image {
                result[index] = MediaGridLaunchImage(image: image, coveredPixelWidth: entry.stored.coverage)
            }
        }
        return result
    }

    public func releaseImages(ids: [String]? = nil) {
        self.condition.lock()
        if let ids {
            for id in ids {
                self.entries[id]?.image = nil
            }
        } else {
            for entry in self.entries.values {
                entry.image = nil
            }
        }
        self.condition.unlock()
    }

    public func update(head: [Key], delivered: [String: Delivered], completion: ((Bool) -> Void)? = nil) {
        let head = Array(head.prefix(self.capacity))
        self.ioQueue.async {
            self.load()
            self.condition.lock()
            let current = self.entries
            let currentOrder = self.order
            self.condition.unlock()

            var result: [StoredEntry] = []
            var images: [String: CGImage] = [:]
            for key in head {
                let existing = current[key.id].flatMap { $0.stored.version == key.version ? $0 : nil }
                if let delivery = delivered[key.id], delivery.version == key.version, self.improves(delivery, on: existing?.stored), let prepared = MediaGridLaunchCache.prepare(delivery.image, pixelSize: self.pixelSize), let data = MediaGridLaunchCache.encode(prepared) {
                    let pixelWidth = min(prepared.width, prepared.height)
                    result.append(StoredEntry(id: key.id, version: key.version, pixelWidth: pixelWidth, coverage: max(pixelWidth, min(delivery.coverage, self.pixelSize)), data: data))
                } else if let existing {
                    result.append(existing.stored)
                    images[key.id] = existing.image
                }
            }
            let unchanged = result.count == currentOrder.count && zip(result, currentOrder).allSatisfy { $0.id == $1.id && $0.version == $1.version && $0.pixelWidth == $1.pixelWidth && $0.coverage == $1.coverage }
            if unchanged {
                completion?(false)
                return
            }
            var written = false
            if let url = self.fileURL {
                do {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let encoder = PropertyListEncoder()
                    encoder.outputFormat = .binary
                    try encoder.encode(Container(formatVersion: MediaGridLaunchCache.formatVersion, entries: result)).write(to: url, options: .atomic)
                    written = true
                } catch {
                    written = false
                }
            } else {
                written = true
            }
            self.willInstall?()
            self.condition.lock()
            var entries: [String: Entry] = [:]
            for entry in result {
                var image: CGImage?
                if let carried = images[entry.id], let live = self.entries[entry.id], live.stored.version == entry.version, live.image === carried {
                    image = carried
                }
                entries[entry.id] = Entry(stored: entry, image: image)
            }
            self.entries = entries
            self.order = result
            self.condition.unlock()
            completion?(written)
        }
    }

    public func flush(completion: @escaping () -> Void) {
        self.ioQueue.async {
            completion()
        }
    }

    private func improves(_ delivery: Delivered, on existing: StoredEntry?) -> Bool {
        guard let existing else {
            return true
        }
        let coverage = min(delivery.coverage, self.pixelSize)
        if coverage != existing.coverage {
            return coverage > existing.coverage
        }
        return min(self.pixelSize, min(delivery.image.width, delivery.image.height)) > existing.pixelWidth
    }

    static func prepare(_ image: CGImage, pixelSize: Int) -> CGImage? {
        let side = min(image.width, image.height)
        guard side > 0 else {
            return nil
        }
        let target = min(side, pixelSize)
        let scale = CGFloat(target) / CGFloat(side)
        let width = CGFloat(image.width) * scale
        let height = CGFloat(image.height) * scale
        guard let context = CGContext(data: nil, width: target, height: target, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: (CGFloat(target) - width) / 2.0, y: (CGFloat(target) - height) / 2.0, width: width, height: height))
        return context.makeImage()
    }

    static func encode(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: MediaGridLaunchCache.quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }

    static func decode(_ data: Data, pixelWidth: Int) -> CGImage? {
        guard !data.isEmpty, pixelWidth > 0, let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: pixelWidth, kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
}
