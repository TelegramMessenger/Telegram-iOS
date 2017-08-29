import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

final class SynchronizeLocalizationUpdatesOperation: PostboxCoding {
    init() {
    }
    
    init(decoder: PostboxDecoder) {
    }
    
    func encode(_ encoder: PostboxEncoder) {
    }
}

func addSynchronizeLocalizationUpdatesOperation(modifier: Modifier) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeLocalizationUpdates
    let peerId = PeerId(namespace: 0, id: 0)
    
    var topLocalIndex: Int32?
    modifier.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        topLocalIndex = entry.tagLocalIndex
        return false
    })
    
    if let topLocalIndex = topLocalIndex {
        let _ = modifier.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    modifier.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeLocalizationUpdatesOperation())
}
