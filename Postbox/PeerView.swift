import Foundation

public class PeerViewEntry {
    public let peer: Peer
    public let message: Message
    
    public init(peer: Peer, message: Message) {
        self.peer = peer
        self.message = message
    }
}

public struct PeerViewEntryIndex: Equatable, Comparable {
    public let peerId: PeerId
    public let messageIndex: MessageIndex
    
    public init(_ entry: PeerViewEntry) {
        self.peerId = entry.peer.id
        self.messageIndex = MessageIndex(entry.message)
    }
    
    public init(peerId: PeerId, messageIndex: MessageIndex) {
        self.peerId = peerId
        self.messageIndex = messageIndex
    }
    
    public func earlier() -> PeerViewEntryIndex {
        return PeerViewEntryIndex(peerId: self.peerId, messageIndex: MessageIndex(id: MessageId(peerId: self.messageIndex.id.peerId, namespace: self.messageIndex.id.namespace, id: self.messageIndex.id.id - 1), timestamp: self.messageIndex.timestamp))
    }
    
    public func later() -> PeerViewEntryIndex {
        return PeerViewEntryIndex(peerId: self.peerId, messageIndex: MessageIndex(id: MessageId(peerId: self.messageIndex.id.peerId, namespace: self.messageIndex.id.namespace, id: self.messageIndex.id.id + 1), timestamp: self.messageIndex.timestamp))
    }
}

public func ==(lhs: PeerViewEntryIndex, rhs: PeerViewEntryIndex) -> Bool {
    return lhs.peerId == rhs.peerId && lhs.messageIndex == rhs.messageIndex
}

public func <(lhs: PeerViewEntryIndex, rhs: PeerViewEntryIndex) -> Bool {
    if lhs.messageIndex != rhs.messageIndex {
        return lhs.messageIndex < rhs.messageIndex
    }
    
    return lhs.peerId < rhs.peerId
}

public final class MutablePeerView: Printable {
    public struct RemoveContext {
        var invalidEarlier = false
        var invalidLater = false
        var removedEntries = false
    }
    
    let tags: [Int32]
    let count: Int
    var earlier: PeerViewEntry?
    var later: PeerViewEntry?
    var entries: [PeerViewEntry]
    
    public init(tags: [Int32], count: Int, earlier: PeerViewEntry?, entries: [PeerViewEntry], later: PeerViewEntry?) {
        self.tags = tags
        self.count = count
        self.earlier = earlier
        self.entries = entries
        self.later = later
    }
    
    public func removeEntry(context: RemoveContext?, peerId: PeerId) -> RemoveContext {
        var invalidationContext = context ?? RemoveContext()
        
        if let earlier = self.earlier {
            if peerId == earlier.peer.id {
                invalidationContext.invalidEarlier = true
            }
        }
        
        if let later = self.later {
            if peerId == later.peer.id {
                invalidationContext.invalidLater = true
            }
        }
        
        var i = 0
        while i < self.entries.count {
            if self.entries[i].peer.id == peerId {
                self.entries.removeAtIndex(i)
                invalidationContext.removedEntries = true
                break
            }
            i++
        }
        
        return invalidationContext
    }
    
    public func addEntry(entry: PeerViewEntry) {
        if self.entries.count == 0 {
            self.entries.append(entry)
        } else {
            var first = PeerViewEntryIndex(self.entries[self.entries.count - 1])
            var last = PeerViewEntryIndex(self.entries[0])
            
            let index = PeerViewEntryIndex(entry)
            
            var next: PeerViewEntryIndex?
            if let later = self.later {
                next = PeerViewEntryIndex(later)
            }
            
            if index < last {
                let earlierEntry = self.earlier
                if earlierEntry == nil || PeerViewEntryIndex(earlierEntry!) < index {
                    if self.entries.count < self.count {
                        self.entries.insert(entry, atIndex: 0)
                    } else {
                        self.earlier = entry
                    }
                }
            } else if index > first {
                if next != nil && index > next! {
                    let laterEntry = self.later
                    if laterEntry == nil || PeerViewEntryIndex(laterEntry!) > index {
                        if self.entries.count < self.count {
                            self.entries.append(entry)
                        } else {
                            self.later = entry
                        }
                    }
                } else {
                    self.entries.append(entry)
                    if self.entries.count > self.count {
                        let earliest = self.entries[0]
                        self.earlier = earliest
                        self.entries.removeAtIndex(0)
                    }
                }
            } else if index != last && index != first {
                var i = self.entries.count
                while i >= 1 {
                    if PeerViewEntryIndex(self.entries[i - 1]) < index {
                        break
                    }
                    i--
                }
                self.entries.insert(entry, atIndex: i)
                if self.entries.count > self.count {
                    let earliest = self.entries[0]
                    self.earlier = earliest
                    self.entries.removeAtIndex(0)
                }
            }
        }
    }
    
    public func complete(context: RemoveContext, fetchEarlier: (PeerViewEntryIndex?, Int) -> [PeerViewEntry], fetchLater: (PeerViewEntryIndex?, Int) -> [PeerViewEntry]) {
        if context.removedEntries && self.entries.count != self.count {
            var addedEntries: [PeerViewEntry] = []
            
            var latestAnchor: PeerViewEntryIndex?
            
            if self.entries.count != 0 {
                latestAnchor = PeerViewEntryIndex(self.entries[self.entries.count - 1])
            } else if let later = self.later {
                latestAnchor = PeerViewEntryIndex(later)
            }

            if let later = self.later {
                addedEntries += fetchLater(PeerViewEntryIndex(later).earlier(), self.count)
            }
            if let earlier = self.earlier {
                addedEntries += fetchEarlier(PeerViewEntryIndex(earlier).later(), self.count)
            }
            
            addedEntries += self.entries
            addedEntries.sort({ PeerViewEntryIndex($0) < PeerViewEntryIndex($1) })
            
            var i = addedEntries.count - 1
            while i >= 1 {
                if PeerViewEntryIndex(addedEntries[i]) == PeerViewEntryIndex(addedEntries[i - 1]) {
                    addedEntries.removeAtIndex(i)
                }
                i--
            }
            self.entries = []
            
            var anchorIndex = addedEntries.count - 1
            if let latestAnchor = latestAnchor {
                var i = addedEntries.count - 1
                while i >= 0 {
                    if PeerViewEntryIndex(addedEntries[i]) <= latestAnchor {
                        anchorIndex = i
                        break
                    }
                    i--
                }
            }
            
            self.later = nil
            if anchorIndex + 1 < addedEntries.count {
                var i = anchorIndex + 1
                while i < addedEntries.count {
                    self.later = addedEntries[i]
                    break
                }
            }
            
            i = anchorIndex
            while i >= 0 && i > anchorIndex - self.count {
                self.entries.insert(addedEntries[i], atIndex: 0)
                i--
            }
            
            self.earlier = nil
            if anchorIndex - self.count >= 0 {
                i = anchorIndex - self.count
                while i >= 0 {
                    self.earlier = addedEntries[i]
                    break
                }
            }
        } else {
            var earlyIndex: PeerViewEntryIndex?
            if self.entries.count != 0 {
                earlyIndex = PeerViewEntryIndex(self.entries[0])
            }
            
            let earlierEntries = fetchEarlier(earlyIndex, 1)
            if earlierEntries.count == 0 {
                self.earlier = nil
            } else {
                self.earlier = earlierEntries[0]
            }
            
            var lateIndex: PeerViewEntryIndex?
            if self.entries.count != 0 {
                lateIndex = PeerViewEntryIndex(self.entries[self.entries.count - 1])
            }
            
            let laterEntries = fetchLater(lateIndex, 1)
            if laterEntries.count == 0 {
                self.later = nil
            } else {
                self.later = laterEntries[0]
            }
        }
    }
    
    public var description: String {
        var string = ""
        
        if let earlier = self.earlier {
            string += "more("
            string += "(p \(earlier.peer.id.namespace):\(earlier.peer.id.id), m \(earlier.message.id.namespace):\(earlier.message.id.id)—\(earlier.message.timestamp)"
            string += ") "
        }
        
        string += "["
        var first = true
        for entry in self.entries {
            if first {
                first = false
            } else {
                string += ", "
            }
            string += "(p \(entry.peer.id.namespace):\(entry.peer.id.id), m \(entry.message.id.namespace):\(entry.message.id.id)—\(entry.message.timestamp))"
        }
        string += "]"
        
        if let later = self.later {
            string += " more("
            string += "(p \(later.peer.id.namespace):\(later.peer.id.id), m \(later.message.id.namespace):\(later.message.id.id)—\(later.message.timestamp)"
            string += ")"
        }
        
        return string
    }
}
