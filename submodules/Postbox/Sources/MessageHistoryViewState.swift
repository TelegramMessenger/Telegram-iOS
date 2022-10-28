import Foundation

public enum MessageHistoryInput: Equatable, Hashable {
    public struct Automatic: Equatable, Hashable {
        public var tag: MessageTags
        public var appendMessagesFromTheSameGroup: Bool
        
        public init(tag: MessageTags, appendMessagesFromTheSameGroup: Bool) {
            self.tag = tag
            self.appendMessagesFromTheSameGroup = appendMessagesFromTheSameGroup
        }
    }
    
    case automatic(threadId: Int64?, info: Automatic?)
    case external(MessageHistoryViewExternalInput, MessageTags?)
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .automatic:
            hasher.combine(1)
        case .external:
            hasher.combine(2)
        }
    }
}

private extension MessageHistoryInput {
    func fetch(postbox: PostboxImpl, peerId: PeerId, namespace: MessageId.Namespace, from fromIndex: MessageIndex, includeFrom: Bool, to toIndex: MessageIndex, ignoreMessagesInTimestampRange: ClosedRange<Int32>?, limit: Int) -> [IntermediateMessage] {
        switch self {
        case let .automatic(threadId, automatic):
            var items = postbox.messageHistoryTable.fetch(peerId: peerId, namespace: namespace, tag: automatic?.tag, threadId: threadId, from: fromIndex, includeFrom: includeFrom, to: toIndex, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, limit: limit)
            if let automatic = automatic, automatic.appendMessagesFromTheSameGroup {
                enum Direction {
                    case lowToHigh
                    case highToLow
                }
                func processItem(index: Int, direction: Direction) {
                    guard let _ = items[index].groupInfo else {
                        return
                    }
                    if var group = postbox.messageHistoryTable.getMessageGroup(at: items[index].index, limit: 20), group.count > 1 {
                        switch direction {
                        case .lowToHigh:
                            group.sort(by: { lhs, rhs in
                                return lhs.index < rhs.index
                            })
                        case .highToLow:
                            group.sort(by: { lhs, rhs in
                                return lhs.index > rhs.index
                            })
                        }
                        items.replaceSubrange(index ..< index + 1, with: group)
                        switch direction {
                        case .lowToHigh:
                            items.removeFirst(group.count - 1)
                        case .highToLow:
                            items.removeLast(group.count - 1)
                        }
                    }
                }
                if fromIndex < toIndex {
                    for i in 0 ..< items.count {
                        processItem(index: i, direction: .lowToHigh)
                    }
                } else {
                    for i in (0 ..< items.count).reversed() {
                        processItem(index: i, direction: .highToLow)
                    }
                }
            }
            return items
        case let .external(input, tag):
            switch input.content {
            case let .thread(peerId, id, _):
                return postbox.messageHistoryTable.fetch(peerId: peerId, namespace: namespace, tag: tag, threadId: id, from: fromIndex, includeFrom: includeFrom, to: toIndex, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, limit: limit)
            case let .messages(allIndices, _, _):
                if allIndices.isEmpty {
                    return []
                }
                var indices: [MessageIndex] = []
                var startIndex = fromIndex
                var localIncludeFrom = includeFrom
                while true {
                    var sliceIndices: [MessageIndex] = []
                    if fromIndex < toIndex {
                        for i in 0 ..< allIndices.count {
                            var matches = false
                            if localIncludeFrom {
                                if allIndices[i] >= startIndex {
                                    matches = true
                                }
                            } else {
                                if allIndices[i] > startIndex {
                                    matches = true
                                }
                            }
                            if matches {
                                for j in i ..< min(i + limit, allIndices.count) {
                                    sliceIndices.append(allIndices[j])
                                }
                                break
                            }
                        }
                        //sliceIndices = self.threadsTable.laterIndices(threadId: threadId, peerId: peerId, namespace: namespace, index: startIndex, includeFrom: localIncludeFrom, count: limit)
                    } else {
                        for i in (0 ..< allIndices.count).reversed() {
                            var matches = false
                            if localIncludeFrom {
                                if allIndices[i] <= startIndex {
                                    matches = true
                                }
                            } else {
                                if allIndices[i] < startIndex {
                                    matches = true
                                }
                            }
                            if matches {
                                for j in (max(i - limit + 1, 0) ... i).reversed() {
                                    sliceIndices.append(allIndices[j])
                                }
                                break
                            }
                        }
                        
                        //sliceIndices = self.threadsTable.earlierIndices(threadId: threadId, peerId: peerId, namespace: namespace, index: startIndex, includeFrom: localIncludeFrom, count: limit)
                    }
                    if sliceIndices.isEmpty {
                        break
                    }
                    startIndex = sliceIndices[sliceIndices.count - 1]
                    localIncludeFrom = false
                    
                    for index in sliceIndices {
                        if let ignoreMessagesInTimestampRange = ignoreMessagesInTimestampRange {
                            if ignoreMessagesInTimestampRange.contains(index.timestamp) {
                                continue
                            }
                        }
                        indices.append(index)
                    }
                    if indices.count >= limit {
                        break
                    }
                }
                var result: [IntermediateMessage] = []
                if fromIndex < toIndex {
                    assert(indices.sorted() == indices)
                } else {
                    assert(indices.sorted().reversed() == indices)
                }
                for index in indices {
                    if fromIndex < toIndex {
                        if index < fromIndex || index > toIndex {
                            continue
                        }
                    } else {
                        if index < toIndex || index > fromIndex {
                            continue
                        }
                    }
                    if let message = postbox.messageHistoryTable.getMessage(index) {
                        result.append(message)
                    } else {
                        assertionFailure()
                    }
                }
                return result
            }
        }
    }
    
    func getMessageCountInRange(postbox: PostboxImpl, peerId: PeerId, namespace: MessageId.Namespace, lowerBound: MessageIndex, upperBound: MessageIndex) -> Int {
        switch self {
        case let .automatic(threadId, automatic):
            if let automatic = automatic {
                if let threadId = threadId {
                    return postbox.messageHistoryThreadTagsTable.getMessageCountInRange(tag: automatic.tag, threadId: threadId, peerId: peerId, namespace: namespace, lowerBound: lowerBound, upperBound: upperBound)
                } else {
                    return postbox.messageHistoryTagsTable.getMessageCountInRange(tag: automatic.tag, peerId: peerId, namespace: namespace, lowerBound: lowerBound, upperBound: upperBound)
                }
            } else {
                if let threadId = threadId {
                    return postbox.messageHistoryThreadsTable.getMessageCountInRange(threadId: threadId, peerId: peerId, namespace: namespace, lowerBound: lowerBound, upperBound: upperBound)
                } else {
                    return postbox.messageHistoryTable.getMessageCountInRange(peerId: peerId, namespace: namespace, tag: nil, lowerBound: lowerBound, upperBound: upperBound)
                }
            }
        case .external:
            return 0
        }
    }
}

public struct PeerIdAndNamespace: Hashable {
    public let peerId: PeerId
    public let namespace: MessageId.Namespace
    
    public init(peerId: PeerId, namespace: MessageId.Namespace) {
        self.peerId = peerId
        self.namespace = namespace
    }
}

private func canContainHoles(_ peerIdAndNamespace: PeerIdAndNamespace, input: MessageHistoryInput, seedConfiguration: SeedConfiguration) -> Bool {
    switch input {
    case .automatic:
        guard let messageNamespaces = seedConfiguration.messageHoles[peerIdAndNamespace.peerId.namespace] else {
            return false
        }
        return messageNamespaces[peerIdAndNamespace.namespace] != nil
    case let .external(data, _):
        switch data.content {
        case .thread:
            return true
        case .messages:
            return false
        }
    }
}

private struct MessageMonthIndex: Equatable {
    let year: Int32
    let month: Int32
    
    var timestamp: Int32 {
        var timeinfo = tm()
        timeinfo.tm_year = self.year
        timeinfo.tm_mon = self.month
        return Int32(timegm(&timeinfo))
    }
    
    init(year: Int32, month: Int32) {
        self.year = year
        self.month = month
    }
    
    init(timestamp: Int32) {
        var t = Int(timestamp)
        var timeinfo = tm()
        gmtime_r(&t, &timeinfo)
        self.year = timeinfo.tm_year
        self.month = timeinfo.tm_mon
    }
    
    var successor: MessageMonthIndex {
        if self.month == 11 {
            return MessageMonthIndex(year: self.year + 1, month: 0)
        } else {
            return MessageMonthIndex(year: self.year, month: self.month + 1)
        }
    }
    
    var predecessor: MessageMonthIndex {
        if self.month == 0 {
            return MessageMonthIndex(year: self.year - 1, month: 11)
        } else {
            return MessageMonthIndex(year: self.year, month: self.month - 1)
        }
    }
}

private func monthUpperBoundIndex(peerId: PeerId, namespace: MessageId.Namespace, index: MessageMonthIndex) -> MessageIndex {
    return MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: 0), timestamp: index.successor.timestamp)
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

func binaryIndexOrLower(_ inputArr: [MessageHistoryMessageEntry], _ searchItem: HistoryViewAnchor) -> Int {
    var lo = 0
    var hi = inputArr.count - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        if searchItem.isGreater(than: inputArr[mid].message.index) {
            lo = mid + 1
        } else if searchItem.isLower(than: inputArr[mid].message.index) {
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

private func sampleEntries(orderedEntriesBySpace: [PeerIdAndNamespace: OrderedHistoryViewEntries], anchor: HistoryViewAnchor, halfLimit: Int) -> (lowerOrAtAnchor: [(PeerIdAndNamespace, Int)], higherThanAnchor: [(PeerIdAndNamespace, Int)]) {
    var previousAnchorIndices: [PeerIdAndNamespace: Int] = [:]
    var nextAnchorIndices: [PeerIdAndNamespace: Int] = [:]
    for (space, items) in orderedEntriesBySpace {
        previousAnchorIndices[space] = items.lowerOrAtAnchor.count - 1
        nextAnchorIndices[space] = 0
    }
    
    var backwardsResult: [(PeerIdAndNamespace, Int)] = []
    var result: [(PeerIdAndNamespace, Int)] = []
    
    while true {
        var minSpace: PeerIdAndNamespace?
        for (space, value) in previousAnchorIndices {
            if value != -1 {
                if let minSpaceValue = minSpace {
                    if orderedEntriesBySpace[space]!.lowerOrAtAnchor[value].index > orderedEntriesBySpace[minSpaceValue]!.lowerOrAtAnchor[previousAnchorIndices[minSpaceValue]!].index {
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
            if backwardsResult.count == halfLimit {
                break
            }
        }
        
        if minSpace == nil {
            break
        }
    }
    
    while true {
        var maxSpace: PeerIdAndNamespace?
        for (space, value) in nextAnchorIndices {
            if value != orderedEntriesBySpace[space]!.higherThanAnchor.count {
                if let maxSpaceValue = maxSpace {
                    if orderedEntriesBySpace[space]!.higherThanAnchor[value].index < orderedEntriesBySpace[maxSpaceValue]!.higherThanAnchor[nextAnchorIndices[maxSpaceValue]!].index {
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
            if result.count == halfLimit {
                break
            }
        }
        
        if maxSpace == nil {
            break
        }
    }
    return (backwardsResult.reversed(), result)
}

struct SampledHistoryViewHole: Equatable {
    let peerId: PeerId
    let namespace: MessageId.Namespace
    let tag: MessageTags?
    let threadId: Int64?
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

private func sampleHoleRanges(input: MessageHistoryInput, orderedEntriesBySpace: [PeerIdAndNamespace: OrderedHistoryViewEntries], holes: HistoryViewHoles, anchor: HistoryViewAnchor, halfLimit: Int, seedConfiguration: SeedConfiguration) -> (clipRanges: [ClosedRange<MessageIndex>], sampledHole: SampledHistoryViewHole?) {
    var clipRanges: [ClosedRange<MessageIndex>] = []
    var sampledHole: (distanceFromAnchor: Int?, hole: SampledHistoryViewHole)?
    
    var tag: MessageTags?
    var threadId: Int64?
    switch input {
    case let .automatic(threadIdValue, automatic):
        tag = automatic?.tag
        threadId = threadIdValue
    case let .external(value, _):
        switch value.content {
        case let .thread(_, id, _):
            threadId = id
        case .messages:
            threadId = nil
        }
    }
    
    for (space, indices) in holes.holesBySpace {
        if indices.isEmpty {
            continue
        }
        switch input {
        case .automatic:
            assert(canContainHoles(space, input: input, seedConfiguration: seedConfiguration))
        case let .external(data, _):
            switch data.content {
            case .thread:
                assert(canContainHoles(space, input: input, seedConfiguration: seedConfiguration))
            case .messages:
                break
            }
        }
        switch anchor {
            case .lowerBound, .upperBound:
                break
            case let .index(index):
                if index.id.peerId == space.peerId && index.id.namespace == space.namespace {
                    if indices.contains(Int(index.id.id)) {
                        return ([MessageIndex.absoluteLowerBound() ... MessageIndex.absoluteUpperBound()], SampledHistoryViewHole(peerId: space.peerId, namespace: space.namespace, tag: tag, threadId: threadId, indices: indices, startId: index.id.id, endId: nil))
                    }
                }
        }
        guard let items = orderedEntriesBySpace[space], (!items.lowerOrAtAnchor.isEmpty || !items.higherThanAnchor.isEmpty) else {
            let holeBounds: (startId: MessageId.Id, endId: MessageId.Id)
            switch anchor {
                case .lowerBound:
                    holeBounds = (1, Int32.max - 1)
                case .upperBound, .index:
                    holeBounds = (Int32.max - 1, 1)
            }
            if case let .index(index) = anchor, index.id.peerId == space.peerId {
                return ([MessageIndex.absoluteLowerBound() ... MessageIndex.absoluteUpperBound()], SampledHistoryViewHole(peerId: space.peerId, namespace: space.namespace, tag: tag, threadId: threadId, indices: indices, startId: holeBounds.startId, endId: holeBounds.endId))
            } else {
                sampledHole = (nil, SampledHistoryViewHole(peerId: space.peerId, namespace: space.namespace, tag: tag, threadId: threadId, indices: indices, startId: holeBounds.startId, endId: holeBounds.endId))
                continue
            }
        }
        
        var lowerOrAtAnchorHole: (distanceFromAnchor: Int, hole: SampledHistoryViewHole)?
        
        for i in (-1 ..< items.lowerOrAtAnchor.count).reversed() {
            let startingMessageId: MessageId.Id
            if items.higherThanAnchor.isEmpty {
                startingMessageId = Int32.max - 1
            } else {
                startingMessageId = items.higherThanAnchor[0].index.id.id
            }
            let currentMessageId: MessageId.Id
            if i == -1 {
                if items.lowerOrAtAnchor.count >= halfLimit {
                    break
                }
                currentMessageId = 1
            } else {
                currentMessageId = items.lowerOrAtAnchor[i].index.id.id
            }
            let range: ClosedRange<Int>
            if currentMessageId <= startingMessageId {
                range = Int(currentMessageId) ... Int(startingMessageId)
            } else {
                assertionFailure()
                range = Int(startingMessageId) ... Int(currentMessageId)
            }
            if indices.intersects(integersIn: range) {
                let holeStartIndex: Int
                if let value = indices.integerLessThanOrEqualTo(Int(startingMessageId)) {
                    holeStartIndex = value
                } else {
                    holeStartIndex = indices[indices.endIndex]
                }
                lowerOrAtAnchorHole = (items.lowerOrAtAnchor.count - i, SampledHistoryViewHole(peerId: space.peerId, namespace: space.namespace, tag: tag, threadId: threadId, indices: indices, startId: Int32(holeStartIndex), endId: 1))
                
                if i == -1 {
                    if items.lowerOrAtAnchor.count == 0 {
                        if items.higherThanAnchor.count == 0 {
                            clipRanges.append(MessageIndex.absoluteLowerBound() ... MessageIndex.absoluteUpperBound())
                        } else {
                            let clipIndex = items.higherThanAnchor[0].index.peerLocalPredecessor()
                            clipRanges.append(MessageIndex.absoluteLowerBound() ... clipIndex)
                        }
                    } else {
                        let clipIndex = items.lowerOrAtAnchor[0].index.peerLocalPredecessor()
                        clipRanges.append(MessageIndex.absoluteLowerBound() ... clipIndex)
                    }
                } else {
                    if i == items.lowerOrAtAnchor.count - 1 {
                        if items.higherThanAnchor.count == 0 {
                            clipRanges.append(MessageIndex.absoluteLowerBound() ... MessageIndex.absoluteUpperBound())
                        } else {
                            let clipIndex = items.higherThanAnchor[0].index.peerLocalPredecessor()
                            clipRanges.append(MessageIndex.absoluteLowerBound() ... clipIndex)
                        }
                    } else {
                        let clipIndex: MessageIndex
                        if indices.contains(Int(items.lowerOrAtAnchor[i + 1].index.id.id)) {
                            clipIndex = items.lowerOrAtAnchor[i + 1].index
                        } else {
                            clipIndex = items.lowerOrAtAnchor[i + 1].index.peerLocalPredecessor()
                        }
                        clipRanges.append(MessageIndex.absoluteLowerBound() ... clipIndex)
                    }
                }
                break
            }
        }
        
        var higherThanAnchorHole: (distanceFromAnchor: Int, hole: SampledHistoryViewHole)?
        
        for i in (0 ..< items.higherThanAnchor.count + 1) {
            let startingMessageId: MessageId.Id
            if items.lowerOrAtAnchor.isEmpty {
                startingMessageId = 1
            } else {
                startingMessageId = items.lowerOrAtAnchor[items.lowerOrAtAnchor.count - 1].index.id.id
            }
            let currentMessageId: MessageId.Id
            if i == items.higherThanAnchor.count {
                if items.higherThanAnchor.count >= halfLimit {
                    break
                }
                currentMessageId = Int32.max - 1
            } else {
                currentMessageId = items.higherThanAnchor[i].index.id.id
            }
            let range: ClosedRange<Int>
            if startingMessageId <= currentMessageId {
                range = Int(startingMessageId) ... Int(currentMessageId)
            } else {
                assertionFailure()
                range = Int(currentMessageId) ... Int(startingMessageId)
            }
            if indices.intersects(integersIn: range) {
                let holeStartIndex: Int
                if let value = indices.integerGreaterThanOrEqualTo(Int(startingMessageId)) {
                    holeStartIndex = value
                } else {
                    holeStartIndex = indices[indices.startIndex]
                }
                higherThanAnchorHole = (i, SampledHistoryViewHole(peerId: space.peerId, namespace: space.namespace, tag: tag, threadId: threadId, indices: indices, startId: Int32(holeStartIndex), endId: Int32.max - 1))
                
                if i == items.higherThanAnchor.count {
                    if items.higherThanAnchor.count == 0 {
                        if items.lowerOrAtAnchor.count == 0 {
                            clipRanges.append(MessageIndex.absoluteLowerBound() ... MessageIndex.absoluteUpperBound())
                        } else {
                            let clipIndex = items.lowerOrAtAnchor[items.lowerOrAtAnchor.count - 1].index.peerLocalSuccessor()
                            clipRanges.append(clipIndex ... MessageIndex.absoluteUpperBound())
                        }
                    } else {
                        let clipIndex = items.higherThanAnchor[items.higherThanAnchor.count - 1].index.peerLocalSuccessor()
                        clipRanges.append(clipIndex ... MessageIndex.absoluteUpperBound())
                    }
                } else {
                    if i == 0 {
                        if items.lowerOrAtAnchor.count == 0 {
                            clipRanges.append(MessageIndex.absoluteLowerBound() ... MessageIndex.absoluteUpperBound())
                        } else {
                            let clipIndex = items.lowerOrAtAnchor[items.lowerOrAtAnchor.count - 1].index.peerLocalSuccessor()
                            clipRanges.append(clipIndex ... MessageIndex.absoluteUpperBound())
                        }
                    } else {
                        let clipIndex: MessageIndex
                        if indices.contains(Int(items.higherThanAnchor[i - 1].index.id.id)) {
                            clipIndex = items.higherThanAnchor[i - 1].index
                        } else {
                            clipIndex = items.higherThanAnchor[i - 1].index.peerLocalSuccessor()
                        }
                        clipRanges.append(clipIndex ... MessageIndex.absoluteUpperBound())
                    }
                }
                break
            }
        }
        
        var chosenHole: (distanceFromAnchor: Int, hole: SampledHistoryViewHole)?
        if let lowerOrAtAnchorHole = lowerOrAtAnchorHole, let higherThanAnchorHole = higherThanAnchorHole {
            if items.lowerOrAtAnchor.isEmpty != items.higherThanAnchor.isEmpty {
                if !items.lowerOrAtAnchor.isEmpty {
                    chosenHole = lowerOrAtAnchorHole
                } else {
                    chosenHole = higherThanAnchorHole
                }
            } else {
                if lowerOrAtAnchorHole.distanceFromAnchor < higherThanAnchorHole.distanceFromAnchor {
                    chosenHole = lowerOrAtAnchorHole
                } else {
                    chosenHole = higherThanAnchorHole
                }
            }
        } else if let lowerOrAtAnchorHole = lowerOrAtAnchorHole {
            chosenHole = lowerOrAtAnchorHole
        } else if let higherThanAnchorHole = higherThanAnchorHole {
            chosenHole = higherThanAnchorHole
        }
        
        if let chosenHole = chosenHole {
            if let current = sampledHole {
                if let distance = current.distanceFromAnchor {
                    if chosenHole.distanceFromAnchor < distance {
                        sampledHole = (chosenHole.distanceFromAnchor, chosenHole.hole)
                    }
                }
            } else {
                sampledHole = (chosenHole.distanceFromAnchor, chosenHole.hole)
            }
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
    private(set) var lowerOrAtAnchor: [MutableMessageHistoryEntry]
    private(set) var higherThanAnchor: [MutableMessageHistoryEntry]
    
    private(set) var reverseAssociatedIndices: [MessageId: [MessageIndex]] = [:]
    
    fileprivate init(lowerOrAtAnchor: [MutableMessageHistoryEntry], higherThanAnchor: [MutableMessageHistoryEntry]) {
        self.lowerOrAtAnchor = lowerOrAtAnchor
        self.higherThanAnchor = higherThanAnchor
        
        for entry in lowerOrAtAnchor {
            for id in entry.getAssociatedMessageIds() {
                if self.reverseAssociatedIndices[id] == nil {
                    self.reverseAssociatedIndices[id] = [entry.index]
                } else {
                    self.reverseAssociatedIndices[id]!.append(entry.index)
                }
            }
        }
        for entry in higherThanAnchor {
            for id in entry.getAssociatedMessageIds() {
                if self.reverseAssociatedIndices[id] == nil {
                    self.reverseAssociatedIndices[id] = [entry.index]
                } else {
                    self.reverseAssociatedIndices[id]!.append(entry.index)
                }
            }
        }
    }
    
    mutating func setLowerOrAtAnchorAtArrayIndex(_ index: Int, to value: MutableMessageHistoryEntry) {
        let previousIndex = self.lowerOrAtAnchor[index].index
        let updatedIndex = value.index
        let previousAssociatedIds = self.lowerOrAtAnchor[index].getAssociatedMessageIds()
        let updatedAssociatedIds = value.getAssociatedMessageIds()
        
        self.lowerOrAtAnchor[index] = value
        
        if previousAssociatedIds != updatedAssociatedIds {
            for id in previousAssociatedIds {
                self.reverseAssociatedIndices[id]?.removeAll(where: { $0 == previousIndex })
                if let isEmpty = self.reverseAssociatedIndices[id]?.isEmpty, isEmpty {
                    self.reverseAssociatedIndices.removeValue(forKey: id)
                }
            }
            for id in updatedAssociatedIds {
                if self.reverseAssociatedIndices[id] == nil {
                    self.reverseAssociatedIndices[id] = [updatedIndex]
                } else {
                    self.reverseAssociatedIndices[id]!.append(updatedIndex)
                }
            }
        }
    }
    
    mutating func setHigherThanAnchorAtArrayIndex(_ index: Int, to value: MutableMessageHistoryEntry) {
        let previousIndex = self.higherThanAnchor[index].index
        let updatedIndex = value.index
        let previousAssociatedIds = self.higherThanAnchor[index].getAssociatedMessageIds()
        let updatedAssociatedIds = value.getAssociatedMessageIds()
        
        self.higherThanAnchor[index] = value
        
        if previousAssociatedIds != updatedAssociatedIds {
            for id in previousAssociatedIds {
                self.reverseAssociatedIndices[id]?.removeAll(where: { $0 == previousIndex })
                if let isEmpty = self.reverseAssociatedIndices[id]?.isEmpty, isEmpty {
                    self.reverseAssociatedIndices.removeValue(forKey: id)
                }
            }
            for id in updatedAssociatedIds {
                if self.reverseAssociatedIndices[id] == nil {
                    self.reverseAssociatedIndices[id] = [updatedIndex]
                } else {
                    self.reverseAssociatedIndices[id]!.append(updatedIndex)
                }
            }
        }
    }
    
    mutating func insertLowerOrAtAnchorAtArrayIndex(_ index: Int, value: MutableMessageHistoryEntry) {
        self.lowerOrAtAnchor.insert(value, at: index)
        
        for id in value.getAssociatedMessageIds() {
            if self.reverseAssociatedIndices[id] == nil {
                self.reverseAssociatedIndices[id] = [value.index]
            } else {
                self.reverseAssociatedIndices[id]!.append(value.index)
            }
        }
    }
    
    mutating func insertHigherThanAnchorAtArrayIndex(_ index: Int, value: MutableMessageHistoryEntry) {
        self.higherThanAnchor.insert(value, at: index)
        
        for id in value.getAssociatedMessageIds() {
            if self.reverseAssociatedIndices[id] == nil {
                self.reverseAssociatedIndices[id] = [value.index]
            } else {
                self.reverseAssociatedIndices[id]!.append(value.index)
            }
        }
    }
    
    mutating func removeLowerOrAtAnchorAtArrayIndex(_ index: Int) {
        let previousIndex = self.lowerOrAtAnchor[index].index
        for id in self.lowerOrAtAnchor[index].getAssociatedMessageIds() {
            self.reverseAssociatedIndices[id]?.removeAll(where: { $0 == previousIndex })
            if let isEmpty = self.reverseAssociatedIndices[id]?.isEmpty, isEmpty {
                self.reverseAssociatedIndices.removeValue(forKey: id)
            }
        }
        
        self.lowerOrAtAnchor.remove(at: index)
    }
    
    mutating func removeHigherThanAnchorAtArrayIndex(_ index: Int) {
        let previousIndex = self.higherThanAnchor[index].index
        for id in self.higherThanAnchor[index].getAssociatedMessageIds() {
            self.reverseAssociatedIndices[id]?.removeAll(where: { $0 == previousIndex })
            if let isEmpty = self.reverseAssociatedIndices[id]?.isEmpty, isEmpty {
                self.reverseAssociatedIndices.removeValue(forKey: id)
            }
        }
        
        self.higherThanAnchor.remove(at: index)
    }
    
    mutating func fixMonotony() {
        if self.lowerOrAtAnchor.count > 1 {
            for i in 1 ..< self.lowerOrAtAnchor.count {
                if self.lowerOrAtAnchor[i].index < self.lowerOrAtAnchor[i - 1].index {
                    assertionFailure()
                    break
                }
            }
        }
        if self.higherThanAnchor.count > 1 {
            for i in 1 ..< self.higherThanAnchor.count {
                if self.higherThanAnchor[i].index < self.higherThanAnchor[i - 1].index {
                    assertionFailure()
                    break
                }
            }
        }
        
        var fix = false
        if self.lowerOrAtAnchor.count > 1 {
            for i in 1 ..< self.lowerOrAtAnchor.count {
                if self.lowerOrAtAnchor[i].index.id.id < self.lowerOrAtAnchor[i - 1].index.id.id {
                    fix = true
                    break
                }
            }
        }
        if !fix && self.higherThanAnchor.count > 1 {
            for i in 1 ..< self.higherThanAnchor.count {
                if self.higherThanAnchor[i].index.id.id < self.higherThanAnchor[i - 1].index.id.id {
                    fix = true
                    break
                }
            }
        }
        if fix {
            //assertionFailure()
            self.lowerOrAtAnchor.sort(by: { $0.index.id.id < $1.index.id.id })
            self.higherThanAnchor.sort(by: { $0.index.id.id < $1.index.id.id })
        }
    }
    
    func find(index: MessageIndex) -> MutableMessageHistoryEntry? {
        if let entryIndex = binarySearch(self.lowerOrAtAnchor, extract: { $0.index }, searchItem: index) {
            return self.lowerOrAtAnchor[entryIndex]
        } else if let entryIndex = binarySearch(self.higherThanAnchor, extract: { $0.index }, searchItem: index) {
            return self.higherThanAnchor[entryIndex]
        } else {
            return nil
        }
    }
    
    func indicesForAssociatedMessageId(_ id: MessageId) -> [MessageIndex]? {
        return self.reverseAssociatedIndices[id]
    }
    
    var first: MutableMessageHistoryEntry? {
        return self.lowerOrAtAnchor.first ?? self.higherThanAnchor.first
    }
    
    mutating func mutableScan(_ f: (MutableMessageHistoryEntry) -> MutableMessageHistoryEntry?) -> Bool {
        var anyUpdated = false
        for i in 0 ..< self.lowerOrAtAnchor.count {
            if let updated = f(self.lowerOrAtAnchor[i]) {
                self.setLowerOrAtAnchorAtArrayIndex(i, to: updated)
                anyUpdated = true
            }
        }
        for i in 0 ..< self.higherThanAnchor.count {
            if let updated = f(self.higherThanAnchor[i]) {
                self.setHigherThanAnchorAtArrayIndex(i, to: updated)
                anyUpdated = true
            }
        }
        return anyUpdated
    }
    
    mutating func update(index: MessageIndex, _ f: (MutableMessageHistoryEntry) -> MutableMessageHistoryEntry?) -> Bool {
        if let entryIndex = binarySearch(self.lowerOrAtAnchor, extract: { $0.index }, searchItem: index) {
            if let updated = f(self.lowerOrAtAnchor[entryIndex]) {
                self.setLowerOrAtAnchorAtArrayIndex(entryIndex, to: updated)
                return true
            }
        } else if let entryIndex = binarySearch(self.higherThanAnchor, extract: { $0.index }, searchItem: index) {
            if let updated = f(self.higherThanAnchor[entryIndex]) {
                self.setHigherThanAnchorAtArrayIndex(entryIndex, to: updated)
                return true
            }
        }
        return false
    }
    
    mutating func remove(index: MessageIndex) -> Bool {
        if let entryIndex = binarySearch(self.lowerOrAtAnchor, extract: { $0.index }, searchItem: index) {
            self.removeLowerOrAtAnchorAtArrayIndex(entryIndex)
            return true
        } else if let entryIndex = binarySearch(self.higherThanAnchor, extract: { $0.index }, searchItem: index) {
            self.removeHigherThanAnchorAtArrayIndex(entryIndex)
            return true
        } else {
            return false
        }
    }
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
    let namespaces: MessageIdNamespaces
    let input: MessageHistoryInput
    let statistics: MessageHistoryViewOrderStatistics
    let ignoreMessagesInTimestampRange: ClosedRange<Int32>?
    let halfLimit: Int
    let seedConfiguration: SeedConfiguration
    var orderedEntriesBySpace: [PeerIdAndNamespace: OrderedHistoryViewEntries]
    var holes: HistoryViewHoles
    var spacesWithRemovals = Set<PeerIdAndNamespace>()
    
    init(anchor: HistoryViewAnchor, tag: MessageTags?, appendMessagesFromTheSameGroup: Bool, namespaces: MessageIdNamespaces, statistics: MessageHistoryViewOrderStatistics, ignoreMessagesInTimestampRange: ClosedRange<Int32>?, halfLimit: Int, locations: MessageHistoryViewInput, postbox: PostboxImpl, holes: HistoryViewHoles) {
        precondition(halfLimit >= 3)
        self.anchor = anchor
        self.namespaces = namespaces
        self.statistics = statistics
        self.ignoreMessagesInTimestampRange = ignoreMessagesInTimestampRange
        self.halfLimit = halfLimit
        self.seedConfiguration = postbox.seedConfiguration
        self.orderedEntriesBySpace = [:]
        self.holes = holes
        
        var peerIds: [PeerId] = []
        var spaces: [PeerIdAndNamespace] = []
        
        let input: MessageHistoryInput
        switch locations {
        case let .single(peerId, threadId):
            peerIds.append(peerId)
            input = .automatic(threadId: threadId, info: tag.flatMap { tag in
                MessageHistoryInput.Automatic(tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup)
            })
        case let .associated(peerId, associatedId):
            peerIds.append(peerId)
            if let associatedId = associatedId {
                peerIds.append(associatedId.peerId)
            }
            input = .automatic(threadId: nil, info: tag.flatMap { tag in
                MessageHistoryInput.Automatic(tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup)
            })
        case let .external(external):
            switch external.content {
            case let .thread(peerId, _, _):
                peerIds.append(peerId)
                input = .external(external, tag)
            case .messages:
                input = .external(external, tag)
                spaces.append(PeerIdAndNamespace(peerId: PeerId(namespace: PeerId.Namespace.max, id: PeerId.Id.max), namespace: 0))
            }
        }
        self.input = input
        
        for peerId in peerIds {
            for namespace in postbox.messageHistoryIndexTable.existingNamespaces(peerId: peerId) {
                if namespaces.contains(namespace) {
                    spaces.append(PeerIdAndNamespace(peerId: peerId, namespace: namespace))
                }
            }
        }
        
        for space in spaces {
            self.fillSpace(space: space, postbox: postbox)
        }
    }
    
    private func fillSpace(space: PeerIdAndNamespace, postbox: PostboxImpl) {
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
        
        var lowerOrAtAnchorMessages: [MutableMessageHistoryEntry] = []
        var higherThanAnchorMessages: [MutableMessageHistoryEntry] = []
        
        if let currentEntries = self.orderedEntriesBySpace[space] {
            lowerOrAtAnchorMessages = currentEntries.lowerOrAtAnchor.reversed()
            higherThanAnchorMessages = currentEntries.higherThanAnchor
        }
        
        func mapEntry(_ message: IntermediateMessage) -> MutableMessageHistoryEntry {
            return .IntermediateMessageEntry(message, nil, nil)
        }
        
        if lowerOrAtAnchorMessages.count < self.halfLimit {
            let nextLowerIndex: (index: MessageIndex, includeFrom: Bool)
            if let lastMessage = lowerOrAtAnchorMessages.min(by: { $0.index < $1.index }) {
                nextLowerIndex = (lastMessage.index, false)
            } else {
                nextLowerIndex = (anchorIndex, true)
            }
            lowerOrAtAnchorMessages.append(contentsOf: self.input.fetch(postbox: postbox, peerId: space.peerId, namespace: space.namespace, from: nextLowerIndex.index, includeFrom: nextLowerIndex.includeFrom, to: lowerBound, ignoreMessagesInTimestampRange: self.ignoreMessagesInTimestampRange, limit: self.halfLimit - lowerOrAtAnchorMessages.count).map(mapEntry))
        }
        if higherThanAnchorMessages.count < self.halfLimit {
            let nextHigherIndex: MessageIndex
            if let lastMessage = higherThanAnchorMessages.max(by: { $0.index < $1.index }) {
                nextHigherIndex = lastMessage.index
            } else {
                nextHigherIndex = anchorIndex
            }
            higherThanAnchorMessages.append(contentsOf: self.input.fetch(postbox: postbox, peerId: space.peerId, namespace: space.namespace, from: nextHigherIndex, includeFrom: false, to: upperBound, ignoreMessagesInTimestampRange: self.ignoreMessagesInTimestampRange, limit: self.halfLimit - higherThanAnchorMessages.count).map(mapEntry))
        }
        
        lowerOrAtAnchorMessages.reverse()
        
        assert(lowerOrAtAnchorMessages.count <= self.halfLimit)
        assert(higherThanAnchorMessages.count <= self.halfLimit)
        
        var entries = OrderedHistoryViewEntries(lowerOrAtAnchor: lowerOrAtAnchorMessages, higherThanAnchor: higherThanAnchorMessages)
        
        if case .automatic = self.input, self.statistics.contains(.combinedLocation), let first = entries.first {
            let messageIndex = first.index
            let previousCount = self.input.getMessageCountInRange(postbox: postbox, peerId: space.peerId, namespace: space.namespace, lowerBound: MessageIndex.lowerBound(peerId: space.peerId, namespace: space.namespace), upperBound: messageIndex)
            let nextCount = self.input.getMessageCountInRange(postbox: postbox, peerId: space.peerId, namespace: space.namespace, lowerBound: messageIndex, upperBound: MessageIndex.upperBound(peerId: space.peerId, namespace: space.namespace))
            let initialLocation = MessageHistoryEntryLocation(index: previousCount - 1, count: previousCount + nextCount - 1)
            var nextLocation = initialLocation
            
            let _ = entries.mutableScan { entry in
                let currentLocation = nextLocation
                nextLocation = nextLocation.successor
                switch entry {
                case let .IntermediateMessageEntry(message, _, monthLocation):
                    return .IntermediateMessageEntry(message, currentLocation, monthLocation)
                case let .MessageEntry(entry, reloadAssociatedMessages, reloadPeers):
                    return .MessageEntry(MessageHistoryMessageEntry(message: entry.message, location: currentLocation, monthLocation: entry.monthLocation, attributes: entry.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
                }
            }
        }

        
        if canContainHoles(space, input: self.input, seedConfiguration: self.seedConfiguration) {
            entries.fixMonotony()
        }
        self.orderedEntriesBySpace[space] = entries
    }
    
    func insertHole(space: PeerIdAndNamespace, range: ClosedRange<MessageId.Id>) -> Bool {
        assert(canContainHoles(space, input: self.input, seedConfiguration: self.seedConfiguration))
        return self.holes.insertHole(space: space, range: range)
    }
    
    func removeHole(space: PeerIdAndNamespace, range: ClosedRange<MessageId.Id>) -> Bool {
        assert(canContainHoles(space, input: self.input, seedConfiguration: self.seedConfiguration))
        return self.holes.removeHole(space: space, range: range)
    }
    
    func updateTimestamp(postbox: PostboxImpl, index: MessageIndex, timestamp: Int32) -> Bool {
        let space = PeerIdAndNamespace(peerId: index.id.peerId, namespace: index.id.namespace)
        if self.orderedEntriesBySpace[space] == nil {
            return false
        }
        guard let entry = self.orderedEntriesBySpace[space]!.find(index: index) else {
            return false
        }
        var updated = false
        if self.remove(index: index) {
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
            let spaceUpdated = self.orderedEntriesBySpace[space]!.mutableScan({ entry in
                if let groupInfo = spaceMapping[entry.index.id.id] {
                    updated = true
                    switch entry {
                        case let .IntermediateMessageEntry(message, location, monthLocation):
                            return .IntermediateMessageEntry(message.withUpdatedGroupInfo(groupInfo), location, monthLocation)
                        case let .MessageEntry(messageEntry, reloadAssociatedMessages, reloadPeers):
                            return .MessageEntry(MessageHistoryMessageEntry(message: messageEntry.message.withUpdatedGroupInfo(groupInfo), location: messageEntry.location, monthLocation: messageEntry.monthLocation, attributes: messageEntry.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
                    }
                }
                return nil
            })
            if spaceUpdated {
                updated = true
            }
        }
        return updated
    }
    
    func updateEmbeddedMedia(index: MessageIndex, buffer: ReadBuffer) -> Bool {
        let space = PeerIdAndNamespace(peerId: index.id.peerId, namespace: index.id.namespace)
        if self.orderedEntriesBySpace[space] == nil {
            return false
        }
        
        return self.orderedEntriesBySpace[space]!.update(index: index, { entry in
            switch entry {
                case let .IntermediateMessageEntry(message, location, monthLocation):
                    return .IntermediateMessageEntry(message.withUpdatedEmbeddedMedia(buffer), location, monthLocation)
                case let .MessageEntry(messageEntry, reloadAssociatedMessages, reloadPeers):
                    return .MessageEntry(MessageHistoryMessageEntry(message: messageEntry.message, location: messageEntry.location, monthLocation: messageEntry.monthLocation, attributes: messageEntry.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
            }
        })
    }
    
    func updateMedia(updatedMedia: [MediaId: Media?]) -> Bool {
        var updated = false
        for space in self.orderedEntriesBySpace.keys {
            let spaceUpdated = self.orderedEntriesBySpace[space]!.mutableScan({ entry in
                switch entry {
                    case let .MessageEntry(value, reloadAssociatedMessages, reloadPeers):
                        let message = value.message
                        var reloadPeers = reloadPeers
                        
                        var rebuild = false
                        for media in message.media {
                            if let mediaId = media.id, let _ = updatedMedia[mediaId] {
                                rebuild = true
                                break
                            }
                        }
                        
                        if rebuild {
                            var messageMedia: [Media] = []
                            for media in message.media {
                                if let mediaId = media.id, let updated = updatedMedia[mediaId] {
                                    if let updated = updated {
                                        if media.peerIds != updated.peerIds {
                                            reloadPeers = true
                                        }
                                        messageMedia.append(updated)
                                    }
                                } else {
                                    messageMedia.append(media)
                                }
                            }
                            let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, threadId: message.threadId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: messageMedia, peers: message.peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds, associatedMedia: message.associatedMedia, associatedThreadInfo: message.associatedThreadInfo)
                            return .MessageEntry(MessageHistoryMessageEntry(message: updatedMessage, location: value.location, monthLocation: value.monthLocation, attributes: value.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
                        }
                    case .IntermediateMessageEntry:
                        break
                }
                return nil
            })
            if spaceUpdated {
                updated = true
            }
        }
        return updated
    }
    
    func add(entry: MutableMessageHistoryEntry) -> Bool {
        if let ignoreMessagesInTimestampRange = self.ignoreMessagesInTimestampRange {
            if ignoreMessagesInTimestampRange.contains(entry.index.timestamp) {
                return false
            }
        }
        
        let space = PeerIdAndNamespace(peerId: entry.index.id.peerId, namespace: entry.index.id.namespace)
        
        if self.orderedEntriesBySpace[space] == nil {
            self.orderedEntriesBySpace[space] = OrderedHistoryViewEntries(lowerOrAtAnchor: [], higherThanAnchor: [])
        }

        var updated = false
        
        if let associatedIndices = self.orderedEntriesBySpace[space]!.indicesForAssociatedMessageId(entry.index.id) {
            for associatedIndex in associatedIndices {
                let _ = self.orderedEntriesBySpace[space]!.update(index: associatedIndex, { current in
                    switch current {
                    case .IntermediateMessageEntry:
                        return current
                    case let .MessageEntry(messageEntry, _, reloadPeers):
                        updated = true
                        return .MessageEntry(messageEntry, reloadAssociatedMessages: true, reloadPeers: reloadPeers)
                    }
                })
            }
        }
        
        if self.anchor.isEqualOrGreater(than: entry.index) {
            let insertionIndex = binaryInsertionIndex(self.orderedEntriesBySpace[space]!.lowerOrAtAnchor, extract: { $0.index }, searchItem: entry.index)
            
            if insertionIndex < self.orderedEntriesBySpace[space]!.lowerOrAtAnchor.count {
                if self.orderedEntriesBySpace[space]!.lowerOrAtAnchor[insertionIndex].index == entry.index {
                    assertionFailure("Inserting an existing index is not allowed")
                    self.orderedEntriesBySpace[space]!.setLowerOrAtAnchorAtArrayIndex(insertionIndex, to: entry)
                    return true
                }
            }
            
            if insertionIndex == 0 && self.orderedEntriesBySpace[space]!.lowerOrAtAnchor.count >= self.halfLimit {
                return updated
            }
            self.orderedEntriesBySpace[space]!.insertLowerOrAtAnchorAtArrayIndex(insertionIndex, value: entry)
            if self.orderedEntriesBySpace[space]!.lowerOrAtAnchor.count > self.halfLimit {
                self.orderedEntriesBySpace[space]!.removeLowerOrAtAnchorAtArrayIndex(0)
            }
            return true
        } else {
            let insertionIndex = binaryInsertionIndex(self.orderedEntriesBySpace[space]!.higherThanAnchor, extract: { $0.index }, searchItem: entry.index)
            
            if insertionIndex < self.orderedEntriesBySpace[space]!.higherThanAnchor.count {
                if self.orderedEntriesBySpace[space]!.higherThanAnchor[insertionIndex].index == entry.index {
                    assertionFailure("Inserting an existing index is not allowed")
                    self.orderedEntriesBySpace[space]!.setHigherThanAnchorAtArrayIndex(insertionIndex, to: entry)
                    return true
                }
            }
            
            if insertionIndex == self.orderedEntriesBySpace[space]!.higherThanAnchor.count && self.orderedEntriesBySpace[space]!.higherThanAnchor.count >= self.halfLimit {
                return updated
            }
            self.orderedEntriesBySpace[space]!.insertHigherThanAnchorAtArrayIndex(insertionIndex, value: entry)
            if self.orderedEntriesBySpace[space]!.higherThanAnchor.count > self.halfLimit {
                self.orderedEntriesBySpace[space]!.removeHigherThanAnchorAtArrayIndex(self.orderedEntriesBySpace[space]!.higherThanAnchor.count - 1)
            }
            return true
        }
    }
    
    func addAssociated(entry: MutableMessageHistoryEntry) -> Bool {
        var updated = false
        
        for (space, _) in self.orderedEntriesBySpace {
            if let associatedIndices = self.orderedEntriesBySpace[space]!.indicesForAssociatedMessageId(entry.index.id) {
                for associatedIndex in associatedIndices {
                    let _ = self.orderedEntriesBySpace[space]!.update(index: associatedIndex, { current in
                        switch current {
                        case .IntermediateMessageEntry:
                            return current
                        case let .MessageEntry(messageEntry, _, reloadPeers):
                            updated = true
                            return .MessageEntry(messageEntry, reloadAssociatedMessages: true, reloadPeers: reloadPeers)
                        }
                    })
                }
            }
        }
        
        return updated
    }
    
    func remove(index: MessageIndex) -> Bool {
        let space = PeerIdAndNamespace(peerId: index.id.peerId, namespace: index.id.namespace)
        if self.orderedEntriesBySpace[space] == nil {
            return false
        }
        
        var updated = false
        
        if let associatedIndices = self.orderedEntriesBySpace[space]!.indicesForAssociatedMessageId(index.id) {
            for associatedIndex in associatedIndices {
                let _ = self.orderedEntriesBySpace[space]!.update(index: associatedIndex, { current in
                    switch current {
                    case .IntermediateMessageEntry:
                        return current
                    case let .MessageEntry(messageEntry, reloadAssociatedMessages, reloadPeers):
                        updated = true
                        
                        if let associatedMessages = messageEntry.message.associatedMessages.filteredOut(keysIn: [index.id]) {
                            return .MessageEntry(MessageHistoryMessageEntry(message: messageEntry.message.withUpdatedAssociatedMessages(associatedMessages), location: messageEntry.location, monthLocation: messageEntry.monthLocation, attributes: messageEntry.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
                        } else {
                            return current
                        }
                    }
                })
            }
        }
        
        if self.orderedEntriesBySpace[space]!.remove(index: index) {
            self.spacesWithRemovals.insert(space)
            updated = true
        }
        
        return updated
    }
    
    func completeAndSample(postbox: PostboxImpl, clipHoles: Bool) -> HistoryViewLoadedSample {
        if !self.spacesWithRemovals.isEmpty {
            for space in self.spacesWithRemovals {
                self.fillSpace(space: space, postbox: postbox)
            }
            self.spacesWithRemovals.removeAll()
        }
        let combinedSpacesAndIndicesByDirection = sampleEntries(orderedEntriesBySpace: self.orderedEntriesBySpace, anchor: self.anchor, halfLimit: self.halfLimit)
        let (clipRanges, sampledHole) = sampleHoleRanges(input: self.input, orderedEntriesBySpace: self.orderedEntriesBySpace, holes: self.holes, anchor: self.anchor, halfLimit: self.halfLimit, seedConfiguration: self.seedConfiguration)
        
        /*switch self.input {
        case .external:
            if sampledHole == nil {
                assert(true)
            }
        default:
            break
        }*/
        
        var holesToLower = false
        var holesToHigher = false
        var result: [MessageHistoryMessageEntry] = []
        if combinedSpacesAndIndicesByDirection.lowerOrAtAnchor.isEmpty && combinedSpacesAndIndicesByDirection.higherThanAnchor.isEmpty {
            if !clipRanges.isEmpty {
                holesToLower = true
                holesToHigher = true
            }
        } else {
            let directions = [combinedSpacesAndIndicesByDirection.lowerOrAtAnchor, combinedSpacesAndIndicesByDirection.higherThanAnchor]
            for directionIndex in 0 ..< directions.count {
                outer: for i in 0 ..< directions[directionIndex].count {
                    let (space, index) = directions[directionIndex][i]
                    
                    let entry: MutableMessageHistoryEntry
                    if directionIndex == 0 {
                        entry = self.orderedEntriesBySpace[space]!.lowerOrAtAnchor[index]
                    } else {
                        entry = self.orderedEntriesBySpace[space]!.higherThanAnchor[index]
                    }
                    
                    if clipHoles && !clipRanges.isEmpty {
                        let entryIndex = entry.index
                        for range in clipRanges {
                            if range.contains(entryIndex) {
                                if directionIndex == 0 && i == 0 {
                                    holesToLower = true
                                }
                                if directionIndex == 1 && i == directions[directionIndex].count - 1 {
                                    holesToHigher = true
                                }
                                continue outer
                            }
                        }
                    }
                    
                    switch entry {
                        case let .MessageEntry(value, reloadAssociatedMessages, reloadPeers):
                            var updatedMessage = value.message
                            if reloadAssociatedMessages {
                                let associatedMessages = postbox.messageHistoryTable.renderAssociatedMessages(associatedMessageIds: value.message.associatedMessageIds, peerTable: postbox.peerTable, threadIndexTable: postbox.messageHistoryThreadIndexTable)
                                updatedMessage = value.message.withUpdatedAssociatedMessages(associatedMessages)
                            }
                            if reloadPeers {
                                updatedMessage = postbox.messageHistoryTable.renderMessagePeers(updatedMessage, peerTable: postbox.peerTable)
                            }
                            
                            if value.message !== updatedMessage {
                                let updatedValue = MessageHistoryMessageEntry(message: updatedMessage, location: value.location, monthLocation: value.monthLocation, attributes: value.attributes)
                                if directionIndex == 0 {
                                    self.orderedEntriesBySpace[space]!.setLowerOrAtAnchorAtArrayIndex(index, to: .MessageEntry(updatedValue, reloadAssociatedMessages: false, reloadPeers: false))
                                } else {
                                    self.orderedEntriesBySpace[space]!.setHigherThanAnchorAtArrayIndex(index, to: .MessageEntry(updatedValue, reloadAssociatedMessages: false, reloadPeers: false))
                                }
                                result.append(updatedValue)
                            } else {
                                result.append(value)
                            }
                        case let .IntermediateMessageEntry(message, location, monthLocation):
                            let renderedMessage = postbox.messageHistoryTable.renderMessage(message, peerTable: postbox.peerTable, threadIndexTable: postbox.messageHistoryThreadIndexTable)
                            var authorIsContact = false
                            if let author = renderedMessage.author {
                                authorIsContact = postbox.contactsTable.isContact(peerId: author.id)
                            }
                            let entry = MessageHistoryMessageEntry(message: renderedMessage, location: location, monthLocation: monthLocation, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: authorIsContact))
                            if directionIndex == 0 {
                                self.orderedEntriesBySpace[space]!.setLowerOrAtAnchorAtArrayIndex(index, to: .MessageEntry(entry, reloadAssociatedMessages: false, reloadPeers: false))
                            } else {
                                self.orderedEntriesBySpace[space]!.setHigherThanAnchorAtArrayIndex(index, to: .MessageEntry(entry, reloadAssociatedMessages: false, reloadPeers: false))
                            }
                            result.append(entry)
                    }
                }
            }
        }
        //assert(Set(result.map({ $0.message.stableId })).count == result.count)
        return HistoryViewLoadedSample(anchor: self.anchor, entries: result, holesToLower: holesToLower, holesToHigher: holesToHigher, hole: sampledHole)
    }
}

private func fetchHoles(postbox: PostboxImpl, locations: MessageHistoryViewInput, tag: MessageTags?, namespaces: MessageIdNamespaces) -> [PeerIdAndNamespace: IndexSet] {
    var peerIds: [PeerId] = []
    var threadId: Int64?
    switch locations {
    case let .single(peerId, threadIdValue):
        peerIds.append(peerId)
        threadId = threadIdValue
    case let .associated(peerId, associatedId):
        peerIds.append(peerId)
        if let associatedId = associatedId {
            peerIds.append(associatedId.peerId)
        }
    case let .external(input):
        switch input.content {
        case let .thread(peerId, _, _):
            peerIds.append(peerId)
        case let .messages(_, holes, _):
            let key = PeerIdAndNamespace(peerId: PeerId(namespace: PeerId.Namespace.max, id: PeerId.Id.max), namespace: 0)
            if let namespaceHoles = holes[0] {
                return [key: namespaceHoles]
            } else {
                return [:]
            }
        }
    }
    switch locations {
    case .single, .associated:
        var holesBySpace: [PeerIdAndNamespace: IndexSet] = [:]
        let holeSpace = tag.flatMap(MessageHistoryHoleSpace.tag) ?? .everywhere
        for peerId in peerIds {
            if let threadId = threadId {
                for namespace in postbox.messageHistoryThreadHoleIndexTable.existingNamespaces(peerId: peerId, threadId: threadId, holeSpace: holeSpace) {
                    if namespaces.contains(namespace) {
                        let indices = postbox.messageHistoryThreadHoleIndexTable.closest(peerId: peerId, threadId: threadId, namespace: namespace, space: holeSpace, range: 1 ... (Int32.max - 1))
                        if !indices.isEmpty {
                            let peerIdAndNamespace = PeerIdAndNamespace(peerId: peerId, namespace: namespace)
                            assert(canContainHoles(peerIdAndNamespace, input: .automatic(threadId: threadId, info: tag.flatMap { tag in
                                MessageHistoryInput.Automatic(tag: tag, appendMessagesFromTheSameGroup: false)
                            }), seedConfiguration: postbox.seedConfiguration))
                            holesBySpace[peerIdAndNamespace] = indices
                        }
                    }
                }
            } else {
                for namespace in postbox.messageHistoryHoleIndexTable.existingNamespaces(peerId: peerId, holeSpace: holeSpace) {
                    if namespaces.contains(namespace) {
                        let indices = postbox.messageHistoryHoleIndexTable.closest(peerId: peerId, namespace: namespace, space: holeSpace, range: 1 ... (Int32.max - 1))
                        if !indices.isEmpty {
                            let peerIdAndNamespace = PeerIdAndNamespace(peerId: peerId, namespace: namespace)
                            assert(canContainHoles(peerIdAndNamespace, input: .automatic(threadId: nil, info: tag.flatMap { tag in
                                MessageHistoryInput.Automatic(tag: tag, appendMessagesFromTheSameGroup: false)
                            }), seedConfiguration: postbox.seedConfiguration))
                            holesBySpace[peerIdAndNamespace] = indices
                        }
                    }
                }
            }
        }
        return holesBySpace
    case let .external(input):
        switch input.content {
        case let .thread(_, _, holes):
            var holesBySpace: [PeerIdAndNamespace: IndexSet] = [:]
            for peerId in peerIds {
                for (namespace, indices) in holes {
                    if namespaces.contains(namespace) {
                        if !indices.isEmpty {
                            let peerIdAndNamespace = PeerIdAndNamespace(peerId: peerId, namespace: namespace)
                            assert(canContainHoles(peerIdAndNamespace, input: .external(input, tag), seedConfiguration: postbox.seedConfiguration))
                            holesBySpace[peerIdAndNamespace] = indices
                        }
                    }
                }
            }
            return holesBySpace
        case .messages:
            return [:]
        }
    }
}

enum HistoryViewLoadingSample {
    case ready(HistoryViewAnchor, HistoryViewHoles)
    case loadHole(PeerId, MessageId.Namespace, MessageTags?, Int64?, MessageId.Id)
}

final class HistoryViewLoadingState {
    var messageId: MessageId
    let tag: MessageTags?
    let threadId: Int64?
    let halfLimit: Int
    var holes: HistoryViewHoles
    
    init(postbox: PostboxImpl, locations: MessageHistoryViewInput, tag: MessageTags?, threadId: Int64?, namespaces: MessageIdNamespaces, messageId: MessageId, halfLimit: Int) {
        self.messageId = messageId
        self.tag = tag
        self.threadId = threadId
        self.halfLimit = halfLimit
        self.holes = HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag, namespaces: namespaces))
    }
    
    func insertHole(space: PeerIdAndNamespace, range: ClosedRange<MessageId.Id>) -> Bool {
        return self.holes.insertHole(space: space, range: range)
    }
    
    func removeHole(space: PeerIdAndNamespace, range: ClosedRange<MessageId.Id>) -> Bool {
        return self.holes.removeHole(space: space, range: range)
    }
    
    func checkAndSample(postbox: PostboxImpl) -> HistoryViewLoadingSample {
        while true {
            if let indices = self.holes.holesBySpace[PeerIdAndNamespace(peerId: self.messageId.peerId, namespace: self.messageId.namespace)] {
                if indices.contains(Int(messageId.id)) {
                    return .loadHole(messageId.peerId, messageId.namespace, self.tag, self.threadId, messageId.id)
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
    
    init(postbox: PostboxImpl, inputAnchor: HistoryViewInputAnchor, tag: MessageTags?, appendMessagesFromTheSameGroup: Bool, namespaces: MessageIdNamespaces, statistics: MessageHistoryViewOrderStatistics, ignoreMessagesInTimestampRange: ClosedRange<Int32>?, halfLimit: Int, locations: MessageHistoryViewInput) {
        switch inputAnchor {
            case let .index(index):
            self = .loaded(HistoryViewLoadedState(anchor: .index(index), tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: namespaces, statistics: statistics, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, halfLimit: halfLimit, locations: locations, postbox: postbox, holes: HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag, namespaces: namespaces))))
            case .lowerBound:
                self = .loaded(HistoryViewLoadedState(anchor: .lowerBound, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: namespaces, statistics: statistics, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, halfLimit: halfLimit, locations: locations, postbox: postbox, holes: HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag, namespaces: namespaces))))
            case .upperBound:
                self = .loaded(HistoryViewLoadedState(anchor: .upperBound, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: namespaces, statistics: statistics, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, halfLimit: halfLimit, locations: locations, postbox: postbox, holes: HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag, namespaces: namespaces))))
            case .unread:
                let anchorPeerId: PeerId
                switch locations {
                    case let .single(peerId, threadId):
                        anchorPeerId = peerId
                        if threadId != nil {
                            self = .loaded(HistoryViewLoadedState(anchor: .upperBound, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: namespaces, statistics: statistics, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, halfLimit: halfLimit, locations: locations, postbox: postbox, holes: HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag, namespaces: namespaces))))
                            return
                        }
                    case let .associated(peerId, _):
                        anchorPeerId = peerId
                    case .external:
                        self = .loaded(HistoryViewLoadedState(anchor: .upperBound, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: namespaces, statistics: statistics, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, halfLimit: halfLimit, locations: locations, postbox: postbox, holes: HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag, namespaces: namespaces))))
                        return
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
                        let loadingState = HistoryViewLoadingState(postbox: postbox, locations: locations, tag: tag, threadId: nil, namespaces: namespaces, messageId: messageId, halfLimit: halfLimit)
                        let sampledState = loadingState.checkAndSample(postbox: postbox)
                        switch sampledState {
                            case let .ready(anchor, holes):
                                self = .loaded(HistoryViewLoadedState(anchor: anchor, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: namespaces, statistics: statistics, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, halfLimit: halfLimit, locations: locations, postbox: postbox, holes: holes))
                            case .loadHole:
                                self = .loading(loadingState)
                        }
                    } else {
                        self = .loaded(HistoryViewLoadedState(anchor: anchor ?? .upperBound, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: namespaces, statistics: statistics, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, halfLimit: halfLimit, locations: locations, postbox: postbox, holes: HistoryViewHoles(holesBySpace: fetchHoles(postbox: postbox, locations: locations, tag: tag, namespaces: namespaces))))
                    }
                } else {
                    preconditionFailure()
                }
            case let .message(messageId):
                var threadId: Int64?
                switch locations {
                case let .single(_, threadIdValue):
                    threadId = threadIdValue
                case let .external(input):
                    switch input.content {
                    case let .thread(_, id, _):
                        threadId = id
                    case .messages:
                        break
                    }
                default:
                    break
                }
                let loadingState = HistoryViewLoadingState(postbox: postbox, locations: locations, tag: tag, threadId: threadId, namespaces: namespaces, messageId: messageId, halfLimit: halfLimit)
                let sampledState = loadingState.checkAndSample(postbox: postbox)
                switch sampledState {
                    case let .ready(anchor, holes):
                        self = .loaded(HistoryViewLoadedState(anchor: anchor, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: namespaces, statistics: statistics, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, halfLimit: halfLimit, locations: locations, postbox: postbox, holes: holes))
                    case .loadHole:
                        self = .loading(loadingState)
                }
        }
    }
    
    func sample(postbox: PostboxImpl, clipHoles: Bool) -> HistoryViewSample {
        switch self {
        case let .loading(loadingState):
            return .loading(loadingState.checkAndSample(postbox: postbox))
        case let .loaded(loadedState):
            return .loaded(loadedState.completeAndSample(postbox: postbox, clipHoles: clipHoles))
        }
    }
}
