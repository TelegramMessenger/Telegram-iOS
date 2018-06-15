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

func fetchSecretFileResource(account: Account, resource: SecretFileMediaResource, ranges: Signal<IndexSet, NoError>, tag: MediaResourceFetchTag?) -> Signal<MediaResourceDataFetchResult, NoError> {
    return multipartFetch(account: account, resource: resource, datacenterId: resource.datacenterId, size: resource.size, ranges: ranges, tag: tag, encryptionKey: resource.key, decryptedSize: resource.decryptedSize)
}
