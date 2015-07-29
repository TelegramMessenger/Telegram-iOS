import Foundation

public final class MutableMessageView: CustomStringConvertible {
    public struct RemoveContext {
        var invalidEarlier: Set<MessageId.Namespace>
        var invalidLater: Set<MessageId.Namespace>
        var removedMessages: Bool
        
        init() {
            self.invalidEarlier = []
            self.invalidLater = []
            self.removedMessages = false
        }
        
        func empty() -> Bool {
            return !self.removedMessages && self.invalidEarlier.count == 0 && self.invalidLater.count == 0
        }
    }
    
    let namespaces: [MessageId.Namespace]
    let count: Int
    var earlier: [MessageId.Namespace : RenderedMessage] = [:]
    var later: [MessageId.Namespace : RenderedMessage] = [:]
    var messages: [RenderedMessage]
    
    public init(namespaces: [MessageId.Namespace], count: Int, earlier: [MessageId.Namespace : RenderedMessage], messages: [RenderedMessage], later: [MessageId.Namespace : RenderedMessage]) {
        self.namespaces = namespaces
        self.count = count
        self.earlier = earlier
        self.later = later
        self.messages = messages
    }
    
    public func add(message: RenderedMessage) -> Bool {
        if self.messages.count == 0 {
            self.messages.append(message)
            return true
        } else {
            let first = MessageIndex(self.messages[self.messages.count - 1].message)
            let last = MessageIndex(self.messages[0].message)
            
            var next: MessageIndex?
            for namespace in self.namespaces {
                if let message = later[namespace] {
                    let messageIndex = MessageIndex(message.message)
                    if next == nil || messageIndex < next! {
                        next = messageIndex
                    }
                }
            }
            
            let index = MessageIndex(message.message)
            
            if index < last {
                let earlierMessage = self.earlier[message.message.id.namespace]
                if earlierMessage == nil || earlierMessage!.message.id.id < message.message.id.id {
                    if self.messages.count < self.count {
                        self.messages.insert(message, atIndex: 0)
                    } else {
                        self.earlier[message.message.id.namespace] = message
                    }
                }
                
                return true
            } else if index > first {
                if next != nil && index > next! {
                    let laterMessage = self.later[message.message.id.namespace]
                    if laterMessage == nil || laterMessage!.message.id.id > message.message.id.id {
                        if self.messages.count < self.count {
                            self.messages.append(message)
                        } else {
                            self.later[message.message.id.namespace] = message
                        }
                    }
                } else {
                    self.messages.append(message)
                    if self.messages.count > self.count {
                        let earliest = self.messages[0]
                        self.earlier[earliest.message.id.namespace] = earliest
                        self.messages.removeAtIndex(0)
                    }
                }
                return true
            } else if index != last && index != first {
                var i = self.messages.count
                while i >= 1 {
                    if MessageIndex(self.messages[i - 1].message) < index {
                        break
                    }
                    i--
                }
                self.messages.insert(message, atIndex: i)
                if self.messages.count > self.count {
                    let earliest = self.messages[0]
                    self.earlier[earliest.message.id.namespace] = earliest
                    self.messages.removeAtIndex(0)
                }
                return true
            } else {
                return false
            }
        }
    }
    
    public func remove(ids: Set<MessageId>, context: RemoveContext? = nil) -> RemoveContext {
        var updatedContext = RemoveContext()
        if let context = context {
            updatedContext = context
        }
        
        for (_, message) in self.earlier {
            if ids.contains(message.message.id) {
                updatedContext.invalidEarlier.insert(message.message.id.namespace)
            }
        }

        for (_, message) in self.later {
            if ids.contains(message.message.id) {
                updatedContext.invalidLater.insert(message.message.id.namespace)
            }
        }
        
        if self.messages.count != 0 {
            var i = self.messages.count - 1
            while i >= 0 {
                if ids.contains(self.messages[i].message.id) {
                    self.messages.removeAtIndex(i)
                    updatedContext.removedMessages = true
                }
                i--
            }
        }
        
        return updatedContext
    }
    
    public func complete(context: RemoveContext, fetchEarlier: (MessageId.Namespace, MessageId.Id?, Int) -> [RenderedMessage], fetchLater: (MessageId.Namespace, MessageId.Id?, Int) -> [RenderedMessage]) {
        if context.removedMessages {
            var addedMessages: [RenderedMessage] = []
            
            var latestAnchor: MessageIndex?
            if let lastMessage = self.messages.last {
                latestAnchor = MessageIndex(lastMessage.message)
            }
            
            if latestAnchor == nil {
                for (_, message) in self.later {
                    let messageIndex = MessageIndex(message.message)
                    if latestAnchor == nil || latestAnchor! > messageIndex {
                        latestAnchor = messageIndex
                    }
                }
            }
            
            for namespace in self.namespaces {
                if let later = self.later[namespace] {
                    addedMessages += fetchLater(namespace, later.message.id.id - 1, self.count)
                }
                if let earlier = self.earlier[namespace] {
                    addedMessages += fetchEarlier(namespace, earlier.message.id.id + 1, self.count)
                }
            }
            
            addedMessages += self.messages
            addedMessages.sortInPlace({ MessageIndex($0.message) < MessageIndex($1.message) })
            var i = addedMessages.count - 1
            while i >= 1 {
                if addedMessages[i].message.id == addedMessages[i - 1].message.id {
                    addedMessages.removeAtIndex(i)
                }
                i--
            }
            self.messages = []
            
            var anchorIndex = addedMessages.count - 1
            if let latestAnchor = latestAnchor {
                var i = addedMessages.count - 1
                while i >= 0 {
                    if MessageIndex(addedMessages[i].message) <= latestAnchor {
                        anchorIndex = i
                        break
                    }
                    i--
                }
            }
            
            self.later.removeAll(keepCapacity: true)
            if anchorIndex + 1 < addedMessages.count {
                for namespace in self.namespaces {
                    var i = anchorIndex + 1
                    while i < addedMessages.count {
                        if addedMessages[i].message.id.namespace == namespace {
                            self.later[namespace] = addedMessages[i]
                            break
                        }
                        i++
                    }
                }
            }
            
            i = anchorIndex
            while i >= 0 && i > anchorIndex - self.count {
                self.messages.insert(addedMessages[i], atIndex: 0)
                i--
            }
            
            self.earlier.removeAll(keepCapacity: true)
            if anchorIndex - self.count >= 0 {
                for namespace in self.namespaces {
                    i = anchorIndex - self.count
                    while i >= 0 {
                        if addedMessages[i].message.id.namespace == namespace {
                            self.earlier[namespace] = addedMessages[i]
                            break
                        }
                        i--
                    }
                }
            }
        }
        else {
            for namespace in context.invalidEarlier {
                var earlyId: MessageId.Id?
                var i = 0
                while i < self.messages.count {
                    if self.messages[i].message.id.namespace == namespace {
                        earlyId = self.messages[i].message.id.id
                        break
                    }
                    i++
                }
                
                let earlierMessages = fetchEarlier(namespace, earlyId, 1)
                if earlierMessages.count == 0 {
                    self.earlier.removeValueForKey(namespace)
                } else {
                    self.earlier[namespace] = earlierMessages[0]
                }
            }
            
            for namespace in context.invalidLater {
                var lateId: MessageId.Id?
                var i = self.messages.count - 1
                while i >= 0 {
                    if self.messages[i].message.id.namespace == namespace {
                        lateId = self.messages[i].message.id.id
                        break
                    }
                    i--
                }
                
                let laterMessages = fetchLater(namespace, lateId, 1)
                if laterMessages.count == 0 {
                    self.later.removeValueForKey(namespace)
                } else {
                    self.later[namespace] = laterMessages[0]
                }
            }
        }
    }
    
    
    public func incompleteMessages() -> [Message] {
        var result: [Message] = []
        
        for (_, message) in self.earlier {
            if message.incomplete {
                result.append(message.message)
            }
        }
        for (_, message) in self.later {
            if message.incomplete {
                result.append(message.message)
            }
        }
        
        for message in self.messages {
            if message.incomplete {
                result.append(message.message)
            }
        }
        
        return result
    }
    
    public func completeMessages(messages: [MessageId : RenderedMessage]) {
        var earlier = self.earlier
        for (namespace, message) in self.earlier {
            if let message = messages[message.message.id] {
                earlier[namespace] = message
            }
        }
        self.earlier = earlier
        
        var later = self.later
        for (namespace, message) in self.later {
            if let message = messages[message.message.id] {
                later[namespace] = message
            }
        }
        self.later = later
        
        var i = 0
        while i < self.messages.count {
            if let message = messages[self.messages[i].message.id] {
                self.messages[i] = message
            }
            i++
        }
    }
    
    public var description: String {
        var string = ""
        string += "...("
        var first = true
        for namespace in self.namespaces {
            if let value = self.earlier[namespace] {
                if first {
                    first = false
                } else {
                    string += ", "
                }
                string += "\(namespace): \(value.message.id.id)—\(value.message.timestamp)"
            }
        }
        string += ") —— "
        
        string += "["
        first = true
        for message in self.messages {
            if first {
                first = false
            } else {
                string += ", "
            }
            string += "\(message.message.id.namespace): \(message.message.id.id)—\(message.message.timestamp)"
        }
        string += "]"
        
        string += " —— ("
        first = true
        for namespace in self.namespaces {
            if let value = self.later[namespace] {
                if first {
                    first = false
                } else {
                    string += ", "
                }
                string += "\(namespace): \(value.message.id.id)—\(value.message.timestamp)"
            }
        }
        string += ")..."
        
        return string
    }
}

public final class MessageView: CustomStringConvertible {
    public let hasEarlier: Bool
    private let earlierIds: [MessageIndex]
    public let hasLater: Bool
    private let laterIds: [MessageIndex]
    public let messages: [RenderedMessage]
    
    init(_ mutableView: MutableMessageView) {
        self.hasEarlier = mutableView.earlier.count != 0
        self.hasLater = mutableView.later.count != 0
        self.messages = mutableView.messages
        
        var earlierIds: [MessageIndex] = []
        for (_, message) in mutableView.earlier {
            earlierIds.append(MessageIndex(message.message))
        }
        self.earlierIds = earlierIds
        
        var laterIds: [MessageIndex] = []
        for (_, message) in mutableView.later {
            laterIds.append(MessageIndex(message.message))
        }
        self.laterIds = laterIds
    }
    
    public var description: String {
        var string = ""
        if self.hasEarlier {
            string += "more("
            var first = true
            for id in self.earlierIds {
                if first {
                    first = false
                } else {
                    string += ", "
                }
                string += "\(id.id.namespace): \(id.id.id)—\(id.timestamp)"
            }
            string += ") "
        }
        string += "["
        var first = true
        for message in self.messages {
            if first {
                first = false
            } else {
                string += ", "
            }
            string += "\(message.message.id.namespace): \(message.message.id.id)—\(message.message.timestamp)"
        }
        string += "]"
        if self.hasLater {
            string += " more("
            var first = true
            for id in self.laterIds {
                if first {
                    first = false
                } else {
                    string += ", "
                }
                string += "\(id.id.namespace): \(id.id.id)—\(id.timestamp)"
            }
            string += ")"
        }
        return string
    }
}
