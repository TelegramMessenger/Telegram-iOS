import Foundation
import Postbox
import SwiftSignalKit


func addSynchronizeLocalizationUpdatesOperation(transaction: Transaction) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeLocalizationUpdates
    let peerId = PeerId(0)
    
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
