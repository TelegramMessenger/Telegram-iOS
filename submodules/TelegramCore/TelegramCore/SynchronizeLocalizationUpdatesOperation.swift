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

func addSynchronizeLocalizationUpdatesOperation(transaction: Transaction) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeLocalizationUpdates
    let peerId = PeerId(namespace: 0, id: 0)
    
    var topLocalIndex: Int32?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        topLocalIndex = entry.tagLocalIndex
        return false
    })
    
    if let topLocalIndex = topLocalIndex {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeLocalizationUpdatesOperation())
}
