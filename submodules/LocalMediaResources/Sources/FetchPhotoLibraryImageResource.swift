import Foundation
import UIKit
import Photos
import Postbox
import SwiftSignalKit
import ImageCompression

private final class RequestId {
    var id: PHImageRequestID?
    var invalidated: Bool = false
}

public func fetchPhotoLibraryResource(localIdentifier: String) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        let requestId = Atomic<RequestId>(value: RequestId())
        if fetchResult.count != 0 {
            let asset = fetchResult.object(at: 0)
            let option = PHImageRequestOptions()
            option.deliveryMode = .opportunistic
            option.isNetworkAccessAllowed = true
            option.isSynchronous = false
            let madeProgress = Atomic<Bool>(value: false)
            option.progressHandler = { progress, error, _, _ in
                if !madeProgress.swap(true) {
                    //subscriber.putNext(.reset)
                }
            }
            let size = CGSize(width: 1280.0, height: 1280.0)
            
            let requestIdValue = PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: option, resultHandler: { (image, info) -> Void in
                Queue.concurrentDefaultQueue().async {
                    requestId.with { current -> Void in
                        if !current.invalidated {
                            current.id = nil
                            current.invalidated = true
                        }
                    }
                    if let image = image {
                        if let info = info, let degraded = info[PHImageResultIsDegradedKey], (degraded as AnyObject).boolValue!{
                            if !madeProgress.swap(true) {
                                //subscriber.putNext(.reset)
                            }
                        } else {
                            _ = madeProgress.swap(true)
                            
                            let scale = min(1.0, min(size.width / max(1.0, image.size.width), size.height / max(1.0, image.size.height)))
                            let scaledSize = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
                            
                            UIGraphicsBeginImageContextWithOptions(scaledSize, true, 1.0)
                            image.draw(in: CGRect(origin: CGPoint(), size: scaledSize))
                            let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                            UIGraphicsEndImageContext()
                            
                            if let scaledImage = scaledImage, let data = scaledImage.jpegData(compressionQuality: 0.8) {
                                if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                                    #if DEBUG
                                    if false, let heicData = compressImage(scaledImage, quality: 0.8) {
                                        //compressTinyThumbnail(scaledImage)
                                        print("data \(data.count), heicData \(heicData.count)")
                                        subscriber.putNext(.dataPart(resourceOffset: 0, data: heicData, range: 0 ..< heicData.count, complete: true))
                                        subscriber.putCompletion()
                                        return
                                    }
                                    #endif
                                }
                                
                                subscriber.putNext(.dataPart(resourceOffset: 0, data: data, range: 0 ..< data.count, complete: true))
                                subscriber.putCompletion()
                            } else {
                                subscriber.putCompletion()
                            }
                        }
                    } else {
                        if !madeProgress.swap(true) {
                            //subscriber.putNext(.reset)
                        }
                    }
                }
            })
            requestId.with { current -> Void in
                if !current.invalidated {
                    current.id = requestIdValue
                }
            }
        } else {
            subscriber.putNext(.reset)
        }
        
        return ActionDisposable {
            let requestIdValue = requestId.with { current -> PHImageRequestID? in
                if !current.invalidated {
                    let value = current.id
                    current.id = nil
                    current.invalidated = true
                    return value
                } else {
                    return nil
                }
            }
            if let requestIdValue = requestIdValue {
                PHImageManager.default().cancelImageRequest(requestIdValue)
            }
        }
    }
}

public func fetchPhotoLibraryImage(localIdentifier: String, thumbnail: Bool) -> Signal<(UIImage, Bool)?, NoError> {
    return Signal { subscriber in
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        let requestId = Atomic<RequestId>(value: RequestId())
        if fetchResult.count != 0 {
            let asset = fetchResult.object(at: 0)
            let option = PHImageRequestOptions()
            option.deliveryMode = .highQualityFormat
            if thumbnail {
                option.resizeMode = .fast
            }
            option.isNetworkAccessAllowed = true
            option.isSynchronous = false
            
            let targetSize: CGSize = thumbnail ? CGSize(width: 128.0, height: 128.0) : PHImageManagerMaximumSize
            let requestIdValue = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: option, resultHandler: { (image, info) -> Void in
                Queue.concurrentDefaultQueue().async {
                    requestId.with { current -> Void in
                        if !current.invalidated {
                            current.id = nil
                            current.invalidated = true
                        }
                    }
                    if let image = image {
                        subscriber.putNext((image, thumbnail))
                        subscriber.putCompletion()
                    }
                }
            })
            requestId.with { current -> Void in
                if !current.invalidated {
                    current.id = requestIdValue
                }
            }
        } else {
            subscriber.putNext(nil)
            subscriber.putCompletion()
        }
        
        return ActionDisposable {
            let requestIdValue = requestId.with { current -> PHImageRequestID? in
                if !current.invalidated {
                    let value = current.id
                    current.id = nil
                    current.invalidated = true
                    return value
                } else {
                    return nil
                }
            }
            if let requestIdValue = requestIdValue {
                PHImageManager.default().cancelImageRequest(requestIdValue)
            }
        }
    }
}
