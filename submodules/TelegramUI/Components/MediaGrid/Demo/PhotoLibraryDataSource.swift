import UIKit
import Photos
import MediaGrid

private final class PhotoLibraryImageRequest: MediaGridImageRequest {
    private let manager: PHImageManager
    private let requestId: PHImageRequestID

    init(manager: PHImageManager, requestId: PHImageRequestID) {
        self.manager = manager
        self.requestId = requestId
    }

    func cancel() {
        self.manager.cancelImageRequest(self.requestId)
    }
}

final class PhotoLibraryDataSource: MediaGridDataSource {
    private let fetchResult: PHFetchResult<PHAsset>
    private let manager = PHCachingImageManager()
    private let options: PHImageRequestOptions

    init(fetchResult: PHFetchResult<PHAsset>) {
        self.fetchResult = fetchResult
        self.manager.allowsCachingHighQualityImages = false
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        self.options = options
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

    func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        guard let asset = self.asset(at: index) else {
            completion(nil, false)
            return nil
        }
        let requestId = self.manager.requestImage(for: asset, targetSize: pixelSize, contentMode: .aspectFill, options: self.options, resultHandler: { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            completion(image, isDegraded)
        })
        return PhotoLibraryImageRequest(manager: self.manager, requestId: requestId)
    }

    func startCaching(indices: [Int], pixelSize: CGSize) {
        let assets = indices.compactMap { self.asset(at: $0) }
        self.manager.startCachingImages(for: assets, targetSize: pixelSize, contentMode: .aspectFill, options: self.options)
    }

    func stopCaching(indices: [Int], pixelSize: CGSize) {
        let assets = indices.compactMap { self.asset(at: $0) }
        self.manager.stopCachingImages(for: assets, targetSize: pixelSize, contentMode: .aspectFill, options: self.options)
    }
}
