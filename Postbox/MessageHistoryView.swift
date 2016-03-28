import Foundation

enum MutableMessageHistoryEntry {
    case IntermediateMessageEntry(IntermediateMessage)
    case MessageEntry(Message)
    case HoleEntry(MessageHistoryHole)
    
    var index: MessageIndex {
        switch self {
            case let .IntermediateMessageEntry(message):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .MessageEntry(message):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .HoleEntry(hole):
                return hole.maxIndex
        }
    }
}

public enum MessageHistoryEntry: Comparable {
    case MessageEntry(Message)
    case HoleEntry(MessageHistoryHole)
    
    public var index: MessageIndex {
        switch self {
            case let .MessageEntry(message):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .HoleEntry(hole):
                return hole.maxIndex
        }
    }
}

public func ==(lhs: MessageHistoryEntry, rhs: MessageHistoryEntry) -> Bool {
    switch lhs {
        case let .MessageEntry(lhsMessage):
            switch rhs {
                case .HoleEntry:
                    return false
                case let .MessageEntry(rhsMessage):
                    if MessageIndex(lhsMessage) == MessageIndex(rhsMessage) && lhsMessage.flags == rhsMessage.flags {
                        return true
                    }
                    return false
            }
        case let .HoleEntry(lhsHole):
            switch rhs {
                case let .HoleEntry(rhsHole):
                    return lhsHole == rhsHole
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

final class MutableMessageHistoryView {
    let tagMask: MessageTags?
    private let count: Int
    private var earlier: MutableMessageHistoryEntry?
    private var later: MutableMessageHistoryEntry?
    private var entries: [MutableMessageHistoryEntry]
    
    init(earlier: MutableMessageHistoryEntry?, entries: [MutableMessageHistoryEntry], later: MutableMessageHistoryEntry?, tagMask: MessageTags?, count: Int) {
        self.earlier = earlier
        self.entries = entries
        self.later = later
        self.tagMask = tagMask
        self.count = count
    }
    
    func replay(operations: [MessageHistoryOperation], context: MutableMessageHistoryViewReplayContext) -> Bool {
        let tagMask = self.tagMask
        let unwrappedTagMask: UInt32 = tagMask?.rawValue ?? 0
        
        var hasChanges = false
        for operation in operations {
            switch operation {
                case let .InsertHole(hole):
                    if tagMask == nil || (hole.tags & unwrappedTagMask) != 0 {
                        if self.add(.HoleEntry(hole)) {
                            hasChanges = true
                        }
                    }
                case let .InsertMessage(intermediateMessage):
                    if tagMask == nil || (intermediateMessage.tags.rawValue & unwrappedTagMask) != 0 {
                        if self.add(.IntermediateMessageEntry(intermediateMessage)) {
                            hasChanges = true
                        }
                    }
                case let .Remove(indices):
                    if self.remove(Set(indices), context: context) {
                        hasChanges = true
                    }
            }
        }
        return hasChanges
    }
    
    private func add(entry: MutableMessageHistoryEntry) -> Bool {
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
                    i -= 1
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
    
    private func remove(indices: Set<MessageIndex>, context: MutableMessageHistoryViewReplayContext) -> Bool {
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
                i -= 1
            }
        }
        
        return hasChanges
    }
    
    func updatePeers(peers: [PeerId: Peer]) -> Bool {
        return false
    }
    
    func complete(context: MutableMessageHistoryViewReplayContext, fetchEarlier: (MessageIndex?, Int) -> [MutableMessageHistoryEntry], fetchLater: (MessageIndex?, Int) -> [MutableMessageHistoryEntry]) {
        if context.removedEntries {
            var addedEntries: [MutableMessageHistoryEntry] = []
            
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
                self.entries.insert(addedEntries[i], atIndex: 0)
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
    
    func render(renderIntermediateMessage: IntermediateMessage -> Message) {
        if let earlier = self.earlier, case let .IntermediateMessageEntry(intermediateMessage) = earlier {
            self.earlier = .MessageEntry(renderIntermediateMessage(intermediateMessage))
        }
        if let later = self.later, case let .IntermediateMessageEntry(intermediateMessage) = later {
            self.later = .MessageEntry(renderIntermediateMessage(intermediateMessage))
        }
        
        for i in  0 ..< self.entries.count {
            if case let .IntermediateMessageEntry(intermediateMessage) = self.entries[i] {
                self.entries[i] = .MessageEntry(renderIntermediateMessage(intermediateMessage))
            }
        }
    }
    
    func firstHole() -> MessageHistoryHole? {
        for entry in self.entries.reverse() as ReverseCollection {
            if case let .HoleEntry(hole) = entry {
                return hole
            }
        }
        
        return nil
    }
}

public final class MessageHistoryView {
    public let earlierId: MessageIndex?
    public let laterId: MessageIndex?
    public let entries: [MessageHistoryEntry]
    
    init(_ mutableView: MutableMessageHistoryView) {
        var entries: [MessageHistoryEntry] = []
        for entry in mutableView.entries {
            switch entry {
                case let .HoleEntry(hole):
                    entries.append(.HoleEntry(hole))
                case let .MessageEntry(message):
                    entries.append(.MessageEntry(message))
                case .IntermediateMessageEntry:
                    assertionFailure("got IntermediateMessageEntry")
            }
        }
        self.entries = entries
        
        self.earlierId = mutableView.earlier?.index
        self.laterId = mutableView.later?.index
    }
}
