import Foundation
import Photos
import Postbox
import SwiftSignalKit

func fetchPhotoLibraryResource(localIdentifier: String) -> Signal<MediaResourceDataFetchResult, NoError> {
    return Signal { subscriber in
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        var requestId: PHImageRequestID?
        if fetchResult.count != 0 {
            let asset = fetchResult.object(at: 0)
            let option = PHImageRequestOptions()
            option.deliveryMode = .opportunistic
            option.isNetworkAccessAllowed = true
            option.isSynchronous = false
            let madeProgress = Atomic<Bool>(value: false)
            option.progressHandler = { progress, error, _, _ in
                if !madeProgress.swap(true) {
                    subscriber.putNext(.reset)
                }
            }
            let size = CGSize(width: 1280.0, height: 1280.0)
            requestId = PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: option, resultHandler: { (image, info) -> Void in
                Queue.concurrentDefaultQueue().async {
                    requestId = nil
                    if let image = image {
                        if let info = info, let degraded = info[PHImageResultIsDegradedKey], (degraded as AnyObject).boolValue!{
                            if !madeProgress.swap(true) {
                                subscriber.putNext(.reset)
                            }
                        } else {
                            _ = madeProgress.swap(true)
                            
                            let scale = min(1.0, min(size.width / max(1.0, image.size.width), size.height / max(1.0, image.size.height)))
                            let scaledSize = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
                            
                            UIGraphicsBeginImageContextWithOptions(scaledSize, true, image.scale)
                            image.draw(in: CGRect(origin: CGPoint(), size: scaledSize))
                            let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                            UIGraphicsEndImageContext()
                            
                            if let scaledImage = scaledImage, let data = UIImageJPEGRepresentation(scaledImage, 0.6) {
                                subscriber.putNext(.dataPart(data: data, range: 0 ..< data.count, complete: true))
                                subscriber.putCompletion()
                            } else {
                                subscriber.putCompletion()
                            }
                        }
                    } else {
                        if !madeProgress.swap(true) {
                            subscriber.putNext(.reset)
                        }
                    }
                }
            })
        } else {
            subscriber.putNext(.reset)
        }
        
        return ActionDisposable {
            if let requestId = requestId {
                PHImageManager.default().cancelImageRequest(requestId)
            }
        }
    }
}
