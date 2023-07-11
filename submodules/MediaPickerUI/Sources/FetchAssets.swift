import Foundation
import UIKit
import Photos
import SwiftSignalKit

private let imageManager: PHCachingImageManager = {
    let imageManager = PHCachingImageManager()
    imageManager.allowsCachingHighQualityImages = false
    return imageManager
}()


private let assetsQueue = Queue()

final class AssetDownloadManager {
    private final class DownloadingAssetContext {
        let identifier: String
        let updated: () -> Void
        
        var status: AssetDownloadStatus = .progress(0.0)
        var disposable: Disposable?
        
        init(identifier: String, updated: @escaping () -> Void) {
            self.identifier = identifier
            self.updated = updated
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    private let queue = Queue()
    private var currentAssetContext: DownloadingAssetContext?
    
    init() {
    }
    
    deinit {
    }
    
    func download(asset: PHAsset) {
        if let currentAssetContext = self.currentAssetContext {
            currentAssetContext.disposable?.dispose()
        }
        
        let queue = self.queue
        let identifier = asset.localIdentifier
        
        let assetContext = DownloadingAssetContext(identifier: identifier, updated: { [weak self] in
            queue.async {
                guard let self else {
                    return
                }
                if let currentAssetContext = self.currentAssetContext, currentAssetContext.identifier == identifier, let bag = self.progressObserverContexts[identifier] {
                    for f in bag.copyItems() {
                        f(currentAssetContext.status)
                    }
                }
            }
        })
        assetContext.disposable = (downloadAssetMediaData(asset)
        |> deliverOn(queue)).start(next: { [weak self] status in
            guard let self else {
                return
            }
            if let currentAssetContext = self.currentAssetContext, currentAssetContext.identifier == identifier {
                currentAssetContext.status = status
                currentAssetContext.updated()
            }
        })
        self.currentAssetContext = assetContext
    }
    
    func cancel(identifier: String) {
        if let currentAssetContext = self.currentAssetContext, currentAssetContext.identifier == identifier {
            currentAssetContext.disposable?.dispose()
            self.currentAssetContext = nil
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
            next(.progress(0.0))
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
    
    func downloadProgress(identifier: String) -> Signal<AssetDownloadStatus, NoError> {
        return Signal { [weak self] subscriber in
            if let self {
                return self.downloadProgress(identifier: identifier, next: { status in
                    subscriber.putNext(status)
                    if case .completed = status {
                        subscriber.putCompletion()
                    }
                })
            } else {
                return EmptyDisposable
            }
        }
    }
}

func checkIfAssetIsLocal(_ asset: PHAsset) -> Signal<Bool, NoError> {
    return Signal { subscriber in
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        
        let requestId: PHImageRequestID
        if #available(iOS 13, *) {
            requestId = imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                if data != nil {
                    subscriber.putNext(data != nil)
                }
                subscriber.putCompletion()
            }
        } else {
            requestId = imageManager.requestImageData(for: asset, options: options) { data, _, _, _ in
                if data != nil {
                    subscriber.putNext(data != nil)
                }
                subscriber.putCompletion()
            }
        }
        
        return ActionDisposable {
            imageManager.cancelImageRequest(requestId)
        }
    }
}

enum AssetDownloadStatus {
    case progress(Float)
    case completed
}

private func downloadAssetMediaData(_ asset: PHAsset) -> Signal<AssetDownloadStatus, NoError> {
    return Signal { subscriber in
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress, _, _, _ in
            subscriber.putNext(.progress(Float(progress)))
        }
        
        let requestId: PHImageRequestID
        if #available(iOS 13, *) {
            requestId = imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                if data != nil {
                    subscriber.putNext(.completed)
                }
                subscriber.putCompletion()
            }
        } else {
            requestId = imageManager.requestImageData(for: asset, options: options) { data, _, _, _ in
                if data != nil {
                    subscriber.putNext(.completed)
                }
                subscriber.putCompletion()
            }
        }
        
        return ActionDisposable {
            imageManager.cancelImageRequest(requestId)
        }
    }
}

func assetImage(fetchResult: PHFetchResult<PHAsset>, index: Int, targetSize: CGSize, exact: Bool, deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic, synchronous: Bool = false) -> Signal<UIImage?, NoError> {
    let asset = fetchResult[index]
    return assetImage(asset: asset, targetSize: targetSize, exact: exact, deliveryMode: deliveryMode, synchronous: synchronous)
}

func assetImage(asset: PHAsset, targetSize: CGSize, exact: Bool, deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic, synchronous: Bool = false) -> Signal<UIImage?, NoError> {
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
            }
        }
        return ActionDisposable {
            imageManager.cancelImageRequest(token)
        }
    }
}

func assetVideo(fetchResult: PHFetchResult<PHAsset>, index: Int) -> Signal<AVAsset?, NoError> {
    return Signal { subscriber in
        let asset = fetchResult[index]
        
        let options = PHVideoRequestOptions()
        let token = imageManager.requestAVAsset(forVideo: asset, options: options) { (avAsset, _, info) in
            if let avAsset = avAsset {
                subscriber.putNext(avAsset)
                subscriber.putCompletion()
            }
        }
    
        return ActionDisposable {
            imageManager.cancelImageRequest(token)
        }
    }
}

extension PHAsset {
    var isLocallyAvailable: Bool? {
        let resourceArray = PHAssetResource.assetResources(for: self)
        return resourceArray.first?.value(forKey: "locallyAvailable") as? Bool
    }
}
