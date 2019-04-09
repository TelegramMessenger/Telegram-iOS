import Foundation

public struct MessageHistoryViewPeerHole: Equatable, Hashable {
    public let peerId: PeerId
    public let namespace: MessageId.Namespace
    public let indices: IndexSet
}

public enum MessageHistoryViewHole: Equatable, Hashable {
    case peer(MessageHistoryViewPeerHole)
}

public struct MessageHistoryMessageEntry {
    let message: Message
    let location: MessageHistoryEntryLocation?
    let monthLocation: MessageHistoryEntryMonthLocation?
    let attributes: MutableMessageHistoryEntryAttributes
}

enum MutableMessageHistoryEntry {
    case IntermediateMessageEntry(IntermediateMessage, MessageHistoryEntryLocation?, MessageHistoryEntryMonthLocation?)
    case MessageEntry(MessageHistoryMessageEntry)
    
    var index: MessageIndex {
        switch self {
            case let .IntermediateMessageEntry(message, _, _):
                return message.index
            case let .MessageEntry(message):
                return message.message.index
        }
    }
    
    var tags: MessageTags {
        switch self {
            case let .IntermediateMessageEntry(message, _, _):
                return message.tags
            case let .MessageEntry(message):
                return message.message.tags
        }
    }
    
    func updatedLocation(_ location: MessageHistoryEntryLocation?) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, _, monthLocation):
                return .IntermediateMessageEntry(message, location, monthLocation)
            case let .MessageEntry(message):
                return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: location, monthLocation: message.monthLocation, attributes: message.attributes))
        }
    }
    
    func updatedMonthLocation(_ monthLocation: MessageHistoryEntryMonthLocation?) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, location, _):
                return .IntermediateMessageEntry(message, location, monthLocation)
            case let .MessageEntry(message):
                return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: message.location, monthLocation: monthLocation, attributes: message.attributes))
        }
    }
    
    func offsetLocationForInsertedIndex(_ index: MessageIndex) -> MutableMessageHistoryEntry {
        switch self {
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
            case let .MessageEntry(message):
                if let location = message.location {
                    if message.message.index > index {
                        return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: MessageHistoryEntryLocation(index: location.index + 1, count: location.count + 1), monthLocation: message.monthLocation, attributes: message.attributes))
                    } else {
                        return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: MessageHistoryEntryLocation(index: location.index, count: location.count + 1), monthLocation: message.monthLocation, attributes: message.attributes))
                    }
                } else {
                    return self
                }
        }
    }
    
    func offsetLocationForRemovedIndex(_ index: MessageIndex) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, location, monthLocation):
                if let location = location {
                    if MessageIndex(id: message.id, timestamp: message.timestamp) > index {
                        //assert(location.index > 0)
                        //assert(location.count != 0)
                        return .IntermediateMessageEntry(message, MessageHistoryEntryLocation(index: location.index - 1, count: location.count - 1), monthLocation)
                    } else {
                        //assert(location.count != 0)
                        return .IntermediateMessageEntry(message, MessageHistoryEntryLocation(index: location.index, count: location.count - 1), monthLocation)
                    }
                } else {
                    return self
                }
            case let .MessageEntry(message):
                if let location = message.location {
                    if message.message.index > index {
                        //assert(location.index > 0)
                        //assert(location.count != 0)
                        return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: MessageHistoryEntryLocation(index: location.index - 1, count: location.count - 1), monthLocation: message.monthLocation, attributes: message.attributes))
                    } else {
                        //assert(location.count != 0)
                        return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: MessageHistoryEntryLocation(index: location.index, count: location.count - 1), monthLocation: message.monthLocation, attributes: message.attributes))
                    }
                } else {
                    return self
                }
        }
    }
    
    func updatedTimestamp(_ timestamp: Int32) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, location, monthLocation):
                let updatedMessage = IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: message.embeddedMediaData, referencedMedia: message.referencedMedia)
                return .IntermediateMessageEntry(updatedMessage, location, monthLocation)
            case let .MessageEntry(value):
                let message = value.message
                let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: message.peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds)
                return .MessageEntry(MessageHistoryMessageEntry(message: updatedMessage, location: value.location, monthLocation: value.monthLocation, attributes: value.attributes))
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
}

public struct MessageHistoryEntryMonthLocation: Equatable {
    public let indexInMonth: Int32
}

public struct MessageHistoryEntry: Comparable {
    public let message: Message
    public let isRead: Bool
    public let location: MessageHistoryEntryLocation?
    public let monthLocation: MessageHistoryEntryMonthLocation?
    public let attributes: MutableMessageHistoryEntryAttributes
    
    public var index: MessageIndex {
        return MessageIndex(id: self.message.id, timestamp: self.message.timestamp)
    }
    
    public init(message: Message, isRead: Bool, location: MessageHistoryEntryLocation?, monthLocation: MessageHistoryEntryMonthLocation?, attributes: MutableMessageHistoryEntryAttributes) {
        self.message = message
        self.isRead = isRead
        self.location = location
        self.monthLocation = monthLocation
        self.attributes = attributes
    }

    public static func ==(lhs: MessageHistoryEntry, rhs: MessageHistoryEntry) -> Bool {
        if lhs.message.index == rhs.message.index && lhs.message.flags == rhs.message.flags && lhs.location == rhs.location && lhs.isRead == rhs.isRead && lhs.monthLocation == rhs.monthLocation && lhs.attributes == rhs.attributes {
            return true
        }
        return false
    }
    
    public static func <(lhs: MessageHistoryEntry, rhs: MessageHistoryEntry) -> Bool {
        return lhs.index < rhs.index
    }
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

public enum MessageHistoryViewRelativeHoleDirection: Equatable, Hashable {
    case UpperToLower
    case LowerToUpper
    case AroundId(MessageId)
}

public struct MessageHistoryViewOrderStatistics: OptionSet {
    public var rawValue: Int32
    
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

public enum MessageHistoryViewPeerIds: Equatable {
    case single(PeerId)
    case associated(PeerId, MessageId?)
}

public enum MessageHistoryViewReadState {
    case peer([PeerId: CombinedPeerReadState])
}

public enum HistoryViewInputAnchor {
    case lowerBound
    case upperBound
    case message(MessageId)
    case index(MessageIndex)
    case unread
}

final class MutableMessageHistoryView {
    private(set) var peerIds: MessageHistoryViewPeerIds
    let tag: MessageTags?
    private let orderStatistics: MessageHistoryViewOrderStatistics
    private let anchor: HistoryViewInputAnchor
    
    fileprivate var combinedReadStates: MessageHistoryViewReadState?
    fileprivate var transientReadStates: MessageHistoryViewReadState?
    
    fileprivate let fillCount: Int
    fileprivate var state: HistoryViewState
    
    fileprivate var topTaggedMessages: [MessageId.Namespace: MessageHistoryTopTaggedMessage?]
    fileprivate var additionalDatas: [AdditionalMessageHistoryViewDataEntry]
    
    init(postbox: Postbox, orderStatistics: MessageHistoryViewOrderStatistics, peerIds: MessageHistoryViewPeerIds, anchor: HistoryViewInputAnchor, combinedReadStates: MessageHistoryViewReadState?, transientReadStates: MessageHistoryViewReadState?, tag: MessageTags?, count: Int, topTaggedMessages: [MessageId.Namespace: MessageHistoryTopTaggedMessage?], additionalDatas: [AdditionalMessageHistoryViewDataEntry], getMessageCountInRange: (MessageIndex, MessageIndex) -> Int32) {
        self.anchor = anchor
        
        self.orderStatistics = orderStatistics
        self.peerIds = peerIds
        self.combinedReadStates = combinedReadStates
        self.transientReadStates = transientReadStates
        self.tag = tag
        self.fillCount = count
        self.topTaggedMessages = topTaggedMessages
        self.additionalDatas = additionalDatas
        
        preconditionFailure()
        
        /*if let tagMask = self.tagMask, !orderStatistics.isEmpty && !self.entries.isEmpty {
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
                var peerId: PeerId?
                switch self.peerIds {
                    case let .single(id):
                        peerId = id
                    case let .associated(id, _):
                        peerId = id
                }
                
                if let peerId = peerId {
                    var topMessageEntryIndex: Int?
                    var index = self.entries.count - 1
                    loop: for entry in self.entries.reversed() {
                        switch entry {
                            case .IntermediateMessageEntry, .MessageEntry:
                                topMessageEntryIndex = index
                                break loop
                        }
                        index -= 1
                    }
                    if let topMessageEntryIndex = topMessageEntryIndex {
                        let topMessageIndex = self.entries[topMessageEntryIndex].index
                        
                        let monthIndex = MessageMonthIndex(timestamp: topMessageIndex.timestamp)
                        
                        let laterCount: Int32
                        if self.later == nil {
                            laterCount = 0
                        } else {
                            laterCount = postbox.messageHistoryTagsTable.getMessageCountInRange(tagMask: tagMask, peerId: peerId, lowerBound: topMessageIndex.successor(), upperBound: monthUpperBoundIndex(peerId: peerId, index: monthIndex))
                        }
                        self.entries[topMessageEntryIndex] = self.entries[topMessageEntryIndex].updatedMonthLocation(MessageHistoryEntryMonthLocation(indexInMonth: laterCount))
                    }
                }
            }
        }*/
    }
    
    private func reset(postbox: Postbox) {
        
    }
    
    func refreshDueToExternalTransaction(postbox: Postbox) -> Bool {
        self.reset(postbox: postbox)
        return true
    }
    
    func updatePeerIds(transaction: PostboxTransaction) {
        switch self.peerIds {
            case let .single(peerId):
                if let updatedData = transaction.currentUpdatedCachedPeerData[peerId] {
                    if updatedData.associatedHistoryMessageId != nil {
                        self.peerIds = .associated(peerId, updatedData.associatedHistoryMessageId)
                    }
                }
            case let .associated(peerId, associatedId):
                if let updatedData = transaction.currentUpdatedCachedPeerData[peerId] {
                    if updatedData.associatedHistoryMessageId != associatedId {
                        self.peerIds = .associated(peerId, updatedData.associatedHistoryMessageId)
                    }
                }
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction, updatedMedia: [MediaId: Media?], updatedCachedPeerData: [PeerId: CachedPeerData], context: MutableMessageHistoryViewReplayContext, renderIntermediateMessage: (IntermediateMessage) -> Message) -> Bool {
        var operations: [[MessageHistoryOperation]] = []
        
        /*switch self.peerIds {
            case let .single(peerId):
                if let value = transaction.currentOperationsByPeerId[peerId] {
                    operations.append(value)
                }
            case .associated:
                var ids = Set<PeerId>()
                switch self.peerIds {
                    case .single:
                        assertionFailure()
                    case let .associated(mainPeerId, associatedPeerId):
                        ids.insert(mainPeerId)
                        if let associatedPeerId = associatedPeerId {
                            ids.insert(associatedPeerId.peerId)
                        }
                }
                
                if !ids.isEmpty {
                    for (peerId, value) in transaction.currentOperationsByPeerId {
                        if ids.contains(peerId) {
                            operations.append(value)
                        }
                    }
                }
        }
        
        let tagMask = self.tagMask
        let unwrappedTagMask: UInt32 = tagMask?.rawValue ?? 0*/
        
        var hasChanges = false
        
        /*for operationSet in operations {
            for operation in operationSet {
                switch operation {
                    case let .InsertMessage(intermediateMessage):
                        if tagMask == nil || (intermediateMessage.tags.rawValue & unwrappedTagMask) != 0 {
                            if self.add(.IntermediateMessageEntry(intermediateMessage, nil, nil)) {
                                hasChanges = true
                            }
                        }
                    case let .Remove(indices):
                        if self.remove(indices, context: context) {
                            hasChanges = true
                        }
                    case let .UpdateReadState(peerId, combinedReadState):
                        hasChanges = true
                        if let transientReadStates = self.transientReadStates {
                            switch transientReadStates {
                                case let .peer(states):
                                    var updatedStates = states
                                    updatedStates[peerId] = combinedReadState
                                    self.transientReadStates = .peer(updatedStates)
                                /*case .group:
                                    break*/
                            }
                        }
                    case let .UpdateEmbeddedMedia(index, embeddedMediaData):
                        for i in 0 ..< self.entries.count {
                            if case let .IntermediateMessageEntry(message, location, monthLocation) = self.entries[i] , message.index == index {
                                self.entries[i] = .IntermediateMessageEntry(IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: embeddedMediaData, referencedMedia: message.referencedMedia), location, monthLocation)
                                hasChanges = true
                                break
                            }
                        }
                    case let .UpdateTimestamp(index, timestamp):
                        for i in 0 ..< self.entries.count {
                            let entry = self.entries[i]
                            if entry.index == index {
                                let _ = self.remove([(index, entry.tags)], context: context)
                                let _ = self.add(entry.updatedTimestamp(timestamp))
                                hasChanges = true
                                break
                            }
                        }
                    case let .UpdateGroupInfos(mapping):
                        for i in 0 ..< self.entries.count {
                            if let groupInfo = mapping[self.entries[i].index.id] {
                                switch self.entries[i] {
                                    case let .IntermediateMessageEntry(message, location, monthLocation):
                                        self.entries[i] = .IntermediateMessageEntry(message.withUpdatedGroupInfo(groupInfo), location, monthLocation)
                                        hasChanges = true
                                    case let .MessageEntry(message):
                                        self.entries[i] = .MessageEntry(MessageHistoryMessageEntry(message: message.message.withUpdatedGroupInfo(groupInfo), location: message.location, monthLocation: message.monthLocation, attributes: message.attributes))
                                        hasChanges = true
                                }
                            }
                    }
                }
            }
        }*/
            
        /*if !updatedMedia.isEmpty {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                    case let .MessageEntry(value):
                        let message = value.message
                        
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
                            let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: messageMedia, peers: message.peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds)
                            self.entries[i] = .MessageEntry(MessageHistoryMessageEntry(message: updatedMessage, location: value.location, monthLocation: value.monthLocation, attributes: value.attributes))
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
                }
            }
        }*/
        
        /*for operationSet in operations {
            for operation in operationSet {
                switch operation {
                    case let .InsertMessage(intermediateMessage):
                        for i in 0 ..< self.entries.count {
                            switch self.entries[i] {
                                case let .MessageEntry(value):
                                    let message = value.message
                                    if message.associatedMessageIds.count != message.associatedMessages.count {
                                        if message.associatedMessageIds.contains(intermediateMessage.id) && message.associatedMessages[intermediateMessage.id] == nil {
                                            var updatedAssociatedMessages = message.associatedMessages
                                            let renderedMessage = renderIntermediateMessage(intermediateMessage)
                                            updatedAssociatedMessages[intermediateMessage.id] = renderedMessage
                                            let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: message.peers, associatedMessages: updatedAssociatedMessages, associatedMessageIds: message.associatedMessageIds)
                                            self.entries[i] = .MessageEntry(MessageHistoryMessageEntry(message: updatedMessage, location: value.location, monthLocation: value.monthLocation, attributes: value.attributes))
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
        }*/
        
        /*for operationSet in operations {
            for operation in operationSet {
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
                            for (index, _) in indices {
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
        }*/
        
        var updatedCachedPeerDataMessages = false
        var currentCachedPeerData: CachedPeerData?
        for i in 0 ..< self.additionalDatas.count {
            switch self.additionalDatas[i] {
                case let .cachedPeerData(peerId, currentData):
                    currentCachedPeerData = currentData
                    if let updatedData = updatedCachedPeerData[peerId] {
                        if currentData?.messageIds != updatedData.messageIds {
                            updatedCachedPeerDataMessages = true
                        }
                        currentCachedPeerData = updatedData
                        self.additionalDatas[i] = .cachedPeerData(peerId, updatedData)
                        hasChanges = true
                    }
                case .cachedPeerDataMessages:
                    break
                case let .peerChatState(peerId, _):
                    if transaction.currentUpdatedPeerChatStates.contains(peerId) {
                        self.additionalDatas[i] = .peerChatState(peerId, postbox.peerChatStateTable.get(peerId) as? PeerChatState)
                        hasChanges = true
                    }
                case .totalUnreadState:
                    break
                case .peerNotificationSettings:
                    break
                case let .cacheEntry(entryId, _):
                    if transaction.updatedCacheEntryKeys.contains(entryId) {
                        self.additionalDatas[i] = .cacheEntry(entryId, postbox.retrieveItemCacheEntry(id: entryId))
                        hasChanges = true
                    }
                case .preferencesEntry:
                    break
                case let .peerIsContact(peerId, value):
                    if let replacedPeerIds = transaction.replaceContactPeerIds {
                        let updatedValue: Bool
                        if let contactPeer = postbox.peerTable.get(peerId), let associatedPeerId = contactPeer.associatedPeerId {
                            updatedValue = replacedPeerIds.contains(associatedPeerId)
                        } else {
                            updatedValue = replacedPeerIds.contains(peerId)
                        }
                        
                        if value != updatedValue {
                            self.additionalDatas[i] = .peerIsContact(peerId, value)
                            hasChanges = true
                        }
                    }
                case let .peer(peerId, _):
                    if let peer = transaction.currentUpdatedPeers[peerId] {
                        self.additionalDatas[i] = .peer(peerId, peer)
                        hasChanges = true
                    }
            }
        }
        if let cachedData = currentCachedPeerData, !cachedData.messageIds.isEmpty {
            for i in 0 ..< self.additionalDatas.count {
                switch self.additionalDatas[i] {
                    case .cachedPeerDataMessages(_, _):
                        outer: for operationSet in operations {
                            for operation in operationSet {
                                switch operation {
                                    case let .InsertMessage(message):
                                        if cachedData.messageIds.contains(message.id) {
                                            updatedCachedPeerDataMessages = true
                                            break outer
                                        }
                                    case let .Remove(indicesWithTags):
                                        for (index, _) in indicesWithTags {
                                            if cachedData.messageIds.contains(index.id) {
                                                updatedCachedPeerDataMessages = true
                                                break outer
                                            }
                                        }
                                    default:
                                        break
                                }
                            }
                        }
                    default:
                        break
                }
            }
        }
        
        if updatedCachedPeerDataMessages {
            hasChanges = true
            for i in 0 ..< self.additionalDatas.count {
                switch self.additionalDatas[i] {
                    case let .cachedPeerDataMessages(peerId, _):
                        var messages: [MessageId: Message] = [:]
                        if let cachedData = currentCachedPeerData {
                            for id in cachedData.messageIds {
                                if let message = postbox.getMessage(id) {
                                    messages[id] = message
                                }
                            }
                        }
                        self.additionalDatas[i] = .cachedPeerDataMessages(peerId, messages)
                    default:
                        break
                }
            }
        }
        
        if !transaction.currentPeerHoleOperations.isEmpty {
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
            let space: MessageHistoryHoleSpace = self.tag.flatMap(MessageHistoryHoleSpace.tag) ?? .everywhere
            for key in transaction.currentPeerHoleOperations.keys {
                if peerIdsSet.contains(key.peerId) && key.space == space {
                    hasChanges = true
                }
            }
        }
        
        return hasChanges
    }
    
    func updatePeers(_ peers: [PeerId: Peer]) -> Bool {
        return false
    }
    
    func render(postbox: Postbox) {
        
        for namespace in self.topTaggedMessages.keys {
            if let entry = self.topTaggedMessages[namespace]!, case let .intermediate(message) = entry {
                let item: MessageHistoryTopTaggedMessage? = .message(postbox.messageHistoryTable.renderMessage(message, peerTable: postbox.peerTable))
                self.topTaggedMessages[namespace] = item
            }
        }
    }
    
    func firstHole() -> (MessageHistoryViewHole, MessageHistoryViewRelativeHoleDirection)? {
        return nil
    }
}

public final class MessageHistoryView {
    public let tagMask: MessageTags?
    public let anchorIndex: MessageHistoryAnchorIndex
    public let earlierId: MessageIndex?
    public let laterId: MessageIndex?
    public let holeEarlier: Bool
    public let holeLater: Bool
    public let entries: [MessageHistoryEntry]
    public let maxReadIndex: MessageIndex?
    public let fixedReadStates: MessageHistoryViewReadState?
    public let topTaggedMessages: [Message]
    public let additionalData: [AdditionalMessageHistoryViewDataEntry]
    public let isLoading: Bool
    
    init(_ mutableView: MutableMessageHistoryView) {
        self.tagMask = mutableView.tag
        switch mutableView.state {
            case .loading:
                self.isLoading = true
                self.anchorIndex = .upperBound
            case let .loaded(state):
                self.isLoading = false
                switch state.anchor {
                    case .lowerBound:
                        self.anchorIndex = .lowerBound
                    case .upperBound:
                        self.anchorIndex = .upperBound
                    case let .index(index):
                        self.anchorIndex = .message(index)
                }
        }
        
        /*var entries: [MessageHistoryEntry] = []
        if let transientReadStates = mutableView.transientReadStates, case let .peer(states) = transientReadStates {
            for entry in mutableView.entries {
                switch entry {
                    case let .MessageEntry(value):
                        let read: Bool
                        if value.message.flags.contains(.Incoming) {
                            read = false
                        } else if let readState = states[value.message.id.peerId] {
                            read = readState.isOutgoingMessageIndexRead(value.message.index)
                        } else {
                            read = false
                        }
                        entries.append(MessageHistoryEntry(message: value.message, isRead: read, location: value.location, monthLocation: value.monthLocation, attributes: value.attributes))
                    case .IntermediateMessageEntry:
                        assertionFailure("unexpected IntermediateMessageEntry in MessageHistoryView.init()")
                }
            }
        } else {
            for entry in mutableView.entries {
                switch entry {
                    case let .MessageEntry(value):
                        entries.append(MessageHistoryEntry(message: value.message, isRead: false, location: value.location, monthLocation: value.monthLocation, attributes: value.attributes))
                    case .IntermediateMessageEntry:
                        assertionFailure("unexpected IntermediateMessageEntry in MessageHistoryView.init()")
                }
            }
        }
        var holeEarlier = false
        var holeLater = false
        if mutableView.clipHoles {
            if entries.isEmpty {
                if !mutableView.holes.isEmpty {
                    holeEarlier = true
                    holeLater = true
                }
            } else {
                var clearAllEntries = false
                if case let .message(index) = self.anchorIndex {
                    for (holeKey, indices) in mutableView.holes {
                        if holeKey.peerId == index.id.peerId && holeKey.namespace == index.id.namespace && indices.contains(Int(index.id.id)) {
                            entries.removeAll()
                            earlierId = nil
                            holeEarlier = true
                            laterId = nil
                            holeLater = true
                            clearAllEntries = true
                            break
                        }
                    }
                }
                if !clearAllEntries {
                    var referenceIndex = entries.count - 1
                    for i in 0 ..< entries.count {
                        if self.anchorIndex.isLessOrEqual(to: entries[i].index) {
                            referenceIndex = i
                            break
                        }
                    }
                    var groupStart: (Int, MessageGroupInfo)?
                    for i in referenceIndex ..< entries.count {
                        let id = entries[i].message.id
                        if let holeIndices = mutableView.holes[PeerIdAndNamespace(peerId: id.peerId, namespace: id.namespace)] {
                            if holeIndices.contains(Int(id.id)) {
                                if let groupStart = groupStart {
                                    entries.removeSubrange(groupStart.0 ..< entries.count)
                                } else {
                                    entries.removeSubrange(i ..< entries.count)
                                }
                                laterId = nil
                                holeLater = true
                                break
                            }
                        }
                        /*if let groupStart = groupStart {
                            entries.removeSubrange(groupStart.0 ..< entries.count)
                            laterId = nil
                        } else {
                            if i != entries.count - 1 {
                                entries.removeSubrange(i + 1 ..< entries.count)
                                laterId = nil
                            }
                        }*/
                        if let groupInfo = entries[i].message.groupInfo {
                            if let groupStart = groupStart, groupStart.1 == groupInfo {
                            } else {
                                groupStart = (i, groupInfo)
                            }
                        } else {
                            groupStart = nil
                        }
                    }
                    if let groupStart = groupStart, laterId != nil {
                        entries.removeSubrange(groupStart.0 ..< entries.count)
                    }
                    
                    groupStart = nil
                    if !entries.isEmpty {
                        for i in (0 ... min(referenceIndex, entries.count - 1)).reversed() {
                            let id = entries[i].message.id
                            if let holeIndices = mutableView.holes[PeerIdAndNamespace(peerId: id.peerId, namespace: id.namespace)] {
                                if holeIndices.contains(Int(id.id)) {
                                    if let groupStart = groupStart {
                                        entries.removeSubrange(0 ..< groupStart.0 + 1)
                                    } else {
                                        entries.removeSubrange(0 ... i)
                                    }
                                    earlierId = nil
                                    holeEarlier = true
                                    break
                                }
                            }
                            /*if let groupStart = groupStart {
                                entries.removeSubrange(0 ..< groupStart.0 + 1)
                                earlierId = nil
                            } else {
                                if i != 0 {
                                    entries.removeSubrange(0 ..< i)
                                    earlierId = nil
                                }
                            }
                            break
                            */
                            if let groupInfo = entries[i].message.groupInfo {
                                if let groupStart = groupStart, groupStart.1 == groupInfo {
                                } else {
                                    groupStart = (i, groupInfo)
                                }
                            } else {
                                groupStart = nil
                            }
                        }
                        if let groupStart = groupStart, earlierId != nil {
                            entries.removeSubrange(0 ..< groupStart.0 + 1)
                        }
                    }
                }
            }
        }
        self.holeEarlier = holeEarlier
        self.holeLater = holeLater
        self.entries = entries*/
        
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
        
        var entries: [MessageHistoryEntry] = []
        
        self.entries = entries
        self.earlierId = nil
        self.laterId = nil
        self.holeEarlier = false
        self.holeLater = false
        
        self.fixedReadStates = mutableView.combinedReadStates
        
        if let combinedReadStates = mutableView.combinedReadStates {
            switch combinedReadStates {
                case let .peer(states):
                    var hasUnread = false
                    for (_, readState) in states {
                        if readState.count > 0 {
                            hasUnread = true
                            break
                        }
                    }
                    
                    var maxIndex: MessageIndex?
                    
                    if hasUnread {
                        var peerIds = Set<PeerId>()
                        for entry in self.entries {
                            peerIds.insert(entry.index.id.peerId)
                        }
                        for peerId in peerIds {
                            if let combinedReadState = states[peerId] {
                                for (namespace, state) in combinedReadState.states {
                                    var maxNamespaceIndex: MessageIndex?
                                    var index = self.entries.count - 1
                                    for entry in entries.reversed() {
                                        if entry.index.id.peerId == peerId && entry.index.id.namespace == namespace && state.isIncomingMessageIndexRead(entry.index) {
                                            maxNamespaceIndex = entry.index
                                            break
                                        }
                                        index -= 1
                                    }
                                    if maxNamespaceIndex == nil && index == -1 && entries.count != 0 {
                                        index = 0
                                        for entry in entries {
                                            if entry.index.id.peerId == peerId && entry.index.id.namespace == namespace {
                                                maxNamespaceIndex = entry.index.predecessor()
                                                break
                                            }
                                            index += 1
                                        }
                                    }
                                    if let _ = maxNamespaceIndex , index + 1 < entries.count {
                                        for i in index + 1 ..< entries.count {
                                            if !entries[i].message.flags.contains(.Incoming) {
                                                maxNamespaceIndex = entries[i].message.index
                                            } else {
                                                break
                                            }
                                        }
                                    }
                                    if let maxNamespaceIndex = maxNamespaceIndex , maxIndex == nil || maxIndex! < maxNamespaceIndex {
                                        maxIndex = maxNamespaceIndex
                                    }
                                }
                            }
                        }
                    }
                    self.maxReadIndex = maxIndex
            }
        } else {
            self.maxReadIndex = nil
        }
    }
}
