import Foundation
import Postbox
import SwiftSignalKit

#if os(iOS)
import Photos
#endif


private final class MediaResourceDataCopyFile : MediaResourceDataFetchCopyLocalItem {
    let path: String
    init(path: String) {
        self.path = path
    }
    func copyTo(url: URL) -> Bool {
        do {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: self.path), to: url)
            return true
        } catch {
            return false
        }
    }
}

public func fetchCloudMediaLocation(account: Account, resource: TelegramMediaResource, datacenterId: Int, size: Int?, intervals: Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>, parameters: MediaResourceFetchParameters?) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return multipartFetch(postbox: account.postbox, network: account.network, mediaReferenceRevalidationContext: account.mediaReferenceRevalidationContext, resource: resource, datacenterId: datacenterId, size: size, intervals: intervals, parameters: parameters)
}

private func fetchLocalFileResource(path: String, move: Bool) -> Signal<MediaResourceDataFetchResult, NoError> {
    return Signal { subscriber in
        if move {
            subscriber.putNext(.moveLocalFile(path: path))
            subscriber.putCompletion()
        } else {
            subscriber.putNext(.copyLocalItem(MediaResourceDataCopyFile(path: path)))
            subscriber.putCompletion()
        }
        return EmptyDisposable
    }
}

func fetchResource(account: Account, resource: MediaResource, intervals: Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>, parameters: MediaResourceFetchParameters?) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>? {
    if let _ = resource as? EmptyMediaResource {
        return .single(.reset)
        |> then(.never())
    } else if let secretFileResource = resource as? SecretFileMediaResource {
        return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
        |> then(fetchSecretFileResource(account: account, resource: secretFileResource, intervals: intervals, parameters: parameters))
    } else if let cloudResource = resource as? TelegramMultipartFetchableResource {
        return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
        |> then(fetchCloudMediaLocation(account: account, resource: cloudResource, datacenterId: cloudResource.datacenterId, size: resource.size == 0 ? nil : resource.size, intervals: intervals, parameters: parameters))
    } else if let webFileResource = resource as? WebFileReferenceMediaResource {
        return currentWebDocumentsHostDatacenterId(postbox: account.postbox, isTestingEnvironment: account.testingEnvironment)
        |> castError(MediaResourceDataFetchError.self)
        |> mapToSignal { datacenterId -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> in
            return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
            |> then(fetchCloudMediaLocation(account: account, resource: webFileResource, datacenterId: Int(datacenterId), size: resource.size == 0 ? nil : resource.size, intervals: intervals, parameters: parameters))
        }
    } else if let localFileResource = resource as? LocalFileReferenceMediaResource {
        return fetchLocalFileResource(path: localFileResource.localFilePath, move: localFileResource.isUniquelyReferencedTemporaryFile)
        |> castError(MediaResourceDataFetchError.self)
    } else if let httpReference = resource as? HttpReferenceMediaResource {
        return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
        |> then(fetchHttpResource(url: httpReference.url))
    } else if let wallpaperResource = resource as? WallpaperDataResource {
        return getWallpaper(network: account.network, slug: wallpaperResource.slug)
        |> mapError { _ -> MediaResourceDataFetchError in
            return .generic
        }
        |> mapToSignal { wallpaper -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> in
            guard case let .file(file) = wallpaper else {
                return .fail(.generic)
            }
            guard let cloudResource = file.file.resource as? TelegramMultipartFetchableResource else {
                return .fail(.generic)
            }
            return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
            |> then(fetchCloudMediaLocation(account: account, resource: cloudResource, datacenterId: cloudResource.datacenterId, size: resource.size == 0 ? nil : resource.size, intervals: intervals, parameters: MediaResourceFetchParameters(tag: nil, info: TelegramCloudMediaResourceFetchInfo(reference: .standalone(resource: file.file.resource), preferBackgroundReferenceRevalidation: false, continueInBackground: false), isRandomAccessAllowed: true)))
        }
    }
    return nil
}
