import Foundation

public enum ChatListEntry: Comparable {
    case MessageEntry(MessageIndex, Message, CombinedPeerReadState?, PeerNotificationSettings?, PeerChatListEmbeddedInterfaceState?)
    case HoleEntry(ChatListHole)
    case Nothing(MessageIndex)
    
    public var index: MessageIndex {
        switch self {
            case let .MessageEntry(index, _, _, _, _):
                return index
            case let .HoleEntry(hole):
                return hole.index
            case let .Nothing(index):
                return index
        }
    }
}

public func ==(lhs: ChatListEntry, rhs: ChatListEntry) -> Bool {
    switch lhs {
        case let .MessageEntry(lhsIndex, lhsMessage, lhsReadState, lhsSettings, lhsEmbeddedState):
            switch rhs {
                case let .MessageEntry(rhsIndex, rhsMessage, rhsReadState, rhsSettings, rhsEmbeddedState):
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsReadState != rhsReadState {
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
        case let .Nothing(index):
            if case .Nothing(index) = rhs {
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
    case IntermediateMessageEntry(MessageIndex, IntermediateMessage, CombinedPeerReadState?, PeerNotificationSettings?, PeerChatListEmbeddedInterfaceState?)
    case MessageEntry(MessageIndex, Message, CombinedPeerReadState?, PeerNotificationSettings?, PeerChatListEmbeddedInterfaceState?)
    case HoleEntry(ChatListHole)
    case Nothing(MessageIndex)
    
    var index: MessageIndex {
        switch self {
            case let .IntermediateMessageEntry(index, _, _, _, _):
                return index
            case let .MessageEntry(index, _, _, _, _):
                return index
            case let .HoleEntry(hole):
                return hole.index
            case let .Nothing(index):
                return index
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
        case .Nothing:
            switch rhs {
                case .Nothing:
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

final class MutableChatListView {
    fileprivate var earlier: MutableChatListEntry?
    fileprivate var later: MutableChatListEntry?
    fileprivate var entries: [MutableChatListEntry]
    private var count: Int
    
    init(earlier: MutableChatListEntry?, entries: [MutableChatListEntry], later: MutableChatListEntry?, count: Int) {
        self.earlier = earlier
        self.entries = entries
        self.later = later
        self.count = count
    }
    
    func refreshDueToExternalTransaction(fetchAroundChatEntries: (_ index: MessageIndex, _ count: Int) -> (entries: [MutableChatListEntry], earlier: MutableChatListEntry?, later: MutableChatListEntry?)) -> Bool {
        var index = MessageIndex.absoluteUpperBound()
        if !self.entries.isEmpty {
            index = self.entries[self.entries.count / 2].index
        }
        
        var (entries, earlier, later) = fetchAroundChatEntries(index, self.entries.count)
        
        if entries != self.entries || earlier != self.earlier || later != self.later {
            self.entries = entries
            self.earlier = earlier
            self.later = later
            return true
        } else {
            return false
        }
    }
    
    func replay(_ operations: [ChatListOperation], updatedPeerNotificationSettings: [PeerId: PeerNotificationSettings], context: MutableChatListViewReplayContext) -> Bool {
        var hasChanges = false
        for operation in operations {
            switch operation {
                case let .InsertMessage(index, message, combinedReadState, embeddedState):
                    if self.add(.IntermediateMessageEntry(index, message, combinedReadState, nil, embeddedState)) {
                        hasChanges = true
                    }
                case let .InsertNothing(index):
                    if self.add(.Nothing(index)) {
                        hasChanges = true
                    }
                case let .InsertHole(index):
                    if self.add(.HoleEntry(index)) {
                        hasChanges = true
                    }
                case let .RemoveMessage(indices):
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
                    case let .IntermediateMessageEntry(index, message, readState, _, embeddedState):
                        if let settings = updatedPeerNotificationSettings[message.id.peerId] {
                            self.entries[i] = .IntermediateMessageEntry(index, message, readState, settings, embeddedState)
                            hasChanges = true
                        }
                    case let .MessageEntry(index, message, readState, _, embeddedState):
                        if let settings = updatedPeerNotificationSettings[message.id.peerId] {
                            self.entries[i] = .MessageEntry(index, message, readState, settings, embeddedState)
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
    
    func remove(_ indices: Set<MessageIndex>, holes: Bool, context: MutableChatListViewReplayContext) -> Bool {
        var hasChanges = false
        if let earlier = self.earlier , indices.contains(earlier.index) {
            var match = false
            switch earlier {
                case .HoleEntry:
                    match = holes
                case .IntermediateMessageEntry, .MessageEntry, .Nothing:
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
                case .IntermediateMessageEntry, .MessageEntry, .Nothing:
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
                        case .IntermediateMessageEntry, .MessageEntry, .Nothing:
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
    
    func complete(context: MutableChatListViewReplayContext, fetchEarlier: (MessageIndex?, Int) -> [MutableChatListEntry], fetchLater: (MessageIndex?, Int) -> [MutableChatListEntry]) {
        if context.removedEntries {
            var addedEntries: [MutableChatListEntry] = []
            
            var latestAnchor: MessageIndex?
            if let last = self.entries.last {
                latestAnchor = last.index
            }
            
            if latestAnchor == nil {
                if let later = self.later {
                    latestAnchor = later.index
                }
            }
            
            if let later = self.later {
                addedEntries += fetchLater(later.index.predecessor(), self.count)
            }
            if let earlier = self.earlier {
                addedEntries += fetchEarlier(earlier.index.successor(), self.count)
            }
            
            addedEntries += self.entries
            addedEntries.sort(by: { $0.index < $1.index })
            var i = addedEntries.count - 1
            while i >= 1 {
                if addedEntries[i].index.id == addedEntries[i - 1].index.id {
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
    
    func firstHole() -> ChatListHole? {
        for entry in self.entries {
            if case let .HoleEntry(hole) = entry {
                return hole
            }
        }
        
        return nil
    }
    
    func updatePeers(_ peers: [PeerId: Peer]) -> Bool {
        let hasChanges = false
        /*for i in 0 ..< self.entries.count {
            switch self.entries[i] {
                case let .MessageEntry(message):
                    var updatedAuthor: Peer?
                    if let author = message.author, let peer = peers[author.id] {
                        updatedAuthor = peer
                    }
                    
                    for peer in message.peers {
                        
                    }
                    
                    break
                default:
                    break
            }
        }*/
        return hasChanges
    }
    
    func render(_ renderMessage: (IntermediateMessage) -> Message, getPeerNotificationSettings: (PeerId) -> PeerNotificationSettings?) {
        for i in 0 ..< self.entries.count {
            switch self.entries[i] {
                case let .IntermediateMessageEntry(index, message, combinedReadState, notificationSettings, embeddedState):
                    let updatedNotificationSettings: PeerNotificationSettings?
                    if let notificationSettings = notificationSettings {
                        updatedNotificationSettings = notificationSettings
                    } else {
                        updatedNotificationSettings = getPeerNotificationSettings(message.id.peerId)
                    }
                    self.entries[i] = .MessageEntry(index, renderMessage(message), combinedReadState, updatedNotificationSettings, embeddedState)
                default:
                    break
            }
        }
    }
}

public final class ChatListView {
    public let entries: [ChatListEntry]
    public let earlierIndex: MessageIndex?
    public let laterIndex: MessageIndex?
    
    init(_ mutableView: MutableChatListView) {
        var entries: [ChatListEntry] = []
        for entry in mutableView.entries {
            switch entry {
                case let .MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState):
                    entries.append(.MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState))
                case let .Nothing(index):
                    entries.append(.Nothing(index))
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
