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

private func sampleEntries(sortedEntriesBySpace: [PeerIdAndNamespace: [MutableMessageHistoryEntry]], anchor: HistoryViewAnchor, limit: Int) -> [(PeerIdAndNamespace, Int)] {
    var previousAnchorIndices: [PeerIdAndNamespace: Int] = [:]
    var nextAnchorIndices: [PeerIdAndNamespace: Int] = [:]
    for (space, items) in sortedEntriesBySpace {
        let index = binaryIndexOrLower(items, anchor)
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
                    if sortedEntriesBySpace[space]![value].index > sortedEntriesBySpace[minSpaceValue]![previousAnchorIndices[minSpaceValue]!].index {
                        minSpace = space
                    }
                } else {
                    minSpace = space
                }
            }
        }
        if let minSpace = minSpace {
            backwardsResult.append((minSpace, previousAnchorIndices[minSpace]!))
            //result.insert(sortedEntriesBySpace[minSpace]![previousAnchorIndices[minSpace]!], at: 0)
            previousAnchorIndices[minSpace]! -= 1
            if result.count == limit {
                break
            }
        }
        
        var maxSpace: PeerIdAndNamespace?
        for (space, value) in nextAnchorIndices {
            if value != sortedEntriesBySpace[space]!.count {
                if let maxSpaceValue = maxSpace {
                    if sortedEntriesBySpace[space]![value].index < sortedEntriesBySpace[maxSpaceValue]![nextAnchorIndices[maxSpaceValue]!].index {
                        maxSpace = space
                    }
                } else {
                    maxSpace = space
                }
            }
        }
        if let maxSpace = maxSpace {
            result.append((maxSpace, nextAnchorIndices[maxSpace]!))
            //result.append(sortedEntriesBySpace[maxSpace]![nextAnchorIndices[maxSpace]!])
            nextAnchorIndices[maxSpace]! += 1
            if result.count == limit {
                break
            }
        }
        
        if minSpace == nil && maxSpace == nil {
            break
        }
    }
    return backwardsResult.reversed() + result
}

struct HistoryViewLoadedState {
    let anchor: HistoryViewAnchor
    let tag: MessageTags?
    let limit: Int
    var sortedEntriesBySpace: [PeerIdAndNamespace: [MutableMessageHistoryEntry]]
    var holesBySpace: [PeerIdAndNamespace: IndexSet]
    var spacesWithRemovals = Set<PeerIdAndNamespace>()
    
    init(anchor: HistoryViewAnchor, tag: MessageTags?, limit: Int, locations: MessageHistoryViewPeerIds, postbox: Postbox) {
        precondition(limit > 0)
        self.anchor = anchor
        self.tag = tag
        self.limit = limit
        self.sortedEntriesBySpace = [:]
        self.holesBySpace = [:]
        
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
    
    private mutating func fillSpace(space: PeerIdAndNamespace, postbox: Postbox) {
        let anchorIndex: MessageIndex
        let lowerBound = MessageIndex.lowerBound(peerId: space.peerId, namespace: space.namespace)
        let upperBound = MessageIndex.upperBound(peerId: space.peerId, namespace: space.namespace)
        switch self.anchor {
            case let .index(index):
                anchorIndex = index
            case .lowerBound:
                anchorIndex = lowerBound
            case .upperBound:
                anchorIndex = upperBound
        }
        
        var lowerMessages: [IntermediateMessage]
        var higherMessages: [IntermediateMessage]
        
        lowerMessages = postbox.messageHistoryTable.fetch(peerId: space.peerId, namespace: space.namespace, tag: self.tag, from: anchorIndex, includeFrom: true, to: lowerBound, limit: self.limit / 2)
        higherMessages = postbox.messageHistoryTable.fetch(peerId: space.peerId, namespace: space.namespace, tag: self.tag, from: anchorIndex, includeFrom: false, to: upperBound, limit: self.limit - lowerMessages.count)
        
        if !lowerMessages.isEmpty && lowerMessages.count + higherMessages.count < self.limit {
            let additionalLowerMessages = postbox.messageHistoryTable.fetch(peerId: space.peerId, namespace: space.namespace, tag: self.tag, from: lowerMessages[lowerMessages.count - 1].index, includeFrom: false, to: lowerBound, limit: self.limit - lowerMessages.count - higherMessages.count + 1)
            lowerMessages.append(contentsOf: additionalLowerMessages)
        }
        
        var messages: [IntermediateMessage] = []
        messages.append(contentsOf: lowerMessages.reversed())
        messages.append(contentsOf: higherMessages)
        
        self.sortedEntriesBySpace[space] = messages.map({ message -> MutableMessageHistoryEntry in
            return .IntermediateMessageEntry(message, nil, nil)
        })
    }
    
    mutating func add(entry: MutableMessageHistoryEntry) -> Bool {
        let space = PeerIdAndNamespace(peerId: entry.index.id.peerId, namespace: entry.index.id.namespace)
        
        if self.sortedEntriesBySpace[space] == nil {
            self.sortedEntriesBySpace[space] = []
        }
        
        let insertionIndex = binaryInsertionIndex(self.sortedEntriesBySpace[space]!, extract: { $0.index }, searchItem: entry.index)
        
        var shouldBeAdded = false
        if insertionIndex == 0 {
            if self.anchor.isEqualOrLower(than: entry.index) {
                shouldBeAdded = true
            }
        } else if insertionIndex == self.sortedEntriesBySpace[space]!.count {
            if self.anchor.isEqualOrGreater(than: entry.index) {
                shouldBeAdded = true
            }
        } else {
            shouldBeAdded = true
        }
        
        if shouldBeAdded {
            self.sortedEntriesBySpace[space]!.insert(entry, at: insertionIndex)
            
            if self.sortedEntriesBySpace[space]!.count > self.limit {
                if self.anchor.isEqualOrLower(than: entry.index) {
                    self.sortedEntriesBySpace[space]!.removeLast()
                } else {
                    self.sortedEntriesBySpace[space]!.removeFirst()
                }
            }
            return true
        } else {
            return false
        }
    }
    
    mutating func remove(index: MessageIndex) -> Bool {
        let space = PeerIdAndNamespace(peerId: index.id.peerId, namespace: index.id.namespace)
        if self.sortedEntriesBySpace[space] == nil {
            return false
        }
        
        if let itemIndex = binarySearch(self.sortedEntriesBySpace[space]!, extract: { $0.index }, searchItem: index) {
            self.sortedEntriesBySpace[space]!.remove(at: itemIndex)
            self.spacesWithRemovals.insert(space)
            return true
        } else {
            return false
        }
    }
    
    mutating func completeAndSample(postbox: Postbox) -> [MessageHistoryMessageEntry] {
        if !self.spacesWithRemovals.isEmpty {
            for space in self.spacesWithRemovals {
                self.sortedEntriesBySpace[space]?.removeAll()
                
                if self.sortedEntriesBySpace[space]!.isEmpty {
                    self.fillSpace(space: space, postbox: postbox)
                } else {
                    assertionFailure()
                }
            }
            self.spacesWithRemovals.removeAll()
        }
        let combinedSpacesAndIndices = sampleEntries(sortedEntriesBySpace: self.sortedEntriesBySpace, anchor: self.anchor, limit: self.limit)
        var result: [MessageHistoryMessageEntry] = []
        for (space, index) in combinedSpacesAndIndices {
            switch self.sortedEntriesBySpace[space]![index] {
                case let .MessageEntry(value):
                    result.append(value)
                case let .IntermediateMessageEntry(message, location, monthLocation):
                    let renderedMessage = postbox.messageHistoryTable.renderMessage(message, peerTable: postbox.peerTable)
                    var authorIsContact = false
                    if let author = renderedMessage.author {
                        authorIsContact = postbox.contactsTable.isContact(peerId: author.id)
                    }
                    let entry = MessageHistoryMessageEntry(message: renderedMessage, location: location, monthLocation: monthLocation, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: authorIsContact))
                    self.sortedEntriesBySpace[space]![index] = .MessageEntry(entry)
                    result.append(entry)
            }
        }
        return result
    }
}

enum HistoryViewState {
    case loaded(HistoryViewLoadedState)
    case loading(MessageId)
}
