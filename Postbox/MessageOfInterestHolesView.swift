import Foundation

private enum MessageOfInterestLocation: Equatable {
    case id(MessageId)
    case index(MessageIndex)
    
    static func ==(lhs: MessageOfInterestLocation, rhs: MessageOfInterestLocation) -> Bool {
        switch lhs {
            case let .id(value):
                if case .id(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .index(value):
                if case .index(value) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private func getAnchorId(postbox: Postbox, location: MessageOfInterestViewLocation, namespace: MessageId.Namespace) -> MessageOfInterestLocation? {
    switch location {
        case let .peer(peerId):
            if let readState = postbox.readStateTable.getCombinedState(peerId) {
                loop: for (stateNamespace, state) in readState.states {
                    if stateNamespace == namespace {
                        if case let .idBased(maxIncomingReadId, _, _, _, _) = state {
                            return .id(MessageId(peerId: peerId, namespace: namespace, id: maxIncomingReadId))
                        }
                        break loop
                    }
                }
            }
        case let .group(groupId):
            if let state = postbox.groupFeedReadStateTable.get(groupId) {
                return .index(state.maxReadIndex)
            }
    }
    return nil
}

private struct HolesViewEntryHole {
    let hole: MessageHistoryHole
    let lowerIndex: MessageIndex?
}

private enum HolesViewEntryMedia {
    case media(authorId: PeerId?, [Media])
    case intermediate(authorId: PeerId?, [MediaId], ReadBuffer)
}

public struct HolesViewMedia: Comparable {
    public let media: Media
    public let peer: Peer
    public let authorIsContact: Bool
    public let index: MessageIndex
    
    public static func ==(lhs: HolesViewMedia, rhs: HolesViewMedia) -> Bool {
        return lhs.index == rhs.index && (lhs.media === rhs.media || lhs.media.isEqual(to: rhs.media)) && lhs.peer.isEqual(rhs.peer) && lhs.authorIsContact == rhs.authorIsContact
    }
    
    public static func <(lhs: HolesViewMedia, rhs: HolesViewMedia) -> Bool {
        return lhs.index < rhs.index
    }
}

private struct HolesViewEntry {
    let index: MessageIndex
    let hole: HolesViewEntryHole?
    var media: HolesViewEntryMedia?
    
    init(index: MessageIndex, hole: HolesViewEntryHole?, media: HolesViewEntryMedia?) {
        self.index = index
        self.hole = hole
        self.media = media
    }
    
    init(_ entry: IntermediateMessageHistoryEntry) {
        switch entry {
            case let .Message(message):
                self.index = MessageIndex(message)
                self.hole = nil
                self.media = .intermediate(authorId: message.authorId, message.referencedMedia, message.embeddedMediaData)
            case let .Hole(hole, lowerIndex):
                self.index = hole.maxIndex
                self.hole = HolesViewEntryHole(hole: hole, lowerIndex: lowerIndex)
                self.media = nil
        }
    }
}

private func entriesFromIndexEntries(entries: [HistoryIndexEntry], postbox: Postbox) -> [HolesViewEntry] {
    return entries.compactMap { entry -> HolesViewEntry? in
        switch entry {
            case let .Message(index):
                guard let message = postbox.messageHistoryTable.getMessage(entry.index) else {
                    return nil
                }
                return HolesViewEntry(index: index, hole: nil, media: .intermediate(authorId: message.authorId, message.referencedMedia, message.embeddedMediaData))
            case let .Hole(hole):
                return HolesViewEntry(index: hole.maxIndex, hole: HolesViewEntryHole(hole: hole, lowerIndex: nil), media: nil)
        }
    }
}

private func fetchEntries(postbox: Postbox, location: MessageOfInterestViewLocation, anchor: MessageOfInterestLocation, count: Int) -> (entries: [HolesViewEntry], earlier: MessageIndex?, later: MessageIndex?) {
    switch location {
        case let .peer(peerId):
            switch anchor {
                case let .id(id):
                    assert(peerId == id.peerId)
                    let (entries, earlier, later) = postbox.messageHistoryIndexTable.entriesAround(id: id, count: count)
                    return (entriesFromIndexEntries(entries: entries, postbox: postbox), earlier?.index, later?.index)
                case let .index(index):
                    assert(peerId == index.id.peerId)
                    let (entries, earlier, later) = postbox.messageHistoryIndexTable.entriesAround(id: index.id, count: count)
                    return (entriesFromIndexEntries(entries: entries, postbox: postbox), earlier?.index, later?.index)
            }
        case let .group(groupId):
            switch anchor {
                case let .index(index):
                    let (entries, earlier, later) = postbox.groupFeedIndexTable.entriesAround(groupId: groupId, index: index, count: count, messageHistoryTable: postbox.messageHistoryTable)
                    return (entries.map(HolesViewEntry.init), earlier?.index, later?.index)
                default:
                    assertionFailure()
                    return ([], nil, nil)
            }
    }
}

private func fetchLater(postbox: Postbox, location: MessageOfInterestViewLocation, anchor: MessageOfInterestLocation, count: Int) -> [HolesViewEntry] {
    switch location {
        case let .peer(peerId):
            switch anchor {
                case let .id(id):
                    assert(id.peerId == peerId)
                    return entriesFromIndexEntries(entries: postbox.messageHistoryIndexTable.laterEntries(id: id, count: count), postbox: postbox)
                case let .index(index):
                    assert(index.id.peerId == peerId)
                    return entriesFromIndexEntries(entries: postbox.messageHistoryIndexTable.laterEntries(id: index.id, count: count), postbox: postbox)
            }
        case let .group(groupId):
            switch anchor {
                case let .index(index):
                    return postbox.groupFeedIndexTable.laterEntries(groupId: groupId, index: index, count: count, messageHistoryTable: postbox.messageHistoryTable).map(HolesViewEntry.init)
                default:
                    assertionFailure()
                    return []
            }
    }
}

private func fetchEarlier(postbox: Postbox, location: MessageOfInterestViewLocation, anchor: MessageOfInterestLocation, count: Int) -> [HolesViewEntry] {
    switch location {
        case let .peer(peerId):
            switch anchor {
                case let .id(id):
                    assert(id.peerId == peerId)
                    return entriesFromIndexEntries(entries: postbox.messageHistoryIndexTable.earlierEntries(id: id, count: count), postbox: postbox)
                case let .index(index):
                    assert(index.id.peerId == peerId)
                    return entriesFromIndexEntries(entries: postbox.messageHistoryIndexTable.earlierEntries(id: index.id, count: count), postbox: postbox)
            }
        case let .group(groupId):
            switch anchor {
                case let .index(index):
                    return postbox.groupFeedIndexTable.earlierEntries(groupId: groupId, index: index, count: count, messageHistoryTable: postbox.messageHistoryTable).map(HolesViewEntry.init)
                default:
                    assertionFailure()
                    return []
            }
    }
}

public struct MessageOfInterestHole: Hashable, Equatable {
    public let hole: MessageHistoryViewHole
    public let direction: MessageHistoryViewRelativeHoleDirection
    
    public static func ==(lhs: MessageOfInterestHole, rhs: MessageOfInterestHole) -> Bool {
        return lhs.hole == rhs.hole && lhs.direction == rhs.direction
    }
    
    public var hashValue: Int {
        return self.hole.hashValue
    }
}

public enum MessageOfInterestViewLocation: Hashable {
    case peer(PeerId)
    case group(PeerGroupId)
    
    public static func ==(lhs: MessageOfInterestViewLocation, rhs: MessageOfInterestViewLocation) -> Bool {
        switch lhs {
            case let .peer(value):
                if case .peer(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .group(value):
                if case .group(value) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public var hashValue: Int {
        switch self {
            case let .peer(id):
                return id.hashValue
            case let .group(id):
                return id.hashValue
        }
    }
}

private func isGreaterOrEqual(index: MessageIndex, than location: MessageOfInterestLocation) -> Bool {
    switch location {
        case let .id(id):
            return index.id >= id
        case let .index(locationIndex):
            return index >= locationIndex
    }
}

final class MutableMessageOfInterestHolesView: MutablePostboxView {
    private let location: MessageOfInterestViewLocation
    private let namespace: MessageId.Namespace
    private let count: Int
    
    private var anchorLocation: MessageOfInterestLocation?
    
    private var earlier: MessageIndex?
    private var later: MessageIndex?
    private var entries: [HolesViewEntry] = []
    
    fileprivate var closestHole: MessageOfInterestHole?
    fileprivate var closestLaterMedia: [HolesViewMedia] = []
    
    init(postbox: Postbox, location: MessageOfInterestViewLocation, namespace: MessageId.Namespace, count: Int) {
        self.location = location
        self.namespace = namespace
        self.count = count
        self.anchorLocation = getAnchorId(postbox: postbox, location: self.location, namespace: self.namespace)
        if let anchorLocation = self.anchorLocation {
            let (entries, earlier, later) = fetchEntries(postbox: postbox, location: self.location, anchor: anchorLocation, count: self.count)
            self.entries = entries
            self.earlier = earlier
            self.later = later
            
            self.closestHole = self.firstHole()
            self.closestLaterMedia = self.topLaterMedia(postbox: postbox)
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        var anchorUpdated = false
        switch self.location {
            case let .peer(peerId):
                if transaction.alteredInitialPeerCombinedReadStates[peerId] != nil {
                    let anchorLocation = getAnchorId(postbox: postbox, location: self.location, namespace: self.namespace)
                    if self.anchorLocation != anchorLocation {
                        self.anchorLocation = anchorLocation
                        anchorUpdated = true
                    }
                }
            case let .group(groupId):
                if transaction.currentGroupFeedReadStateContext.updatedStates[groupId] != nil {
                    let anchorLocation = getAnchorId(postbox: postbox, location: self.location, namespace: self.namespace)
                    if self.anchorLocation != anchorLocation {
                        self.anchorLocation = anchorLocation
                        anchorUpdated = true
                    }
                }
        }
        if anchorUpdated {
            if let anchorLocation = self.anchorLocation {
                let (entries, earlier, later) = fetchEntries(postbox: postbox, location: self.location, anchor: anchorLocation, count: self.count)
                self.entries = entries
                self.earlier = earlier
                self.later = later
            } else {
                self.entries = []
                self.earlier = nil
                self.later = nil
            }
            updated = true
        } else {
            var invalidEarlier = false
            var invalidLater = false
            var removedEntries = false
            var hasChanges = false
            
            switch self.location {
                case let .peer(peerId):
                    if let operations = transaction.currentOperationsByPeerId[peerId] {
                        for operation in operations {
                            switch operation {
                                case let .InsertHole(hole):
                                    if hole.id.namespace == self.namespace {
                                        if self.add(HolesViewEntry(index: hole.maxIndex, hole: HolesViewEntryHole(hole: hole, lowerIndex: nil), media: nil)) {
                                            hasChanges = true
                                        }
                                    }
                                case let .InsertMessage(intermediateMessage):
                                    if intermediateMessage.id.namespace == self.namespace {
                                        if self.add(HolesViewEntry(index: MessageIndex(intermediateMessage), hole: nil, media: .intermediate(authorId: intermediateMessage.authorId, intermediateMessage.referencedMedia, intermediateMessage.embeddedMediaData))) {
                                            hasChanges = true
                                        }
                                    }
                                case let .UpdateEmbeddedMedia(index, embeddedMedia):
                                    break
                                case let .Remove(indices):
                                    if self.remove(indices, invalidEarlier: &invalidEarlier, invalidLater: &invalidLater, removedEntries: &removedEntries) {
                                        hasChanges = true
                                    }
                                default:
                                    break
                            }
                        }
                    }
                case let .group(groupId):
                    if let operations = transaction.currentGroupFeedOperations[groupId] {
                        for operation in operations {
                            switch operation {
                                case let .insertMessage(message):
                                    if self.add(HolesViewEntry(index: MessageIndex(message), hole: nil, media: .intermediate(authorId: message.authorId, message.referencedMedia, message.embeddedMediaData))) {
                                        hasChanges = true
                                    }
                                case let .insertHole(hole, lowerIndex):
                                    if self.add(HolesViewEntry(index: hole.maxIndex, hole: HolesViewEntryHole(hole: hole, lowerIndex: lowerIndex), media: nil)) {
                                        hasChanges = true
                                    }
                                case let .removeMessage(index):
                                    if self.remove([(index, false, [])], invalidEarlier: &invalidEarlier, invalidLater: &invalidLater, removedEntries: &removedEntries) {
                                        hasChanges = true
                                    }
                                case let .removeHole(index):
                                    if self.remove([(index, false, [])], invalidEarlier: &invalidEarlier, invalidLater: &invalidLater, removedEntries: &removedEntries) {
                                        hasChanges = true
                                    }
                            }
                        }
                    }
            }
            
            if hasChanges {
                updated = true
                
                if let anchorLocation = self.anchorLocation {
                    if removedEntries && self.entries.count < self.count {
                        if self.entries.count == 0 {
                            let (entries, earlier, later) = fetchEntries(postbox: postbox, location: self.location, anchor: anchorLocation, count: self.count)
                            self.entries = entries
                            self.earlier = earlier
                            self.later = later
                        } else {
                            let fetchedLaterEntries = fetchLater(postbox: postbox, location: self.location, anchor: .index(self.entries.last!.index), count: self.count + 1)
                            self.entries.append(contentsOf: fetchedLaterEntries)
                            
                            let fetchedEarlierEntries = fetchEarlier(postbox: postbox, location: self.location, anchor: .index(self.entries[0].index), count: self.count + 1)
                            for entry in fetchedEarlierEntries {
                                self.entries.insert(entry, at: 0)
                            }
                        }
                    }
                    
                    var centerIndex: Int?
                    
                    for i in 0 ..< self.entries.count {
                        if isGreaterOrEqual(index: self.entries[i].index, than: anchorLocation) {
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
                            self.later = self.entries[maxIndex + 1].index
                            invalidLater = false
                            self.entries.removeLast(upperBound - maxIndex)
                        } else {
                            invalidLater = true
                        }
                        if minIndex != 0 {
                            self.earlier = self.entries[minIndex - 1].index
                            invalidEarlier = false
                            self.entries.removeFirst(minIndex)
                        } else {
                            invalidEarlier = true
                        }
                    }
                    
                    if invalidEarlier {
                        if !self.entries.isEmpty {
                            let earlyIndex = self.entries[0].index
                            self.earlier = fetchEarlier(postbox: postbox, location: self.location, anchor: .index(earlyIndex), count: 1).first?.index
                        } else {
                            self.earlier = nil
                        }
                    }
                    
                    if invalidLater {
                        if !self.entries.isEmpty {
                            let lateIndex = self.entries.last!.index
                            self.later = fetchLater(postbox: postbox, location: self.location, anchor: .index(lateIndex), count: 1).first?.index
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
            var updatedResult = false
            let closestHole = self.firstHole()
            if closestHole != self.closestHole {
                self.closestHole = closestHole
                updatedResult = true
            }
            
            let closestLaterMedia = self.topLaterMedia(postbox: postbox)
            updatedResult = true
            if closestLaterMedia.count != self.closestLaterMedia.count {
                updatedResult = true
            } else {
                for i in 0 ..< closestLaterMedia.count {
                    if closestLaterMedia[i] != self.closestLaterMedia[i] {
                        updatedResult = true
                        break
                    }
                }
            }
            self.closestLaterMedia = closestLaterMedia
            
            return updatedResult
        } else {
            return false
        }
    }
    
    private func topLaterMedia(postbox: Postbox) -> [HolesViewMedia] {
        guard let anchorLocation = self.anchorLocation else {
            return []
        }
        let index: MessageIndex
        switch anchorLocation {
            case let .id(id):
                guard let anchorIndex = postbox.messageHistoryTable.anchorIndex(id) else {
                    return []
                }
                switch anchorIndex {
                    case let .message(value, _):
                        index = value
                    case .lowerBound:
                        index = MessageIndex.lowerBound(peerId: id.peerId)
                    case .upperBound:
                        index = MessageIndex.upperBound(peerId: id.peerId)
                }
            case let .index(value):
                index = value
        }
        var result: [HolesViewMedia] = []
        for i in 0 ..< self.entries.count {
            let entry = self.entries[i]
            guard entry.index > index, let media = entry.media else {
                continue
            }
            switch media {
                case let .media(authorId, media):
                    for m in media {
                        if m.id != nil, let peer = postbox.peerTable.get(index.id.peerId) {
                            var isContact = false
                            if let authorId = authorId {
                                isContact = postbox.contactsTable.isContact(peerId: authorId)
                            }
                            result.append(HolesViewMedia(media: m, peer: peer, authorIsContact: isContact, index: index))
                        }
                    }
                case let .intermediate(authorId, ids, data):
                    if ids.isEmpty && data.length <= 4 {
                        continue
                    }
                    var itemMedia: [Media] = []
                    for item in postbox.messageHistoryTable.renderMessageMedia(referencedMedia: ids, embeddedMediaData: data) {
                        if item.id != nil, let peer = postbox.peerTable.get(index.id.peerId) {
                            var isContact = false
                            if let authorId = authorId {
                                isContact = postbox.contactsTable.isContact(peerId: authorId)
                            }
                            result.append(HolesViewMedia(media: item, peer: peer, authorIsContact: isContact, index: entry.index))
                            itemMedia.append(item)
                        }
                    }
                    if itemMedia.isEmpty {
                        entries[i].media = nil
                    } else {
                        entries[i].media = .media(authorId: authorId, itemMedia)
                    }
            }
            
            if result.count >= 3 {
                break
            }
        }
        return result
    }
    
    private func add(_ entry: HolesViewEntry) -> Bool {
        let updated: Bool
        
        if self.entries.count == 0 {
            self.entries.append(entry)
            updated = true
        } else {
            let latestIndex = self.entries[self.entries.count - 1].index
            let earliestIndex = self.entries[0].index
            
            let index = entry.index
            
            if index < earliestIndex {
                if self.earlier == nil || self.earlier! < index {
                    self.entries.insert(entry, at: 0)
                    updated = true
                } else {
                    updated = false
                }
            } else if index > latestIndex {
                if let later = self.later {
                    if index < later {
                        self.entries.append(entry)
                        updated = true
                    } else {
                        updated = false
                    }
                } else {
                    self.entries.append(entry)
                    updated = true
                }
            } else if index != earliestIndex && index != latestIndex {
                var i = self.entries.count
                while i >= 1 {
                    if self.entries[i - 1].index < index {
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
        let indices = Set(indicesAndFlags.map { $0.0 })
        var hasChanges = false
        if let earlier = self.earlier, indices.contains(earlier) {
            invalidEarlier = true
            hasChanges = true
        }
        
        if let later = self.later, indices.contains(later) {
            invalidLater = true
            hasChanges = true
        }
        
        if self.entries.count != 0 {
            var i = self.entries.count - 1
            while i >= 0 {
                let entry = self.entries[i]
                if indices.contains(entry.index) {
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
        guard let anchorLocation = self.anchorLocation else {
            return nil
        }
        
        var referenceIndex = self.entries.count - 1
        for i in 0 ..< self.entries.count {
            if isGreaterOrEqual(index: self.entries[i].index, than: anchorLocation) {
                referenceIndex = i
                break
            }
        }
        
        var i = referenceIndex
        var j = referenceIndex + 1
        
        let lowerI = max(0, referenceIndex - 50)
        let upperJ = min(referenceIndex + 50, self.entries.count)
        
        switch self.location {
            case let .group(groupId):
                while i >= lowerI || j < upperJ {
                    if j < upperJ {
                        if let hole = self.entries[j].hole {
                            switch anchorLocation {
                                case let .index(index):
                                    if let lowerIndex = hole.lowerIndex {
                                        if index >= lowerIndex && index <= hole.hole.maxIndex {
                                            return MessageOfInterestHole(hole: .groupFeed(groupId, lowerIndex: lowerIndex, upperIndex: hole.hole.maxIndex), direction: .AroundIndex(index))
                                        }
                                    } else {
                                        assertionFailure()
                                    }
                                default:
                                    break
                            }
                            
                            if let lowerIndex = hole.lowerIndex {
                                return MessageOfInterestHole(hole: .groupFeed(groupId, lowerIndex: lowerIndex, upperIndex: hole.hole.maxIndex), direction: isGreaterOrEqual(index: hole.hole.maxIndex, than: anchorLocation) ? .LowerToUpper : .UpperToLower)
                            } else {
                                assertionFailure()
                            }
                        }
                    }
                    
                    if i >= lowerI  {
                        if let hole = self.entries[i].hole {
                            switch anchorLocation {
                                case let .index(index):
                                    if let lowerIndex = hole.lowerIndex {
                                        if index >= lowerIndex && index <= hole.hole.maxIndex {
                                            return MessageOfInterestHole(hole: .groupFeed(groupId, lowerIndex: lowerIndex, upperIndex: hole.hole.maxIndex), direction: .AroundIndex(index))
                                        }
                                        
                                        if hole.hole.maxIndex.timestamp >= Int32.max - 1 && index.timestamp >= Int32.max - 1 {
                                            return MessageOfInterestHole(hole: .groupFeed(groupId, lowerIndex: lowerIndex, upperIndex: hole.hole.maxIndex), direction: .UpperToLower)
                                        }
                                    } else {
                                        assertionFailure()
                                    }
                                default:
                                    break
                            }
                            
                            /*if case .upperBound = self.anchorIndex, hole.maxIndex.timestamp >= Int32.max - 1 {
                                if case let .group(groupId) = self.peerIds {
                                    if let lowerIndex = lowerIndex {
                                        return (.groupFeed(groupId, lowerIndex: lowerIndex, upperIndex: hole.maxIndex), .UpperToLower)
                                    }
                                } else {
                                    return (.peer(hole), .UpperToLower)
                                }
                            } else {*/
                                if let lowerIndex = hole.lowerIndex {
                                    return MessageOfInterestHole(hole: .groupFeed(groupId, lowerIndex: lowerIndex, upperIndex: hole.hole.maxIndex), direction: isGreaterOrEqual(index: hole.hole.maxIndex, than: anchorLocation) ? .LowerToUpper : .UpperToLower)
                                }
                            //}
                        }
                    }
                    
                    i -= 1
                    j += 1
                }
            case .peer:
                let anchorId: MessageId
                switch anchorLocation {
                    case let .id(id):
                        anchorId = id
                    case let .index(index):
                        anchorId = index.id
                }
                while i >= lowerI || j < upperJ {
                    if j < upperJ {
                        if let hole = self.entries[j].hole {
                            if anchorId.id >= hole.hole.min && anchorId.id <= hole.hole.maxIndex.id.id {
                                return MessageOfInterestHole(hole: .peer(hole.hole), direction: .AroundId(anchorId))
                            }
                            
                            return MessageOfInterestHole(hole: .peer(hole.hole), direction: hole.hole.maxIndex.id <= anchorId ? .UpperToLower : .LowerToUpper)
                        }
                    }
                    
                    if i >= lowerI {
                        if let hole = self.entries[i].hole {
                            if anchorId.id >= hole.hole.min && anchorId.id <= hole.hole.maxIndex.id.id {
                                return MessageOfInterestHole(hole: .peer(hole.hole), direction: .AroundId(anchorId))
                            }
                            
                            return MessageOfInterestHole(hole: .peer(hole.hole), direction: hole.hole.maxIndex.id <= anchorId ? .UpperToLower : .LowerToUpper)
                        }
                    }
                    
                    i -= 1
                    j += 1
                }
        }
        
        return nil
    }
    
    func immutableView() -> PostboxView {
        return MessageOfInterestHolesView(self)
    }
}

public final class MessageOfInterestHolesView: PostboxView {
    public let closestHole: MessageOfInterestHole?
    public let closestLaterMedia: [HolesViewMedia]
    
    init(_ view: MutableMessageOfInterestHolesView) {
        self.closestHole = view.closestHole
        self.closestLaterMedia = view.closestLaterMedia
    }
}
