import UIKit
import Photos
import MediaGrid

final class PhotoLibraryDataSource: MediaGridDataSource {
    private struct ImageKey: Hashable {
        var identifier: String
        var width: Int
        var height: Int

        var cacheKey: NSString {
            return "\(self.identifier)|\(self.width)x\(self.height)" as NSString
        }
    }

    private struct PrefetchKey: Hashable {
        var index: Int
        var width: Int
        var height: Int
    }

    private enum JobState {
        case pending
        case running
        case finished
    }

    private final class Consumer {
        let isReduced: Bool
        let completion: (UIImage?, Bool) -> Void

        init(isReduced: Bool, completion: @escaping (UIImage?, Bool) -> Void) {
            self.isReduced = isReduced
            self.completion = completion
        }
    }

    private final class Job {
        let key: ImageKey
        let asset: PHAsset
        let targetSize: CGSize
        var consumers: [ObjectIdentifier: Consumer] = [:]
        var isPrefetched = false
        var usesNetwork = false
        var state: JobState = .pending
        var requestId: PHImageRequestID?

        init(key: ImageKey, asset: PHAsset, targetSize: CGSize) {
            self.key = key
            self.asset = asset
            self.targetSize = targetSize
        }

        var isWanted: Bool {
            return !self.consumers.isEmpty || self.isPrefetched
        }
    }

    private final class Lane {
        let limit: Int
        let prefetchLimit: Int
        var running = 0
        var visible: [Job] = []
        var compactionThreshold = 512

        init(limit: Int, prefetchLimit: Int) {
            self.limit = limit
            self.prefetchLimit = prefetchLimit
        }
    }

    private final class Request: MediaGridImageRequest {
        weak var source: PhotoLibraryDataSource?
        let job: Job
        let consumer: Consumer

        init(source: PhotoLibraryDataSource, job: Job, consumer: Consumer) {
            self.source = source
            self.job = job
            self.consumer = consumer
        }

        func cancel() {
            self.source?.remove(self.consumer, from: self.job)
        }
    }

    static let fastMaxPixelSize: CGFloat = 128.0
    static let synchronousBudgetPerFrame: CFTimeInterval = 0.004
    static let fastFormatProbeLimit = 32

    private let fetchResult: PHFetchResult<PHAsset>
    private let manager = PHImageManager.default()
    private let cache = NSCache<NSString, UIImage>()
    private let localLane = Lane(limit: 12, prefetchLimit: 6)
    private let networkLane = Lane(limit: 4, prefetchLimit: 0)
    private var jobs: [ImageKey: Job] = [:]
    private var isUpdatingPrefetch = false
    private var prefetchQueue: [PrefetchKey] = []
    private var prefetchHead = 0
    private var prefetchWanted = Set<PrefetchKey>()
    private var prefetchJobs: [PrefetchKey: Job] = [:]
    private var synchronousWindowStart: CFTimeInterval = 0.0
    private var synchronousSpent: CFTimeInterval = 0.0
    private var fastFormatAttempts = 0
    private var fastFormatSuccesses = 0

    init(fetchResult: PHFetchResult<PHAsset>) {
        self.fetchResult = fetchResult
        self.cache.totalCostLimit = 80 * 1024 * 1024
    }

    static func makeFetchResult() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        return PHAsset.fetchAssets(with: .image, options: options)
    }

    var count: Int {
        return self.fetchResult.count
    }

    private func asset(at index: Int) -> PHAsset? {
        let count = self.fetchResult.count
        guard index >= 0, index < count else {
            return nil
        }
        return self.fetchResult.object(at: count - 1 - index)
    }

    func date(at index: Int) -> Date? {
        return self.asset(at: index)?.creationDate
    }

    func aspectRatio(at index: Int) -> CGFloat {
        guard let asset = self.asset(at: index), asset.pixelWidth > 0, asset.pixelHeight > 0 else {
            return 1.0
        }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    static func targetSize(for pixelSize: CGSize, quality: MediaGridImageQuality) -> CGSize {
        let longest = max(pixelSize.width, pixelSize.height)
        guard quality == .fast, longest > PhotoLibraryDataSource.fastMaxPixelSize else {
            return pixelSize
        }
        let scale = PhotoLibraryDataSource.fastMaxPixelSize / longest
        return CGSize(width: max(1.0, ceil(pixelSize.width * scale)), height: max(1.0, ceil(pixelSize.height * scale)))
    }

    private func key(for asset: PHAsset, size: CGSize) -> ImageKey {
        return ImageKey(identifier: asset.localIdentifier, width: Int(size.width), height: Int(size.height))
    }

    func requestImage(at index: Int, pixelSize: CGSize, quality: MediaGridImageQuality, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        guard let asset = self.asset(at: index) else {
            completion(nil, false)
            return nil
        }
        let targetSize = PhotoLibraryDataSource.targetSize(for: pixelSize, quality: quality)
        let isReduced = targetSize != pixelSize
        let key = self.key(for: asset, size: targetSize)
        if let image = self.cache.object(forKey: key.cacheKey) {
            completion(image, isReduced)
            return nil
        }
        var hasPlaceholder = false
        let fastSize = PhotoLibraryDataSource.targetSize(for: pixelSize, quality: .fast)
        if fastSize != targetSize, let image = self.cache.object(forKey: self.key(for: asset, size: fastSize).cacheKey) {
            completion(image, true)
            hasPlaceholder = true
        }
        if !hasPlaceholder, let image = self.synchronousFastFormatImage(for: asset, targetSize: targetSize) {
            completion(image, true)
            hasPlaceholder = true
            if quality == .fast {
                return nil
            }
        }
        let job: Job
        if let existing = self.jobs[key] {
            job = existing
        } else {
            job = Job(key: key, asset: asset, targetSize: targetSize)
            self.jobs[key] = job
        }
        let consumer = Consumer(isReduced: isReduced, completion: completion)
        job.consumers[ObjectIdentifier(consumer)] = consumer
        if job.state == .pending {
            let lane = self.lane(for: job)
            if lane.visible.count > lane.compactionThreshold {
                lane.visible.removeAll(where: { $0.state != .pending || !$0.isWanted })
                lane.compactionThreshold = max(512, lane.visible.count * 2)
            }
            lane.visible.append(job)
            self.pump()
        }
        return Request(source: self, job: job, consumer: consumer)
    }

    func startCaching(indices: [Int], pixelSize: CGSize, quality: MediaGridImageQuality) {
        let targetSize = PhotoLibraryDataSource.targetSize(for: pixelSize, quality: quality)
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        for index in indices {
            let key = PrefetchKey(index: index, width: width, height: height)
            if self.prefetchWanted.insert(key).inserted {
                self.prefetchQueue.append(key)
            }
        }
        self.pump()
    }

    func stopCaching(indices: [Int], pixelSize: CGSize, quality: MediaGridImageQuality) {
        let targetSize = PhotoLibraryDataSource.targetSize(for: pixelSize, quality: quality)
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        self.isUpdatingPrefetch = true
        defer {
            self.isUpdatingPrefetch = false
            self.pump()
        }
        for index in indices {
            let key = PrefetchKey(index: index, width: width, height: height)
            guard self.prefetchWanted.remove(key) != nil, let job = self.prefetchJobs.removeValue(forKey: key) else {
                continue
            }
            job.isPrefetched = false
            self.dropIfUnwanted(job)
        }
        if self.prefetchHead > 1024 && self.prefetchHead * 2 > self.prefetchQueue.count {
            self.prefetchQueue.removeFirst(self.prefetchHead)
            self.prefetchHead = 0
        }
    }

    private func synchronousFastFormatImage(for asset: PHAsset, targetSize: CGSize) -> UIImage? {
        if self.fastFormatSuccesses == 0 && self.fastFormatAttempts >= PhotoLibraryDataSource.fastFormatProbeLimit {
            return nil
        }
        let now = CACurrentMediaTime()
        if now - self.synchronousWindowStart > 1.0 / 60.0 {
            self.synchronousWindowStart = now
            self.synchronousSpent = 0.0
        }
        if self.synchronousSpent >= PhotoLibraryDataSource.synchronousBudgetPerFrame {
            return nil
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        var result: UIImage?
        self.manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options, resultHandler: { image, _ in
            result = image
        })
        self.synchronousSpent += CACurrentMediaTime() - now
        self.fastFormatAttempts += 1
        if result != nil {
            self.fastFormatSuccesses += 1
        }
        return result
    }

    private func lane(for job: Job) -> Lane {
        return job.usesNetwork ? self.networkLane : self.localLane
    }

    private func remove(_ consumer: Consumer, from job: Job) {
        job.consumers.removeValue(forKey: ObjectIdentifier(consumer))
        self.dropIfUnwanted(job)
    }

    private func dropIfUnwanted(_ job: Job) {
        guard !job.isWanted, job.state != .finished else {
            return
        }
        let wasRunning = job.state == .running
        job.state = .finished
        if self.jobs[job.key] === job {
            self.jobs.removeValue(forKey: job.key)
        }
        if wasRunning {
            if let requestId = job.requestId {
                self.manager.cancelImageRequest(requestId)
            }
            self.lane(for: job).running -= 1
            self.pump()
        }
    }

    private func pump() {
        if self.isUpdatingPrefetch {
            return
        }
        for lane in [self.localLane, self.networkLane] {
            while lane.running < lane.limit, let job = self.nextJob(in: lane) {
                self.start(job, in: lane)
            }
        }
    }

    private func nextJob(in lane: Lane) -> Job? {
        while let job = lane.visible.popLast() {
            if job.state == .pending && job.isWanted {
                return job
            }
        }
        guard lane === self.localLane, lane.running < lane.prefetchLimit else {
            return nil
        }
        while self.prefetchHead < self.prefetchQueue.count {
            let prefetchKey = self.prefetchQueue[self.prefetchHead]
            self.prefetchHead += 1
            guard self.prefetchWanted.contains(prefetchKey), self.prefetchJobs[prefetchKey] == nil, let asset = self.asset(at: prefetchKey.index) else {
                continue
            }
            let key = ImageKey(identifier: asset.localIdentifier, width: prefetchKey.width, height: prefetchKey.height)
            if let job = self.jobs[key] {
                job.isPrefetched = true
                self.prefetchJobs[prefetchKey] = job
                continue
            }
            if self.cache.object(forKey: key.cacheKey) != nil {
                continue
            }
            let job = Job(key: key, asset: asset, targetSize: CGSize(width: prefetchKey.width, height: prefetchKey.height))
            job.isPrefetched = true
            self.jobs[key] = job
            self.prefetchJobs[prefetchKey] = job
            return job
        }
        self.prefetchQueue.removeAll()
        self.prefetchHead = 0
        return nil
    }

    private func start(_ job: Job, in lane: Lane) {
        job.state = .running
        lane.running += 1
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = job.usesNetwork
        let requestId = self.manager.requestImage(for: job.asset, targetSize: job.targetSize, contentMode: .aspectFill, options: options, resultHandler: { [weak self, weak job] image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
            let handle = {
                guard let self, let job, !isCancelled else {
                    return
                }
                self.handle(job, image: image, isDegraded: isDegraded, isInCloud: isInCloud)
            }
            if Thread.isMainThread {
                handle()
            } else {
                DispatchQueue.main.async(execute: handle)
            }
        })
        if job.state == .running {
            job.requestId = requestId
        }
    }

    private func handle(_ job: Job, image: UIImage?, isDegraded: Bool, isInCloud: Bool) {
        guard job.state == .running else {
            return
        }
        if isDegraded {
            if let image {
                for consumer in job.consumers.values {
                    consumer.completion(image, true)
                }
            }
            return
        }
        let lane = self.lane(for: job)
        if image == nil && isInCloud && !job.usesNetwork && !job.consumers.isEmpty {
            lane.running -= 1
            job.state = .pending
            job.requestId = nil
            job.usesNetwork = true
            self.networkLane.visible.append(job)
            self.pump()
            return
        }
        job.state = .finished
        lane.running -= 1
        if self.jobs[job.key] === job {
            self.jobs.removeValue(forKey: job.key)
        }
        if let image, let cgImage = image.cgImage {
            self.cache.setObject(image, forKey: job.key.cacheKey, cost: cgImage.bytesPerRow * cgImage.height)
        }
        let consumers = Array(job.consumers.values)
        job.consumers.removeAll()
        for consumer in consumers {
            consumer.completion(image, image != nil && consumer.isReduced)
        }
        self.pump()
    }
}
