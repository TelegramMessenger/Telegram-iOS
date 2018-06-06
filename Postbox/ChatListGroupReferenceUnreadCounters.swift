import Foundation

private final class UnreadCountersEntry {
    var unreadCount: Int32
    var isMuted: Bool
    
    init(unreadCount: Int32, isMuted: Bool) {
        self.unreadCount = unreadCount
        self.isMuted = isMuted
    }
}

final class ChatListGroupReferenceUnreadCounters {
    let groupId: PeerGroupId
    
    fileprivate var entries: [PeerId: UnreadCountersEntry]
    fileprivate var count: Int32
    fileprivate var mutedCount: Int32
    
    init(postbox: Postbox, groupId: PeerGroupId) {
        self.groupId = groupId
        
        self.entries = [:]
        self.count = 0
        self.mutedCount = 0
        
        for peerId in postbox.groupAssociationTable.get(groupId: groupId) {
            let isMuted: Bool
            if let notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId), notificationSettings.isRemovedFromTotalUnreadCount {
                isMuted = true
            } else {
                isMuted = false
            }
            
            let entry = UnreadCountersEntry(unreadCount: postbox.readStateTable.getCombinedState(peerId)?.count ?? 0, isMuted: isMuted)
            
            self.entries[peerId] = entry
            if isMuted {
                self.mutedCount += entry.unreadCount
            } else {
                self.count += entry.unreadCount
            }
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if !transaction.alteredInitialPeerCombinedReadStates.isEmpty || !transaction.currentUpdatedPeerNotificationSettings.isEmpty || !transaction.currentInitialPeerGroupIdsBeforeUpdate.isEmpty {
            var updatedPeerIds = Set<PeerId>()
            for peerId in transaction.alteredInitialPeerCombinedReadStates.keys {
                if self.entries[peerId] != nil || postbox.groupAssociationTable.get(peerId: peerId) == self.groupId {
                    updatedPeerIds.insert(peerId)
                }
            }
            for peerId in transaction.currentUpdatedPeerNotificationSettings.keys {
                if self.entries[peerId] != nil || postbox.groupAssociationTable.get(peerId: peerId) == self.groupId {
                    updatedPeerIds.insert(peerId)
                }
            }
            
            for peerId in transaction.currentInitialPeerGroupIdsBeforeUpdate.keys {
                if self.entries[peerId] != nil || postbox.groupAssociationTable.get(peerId: peerId) == self.groupId {
                    updatedPeerIds.insert(peerId)
                }
            }
            
            for peerId in updatedPeerIds {
                let unreadCount = postbox.readStateTable.getCombinedState(peerId)?.count ?? 0
                let isMuted: Bool
                let notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
                if let notificationSettings = notificationSettings, notificationSettings.isRemovedFromTotalUnreadCount {
                    isMuted = true
                } else {
                    isMuted = false
                }
                if postbox.groupAssociationTable.get(peerId: peerId) == self.groupId {
                    if let entry = self.entries[peerId] {
                        if entry.unreadCount != unreadCount || entry.isMuted != isMuted {
                            if entry.isMuted {
                                self.mutedCount -= entry.unreadCount
                            } else {
                                self.count -= entry.unreadCount
                            }
                            
                            entry.unreadCount = unreadCount
                            entry.isMuted = isMuted
                            
                            if isMuted {
                                self.mutedCount += unreadCount
                            } else {
                                self.count += unreadCount
                            }
                            updated = true
                        }
                    } else {
                        if isMuted {
                            self.mutedCount += unreadCount
                        } else {
                            self.count += unreadCount
                        }
                        self.entries[peerId] = UnreadCountersEntry(unreadCount: unreadCount, isMuted: isMuted)
                    }
                } else if let entry = self.entries[peerId] {
                    if entry.isMuted {
                        self.mutedCount -= entry.unreadCount
                    } else {
                        self.count -= entry.unreadCount
                    }
                    self.entries.removeValue(forKey: peerId)
                }
            }
        }
        return updated
    }
    
    func getCounters() -> (unread: Int32, mutedUnread: Int32) {
        return (self.count, self.mutedCount)
    }
    
    func getUnreadPeerIds() -> [PeerId] {
        var result: [PeerId] = []
        for (peerId, entry) in self.entries {
            if entry.unreadCount != 0 {
                result.append(peerId)
            }
        }
        return result
    }
}

