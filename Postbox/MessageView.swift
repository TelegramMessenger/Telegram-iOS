import Foundation

public final class MutableMessageView: Printable {
    public struct RemoveContext {
        var invalidEarlier: Set<MessageId.Namespace>
        var invalidLater: Set<MessageId.Namespace>
        var removedMessages: Bool
        
        init() {
            self.invalidEarlier = []
            self.invalidLater = []
            self.removedMessages = false
        }
    }
    
    let namespaces: [MessageId.Namespace]
    let count: Int
    var earlier: [MessageId.Namespace : Message] = [:]
    var later: [MessageId.Namespace : Message] = [:]
    var messages: [Message]
    
    public init(namespaces: [MessageId.Namespace], count: Int, earlier: [MessageId.Namespace : Message], messages: [Message], later: [MessageId.Namespace : Message]) {
        self.namespaces = namespaces
        self.count = count
        self.earlier = earlier
        self.later = later
        self.messages = messages
    }
    
    public func add(message: Message) {
        if self.messages.count == 0 {
            self.messages.append(message)
        } else {
            var first = MessageIndex(self.messages[self.messages.count - 1])
            var last = MessageIndex(self.messages[0])
            
            var next: MessageIndex?
            for namespace in self.namespaces {
                if let message = later[namespace] {
                    let messageIndex = MessageIndex(message)
                    if next == nil || messageIndex < next! {
                        next = messageIndex
                    }
                }
            }
            
            let index = MessageIndex(message)
            
            if index < last {
                let earlierMessage = self.earlier[message.id.namespace]
                if earlierMessage == nil || earlierMessage!.id.id < message.id.id {
                    if self.messages.count < self.count {
                        self.messages.insert(message, atIndex: 0)
                    } else {
                        self.earlier[message.id.namespace] = message
                    }
                }
            } else if index > first {
                if next != nil && index > next! {
                    let laterMessage = self.later[message.id.namespace]
                    if laterMessage == nil || laterMessage!.id.id > message.id.id {
                        if self.messages.count < self.count {
                            self.messages.append(message)
                        } else {
                            self.later[message.id.namespace] = message
                        }
                    }
                } else {
                    self.messages.append(message)
                    if self.messages.count > self.count {
                        let earliest = self.messages[0]
                        self.earlier[earliest.id.namespace] = earliest
                        self.messages.removeAtIndex(0)
                    }
                }
            } else if index != last && index != first {
                var i = self.messages.count
                while i >= 1 {
                    if MessageIndex(self.messages[i - 1]) < index {
                        break
                    }
                    i--
                }
                self.messages.insert(message, atIndex: i)
                if self.messages.count > self.count {
                    let earliest = self.messages[0]
                    self.earlier[earliest.id.namespace] = earliest
                    self.messages.removeAtIndex(0)
                }
            }
        }
    }
    
    public func remove(ids: Set<MessageId>, context: RemoveContext? = nil) -> RemoveContext {
        var updatedContext = RemoveContext()
        if let context = context {
            updatedContext = context
        }
        
        for (_, message) in self.earlier {
            if ids.contains(message.id) {
                updatedContext.invalidEarlier.insert(message.id.namespace)
            }
        }

        for (_, message) in self.later {
            if ids.contains(message.id) {
                updatedContext.invalidLater.insert(message.id.namespace)
            }
        }
        
        if self.messages.count != 0 {
            var i = self.messages.count - 1
            while i >= 0 {
                if ids.contains(self.messages[i].id) {
                    self.messages.removeAtIndex(i)
                    updatedContext.removedMessages = true
                }
                i--
            }
        }
        
        return updatedContext
    }
    
    public func complete(context: RemoveContext, fetchEarlier: (MessageId.Namespace, MessageId.Id?, Int) -> [Message], fetchLater: (MessageId.Namespace, MessageId.Id?, Int) -> [Message]) {
        if context.removedMessages {
            var addedMessages: [Message] = []
            
            var latestAnchor: MessageIndex?
            if let lastMessage = self.messages.last {
                latestAnchor = MessageIndex(lastMessage)
            }
            
            if latestAnchor == nil {
                var laterMessages: [Message] = []
                for (_, message) in self.later {
                    let messageIndex = MessageIndex(message)
                    if latestAnchor == nil || latestAnchor! > messageIndex {
                        latestAnchor = messageIndex
                    }
                }
            }
            
            for namespace in self.namespaces {
                if let later = self.later[namespace] {
                    addedMessages += fetchLater(namespace, later.id.id - 1, self.count)
                }
                if let earlier = self.earlier[namespace] {
                    addedMessages += fetchEarlier(namespace, earlier.id.id + 1, self.count)
                }
            }
            
            addedMessages += self.messages
            addedMessages.sort({ MessageIndex($0) < MessageIndex($1) })
            var i = addedMessages.count - 1
            while i >= 1 {
                if addedMessages[i].id == addedMessages[i - 1].id {
                    addedMessages.removeAtIndex(i)
                }
                i--
            }
            self.messages = []
            
            var anchorIndex = addedMessages.count - 1
            if let latestAnchor = latestAnchor {
                var i = addedMessages.count - 1
                while i >= 0 {
                    if MessageIndex(addedMessages[i]) <= latestAnchor {
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
                        if addedMessages[i].id.namespace == namespace {
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
                        if addedMessages[i].id.namespace == namespace {
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
                    if self.messages[i].id.namespace == namespace {
                        earlyId = self.messages[i].id.id
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
                    if self.messages[i].id.namespace == namespace {
                        lateId = self.messages[i].id.id
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
                string += "\(namespace): \(value.id.id)—\(value.timestamp)"
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
            string += "\(message.id.namespace): \(message.id.id)—\(message.timestamp)"
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
                string += "\(namespace): \(value.id.id)—\(value.timestamp)"
            }
        }
        string += ")..."
        
        return string
    }
}

public final class MessageView: Printable {
    public let hasEarlier: Bool
    private let earlierIds: [MessageIndex]
    public let hasLater: Bool
    private let laterIds: [MessageIndex]
    public let messages: [Message]
    
    init(_ mutableView: MutableMessageView) {
        self.hasEarlier = mutableView.earlier.count != 0
        self.hasLater = mutableView.later.count != 0
        self.messages = mutableView.messages
        
        var earlierIds: [MessageIndex] = []
        for (_, message) in mutableView.earlier {
            earlierIds.append(MessageIndex(message))
        }
        self.earlierIds = earlierIds
        
        var laterIds: [MessageIndex] = []
        for (_, message) in mutableView.later {
            laterIds.append(MessageIndex(message))
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
            string += "\(message.id.namespace): \(message.id.id)—\(message.timestamp)"
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
