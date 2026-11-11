import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

func appLogEventSize(_ operation: SynchronizeAppLogEventsOperation) -> Int? {
    return (try? JSONEncoder().encode(operation))?.count
}

func trimAppLogEvents(transaction: Transaction, owner: AnyObject, now: Double) {
    AppLogEventCollection.sync {
        let peerId = PeerId(0)
        let tag = OperationLogTags.SynchronizeAppLogEvents
        var retained: [(Int32, Int)] = []
        var removed: [Int32] = []
        var bytes = 0
        transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag) { entry in
            guard let operation = entry.contents as? SynchronizeAppLogEventsOperation,
                  AppLogEventCollection.allows(owner: owner, identifier: operation.collectionId),
                  let size = appLogEventSize(operation) else {
                removed.append(entry.tagLocalIndex)
                return true
            }
            if case let .add(time, _, _, _) = operation.content,
               !AppLogEventLimits.accepts(time: time, now: now, bytes: size) {
                removed.append(entry.tagLocalIndex)
                return true
            }
            retained.append((entry.tagLocalIndex, size))
            bytes += size
            return true
        }
        var offset = 0
        while retained.count - offset > AppLogEventLimits.queueCount || bytes > AppLogEventLimits.queueBytes {
            removed.append(retained[offset].0)
            bytes -= retained[offset].1
            offset += 1
        }
        for index in removed {
            let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: index)
        }
    }
}

func purgeInvalidAppLogEvents(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
        trimAppLogEvents(transaction: transaction, owner: postbox, now: Date().timeIntervalSince1970)
    }
}

func makeAppLogEventContext(postbox: Postbox) -> AppLogEventContext {
    return AppLogEventCollection.makeContext(owner: postbox, purge: { [weak postbox] in
        guard let postbox = postbox else { return }
        let _ = purgeInvalidAppLogEvents(postbox: postbox).start()
    })
}

func _internal_addAppLogEvent(postbox: Postbox, time: Double = Date().timeIntervalSince1970, type: String, peerId: PeerId? = nil, data: JSON = .dictionary([:]), context: AppLogEventContext? = nil) {
    let collectionId = context?.identifier
    guard AppLogEventCollection.allows(owner: postbox, identifier: collectionId) else { return }
    let operation = SynchronizeAppLogEventsOperation(content: .add(time: time, type: type, peerId: PeerId(0), data: data), collectionId: collectionId)
    if collectionId != nil || !AppLogEventCollection.allowsLegacyEvents {
        guard let bytes = appLogEventSize(operation), AppLogEventLimits.accepts(time: time, now: Date().timeIntervalSince1970, bytes: bytes) else { return }
    }
    let _ = (postbox.transaction { transaction in
        AppLogEventCollection.perform(owner: postbox, identifiers: [collectionId]) {
            transaction.operationLogAddEntry(peerId: PeerId(0), tag: OperationLogTags.SynchronizeAppLogEvents, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operation)
            if collectionId != nil || !AppLogEventCollection.allowsLegacyEvents {
                trimAppLogEvents(transaction: transaction, owner: postbox, now: Date().timeIntervalSince1970)
            }
        }
    }).start()
}

func _internal_addAppLogEvent(transaction: Transaction, time: Double, type: String, data: JSON) {
    guard AppLogEventCollection.allowsLegacyEvents else { return }
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeAppLogEvents
    let peerId = PeerId(0)
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeAppLogEventsOperation(content: .add(time: time, type: type, peerId: peerId, data: data)))
}

public func invokeAppLogEventsSynchronization(postbox: Postbox) {
    let collectionId = AppLogEventCollection.currentIdentifier(owner: postbox)
    guard AppLogEventCollection.allows(owner: postbox, identifier: collectionId) else { return }
    let tag = OperationLogTags.SynchronizeAppLogEvents
    let peerId = PeerId(0)
    let _ = (postbox.transaction { transaction in
        AppLogEventCollection.perform(owner: postbox, identifiers: [collectionId]) {
            var syncIndices: [Int32] = []
            transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag) { entry in
                if let operation = entry.contents as? SynchronizeAppLogEventsOperation, case .sync = operation.content {
                    syncIndices.append(entry.tagLocalIndex)
                }
                return true
            }
            for index in syncIndices {
                let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: index)
            }
            transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeAppLogEventsOperation(content: .sync, collectionId: collectionId))
        }
    }).start()
}
