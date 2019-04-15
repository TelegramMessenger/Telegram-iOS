import Foundation

private enum MessageOfInterestLocation: Equatable {
    case id(MessageId)
    case index(MessageIndex)
    
    var messageId: MessageId {
        switch self {
            case let .id(id):
                return id
            case let .index(index):
                return index.id
        }
    }
    
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
    }
    return nil
}

private struct HoleKey: Hashable {
    let peerId: PeerId
    let namespace: MessageId.Namespace
}

private func fetchHoles(postbox: Postbox, peerIds: MessageHistoryViewPeerIds, tagMask: MessageTags?, entries: [HolesViewEntry], hasEarlier: Bool, hasLater: Bool) -> [HoleKey: IndexSet] {
    var peerIdsSet: [PeerId] = []
    switch peerIds {
        case let .single(peerId):
            peerIdsSet.append(peerId)
        case let .associated(peerId, associatedId):
            peerIdsSet.append(peerId)
            if let associatedId = associatedId {
                peerIdsSet.append(associatedId.peerId)
            }
    }
    var namespaceBounds: [(PeerId, MessageId.Namespace, ClosedRange<MessageId.Id>?)] = []
    for peerId in peerIdsSet {
        if let namespaces = postbox.seedConfiguration.messageHoles[peerId.namespace] {
            for namespace in namespaces.keys {
                var earlierId: MessageId.Id?
                earlier: for entry in entries {
                    if entry.index.id.peerId == peerId && entry.index.id.namespace == namespace {
                        earlierId = entry.index.id.id
                        break earlier
                    }
                }
                var laterId: MessageId.Id?
                later: for entry in entries.reversed() {
                    if entry.index.id.peerId == peerId && entry.index.id.namespace == namespace {
                        laterId = entry.index.id.id
                        break later
                    }
                }
                if let earlierId = earlierId, let laterId = laterId {
                    namespaceBounds.append((peerId, namespace, earlierId ... laterId))
                } else {
                    namespaceBounds.append((peerId, namespace, nil))
                }
            }
        }
    }
    let space: MessageHistoryHoleSpace = tagMask.flatMap(MessageHistoryHoleSpace.tag) ?? .everywhere
    var result: [HoleKey: IndexSet] = [:]
    for (peerId, namespace, bounds) in namespaceBounds {
        var indices = postbox.messageHistoryHoleIndexTable.closest(peerId: peerId, namespace: namespace, space: space, range: 1 ... Int32.max)
        if let bounds = bounds {
            if hasEarlier {
                indices.remove(integersIn: 1 ... Int(bounds.lowerBound))
            }
            if hasLater {
                indices.remove(integersIn: Int(bounds.upperBound) ... Int(Int32.max))
            }
        }
        if !indices.isEmpty {
            result[HoleKey(peerId: peerId, namespace: namespace)] = indices
        }
    }
    return result
}

private struct HolesViewEntryHole {
    let hole: MessageHistoryViewHole
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
    var media: HolesViewEntryMedia?
    
    init(index: MessageIndex, media: HolesViewEntryMedia?) {
        self.index = index
        self.media = media
    }
    
    init(_ entry: IntermediateMessageHistoryEntry) {
        self.index = entry.message.index
        self.media = .intermediate(authorId: entry.message.authorId, entry.message.referencedMedia, entry.message.embeddedMediaData)
    }
}

private func entriesFromIndexEntries(entries: [MessageIndex], postbox: Postbox) -> [HolesViewEntry] {
    return entries.compactMap { index -> HolesViewEntry? in
        guard let message = postbox.messageHistoryTable.getMessage(index) else {
            return nil
        }
        return HolesViewEntry(index: index, media: .intermediate(authorId: message.authorId, message.referencedMedia, message.embeddedMediaData))
    }
}

private func fetchEntries(postbox: Postbox, location: MessageOfInterestViewLocation, anchor: MessageOfInterestLocation, count: Int) -> (entries: [HolesViewEntry], earlier: MessageIndex?, later: MessageIndex?) {
    switch location {
        case let .peer(peerId):
            switch anchor {
                case let .id(id):
                    assert(peerId == id.peerId)
                    let (entries, earlier, later) = postbox.messageHistoryIndexTable.entriesAround(id: id, count: count)
                    return (entriesFromIndexEntries(entries: entries, postbox: postbox), earlier, later)
                case let .index(index):
                    assert(peerId == index.id.peerId)
                    let (entries, earlier, later) = postbox.messageHistoryIndexTable.entriesAround(id: index.id, count: count)
                    return (entriesFromIndexEntries(entries: entries, postbox: postbox), earlier, later)
            }
        /*case let .group(groupId):
            switch anchor {
                case let .index(index):
                    let (entries, earlier, later) = postbox.groupFeedIndexTable.entriesAround(groupId: groupId, index: index, count: count, messageHistoryTable: postbox.messageHistoryTable)
                    return (entries.map(HolesViewEntry.init), earlier?.index, later?.index)
                default:
                    assertionFailure()
                    return ([], nil, nil)
            }*/
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
    }
}

public struct MessageOfInterestHole: Hashable, Equatable {
    public let hole: MessageHistoryViewHole
    public let direction: MessageHistoryViewRelativeHoleDirection
}

public enum MessageOfInterestViewLocation: Hashable {
    case peer(PeerId)
    
    public static func ==(lhs: MessageOfInterestViewLocation, rhs: MessageOfInterestViewLocation) -> Bool {
        switch lhs {
            case let .peer(value):
                if case .peer(value) = rhs {
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
    private var holes: [HoleKey: IndexSet] = [:]
    
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
            
            switch self.location {
                case let .peer(peerId):
                    self.holes = fetchHoles(postbox: postbox, peerIds: .single(peerId), tagMask: nil, entries: self.entries, hasEarlier: self.earlier != nil, hasLater: self.later != nil)
            }
            
            self.closestHole = self.firstHole()
            self.closestLaterMedia = self.topLaterMedia(postbox: postbox)
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        var anchorUpdated = false
        switch self.location {
            case let .peer(peerId):
                for (key, _) in transaction.currentPeerHoleOperations {
                    if key.peerId == peerId {
                        anchorUpdated = true
                    }
                }
                if transaction.alteredInitialPeerCombinedReadStates[peerId] != nil {
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
            
            switch self.location {
                case let .peer(peerId):
                    self.holes = fetchHoles(postbox: postbox, peerIds: .single(peerId), tagMask: nil, entries: self.entries, hasEarlier: self.earlier != nil, hasLater: self.later != nil)
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
                                case let .InsertMessage(intermediateMessage):
                                    if intermediateMessage.id.namespace == self.namespace {
                                        if self.add(HolesViewEntry(index: intermediateMessage.index, media: .intermediate(authorId: intermediateMessage.authorId, intermediateMessage.referencedMedia, intermediateMessage.embeddedMediaData))) {
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
                
                switch self.location {
                    case let .peer(peerId):
                        self.holes = fetchHoles(postbox: postbox, peerIds: .single(peerId), tagMask: nil, entries: self.entries, hasEarlier: self.earlier != nil, hasLater: self.later != nil)
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
    
    private func remove(_ indicesAndFlags: [(MessageIndex, MessageTags)], invalidEarlier: inout Bool, invalidLater: inout Bool, removedEntries: inout Bool) -> Bool {
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
            if let (key, holeIndices) = self.holes.first {
                let hole = MessageHistoryViewPeerHole(peerId: key.peerId, namespace: key.namespace, indices: holeIndices)
                if let location = self.anchorLocation {
                    if location.messageId.peerId == key.peerId && location.messageId.namespace == key.namespace {
                        return MessageOfInterestHole(hole: .peer(hole), direction: .AroundId(location.messageId))
                    }
                } else {
                    return MessageOfInterestHole(hole: .peer(hole), direction: .UpperToLower)
                }
            }
            return nil
        }
        
        if let location = self.anchorLocation {
            let messageId = location.messageId
            for (holeKey, indices) in self.holes {
                if holeKey.peerId == messageId.peerId && holeKey.namespace == messageId.namespace && indices.contains(Int(messageId.id)) {
                    let hole = MessageHistoryViewPeerHole(peerId: messageId.peerId, namespace: messageId.namespace, indices: indices)
                    return MessageOfInterestHole(hole: .peer(hole), direction: .AroundId(messageId))
                }
            }
        }
        
        var referenceIndex = self.entries.count - 1
        /*for i in 0 ..< self.entries.count {
            if self.anchorLocation.isLessOrEqual(to: self.entries[i].index) {
                referenceIndex = i
                break
            }
        }*/
        
        var i = referenceIndex
        var j = referenceIndex + 1
        
        func processId(_ id: MessageId, toLower: Bool) -> MessageOfInterestHole? {
            if let holeIndices = self.holes[HoleKey(peerId: id.peerId, namespace: id.namespace)] {
                if holeIndices.contains(Int(id.id)) {
                    let hole = MessageHistoryViewPeerHole(peerId: id.peerId, namespace: id.namespace, indices: holeIndices)
                    if let anchorLocation = self.anchorLocation, anchorLocation.messageId.peerId == id.peerId && anchorLocation.messageId.namespace == id.namespace && holeIndices.contains(Int(anchorLocation.messageId.id)) {
                        return MessageOfInterestHole(hole: .peer(hole), direction: .AroundId(anchorLocation.messageId))
                    } else {
                        if toLower {
                            return MessageOfInterestHole(hole: .peer(hole), direction: .UpperToLower)
                        } else {
                            return MessageOfInterestHole(hole: .peer(hole), direction: .LowerToUpper)
                        }
                    }
                }
            }
            return nil
        }
        
        while i >= -1 || j <= self.entries.count {
            if j < self.entries.count {
                if let result = processId(entries[j].index.id, toLower: false) {
                    return result
                }
            }
            
            if i >= 0 {
                if let result = processId(entries[i].index.id, toLower: true) {
                    return result
                }
            }
            
            if i == -1 || j == self.entries.count {
                let toLower = i == -1
                
                var peerIdsSet: [PeerId] = []
                switch self.location {
                    case let .peer(peerId):
                        peerIdsSet.append(peerId)
                }
                var namespaceBounds: [(PeerId, MessageId.Namespace, ClosedRange<MessageId.Id>?)] = []
                for (key, hole) in self.holes {
                    var earlierId: MessageId.Id?
                    earlier: for entry in self.entries {
                        if entry.index.id.peerId == key.peerId && entry.index.id.namespace == key.namespace {
                            earlierId = entry.index.id.id
                            break earlier
                        }
                    }
                    var laterId: MessageId.Id?
                    later: for entry in self.entries.reversed() {
                        if entry.index.id.peerId == key.peerId && entry.index.id.namespace == key.namespace {
                            laterId = entry.index.id.id
                            break later
                        }
                    }
                    if let earlierId = earlierId, let laterId = laterId {
                        let validHole: Bool
                        if toLower {
                            validHole = hole.intersects(integersIn: 1 ... Int(earlierId))
                        } else {
                            validHole = hole.intersects(integersIn: Int(laterId) ... Int(Int32.max))
                        }
                        if validHole {
                            namespaceBounds.append((key.peerId, key.namespace, earlierId ... laterId))
                        }
                    } else {
                        namespaceBounds.append((key.peerId, key.namespace, nil))
                    }
                }
                
                for (peerId, namespace, bounds) in namespaceBounds {
                    if let indices = self.holes[HoleKey(peerId: peerId, namespace: namespace)] {
                        assert(!indices.isEmpty)
                        if let bounds = bounds {
                            var updatedIndices = indices
                            if toLower {
                                updatedIndices.remove(integersIn: Int(bounds.lowerBound) ... Int(Int32.max))
                            } else {
                                updatedIndices.remove(integersIn: 0 ... Int(bounds.upperBound))
                            }
                            if !updatedIndices.isEmpty {
                                let hole = MessageHistoryViewPeerHole(peerId: peerId, namespace: namespace, indices: updatedIndices)
                                if toLower {
                                    return MessageOfInterestHole(hole: .peer(hole), direction: .UpperToLower)
                                } else {
                                    return MessageOfInterestHole(hole: .peer(hole), direction: .LowerToUpper)
                                }
                            }
                        } else {
                            let hole = MessageHistoryViewPeerHole(peerId: peerId, namespace: namespace, indices: indices)
                            if toLower {
                                return MessageOfInterestHole(hole: .peer(hole), direction: .UpperToLower)
                            } else {
                                return MessageOfInterestHole(hole: .peer(hole), direction: .LowerToUpper)
                            }
                        }
                    }
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
    public let closestLaterMedia: [HolesViewMedia]
    
    init(_ view: MutableMessageOfInterestHolesView) {
        self.closestHole = view.closestHole
        self.closestLaterMedia = view.closestLaterMedia
    }
}
