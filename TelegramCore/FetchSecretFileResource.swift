import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

func fetchSecretFileResource(account: Account, resource: SecretFileMediaResource, intervals: Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>, parameters: MediaResourceFetchParameters?) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return multipartFetch(postbox: account.postbox, network: account.network, mediaReferenceRevalidationContext: account.mediaReferenceRevalidationContext, resource: resource, datacenterId: resource.datacenterId, size: resource.size, intervals: intervals, parameters: parameters, encryptionKey: resource.key, decryptedSize: resource.decryptedSize)
}
