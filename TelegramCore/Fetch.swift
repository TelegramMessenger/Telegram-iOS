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

private func fetchLocalFileResource(path: String, move: Bool) -> Signal<MediaResourceDataFetchResult, NoError> {
    return Signal { subscriber in
        if move {
            subscriber.putNext(.moveLocalFile(path: path))
            subscriber.putCompletion()
        } else {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                subscriber.putNext(.dataPart(data: data, range: 0 ..< data.count, complete: true))
                subscriber.putCompletion()
            } else {
                subscriber.putNext(.dataPart(data: Data(), range: 0 ..< 0, complete: false))
            }
        }
        return EmptyDisposable
    }
}

func fetchResource(account: Account, resource: MediaResource, range: Range<Int>) -> Signal<MediaResourceDataFetchResult, NoError>? {
    if let _ = resource as? EmptyMediaResource {
        return .never()
    } else if let secretFileResource = resource as? SecretFileMediaResource {
        return .single(.dataPart(data: Data(), range: 0 ..< 0, complete: false)) |> then(fetchSecretFileResource(account: account, resource: secretFileResource, range: range))
    } else if let cloudResource = resource as? TelegramCloudMediaResource {
        return .single(.dataPart(data: Data(), range: 0 ..< 0, complete: false)) |> then(fetchCloudMediaLocation(account: account, resource: cloudResource, size: resource.size, range: range))
    } else if let localFileResource = resource as? LocalFileReferenceMediaResource {
        if false {
            //return .single(.dataPart(data: Data(), range: 0 ..< 0, complete: false)) |> then(fetchLocalFileResource(path: localFileResource.localFilePath) |> delay(10.0, queue: Queue.concurrentDefaultQueue()))
        } else {
            return fetchLocalFileResource(path: localFileResource.localFilePath, move: localFileResource.isUniquelyReferencedTemporaryFile)
        }
    } else if let httpReference = resource as? HttpReferenceMediaResource {
        return .single(.dataPart(data: Data(), range: 0 ..< 0, complete: false)) |> then(fetchHttpResource(url: httpReference.url))
    }
    return nil
}
