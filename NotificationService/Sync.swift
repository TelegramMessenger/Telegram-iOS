import Foundation
import SwiftSignalKit
import ValueBox
import PostboxDataTypes
import MessageHistoryReadStateTable
import MessageHistoryMetadataTable
import PreferencesTable
import PeerTable
import PostboxCoding
import AppLockState
import NotificationsPresentationData

private let registeredTypes: Void = {
    declareEncodable(InAppNotificationSettings.self, f: InAppNotificationSettings.init(decoder:))
    declareEncodable(TelegramChannel.self, f: TelegramChannel.init(decoder:))
}()

private func accountRecordIdPathName(_ id: Int64) -> String {
    return "account-\(UInt64(bitPattern: id))"
}

private final class ValueBoxLoggerImpl: ValueBoxLogger {
    func log(_ what: String) {
        print("ValueBox: \(what)")
    }
}

enum SyncProviderImpl {
    static func isLocked(withRootPath rootPath: String) -> Bool {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
            return true
        } else {
            return false
        }
    }
    
    static func lockedMessageText(withRootPath rootPath: String) -> String {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: notificationsPresentationDataPath(rootPath: rootPath))), let value = try? JSONDecoder().decode(NotificationsPresentationData.self, from: data) {
            return value.applicationLockedMessageString
        } else {
            return "You have a new message"
        }
    }
    
    static func addIncomingMessage(queue: Queue, withRootPath rootPath: String, accountId: Int64, encryptionParameters: DeviceSpecificEncryptionParameters, peerId: Int64, messageId: Int32, completion: @escaping (Int32) -> Void) {
        queue.async {
            let _ = registeredTypes
            
            let sharedBasePath = rootPath + "/accounts-metadata"
            let basePath = rootPath + "/" + accountRecordIdPathName(accountId) + "/postbox"
            
            let sharedValueBox = SqliteValueBox(basePath: sharedBasePath + "/db", queue: queue, logger: ValueBoxLoggerImpl(), encryptionParameters: nil, disableCache: true, upgradeProgress: { _ in
            })
            
            let valueBox = SqliteValueBox(basePath: basePath + "/db", queue: queue, logger: ValueBoxLoggerImpl(), encryptionParameters: ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: encryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: encryptionParameters.salt)!), disableCache: true, upgradeProgress: { _ in
            })
            
            let metadataTable = MessageHistoryMetadataTable(valueBox: valueBox, table: MessageHistoryMetadataTable.tableSpec(10))
            let readStateTable = MessageHistoryReadStateTable(valueBox: valueBox, table: MessageHistoryReadStateTable.tableSpec(14), defaultMessageNamespaceReadStates: [:])
            let peerTable = PeerTable(valueBox: valueBox, table: PeerTable.tableSpec(2), reverseAssociatedTable: nil)
            
            let preferencesTable = PreferencesTable(valueBox: sharedValueBox, table: PreferencesTable.tableSpec(2))
            
            let peerId = PeerId(peerId)
            
            let initialCombinedState = readStateTable.getCombinedState(peerId)
            
            let combinedState = initialCombinedState.flatMap { state -> CombinedPeerReadState in
                var state = state
                for i in 0 ..< state.states.count {
                    if state.states[i].0 == Namespaces.Message.Cloud {
                        switch state.states[i].1 {
                        case .idBased(let maxIncomingReadId, let maxOutgoingReadId, var maxKnownId, var count, let markedUnread):
                            if messageId > maxIncomingReadId {
                                count += 1
                            }
                            maxKnownId = max(maxKnownId, messageId)
                            state.states[i] = (state.states[i].0, .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count, markedUnread: markedUnread))
                        default:
                            break
                        }
                    }
                }
                return state
            }
            
            if let combinedState = combinedState {
                let initialCount = initialCombinedState?.count ?? 0
                let updatedCount = combinedState.count
                let deltaCount = max(0, updatedCount - initialCount)
                
                let tag: PeerSummaryCounterTags
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    if let channel = peerTable.get(peerId) as? TelegramChannel {
                        switch channel.info {
                        case .broadcast:
                            tag = .channels
                        case .group:
                            if channel.username != nil {
                                tag = .publicGroups
                            } else {
                                tag = .regularChatsAndPrivateGroups
                            }
                        }
                    } else {
                        tag = .channels
                    }
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
                
                let inAppSettings = preferencesTable.get(key: ApplicationSpecificSharedDataKeys.inAppNotificationSettings) as? InAppNotificationSettings ?? InAppNotificationSettings.defaultSettings
                
                totalCount = totalUnreadState.count(for: inAppSettings.totalUnreadCountDisplayStyle.category, in: inAppSettings.totalUnreadCountDisplayCategory.statsType, with: inAppSettings.totalUnreadCountIncludeTags)
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
