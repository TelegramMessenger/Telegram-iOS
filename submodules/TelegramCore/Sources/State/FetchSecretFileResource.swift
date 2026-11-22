import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

func fetchSecretFileResource(
    accountPeerId: PeerId,
    postbox: Postbox,
    network: Network,
    mediaReferenceRevalidationContext: MediaReferenceRevalidationContext,
    networkStatsContext: NetworkStatsContext,
    resource: SecretFileMediaResource,
    intervals: Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>,
    parameters: MediaResourceFetchParameters?
) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return multipartFetch(
        accountPeerId: accountPeerId,
        postbox: postbox,
        network: network,
        mediaReferenceRevalidationContext: mediaReferenceRevalidationContext,
        networkStatsContext: networkStatsContext,
        resource: resource,
        datacenterId: resource.datacenterId,
        size: resource.size,
        intervals: intervals,
        parameters: parameters,
        encryptionKey: resource.key,
        decryptedSize: resource.decryptedSize
    )
}
