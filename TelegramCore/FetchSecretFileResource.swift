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

func fetchSecretFileResource(account: Account, resource: SecretFileMediaResource, ranges: Signal<IndexSet, NoError>, parameters: MediaResourceFetchParameters?) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return multipartFetch(account: account, resource: resource, datacenterId: resource.datacenterId, size: resource.size, ranges: ranges, parameters: parameters, encryptionKey: resource.key, decryptedSize: resource.decryptedSize)
}
