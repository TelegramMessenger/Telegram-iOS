import Foundation
import UIKit
import Photos
import MediaGrid

public final class MediaGridPhotoLibraryFiller {
    let filler: ThumbnailFiller
    let source: PhotoKitThumbnailSource
    var sharpNetworkIdle: () -> Bool = { false }
    public var onLog: ((String) -> Void)?
    public private(set) var networkFills = 0
    private var networkDeliveries = 0

    public var isNetworkLaneEnabled = true {
        didSet {
            if self.isNetworkLaneEnabled != oldValue {
                self.filler.networkConditionsChanged()
            }
        }
    }

    public var isMovingFast: Bool {
        get {
            return self.filler.isMovingFast
        }
        set {
            self.filler.isMovingFast = newValue
        }
    }

    public convenience init(store: MediaGridThumbnailStore, retryRegistryURL: URL?) {
        self.init(store: store, source: PhotoKitThumbnailSource(fetchResult: PHFetchResult<PHAsset>(), reversed: true), registry: ThumbnailRetryRegistry(url: retryRegistryURL))
    }

    init(store: MediaGridThumbnailStore, source: PhotoKitThumbnailSource, registry: ThumbnailRetryRegistry) {
        self.source = source
        self.filler = ThumbnailFiller(store: store, source: source, registry: registry)
        store.onWritabilityChanged = { [weak self] isWritable in
            self?.filler.isPaused = !isWritable
        }
        self.filler.networkGate = { [weak self] in
            guard let self else {
                return false
            }
            return self.isNetworkLaneEnabled && self.sharpNetworkIdle()
        }
        self.filler.onNetworkFill = { [weak self] _ in
            self?.networkFills += 1
        }
        source.onNetworkDelivery = { [weak self] width, height in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.networkDeliveries += 1
                if self.networkDeliveries <= 100 {
                    self.onLog?("NETFILL n=\(self.networkDeliveries) delivered=\(width)x\(height)")
                }
            }
        }
        source.policy.onLog = { [weak self] message in
            DispatchQueue.main.async {
                self?.onLog?(message)
            }
        }
    }

    public var filledCount: Int {
        return self.filler.filledCount
    }

    public var unavailableCount: Int {
        return self.filler.unavailableCount
    }

    public var missingCount: Int {
        return self.filler.missingCount
    }

    public var inFlightCount: Int {
        return self.filler.inFlightCount
    }

    public var networkInFlightCount: Int {
        return self.filler.networkInFlightCount
    }

    public var isComplete: Bool {
        return self.filler.isComplete
    }

    public var retryEntryCount: Int {
        return self.filler.registry.count
    }

    public var launchRetriesReleased: Int {
        return self.filler.launchRetriesReleased
    }
}

public final class MediaGridPhotoLibraryServices {
    public static let shared = MediaGridPhotoLibraryServices(directory: MediaGridPhotoLibraryServices.defaultDirectory, launchDirectory: MediaGridLaunchCache.defaultDirectory, retryRegistryURL: MediaGridPhotoLibraryServices.defaultRetryRegistryURL, snapshotURL: MediaGridPhotoLibraryServices.defaultSnapshotURL)

    public static var defaultDirectory: URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MediaGridThumbnails", isDirectory: true)
    }

    static var defaultRetryRegistryURL: URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MediaGridThumbnailRetries.plist")
    }

    static var defaultSnapshotURL: URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MediaGridLaunchSnapshot.plist")
    }

    public let store: MediaGridThumbnailStore
    public let filler: MediaGridPhotoLibraryFiller
    public let snapshotURL: URL?
    private let launchDirectory: URL?
    private var launchCoverage: () -> MediaGridLaunchCache.Coverage
    private var cachedLaunchCache: MediaGridLaunchCache?

    public init(directory: URL?, launchDirectory: URL?, retryRegistryURL: URL?, snapshotURL: URL?, launchCoverage: (() -> MediaGridLaunchCache.Coverage)? = nil) {
        self.store = MediaGridThumbnailStore(directory: directory)
        self.filler = MediaGridPhotoLibraryFiller(store: self.store, retryRegistryURL: retryRegistryURL)
        self.snapshotURL = snapshotURL
        self.launchDirectory = launchDirectory
        self.launchCoverage = launchCoverage ?? {
            let screen = UIScreen.main
            return MediaGridLaunchCache.coverage(screenSize: screen.bounds.size, scale: screen.scale)
        }
    }

    public var launchCache: MediaGridLaunchCache {
        if let cache = self.cachedLaunchCache {
            return cache
        }
        let coverage = self.launchCoverage()
        let cache = MediaGridLaunchCache(directory: self.launchDirectory, capacity: coverage.capacity, pixelSize: coverage.pixelSize)
        self.cachedLaunchCache = cache
        return cache
    }

    @discardableResult
    public func configureLaunchCoverage(_ coverage: @escaping () -> MediaGridLaunchCache.Coverage) -> Bool {
        guard self.cachedLaunchCache == nil else {
            return false
        }
        self.launchCoverage = coverage
        return true
    }

    public func startLaunchLoading() {
        self.launchCache.startLoading()
    }

    public func makeLaunchMatch(fetchResult: PHFetchResult<PHAsset>, reversed: Bool) -> MediaGridLaunchMatch {
        return MediaGridPhotoLibraryDataSource.launchMatch(cache: self.launchCache, fetchResult: fetchResult, reversed: reversed)
    }

    public func makeDataSource(fetchResult: PHFetchResult<PHAsset>, reversed: Bool, isLibrary: Bool) -> MediaGridPhotoLibraryDataSource {
        guard isLibrary else {
            return MediaGridPhotoLibraryDataSource(fetchResult: fetchResult, reversed: reversed, store: self.store, launch: nil)
        }
        return MediaGridPhotoLibraryDataSource(fetchResult: fetchResult, reversed: reversed, store: self.store, launch: self.makeLaunchMatch(fetchResult: fetchResult, reversed: reversed), filler: self.filler, snapshotURL: self.snapshotURL)
    }
}
