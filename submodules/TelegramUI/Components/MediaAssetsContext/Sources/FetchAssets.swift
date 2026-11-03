import Foundation
import UIKit
import AVFoundation
import Photos
import SwiftSignalKit

private let imageManager: PHCachingImageManager = {
    let imageManager = PHCachingImageManager()
    imageManager.allowsCachingHighQualityImages = false
    return imageManager
}()


private let assetsQueue = Queue()

public final class AssetDownloadManager {
    private final class DownloadingAssetContext {
        let identifier: String
        
        var status: AssetDownloadStatus = .none
        var disposable: Disposable?
        
        init(identifier: String) {
            self.identifier = identifier
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    private let queue = Queue()
    private var currentAssetContext: DownloadingAssetContext?
    private var pendingAssets: [PHAsset] = []
    private var batchTotalCount: Int = 0
    private var batchFinishedCount: Int = 0
    private var batchUnavailableIdentifiers: [String] = []
    private let batchStatusValue = ValuePromise<AssetBatchDownloadStatus>(.none, ignoreRepeated: true)
    
    /// Combined state of the assets passed to the most recent `download(assets:)`.
    public var batchDownloadStatus: Signal<AssetBatchDownloadStatus, NoError> {
        return self.batchStatusValue.get()
    }
    
    public init() {
    }
    
    deinit {
    }
    
    public func download(asset: PHAsset) {
        self.download(assets: [asset])
    }
    
    /// Downloads `assets` from iCloud one at a time. Per-asset progress stays observable through
    /// `downloadProgress(identifier:)`, so picker cells keep their own indicators; the state of the
    /// batch as a whole is reported by `batchDownloadStatus`. An asset that cannot be downloaded
    /// does not abort the batch — its identifier is carried in the final `.completed`.
    public func download(assets: [PHAsset]) {
        self.batchStatusValue.set(.none)
        self.cancelAllDownloads()
        
        self.queue.async { [weak self] in
            guard let self else {
                return
            }
            self.pendingAssets = assets
            self.batchTotalCount = assets.count
            self.batchFinishedCount = 0
            self.batchUnavailableIdentifiers = []
            if assets.isEmpty {
                self.batchStatusValue.set(.completed(unavailableIdentifiers: []))
            } else {
                self.batchStatusValue.set(.progress(0.0))
                self.startNextDownload()
            }
        }
    }
    
    /// Starts a batch on subscription and reports its combined state, completing once every asset
    /// has either arrived or been reported unavailable. Disposing cancels the batch.
    ///
    /// Prefer this over `download(assets:)` plus `batchDownloadStatus`: subscribing to the promise
    /// separately replays the *previous* batch's terminal value and completes immediately.
    public func downloadBatch(assets: [PHAsset]) -> Signal<AssetBatchDownloadStatus, NoError> {
        return Signal { [weak self] subscriber in
            guard !assets.isEmpty else {
                subscriber.putNext(.completed(unavailableIdentifiers: []))
                subscriber.putCompletion()
                return EmptyDisposable
            }
            guard let self else {
                subscriber.putNext(.completed(unavailableIdentifiers: assets.map { $0.localIdentifier }))
                subscriber.putCompletion()
                return EmptyDisposable
            }
            
            // Start first: `download` resets the shared status synchronously, so the value replayed
            // to the subscription below belongs to this batch and never to the one before it.
            self.download(assets: assets)
            
            let statusDisposable = self.batchDownloadStatus.start(next: { status in
                subscriber.putNext(status)
                if case .completed = status {
                    subscriber.putCompletion()
                }
            })
            return ActionDisposable { [weak self] in
                statusDisposable.dispose()
                self?.cancelAllDownloads()
            }
        }
    }
    
    private func startNextDownload() {
        assert(self.queue.isCurrent())
        
        guard !self.pendingAssets.isEmpty else {
            self.batchStatusValue.set(.completed(unavailableIdentifiers: self.batchUnavailableIdentifiers))
            return
        }
        let asset = self.pendingAssets.removeFirst()
        let identifier = asset.localIdentifier
        
        let assetContext = DownloadingAssetContext(identifier: identifier)
        self.currentAssetContext = assetContext
        assetContext.disposable = (downloadAssetMediaData(asset)
        |> deliverOn(self.queue)).start(next: { [weak self] status in
            guard let self, let currentAssetContext = self.currentAssetContext, currentAssetContext.identifier == identifier else {
                return
            }
            currentAssetContext.status = status
            
            // Notify directly rather than through `currentAssetContext`: a terminal status clears it
            // below, and observers must still see that last value.
            self.notifyObservers(identifier: identifier, status: status)
            
            switch status {
            case .completed, .failed:
                if case .failed = status {
                    self.batchUnavailableIdentifiers.append(identifier)
                }
                self.batchFinishedCount += 1
                self.currentAssetContext = nil
                if self.batchTotalCount > 0 {
                    self.batchStatusValue.set(.progress(Float(self.batchFinishedCount) / Float(self.batchTotalCount)))
                }
                self.startNextDownload()
            case .none, .progress:
                break
            }
        })
    }
    
    public func cancelAllDownloads() {
        self.queue.async { [weak self] in
            guard let self else {
                return
            }
            self.pendingAssets = []
            self.batchTotalCount = 0
            self.batchFinishedCount = 0
            self.batchUnavailableIdentifiers = []
            self.batchStatusValue.set(.none)
            self.cancelCurrentDownload()
        }
    }
    
    public func cancel(identifier: String) {
        self.queue.async { [weak self] in
            guard let self else {
                return
            }
            self.pendingAssets.removeAll(where: { $0.localIdentifier == identifier })
            if let currentAssetContext = self.currentAssetContext, currentAssetContext.identifier == identifier {
                self.cancelCurrentDownload()
            }
        }
    }
    
    private func cancelCurrentDownload() {
        assert(self.queue.isCurrent())
        
        guard let currentAssetContext = self.currentAssetContext else {
            return
        }
        self.currentAssetContext = nil
        currentAssetContext.status = .none
        currentAssetContext.disposable?.dispose()
        self.notifyObservers(identifier: currentAssetContext.identifier, status: .none)
    }
    
    private func notifyObservers(identifier: String, status: AssetDownloadStatus) {
        assert(self.queue.isCurrent())
        
        guard let bag = self.progressObserverContexts[identifier] else {
            return
        }
        for f in bag.copyItems() {
            f(status)
        }
    }
    
    private var progressObserverContexts: [String: Bag<(AssetDownloadStatus) -> Void>] = [:]
    private func downloadProgress(identifier: String, next: @escaping (AssetDownloadStatus) -> Void) -> Disposable {
        let bag: Bag<(AssetDownloadStatus) -> Void>
        if let current = self.progressObserverContexts[identifier] {
            bag = current
        } else {
            bag = Bag()
            self.progressObserverContexts[identifier] = bag
        }
        
        let index = bag.add(next)
        if let currentAssetContext = self.currentAssetContext, currentAssetContext.identifier == identifier {
            next(currentAssetContext.status)
        } else {
            next(.none)
        }
        
        let queue = self.queue
        return ActionDisposable { [weak self, weak bag] in
            queue.async {
                guard let `self` = self else {
                    return
                }
                if let bag = bag, let listBag = self.progressObserverContexts[identifier], listBag === bag {
                    bag.remove(index)
                    if bag.isEmpty {
                        self.progressObserverContexts.removeValue(forKey: identifier)
                    }
                }
            }
        }
    }
    
    public func downloadProgress(identifier: String) -> Signal<AssetDownloadStatus, NoError> {
        return Signal { [weak self] subscriber in
            if let self {
                return self.downloadProgress(identifier: identifier, next: { status in
                    subscriber.putNext(status)
                    switch status {
                    case .completed, .failed:
                        subscriber.putCompletion()
                    case .none, .progress:
                        break
                    }
                })
            } else {
                return EmptyDisposable
            }
        } |> runOn(self.queue)
    }
}

public func checkIfAssetIsLocal(_ asset: PHAsset) -> Signal<Bool, NoError> {
    if asset.isLocallyAvailable == true {
        return .single(true)
    }
    return Signal { subscriber in
        let requestId: PHImageRequestID
        if case .video = asset.mediaType {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = false
            
            requestId = imageManager.requestAVAsset(forVideo: asset, options: options) { asset, _, _ in
                subscriber.putNext(asset != nil)
                subscriber.putCompletion()
            }
        } else {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false

            if #available(iOS 13, *) {
                requestId = imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                    subscriber.putNext(data != nil)
                    subscriber.putCompletion()
                }
            } else {
                requestId = imageManager.requestImageData(for: asset, options: options) { data, _, _, _ in
                    subscriber.putNext(data != nil)
                    subscriber.putCompletion()
                }
            }
        }
        return ActionDisposable {
            imageManager.cancelImageRequest(requestId)
        }
    }
}

public enum AssetDownloadStatus {
    case none
    case progress(Float)
    case completed
    case failed
}

public enum AssetBatchDownloadStatus: Equatable {
    case none
    case progress(Float)
    case completed(unavailableIdentifiers: [String])
}

private func downloadAssetMediaData(_ asset: PHAsset) -> Signal<AssetDownloadStatus, NoError> {
    return Signal { subscriber in
        let requestId: PHImageRequestID
        if case .video = asset.mediaType {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.progressHandler = { progress, _, _, _ in
                subscriber.putNext(.progress(Float(progress)))
            }
            
            subscriber.putNext(.progress(0.0))
            
            requestId = imageManager.requestAVAsset(forVideo: asset, options: options) { asset, _, _ in
                if asset != nil {
                    subscriber.putNext(.completed)
                } else {
                    subscriber.putNext(.failed)
                }
                subscriber.putCompletion()
            }
        } else {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.progressHandler = { progress, _, _, _ in
                subscriber.putNext(.progress(Float(progress)))
            }
            
            subscriber.putNext(.progress(0.0))
            if #available(iOS 13, *) {
                requestId = imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                    if data != nil {
                        subscriber.putNext(.completed)
                    } else {
                        subscriber.putNext(.failed)
                    }
                    subscriber.putCompletion()
                }
            } else {
                requestId = imageManager.requestImageData(for: asset, options: options) { data, _, _, _ in
                    if data != nil {
                        subscriber.putNext(.completed)
                    } else {
                        subscriber.putNext(.failed)
                    }
                    subscriber.putCompletion()
                }
            }
        }
        
        return ActionDisposable {
            imageManager.cancelImageRequest(requestId)
        }
    }
}

public func assetImage(fetchResult: PHFetchResult<PHAsset>, index: Int, targetSize: CGSize, exact: Bool, deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic, synchronous: Bool = false) -> Signal<UIImage?, NoError> {
    let asset = fetchResult[index]
    return assetImage(asset: asset, targetSize: targetSize, exact: exact, deliveryMode: deliveryMode, synchronous: synchronous)
}

public func assetImage(asset: PHAsset, targetSize: CGSize, exact: Bool, deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic, synchronous: Bool = false) -> Signal<UIImage?, NoError> {
    return Signal { subscriber in
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        if exact {
            options.resizeMode = .exact
        }
        options.isSynchronous = synchronous
        options.isNetworkAccessAllowed = true
        let token = imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { (image, info) in
            var degraded = false
            
            if let info = info {
                if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                    subscriber.putCompletion()
                    return
                }
                if let degradedValue = info[PHImageResultIsDegradedKey] as? Bool, degradedValue {
                    degraded = true
                }
            }
            
            if let image = image {
                subscriber.putNext(image)
                if !degraded || deliveryMode == .fastFormat {
                    subscriber.putCompletion()
                }
            } else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
            }
        }
        return ActionDisposable {
            imageManager.cancelImageRequest(token)
        }
    }
}

public func assetVideo(fetchResult: PHFetchResult<PHAsset>, index: Int) -> Signal<AVAsset?, NoError> {
    return Signal { subscriber in
        let asset = fetchResult[index]
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        let token = imageManager.requestAVAsset(forVideo: asset, options: options) { (avAsset, _, info) in
            subscriber.putNext(avAsset)
            subscriber.putCompletion()
        }
    
        return ActionDisposable {
            imageManager.cancelImageRequest(token)
        }
    }
}

/// The outcome of loading a `PHAsset`'s full-size media.
///
/// `unavailable` is a real, reportable outcome: an asset whose local copy has been evicted by
/// "Optimize iPhone Storage" cannot be loaded without network access, and even with it the
/// download can fail. Callers must handle it — the loaders below never simply go quiet.
public enum AssetLoadResult<T> {
    case progress(Float)
    case result(T)
    case unavailable
}

/// Loads the `AVAsset` of a video `PHAsset`, downloading it from iCloud when the local copy has
/// been evicted.
///
/// Prefer this over calling `PHImageManager.requestAVAsset` directly. Passing `nil` options — the
/// mistake this helper exists to prevent — leaves `isNetworkAccessAllowed` at `false`, so an
/// offloaded video yields no asset at all. The signal ALWAYS terminates: a request that produces
/// nothing emits `.unavailable` rather than never completing and stranding its caller.
public func assetVideoAsset(_ asset: PHAsset) -> Signal<AssetLoadResult<AVAsset>, NoError> {
    return Signal { subscriber in
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress, _, _, _ in
            subscriber.putNext(.progress(Float(progress)))
        }
        
        let requestId = imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let avAsset {
                subscriber.putNext(.result(avAsset))
            } else {
                subscriber.putNext(.unavailable)
            }
            subscriber.putCompletion()
        }
        return ActionDisposable {
            imageManager.cancelImageRequest(requestId)
        }
    }
}

/// Loads the full-size image of a `PHAsset`, downloading it from iCloud when the local copy has
/// been evicted. Terminates with `.unavailable` rather than going quiet; see `assetVideoAsset`.
public func assetFullImage(_ asset: PHAsset, targetSize: CGSize = PHImageManagerMaximumSize, contentMode: PHImageContentMode = .default) -> Signal<AssetLoadResult<UIImage>, NoError> {
    return Signal { subscriber in
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress, _, _, _ in
            subscriber.putNext(.progress(Float(progress)))
        }
        
        let requestId = imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, info in
            if let info {
                if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                    subscriber.putCompletion()
                    return
                }
                if let degraded = info[PHImageResultIsDegradedKey] as? Bool, degraded {
                    // A placeholder, not the answer. `.highQualityFormat` still delivers the real
                    // one afterwards, so wait for it instead of reporting either outcome now.
                    return
                }
            }
            if let image {
                subscriber.putNext(.result(image))
            } else {
                subscriber.putNext(.unavailable)
            }
            subscriber.putCompletion()
        }
        return ActionDisposable {
            imageManager.cancelImageRequest(requestId)
        }
    }
}

extension PHAsset {
    var isLocallyAvailable: Bool? {
        let resourceArray = PHAssetResource.assetResources(for: self)
        return resourceArray.first?.value(forKey: "locallyAvailable") as? Bool
    }
}
