import Foundation

#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
import Photos
#endif

private func fetchCloudMediaLocation(account: Account, resource: TelegramCloudMediaResource, size: Int?, range: Range<Int>) -> Signal<MediaResourceDataFetchResult, NoError> {
    return multipartFetch(account: account, resource: resource, size: size, range: range)
}

#if os(iOS)
private func fetchPhotoLibraryResource(localIdentifier: String) -> Signal<MediaResourceDataFetchResult, NoError> {
    return Signal { subscriber in
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        var requestId: PHImageRequestID?
        if fetchResult.count != 0 {
            let asset = fetchResult.object(at: 0)
            let option = PHImageRequestOptions()
            option.deliveryMode = .highQualityFormat
            let size = CGSize(width: 1280.0, height: 1280.0)
            requestId = PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: option, resultHandler: { (image, info) -> Void in
                Queue.concurrentDefaultQueue().async {
                    requestId = nil
                    if let image = image {
                        let scale = min(1.0, min(size.width / max(1.0, image.size.width), size.height / max(1.0, image.size.height)))
                        let scaledSize = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
                        
                        UIGraphicsBeginImageContextWithOptions(scaledSize, true, image.scale)
                        image.draw(in: CGRect(origin: CGPoint(), size: scaledSize))
                        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                        UIGraphicsEndImageContext()
                        
                        if let scaledImage = scaledImage, let data = UIImageJPEGRepresentation(scaledImage, 0.6) {
                            subscriber.putNext(MediaResourceDataFetchResult(data: data, complete: true))
                            subscriber.putCompletion()
                        } else {
                            subscriber.putCompletion()
                        }
                    } else {
                        subscriber.putCompletion()
                    }
                }
            })
        }
        
        return ActionDisposable {
            if let requestId = requestId {
                PHImageManager.default().cancelImageRequest(requestId)
            }
        }
    }
}
#endif

private func fetchLocalFileResource(path: String) -> Signal<MediaResourceDataFetchResult, NoError> {
    return Signal { subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
            subscriber.putNext(MediaResourceDataFetchResult(data: data, complete: true))
            subscriber.putCompletion()
        } else {
            subscriber.putNext(MediaResourceDataFetchResult(data: Data(), complete: false))
        }
        return EmptyDisposable
    }
}

func fetchResource(account: Account, resource: MediaResource, range: Range<Int>) -> Signal<MediaResourceDataFetchResult, NoError> {
    if let _ = resource as? EmptyMediaResource {
        return .single(MediaResourceDataFetchResult(data: Data(), complete: false))
    } else if let secretFileResource = resource as? SecretFileMediaResource {
        return .single(MediaResourceDataFetchResult(data: Data(), complete: false)) |> then(fetchSecretFileResource(account: account, resource: secretFileResource, range: range))
    } else if let cloudResource = resource as? TelegramCloudMediaResource {
        return .single(MediaResourceDataFetchResult(data: Data(), complete: false)) |> then(fetchCloudMediaLocation(account: account, resource: cloudResource, size: resource.size, range: range))
    } else if let photoLibraryResource = resource as? PhotoLibraryMediaResource {
        #if os(iOS)
            return .single(MediaResourceDataFetchResult(data: Data(), complete: false)) |> then(fetchPhotoLibraryResource(localIdentifier: photoLibraryResource.localIdentifier))
        #else
            return .single(MediaResourceDataFetchResult(data: Data(), complete: false))
        #endif
    } else if let localFileResource = resource as? LocalFileReferenceMediaResource {
        if false {
            //return .single(MediaResourceDataFetchResult(data: Data(), complete: false)) |> then(fetchLocalFileResource(path: localFileResource.localFilePath) |> delay(10.0, queue: Queue.concurrentDefaultQueue()))
        } else {
            return fetchLocalFileResource(path: localFileResource.localFilePath)
        }
    } else if let httpReference = resource as? HttpReferenceMediaResource {
        return .single(MediaResourceDataFetchResult(data: Data(), complete: false)) |> then(fetchHttpResource(url: httpReference.url))
    }
    return .single(MediaResourceDataFetchResult(data: Data(), complete: false))
}
