import Foundation

struct PeerIdAndNamespace: Hashable {
    let peerId: PeerId
    let namespace: MessageId.Namespace
}

enum HistoryViewAnchor {
    case upperBound
    case lowerBound
    case index(MessageIndex)
    
    func isLower(than otherIndex: MessageIndex) -> Bool {
        switch self {
            case .upperBound:
                return false
            case .lowerBound:
                return true
            case let .index(index):
                return index < otherIndex
        }
    }
    
    func isEqualOrLower(than otherIndex: MessageIndex) -> Bool {
        switch self {
            case .upperBound:
                return false
            case .lowerBound:
                return true
            case let .index(index):
                return index <= otherIndex
        }
    }
    
    func isGreater(than otherIndex: MessageIndex) -> Bool {
        switch self {
            case .upperBound:
                return true
            case .lowerBound:
                return false
            case let .index(index):
                return index > otherIndex
        }
    }
    
    func isEqualOrGreater(than otherIndex: MessageIndex) -> Bool {
        switch self {
            case .upperBound:
                return true
            case .lowerBound:
                return false
            case let .index(index):
                return index >= otherIndex
        }
    }
}

private func binaryInsertionIndex(_ inputArr: [MutableMessageHistoryEntry], searchItem: HistoryViewAnchor) -> Int {
    var lo = 0
    var hi = inputArr.count - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        let value = inputArr[mid]
        if searchItem.isGreater(than: value.index) {
            lo = mid + 1
        } else if searchItem.isLower(than: value.index) {
            hi = mid - 1
        } else {
            return mid
        }
    }
    return lo
}

func binaryIndexOrLower(_ inputArr: [MessageHistoryEntry], _ searchItem: HistoryViewAnchor) -> Int {
    var lo = 0
    var hi = inputArr.count - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        if searchItem.isGreater(than: inputArr[mid].index) {
            lo = mid + 1
        } else if searchItem.isLower(than: inputArr[mid].index) {
            hi = mid - 1
        } else {
            return mid
        }
    }
    return hi
}

private func binaryIndexOrLower(_ inputArr: [MutableMessageHistoryEntry], _ searchItem: HistoryViewAnchor) -> Int {
    var lo = 0
    var hi = inputArr.count - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        if searchItem.isGreater(than: inputArr[mid].index) {
            lo = mid + 1
        } else if searchItem.isLower(than: inputArr[mid].index) {
            hi = mid - 1
        } else {
            return mid
        }
    }
    return hi
}

private func sampleEntries(orderedEntriesBySpace: [PeerIdAndNamespace: OrderedHistoryViewEntries], anchor: HistoryViewAnchor, limit: Int) -> [(PeerIdAndNamespace, Int)] {
    var previousAnchorIndices: [PeerIdAndNamespace: Int] = [:]
    var nextAnchorIndices: [PeerIdAndNamespace: Int] = [:]
    for (space, items) in orderedEntriesBySpace {
        let index = binaryIndexOrLower(items.entries, anchor)
        previousAnchorIndices[space] = index
        nextAnchorIndices[space] = index + 1
    }
    
    var backwardsResult: [(PeerIdAndNamespace, Int)] = []
    var result: [(PeerIdAndNamespace, Int)] = []
    
    while true {
        var minSpace: PeerIdAndNamespace?
        for (space, value) in previousAnchorIndices {
            if value != -1 {
                if let minSpaceValue = minSpace {
                    if orderedEntriesBySpace[space]!.entries[value].index > orderedEntriesBySpace[minSpaceValue]!.entries[previousAnchorIndices[minSpaceValue]!].index {
                        minSpace = space
                    }
                } else {
                    minSpace = space
                }
            }
        }
        if let minSpace = minSpace {
            backwardsResult.append((minSpace, previousAnchorIndices[minSpace]!))
            previousAnchorIndices[minSpace]! -= 1
            if (result.count + backwardsResult.count) == limit {
                break
            }
        }
        
        var maxSpace: PeerIdAndNamespace?
        for (space, value) in nextAnchorIndices {
            if value != orderedEntriesBySpace[space]!.entries.count {
                if let maxSpaceValue = maxSpace {
                    if orderedEntriesBySpace[space]!.entries[value].index < orderedEntriesBySpace[maxSpaceValue]!.entries[nextAnchorIndices[maxSpaceValue]!].index {
                        maxSpace = space
                    }
                } else {
                    maxSpace = space
                }
            }
        }
        if let maxSpace = maxSpace {
            result.append((maxSpace, nextAnchorIndices[maxSpace]!))
            nextAnchorIndices[maxSpace]! += 1
            if (result.count + backwardsResult.count) == limit {
                break
            }
        }
        
        if minSpace == nil && maxSpace == nil {
            break
        }
    }
    return backwardsResult.reversed() + result
}

struct SampledHistoryViewHole: Equatable {
    let peerId: PeerId
    let namespace: MessageId.Namespace
    let tag: MessageTags?
    let indices: IndexSet
    let startId: MessageId.Id
    let endId: MessageId.Id?
}

private func isIndex(index: MessageIndex, closerTo anchor: HistoryViewAnchor, than other: MessageIndex) -> Bool {
    if index.timestamp != other.timestamp {
        let anchorTimestamp: Int32
        switch anchor {
            case .lowerBound:
                anchorTimestamp = 0
            case .upperBound:
                anchorTimestamp = Int32.max
            case let .index(index):
                anchorTimestamp = index.timestamp
        }
        if abs(anchorTimestamp - index.timestamp) < abs(anchorTimestamp - other.timestamp) {
            return true
        } else {
            return false
        }
    } else if index.id.peerId == other.id.peerId {
        if index.id.namespace == other.id.namespace {
            let anchorId: Int32
            switch anchor {
                case .lowerBound:
                    anchorId = 0
                case .upperBound:
                    anchorId = Int32.max
                case let .index(index):
                    anchorId = index.id.id
            }
            if abs(anchorId - index.id.id) < abs(anchorId - other.id.id) {
                return true
            } else {
                return false
            }
        } else {
            return index.id.namespace < other.id.namespace
        }
    } else {
        return index.id.peerId.toInt64() < other.id.peerId.toInt64()
    }
}

private func sampleHoleRanges(orderedEntriesBySpace: [PeerIdAndNamespace: OrderedHistoryViewEntries], holes: HistoryViewHoles, anchor: HistoryViewAnchor, tag: MessageTags?) -> (clipRanges: [ClosedRange<MessageIndex>], sampledHole: SampledHistoryViewHole?) {
    var clipRanges: [ClosedRange<MessageIndex>] = []
    var sampledHole: (index: MessageIndex, hole: SampledHistoryViewHole)?
    
    for (space, indices) in holes.holesBySpace {
        if indices.isEmpty {
            continue
        }
        switch anchor {
            case .lowerBound, .upperBound:
                break
            case let .index(index):
                if index.id.peerId == space.peerId && index.id.namespace == space.namespace {
                    if indices.contains(Int(index.id.id)) {
                        return ([MessageIndex.absoluteLowerBound() ... MessageIndex.absoluteUpperBound()], SampledHistoryViewHole(peerId: space.peerId, namespace: space.namespace, tag: tag, indices: indices, startId: index.id.id, endId: nil))
                    }
                }
        }
        guard let items = orderedEntriesBySpace[space] else {
            return ([MessageIndex.absoluteLowerBound() ... MessageIndex.absoluteUpperBound()], SampledHistoryViewHole(peerId: space.peerId, namespace: space.namespace, tag: tag, indices: indices, startId: Int32.max - 1, endId: 1))
        }
        if items.entries.isEmpty {
            return ([MessageIndex.absoluteLowerBound() ... MessageIndex.absoluteUpperBound()], SampledHistoryViewHole(peerId: space.peerId, namespace: space.namespace, tag: tag, indices: indices, startId: Int32.max - 1, endId: 1))
        }
        guard let bounds = items.bounds else {
            assertionFailure("A non-empty entry list should have non-nil bounds")
            continue
        }
        let anchorIndex = binaryIndexOrLower(items.entries, anchor)
        let anchorStartingMessageId: MessageId.Id
        if anchorIndex == -1 {
            anchorStartingMessageId = 1
        } else {
            anchorStartingMessageId = items.entries[anchorIndex].index.id.id
        }
        
        let startingLowerDirectionIndex = anchorIndex
        let startingHigherDirectionIndex = anchorIndex + 1
        
        var lowerDirectionIndex = startingLowerDirectionIndex
        var higherDirectionIndex = startingHigherDirectionIndex
        while lowerDirectionIndex >= 0 || higherDirectionIndex < items.entries.count {
            if lowerDirectionIndex >= 0 {
                let itemIndex = items.entries[lowerDirectionIndex].index
                var itemBoundaryMessageId: MessageId.Id = itemIndex.id.id
                if lowerDirectionIndex == 0 && itemBoundaryMessageId == bounds.lower.id.id {
                    itemBoundaryMessageId = 1
                }
                let previousBoundaryIndex: MessageIndex
                if lowerDirectionIndex == startingLowerDirectionIndex {
                    previousBoundaryIndex = itemIndex
                } else {
                    previousBoundaryIndex = items.entries[lowerDirectionIndex + 1].index
                }
                if indices.intersects(integersIn: min(Int(anchorStartingMessageId), Int(itemBoundaryMessageId)) ... max(Int(anchorStartingMessageId), Int(itemBoundaryMessageId))) {
                    var itemClipIndex: MessageIndex
                    if indices.contains(Int(previousBoundaryIndex.id.id)) {
                        itemClipIndex = previousBoundaryIndex
                    } else {
                        itemClipIndex = previousBoundaryIndex.predecessor()
                    }
                    clipRanges.append(MessageIndex.absoluteLowerBound() ... itemClipIndex)
                    var replaceHole = false
                    if let (currentIndex, _) = sampledHole {
                        if isIndex(index: itemClipIndex, closerTo: anchor, than: currentIndex) {
                            replaceHole = true
                        }
                    } else {
                        replaceHole = true
                    }
                    
                    if replaceHole {
                        let holeStartId: MessageId.Id
                        if indices.contains(Int(previousBoundaryIndex.id.id)) {
                            holeStartId = previousBoundaryIndex.id.id
                        } else {
                            holeStartId = previousBoundaryIndex.id.id - 1
                        }
                        if let idInHole = indices.integerLessThanOrEqualTo(IndexSet.Element(holeStartId)) {
                            sampledHole = (itemIndex, SampledHistoryViewHole(peerId: space.peerId, namespace: space.namespace, tag: tag, indices: indices, startId: MessageId.Id(idInHole), endId: 1))
                        } else {
                            assertionFailure()
                        }
                    }
                    lowerDirectionIndex = -1
                }
            }
            lowerDirectionIndex -= 1
            
            if higherDirectionIndex < items.entries.count {
                let itemIndex = items.entries[higherDirectionIndex].index
                var itemBoundaryMessageId: MessageId.Id = itemIndex.id.id
                if higherDirectionIndex == items.entries.count - 1 && itemBoundaryMessageId == bounds.upper.id.id {
                    itemBoundaryMessageId = Int32.max - 1
                }
                if indices.intersects(integersIn: min(Int(anchorStartingMessageId), Int(itemBoundaryMessageId)) ... max(Int(anchorStartingMessageId), Int(itemBoundaryMessageId))) {
                    var itemClipIndex: MessageIndex
                    if indices.contains(Int(itemIndex.id.id)) {
                        itemClipIndex = itemIndex
                    } else {
                        itemClipIndex = itemIndex.successor()
                    }
                    clipRanges.append(itemClipIndex ... MessageIndex.absoluteUpperBound())
                    var replaceHole = false
                    if let (currentIndex, _) = sampledHole {
                        if isIndex(index: itemIndex, closerTo: anchor, than: currentIndex) {
                            replaceHole = true
                        }
                    } else {
                        replaceHole = true
                    }
                    
                    if replaceHole {
                        let holeStartId: MessageId.Id
                        if indices.contains(Int(itemIndex.id.id)) {
                            holeStartId = itemIndex.id.id
                        } else {
                            holeStartId = itemIndex.id.id + 1
                        }
                        if let idInHole = indices.integerGreaterThanOrEqualTo(IndexSet.Element(holeStartId)) {
                            sampledHole = (itemIndex, SampledHistoryViewHole(peerId: space.peerId, namespace: space.namespace, tag: tag, indices: indices, startId: MessageId.Id(idInHole), endId: Int32.max - 1))
                        }
                    }
                    higherDirectionIndex = items.entries.count
                }
            }
            higherDirectionIndex += 1
        }
    }
    return (clipRanges, sampledHole?.hole)
}

struct HistoryViewHoles {
    var holesBySpace: [PeerIdAndNamespace: IndexSet]
    
    mutating func insertHole(space: PeerIdAndNamespace, range: ClosedRange<MessageId.Id>) -> Bool {
        if self.holesBySpace[space] == nil {
            self.holesBySpace[space] = IndexSet()
        }
        let intRange = Int(range.lowerBound) ... Int(range.upperBound)
        if self.holesBySpace[space]!.contains(integersIn: intRange) {
            self.holesBySpace[space]!.insert(integersIn: intRange)
            return true
        } else {
            return false
        }
    }
    
    mutating func removeHole(space: PeerIdAndNamespace, range: ClosedRange<MessageId.Id>) -> Bool {
        if self.holesBySpace[space] != nil {
            let intRange = Int(range.lowerBound) ... Int(range.upperBound)
            if self.holesBySpace[space]!.intersects(integersIn: intRange) {
                self.holesBySpace[space]!.remove(integersIn: intRange)
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
}

struct OrderedHistoryViewEntries {
    var entries: [MutableMessageHistoryEntry]
    var bounds: (lower: MessageIndex, upper: MessageIndex)?
}

struct HistoryViewLoadedSample {
    let anchor: HistoryViewAnchor
    let entries: [MessageHistoryMessageEntry]
    let holesToLower: Bool
    let holesToHigher: Bool
    let hole: SampledHistoryViewHole?
}

final class HistoryViewLoadedState {
    let anchor: HistoryViewAnchor
    let tag: MessageTags?
    let limit: Int
    var orderedEntriesBySpace: [PeerIdAndNamespace: OrderedHistoryViewEntries]
    var holes: HistoryViewHoles
    var spacesWithRemovals = Set<PeerIdAndNamespace>()
    
    init(anchor: HistoryViewAnchor, tag: MessageTags?, limit: Int, locations: MessageHistoryViewPeerIds, postbox: Postbox, holes: HistoryViewHoles) {
        precondition(limit >= 3)
        self.anchor = anchor
        self.tag = tag
        self.limit = limit
        self.orderedEntriesBySpace = [:]
        self.holes = holes
        
        var peerIds: [PeerId] = []
        switch locations {
            case let .single(peerId):
                peerIds.append(peerId)
            case let .associated(peerId, associatedId):
                peerIds.append(peerId)
                if let associatedId = associatedId {
                    peerIds.append(associatedId.peerId)
                }
        }
        
        var spaces: [PeerIdAndNamespace] = []
        for peerId in peerIds {
            for namespace in postbox.messageHistoryIndexTable.existingNamespaces(peerId: peerId) {
                spaces.append(PeerIdAndNamespace(peerId: peerId, namespace: namespace))
            }
        }
        
        for space in spaces {
            self.fillSpace(space: space, postbox: postbox)
        }
    }
    
    private func fillSpace(space: PeerIdAndNamespace, postbox: Postbox) {
        let anchorIndex: MessageIndex
        let lowerBound = MessageIndex.lowerBound(peerId: space.peerId, namespace: space.namespace)
        let upperBound = MessageIndex.upperBound(peerId: space.peerId, namespace: space.namespace)
        switch self.anchor {
            case let .index(index):
                anchorIndex = index.withPeerId(space.peerId).withNamespace(space.namespace)
            case .lowerBound:
                anchorIndex = lowerBound
            case .upperBound:
                anchorIndex = upperBound
        }
        
        var lowerMessages: [MutableMessageHistoryEntry] = []
        var higherMessages: [MutableMessageHistoryEntry] = []
        
        if let currentEntries = self.orderedEntriesBySpace[space], !currentEntries.entries.isEmpty {
            let index = binaryIndexOrLower(currentEntries.entries, self.anchor)
            if index >= 0 {
                lowerMessages = Array(currentEntries.entries[0 ... index].reversed())
            }
            if index < currentEntries.entries.count {
                higherMessages = Array(currentEntries.entries[index + 1 ..< currentEntries.entries.count])
            }
        }
        
        func mapEntry(_ message: IntermediateMessage) -> MutableMessageHistoryEntry {
            return .IntermediateMessageEntry(message, nil, nil)
        }
        
        if lowerMessages.count < self.limit / 2 + 1 {
            let nextLowerIndex: (index: MessageIndex, includeFrom: Bool)
            if let lastMessage = lowerMessages.last {
                nextLowerIndex = (lastMessage.index, false)
            } else {
                nextLowerIndex = (anchorIndex, true)
            }
            lowerMessages.append(contentsOf: postbox.messageHistoryTable.fetch(peerId: space.peerId, namespace: space.namespace, tag: self.tag, from: nextLowerIndex.index, includeFrom: nextLowerIndex.includeFrom, to: lowerBound, limit: self.limit / 2 + 1 - lowerMessages.count).map(mapEntry))
        }
        if higherMessages.count < self.limit - lowerMessages.count {
            let nextHigherIndex: MessageIndex
            if let lastMessage = higherMessages.last {
                nextHigherIndex = lastMessage.index
            } else {
                nextHigherIndex = anchorIndex
            }
            higherMessages.append(contentsOf: postbox.messageHistoryTable.fetch(peerId: space.peerId, namespace: space.namespace, tag: self.tag, from: nextHigherIndex, includeFrom: false, to: upperBound, limit: self.limit - lowerMessages.count - higherMessages.count).map(mapEntry))
        }
        
        if !lowerMessages.isEmpty && lowerMessages.count + higherMessages.count < self.limit {
            let additionalLowerMessages = postbox.messageHistoryTable.fetch(peerId: space.peerId, namespace: space.namespace, tag: self.tag, from: lowerMessages[lowerMessages.count - 1].index, includeFrom: false, to: lowerBound, limit: self.limit - lowerMessages.count - higherMessages.count).map(mapEntry)
            lowerMessages.append(contentsOf: additionalLowerMessages)
        }
        
        var messages: [MutableMessageHistoryEntry] = []
        messages.append(contentsOf: lowerMessages.reversed())
        messages.append(contentsOf: higherMessages)
        
        assert(messages.count <= self.limit)
        
        let bounds = postbox.messageHistoryTable.fetchBoundaries(peerId: space.peerId, namespace: space.namespace, tag: self.tag)
        
        self.orderedEntriesBySpace[space] = OrderedHistoryViewEntries(entries: messages, bounds: bounds)
    }
    
    func insertHole(space: PeerIdAndNamespace, range: ClosedRange<MessageId.Id>) -> Bool {
        return self.holes.insertHole(space: space, range: range)
    }
    
    func removeHole(space: PeerIdAndNamespace, range: ClosedRange<MessageId.Id>) -> Bool {
        return self.holes.removeHole(space: space, range: range)
    }
    
    func updateTimestamp(postbox: Postbox, index: MessageIndex, timestamp: Int32) -> Bool {
        let space = PeerIdAndNamespace(peerId: index.id.peerId, namespace: index.id.namespace)
        if self.orderedEntriesBySpace[space] == nil {
            return false
        }
        guard let entryIndex = binarySearch(self.orderedEntriesBySpace[space]!.entries, extract: { $0.index }, searchItem: index) else {
            return false
        }
        let entry = self.orderedEntriesBySpace[space]!.entries[entryIndex]
        var updated = false
        if self.remove(postbox: postbox, index: index) {
            updated = true
        }
        if self.add(entry: entry.updatedTimestamp(timestamp)) {
            updated = true
        }
        return updated
    }
    
    func updateGroupInfo(mapping: [MessageId: MessageGroupInfo]) -> Bool {
        var mappingsBySpace: [PeerIdAndNamespace: [MessageId.Id: MessageGroupInfo]] = [:]
        for (id, info) in mapping {
            let space = PeerIdAndNamespace(peerId: id.peerId, namespace: id.namespace)
            if mappingsBySpace[space] == nil {
                mappingsBySpace[space] = [:]
            }
            mappingsBySpace[space]![id.id] = info
        }
        var updated = false
        for (space, spaceMapping) in mappingsBySpace {
            if self.orderedEntriesBySpace[space] == nil {
                continue
            }
            for i in 0 ..< self.orderedEntriesBySpace[space]!.entries.count {
                if let groupInfo = spaceMapping[self.orderedEntriesBySpace[space]!.entries[i].index.id.id] {
                    updated = true
                    switch self.orderedEntriesBySpace[space]!.entries[i] {
                        case let .IntermediateMessageEntry(message, location, monthLocation):
                            self.orderedEntriesBySpace[space]!.entries[i] = .IntermediateMessageEntry(message.withUpdatedGroupInfo(groupInfo), location, monthLocation)
                        case let .MessageEntry(messageEntry):
                            self.orderedEntriesBySpace[space]!.entries[i] = .MessageEntry(MessageHistoryMessageEntry(message: messageEntry.message.withUpdatedGroupInfo(groupInfo), location: messageEntry.location, monthLocation: messageEntry.monthLocation, attributes: messageEntry.attributes))
                    }
                }
            }
        }
        return updated
    }
    
    func updateEmbeddedMedia(postbox: Postbox, index: MessageIndex, buffer: ReadBuffer) -> Bool {
        let space = PeerIdAndNamespace(peerId: index.id.peerId, namespace: index.id.namespace)
        if self.orderedEntriesBySpace[space] == nil {
            return false
        }
        guard let itemIndex = binarySearch(self.orderedEntriesBySpace[space]!.entries, extract: { $0.index }, searchItem: index) else {
            return false
        }
        switch self.orderedEntriesBySpace[space]!.entries[itemIndex] {
            case let .IntermediateMessageEntry(message, location, monthLocation):
                self.orderedEntriesBySpace[space]!.entries[itemIndex] = .IntermediateMessageEntry(message.withUpdatedEmbeddedMedia(buffer), location, monthLocation)
            case let .MessageEntry(messageEntry):
                self.orderedEntriesBySpace[space]!.entries[itemIndex] = .MessageEntry(MessageHistoryMessageEntry(message: messageEntry.message, location: messageEntry.location, monthLocation: messageEntry.monthLocation, attributes: messageEntry.attributes))
        }
        return true
    }
    
    func add(entry: MutableMessageHistoryEntry) -> Bool {
        let space = PeerIdAndNamespace(peerId: entry.index.id.peerId, namespace: entry.index.id.namespace)
        
        if self.orderedEntriesBySpace[space] == nil {
            self.orderedEntriesBySpace[space] = OrderedHistoryViewEntries(entries: [], bounds: nil)
        }
        
        let insertionIndex = binaryInsertionIndex(self.orderedEntriesBySpace[space]!.entries, extract: { $0.index }, searchItem: entry.index)
        
        if insertionIndex < self.orderedEntriesBySpace[space]!.entries.count {
            if self.orderedEntriesBySpace[space]!.entries[insertionIndex].index == entry.index {
                assertionFailure("Inserting an existing index is not allowed")
                self.orderedEntriesBySpace[space]!.entries[insertionIndex] = entry
                return true
            }
        }
        
        var shouldBeAdded = false
        if insertionIndex == 0 {
            if let bounds = self.orderedEntriesBySpace[space]!.bounds {
                if entry.index < bounds.lower {
                    shouldBeAdded = true
                }
            } else {
                assert(self.orderedEntriesBySpace[space]!.entries.isEmpty, "A non-empty entry list should have non-nil bounds")
                shouldBeAdded = true
            }
        } else if insertionIndex == self.orderedEntriesBySpace[space]!.entries.count {
            if let bounds = self.orderedEntriesBySpace[space]!.bounds {
                if entry.index > bounds.upper {
                    shouldBeAdded = true
                }
            } else {
                assert(self.orderedEntriesBySpace[space]!.entries.isEmpty, "A non-empty entry list should have non-nil bounds")
                shouldBeAdded = true
            }
        } else {
            shouldBeAdded = true
        }
        
        if shouldBeAdded {
            self.orderedEntriesBySpace[space]!.entries.insert(entry, at: insertionIndex)
            if let currentBounds = self.orderedEntriesBySpace[space]!.bounds {
                if entry.index < currentBounds.lower {
                    self.orderedEntriesBySpace[space]!.bounds = (lower: entry.index, upper: currentBounds.upper)
                } else if entry.index > currentBounds.upper {
                    self.orderedEntriesBySpace[space]!.bounds = (lower: currentBounds.lower, upper: entry.index)
                }
            } else {
                self.orderedEntriesBySpace[space]!.bounds = (lower: entry.index, upper: entry.index)
            }
            
            if self.orderedEntriesBySpace[space]!.entries.count > self.limit {
                let anchorIndex = binaryIndexOrLower(self.orderedEntriesBySpace[space]!.entries, self.anchor)
                if anchorIndex > self.limit / 2 {
                    self.orderedEntriesBySpace[space]!.entries.removeFirst()
                } else {
                    self.orderedEntriesBySpace[space]!.entries.removeLast()
                }
            }
            return true
        } else {
            return false
        }
    }
    
    func remove(postbox: Postbox, index: MessageIndex) -> Bool {
        let space = PeerIdAndNamespace(peerId: index.id.peerId, namespace: index.id.namespace)
        if self.orderedEntriesBySpace[space] == nil {
            return false
        }
        
        if let itemIndex = binarySearch(self.orderedEntriesBySpace[space]!.entries, extract: { $0.index }, searchItem: index) {
            if let currentBounds = self.orderedEntriesBySpace[space]!.bounds {
                if currentBounds.lower == index || currentBounds.upper
                    == index {
                    self.orderedEntriesBySpace[space]!.bounds = postbox.messageHistoryTable.fetchBoundaries(peerId: space.peerId, namespace: space.namespace, tag: self.tag)
                }
            } else {
                assertionFailure("A non-empty entry list should have non-nil bounds")
            }
            self.orderedEntriesBySpace[space]!.entries.remove(at: itemIndex)
            self.spacesWithRemovals.insert(space)
            return true
        } else {
            return false
        }
    }
    
    func completeAndSample(postbox: Postbox) -> HistoryViewLoadedSample {
        if !self.spacesWithRemovals.isEmpty {
            for space in self.spacesWithRemovals {
                self.fillSpace(space: space, postbox: postbox)
            }
            self.spacesWithRemovals.removeAll()
        }
        let combinedSpacesAndIndices = sampleEntries(orderedEntriesBySpace: self.orderedEntriesBySpace, anchor: self.anchor, limit: self.limit)
        let (clipRanges, sampledHole) = sampleHoleRanges(orderedEntriesBySpace: self.orderedEntriesBySpace, holes: self.holes, anchor: self.anchor, tag: self.tag)
        
        var holesToLower = false
        var holesToHigher = false
        var result: [MessageHistoryMessageEntry] = []
        outer: for i in 0 ..< combinedSpacesAndIndices.count {
            let (space, index) = combinedSpacesAndIndices[i]
            
            if !clipRanges.isEmpty {
                let entryIndex = self.orderedEntriesBySpace[space]!.entries[index].index
                for range in clipRanges {
                    if range.contains(entryIndex) {
                        if i == 0 {
                            holesToLower = true
                        }
                        if i == combinedSpacesAndIndices.count - 1 {
                            holesToHigher = true
                        }
                        continue outer
                    }
                }
            }
            
            switch self.orderedEntriesBySpace[space]!.entries[index] {
                case let .MessageEntry(value):
                    result.append(value)
                case let .IntermediateMessageEntry(message, location, monthLocation):
                    let renderedMessage = postbox.messageHistoryTable.renderMessage(message, peerTable: postbox.peerTable)
                    var authorIsContact = false
                    if let author = renderedMessage.author {
                        authorIsContact = postbox.contactsTable.isContact(peerId: author.id)
                    }
                    let entry = MessageHistoryMessageEntry(message: renderedMessage, location: location, monthLocation: monthLocation, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: authorIsContact))
                    self.orderedEntriesBySpace[space]!.entries[index] = .MessageEntry(entry)
                    result.append(entry)
            }
        }
        let stableIds = Set(result.map({ $0.message.stableId }))
        assert(stableIds.count == result.count)
        return HistoryViewLoadedSample(anchor: self.anchor, entries: result, holesToLower: holesToLower, holesToHigher: holesToHigher, hole: sampledHole)
    }
}

private func fetchHoles(postbox: Postbox, locations: MessageHistoryViewPeerIds, tag: MessageTags?) -> [PeerIdAndNamespace: IndexSet] {
    var holesBySpace: [PeerIdAndNamespace: IndexSet] = [:]
    var peerIds: [PeerId] = []
    switch locations {
        case let .single(peerId):
            peerIds.append(peerId)
        case let .associated(peerId, associatedId):
            peerIds.append(peerId)
            if let associatedId = associatedId {
                peerIds.append(associatedId.peerId)
            }
    }
    let holeSpace = tag.flatMap(MessageHistoryHoleSpace.tag) ?? .everywhere
    for peerId in peerIds {
        for namespace in postbox.messageHistoryHoleIndexTable.existingNamespaces(peerId: peerId, holeSpace: holeSpace) {
            let indices = postbox.messageHistoryHoleIndexTable.closest(peerId: peerId, namespace: namespace, space: holeSpace, range: 1 ... (Int32.max - 1))
            if !indices.isEmpty {
                holesBySpace[PeerIdAndNamespace(peerId: peerId, namespace: namespace)] = indices
            }
        }
    }
    return holesBySpace
}

enum HistoryViewLoadingSample {
    case ready(HistoryViewAnchor, HistoryViewHoles)
    case loadHole(PeerId, MessageId.Namespace, MessageTags?, IndexSet, MessageId.Id)
}

final class HistoryViewLoadingState {
    var messageId: MessageId
    let tag: MessageTags?
    let limit: Int
    var holes: HistoryViewHoles
    
    init(postbox: Postbox, locations: MessageHistoryViewPeerIds, tag: MessageTags?, messageId: MessageId, limit: Int) {
        self.messageId = messageId
        self.tag = tag
        self.limit = limit
        self.holes = HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag))
    }
    
    func insertHole(space: PeerIdAndNamespace, range: ClosedRange<MessageId.Id>) -> Bool {
        return self.holes.insertHole(space: space, range: range)
    }
    
    func removeHole(space: PeerIdAndNamespace, range: ClosedRange<MessageId.Id>) -> Bool {
        return self.holes.removeHole(space: space, range: range)
    }
    
    func checkAndSample(postbox: Postbox) -> HistoryViewLoadingSample {
        while true {
            if let indices = self.holes.holesBySpace[PeerIdAndNamespace(peerId: self.messageId.peerId, namespace: self.messageId.namespace)] {
                if indices.contains(Int(messageId.id)) {
                    return .loadHole(messageId.peerId, messageId.namespace, self.tag, indices, messageId.id)
                }
            }
            
            if let index = postbox.messageHistoryIndexTable.getIndex(self.messageId) {
                return .ready(.index(index), self.holes)
            }
            if let nextHigherIndex = postbox.messageHistoryIndexTable.indexForId(higherThan: self.messageId) {
                self.messageId = nextHigherIndex.id
            } else {
                return .ready(.upperBound, self.holes)
            }
        }
    }
}

enum HistoryViewSample {
    case loaded(HistoryViewLoadedSample)
    case loading(HistoryViewLoadingSample)
}

enum HistoryViewState {
    case loaded(HistoryViewLoadedState)
    case loading(HistoryViewLoadingState)
    
    init(postbox: Postbox, inputAnchor: HistoryViewInputAnchor, tag: MessageTags?, limit: Int, locations: MessageHistoryViewPeerIds) {
        switch inputAnchor {
            case let .index(index):
                self = .loaded(HistoryViewLoadedState(anchor: .index(index), tag: tag, limit: limit, locations: locations, postbox: postbox, holes: HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag))))
            case .lowerBound:
                self = .loaded(HistoryViewLoadedState(anchor: .lowerBound, tag: tag, limit: limit, locations: locations, postbox: postbox, holes: HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag))))
            case .upperBound:
                self = .loaded(HistoryViewLoadedState(anchor: .upperBound, tag: tag, limit: limit, locations: locations, postbox: postbox, holes: HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag))))
            case .unread:
                let anchorPeerId: PeerId
                switch locations {
                    case let .single(peerId):
                        anchorPeerId = peerId
                    case let .associated(peerId, _):
                        anchorPeerId = peerId
                }
                if postbox.chatListIndexTable.get(peerId: anchorPeerId).includedIndex(peerId: anchorPeerId) != nil, let combinedState = postbox.readStateTable.getCombinedState(anchorPeerId) {
                    var messageId: MessageId?
                    var anchor: HistoryViewAnchor?
                    loop: for (namespace, state) in combinedState.states {
                        switch state {
                            case let .idBased(maxIncomingReadId, _, _, count, _):
                                if count == 0 {
                                    anchor = .upperBound
                                    break loop
                                } else {
                                    messageId = MessageId(peerId: anchorPeerId, namespace: namespace, id: maxIncomingReadId)
                                    break loop
                                }
                            case let .indexBased(maxIncomingReadIndex, _, count, _):
                                if count == 0 {
                                    anchor = .upperBound
                                    break loop
                                } else {
                                    anchor = .index(maxIncomingReadIndex)
                                    break loop
                                }
                        }
                    }
                    if let messageId = messageId {
                        let loadingState = HistoryViewLoadingState(postbox: postbox, locations: locations, tag: tag, messageId: messageId, limit: limit)
                        let sampledState = loadingState.checkAndSample(postbox: postbox)
                        switch sampledState {
                            case let .ready(anchor, holes):
                                self = .loaded(HistoryViewLoadedState(anchor: anchor, tag: tag, limit: limit, locations: locations, postbox: postbox, holes: holes))
                            case .loadHole:
                                self = .loading(loadingState)
                        }
                    } else {
                        self = .loaded(HistoryViewLoadedState(anchor: anchor ?? .upperBound, tag: tag, limit: limit, locations: locations, postbox: postbox, holes: HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag))))
                    }
                } else {
                    preconditionFailure()
                }
            case let .message(messageId):
                let loadingState = HistoryViewLoadingState(postbox: postbox, locations: locations, tag: tag, messageId: messageId, limit: limit)
                let sampledState = loadingState.checkAndSample(postbox: postbox)
                switch sampledState {
                    case let .ready(anchor, holes):
                        self = .loaded(HistoryViewLoadedState(anchor: anchor, tag: tag, limit: limit, locations: locations, postbox: postbox, holes: holes))
                    case .loadHole:
                        self = .loading(loadingState)
                }
        }
    }
    
    func sample(postbox: Postbox) -> HistoryViewSample {
        switch self {
            case let .loading(loadingState):
                return .loading(loadingState.checkAndSample(postbox: postbox))
            case let .loaded(loadedState):
                return .loaded(loadedState.completeAndSample(postbox: postbox))
        }
    }
}
