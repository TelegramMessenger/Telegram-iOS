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
