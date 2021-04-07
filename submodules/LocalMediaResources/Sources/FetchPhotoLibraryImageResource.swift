import Foundation
import UIKit
import Photos
import Postbox
import SwiftSignalKit
import ImageCompression
import Accelerate.vImage

private final class RequestId {
    var id: PHImageRequestID?
    var invalidated: Bool = false
}

private func resizedImage(_ image: UIImage, for size: CGSize) -> UIImage? {
    guard let cgImage = image.cgImage else {
        return nil
    }

    var format = vImage_CGImageFormat(bitsPerComponent: 8,
                                      bitsPerPixel: 32,
                                      colorSpace: nil,
                                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                                      version: 0,
                                      decode: nil,
                                      renderingIntent: .defaultIntent)

    var error: vImage_Error
    var sourceBuffer = vImage_Buffer()
    defer { sourceBuffer.data.deallocate() }
    error = vImageBuffer_InitWithCGImage(&sourceBuffer,
                                         &format,
                                         nil,
                                         cgImage,
                                         vImage_Flags(kvImageNoFlags))
    guard error == kvImageNoError else { return nil }

    var destinationBuffer = vImage_Buffer()
    error = vImageBuffer_Init(&destinationBuffer,
                              vImagePixelCount(size.height),
                              vImagePixelCount(size.width),
                              format.bitsPerPixel,
                              vImage_Flags(kvImageNoFlags))
    guard error == kvImageNoError else {
        return nil
    }

    error = vImageScale_ARGB8888(&sourceBuffer,
                                 &destinationBuffer,
                                 nil,
                                 vImage_Flags(kvImageHighQualityResampling))
    guard error == kvImageNoError else {
        return nil
    }

    guard let resizedImage =
        vImageCreateCGImageFromBuffer(&destinationBuffer,
                                      &format,
                                      nil,
                                      nil,
                                      vImage_Flags(kvImageNoAllocate),
                                      &error)?.takeRetainedValue(),
        error == kvImageNoError
    else {
        return nil
    }

    return UIImage(cgImage: resizedImage)
}

extension UIImage.Orientation {
    init(_ cgOrientation: CGImagePropertyOrientation) {
        switch cgOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        }
    }
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
            
            let startTime = CACurrentMediaTime()
            
            let requestIdValue = PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: option, resultHandler: { (image, info) -> Void in
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
                            #if DEBUG
                            print("load completion \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                            #endif
                            
                            _ = madeProgress.swap(true)

                            let scale = min(1.0, min(size.width / max(1.0, image.size.width), size.height / max(1.0, image.size.height)))
                            let scaledSize = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
                            let scaledImage = resizedImage(image, for: scaledSize)

                            #if DEBUG
                            print("scaled completion \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                            #endif
                            
                            if let scaledImage = scaledImage, let data = compressImageToJPEG(scaledImage, quality: 0.6) {
                                #if DEBUG
                                print("compression completion \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                                #endif
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

