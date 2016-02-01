import Foundation

public enum ChatListEntry: Comparable {
    case MessageEntry(Message)
    case Nothing(MessageIndex)
    
    public var index: MessageIndex {
        switch self {
            case let .MessageEntry(message):
                return MessageIndex(message)
            case let .Nothing(index):
                return index
        }
    }
}

public func ==(lhs: ChatListEntry, rhs: ChatListEntry) -> Bool {
    return lhs.index == rhs.index
}

public func <(lhs: ChatListEntry, rhs: ChatListEntry) -> Bool {
    return lhs.index < rhs.index
}

enum MutableChatListEntry {
    case IntermediateMessageEntry(IntermediateMessage)
    case MessageEntry(Message)
    case Nothing(MessageIndex)
    
    var index: MessageIndex {
        switch self {
            case let .IntermediateMessageEntry(message):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .MessageEntry(message):
                return MessageIndex(message)
            case let .Nothing(index):
                return index
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
    private var earlier: MutableChatListEntry?
    private var later: MutableChatListEntry?
    private var entries: [MutableChatListEntry]
    private var count: Int
    
    init(earlier: MutableChatListEntry?, entries: [MutableChatListEntry], later: MutableChatListEntry?, count: Int) {
        self.earlier = earlier
        self.entries = entries
        self.later = later
        self.count = count
    }
    
    func replay(operations: [ChatListOperation], context: MutableChatListViewReplayContext) -> Bool {
        var hasChanges = false
        for operation in operations {
            switch operation {
                case let .InsertMessage(message):
                    if self.add(.IntermediateMessageEntry(message)) {
                        hasChanges = true
                    }
                case let .InsertNothing(index):
                    if self.add(.Nothing(index)) {
                        hasChanges = true
                    }
                case let .Remove(indices):
                    if self.remove(Set(indices), context: context) {
                        hasChanges = true
                    }
            }
        }
        return hasChanges
    }
    
    func add(entry: MutableChatListEntry) -> Bool {
        if self.entries.count == 0 {
            self.entries.append(entry)
            return true
        } else {
            let first = self.entries[self.entries.count - 1].index
            let last = self.entries[0].index
            
            var next: MessageIndex?
            if let later = self.later {
                next = later.index
            }
            
            let index = entry.index
            
            if index < last {
                if self.earlier == nil || self.earlier!.index < index {
                    if self.entries.count < self.count {
                        self.entries.insert(entry, atIndex: 0)
                    } else {
                        self.earlier = entry
                    }
                    return true
                } else {
                    return false
                }
            } else if index > first {
                if next != nil && index > next! {
                    if self.later == nil || self.later!.index > index {
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
                        self.entries.removeAtIndex(0)
                    }
                    return true
                }
            } else if index != last && index != first {
                var i = self.entries.count
                while i >= 1 {
                    if self.entries[i - 1].index < index {
                        break
                    }
                    i--
                }
                self.entries.insert(entry, atIndex: i)
                if self.entries.count > self.count {
                    self.earlier = self.entries[0]
                    self.entries.removeAtIndex(0)
                }
                return true
            } else {
                return false
            }
        }
    }
    
    func remove(indices: Set<MessageIndex>, context: MutableChatListViewReplayContext) -> Bool {
        var hasChanges = false
        if let earlier = self.earlier where indices.contains(earlier.index) {
            context.invalidEarlier = true
            hasChanges = true
        }
        
        if let later = self.later where indices.contains(later.index) {
            context.invalidLater = true
            hasChanges = true
        }
        
        if self.entries.count != 0 {
            var i = self.entries.count - 1
            while i >= 0 {
                if indices.contains(self.entries[i].index) {
                    self.entries.removeAtIndex(i)
                    context.removedEntries = true
                    hasChanges = true
                }
                i--
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
            addedEntries.sortInPlace({ $0.index < $1.index })
            var i = addedEntries.count - 1
            while i >= 1 {
                if addedEntries[i].index.id == addedEntries[i - 1].index.id {
                    addedEntries.removeAtIndex(i)
                }
                i--
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
                    i--
                }
            }
            
            self.later = nil
            if anchorIndex + 1 < addedEntries.count {
                self.later = addedEntries[anchorIndex + 1]
            }
            
            i = anchorIndex
            while i >= 0 && i > anchorIndex - self.count {
                self.entries.insert(addedEntries[i], atIndex: 0)
                i--
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
    
    func updatePeers(peers: [PeerId: Peer]) -> Bool {
        var hasChanges = false
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
    
    func render(renderMessage: IntermediateMessage -> Message) {
        for i in 0 ..< self.entries.count {
            if case let .IntermediateMessageEntry(message) = self.entries[i] {
                self.entries[i] = .MessageEntry(renderMessage(message))
            }
        }
    }
}

public final class ChatListView {
    public let entries: [ChatListEntry]
    
    init(_ mutableView: MutableChatListView) {
        var entries: [ChatListEntry] = []
        for entry in mutableView.entries {
            switch entry {
                case let .MessageEntry(message):
                    entries.append(.MessageEntry(message))
                case let .Nothing(index):
                    entries.append(.Nothing(index))
                case .IntermediateMessageEntry:
                    assertionFailure()
            }
        }
        self.entries = entries
    }
}
