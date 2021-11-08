import Foundation

private enum InternalGlobalMessageTagsEntry: Comparable {
    case intermediateMessage(IntermediateMessage)
    case message(Message)
    case hole(MessageIndex)
    
    var index: MessageIndex {
        switch self {
            case let .intermediateMessage(message):
                return message.index
            case let .message(message):
                return message.index
            case let .hole(index):
                return index
        }
    }
    
    static func ==(lhs: InternalGlobalMessageTagsEntry, rhs: InternalGlobalMessageTagsEntry) -> Bool {
        switch lhs {
            case let .intermediateMessage(lhsMessage):
                if case let .intermediateMessage(rhsMessage) = rhs {
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    if lhsMessage.index != rhsMessage.index {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .message(lhsMessage):
                if case let .message(rhsMessage) = rhs {
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    if lhsMessage.index != rhsMessage.index {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .hole(index):
                if case .hole(index) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: InternalGlobalMessageTagsEntry, rhs: InternalGlobalMessageTagsEntry) -> Bool {
        return lhs.index < rhs.index
    }
}

public enum GlobalMessageTagsEntry {
    case message(Message)
    case hole(MessageIndex)
    
    public var index: MessageIndex {
        switch self {
            case let .message(message):
                return message.index
            case let .hole(index):
                return index
        }
    }
}

final class MutableGlobalMessageTagsViewReplayContext {
    var invalidEarlier: Bool = false
    var invalidLater: Bool = false
    var removedEntries: Bool = false
    
    func empty() -> Bool {
        return !self.removedEntries && !invalidEarlier && !invalidLater
    }
}

final class MutableGlobalMessageTagsView: MutablePostboxView {
    private let globalTag: GlobalMessageTags
    private let position: MessageIndex
    private let count: Int
    private let groupingPredicate: ((Message, Message) -> Bool)?
    
    fileprivate var entries: [InternalGlobalMessageTagsEntry]
    fileprivate var earlier: MessageIndex?
    fileprivate var later: MessageIndex?
    
    init(postbox: PostboxImpl, globalTag: GlobalMessageTags, position: MessageIndex, count: Int, groupingPredicate: ((Message, Message) -> Bool)?) {
        self.globalTag = globalTag
        self.position = position
        self.count = count
        self.groupingPredicate = groupingPredicate
        
        let (entries, lower, upper) = postbox.messageHistoryTable.entriesAround(globalTagMask: globalTag, index: position, count: count)
        
        self.entries = entries.map { entry -> InternalGlobalMessageTagsEntry in
            switch entry {
                case let .message(message):
                    return .intermediateMessage(message)
                case let .hole(index):
                    return .hole(index)
            }
        }
        self.earlier = lower
        self.later = upper
        
        self.render(postbox: postbox)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var hasChanges = false
        
        let context = MutableGlobalMessageTagsViewReplayContext()
        
        var wasSingleHole = false
        if self.entries.count == 1, case .hole = self.entries[0] {
            wasSingleHole = true
        }
        
        for operation in transaction.currentGlobalTagsOperations {
            switch operation {
            case let .insertMessage(tags, message):
                if (self.globalTag.rawValue & tags.rawValue) != 0 {
                    if self.add(.intermediateMessage(message)) {
                        hasChanges = true
                    }
                }
            case let .insertHole(tags, index):
                if (self.globalTag.rawValue & tags.rawValue) != 0 {
                    if self.add(.hole(index)) {
                        hasChanges = true
                    }
                }
            case let .remove(tagsAndIndices):
                var indices = Set<MessageIndex>()
                for (tags, index) in tagsAndIndices {
                    if (self.globalTag.rawValue & tags.rawValue) != 0 {
                        indices.insert(index)
                    }
                }
                if !indices.isEmpty {
                    if self.remove(indices, context: context) {
                        hasChanges = true
                    }
                }
            case let .updateTimestamp(tags, previousIndex, updatedTimestamp):
                if (self.globalTag.rawValue & tags.rawValue) != 0 {
                    inner: for i in 0 ..< self.entries.count {
                        let entry = self.entries[i]
                        if entry.index == previousIndex {
                            let updatedIndex = MessageIndex(id: entry.index.id, timestamp: updatedTimestamp)
                            if self.remove(Set([entry.index]), context: context) {
                                hasChanges = true
                            }
                            switch entry {
                            case .hole:
                                if self.add(.hole(updatedIndex)) {
                                    hasChanges = true
                                }
                            case let .intermediateMessage(message):
                                if self.add(.intermediateMessage(IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, threadId: message.threadId, timestamp: updatedTimestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: message.embeddedMediaData, referencedMedia: message.referencedMedia))) {
                                    hasChanges = true
                                }
                            case let .message(message):
                                if self.add(.message(Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, threadId: message.threadId, timestamp: updatedTimestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: message.peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds))) {
                                    hasChanges = true
                                }
                            }
                            break inner
                        }
                    }
                }
            }
        }
        
        if hasChanges || !context.empty() {
            if wasSingleHole {
                let (entries, lower, upper) = postbox.messageHistoryTable.entriesAround(globalTagMask: self.globalTag, index: self.position, count: self.count)
                
                self.entries = entries.map { entry -> InternalGlobalMessageTagsEntry in
                    switch entry {
                    case let .message(message):
                        return .intermediateMessage(message)
                    case let .hole(index):
                        return .hole(index)
                    }
                }
                self.earlier = lower
                self.later = upper
            }
            
            self.complete(postbox: postbox, context: context)
            self.render(postbox: postbox)
            
            self.render(postbox: postbox)
        }
        
        return hasChanges
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        /*let (entries, lower, upper) = postbox.messageHistoryTable.entriesAround(globalTagMask: globalTag, index: position, count: count)

        self.entries = entries.map { entry -> InternalGlobalMessageTagsEntry in
            switch entry {
                case let .message(message):
                    return .intermediateMessage(message)
                case let .hole(index):
                    return .hole(index)
            }
        }
        self.earlier = lower
        self.later = upper

        self.render(postbox: postbox)

        return true*/
        return false
    }
    
    private func add(_ entry: InternalGlobalMessageTagsEntry) -> Bool {
        if self.entries.count == 0 {
            self.entries.append(entry)
            return true
        } else {
            let first = self.entries[self.entries.count - 1]
            let last = self.entries[0]
            
            let next = self.later
            
            if entry.index < last.index {
                if self.earlier == nil || self.earlier! < entry.index {
                    if self.entries.count < self.count {
                        self.entries.insert(entry, at: 0)
                    } else {
                        self.earlier = entry.index
                    }
                    return true
                } else {
                    return false
                }
            } else if entry.index > first.index {
                if next != nil && entry.index > next! {
                    if self.later == nil || self.later! > entry.index {
                        if self.entries.count < self.count {
                            self.entries.append(entry)
                        } else {
                            self.later = entry.index
                        }
                        return true
                    } else {
                        return false
                    }
                } else {
                    self.entries.append(entry)
                    if self.entries.count > self.count {
                        self.earlier = self.entries[0].index
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
                    self.earlier = self.entries[0].index
                    self.entries.remove(at: 0)
                }
                return true
            } else {
                return false
            }
        }
    }
    
    private func remove(_ indices: Set<MessageIndex>, context: MutableGlobalMessageTagsViewReplayContext) -> Bool {
        var hasChanges = false
        if let earlier = self.earlier, indices.contains(earlier) {
            context.invalidEarlier = true
            hasChanges = true
        }
        
        if let later = self.later , indices.contains(later) {
            context.invalidLater = true
            hasChanges = true
        }
        
        if self.entries.count != 0 {
            var i = self.entries.count - 1
            while i >= 0 {
                if indices.contains(self.entries[i].index) {
                    self.entries.remove(at: i)
                    context.removedEntries = true
                    hasChanges = true
                }
                i -= 1
            }
        }
        
        return hasChanges
    }
    
    private func complete(postbox: PostboxImpl, context: MutableGlobalMessageTagsViewReplayContext) {
        if context.removedEntries {
            self.completeWithReset(postbox: postbox)
        } else {
            if context.invalidEarlier {
                var earlyId: MessageIndex?
                let i = 0
                if i < self.entries.count {
                    earlyId = self.entries[i].index
                }
                
                let earlierEntries = postbox.messageHistoryTable.earlierEntries(globalTagMask: self.globalTag, index: earlyId, count: 1).map { entry -> InternalGlobalMessageTagsEntry in
                    switch entry {
                        case let .message(message):
                            return .intermediateMessage(message)
                        case let .hole(index):
                            return .hole(index)
                    }
                }
                self.earlier = earlierEntries.first?.index
            }
            
            if context.invalidLater {
                var laterId: MessageIndex?
                let i = self.entries.count - 1
                if i >= 0 {
                    laterId = self.entries[i].index
                }
                
                let laterEntries = postbox.messageHistoryTable.laterEntries(globalTagMask: self.globalTag, index: laterId, count: 1).map { entry -> InternalGlobalMessageTagsEntry in
                    switch entry {
                        case let .message(message):
                            return .intermediateMessage(message)
                        case let .hole(index):
                            return .hole(index)
                    }
                }
                self.later = laterEntries.first?.index
            }
        }
    }
    
    private func completeWithReset(postbox: PostboxImpl) {
        var addedEntries: [InternalGlobalMessageTagsEntry] = []
        
        var latestAnchor: MessageIndex?
        if let last = self.entries.last {
            latestAnchor = last.index
        }
        
        if latestAnchor == nil {
            if let later = self.later {
                latestAnchor = later
            }
        }
        
        if let later = self.later {
            addedEntries += postbox.messageHistoryTable.laterEntries(globalTagMask: self.globalTag, index: later.globalPredecessor(), count: self.count).map { entry -> InternalGlobalMessageTagsEntry in
                switch entry {
                    case let .message(message):
                        return .intermediateMessage(message)
                    case let .hole(index):
                        return .hole(index)
                }
            }
        }
        if let earlier = self.earlier {
            addedEntries += postbox.messageHistoryTable.earlierEntries(globalTagMask: self.globalTag, index: earlier.globalSuccessor(), count: self.count).map { entry -> InternalGlobalMessageTagsEntry in
                switch entry {
                    case let .message(message):
                        return .intermediateMessage(message)
                    case let .hole(index):
                        return .hole(index)
                }
            }
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
        
        /*let indices = self.groupedIndices(addedEntries)
        
        if indices.count > self.count {
            
        } else {
            self.later = nil
            self.earlier = nil
            self.entries = addedEntries
        }*/
        
        self.later = nil
        if anchorIndex + 1 < addedEntries.count {
            self.later = addedEntries[anchorIndex + 1].index
        }
        
        i = anchorIndex
        while i >= 0 && i > anchorIndex - self.count {
            self.entries.insert(addedEntries[i], at: 0)
            i -= 1
        }
        
        self.earlier = nil
        if anchorIndex - self.count >= 0 {
            self.earlier = addedEntries[anchorIndex - self.count].index
        }
    }
    
    private func groupedIndices(_ entries: [InternalGlobalMessageTagsEntry]) -> [[Int]] {
        if entries.isEmpty {
            return []
        }
        if let groupingPredicate = self.groupingPredicate {
            var result: [[Int]] = [[0]]
            for i in 1 ..< entries.count {
                switch entries[i] {
                    case .hole:
                        result.append([i])
                    case let .message(message):
                        switch entries[i - 1] {
                            case .hole:
                                result.append([i])
                            case let .message(previousMessage):
                                if !groupingPredicate(message, previousMessage) {
                                    result.append([i])
                                } else {
                                    result[result.count - 1].append(i)
                                }
                            case .intermediateMessage:
                                assertionFailure()
                                result.append([i])
                        }
                    case .intermediateMessage:
                        assertionFailure()
                        result.append([i])
                }
            }
            return result
        } else {
            return (0 ..< entries.count).map { [$0] }
        }
    }
    
    private func render(postbox: PostboxImpl) {
        for i in 0 ..< self.entries.count {
            if case let .intermediateMessage(message) = self.entries[i] {
                self.entries[i] = .message(postbox.renderIntermediateMessage(message))
            }
        }
    }
    
    func immutableView() -> PostboxView {
        return GlobalMessageTagsView(self)
    }
}

public final class GlobalMessageTagsView: PostboxView {
    public let entries: [GlobalMessageTagsEntry]
    public let earlier: MessageIndex?
    public let later: MessageIndex?
    
    init(_ view: MutableGlobalMessageTagsView) {
        var entries: [GlobalMessageTagsEntry] = []
        for entry in view.entries {
            switch entry {
                case let .message(message):
                    entries.append(.message(message))
                case let .hole(index):
                    entries.append(.hole(index))
                case .intermediateMessage:
                    assertionFailure()
                    break
            }
        }
        self.entries = entries
        self.earlier = view.earlier
        self.later = view.later
    }
}
