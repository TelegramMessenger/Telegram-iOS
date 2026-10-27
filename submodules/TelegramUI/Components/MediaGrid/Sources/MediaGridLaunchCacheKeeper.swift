import Foundation
import CoreGraphics
import QuartzCore

public final class MediaGridLaunchCacheKeeper {
    public typealias Key = MediaGridLaunchCache.Key

    static let settleDelay: Double = 1.0
    static let enlargementFloor: CGFloat = 0.7

    public let cache: MediaGridLaunchCache
    public private(set) var head: [Key] = []
    public private(set) var images: [Int: MediaGridLaunchImage] = [:]
    public private(set) var isReleased = false
    public private(set) var isAtTop = true
    public private(set) var refreshCount = 0
    private var delivered: [String: MediaGridLaunchCache.Delivered] = [:]
    private var generation = 0
    public var schedule: (Double, @escaping () -> Void) -> Void = { delay, block in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }
    public var onRefresh: ((Bool) -> Void)?

    public init(cache: MediaGridLaunchCache) {
        self.cache = cache
    }

    public var capacity: Int {
        return self.cache.capacity
    }

    public func install(head: [Key], images: [Int: MediaGridLaunchImage]) {
        self.head = Array(head.prefix(self.capacity))
        self.images = self.isReleased ? [:] : images
    }

    public func setHead(_ head: [Key]) {
        let head = Array(head.prefix(self.capacity))
        guard head != self.head else {
            return
        }
        self.head = head
        if !self.isReleased {
            var images: [Int: MediaGridLaunchImage] = [:]
            for (index, key) in head.enumerated() {
                if let image = self.cache.launchImage(for: key.id, version: key.version) {
                    images[index] = image
                }
            }
            self.images = images
        }
        self.scheduleRefresh()
    }

    public static func coverage(of image: CGImage) -> Int {
        return min(image.width, image.height)
    }

    public func targetSize(at index: Int, pixelSize: CGSize) -> CGSize {
        let launch = CGFloat(self.cache.pixelSize)
        let side = min(pixelSize.width, pixelSize.height)
        guard index >= 0, index < self.capacity, side > 0.0, side < launch, side >= MediaGridLaunchCacheKeeper.enlargementFloor * launch else {
            return pixelSize
        }
        let scale = launch / side
        return CGSize(width: (pixelSize.width * scale).rounded(.up), height: (pixelSize.height * scale).rounded(.up))
    }

    public func delivered(id: String, image: CGImage) {
        guard let index = self.head.firstIndex(where: { $0.id == id }) else {
            return
        }
        let version = self.head[index].version
        let delivery = MediaGridLaunchCache.Delivered(version: version, image: image, coverage: MediaGridLaunchCacheKeeper.coverage(of: image))
        if let current = self.delivered[id], current.version == version, !delivery.isBetter(than: current) {
            return
        }
        self.delivered[id] = delivery
        if self.images.removeValue(forKey: index) != nil {
            self.cache.releaseImages(ids: [id])
        }
        self.scheduleRefresh()
    }

    public func viewportChanged(lowerBound: Int) {
        let isAtTop = lowerBound <= 0
        if lowerBound >= self.capacity && !self.isReleased {
            self.isReleased = true
            self.images = [:]
            self.cache.releaseImages()
        }
        if isAtTop != self.isAtTop {
            self.isAtTop = isAtTop
            if isAtTop {
                self.scheduleRefresh()
            }
        }
    }

    public func scheduleRefresh() {
        self.generation += 1
        let generation = self.generation
        self.schedule(MediaGridLaunchCacheKeeper.settleDelay) { [weak self] in
            guard let self, self.generation == generation else {
                return
            }
            self.refreshIfResting()
        }
    }

    public func refreshIfResting() {
        guard self.isAtTop, !self.head.isEmpty else {
            return
        }
        let current = Set(self.head.map { $0.id })
        self.delivered = self.delivered.filter { current.contains($0.key) }
        self.refreshCount += 1
        let onRefresh = self.onRefresh
        let delivered = self.delivered
        self.delivered = [:]
        self.cache.update(head: self.head, delivered: delivered, completion: { written in
            DispatchQueue.main.async {
                onRefresh?(written)
            }
        })
    }
}

public final class MediaGridLaunchMatch {
    public typealias Key = MediaGridLaunchCache.Key

    public struct Result {
        public let head: [Key]?
        public let images: [Int: MediaGridLaunchImage]
        public let duration: CFTimeInterval
    }

    public let cache: MediaGridLaunchCache
    private let lock = NSLock()
    private let resultGroup = DispatchGroup()
    private let headGroup = DispatchGroup()
    private var storedResult: Result?
    private var storedHead: [Key]?

    public static let defaultQueue = DispatchQueue(label: "org.telegram.MediaGrid.launchMatch", qos: .userInteractive)

    public init(cache: MediaGridLaunchCache, queue: DispatchQueue = MediaGridLaunchMatch.defaultQueue, readHead: @escaping () -> [Key]) {
        self.cache = cache
        self.resultGroup.enter()
        self.headGroup.enter()
        let start = CACurrentMediaTime()
        cache.startLoading()
        queue.async {
            cache.load()
            if cache.storedKeys.isEmpty {
                self.publish(Result(head: nil, images: [:], duration: CACurrentMediaTime() - start))
                self.publish(head: readHead())
                return
            }
            let head = readHead()
            let images = cache.images(matching: head)
            self.publish(Result(head: head, images: images, duration: CACurrentMediaTime() - start))
            self.publish(head: head)
        }
    }

    private func publish(_ result: Result) {
        self.lock.lock()
        self.storedResult = result
        self.lock.unlock()
        self.resultGroup.leave()
    }

    private func publish(head: [Key]) {
        self.lock.lock()
        self.storedHead = head
        self.lock.unlock()
        self.headGroup.leave()
    }

    public var result: Result? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.storedResult
    }

    public var head: [Key]? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.storedHead
    }

    public func wait(timeout: TimeInterval) -> Result? {
        guard self.resultGroup.wait(timeout: .now() + timeout) == .success else {
            return nil
        }
        return self.result
    }

    public func notifyResult(queue: DispatchQueue, _ block: @escaping (Result) -> Void) {
        self.resultGroup.notify(queue: queue) { [self] in
            if let result = self.result {
                block(result)
            }
        }
    }

    public func notifyHead(queue: DispatchQueue, _ block: @escaping ([Key]) -> Void) {
        self.headGroup.notify(queue: queue) { [self] in
            if let head = self.head {
                block(head)
            }
        }
    }
}
