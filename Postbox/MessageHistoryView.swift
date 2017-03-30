import Foundation

public enum AdditionalMessageHistoryViewData {
    case cachedPeerData(PeerId)
}

public enum AdditionalMessageHistoryViewDataEntry {
    case cachedPeerData(PeerId, CachedPeerData?)
}

public struct MessageHistoryViewId: Equatable {
    let peerId: PeerId
    let id: Int
    let version: Int
    
    init(peerId: PeerId, id: Int, version: Int = 0) {
        self.peerId = peerId
        self.id = id
        self.version = version
    }
    
    var nextVersion: MessageHistoryViewId {
        return MessageHistoryViewId(peerId: self.peerId, id: self.id, version: self.version + 1)
    }
}

public func ==(lhs: MessageHistoryViewId, rhs: MessageHistoryViewId) -> Bool {
    return lhs.peerId == rhs.peerId && lhs.id == rhs.id && lhs.version == rhs.version
}

enum MutableMessageHistoryEntry {
    case IntermediateMessageEntry(IntermediateMessage, MessageHistoryEntryLocation?, MessageHistoryEntryMonthLocation?)
    case MessageEntry(Message, MessageHistoryEntryLocation?, MessageHistoryEntryMonthLocation?)
    case HoleEntry(MessageHistoryHole, MessageHistoryEntryLocation?)
    
    var index: MessageIndex {
        switch self {
            case let .IntermediateMessageEntry(message, _, _):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .MessageEntry(message, _, _):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .HoleEntry(hole, _):
                return hole.maxIndex
        }
    }
    
    var tags: MessageTags {
        switch self {
            case let .IntermediateMessageEntry(message, _, _):
                return message.tags
            case let .MessageEntry(message, _, _):
                return message.tags
            case let .HoleEntry(hole, _):
                return MessageTags(rawValue: hole.tags)
        }
    }
    
    func updatedLocation(_ location: MessageHistoryEntryLocation?) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, _, monthLocation):
                return .IntermediateMessageEntry(message, location, monthLocation)
            case let .MessageEntry(message, _, monthLocation):
                return .MessageEntry(message, location, monthLocation)
            case let .HoleEntry(hole, _):
                return .HoleEntry(hole, location)
        }
    }
    
    func updatedMonthLocation(_ monthLocation: MessageHistoryEntryMonthLocation?) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, location, _):
                return .IntermediateMessageEntry(message, location, monthLocation)
            case let .MessageEntry(message, location, _):
                return .MessageEntry(message, location, monthLocation)
            case .HoleEntry:
                return self
        }
    }
    
    func offsetLocationForInsertedIndex(_ index: MessageIndex, isMessage: Bool) -> MutableMessageHistoryEntry {
        switch self {
            case let .HoleEntry(hole, location):
                if let location = location {
                    if hole.maxIndex > index {
                        return .HoleEntry(hole, MessageHistoryEntryLocation(index: location.index + 1, count: location.count + 1))
                    } else {
                        return .HoleEntry(hole, MessageHistoryEntryLocation(index: location.index, count: location.count + 1))
                    }
                } else {
                    return self
                }
            case let .IntermediateMessageEntry(message, location, monthLocation):
                if let location = location {
                    if MessageIndex(id: message.id, timestamp: message.timestamp) > index {
                        return .IntermediateMessageEntry(message, MessageHistoryEntryLocation(index: location.index + 1, count: location.count + 1), monthLocation)
                    } else {
                        return .IntermediateMessageEntry(message, MessageHistoryEntryLocation(index: location.index, count: location.count - 1), monthLocation)
                    }
                } else {
                    return self
                }
            case let .MessageEntry(message, location, monthLocation):
                if let location = location {
                    if MessageIndex(id: message.id, timestamp: message.timestamp) > index {
                        return .MessageEntry(message, MessageHistoryEntryLocation(index: location.index + 1, count: location.count + 1), monthLocation)
                    } else {
                        return .MessageEntry(message, MessageHistoryEntryLocation(index: location.index, count: location.count + 1), monthLocation)
                    }
                } else {
                    return self
                }
        }
    }
    
    func offsetLocationForRemovedIndex(_ index: MessageIndex, wasMessage: Bool) -> MutableMessageHistoryEntry {
        switch self {
            case let .HoleEntry(hole, location):
                if let location = location {
                    if hole.maxIndex > index {
                        assert(location.index > 0)
                        assert(location.count != 0)
                        return .HoleEntry(hole, MessageHistoryEntryLocation(index: location.index - 1, count: location.count - 1))
                    } else {
                        assert(location.count != 0)
                        return .HoleEntry(hole, MessageHistoryEntryLocation(index: location.index, count: location.count - 1))
                    }
                } else {
                    return self
                }
            case let .IntermediateMessageEntry(message, location, monthLocation):
                if let location = location {
                    if MessageIndex(id: message.id, timestamp: message.timestamp) > index {
                        assert(location.index > 0)
                        assert(location.count != 0)
                        return .IntermediateMessageEntry(message, MessageHistoryEntryLocation(index: location.index - 1, count: location.count - 1), monthLocation)
                    } else {
                        assert(location.count != 0)
                        return .IntermediateMessageEntry(message, MessageHistoryEntryLocation(index: location.index, count: location.count - 1), monthLocation)
                    }
                } else {
                    return self
                }
            case let .MessageEntry(message, location, monthLocation):
                if let location = location {
                    if MessageIndex(id: message.id, timestamp: message.timestamp) > index {
                        assert(location.index > 0)
                        assert(location.count != 0)
                        return .MessageEntry(message, MessageHistoryEntryLocation(index: location.index - 1, count: location.count - 1), monthLocation)
                    } else {
                        assert(location.count != 0)
                        return .MessageEntry(message, MessageHistoryEntryLocation(index: location.index, count: location.count - 1), monthLocation)
                    }
                } else {
                    return self
                }
        }
    }
    
    func updatedTimestamp(_ timestamp: Int32) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, location, monthLocation):
                let updatedMessage = IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, timestamp: timestamp, flags: message.flags, tags: message.tags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: message.embeddedMediaData, referencedMedia: message.referencedMedia)
                return .IntermediateMessageEntry(updatedMessage, location, monthLocation)
            case let .MessageEntry(message, location, monthLocation):
                let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, timestamp: timestamp, flags: message.flags, tags: message.tags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: message.peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds)
                return .MessageEntry(updatedMessage, location, monthLocation)
            case let .HoleEntry(hole, location):
                let updatedHole = MessageHistoryHole(stableId: hole.stableId, maxIndex: MessageIndex(id: hole.maxIndex.id, timestamp: timestamp), min: hole.min, tags: hole.tags)
                return .HoleEntry(updatedHole, location)
        }
    }
}

public struct MessageHistoryEntryLocation: Equatable {
    public let index: Int
    public let count: Int
    
    var predecessor: MessageHistoryEntryLocation? {
        if index == 0 {
            return nil
        } else {
            return MessageHistoryEntryLocation(index: index - 1, count: count)
        }
    }
    
    var successor: MessageHistoryEntryLocation {
        return MessageHistoryEntryLocation(index: index + 1, count: count)
    }
    
    public static func ==(lhs: MessageHistoryEntryLocation, rhs: MessageHistoryEntryLocation) -> Bool {
        return lhs.index == rhs.index && lhs.count == rhs.count
    }
}

public struct MessageHistoryEntryMonthLocation: Equatable {
    public let indexInMonth: Int32
    
    public static func ==(lhs: MessageHistoryEntryMonthLocation, rhs: MessageHistoryEntryMonthLocation) -> Bool {
        return lhs.indexInMonth == rhs.indexInMonth
    }
}

public enum MessageHistoryEntry: Comparable {
    case MessageEntry(Message, Bool, MessageHistoryEntryLocation?, MessageHistoryEntryMonthLocation?)
    case HoleEntry(MessageHistoryHole, MessageHistoryEntryLocation?)
    
    public var index: MessageIndex {
        switch self {
            case let .MessageEntry(message, _, _, _):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .HoleEntry(hole, _):
                return hole.maxIndex
        }
    }
}

public func ==(lhs: MessageHistoryEntry, rhs: MessageHistoryEntry) -> Bool {
    switch lhs {
        case let .MessageEntry(lhsMessage, lhsRead, lhsLocation, lhsMonthLocation):
            switch rhs {
                case .HoleEntry:
                    return false
                case let .MessageEntry(rhsMessage, rhsRead, rhsLocation, rhsMonthLocation):
                    if MessageIndex(lhsMessage) == MessageIndex(rhsMessage) && lhsMessage.flags == rhsMessage.flags && lhsLocation == rhsLocation && lhsRead == rhsRead && lhsMonthLocation != rhsMonthLocation {
                        return true
                    }
                    return false
            }
        case let .HoleEntry(lhsHole, lhsLocation):
            switch rhs {
                case let .HoleEntry(rhsHole, rhsLocation):
                    return lhsHole == rhsHole && lhsLocation == rhsLocation
                case .MessageEntry:
                    return false
            }
    }
}

public func <(lhs: MessageHistoryEntry, rhs: MessageHistoryEntry) -> Bool {
    return lhs.index < rhs.index
}

final class MutableMessageHistoryViewReplayContext {
    var invalidEarlier: Bool = false
    var invalidLater: Bool = false
    var removedEntries: Bool = false
    
    func empty() -> Bool {
        return !self.removedEntries && !invalidEarlier && !invalidLater
    }
}

enum MessageHistoryTopTaggedMessage {
    case message(Message)
    case intermediate(IntermediateMessage)
    
    var id: MessageId {
        switch self {
            case let .message(message):
                return message.id
            case let .intermediate(message):
                return message.id
        }
    }
}

public enum MessageHistoryViewRelativeHoleDirection: Equatable {
    case UpperToLower
    case LowerToUpper
    case AroundIndex(MessageIndex)
    
    public static func ==(lhs: MessageHistoryViewRelativeHoleDirection, rhs: MessageHistoryViewRelativeHoleDirection) -> Bool {
        switch lhs {
            case .UpperToLower:
                if case .UpperToLower = rhs {
                    return true
                } else {
                    return false
                }
            case .LowerToUpper:
                if case .LowerToUpper = rhs {
                    return true
                } else {
                    return false
                }
            case let .AroundIndex(index):
                if case .AroundIndex(index) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct MessageHistoryViewOrderStatistics: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let combinedLocation = MessageHistoryViewOrderStatistics(rawValue: 1 << 0)
    public static let locationWithinMonth = MessageHistoryViewOrderStatistics(rawValue: 1 << 1)
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
    
    static func ==(lhs: MessageMonthIndex, rhs: MessageMonthIndex) -> Bool {
        return lhs.month == rhs.month && lhs.year == rhs.year
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

private func monthUpperBoundIndex(peerId: PeerId, index: MessageMonthIndex) -> MessageIndex {
    return MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: index.successor.timestamp)
}

final class MutableMessageHistoryView {
    private(set) var id: MessageHistoryViewId
    let tagMask: MessageTags?
    private let orderStatistics: MessageHistoryViewOrderStatistics
    
    fileprivate var anchorIndex: MessageHistoryAnchorIndex
    fileprivate let combinedReadState: CombinedPeerReadState?
    fileprivate var transientReadState: CombinedPeerReadState?
    fileprivate var earlier: MutableMessageHistoryEntry?
    fileprivate var later: MutableMessageHistoryEntry?
    fileprivate var entries: [MutableMessageHistoryEntry]
    fileprivate let fillCount: Int
    
    fileprivate var topTaggedMessages: [MessageId.Namespace: MessageHistoryTopTaggedMessage?]
    fileprivate var additionalDatas: [AdditionalMessageHistoryViewDataEntry]
    
    init(id: MessageHistoryViewId, postbox: Postbox, orderStatistics: MessageHistoryViewOrderStatistics, peerId: PeerId, anchorIndex: MessageHistoryAnchorIndex, combinedReadState: CombinedPeerReadState?, earlier: MutableMessageHistoryEntry?, entries: [MutableMessageHistoryEntry], later: MutableMessageHistoryEntry?, tagMask: MessageTags?, count: Int, topTaggedMessages: [MessageId.Namespace: MessageHistoryTopTaggedMessage?], additionalDatas: [AdditionalMessageHistoryViewDataEntry], getMessageCountInRange: (MessageIndex, MessageIndex) -> Int32) {
        self.id = id
        self.orderStatistics = orderStatistics
        self.anchorIndex = anchorIndex
        self.combinedReadState = combinedReadState
        self.transientReadState = combinedReadState
        self.earlier = earlier
        self.entries = entries
        self.later = later
        self.tagMask = tagMask
        self.fillCount = count
        self.topTaggedMessages = topTaggedMessages
        self.additionalDatas = additionalDatas
        
        if let tagMask = self.tagMask, !orderStatistics.isEmpty && !self.entries.isEmpty {
            if orderStatistics.contains(.combinedLocation) {
                if let location = postbox.messageHistoryTagsTable.entryLocation(at: self.entries[0].index, tagMask: tagMask) {
                    self.entries[0] = self.entries[0].updatedLocation(location)
                    
                    var previousLocation = location
                    for i in 1 ..< self.entries.count {
                        previousLocation = previousLocation.successor
                        self.entries[i] = self.entries[i].updatedLocation(previousLocation)
                    }
                } else {
                    assertionFailure()
                }
            }
            
            if orderStatistics.contains(.locationWithinMonth) {
                var topMessageEntryIndex: Int?
                var index = self.entries.count - 1
                loop: for entry in self.entries.reversed() {
                    switch entry {
                        case .IntermediateMessageEntry, .MessageEntry:
                            topMessageEntryIndex = index
                            break loop
                        default:
                            break
                    }
                    index -= 1
                }
                if let topMessageEntryIndex = topMessageEntryIndex {
                    let topMessageIndex = self.entries[topMessageEntryIndex].index
                    
                    let monthIndex = MessageMonthIndex(timestamp: topMessageIndex.timestamp)
                    
                    let laterCount = postbox.messageHistoryTagsTable.getMessageCountInRange(tagMask: tagMask, peerId: peerId, lowerBound: topMessageIndex.successor(), upperBound: monthUpperBoundIndex(peerId: peerId, index: monthIndex))
                    self.entries[topMessageEntryIndex] = self.entries[topMessageEntryIndex].updatedMonthLocation(MessageHistoryEntryMonthLocation(indexInMonth: laterCount))
                }
            }
        }
    }
    
    func incrementVersion() {
        self.id = self.id.nextVersion
    }
    
    func updateVisibleRange(earliestVisibleIndex: MessageIndex, latestVisibleIndex: MessageIndex, context: MutableMessageHistoryViewReplayContext) -> Bool {
        var minIndex: Int?
        var maxIndex: Int?
        
        for i in 0 ..< self.entries.count {
            if self.entries[i].index >= earliestVisibleIndex {
                minIndex = i
                break
            }
        }
        
        for i in (0 ..< self.entries.count).reversed() {
            if self.entries[i].index <= latestVisibleIndex {
                maxIndex = i
                break
            }
        }
        
        if let minIndex = minIndex, let maxIndex = maxIndex {
            var minClipIndex = minIndex
            var maxClipIndex = maxIndex
            
            while maxClipIndex - minClipIndex <= self.fillCount {
                if maxClipIndex != self.entries.count - 1 {
                    maxClipIndex += 1
                }
                
                if minClipIndex != 0 {
                    minClipIndex -= 1
                } else if maxClipIndex == self.entries.count - 1 {
                    break
                }
            }
            
            if minClipIndex != 0 || maxClipIndex != self.entries.count - 1 {
                if minClipIndex != 0 {
                    self.earlier = self.entries[minClipIndex - 1]
                }
                
                if maxClipIndex != self.entries.count - 1 {
                    self.later = self.entries[maxClipIndex + 1]
                }
                
                for _ in 0 ..< self.entries.count - 1 - maxClipIndex {
                    self.entries.removeLast()
                }
                
                for _ in 0 ..< minClipIndex {
                    self.entries.removeFirst()
                }
                
                return true
            }
        }
        
        return false
    }
    
    func updateAnchorIndex(_ getIndex: (MessageId) -> MessageHistoryAnchorIndex?) -> Bool {
        if !self.anchorIndex.exact {
            if let index = getIndex(self.anchorIndex.index.id) {
                self.anchorIndex = index
                return true
            }
        }
        return false
    }
    
    func refreshDueToExternalTransaction(fetchAroundHistoryEntries: (_ index: MessageIndex, _ count: Int, _ tagMask: MessageTags?) -> (entries: [MutableMessageHistoryEntry], lower: MutableMessageHistoryEntry?, upper: MutableMessageHistoryEntry?)) -> Bool {
        var index = MessageIndex.upperBound(peerId: self.anchorIndex.index.id.peerId)
        if !self.entries.isEmpty {
            if let _ = self.later {
                index = self.entries[self.entries.count / 2].index
            }
        }
        
        let (entries, earlier, later) = fetchAroundHistoryEntries(index, max(self.fillCount, self.entries.count), self.tagMask)
        
        self.entries = entries
        self.earlier = earlier
        self.later = later
        
        return true
    }
    
    func replay(_ operations: [MessageHistoryOperation], holeFillDirections: [MessageIndex: HoleFillDirection], updatedMedia: [MediaId: Media?], updatedCachedPeerData: [PeerId: CachedPeerData], context: MutableMessageHistoryViewReplayContext, renderIntermediateMessage: (IntermediateMessage) -> Message) -> Bool {
        let tagMask = self.tagMask
        let unwrappedTagMask: UInt32 = tagMask?.rawValue ?? 0
        
        var hasChanges = false
        for operation in operations {
            switch operation {
                case let .InsertHole(hole):
                    if tagMask == nil || (hole.tags & unwrappedTagMask) != 0 {
                        if self.add(.HoleEntry(hole, nil), holeFillDirections: holeFillDirections) {
                            hasChanges = true
                        }
                    }
                case let .InsertMessage(intermediateMessage):
                    if tagMask == nil || (intermediateMessage.tags.rawValue & unwrappedTagMask) != 0 {
                        if self.add(.IntermediateMessageEntry(intermediateMessage, nil, nil), holeFillDirections: holeFillDirections) {
                            hasChanges = true
                        }
                    }
                case let .Remove(indices):
                    if self.remove(indices, context: context) {
                        hasChanges = true
                    }
                case let .UpdateReadState(combinedReadState):
                    hasChanges = true
                    self.transientReadState = combinedReadState
                case let .UpdateEmbeddedMedia(index, embeddedMediaData):
                    for i in 0 ..< self.entries.count {
                        if case let .IntermediateMessageEntry(message, location, monthLocation) = self.entries[i] , MessageIndex(message) == index {
                            self.entries[i] = .IntermediateMessageEntry(IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: embeddedMediaData, referencedMedia: message.referencedMedia), location, monthLocation)
                            hasChanges = true
                            break
                        }
                    }
                case let .UpdateTimestamp(index, timestamp):
                    for i in 0 ..< self.entries.count {
                        let entry = self.entries[i]
                        if entry.index == index {
                            let _ = self.remove([(index, true, entry.tags)], context: context)
                            let _ = self.add(entry.updatedTimestamp(timestamp), holeFillDirections: [:])
                            hasChanges = true
                            break
                        }
                    }
            }
        }
        
        if !updatedMedia.isEmpty {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                    case let .MessageEntry(message, location, monthLocation):
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
                                        messageMedia.append(updated)
                                    }
                                } else {
                                    messageMedia.append(media)
                                }
                            }
                            let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: messageMedia, peers: message.peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds)
                            self.entries[i] = .MessageEntry(updatedMessage, location, monthLocation)
                            hasChanges = true
                        }
                    case let .IntermediateMessageEntry(message, location, monthLocation):
                        var rebuild = false
                        for mediaId in message.referencedMedia {
                            if let media = updatedMedia[mediaId] , media?.id != mediaId {
                                rebuild = true
                                break
                            }
                        }
                        if rebuild {
                            var referencedMedia: [MediaId] = []
                            for mediaId in message.referencedMedia {
                                if let media = updatedMedia[mediaId] , media?.id != mediaId {
                                    if let id = media?.id {
                                        referencedMedia.append(id)
                                    }
                                } else {
                                    referencedMedia.append(mediaId)
                                }
                            }
                            hasChanges = true
                        }
                    default:
                        break
                }
            }
        }
        
        for operation in operations {
            switch operation {
                case let .InsertMessage(intermediateMessage):
                    for i in 0 ..< self.entries.count {
                        switch self.entries[i] {
                            case let .MessageEntry(message, location, monthLocation):
                                if message.associatedMessageIds.count != message.associatedMessages.count {
                                    if message.associatedMessageIds.contains(intermediateMessage.id) && message.associatedMessages[intermediateMessage.id] == nil {
                                        var updatedAssociatedMessages = message.associatedMessages
                                        let renderedMessage = renderIntermediateMessage(intermediateMessage)
                                        updatedAssociatedMessages[intermediateMessage.id] = renderedMessage
                                        let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId:message.globallyUniqueId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: message.peers, associatedMessages: updatedAssociatedMessages, associatedMessageIds: message.associatedMessageIds)
                                        self.entries[i] = .MessageEntry(updatedMessage, location, monthLocation)
                                        hasChanges = true
                                    }
                                }
                                break
                            default:
                                break
                        }
                    }
                    break
                default:
                    break
            }
        }
        
        for operation in operations {
            switch operation {
                case let .InsertMessage(message):
                    if message.flags.contains(.TopIndexable) {
                        if let currentTopMessage = self.topTaggedMessages[message.id.namespace] {
                            if currentTopMessage == nil || currentTopMessage!.id < message.id {
                                self.topTaggedMessages[message.id.namespace] = MessageHistoryTopTaggedMessage.intermediate(message)
                                hasChanges = true
                            }
                        }
                    }
                case let .Remove(indices):
                    if !self.topTaggedMessages.isEmpty {
                        for (index, _, _) in indices {
                            if let maybeCurrentTopMessage = self.topTaggedMessages[index.id.namespace], let currentTopMessage = maybeCurrentTopMessage, index.id == currentTopMessage.id {
                                let item: MessageHistoryTopTaggedMessage? = nil
                                self.topTaggedMessages[index.id.namespace] = item
                            }
                        }
                    }
                default:
                    break
            }
        }
        
        for i in 0 ..< self.additionalDatas.count {
            switch self.additionalDatas[i] {
                case let .cachedPeerData(peerId, _):
                    if let updatedData = updatedCachedPeerData[peerId] {
                        self.additionalDatas[i] = .cachedPeerData(peerId, updatedData)
                        hasChanges = true
                    }
            }
        }
        
        return hasChanges
    }
    
    private func add(_ entry: MutableMessageHistoryEntry, holeFillDirections: [MessageIndex: HoleFillDirection]) -> Bool {
        let updated: Bool
        
        if self.entries.count == 0 {
            self.entries.append(entry)
            updated = true
        } else {
            let latestIndex = self.entries[self.entries.count - 1].index
            let earliestIndex = self.entries[0].index
            
            let index = entry.index
            
            if index < earliestIndex {
                if self.earlier == nil || self.earlier!.index < index {
                    self.entries.insert(entry, at: 0)
                    updated = true
                } else {
                    updated = false
                }
            } else if index > latestIndex {
                if let later = self.later {
                    if index < later.index {
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
        
        if !self.orderStatistics.isEmpty {
            let entryIndex = entry.index
            let isMessage: Bool
            switch entry {
                case .HoleEntry:
                    isMessage = false
                case .IntermediateMessageEntry, .MessageEntry:
                    isMessage = true
            }
            
            if self.orderStatistics.contains(.combinedLocation) {
                for i in 0 ..< self.entries.count {
                    if self.entries[i].index != entryIndex {
                        self.entries[i] = self.entries[i].offsetLocationForInsertedIndex(entryIndex, isMessage: isMessage)
                    }
                }
            }
            if self.orderStatistics.contains(.locationWithinMonth) {
                
            }
        }
        
        return updated
    }
    
    private func remove(_ indicesAndFlags: [(MessageIndex, Bool, MessageTags)], context: MutableMessageHistoryViewReplayContext) -> Bool {
        let indices = Set(indicesAndFlags.map { $0.0 })
        var hasChanges = false
        if let earlier = self.earlier , indices.contains(earlier.index) {
            context.invalidEarlier = true
            hasChanges = true
        }
        
        if let later = self.later , indices.contains(later.index) {
            context.invalidLater = true
            hasChanges = true
        }
        
        var ids = Set<MessageId>()
        for index in indices {
            ids.insert(index.id)
        }
        
        if self.entries.count != 0 {
            var i = self.entries.count - 1
            while i >= 0 {
                let entry = self.entries[i]
                if indices.contains(entry.index) {
                    self.entries.remove(at: i)
                    
                    context.removedEntries = true
                    hasChanges = true
                } else {
                    switch entry {
                        case let .MessageEntry(message, location, monthLocation):
                            if let updatedAssociatedMessages = message.associatedMessages.filteredOut(keysIn: ids) {
                                let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: message.peers, associatedMessages: updatedAssociatedMessages, associatedMessageIds: message.associatedMessageIds)
                                self.entries[i] = .MessageEntry(updatedMessage, location, monthLocation)
                            }
                        default:
                            break
                    }
                }
                i -= 1
            }
        }
        
        if let tagMask = self.tagMask {
            for (index, wasMessage, tags) in indicesAndFlags {
                if (tagMask.rawValue & tags.rawValue) != 0 {
                    for i in 0 ..< self.entries.count {
                        self.entries[i] = self.entries[i].offsetLocationForRemovedIndex(index, wasMessage: wasMessage)
                    }
                }
            }
        }
        
        return hasChanges
    }
    
    func updatePeers(_ peers: [PeerId: Peer]) -> Bool {
        return false
    }
    
    func complete(context: MutableMessageHistoryViewReplayContext, fetchEarlier: (MessageIndex?, Int) -> [MutableMessageHistoryEntry], fetchLater: (MessageIndex?, Int) -> [MutableMessageHistoryEntry]) {
        if context.removedEntries && self.entries.count < self.fillCount {
            if self.entries.count == 0 {
                var anchorIndex: MessageIndex?
                
                if context.invalidLater {
                    var laterId: MessageIndex?
                    let i = self.entries.count - 1
                    if i >= 0 {
                        laterId = self.entries[i].index
                    }
                    
                    let laterEntries = fetchLater(laterId, 1)
                    anchorIndex = laterEntries.first?.index
                } else {
                    anchorIndex = self.later?.index
                }
                
                if anchorIndex == nil {
                    if context.invalidEarlier {
                        var earlyId: MessageIndex?
                        let i = 0
                        if i < self.entries.count {
                            earlyId = self.entries[i].index
                        }
                        
                        let earlierEntries = fetchEarlier(earlyId, 1)
                        anchorIndex = earlierEntries.first?.index
                    } else {
                        anchorIndex = self.earlier?.index
                    }
                }
                
                let fetchedEntries = fetchEarlier(anchorIndex, self.fillCount + 2)
                if fetchedEntries.count >= self.fillCount + 2 {
                    self.earlier = fetchedEntries.last
                    for i in (1 ..< fetchedEntries.count - 1).reversed() {
                        self.entries.append(fetchedEntries[i])
                    }
                    self.later = fetchedEntries.first
                } else if fetchedEntries.count >= self.fillCount + 1 {
                    self.earlier = fetchedEntries.last
                    for i in (1 ..< fetchedEntries.count).reversed() {
                        self.entries.append(fetchedEntries[i])
                    }
                    self.later = nil
                } else {
                    for i in (0 ..< fetchedEntries.count).reversed() {
                        self.entries.append(fetchedEntries[i])
                    }
                    self.earlier = nil
                    self.later = nil
                }
            } else {
                let fetchedEntries = fetchEarlier(self.entries[0].index, self.fillCount - self.entries.count)
                for entry in fetchedEntries {
                    self.entries.insert(entry, at: 0)
                }
                
                if context.invalidEarlier {
                    var earlyId: MessageIndex?
                    let i = 0
                    if i < self.entries.count {
                        earlyId = self.entries[i].index
                    }
                    
                    let earlierEntries = fetchEarlier(earlyId, 1)
                    self.earlier = earlierEntries.first
                }
                
                if context.invalidLater {
                    var laterId: MessageIndex?
                    let i = self.entries.count - 1
                    if i >= 0 {
                        laterId = self.entries[i].index
                    }
                    
                    let laterEntries = fetchLater(laterId, 1)
                    self.later = laterEntries.first
                }
            }
        } else {
            if context.invalidEarlier {
                var earlyId: MessageIndex?
                let i = 0
                if i < self.entries.count {
                    earlyId = self.entries[i].index
                }
                
                let earlierEntries = fetchEarlier(earlyId, 1)
                self.earlier = earlierEntries.first
            }
            
            if context.invalidLater {
                var laterId: MessageIndex?
                let i = self.entries.count - 1
                if i >= 0 {
                    laterId = self.entries[i].index
                }
                
                let laterEntries = fetchLater(laterId, 1)
                self.later = laterEntries.first
            }
        }
    }
    
    func render(_ renderIntermediateMessage: (IntermediateMessage) -> Message) {
        if let earlier = self.earlier, case let .IntermediateMessageEntry(intermediateMessage, location, monthLocation) = earlier {
            self.earlier = .MessageEntry(renderIntermediateMessage(intermediateMessage), location, monthLocation)
        }
        if let later = self.later, case let .IntermediateMessageEntry(intermediateMessage, location, monthLocation) = later {
            self.later = .MessageEntry(renderIntermediateMessage(intermediateMessage), location, monthLocation)
        }
        
        for i in 0 ..< self.entries.count {
            if case let .IntermediateMessageEntry(intermediateMessage, location, monthLocation) = self.entries[i] {
                self.entries[i] = .MessageEntry(renderIntermediateMessage(intermediateMessage), location, monthLocation)
            }
        }
        
        for namespace in self.topTaggedMessages.keys {
            if let entry = self.topTaggedMessages[namespace]!, case let .intermediate(message) = entry {
                let item: MessageHistoryTopTaggedMessage? = .message(renderIntermediateMessage(message))
                self.topTaggedMessages[namespace] = item
            }
        }
    }
    
    func firstHole() -> (MessageHistoryHole, MessageHistoryViewRelativeHoleDirection)? {
        if self.entries.isEmpty {
            return nil
        }
        
        var referenceIndex = self.entries.count - 1
        for i in 0 ..< self.entries.count {
            if self.entries[i].index >= self.anchorIndex.index {
                referenceIndex = i
                break
            }
        }
        
        var i = referenceIndex
        var j = referenceIndex + 1
        
        while i >= 0 || j < self.entries.count {
            if j < self.entries.count {
                if case let .HoleEntry(hole, _) = self.entries[j] {
                    if self.anchorIndex.index.id.namespace == hole.id.namespace {
                        if self.anchorIndex.index.id.id >= hole.min && self.anchorIndex.index.id.id <= hole.maxIndex.id.id {
                            return (hole, .AroundIndex(self.anchorIndex.index))
                        }
                    }
                    
                    return (hole, hole.maxIndex <= self.anchorIndex.index ? .UpperToLower : .LowerToUpper)
                }
            }
            
            if i >= 0 {
                if case let .HoleEntry(hole, _) = self.entries[i] {
                    if self.anchorIndex.index.id.namespace == hole.id.namespace {
                        if self.anchorIndex.index.id.id >= hole.min && self.anchorIndex.index.id.id <= hole.maxIndex.id.id {
                            return (hole, .AroundIndex(self.anchorIndex.index))
                        }
                    }
                    
                    if hole.maxIndex.timestamp == Int32.max && self.anchorIndex.index.timestamp == Int32.max {
                        return (hole, .UpperToLower)
                    } else {
                        return (hole, hole.maxIndex <= self.anchorIndex.index ? .UpperToLower : .LowerToUpper)
                    }
                }
            }
            
            i -= 1
            j += 1
        }
        
        return nil
    }
}

public final class MessageHistoryView {
    public let id: MessageHistoryViewId
    public let anchorIndex: MessageIndex
    public let earlierId: MessageIndex?
    public let laterId: MessageIndex?
    public let entries: [MessageHistoryEntry]
    public let maxReadIndex: MessageIndex?
    public let combinedReadState: CombinedPeerReadState?
    public let topTaggedMessages: [Message]
    public let additionalData: [AdditionalMessageHistoryViewDataEntry]
    
    init(_ mutableView: MutableMessageHistoryView) {
        self.id = mutableView.id
        self.anchorIndex = mutableView.anchorIndex.index
        
        var earlierId = mutableView.earlier?.index
        var laterId = mutableView.later?.index
        
        var entries: [MessageHistoryEntry] = []
        if let transientReadState = mutableView.transientReadState {
            for entry in mutableView.entries {
                switch entry {
                    case let .HoleEntry(hole, location):
                        entries.append(.HoleEntry(hole, location))
                    case let .MessageEntry(message, location, monthLocation):
                        let read: Bool
                        if message.flags.contains(.Incoming) {
                            read = false
                        } else {
                            read = transientReadState.isOutgoingMessageIndexRead(MessageIndex(message))
                        }
                        entries.append(.MessageEntry(message, read, location, monthLocation))
                    case .IntermediateMessageEntry:
                        assertionFailure("unexpected IntermediateMessageEntry in MessageHistoryView.init()")
                }
            }
        } else {
            for entry in mutableView.entries {
                switch entry {
                    case let .HoleEntry(hole, location):
                        entries.append(.HoleEntry(hole, location))
                    case let .MessageEntry(message, location, monthLocation):
                        entries.append(.MessageEntry(message, false, location, monthLocation))
                    case .IntermediateMessageEntry:
                        assertionFailure("unexpected IntermediateMessageEntry in MessageHistoryView.init()")
                }
            }
        }
        if !entries.isEmpty {
            var referenceIndex = entries.count - 1
            for i in 0 ..< entries.count {
                if entries[i].index >= self.anchorIndex {
                    referenceIndex = i
                    break
                }
            }
            for i in referenceIndex ..< entries.count {
                if case .HoleEntry = entries[i] {
                    if i != entries.count - 1 {
                        entries.removeSubrange(i + 1 ..< entries.count)
                        laterId = nil
                    }
                    break
                }
            }
            for i in (0 ... referenceIndex).reversed() {
                if case .HoleEntry = entries[i] {
                    if i != 0 {
                        entries.removeSubrange(0 ..< i)
                        earlierId = nil
                    }
                    break
                }
            }
        }
        self.entries = entries
        
        var topTaggedMessages: [Message] = []
        for (_, message) in mutableView.topTaggedMessages {
            if let message = message {
                switch message {
                    case let .message(message):
                        topTaggedMessages.append(message)
                    default:
                        assertionFailure("unexpected intermediate tagged message entry in MessageHistoryView.init()")
                }
            }
        }
        self.topTaggedMessages = topTaggedMessages
        self.additionalData = mutableView.additionalDatas
        
        self.earlierId = earlierId
        self.laterId = laterId
        
        self.combinedReadState = mutableView.combinedReadState
        
        if let combinedReadState = mutableView.combinedReadState , combinedReadState.count != 0 {
            var maxIndex: MessageIndex?
            for (namespace, state) in combinedReadState.states {
                var maxNamespaceIndex: MessageIndex?
                var index = entries.count - 1
                for entry in entries.reversed() {
                    if entry.index.id.namespace == namespace && state.isIncomingMessageIndexRead(entry.index) {
                        maxNamespaceIndex = entry.index
                        break
                    }
                    index -= 1
                }
                if maxNamespaceIndex == nil && index == -1 && entries.count != 0 {
                    index = 0
                    for entry in entries {
                        if entry.index.id.namespace == namespace {
                            maxNamespaceIndex = entry.index
                            break
                        }
                        index += 1
                    }
                }
                if let _ = maxNamespaceIndex , index + 1 < entries.count {
                    for i in index + 1 ..< entries.count {
                        if case let .MessageEntry(message, _, _, _) = entries[i] , !message.flags.contains(.Incoming) {
                            maxNamespaceIndex = MessageIndex(message)
                        } else {
                            break
                        }
                    }
                }
                if let maxNamespaceIndex = maxNamespaceIndex , maxIndex == nil || maxIndex! < maxNamespaceIndex {
                    maxIndex = maxNamespaceIndex
                }
            }
            self.maxReadIndex = maxIndex
        } else {
            self.maxReadIndex = nil
        }
    }
}
