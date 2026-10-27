import UIKit
import MediaGrid

final class InstrumentedDataSource: MediaGridDataSource {
    struct Counters {
        var requests = 0
        var cancelledBeforeImage = 0
        var firstImages = 0
        var synchronousFirstImages = 0
        var firstImageLatencyTotal: Double = 0.0
        var firstImageLatencyWorst: Double = 0.0
        var cachingStarted = 0
        var cachingStopped = 0
        var cachingCallWorst: Double = 0.0
        var requestCallWorst: Double = 0.0
        var prepareCalls = 0
        var prepareCallTotal: Double = 0.0
        var prepareCallWorst: Double = 0.0
    }

    private final class Request: MediaGridImageRequest {
        weak var owner: InstrumentedDataSource?
        var inner: MediaGridImageRequest?
        var hasImage = false
        var isCancelled = false

        func cancel() {
            if !self.isCancelled {
                self.isCancelled = true
                if !self.hasImage {
                    self.owner?.counters.cancelledBeforeImage += 1
                }
            }
            self.inner?.cancel()
        }
    }

    let base: MediaGridDataSource
    var counters = Counters()
    var forwardsCaching = true
    var providesThumbnails = true

    init(base: MediaGridDataSource) {
        self.base = base
    }

    func resetCounters() {
        self.counters = Counters()
    }

    var count: Int {
        return self.base.count
    }

    func date(at index: Int) -> Date? {
        return self.base.date(at: index)
    }

    func aspectRatioReader() -> MediaGridAspectRatioReader {
        return self.base.aspectRatioReader()
    }

    func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        self.counters.requests += 1
        let request = Request()
        request.owner = self
        let start = CACurrentMediaTime()
        var isCalling = true
        request.inner = self.base.requestImage(at: index, pixelSize: pixelSize, completion: { [weak self, weak request] image, isDegraded in
            let deliver = {
                if let self, let request, image != nil, !request.hasImage, !request.isCancelled {
                    request.hasImage = true
                    let latency = CACurrentMediaTime() - start
                    self.counters.firstImages += 1
                    if isCalling {
                        self.counters.synchronousFirstImages += 1
                    }
                    self.counters.firstImageLatencyTotal += latency
                    self.counters.firstImageLatencyWorst = max(self.counters.firstImageLatencyWorst, latency)
                }
            }
            if Thread.isMainThread {
                deliver()
            } else {
                DispatchQueue.main.async(execute: deliver)
            }
            completion(image, isDegraded)
        })
        isCalling = false
        self.counters.requestCallWorst = max(self.counters.requestCallWorst, CACurrentMediaTime() - start)
        return request
    }

    func performBatch(_ updates: () -> Void) {
        self.base.performBatch(updates)
    }

    func thumbnail(at index: Int) -> MediaGridThumbnail? {
        guard self.providesThumbnails else {
            return nil
        }
        return self.base.thumbnail(at: index)
    }

    func prepareThumbnails(ranges: [Range<Int>]) {
        guard self.providesThumbnails else {
            return
        }
        let start = CACurrentMediaTime()
        self.base.prepareThumbnails(ranges: ranges)
        let duration = CACurrentMediaTime() - start
        self.counters.prepareCalls += 1
        self.counters.prepareCallTotal += duration
        self.counters.prepareCallWorst = max(self.counters.prepareCallWorst, duration)
    }

    func launchImage(at index: Int) -> MediaGridLaunchImage? {
        return self.base.launchImage(at: index)
    }

    func waitForLaunchImages(timeout: TimeInterval) {
        self.base.waitForLaunchImages(timeout: timeout)
    }

    func startCaching(indices: [Int], pixelSize: CGSize) {
        self.counters.cachingStarted += indices.count
        if self.forwardsCaching {
            let start = CACurrentMediaTime()
            self.base.startCaching(indices: indices, pixelSize: pixelSize)
            self.counters.cachingCallWorst = max(self.counters.cachingCallWorst, CACurrentMediaTime() - start)
        }
    }

    func stopCaching(indices: [Int], pixelSize: CGSize) {
        self.counters.cachingStopped += indices.count
        if self.forwardsCaching {
            let start = CACurrentMediaTime()
            self.base.stopCaching(indices: indices, pixelSize: pixelSize)
            self.counters.cachingCallWorst = max(self.counters.cachingCallWorst, CACurrentMediaTime() - start)
        }
    }
}
