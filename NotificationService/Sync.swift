import Foundation
import SwiftSignalKit
import ValueBox
import MessageHistoryReadStateTable
import MessageHistoryMetadataTable
import PostboxDataTypes

private func accountRecordIdPathName(_ id: Int64) -> String {
    return "account-\(UInt64(bitPattern: id))"
}

private final class ValueBoxLoggerImpl: ValueBoxLogger {
    func log(_ what: String) {
        print("ValueBox: \(what)")
    }
}

private extension PeerSummaryCounterTags {
    static let regularChatsAndPrivateGroups = PeerSummaryCounterTags(rawValue: 1 << 0)
    static let publicGroups = PeerSummaryCounterTags(rawValue: 1 << 1)
    static let channels = PeerSummaryCounterTags(rawValue: 1 << 2)
}

private struct Namespaces {
    struct Message {
        static let Cloud: Int32 = 0
    }

    struct Peer {
        static let CloudUser: Int32 = 0
        static let CloudGroup: Int32 = 1
        static let CloudChannel: Int32 = 2
        static let SecretChat: Int32 = 3
    }
}

final class SyncProviderImpl {
    func addIncomingMessage(withRootPath rootPath: String, accountId: Int64, encryptionParameters: DeviceSpecificEncryptionParameters, peerId: Int64, messageId: Int32, completion: @escaping (Int32) -> Void) {
        Queue.mainQueue().async {
            let basePath = rootPath + "/" + accountRecordIdPathName(accountId) + "/postbox"
            
            let valueBox = SqliteValueBox(basePath: basePath + "/db", queue: Queue.mainQueue(), logger: ValueBoxLoggerImpl(), encryptionParameters: ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: encryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: encryptionParameters.salt)!), disableCache: true, upgradeProgress: { _ in
            })
            
            let metadataTable = MessageHistoryMetadataTable(valueBox: valueBox, table: MessageHistoryMetadataTable.tableSpec(10))
            let readStateTable = MessageHistoryReadStateTable(valueBox: valueBox, table: MessageHistoryReadStateTable.tableSpec(14), defaultMessageNamespaceReadStates: [:])
            
            let peerId = PeerId(peerId)
            
            let initialCombinedState = readStateTable.getCombinedState(peerId)
            let (combinedState, _) = readStateTable.addIncomingMessages(peerId, indices: Set([MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: messageId), timestamp: 1)]))
            if let combinedState = combinedState {
                let initialCount = initialCombinedState?.count ?? 0
                let updatedCount = combinedState.count
                let deltaCount = max(0, updatedCount - initialCount)
                
                let tag: PeerSummaryCounterTags
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    tag = .channels
                } else {
                    tag = .regularChatsAndPrivateGroups
                }
                
                var totalCount: Int32 = -1
                
                var totalUnreadState = metadataTable.getChatListTotalUnreadState()
                if var counters = totalUnreadState.absoluteCounters[tag] {
                    if initialCount == 0 && updatedCount > 0 {
                        counters.chatCount += 1
                    }
                    counters.messageCount += deltaCount
                    totalUnreadState.absoluteCounters[tag] = counters
                }
                if var counters = totalUnreadState.filteredCounters[tag] {
                    if initialCount == 0 && updatedCount > 0 {
                        counters.chatCount += 1
                    }
                    counters.messageCount += deltaCount
                    totalUnreadState.filteredCounters[tag] = counters
                }
                
                totalCount = totalUnreadState.count(for: .filtered, in: .messages, with: [.channels, .publicGroups, .regularChatsAndPrivateGroups])
                metadataTable.setChatListTotalUnreadState(totalUnreadState)
                metadataTable.setShouldReindexUnreadCounts(value: true)
                
                metadataTable.beforeCommit()
                readStateTable.beforeCommit()
                
                completion(totalCount)
            } else {
                completion(-1)
            }
        }
    }
}
