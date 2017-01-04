import Foundation

final class ChatListIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private let peerNameIndexTable: PeerNameIndexTable
    private let metadataTable: MessageHistoryMetadataTable
    private let readStateTable: MessageHistoryReadStateTable
    private let notificationSettingsTable: PeerNotificationSettingsTable
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedIndices: [PeerId: MessageIndex?] = [:]
    private var updatedPreviousCachedIndices: [PeerId: MessageIndex?] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, peerNameIndexTable: PeerNameIndexTable, metadataTable: MessageHistoryMetadataTable, readStateTable: MessageHistoryReadStateTable, notificationSettingsTable: PeerNotificationSettingsTable) {
        self.peerNameIndexTable = peerNameIndexTable
        self.metadataTable = metadataTable
        self.readStateTable = readStateTable
        self.notificationSettingsTable = notificationSettingsTable
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(_ peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        return self.sharedKey
    }
    
    func set(_ index: MessageIndex) {
        self.updatedPreviousCachedIndices[index.id.peerId] = self.get(index.id.peerId)
        self.cachedIndices[index.id.peerId] = index
    }
    
    func remove(_ peerId: PeerId) {
        self.updatedPreviousCachedIndices[peerId] = self.get(peerId)
        self.cachedIndices[peerId] = nil
    }
    
    func get(_ peerId: PeerId) -> MessageIndex? {
        if let cached = self.cachedIndices[peerId] {
            return cached
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(peerId)) {
                var idNamespace: Int32 = 0
                var idId: Int32 = 0
                var idTimestamp: Int32 = 0
                value.read(&idNamespace, offset: 0, length: 4)
                value.read(&idId, offset: 0, length: 4)
                value.read(&idTimestamp, offset: 0, length: 4)
                let index = MessageIndex(id: MessageId(peerId: peerId, namespace: idNamespace, id: idId), timestamp: idTimestamp)
                self.cachedIndices[peerId] = index
                return index
            } else {
                return nil
            }
        }
    }
    
    override func clearMemoryCache() {
        self.cachedIndices.removeAll()
        assert(self.updatedPreviousCachedIndices.isEmpty)
    }
    
    func commitWithTransactionUnreadCountDeltas(_ deltas: [PeerId: Int32], transactionParticipationInTotalUnreadCountUpdates: (added: Set<PeerId>, removed: Set<PeerId>), updatedTotalUnreadCount: inout Int32?) {
        if !self.updatedPreviousCachedIndices.isEmpty || !deltas.isEmpty || !transactionParticipationInTotalUnreadCountUpdates.added.isEmpty || !transactionParticipationInTotalUnreadCountUpdates.removed.isEmpty {
            var addedChatListPeerIds = Set<PeerId>()
            var removedChatListPeerIds = Set<PeerId>()
            
            for (peerId, previousIndex) in self.updatedPreviousCachedIndices {
                let index = self.cachedIndices[peerId]!
                if let index = index {
                    if previousIndex == nil {
                        addedChatListPeerIds.insert(peerId)
                    }
                    
                    let writeBuffer = WriteBuffer()
                    var idNamespace: Int32 = index.id.namespace
                    var idId: Int32 = index.id.id
                    var idTimestamp: Int32 = index.timestamp
                    writeBuffer.write(&idNamespace, offset: 0, length: 4)
                    writeBuffer.write(&idId, offset: 0, length: 4)
                    writeBuffer.write(&idTimestamp, offset: 0, length: 4)
                    self.valueBox.set(self.table, key: self.key(index.id.peerId), value: writeBuffer.readBufferNoCopy())
                } else {
                    if previousIndex != nil {
                        removedChatListPeerIds.insert(peerId)
                    }
                    
                    self.valueBox.remove(self.table, key: self.key(peerId))
                }
            }
            self.updatedPreviousCachedIndices.removeAll()
            
            let addedUnreadCountPeerIds = addedChatListPeerIds.union(transactionParticipationInTotalUnreadCountUpdates.added)
            let removedUnreadCountPeerIds = removedChatListPeerIds.union(transactionParticipationInTotalUnreadCountUpdates.removed)
            
            var totalUnreadCount = self.metadataTable.getChatListTotalUnreadCount()
            for (peerId, delta) in deltas {
                if !addedUnreadCountPeerIds.contains(peerId) && !removedUnreadCountPeerIds.contains(peerId) {
                    if let _ = self.get(peerId), let notificationSettings = self.notificationSettingsTable.get(peerId), !notificationSettings.isRemovedFromTotalUnreadCount {
                        totalUnreadCount += delta
                    }
                }
            }
            
            for peerId in addedChatListPeerIds {
                self.peerNameIndexTable.setPeerCategoryState(peerId: peerId, category: [.chats], includes: true)
            }
            
            for peerId in addedUnreadCountPeerIds {
                let addedToList = addedChatListPeerIds.contains(peerId)
                let startedParticipationInUnreadCount = transactionParticipationInTotalUnreadCountUpdates.added.contains(peerId)
                
                if addedToList && startedParticipationInUnreadCount {
                    if let combinedState = self.readStateTable.getCombinedState(peerId) {
                        totalUnreadCount += combinedState.count
                    }
                } else if addedToList {
                    if let notificationSettings = self.notificationSettingsTable.get(peerId), !notificationSettings.isRemovedFromTotalUnreadCount {
                        if let combinedState = self.readStateTable.getCombinedState(peerId) {
                            totalUnreadCount += combinedState.count
                        }
                    }
                } else if startedParticipationInUnreadCount {
                    if let _ = self.get(peerId) {
                        if let combinedState = self.readStateTable.getCombinedState(peerId) {
                            totalUnreadCount += combinedState.count
                        }
                    }
                } else {
                    assertionFailure()
                }
            }
            
            for peerId in removedChatListPeerIds {
                self.peerNameIndexTable.setPeerCategoryState(peerId: peerId, category: [.chats], includes: false)
            }
            
            for peerId in removedUnreadCountPeerIds {
                var currentPeerUnreadCount: Int32 = 0
                if let combinedState = self.readStateTable.getCombinedState(peerId) {
                    currentPeerUnreadCount = combinedState.count
                }
                
                if let delta = deltas[peerId] {
                    currentPeerUnreadCount -= delta
                }
                
                var removedFromList = removedChatListPeerIds.contains(peerId)
                var removedFromParticipationInUnreadCount = transactionParticipationInTotalUnreadCountUpdates.removed.contains(peerId)
                if removedFromList && removedFromParticipationInUnreadCount {
                    totalUnreadCount -= currentPeerUnreadCount
                } else if removedFromList {
                    if let notificationSettings = self.notificationSettingsTable.get(peerId), !notificationSettings.isRemovedFromTotalUnreadCount {
                        totalUnreadCount -= currentPeerUnreadCount
                    }
                } else if removedFromParticipationInUnreadCount {
                    if let _ = self.get(peerId) {
                        totalUnreadCount -= currentPeerUnreadCount
                    }
                } else {
                    assertionFailure()
                }
            }
            
            //assert(totalUnreadCount >= 0)
            
            if self.metadataTable.getChatListTotalUnreadCount() != totalUnreadCount {
                self.metadataTable.setChatListTotalUnreadCount(totalUnreadCount)
                updatedTotalUnreadCount = totalUnreadCount
            }
        }
    }
    
    override func beforeCommit() {
        assert(self.updatedPreviousCachedIndices.isEmpty)
    }
}
