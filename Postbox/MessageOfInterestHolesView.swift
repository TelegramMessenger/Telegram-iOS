import Foundation

private func getAnchorId(postbox: Postbox, peerId: PeerId, namespace: MessageId.Namespace) -> MessageId? {
    if let readState = postbox.readStateTable.getCombinedState(peerId) {
        loop: for (stateNamespace, state) in readState.states {
            if stateNamespace == namespace {
                if case let .idBased(maxIncomingReadId, _, _, _) = state {
                    return MessageId(peerId: peerId, namespace: namespace, id: maxIncomingReadId)
                }
                break loop
            }
        }
    }
    return nil
}

private struct HolesViewEntry {
    let id: MessageId
    let hole: MessageHistoryHole?
    
    init(id: MessageId, hole: MessageHistoryHole?) {
        self.id = id
        self.hole = hole
    }
    
    init(_ entry: HistoryIndexEntry) {
        switch entry {
            case let .Message(index):
                self.id = index.id
                self.hole = nil
            case let .Hole(hole):
                self.id = hole.maxIndex.id
                self.hole = hole
        }
    }
}

private func fetchEntries(postbox: Postbox, anchor: MessageId, count: Int) -> (entries: [HolesViewEntry], earlier: MessageId?, later: MessageId?) {
    let (entries, earlier, later) = postbox.messageHistoryIndexTable.entriesAround(id: anchor, count: count)
    return (entries.map(HolesViewEntry.init), earlier?.index.id, later?.index.id)
}

private func fetchLater(postbox: Postbox, id: MessageId, count: Int) -> [HolesViewEntry] {
    return postbox.messageHistoryIndexTable.laterEntries(id: id, count: count).map(HolesViewEntry.init)
}

private func fetchEarlier(postbox: Postbox, id: MessageId, count: Int) -> [HolesViewEntry] {
    return postbox.messageHistoryIndexTable.earlierEntries(id: id, count: count).map(HolesViewEntry.init)
}

public struct MessageOfInterestHole: Hashable, Equatable {
    public let hole: MessageHistoryHole
    public let direction: MessageHistoryViewRelativeHoleDirection
    
    public static func ==(lhs: MessageOfInterestHole, rhs: MessageOfInterestHole) -> Bool {
        return lhs.hole == rhs.hole && lhs.direction == rhs.direction
    }
    
    public var hashValue: Int {
        return self.hole.maxIndex.hashValue &* 31 &+ self.hole.min.hashValue
    }
}

final class MutableMessageOfInterestHolesView: MutablePostboxView {
    private let peerId: PeerId
    private let namespace: MessageId.Namespace
    private let count: Int
    
    private var anchorId: MessageId?
    
    private var earlier: MessageId?
    private var later: MessageId?
    private var entries: [HolesViewEntry] = []
    
    fileprivate var closestHole: MessageOfInterestHole?
    
    init(postbox: Postbox, peerId: PeerId, namespace: MessageId.Namespace, count: Int) {
        self.peerId = peerId
        self.namespace = namespace
        self.count = count
        self.anchorId = getAnchorId(postbox: postbox, peerId: self.peerId, namespace: self.namespace)
        if let anchorId = self.anchorId {
            let (entries, earlier, later) = fetchEntries(postbox: postbox, anchor: anchorId, count: self.count)
            self.entries = entries
            self.earlier = earlier
            self.later = later
            
            self.closestHole = self.firstHole()
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        var anchorUpdated = false
        if transaction.peerIdsWithUpdatedCombinedReadStates.contains(self.peerId) {
            let anchorId = getAnchorId(postbox: postbox, peerId: self.peerId, namespace: self.namespace)
            if self.anchorId != anchorId {
                self.anchorId = anchorId
                anchorUpdated = true
            }
        }
        if anchorUpdated {
            if self.peerId.id == 1076840162 {
                assert(true)
            }
            
            if let anchorId = self.anchorId {
                let (entries, earlier, later) = fetchEntries(postbox: postbox, anchor: anchorId, count: self.count)
                self.entries = entries
                self.earlier = earlier
                self.later = later
            } else {
                self.entries = []
                self.earlier = nil
                self.later = nil
            }
            updated = true
        } else if let operations = transaction.currentOperationsByPeerId[self.peerId] {
            var invalidEarlier = false
            var invalidLater = false
            var removedEntries = false
            var hasChanges = false
            
            for operation in operations {
                switch operation {
                    case let .InsertHole(hole):
                        if hole.id.namespace == self.namespace {
                            if self.add(HolesViewEntry(id: hole.maxIndex.id, hole: hole)) {
                                hasChanges = true
                            }
                        }
                    case let .InsertMessage(intermediateMessage):
                        if intermediateMessage.id.namespace == self.namespace {
                            if self.add(HolesViewEntry(id: intermediateMessage.id, hole: nil)) {
                                hasChanges = true
                            }
                        }
                    case let .Remove(indices):
                        if self.remove(indices, invalidEarlier: &invalidEarlier, invalidLater: &invalidLater, removedEntries: &removedEntries) {
                            hasChanges = true
                        }
                    default:
                        break
                }
            }
            
            if hasChanges {
                updated = true
                
                if let anchorId = self.anchorId {
                    if removedEntries && self.entries.count < self.count {
                        if self.entries.count == 0 {
                            let (entries, earlier, later) = fetchEntries(postbox: postbox, anchor: anchorId, count: self.count)
                            self.entries = entries
                            self.earlier = earlier
                            self.later = later
                        } else {
                            let fetchedLaterEntries = fetchLater(postbox: postbox, id: self.entries.last!.id, count: self.count + 1)
                            self.entries.append(contentsOf: fetchedLaterEntries)
                            
                            let fetchedEarlierEntries = fetchEarlier(postbox: postbox, id: self.entries[0].id, count: self.count + 1)
                            for entry in fetchedEarlierEntries {
                                self.entries.insert(entry, at: 0)
                            }
                        }
                    }
                    
                    var centerIndex: Int?
                    
                    for i in 0 ..< self.entries.count {
                        if self.entries[i].id >= anchorId {
                            centerIndex = i
                            break
                        }
                    }
                    
                    if let centerIndex = centerIndex {
                        var minIndex = centerIndex
                        var maxIndex = centerIndex
                        let upperBound = self.entries.count - 1
                        var count = 1
                        while true {
                            if minIndex != 0 {
                                minIndex -= 1
                                count += 1
                            }
                            if count >= self.count {
                                break
                            }
                            if maxIndex != upperBound {
                                maxIndex += 1
                                count += 1
                            }
                            if count >= self.count {
                                break
                            }
                            if minIndex == 0 && maxIndex == upperBound {
                                break
                            }
                        }
                        if maxIndex != upperBound {
                            self.later = self.entries[maxIndex + 1].id
                            invalidLater = false
                            self.entries.removeLast(upperBound - maxIndex)
                        } else {
                            invalidLater = true
                        }
                        if minIndex != 0 {
                            self.earlier = self.entries[minIndex - 1].id
                            invalidEarlier = false
                            self.entries.removeFirst(minIndex)
                        } else {
                            invalidEarlier = true
                        }
                    }
                    
                    if invalidEarlier {
                        if !self.entries.isEmpty {
                            let earlyId = self.entries[0].id
                            self.earlier = fetchEarlier(postbox: postbox, id: earlyId, count: 1).first?.id
                        } else {
                            self.earlier = nil
                        }
                    }
                    
                    if invalidLater {
                        if !self.entries.isEmpty {
                            let lateId = self.entries.last!.id
                            self.later = fetchLater(postbox: postbox, id: lateId, count: 1).first?.id
                        } else {
                            self.later = nil
                        }
                    }
                } else {
                    self.entries = []
                    self.earlier = nil
                    self.later = nil
                }
            }
        }
        
        if updated {
            if self.peerId.id == 1076840162 {
                assert(true)
            }
            let closestHole = self.firstHole()
            if closestHole != self.closestHole {
                self.closestHole = closestHole
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    private func add(_ entry: HolesViewEntry) -> Bool {
        let updated: Bool
        
        if self.entries.count == 0 {
            self.entries.append(entry)
            updated = true
        } else {
            let latestId = self.entries[self.entries.count - 1].id
            let earliestId = self.entries[0].id
            
            let id = entry.id
            
            if id < earliestId {
                if self.earlier == nil || self.earlier! < id {
                    self.entries.insert(entry, at: 0)
                    updated = true
                } else {
                    updated = false
                }
            } else if id > latestId {
                if let later = self.later {
                    if id < later {
                        self.entries.append(entry)
                        updated = true
                    } else {
                        updated = false
                    }
                } else {
                    self.entries.append(entry)
                    updated = true
                }
            } else if id != earliestId && id != latestId {
                var i = self.entries.count
                while i >= 1 {
                    if self.entries[i - 1].id < id {
                        break
                    }
                    i -= 1
                }
                self.entries.insert(entry, at: i)
                updated = true
            } else {
                updated = false
            }
        }
        
        return updated
    }
    
    private func remove(_ indicesAndFlags: [(MessageIndex, Bool, MessageTags)], invalidEarlier: inout Bool, invalidLater: inout Bool, removedEntries: inout Bool) -> Bool {
        let ids = Set(indicesAndFlags.map { $0.0.id })
        var hasChanges = false
        if let earlier = self.earlier, ids.contains(earlier) {
            invalidEarlier = true
            hasChanges = true
        }
        
        if let later = self.later, ids.contains(later) {
            invalidLater = true
            hasChanges = true
        }
        
        if self.entries.count != 0 {
            var i = self.entries.count - 1
            while i >= 0 {
                let entry = self.entries[i]
                if ids.contains(entry.id) {
                    self.entries.remove(at: i)
                    removedEntries = true
                    hasChanges = true
                }
                i -= 1
            }
        }
        
        return hasChanges
    }
    
    private func firstHole() -> MessageOfInterestHole? {
        if self.entries.isEmpty {
            return nil
        }
        guard let anchorId = self.anchorId else {
            return nil
        }
        
        var referenceIndex = self.entries.count - 1
        for i in 0 ..< self.entries.count {
            if self.entries[i].id >= anchorId {
                referenceIndex = i
                break
            }
        }
        
        var i = referenceIndex
        var j = referenceIndex + 1
        
        while i >= 0 || j < self.entries.count {
            if j < self.entries.count {
                if let hole = self.entries[j].hole {
                    if anchorId.id >= hole.min && anchorId.id <= hole.maxIndex.id.id {
                        return MessageOfInterestHole(hole: hole, direction: .AroundId(anchorId))
                    }
                    
                    return MessageOfInterestHole(hole: hole, direction: hole.maxIndex.id <= anchorId ? .UpperToLower : .LowerToUpper)
                }
            }
            
            if i >= 0 {
                if let hole = self.entries[i].hole {
                    if anchorId.id >= hole.min && anchorId.id <= hole.maxIndex.id.id {
                        return MessageOfInterestHole(hole: hole, direction: .AroundId(anchorId))
                    }
                    
                    return MessageOfInterestHole(hole: hole, direction: hole.maxIndex.id <= anchorId ? .UpperToLower : .LowerToUpper)
                }
            }
            
            i -= 1
            j += 1
        }
        
        return nil
    }
    
    func immutableView() -> PostboxView {
        return MessageOfInterestHolesView(self)
    }
}

public final class MessageOfInterestHolesView: PostboxView {
    public let closestHole: MessageOfInterestHole?
    
    init(_ view: MutableMessageOfInterestHolesView) {
        self.closestHole = view.closestHole
    }
}

