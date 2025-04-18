import Foundation

final class MutablePeerMergedOperationLogView {
    let tag: PeerOperationLogTag
    let filterByPeerId: PeerId?
    var entries: [PeerMergedOperationLogEntry]
    var tailIndex: Int32?
    let limit: Int
    
    init(postbox: PostboxImpl, tag: PeerOperationLogTag, filterByPeerId: PeerId?, limit: Int) {
        self.tag = tag
        self.filterByPeerId = filterByPeerId
        if let filterByPeerId = self.filterByPeerId {
            self.entries = postbox.peerOperationLogTable.getMergedEntries(tag: tag, peerId: filterByPeerId, fromIndex: 0, limit: limit)
        } else {
            self.entries = postbox.peerOperationLogTable.getMergedEntries(tag: tag, fromIndex: 0, limit: limit)
        }
        self.tailIndex = postbox.peerMergedOperationLogIndexTable.tailIndex(tag: tag)
        self.limit = limit
    }
    
    func replay(postbox: PostboxImpl, operations: [PeerMergedOperationLogOperation]) -> Bool {
        var updated = false
        
        if let filterByPeerId = self.filterByPeerId {
            if operations.contains(where: { operation in
                switch operation {
                case let .append(entry):
                    if entry.tag == self.tag && entry.peerId == filterByPeerId {
                        return true
                    }
                case let .remove(tag, peerId, _):
                    if tag == self.tag && peerId == filterByPeerId {
                        return true
                    }
                case let .updateContents(entry):
                    if entry.tag == self.tag && entry.peerId == filterByPeerId {
                        return true
                    }
                }
                return false
            }) {
                self.entries = postbox.peerOperationLogTable.getMergedEntries(tag: tag, peerId: filterByPeerId, fromIndex: 0, limit: limit)
                updated = true
            }
        } else {
            var invalidatedTail = false
            
            for operation in operations {
                switch operation {
                case let .append(entry):
                    if entry.tag == self.tag {
                        if let tailIndex = self.tailIndex {
                            assert(entry.mergedIndex > tailIndex)
                            self.tailIndex = entry.mergedIndex
                            if self.entries.count < self.limit {
                                self.entries.append(entry)
                                updated = true
                            }
                        } else {
                            updated = true
                            if !self.entries.isEmpty && !invalidatedTail {
                                assertionFailure("self.entries.isEmpty == false for tag \(self.tag)")
                            }
                            self.entries.append(entry)
                            self.tailIndex = entry.mergedIndex
                        }
                    }
                case let .updateContents(entry):
                    if entry.tag == self.tag {
                    loop: for i in 0 ..< self.entries.count {
                        if self.entries[i].tagLocalIndex == entry.tagLocalIndex {
                            self.entries[i] = entry
                            updated = true
                            break loop
                        }
                    }
                    }
                case let .remove(tag, _, mergedIndices):
                    if tag == self.tag {
                        updated = true
                        for i in (0 ..< self.entries.count).reversed() {
                            if mergedIndices.contains(self.entries[i].mergedIndex) {
                                self.entries.remove(at: i)
                            }
                        }
                        if let tailIndex = self.tailIndex, mergedIndices.contains(tailIndex) {
                            self.tailIndex = nil
                            invalidatedTail = true
                        }
                    }
                }
            }
            
            if updated {
                if invalidatedTail {
                    self.tailIndex = postbox.peerMergedOperationLogIndexTable.tailIndex(tag: self.tag)
                }
                if self.entries.count < self.limit {
                    if let tailIndex = self.tailIndex {
                        if self.entries.isEmpty || self.entries.last!.mergedIndex < tailIndex {
                            var fromIndex: Int32 = 0
                            if !self.entries.isEmpty {
                                fromIndex = self.entries.last!.mergedIndex + 1
                            }
                            for entry in postbox.peerOperationLogTable.getMergedEntries(tag: self.tag, fromIndex: fromIndex, limit: self.limit - self.entries.count) {
                                self.entries.append(entry)
                            }
                            for i in 0 ..< self.entries.count {
                                if i != 0 {
                                    assert(self.entries[i].mergedIndex >= self.entries[i - 1].mergedIndex + 1)
                                }
                            }
                            if !self.entries.isEmpty {
                                assert(self.entries.last!.mergedIndex <= tailIndex)
                            }
                        }
                    }
                } else {
                    assert(self.tailIndex != nil)
                    if let tailIndex = self.tailIndex {
                        assert(self.entries.last!.mergedIndex <= tailIndex)
                    }
                }
            }
        }
        
        return updated
    }
}

public final class PeerMergedOperationLogView {
    public let entries: [PeerMergedOperationLogEntry]
    
    init(_ view: MutablePeerMergedOperationLogView) {
       self.entries = view.entries
    }
}
