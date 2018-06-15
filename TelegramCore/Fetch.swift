import Foundation

#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
import Photos
#endif

private func fetchCloudMediaLocation(account: Account, resource: TelegramMediaResource, datacenterId: Int, size: Int?, ranges: Signal<IndexSet, NoError>, tag: MediaResourceFetchTag?) -> Signal<MediaResourceDataFetchResult, NoError> {
    return multipartFetch(account: account, resource: resource, datacenterId: datacenterId, size: size, ranges: ranges, tag: tag)
}

private func fetchLocalFileResource(path: String, move: Bool) -> Signal<MediaResourceDataFetchResult, NoError> {
    return Signal { subscriber in
        if move {
            subscriber.putNext(.moveLocalFile(path: path))
            subscriber.putCompletion()
        } else {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                subscriber.putNext(.dataPart(resourceOffset: 0, data: data, range: 0 ..< data.count, complete: true))
                subscriber.putCompletion()
            } else {
                subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
            }
        }
        return EmptyDisposable
    }
}

func fetchResource(account: Account, resource: MediaResource, ranges: Signal<IndexSet, NoError>, tag: MediaResourceFetchTag?) -> Signal<MediaResourceDataFetchResult, NoError>? {
    if let _ = resource as? EmptyMediaResource {
        return .single(.reset) |> then(.never())
    } else if let secretFileResource = resource as? SecretFileMediaResource {
        return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false)) |> then(fetchSecretFileResource(account: account, resource: secretFileResource, ranges: ranges, tag: tag))
    } else if let cloudResource = resource as? TelegramMultipartFetchableResource {
        return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false)) |> then(fetchCloudMediaLocation(account: account, resource: cloudResource, datacenterId: cloudResource.datacenterId, size: resource.size == 0 ? nil : resource.size, ranges: ranges, tag: tag))
    } else if let webFileResource = resource as? WebFileReferenceMediaResource {
        return currentWebDocumentsHostDatacenterId(postbox: account.postbox, isTestingEnvironment: account.testingEnvironment)
        |> mapToSignal { datacenterId -> Signal<MediaResourceDataFetchResult, NoError> in
            return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false)) |> then(fetchCloudMediaLocation(account: account, resource: webFileResource, datacenterId: Int(datacenterId), size: resource.size == 0 ? nil : resource.size, ranges: ranges, tag: tag))
        }
    } else if let localFileResource = resource as? LocalFileReferenceMediaResource {
        return fetchLocalFileResource(path: localFileResource.localFilePath, move: localFileResource.isUniquelyReferencedTemporaryFile)
    } else if let httpReference = resource as? HttpReferenceMediaResource {
        return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false)) |> then(fetchHttpResource(url: httpReference.url))
    }
    return nil
}
