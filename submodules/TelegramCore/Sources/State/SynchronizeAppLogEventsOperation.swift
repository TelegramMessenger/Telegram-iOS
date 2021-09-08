import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit


public func addAppLogEvent(postbox: Postbox, time: Double = Date().timeIntervalSince1970, type: String, peerId: PeerId? = nil, data: JSON = .dictionary([:])) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeAppLogEvents
    let peerId = PeerId(0)
    let _ = (postbox.transaction { transaction in
        transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeAppLogEventsOperation(content: .add(time: time, type: type, peerId: peerId, data: data)))
    }).start()
}

public func invokeAppLogEventsSynchronization(postbox: Postbox) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeAppLogEvents
    let peerId = PeerId(0)
    
    let _ = (postbox.transaction { transaction in
        var topOperation: (SynchronizeSavedStickersOperation, Int32)?
        transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
            if let operation = entry.contents as? SynchronizeSavedStickersOperation, case .sync = operation.content {
                topOperation = (operation, entry.tagLocalIndex)
            }
            return false
        })
        
        if let (_, topLocalIndex) = topOperation {
            let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
        }
        
        transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeAppLogEventsOperation(content: .sync))
    }).start()
}
