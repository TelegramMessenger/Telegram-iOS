import UIKit
import Photos
import MediaGrid

final class PhotoLibraryDataSource: MediaGridDataSource {
    struct ImageKey: Hashable {
        var identifier: String
        var width: Int
        var height: Int

        var cacheKey: NSString {
            return "\(self.identifier)|\(self.width)x\(self.height)" as NSString
        }
    }

    struct PrefetchKey: Hashable {
        var index: Int
        var width: Int
        var height: Int
    }

    struct Load {
        var asset: PHAsset
        var targetSize: CGSize
    }

    typealias Scheduler = ImageLoadScheduler<ImageKey, PrefetchKey, Load>

    static let fastMaxPixelSize: CGFloat = 128.0
    static let synchronousBudgetPerTurn: CFTimeInterval = 0.004
    static let fastFormatProbeLimit = 32
    static let fastFormatReprobeInterval: CFTimeInterval = 10.0

    private let fetchResult: PHFetchResult<PHAsset>
    private let manager = PHImageManager.default()
    private let cache = NSCache<NSString, UIImage>()
    private let scheduler = Scheduler(localLimit: 12, localPrefetchLimit: 6, networkLimit: 4)
    private var synchronousSpent: CFTimeInterval = 0.0
    private var isSynchronousResetScheduled = false
    private var fastFormatFailures = 0
    private var fastFormatSuccesses = 0
    private var fastFormatReprobeTime: CFTimeInterval?

    init(fetchResult: PHFetchResult<PHAsset>) {
        self.fetchResult = fetchResult
        self.cache.totalCostLimit = 80 * 1024 * 1024
        self.scheduler.startJob = { [weak self] job in
            self?.start(job)
        }
        self.scheduler.cancelJob = { [weak self] job in
            if let token = job.token {
                self?.manager.cancelImageRequest(token)
            }
        }
        self.scheduler.resolvePrefetch = { [weak self] key in
            guard let self, let asset = self.asset(at: key.index) else {
                return nil
            }
            return (ImageKey(identifier: asset.localIdentifier, width: key.width, height: key.height), Load(asset: asset, targetSize: CGSize(width: key.width, height: key.height)))
        }
        self.scheduler.isCached = { [weak self] key in
            return self?.cache.object(forKey: key.cacheKey) != nil
        }
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
        if isReduced, let image = self.cache.object(forKey: self.key(for: asset, size: pixelSize).cacheKey) {
            completion(image, false)
            return nil
        }
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
            if quality == .fast {
                return nil
            }
        }
        return self.scheduler.request(key: key, payload: Load(asset: asset, targetSize: targetSize), isReduced: isReduced, completion: completion)
    }

    func startCaching(indices: [Int], pixelSize: CGSize, quality: MediaGridImageQuality) {
        self.scheduler.startPrefetching(self.prefetchKeys(indices: indices, pixelSize: pixelSize, quality: quality))
    }

    func stopCaching(indices: [Int], pixelSize: CGSize, quality: MediaGridImageQuality) {
        self.scheduler.stopPrefetching(self.prefetchKeys(indices: indices, pixelSize: pixelSize, quality: quality))
    }

    private func prefetchKeys(indices: [Int], pixelSize: CGSize, quality: MediaGridImageQuality) -> [PrefetchKey] {
        let targetSize = PhotoLibraryDataSource.targetSize(for: pixelSize, quality: quality)
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        return indices.map { PrefetchKey(index: $0, width: width, height: height) }
    }

    private var isFastFormatProbing: Bool {
        if self.fastFormatSuccesses > 0 || self.fastFormatFailures < PhotoLibraryDataSource.fastFormatProbeLimit {
            return true
        }
        let now = CACurrentMediaTime()
        guard let reprobeTime = self.fastFormatReprobeTime else {
            self.fastFormatReprobeTime = now + PhotoLibraryDataSource.fastFormatReprobeInterval
            return false
        }
        if now >= reprobeTime {
            self.fastFormatReprobeTime = now + PhotoLibraryDataSource.fastFormatReprobeInterval
            return true
        }
        return false
    }

    private func synchronousFastFormatImage(for asset: PHAsset, targetSize: CGSize) -> UIImage? {
        guard self.synchronousSpent < PhotoLibraryDataSource.synchronousBudgetPerTurn, self.isFastFormatProbing else {
            return nil
        }
        if !self.isSynchronousResetScheduled {
            self.isSynchronousResetScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.synchronousSpent = 0.0
                self?.isSynchronousResetScheduled = false
            }
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        let start = CACurrentMediaTime()
        var result: UIImage?
        var isInCloud = false
        self.manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options, resultHandler: { image, info in
            result = image
            isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
        })
        self.synchronousSpent += CACurrentMediaTime() - start
        if result != nil {
            self.fastFormatSuccesses += 1
        } else if !isInCloud {
            self.fastFormatFailures += 1
        }
        return result
    }

    private func start(_ job: Scheduler.Job) {
        let attempt = job.attempt
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = job.usesNetwork
        let token = self.manager.requestImage(for: job.payload.asset, targetSize: job.payload.targetSize, contentMode: .aspectFill, options: options, resultHandler: { [weak self, weak job] image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
            let handle = {
                guard let self, let job else {
                    return
                }
                self.handle(job, attempt: attempt, image: image, isDegraded: isDegraded, isCancelled: isCancelled, isInCloud: isInCloud)
            }
            if Thread.isMainThread {
                handle()
            } else {
                DispatchQueue.main.async(execute: handle)
            }
        })
        if job.state == .running && job.attempt == attempt {
            job.token = token
        }
    }

    private func handle(_ job: Scheduler.Job, attempt: Int, image: UIImage?, isDegraded: Bool, isCancelled: Bool, isInCloud: Bool) {
        if isCancelled {
            self.scheduler.cancelledExternally(job, attempt: attempt)
            return
        }
        if isDegraded {
            if let image {
                self.scheduler.deliverDegraded(job, attempt: attempt, image: image)
            }
            return
        }
        if image == nil && isInCloud && self.scheduler.moveToNetwork(job, attempt: attempt) {
            return
        }
        if let image, let cgImage = image.cgImage, job.state == .running, job.attempt == attempt {
            self.cache.setObject(image, forKey: job.key.cacheKey, cost: cgImage.bytesPerRow * cgImage.height)
        }
        self.scheduler.finish(job, attempt: attempt, image: image)
    }
}
