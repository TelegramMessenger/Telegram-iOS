import Foundation

public struct ChatListEntryMessageTagSummaryComponent {
    public let tag: MessageTags
    public let namespace: MessageId.Namespace
    
    public init(tag: MessageTags, namespace: MessageId.Namespace) {
        self.tag = tag
        self.namespace = namespace
    }
}

public struct ChatListEntryPendingMessageActionsSummaryComponent {
    public let type: PendingMessageActionType
    public let namespace: MessageId.Namespace
    
    public init(type: PendingMessageActionType, namespace: MessageId.Namespace) {
        self.type = type
        self.namespace = namespace
    }
}

public struct ChatListEntrySummaryComponents {
    public let tagSummary: ChatListEntryMessageTagSummaryComponent?
    public let actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent?
    
    public init(tagSummary: ChatListEntryMessageTagSummaryComponent? = nil, actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent? = nil) {
        self.tagSummary = tagSummary
        self.actionsSummary = actionsSummary
    }
}

public struct ChatListMessageTagSummaryInfo: Equatable {
    public let tagSummaryCount: Int32?
    public let actionsSummaryCount: Int32?
    
    public init(tagSummaryCount: Int32? = nil, actionsSummaryCount: Int32? = nil) {
        self.tagSummaryCount = tagSummaryCount
        self.actionsSummaryCount = actionsSummaryCount
    }
    
    public static func ==(lhs: ChatListMessageTagSummaryInfo, rhs: ChatListMessageTagSummaryInfo) -> Bool {
        return lhs.tagSummaryCount == rhs.tagSummaryCount && lhs.actionsSummaryCount == rhs.actionsSummaryCount
    }
}

public enum ChatListEntry: Comparable {
    case MessageEntry(ChatListIndex, Message?, CombinedPeerReadState?, PeerNotificationSettings?, PeerChatListEmbeddedInterfaceState?, RenderedPeer, ChatListMessageTagSummaryInfo)
    case HoleEntry(ChatListHole)
    
    public var index: ChatListIndex {
        switch self {
            case let .MessageEntry(index, _, _, _, _, _, _):
                return index
            case let .HoleEntry(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
        }
    }
}

public func ==(lhs: ChatListEntry, rhs: ChatListEntry) -> Bool {
    switch lhs {
        case let .MessageEntry(lhsIndex, lhsMessage, lhsReadState, lhsSettings, lhsEmbeddedState, lhsPeer, lhsInfo):
            switch rhs {
                case let .MessageEntry(rhsIndex, rhsMessage, rhsReadState, rhsSettings, rhsEmbeddedState, rhsPeer, rhsInfo):
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsReadState != rhsReadState {
                        return false
                    }
                    if lhsMessage?.stableVersion != rhsMessage?.stableVersion {
                        return false
                    }
                    if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                        if !lhsSettings.isEqual(to: rhsSettings) {
                            return false
                        }
                    } else if (lhsSettings != nil) != (rhsSettings != nil) {
                        return false
                    }
                    if let lhsEmbeddedState = lhsEmbeddedState, let rhsEmbeddedState = rhsEmbeddedState {
                        if !lhsEmbeddedState.isEqual(to: rhsEmbeddedState) {
                            return false
                        }
                    } else if (lhsEmbeddedState != nil) != (rhsEmbeddedState != nil) {
                        return false
                    }
                    if lhsPeer != rhsPeer {
                        return false
                    }
                    if lhsInfo != rhsInfo {
                        return false
                    }
                    return true
                default:
                    return false
            }
        case let .HoleEntry(hole):
            if case .HoleEntry(hole) = rhs {
                return true
            } else {
                return false
            }
    }
}

public func <(lhs: ChatListEntry, rhs: ChatListEntry) -> Bool {
    return lhs.index < rhs.index
}

enum MutableChatListEntry: Equatable {
    case IntermediateMessageEntry(ChatListIndex, IntermediateMessage?, CombinedPeerReadState?, PeerChatListEmbeddedInterfaceState?)
    case MessageEntry(ChatListIndex, Message?, CombinedPeerReadState?, PeerNotificationSettings?, PeerChatListEmbeddedInterfaceState?, RenderedPeer, ChatListMessageTagSummaryInfo)
    case HoleEntry(ChatListHole)
    
    var index: ChatListIndex {
        switch self {
            case let .IntermediateMessageEntry(index, _, _, _):
                return index
            case let .MessageEntry(index, _, _, _, _, _, _):
                return index
            case let .HoleEntry(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
        }
    }
}

func ==(lhs: MutableChatListEntry, rhs: MutableChatListEntry) -> Bool {
    if lhs.index != rhs.index {
        return false
    }
    
    switch lhs {
        case .IntermediateMessageEntry:
            switch rhs {
                case .IntermediateMessageEntry:
                    return true
                default:
                    return false
            }
        case .MessageEntry:
            switch rhs {
                case .MessageEntry:
                    return true
                default:
                    return false
            }
        case .HoleEntry:
            switch rhs {
                case .HoleEntry:
                    return true
                default:
                    return false
            }
    }
}

final class MutableChatListViewReplayContext {
    var invalidEarlier: Bool = false
    var invalidLater: Bool = false
    var removedEntries: Bool = false
    
    func empty() -> Bool {
        return !self.removedEntries && !invalidEarlier && !invalidLater
    }
}

private func updateMessagePeers(_ message: Message, updatedPeers: [PeerId: Peer]) -> Message? {
    var updated = false
    for (peerId, currentPeer) in message.peers {
        if let updatedPeer = updatedPeers[peerId], !arePeersEqual(currentPeer, updatedPeer) {
            updated = true
            break
        }
    }
    if updated {
        var peers = SimpleDictionary<PeerId, Peer>()
        for (peerId, currentPeer) in message.peers {
            if let updatedPeer = updatedPeers[peerId] {
                peers[peerId] = updatedPeer
            } else {
                peers[peerId] = currentPeer
            }
        }
        return Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds)
    }
    return nil
}

private func updatedRenderedPeer(_ renderedPeer: RenderedPeer, updatedPeers: [PeerId: Peer]) -> RenderedPeer? {
    var updated = false
    for (peerId, currentPeer) in renderedPeer.peers {
        if let updatedPeer = updatedPeers[peerId], !arePeersEqual(currentPeer, updatedPeer) {
            updated = true
            break
        }
    }
    if updated {
        var peers = SimpleDictionary<PeerId, Peer>()
        for (peerId, currentPeer) in renderedPeer.peers {
            if let updatedPeer = updatedPeers[peerId] {
                peers[peerId] = updatedPeer
            } else {
                peers[peerId] = currentPeer
            }
        }
        return RenderedPeer(peerId: renderedPeer.peerId, peers: peers)
    }
    return nil
}

final class MutableChatListView {
    private let summaryComponents: ChatListEntrySummaryComponents
    fileprivate var earlier: MutableChatListEntry?
    fileprivate var later: MutableChatListEntry?
    fileprivate var entries: [MutableChatListEntry]
    private var count: Int
    
    init(earlier: MutableChatListEntry?, entries: [MutableChatListEntry], later: MutableChatListEntry?, count: Int, summaryComponents: ChatListEntrySummaryComponents) {
        self.earlier = earlier
        self.entries = entries
        self.later = later
        self.count = count
        self.summaryComponents = summaryComponents
    }
    
    func refreshDueToExternalTransaction(fetchAroundChatEntries: (_ index: ChatListIndex, _ count: Int) -> (entries: [MutableChatListEntry], earlier: MutableChatListEntry?, later: MutableChatListEntry?)) -> Bool {
        var index = ChatListIndex.absoluteUpperBound
        if !self.entries.isEmpty && self.later != nil {
            index = self.entries[self.entries.count / 2].index
        }
        
        let (entries, earlier, later) = fetchAroundChatEntries(index, self.entries.count)
        
        if entries != self.entries || earlier != self.earlier || later != self.later {
            self.entries = entries
            self.earlier = earlier
            self.later = later
            return true
        } else {
            return false
        }
    }
    
    func replay(_ operations: [ChatListOperation], updatedPeerNotificationSettings: [PeerId: PeerNotificationSettings], updatedPeers: [PeerId: Peer], transaction: PostboxTransaction, context: MutableChatListViewReplayContext) -> Bool {
        var hasChanges = false
        for operation in operations {
            switch operation {
                case let .InsertEntry(index, message, combinedReadState, embeddedState):
                    if self.add(.IntermediateMessageEntry(index, message, combinedReadState, embeddedState)) {
                        hasChanges = true
                    }
                case let .InsertHole(index):
                    if self.add(.HoleEntry(index)) {
                        hasChanges = true
                    }
                case let .RemoveEntry(indices):
                    if self.remove(Set(indices), holes: false, context: context) {
                        hasChanges = true
                    }
                case let .RemoveHoles(indices):
                    if self.remove(Set(indices), holes: true, context: context) {
                        hasChanges = true
                    }
            }
        }
        if !updatedPeerNotificationSettings.isEmpty {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                    case let .MessageEntry(index, message, readState, _, embeddedState, peer, summaryInfo):
                        var notificationSettingsPeerId = peer.peerId
                        if let peer = peer.peers[peer.peerId], let associatedPeerId = peer.associatedPeerId {
                            notificationSettingsPeerId = associatedPeerId
                        }
                        if let settings = updatedPeerNotificationSettings[notificationSettingsPeerId] {
                            self.entries[i] = .MessageEntry(index, message, readState, settings, embeddedState, peer, summaryInfo)
                            hasChanges = true
                        }
                    default:
                        continue
                }
            }
        }
        if !updatedPeers.isEmpty {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                    case let .MessageEntry(index, message, readState, settings, embeddedState, peer, summaryInfo):
                        var updatedMessage: Message?
                        if let message = message {
                            updatedMessage = updateMessagePeers(message, updatedPeers: updatedPeers)
                        }
                        let updatedPeer = updatedRenderedPeer(peer, updatedPeers: updatedPeers)
                        if updatedMessage != nil || updatedPeer != nil {
                            self.entries[i] = .MessageEntry(index, updatedMessage ?? message, readState, settings, embeddedState, updatedPeer ?? peer, summaryInfo)
                            hasChanges = true
                        }
                    default:
                        continue
                }
            }
        }
        if !transaction.currentUpdatedMessageTagSummaries.isEmpty || !transaction.currentUpdatedMessageActionsSummaries.isEmpty {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                    case let .MessageEntry(index, message, readState, settings, embeddedState, peer, currentSummary):
                        var updatedTagSummaryCount: Int32?
                        var updatedActionsSummaryCount: Int32?
                        
                        if let tagSummary = self.summaryComponents.tagSummary {
                            let key = MessageHistoryTagsSummaryKey(tag: tagSummary.tag, peerId: index.messageIndex.id.peerId, namespace: tagSummary.namespace)
                            if let summary = transaction.currentUpdatedMessageTagSummaries[key] {
                                updatedTagSummaryCount = summary.count
                            }
                        }
                        
                        if let actionsSummary = self.summaryComponents.actionsSummary {
                            let key = PendingMessageActionsSummaryKey(type: actionsSummary.type, peerId: index.messageIndex.id.peerId, namespace: actionsSummary.namespace)
                            if let count = transaction.currentUpdatedMessageActionsSummaries[key] {
                                updatedActionsSummaryCount = count
                            }
                        }
                        
                        if updatedTagSummaryCount != nil || updatedActionsSummaryCount != nil {
                            let summaryInfo = ChatListMessageTagSummaryInfo(tagSummaryCount: updatedTagSummaryCount ?? currentSummary.tagSummaryCount, actionsSummaryCount: updatedActionsSummaryCount ?? currentSummary.actionsSummaryCount)
                            
                            self.entries[i] = .MessageEntry(index, message, readState, settings, embeddedState, peer, summaryInfo)
                            hasChanges = true
                        }
                    default:
                        continue
                }
            }
        }
        return hasChanges
    }
    
    func add(_ entry: MutableChatListEntry) -> Bool {
        if self.entries.count == 0 {
            self.entries.append(entry)
            return true
        } else {
            let first = self.entries[self.entries.count - 1]
            let last = self.entries[0]
            
            let next = self.later
            
            if entry.index < last.index {
                if self.earlier == nil || self.earlier!.index < entry.index {
                    if self.entries.count < self.count {
                        self.entries.insert(entry, at: 0)
                    } else {
                        self.earlier = entry
                    }
                    return true
                } else {
                    return false
                }
            } else if entry.index > first.index {
                if next != nil && entry.index > next!.index {
                    if self.later == nil || self.later!.index > entry.index {
                        if self.entries.count < self.count {
                            self.entries.append(entry)
                        } else {
                            self.later = entry
                        }
                        return true
                    } else {
                        return false
                    }
                } else {
                    self.entries.append(entry)
                    if self.entries.count > self.count {
                        self.earlier = self.entries[0]
                        self.entries.remove(at: 0)
                    }
                    return true
                }
            } else if entry != last && entry != first {
                var i = self.entries.count
                while i >= 1 {
                    if self.entries[i - 1].index < entry.index {
                        break
                    }
                    i -= 1
                }
                self.entries.insert(entry, at: i)
                if self.entries.count > self.count {
                    self.earlier = self.entries[0]
                    self.entries.remove(at: 0)
                }
                return true
            } else {
                return false
            }
        }
    }
    
    func remove(_ indices: Set<ChatListIndex>, holes: Bool, context: MutableChatListViewReplayContext) -> Bool {
        var hasChanges = false
        if let earlier = self.earlier , indices.contains(earlier.index) {
            var match = false
            switch earlier {
                case .HoleEntry:
                    match = holes
                case .IntermediateMessageEntry, .MessageEntry:
                    match = !holes
            }
            if match {
                context.invalidEarlier = true
                hasChanges = true
            }
        }
        
        if let later = self.later , indices.contains(later.index) {
            var match = false
            switch later {
                case .HoleEntry:
                    match = holes
                case .IntermediateMessageEntry, .MessageEntry:
                    match = !holes
            }
            if match {
                context.invalidLater = true
                hasChanges = true
            }
        }
        
        if self.entries.count != 0 {
            var i = self.entries.count - 1
            while i >= 0 {
                if indices.contains(self.entries[i].index) {
                    var match = false
                    switch self.entries[i] {
                        case .HoleEntry:
                            match = holes
                        case .IntermediateMessageEntry, .MessageEntry:
                            match = !holes
                    }
                    if match {
                        self.entries.remove(at: i)
                        context.removedEntries = true
                        hasChanges = true
                    }
                }
                i -= 1
            }
        }
        
        return hasChanges
    }
    
    func complete(context: MutableChatListViewReplayContext, fetchEarlier: (ChatListIndex?, Int) -> [MutableChatListEntry], fetchLater: (ChatListIndex?, Int) -> [MutableChatListEntry]) {
        if context.removedEntries {
            var addedEntries: [MutableChatListEntry] = []
            
            var latestAnchor: ChatListIndex?
            if let last = self.entries.last {
                latestAnchor = last.index
            }
            
            if latestAnchor == nil {
                if let later = self.later {
                    latestAnchor = later.index
                }
            }
            
            if let later = self.later {
                addedEntries += fetchLater(later.index.predecessor, self.count)
            }
            if let earlier = self.earlier {
                addedEntries += fetchEarlier(earlier.index.successor, self.count)
            }
            
            addedEntries += self.entries
            addedEntries.sort(by: { $0.index < $1.index })
            var i = addedEntries.count - 1
            while i >= 1 {
                if addedEntries[i].index.messageIndex.id == addedEntries[i - 1].index.messageIndex.id {
                    addedEntries.remove(at: i)
                }
                i -= 1
            }
            self.entries = []
            
            var anchorIndex = addedEntries.count - 1
            if let latestAnchor = latestAnchor {
                var i = addedEntries.count - 1
                while i >= 0 {
                    if addedEntries[i].index <= latestAnchor {
                        anchorIndex = i
                        break
                    }
                    i -= 1
                }
            }
            
            self.later = nil
            if anchorIndex + 1 < addedEntries.count {
                self.later = addedEntries[anchorIndex + 1]
            }
            
            i = anchorIndex
            while i >= 0 && i > anchorIndex - self.count {
                self.entries.insert(addedEntries[i], at: 0)
                i -= 1
            }
            
            self.earlier = nil
            if anchorIndex - self.count >= 0 {
                self.earlier = addedEntries[anchorIndex - self.count]
            }
        } else {
            if context.invalidEarlier {
                var earlyId: ChatListIndex?
                let i = 0
                if i < self.entries.count {
                    earlyId = self.entries[i].index
                }
                
                let earlierEntries = fetchEarlier(earlyId, 1)
                self.earlier = earlierEntries.first
            }
            
            if context.invalidLater {
                var laterId: ChatListIndex?
                let i = self.entries.count - 1
                if i >= 0 {
                    laterId = self.entries[i].index
                }
                
                let laterEntries = fetchLater(laterId, 1)
                self.later = laterEntries.first
            }
        }
    }
    
    func firstHole() -> ChatListHole? {
        for entry in self.entries {
            if case let .HoleEntry(hole) = entry {
                return hole
            }
        }
        
        return nil
    }
    
    func render(postbox: Postbox, renderMessage: (IntermediateMessage) -> Message, getPeer: (PeerId) -> Peer?, getPeerNotificationSettings: (PeerId) -> PeerNotificationSettings?) {
        for i in 0 ..< self.entries.count {
            switch self.entries[i] {
                case let .IntermediateMessageEntry(index, message, combinedReadState, embeddedState):
                    let renderedMessage: Message?
                    if let message = message {
                        renderedMessage = renderMessage(message)
                    } else {
                        renderedMessage = nil
                    }
                    var peers = SimpleDictionary<PeerId, Peer>()
                    var notificationSettings: PeerNotificationSettings?
                    if let peer = getPeer(index.messageIndex.id.peerId) {
                        peers[peer.id] = peer
                        if let associatedPeerId = peer.associatedPeerId {
                            if let associatedPeer = getPeer(associatedPeerId) {
                                peers[associatedPeer.id] = associatedPeer
                            }
                            notificationSettings = getPeerNotificationSettings(associatedPeerId)
                        } else {
                            notificationSettings = getPeerNotificationSettings(index.messageIndex.id.peerId)
                        }
                    }
                    
                    var tagSummaryCount: Int32?
                    var actionsSummaryCount: Int32?
                    
                    if let tagSummary = self.summaryComponents.tagSummary {
                        let key = MessageHistoryTagsSummaryKey(tag: tagSummary.tag, peerId: index.messageIndex.id.peerId, namespace: tagSummary.namespace)
                        if let summary = postbox.messageHistoryTagsSummaryTable.get(key) {
                            tagSummaryCount = summary.count
                        }
                    }
                    
                    if let actionsSummary = self.summaryComponents.actionsSummary {
                        let key = PendingMessageActionsSummaryKey(type: actionsSummary.type, peerId: index.messageIndex.id.peerId, namespace: actionsSummary.namespace)
                        actionsSummaryCount = postbox.pendingMessageActionsMetadataTable.getCount(.peerNamespaceAction(key.peerId, key.namespace, key.type))
                    }
                    
                    self.entries[i] = .MessageEntry(index, renderedMessage, combinedReadState, notificationSettings, embeddedState, RenderedPeer(peerId: index.messageIndex.id.peerId, peers: peers), ChatListMessageTagSummaryInfo(tagSummaryCount: tagSummaryCount, actionsSummaryCount: actionsSummaryCount))
                default:
                    break
            }
        }
    }
}

public final class ChatListView {
    public let entries: [ChatListEntry]
    public let earlierIndex: ChatListIndex?
    public let laterIndex: ChatListIndex?
    
    init(_ mutableView: MutableChatListView) {
        var entries: [ChatListEntry] = []
        for entry in mutableView.entries {
            switch entry {
                case let .MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo):
                    entries.append(.MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo))
                case let .HoleEntry(hole):
                    entries.append(.HoleEntry(hole))
                case .IntermediateMessageEntry:
                    assertionFailure()
            }
        }
        self.entries = entries
        self.earlierIndex = mutableView.earlier?.index
        self.laterIndex = mutableView.later?.index
    }
}
