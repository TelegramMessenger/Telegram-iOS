import Foundation

public struct MessageHistoryViewPeerHole: Equatable, Hashable, CustomStringConvertible {
    public let peerId: PeerId
    public let namespace: MessageId.Namespace
    public let threadId: Int64?
    
    public init(peerId: PeerId, namespace: MessageId.Namespace, threadId: Int64?) {
        self.peerId = peerId
        self.namespace = namespace
        self.threadId = threadId
    }
    
    public var description: String {
        return "peerId: \(self.peerId), namespace: \(self.namespace), threadId: \(String(describing: self.threadId))"
    }
}

public enum MessageHistoryViewHole: Equatable, Hashable, CustomStringConvertible {
    case peer(MessageHistoryViewPeerHole)
    
    public var description: String {
        switch self {
        case let .peer(hole):
            return "peer(\(hole))"
        }
    }
}

public struct MessageHistoryMessageEntry {
    let message: Message
    let location: MessageHistoryEntryLocation?
    let monthLocation: MessageHistoryEntryMonthLocation?
    let attributes: MutableMessageHistoryEntryAttributes
}

enum MutableMessageHistoryEntry {
    case IntermediateMessageEntry(IntermediateMessage, MessageHistoryEntryLocation?, MessageHistoryEntryMonthLocation?)
    case MessageEntry(MessageHistoryMessageEntry, reloadAssociatedMessages: Bool, reloadPeers: Bool)
    
    var index: MessageIndex {
        switch self {
        case let .IntermediateMessageEntry(message, _, _):
            return message.index
        case let .MessageEntry(message, _, _):
            return message.message.index
        }
    }
    
    var tags: MessageTags {
        switch self {
        case let .IntermediateMessageEntry(message, _, _):
            return message.tags
        case let .MessageEntry(message, _, _):
            return message.message.tags
        }
    }
    
    func updatedLocation(_ location: MessageHistoryEntryLocation?) -> MutableMessageHistoryEntry {
        switch self {
        case let .IntermediateMessageEntry(message, _, monthLocation):
            return .IntermediateMessageEntry(message, location, monthLocation)
        case let .MessageEntry(message, reloadAssociatedMessages, reloadPeers):
            return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: location, monthLocation: message.monthLocation, attributes: message.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
        }
    }
    
    func updatedMonthLocation(_ monthLocation: MessageHistoryEntryMonthLocation?) -> MutableMessageHistoryEntry {
        switch self {
        case let .IntermediateMessageEntry(message, location, _):
            return .IntermediateMessageEntry(message, location, monthLocation)
        case let .MessageEntry(message, reloadAssociatedMessages, reloadPeers):
            return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: message.location, monthLocation: monthLocation, attributes: message.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
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
        case let .MessageEntry(message, reloadAssociatedMessages, reloadPeers):
            if let location = message.location {
                if message.message.index > index {
                    return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: MessageHistoryEntryLocation(index: location.index + 1, count: location.count + 1), monthLocation: message.monthLocation, attributes: message.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
                } else {
                    return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: MessageHistoryEntryLocation(index: location.index, count: location.count + 1), monthLocation: message.monthLocation, attributes: message.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
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
        case let .MessageEntry(message, reloadAssociatedMessages, reloadPeers):
            if let location = message.location {
                if message.message.index > index {
                    //assert(location.index > 0)
                    //assert(location.count != 0)
                    return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: MessageHistoryEntryLocation(index: location.index - 1, count: location.count - 1), monthLocation: message.monthLocation, attributes: message.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
                } else {
                    //assert(location.count != 0)
                    return .MessageEntry(MessageHistoryMessageEntry(message: message.message, location: MessageHistoryEntryLocation(index: location.index, count: location.count - 1), monthLocation: message.monthLocation, attributes: message.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
                }
            } else {
                return self
            }
        }
    }
    
    func updatedTimestamp(_ timestamp: Int32) -> MutableMessageHistoryEntry {
        switch self {
        case let .IntermediateMessageEntry(message, location, monthLocation):
            let updatedMessage = IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, threadId: message.threadId, timestamp: timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: message.embeddedMediaData, referencedMedia: message.referencedMedia)
            return .IntermediateMessageEntry(updatedMessage, location, monthLocation)
        case let .MessageEntry(value, reloadAssociatedMessages, reloadPeers):
            let message = value.message
            let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, threadId: message.threadId, timestamp: timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: message.peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds, associatedMedia: message.associatedMedia, associatedThreadInfo: message.associatedThreadInfo)
            return .MessageEntry(MessageHistoryMessageEntry(message: updatedMessage, location: value.location, monthLocation: value.monthLocation, attributes: value.attributes), reloadAssociatedMessages: reloadAssociatedMessages, reloadPeers: reloadPeers)
        }
    }
    
    func getAssociatedMessageIds() -> [MessageId] {
        switch self {
        case .IntermediateMessageEntry:
            return []
        case let .MessageEntry(value, _, _):
            return value.message.associatedMessageIds
        }
    }
}

public struct MessageHistoryEntryLocation: Equatable {
    public let index: Int
    public let count: Int
    
    public init(index: Int, count: Int) {
        self.index = index
        self.count = count
    }
    
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

public enum MessageHistoryViewRelativeHoleDirection: Equatable, Hashable, CustomStringConvertible {
    case range(start: MessageId, end: MessageId)
    case aroundId(MessageId)
    
    public var description: String {
        switch self {
        case let .range(start, end):
            return "range(\(start), \(end))"
        case let .aroundId(id):
            return "aroundId(\(id))"
        }
    }
}

public struct MessageHistoryViewOrderStatistics: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let combinedLocation = MessageHistoryViewOrderStatistics(rawValue: 1 << 0)
}

public final class MessageHistoryViewExternalInput: Equatable {
    public enum Content: Equatable {
        case messages(indices: [MessageIndex], holes: [MessageId.Namespace: IndexSet], userId: Int64?)
        case thread(peerId: PeerId, id: Int64, holes: [MessageId.Namespace: IndexSet])
    }
    
    public let content: Content
    public let maxReadIncomingMessageId: MessageId?
    public let maxReadOutgoingMessageId: MessageId?
    
    public init(
        content: Content,
        maxReadIncomingMessageId: MessageId?,
        maxReadOutgoingMessageId: MessageId?
    ) {
        self.content = content
        self.maxReadIncomingMessageId = maxReadIncomingMessageId
        self.maxReadOutgoingMessageId = maxReadOutgoingMessageId
    }
    
    public static func ==(lhs: MessageHistoryViewExternalInput, rhs: MessageHistoryViewExternalInput) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.maxReadIncomingMessageId != rhs.maxReadIncomingMessageId {
            return false
        }
        if lhs.maxReadOutgoingMessageId != rhs.maxReadOutgoingMessageId {
            return false
        }
        return true
    }
}

public enum MessageHistoryViewInput: Equatable {
    case single(peerId: PeerId, threadId: Int64?)
    case associated(PeerId, MessageId?)
    case external(MessageHistoryViewExternalInput)
}

public enum MessageHistoryViewReadState {
    case peer([PeerId: CombinedPeerReadState])
}

public enum HistoryViewInputAnchor: Equatable {
    case lowerBound
    case upperBound
    case message(MessageId)
    case index(MessageIndex)
    case unread
}

final class MutableMessageHistoryView {
    private(set) var peerIds: MessageHistoryViewInput
    private let ignoreMessagesInTimestampRange: ClosedRange<Int32>?
    let tag: MessageTags?
    private let appendMessagesFromTheSameGroup: Bool
    let namespaces: MessageIdNamespaces
    private let orderStatistics: MessageHistoryViewOrderStatistics
    private let clipHoles: Bool
    private let anchor: HistoryViewInputAnchor
    
    fileprivate var combinedReadStates: MessageHistoryViewReadState?
    fileprivate var transientReadStates: MessageHistoryViewReadState?
    
    fileprivate let fillCount: Int
    fileprivate var state: HistoryViewState
    
    fileprivate var topTaggedMessages: [MessageId.Namespace: MessageHistoryTopTaggedMessage?]
    fileprivate var additionalDatas: [AdditionalMessageHistoryViewDataEntry]
    
    fileprivate(set) var sampledState: HistoryViewSample
    
    fileprivate var isAddedToChatList: Bool
    
    private var userId: Int64?
    
    init(
        postbox: PostboxImpl,
        orderStatistics: MessageHistoryViewOrderStatistics,
        clipHoles: Bool,
        peerIds: MessageHistoryViewInput,
        ignoreMessagesInTimestampRange: ClosedRange<Int32>?,
        anchor inputAnchor: HistoryViewInputAnchor,
        combinedReadStates: MessageHistoryViewReadState?,
        transientReadStates: MessageHistoryViewReadState?,
        tag: MessageTags?,
        appendMessagesFromTheSameGroup: Bool,
        namespaces: MessageIdNamespaces,
        count: Int,
        topTaggedMessages: [MessageId.Namespace: MessageHistoryTopTaggedMessage?],
        additionalDatas: [AdditionalMessageHistoryViewDataEntry],
        getMessageCountInRange: (MessageIndex, MessageIndex) -> Int32
    ) {
        self.anchor = inputAnchor
        
        self.orderStatistics = orderStatistics
        self.clipHoles = clipHoles
        self.peerIds = peerIds
        self.ignoreMessagesInTimestampRange = ignoreMessagesInTimestampRange
        self.combinedReadStates = combinedReadStates
        self.transientReadStates = transientReadStates
        self.tag = tag
        self.appendMessagesFromTheSameGroup = appendMessagesFromTheSameGroup
        self.namespaces = namespaces
        self.fillCount = count
        self.topTaggedMessages = topTaggedMessages
        self.additionalDatas = additionalDatas
        
        switch peerIds {
        case let .associated(peerId, _):
            self.isAddedToChatList = postbox.chatListTable.getPeerChatListIndex(peerId: peerId) != nil
        case let .single(peerId, _):
            self.isAddedToChatList = postbox.chatListTable.getPeerChatListIndex(peerId: peerId) != nil
        case let .external(input):
            switch input.content {
            case let .thread(peerId, _, _):
                self.isAddedToChatList = postbox.chatListTable.getPeerChatListIndex(peerId: peerId) != nil
            case let .messages(_, _, userId):
                self.isAddedToChatList = false
                self.userId = userId
            }
        }
        
        self.state = HistoryViewState(postbox: postbox, inputAnchor: inputAnchor, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: namespaces, statistics: self.orderStatistics, ignoreMessagesInTimestampRange: self.ignoreMessagesInTimestampRange, halfLimit: count + 1, locations: peerIds)
        if case let .loading(loadingState) = self.state {
            let sampledState = loadingState.checkAndSample(postbox: postbox)
            switch sampledState {
            case let .ready(anchor, holes):
                self.state = .loaded(HistoryViewLoadedState(anchor: anchor, tag: tag, appendMessagesFromTheSameGroup: self.appendMessagesFromTheSameGroup, namespaces: namespaces, statistics: self.orderStatistics, ignoreMessagesInTimestampRange: self.ignoreMessagesInTimestampRange, halfLimit: count + 1, locations: peerIds, postbox: postbox, holes: holes))
                self.sampledState = self.state.sample(postbox: postbox, clipHoles: self.clipHoles)
            case .loadHole:
                break
            }
        }
        self.sampledState = self.state.sample(postbox: postbox, clipHoles: self.clipHoles)
        
        self.render(postbox: postbox)
    }
    
    private func reset(postbox: PostboxImpl) {
        self.state = HistoryViewState(postbox: postbox, inputAnchor: self.anchor, tag: self.tag, appendMessagesFromTheSameGroup: self.appendMessagesFromTheSameGroup, namespaces: self.namespaces, statistics: self.orderStatistics, ignoreMessagesInTimestampRange: self.ignoreMessagesInTimestampRange, halfLimit: self.fillCount + 1, locations: self.peerIds)
        if case let .loading(loadingState) = self.state {
            let sampledState = loadingState.checkAndSample(postbox: postbox)
            switch sampledState {
            case let .ready(anchor, holes):
                self.state = .loaded(HistoryViewLoadedState(anchor: anchor, tag: self.tag, appendMessagesFromTheSameGroup: self.appendMessagesFromTheSameGroup, namespaces: self.namespaces, statistics: self.orderStatistics, ignoreMessagesInTimestampRange: self.ignoreMessagesInTimestampRange, halfLimit: self.fillCount + 1, locations: self.peerIds, postbox: postbox, holes: holes))
            case .loadHole:
                break
            }
        }
        if case let .loading(loadingState) = self.state {
            let sampledState = loadingState.checkAndSample(postbox: postbox)
            switch sampledState {
            case let .ready(anchor, holes):
                self.state = .loaded(HistoryViewLoadedState(anchor: anchor, tag: self.tag, appendMessagesFromTheSameGroup: self.appendMessagesFromTheSameGroup, namespaces: self.namespaces, statistics: self.orderStatistics, ignoreMessagesInTimestampRange: self.ignoreMessagesInTimestampRange, halfLimit: self.fillCount + 1, locations: self.peerIds, postbox: postbox, holes: holes))
            case .loadHole:
                break
            }
        }
        self.sampledState = self.state.sample(postbox: postbox, clipHoles: self.clipHoles)
    }
    
    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        self.reset(postbox: postbox)
        return true
    }
    
    func updatePeerIds(transaction: PostboxTransaction) {
        switch self.peerIds {
        case let .single(peerId, threadId):
            if threadId == nil {
                if let updatedData = transaction.currentUpdatedCachedPeerData[peerId] {
                    if updatedData.associatedHistoryMessageId != nil {
                        self.peerIds = .associated(peerId, updatedData.associatedHistoryMessageId)
                    }
                }
            }
        case let .associated(peerId, associatedId):
            if let updatedData = transaction.currentUpdatedCachedPeerData[peerId] {
                if updatedData.associatedHistoryMessageId != associatedId {
                    self.peerIds = .associated(peerId, updatedData.associatedHistoryMessageId)
                }
            }
        case .external:
            break
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var operations: [[MessageHistoryOperation]] = []
        var holePeerIdsSet = Set<PeerId>()
        
        if !transaction.chatListOperations.isEmpty {
            switch peerIds {
            case let .associated(peerId, _):
                self.isAddedToChatList = postbox.chatListTable.getPeerChatListIndex(peerId: peerId) != nil
            case let .single(peerId, _):
                self.isAddedToChatList = postbox.chatListTable.getPeerChatListIndex(peerId: peerId) != nil
            case let .external(input):
                switch input.content {
                case let .thread(peerId, _, _):
                    self.isAddedToChatList = postbox.chatListTable.getPeerChatListIndex(peerId: peerId) != nil
                case .messages:
                    self.isAddedToChatList = false
                }
            }
        }
        
        switch self.peerIds {
        case let .single(peerId, _):
            holePeerIdsSet.insert(peerId)
            if let value = transaction.currentOperationsByPeerId[peerId] {
                operations.append(value)
            }
        case .associated:
            switch self.peerIds {
            case .single, .external:
                assertionFailure()
            case let .associated(mainPeerId, associatedPeerId):
                holePeerIdsSet.insert(mainPeerId)
                if let associatedPeerId = associatedPeerId {
                    holePeerIdsSet.insert(associatedPeerId.peerId)
                }
            }
            
            for (peerId, value) in transaction.currentOperationsByPeerId {
                if holePeerIdsSet.contains(peerId) {
                    operations.append(value)
                }
            }
        case let .external(input):
            switch input.content {
            case let .thread(peerId, _, _):
                if let value = transaction.currentOperationsByPeerId[peerId] {
                    operations.append(value)
                }
            case .messages:
                //TODO:implement
                break
            }
        }
        
        var hasChanges = false
        
        let unwrappedTag: MessageTags = self.tag ?? []
        let externalThreadId: Int64?
        let isExternal: Bool
        switch self.peerIds {
        case let .single(_, threadId):
            externalThreadId = threadId
            isExternal = false
        case .associated:
            externalThreadId = nil
            isExternal = false
        case let .external(input):
            isExternal = true
            switch input.content {
            case let .thread(_, id, _):
                externalThreadId = id
            case .messages:
                externalThreadId = nil
                //TODO:implement
                break
            }
        }
        
        switch self.state {
        case let .loading(loadingState):
            for (key, holeOperations) in transaction.currentPeerHoleOperations {
                var matchesSpace = false
                if !isExternal {
                    switch key.space {
                    case .everywhere:
                        matchesSpace = unwrappedTag.isEmpty
                    case let .tag(tag):
                        if let currentTag = self.tag, currentTag == tag {
                            matchesSpace = true
                        }
                    }
                }
                if matchesSpace {
                    if holePeerIdsSet.contains(key.peerId) && key.threadId == externalThreadId {
                        for operation in holeOperations {
                            switch operation {
                            case let .insert(range):
                                if loadingState.insertHole(space: PeerIdAndNamespace(peerId: key.peerId, namespace: key.namespace), range: range) {
                                    hasChanges = true
                                }
                            case let .remove(range):
                                if loadingState.removeHole(space: PeerIdAndNamespace(peerId: key.peerId, namespace: key.namespace), range: range) {
                                    hasChanges = true
                                }
                            }
                        }
                    }
                }
            }
        case let .loaded(loadedState):
            for operationSet in operations {
                var addCount = 0
                var removeCount = 0
                for operation in operationSet {
                    switch operation {
                    case .InsertMessage:
                        addCount += 1
                    case .Remove:
                        removeCount += 1
                    default:
                        break
                    }
                }
                for operation in operationSet {
                    switch operation {
                    case let .InsertMessage(message):
                        var matchesTag = false
                        if unwrappedTag.isEmpty {
                            matchesTag = true
                        } else if message.tags.contains(unwrappedTag) {
                            matchesTag = true
                        } else if self.appendMessagesFromTheSameGroup, let _ = message.groupInfo {
                            if let group = postbox.messageHistoryTable.getMessageGroup(at: message.index, limit: 20) {
                                for groupMessage in group {
                                    if groupMessage.tags.contains(unwrappedTag) {
                                        matchesTag = true
                                    }
                                }
                            }
                        }
                        
                        var matches = false
                        if matchesTag {
                            if (!isExternal && externalThreadId == nil) || message.threadId == externalThreadId {
                                if self.namespaces.contains(message.id.namespace) {
                                    matches = true
                                    if loadedState.add(entry: .IntermediateMessageEntry(message, nil, nil)) {
                                        hasChanges = true
                                    }
                                }
                            }
                        }
                        if !matches {
                            if loadedState.addAssociated(entry: .IntermediateMessageEntry(message, nil, nil)) {
                                hasChanges = true
                            }
                        }
                    case let .Remove(indicesAndTags):
                        for (index, _) in indicesAndTags {
                            if self.namespaces.contains(index.id.namespace) {
                                if loadedState.remove(index: index) {
                                    hasChanges = true
                                }
                            }
                        }
                    case let .UpdateEmbeddedMedia(index, buffer):
                        if self.namespaces.contains(index.id.namespace) {
                            if loadedState.updateEmbeddedMedia(index: index, buffer: buffer) {
                                hasChanges = true
                            }
                        }
                    case let .UpdateGroupInfos(groupInfos):
                        if loadedState.updateGroupInfo(mapping: groupInfos) {
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
                            }
                        }
                    case let .UpdateTimestamp(index, timestamp):
                        if loadedState.updateTimestamp(postbox: postbox, index: index, timestamp: timestamp) {
                            hasChanges = true
                        }
                    }
                }
            }
            for (key, holeOperations) in transaction.currentPeerHoleOperations {
                var matchesSpace = false
                if !isExternal {
                    switch key.space {
                    case .everywhere:
                        matchesSpace = unwrappedTag.isEmpty
                    case let .tag(tag):
                        if let currentTag = self.tag, currentTag == tag {
                            matchesSpace = true
                        }
                    }
                }
                if matchesSpace {
                    if holePeerIdsSet.contains(key.peerId) {
                        for operation in holeOperations {
                            switch operation {
                            case let .insert(range):
                                if loadedState.insertHole(space: PeerIdAndNamespace(peerId: key.peerId, namespace: key.namespace), range: range) {
                                    hasChanges = true
                                }
                            case let .remove(range):
                                if loadedState.removeHole(space: PeerIdAndNamespace(peerId: key.peerId, namespace: key.namespace), range: range) {
                                    hasChanges = true
                                }
                            }
                        }
                    }
                }
            }
            if !transaction.updatedMedia.isEmpty {
                if loadedState.updateMedia(updatedMedia: transaction.updatedMedia) {
                    hasChanges = true
                }
            }
        }
        
        if hasChanges {
            if case let .loading(loadingState) = self.state {
                let sampledState = loadingState.checkAndSample(postbox: postbox)
                switch sampledState {
                case let .ready(anchor, holes):
                    self.state = .loaded(HistoryViewLoadedState(anchor: anchor, tag: self.tag, appendMessagesFromTheSameGroup: self.appendMessagesFromTheSameGroup, namespaces: self.namespaces, statistics: self.orderStatistics, ignoreMessagesInTimestampRange: self.ignoreMessagesInTimestampRange, halfLimit: self.fillCount + 1, locations: self.peerIds, postbox: postbox, holes: holes))
                case .loadHole:
                    break
                }
            }
            self.sampledState = self.state.sample(postbox: postbox, clipHoles: self.clipHoles)
        }
        
        for operationSet in operations {
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
        }
        
        var updatedCachedPeerDataMessages = false
        var currentCachedPeerData: CachedPeerData?
        
        let additionalDatas = self.additionalDatas
        var updated = self.additionalDatas

        for i in 0 ..< additionalDatas.count {
            switch additionalDatas[i] {
            case let .cachedPeerData(peerId, currentData):
                currentCachedPeerData = currentData
                if let updatedData = transaction.currentUpdatedCachedPeerData[peerId] {
                    if currentData?.messageIds != updatedData.messageIds {
                        updatedCachedPeerDataMessages = true
                    }
                    currentCachedPeerData = updatedData
                    updated[i] = .cachedPeerData(peerId, updatedData)
                    hasChanges = true
                }
            case .cachedPeerDataMessages:
                break
            case let .message(id, currentMessages):
                let currentGroupingKey = currentMessages.first?.groupingKey
                var currentIds = [id]
                for message in currentMessages {
                    if message.id != id {
                        currentIds.append(message.id)
                    }
                }
                
                if let operations = transaction.currentOperationsByPeerId[id.peerId] {
                    var updateMessage = false
                    findOperation: for operation in operations {
                        switch operation {
                        case let .InsertMessage(message):
                            if message.id == id || (currentGroupingKey != nil && message.groupingKey == currentGroupingKey) {
                                updateMessage = true
                                break findOperation
                            }
                        case let .Remove(indices):
                            for (index, _) in indices {
                                if currentIds.contains(index.id) {
                                    updateMessage = true
                                    break findOperation
                                }
                            }
                        case let .UpdateEmbeddedMedia(index, _):
                            if currentIds.contains(index.id) {
                                updateMessage = true
                                break findOperation
                            }
                        case let .UpdateGroupInfos(dict):
                            for id in currentIds {
                                if dict[id] != nil {
                                    updateMessage = true
                                    break findOperation
                                }
                            }
                        case let .UpdateTimestamp(index, _):
                            if currentIds.contains(index.id) {
                                updateMessage = true
                                break findOperation
                            }
                        case .UpdateReadState:
                            break
                        }
                    }
                    if updateMessage {
                        let messages = postbox.getMessageGroup(at: id) ?? []
                        updated[i] = .message(id, messages)
                        hasChanges = true
                    }
                }
            case let .peerChatState(peerId, _):
                if transaction.currentUpdatedPeerChatStates.contains(peerId) {
                    updated[i] = .peerChatState(peerId, postbox.peerChatStateTable.get(peerId)?.getLegacy() as? PeerChatState)
                    hasChanges = true
                }
            case .totalUnreadState:
                break
            case .peerNotificationSettings:
                break
            case let .cacheEntry(entryId, _):
                if transaction.updatedCacheEntryKeys.contains(entryId) {
                    updated[i] = .cacheEntry(entryId, postbox.retrieveItemCacheEntry(id: entryId))
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
                        updated[i] = .peerIsContact(peerId, value)
                        hasChanges = true
                    }
                }
            case let .peer(peerId, _):
                if let peer = transaction.currentUpdatedPeers[peerId] {
                    updated[i] = .peer(peerId, peer)
                    hasChanges = true
                }
            }
        }
        if let cachedData = currentCachedPeerData, !cachedData.messageIds.isEmpty {
            for i in 0 ..< additionalDatas.count {
                switch additionalDatas[i] {
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
            for i in 0 ..< additionalDatas.count {
                switch additionalDatas[i] {
                case let .cachedPeerDataMessages(peerId, _):
                    var messages: [MessageId: Message] = [:]
                    if let cachedData = currentCachedPeerData {
                        for id in cachedData.messageIds {
                            if let message = postbox.getMessage(id) {
                                messages[id] = message
                            }
                        }
                    }
                    updated[i] = .cachedPeerDataMessages(peerId, messages)
                default:
                    break
                }
            }
        }
        
        self.additionalDatas = updated
        
        if !transaction.currentPeerHoleOperations.isEmpty {
            var holePeerIdsSet: [PeerId] = []
            var threadId: Int64?
            switch self.peerIds {
            case let .single(peerId, threadIdValue):
                holePeerIdsSet.append(peerId)
                threadId = threadIdValue
            case let .associated(peerId, associatedId):
                holePeerIdsSet.append(peerId)
                if let associatedId = associatedId {
                    holePeerIdsSet.append(associatedId.peerId)
                }
            case .external:
                break
            }
            let space: MessageHistoryHoleSpace = self.tag.flatMap(MessageHistoryHoleSpace.tag) ?? .everywhere
            for key in transaction.currentPeerHoleOperations.keys {
                if holePeerIdsSet.contains(key.peerId) && threadId == key.threadId && key.space == space {
                    hasChanges = true
                }
            }
        }
        
        if hasChanges {
            self.render(postbox: postbox)
        }
        
        return hasChanges
    }
    
    private func render(postbox: PostboxImpl) {
        for namespace in self.topTaggedMessages.keys {
            if let entry = self.topTaggedMessages[namespace]!, case let .intermediate(message) = entry {
                let item: MessageHistoryTopTaggedMessage? = .message(postbox.messageHistoryTable.renderMessage(message, peerTable: postbox.peerTable, threadIndexTable: postbox.messageHistoryThreadIndexTable))
                self.topTaggedMessages[namespace] = item
            }
        }
    }
    
    func firstHole() -> (MessageHistoryViewHole, MessageHistoryViewRelativeHoleDirection, Int, Int64?)? {
        switch self.sampledState {
        case let .loading(loadingSample):
            switch loadingSample {
            case .ready:
                return nil
            case let .loadHole(peerId, namespace, _, threadId, id):
                return (.peer(MessageHistoryViewPeerHole(peerId: peerId, namespace: namespace, threadId: threadId)), .aroundId(MessageId(peerId: peerId, namespace: namespace, id: id)), self.fillCount * 2, self.userId)
            }
        case let .loaded(loadedSample):
            if let hole = loadedSample.hole {
                let direction: MessageHistoryViewRelativeHoleDirection
                if let endId = hole.endId {
                    direction = .range(start: MessageId(peerId: hole.peerId, namespace: hole.namespace, id: hole.startId), end: MessageId(peerId: hole.peerId, namespace: hole.namespace, id: endId))
                } else {
                    direction = .aroundId(MessageId(peerId: hole.peerId, namespace: hole.namespace, id: hole.startId))
                }
                return (.peer(MessageHistoryViewPeerHole(peerId: hole.peerId, namespace: hole.namespace, threadId: hole.threadId)), direction, self.fillCount * 2, self.userId)
            } else {
                return nil
            }
        }
    }
}

public final class MessageHistoryView {
    public let tagMask: MessageTags?
    public let namespaces: MessageIdNamespaces
    public let anchorIndex: MessageHistoryAnchorIndex
    public let earlierId: MessageIndex?
    public let laterId: MessageIndex?
    public let holeEarlier: Bool
    public let holeLater: Bool
    public let entries: [MessageHistoryEntry]
    public let maxReadIndex: MessageIndex?
    public let fixedReadStates: MessageHistoryViewReadState?
    public let transientReadStates: MessageHistoryViewReadState?
    public let topTaggedMessages: [Message]
    public let additionalData: [AdditionalMessageHistoryViewDataEntry]
    public let isLoading: Bool
    public let isLoadingEarlier: Bool
    public let isAddedToChatList: Bool
    
    public init(tagMask: MessageTags?, namespaces: MessageIdNamespaces, entries: [MessageHistoryEntry], holeEarlier: Bool, holeLater: Bool, isLoading: Bool) {
        self.tagMask = tagMask
        self.namespaces = namespaces
        self.anchorIndex = .lowerBound
        self.earlierId = nil
        self.laterId = nil
        self.holeEarlier = holeEarlier
        self.holeLater = holeLater
        self.entries = entries
        self.maxReadIndex = nil
        self.fixedReadStates = nil
        self.transientReadStates = nil
        self.topTaggedMessages = []
        self.additionalData = []
        self.isLoading = isLoading
        self.isLoadingEarlier = true
        self.isAddedToChatList = false
    }
    
    init(_ mutableView: MutableMessageHistoryView) {
        self.tagMask = mutableView.tag
        self.namespaces = mutableView.namespaces
        self.isAddedToChatList = mutableView.isAddedToChatList
        var entries: [MessageHistoryEntry]
        switch mutableView.sampledState {
        case .loading:
            self.isLoading = true
            self.anchorIndex = .upperBound
            entries = []
            self.holeEarlier = true
            self.holeLater = true
            self.earlierId = nil
            self.laterId = nil
            self.isLoadingEarlier = true
        case let .loaded(state):
            var isLoading = false
            var isLoadingEarlier = false
            switch state.anchor {
            case .lowerBound:
                self.anchorIndex = .lowerBound
            case .upperBound:
                self.anchorIndex = .upperBound
            case let .index(index):
                self.anchorIndex = .message(index)
            }
            self.holeEarlier = state.holesToLower
            self.holeLater = state.holesToHigher
            if state.entries.isEmpty && state.hole != nil {
                isLoading = true
            }
            if state.entries.count <= 1 && state.hole != nil {
                isLoadingEarlier = true
            }
            self.isLoadingEarlier = isLoadingEarlier
            entries = []
            if let transientReadStates = mutableView.transientReadStates, case let .peer(states) = transientReadStates {
                for entry in state.entries {
                    if mutableView.namespaces.contains(entry.message.id.namespace) {
                        let read: Bool
                        if entry.message.flags.contains(.Incoming) {
                            read = false
                        } else if let readState = states[entry.message.id.peerId] {
                            read = readState.isOutgoingMessageIndexRead(entry.message.index)
                        } else {
                            read = false
                        }
                        entries.append(MessageHistoryEntry(message: entry.message, isRead: read, location: entry.location, monthLocation: entry.monthLocation, attributes: entry.attributes))
                    }
                }
            } else {
                for entry in state.entries {
                    if mutableView.namespaces.contains(entry.message.id.namespace) {
                        entries.append(MessageHistoryEntry(message: entry.message, isRead: false, location: entry.location, monthLocation: entry.monthLocation, attributes: entry.attributes))
                    }
                }
            }
            assert(Set(entries.map({ $0.message.stableId })).count == entries.count)
            if !entries.isEmpty {
                let anchorIndex = binaryIndexOrLower(entries, state.anchor)
                let lowerOrEqualThanAnchorCount = anchorIndex + 1
                let higherThanAnchorCount = entries.count - anchorIndex - 1
                
                if higherThanAnchorCount > mutableView.fillCount {
                    self.laterId = entries[entries.count - 1].index
                    entries.removeLast()
                } else {
                    self.laterId = nil
                }
                
                if lowerOrEqualThanAnchorCount > mutableView.fillCount {
                    self.earlierId = entries[0].index
                    entries.removeFirst()
                } else {
                    self.earlierId = nil
                }
            } else {
                self.earlierId = nil
                self.laterId = nil
                if state.holesToLower || state.holesToHigher {
                    isLoading = true
                }
            }
            self.isLoading = isLoading
        }
        
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
        
        self.fixedReadStates = mutableView.combinedReadStates
        self.transientReadStates = mutableView.transientReadStates
        
        switch mutableView.peerIds {
        case .single, .associated:
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
                        for entry in entries {
                            peerIds.insert(entry.index.id.peerId)
                        }
                        for peerId in peerIds {
                            if let combinedReadState = states[peerId] {
                                for (namespace, state) in combinedReadState.states {
                                    var maxNamespaceIndex: MessageIndex?
                                    var index = entries.count - 1
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
                                                maxNamespaceIndex = entry.index.peerLocalPredecessor()
                                                break
                                            }
                                            index += 1
                                        }
                                    }
                                    if let _ = maxNamespaceIndex , index + 1 < entries.count {
                                        for i in index + 1 ..< entries.count {
                                            if entries[i].message.flags.intersection(.IsIncomingMask).isEmpty {
                                                maxNamespaceIndex = entries[i].message.index
                                            } else {
                                                break
                                            }
                                        }
                                    }
                                    if let maxNamespaceIndex = maxNamespaceIndex, maxIndex == nil || maxIndex! < maxNamespaceIndex {
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
        case let .external(input):
            if let maxReadMessageId = input.maxReadIncomingMessageId {
                var maxIndex: MessageIndex?
                
                let hasUnread = true
                if hasUnread {
                    var peerIds = Set<PeerId>()
                    for entry in entries {
                        peerIds.insert(entry.index.id.peerId)
                    }
                    for peerId in peerIds {
                        if peerId != maxReadMessageId.peerId {
                            continue
                        }
                        let namespace = maxReadMessageId.namespace
                        
                        var maxNamespaceIndex: MessageIndex?
                        var index = entries.count - 1
                        for entry in entries.reversed() {
                            if entry.index.id.peerId == peerId && entry.index.id.namespace == namespace && entry.index.id <= maxReadMessageId {
                                maxNamespaceIndex = entry.index
                                break
                            }
                            index -= 1
                        }
                        if maxNamespaceIndex == nil && index == -1 && entries.count != 0 {
                            index = 0
                            for entry in entries {
                                if entry.index.id.peerId == peerId && entry.index.id.namespace == namespace {
                                    maxNamespaceIndex = entry.index.peerLocalPredecessor()
                                    break
                                }
                                index += 1
                            }
                        }
                        if let _ = maxNamespaceIndex , index + 1 < entries.count {
                            for i in index + 1 ..< entries.count {
                                if entries[i].message.flags.intersection(.IsIncomingMask).isEmpty {
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
                self.maxReadIndex = maxIndex
            } else {
                self.maxReadIndex = nil
            }
        }
        
        self.entries = entries
    }
    
    public init(base: MessageHistoryView, fixed combinedReadStates: MessageHistoryViewReadState?, transient transientReadStates: MessageHistoryViewReadState?) {
        self.tagMask = base.tagMask
        self.namespaces = base.namespaces
        self.anchorIndex = base.anchorIndex
        self.earlierId = base.earlierId
        self.laterId = base.laterId
        self.holeEarlier = base.holeEarlier
        self.holeLater = base.holeLater
        self.entries = base.entries
        self.fixedReadStates = combinedReadStates
        self.transientReadStates = transientReadStates
        self.topTaggedMessages = base.topTaggedMessages
        self.additionalData = base.additionalData
        self.isLoading = base.isLoading
        self.isLoadingEarlier = base.isLoadingEarlier
        self.isAddedToChatList = base.isAddedToChatList
        
        if let combinedReadStates = combinedReadStates {
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
                    for entry in entries {
                        peerIds.insert(entry.index.id.peerId)
                    }
                    for peerId in peerIds {
                        if let combinedReadState = states[peerId] {
                            for (namespace, state) in combinedReadState.states {
                                var maxNamespaceIndex: MessageIndex?
                                var index = entries.count - 1
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
                                            maxNamespaceIndex = entry.index.peerLocalPredecessor()
                                            break
                                        }
                                        index += 1
                                    }
                                }
                                if let _ = maxNamespaceIndex , index + 1 < entries.count {
                                    for i in index + 1 ..< entries.count {
                                        if entries[i].message.flags.intersection(.IsIncomingMask).isEmpty {
                                            maxNamespaceIndex = entries[i].message.index
                                        } else {
                                            break
                                        }
                                    }
                                }
                                if let maxNamespaceIndex = maxNamespaceIndex, maxIndex == nil || maxIndex! < maxNamespaceIndex {
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
