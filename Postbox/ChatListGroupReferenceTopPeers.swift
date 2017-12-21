import Foundation

private struct GroupReferenceTopPeersEntry {
    let index: ChatListIndex
    let peer: Peer?
}

final class ChatListGroupReferenceTopPeers {
    let groupId: PeerGroupId
    
    fileprivate var entries: [GroupReferenceTopPeersEntry] = []
    
    init(postbox: Postbox, groupId: PeerGroupId) {
        self.groupId = groupId
        
        self.entries = postbox.chatListTable.topMessageIndices(groupId: groupId, count: 4).map { index in
            return GroupReferenceTopPeersEntry(index: index, peer: postbox.peerTable.get(index.messageIndex.id.peerId))
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if let operations = transaction.chatListOperations[WrappedPeerGroupId(groupId: self.groupId)] {
            var updated = false
            var hasRemovals = false
            for operation in operations {
                switch operation {
                    case let .InsertEntry(index, _, _, _):
                        if self.insertIndex(postbox: postbox, index: index) {
                            updated = true
                        }
                    case let .RemoveEntry(indices):
                        for index in indices {
                            if self.removeIndex(index: index) {
                                updated = true
                                hasRemovals = true
                            }
                        }
                    default:
                        break
                }
            }
            
            if hasRemovals {
                self.complete(postbox: postbox)
            }
            
            return updated
        }
        return false
    }
    
    private func insertIndex(postbox: Postbox, index: ChatListIndex) -> Bool {
        if self.entries.isEmpty {
            self.entries.append(GroupReferenceTopPeersEntry(index: index, peer: postbox.peerTable.get(index.messageIndex.id.peerId)))
            return true
        } else {
            let latest = self.entries[0]
            if index > latest.index {
                self.entries.insert(GroupReferenceTopPeersEntry(index: index, peer: postbox.peerTable.get(index.messageIndex.id.peerId)), at: 0)
                self.entries.removeLast()
                return true
            } else if index > self.entries[self.entries.count - 1].index {
                for i in 0 ..< self.entries.count {
                    if self.entries[i].index < index {
                        self.entries.insert(GroupReferenceTopPeersEntry(index: index, peer: postbox.peerTable.get(index.messageIndex.id.peerId)), at: i)
                        if self.entries.count > 4 {
                            self.entries.removeLast()
                        }
                        break
                    }
                }
                return true
            } else if self.entries.count < 4 {
                self.entries.append(GroupReferenceTopPeersEntry(index: index, peer: postbox.peerTable.get(index.messageIndex.id.peerId)))
                return true
            } else {
                return false
            }
        }
    }
    
    private func removeIndex(index: ChatListIndex) -> Bool {
        for i in 0 ..< self.entries.count {
            if self.entries[i].index == index {
                self.entries.remove(at: i)
                return true
            }
        }
        return false
    }
    
    private func complete(postbox: Postbox) {
        if self.entries.count < 4 {
            self.entries = postbox.chatListTable.topMessageIndices(groupId: groupId, count: 4).map { index in
                return GroupReferenceTopPeersEntry(index: index, peer: postbox.peerTable.get(index.messageIndex.id.peerId))
            }
        }
    }
    
    func getPeers() -> [Peer] {
        var result: [Peer] = []
        for entry in self.entries {
            if let peer = entry.peer {
                result.append(peer)
            }
        }
        return result
    }
}
