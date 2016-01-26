import Foundation

public final class MutableMessageHistoryView: CustomStringConvertible {
    public struct RemoveContext {
        var invalidEarlier: Bool = false
        var invalidLater: Bool = false
        var invalidEarlierHole: Bool = false
        var invalidLaterHole: Bool = false
        var removedMessages: Bool = false
        var removedHole: Bool = false
        
        func empty() -> Bool {
            return !self.removedMessages && !invalidEarlier && !invalidLater
        }
    }
    
    let count: Int
    var earlierMessage: RenderedMessage?
    var laterMessage: RenderedMessage?
    var messages: [RenderedMessage]
    
    public init(count: Int, earlierMessage: RenderedMessage?, messages: [RenderedMessage], laterMessage: RenderedMessage?) {
        self.count = count
        self.earlierMessage = earlierMessage
        self.laterMessage = laterMessage
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
            if let message = laterMessage {
                let messageIndex = MessageIndex(message.message)
                next = messageIndex
            }
            
            let index = MessageIndex(message.message)
            
            if index < last {
                let earlierMessage = self.earlierMessage
                if earlierMessage == nil || MessageIndex(earlierMessage!.message) < index {
                    if self.messages.count < self.count {
                        self.messages.insert(message, atIndex: 0)
                    } else {
                        self.earlierMessage = message
                    }
                    return true
                } else {
                    return false
                }
            } else if index > first {
                if next != nil && index > next! {
                    let laterMessage = self.laterMessage
                    if laterMessage == nil || MessageIndex(laterMessage!.message) > index {
                        if self.messages.count < self.count {
                            self.messages.append(message)
                        } else {
                            self.laterMessage = message
                        }
                        return true
                    } else {
                        return false
                    }
                } else {
                    self.messages.append(message)
                    if self.messages.count > self.count {
                        let earliest = self.messages[0]
                        self.earlierMessage = earliest
                        self.messages.removeAtIndex(0)
                    }
                    return true
                }
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
                    self.earlierMessage = earliest
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
        
        if let earlierMessage = self.earlierMessage where ids.contains(earlierMessage.message.id) {
            updatedContext.invalidEarlier = true
        }
        
        if let laterMessage = self.laterMessage where ids.contains(laterMessage.message.id) {
            updatedContext.invalidLater = true
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
    
    public func complete(context: RemoveContext, fetchEarlier: (MessageIndex?, Int) -> [RenderedMessage], fetchLater: (MessageIndex?, Int) -> [RenderedMessage]) {
        if context.removedMessages {
            var addedMessages: [RenderedMessage] = []
            
            var latestAnchor: MessageIndex?
            if let lastMessage = self.messages.last {
                latestAnchor = MessageIndex(lastMessage.message)
            }
            
            if latestAnchor == nil {
                if let laterMessage = self.laterMessage {
                    latestAnchor = MessageIndex(laterMessage.message)
                }
            }
            
            if let laterMessage = self.laterMessage {
                addedMessages += fetchLater(MessageIndex(laterMessage.message).predecessor(), self.count)
            }
            if let earlierMessage = self.earlierMessage {
                addedMessages += fetchEarlier(MessageIndex(earlierMessage.message).successor(), self.count)
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
            
            self.laterMessage = nil
            if anchorIndex + 1 < addedMessages.count {
                self.laterMessage = addedMessages[anchorIndex + 1]
            }
            
            i = anchorIndex
            while i >= 0 && i > anchorIndex - self.count {
                self.messages.insert(addedMessages[i], atIndex: 0)
                i--
            }
            
            self.earlierMessage = nil
            if anchorIndex - self.count >= 0 {
                self.earlierMessage = addedMessages[anchorIndex - self.count]
            }
        }
        else {
            if context.invalidEarlier {
                var earlyId: MessageIndex?
                let i = 0
                if i < self.messages.count {
                    earlyId = MessageIndex(self.messages[i].message)
                }
                
                let earlierMessages = fetchEarlier(earlyId, 1)
                self.earlierMessage = earlierMessages.first
            }
            
            if context.invalidLater {
                var laterId: MessageIndex?
                let i = self.messages.count - 1
                if i >= 0 {
                    laterId = MessageIndex(self.messages[i].message)
                }
                
                let laterMessages = fetchLater(laterId, 1)
                self.laterMessage = laterMessages.first
            }
        }
    }
    
    
    public func incompleteMessages() -> [Message] {
        var result: [Message] = []
        
        if let earlierMessage = self.earlierMessage where earlierMessage.incomplete {
            result.append(earlierMessage.message)
        }

        if let laterMessage = self.laterMessage where laterMessage.incomplete {
            result.append(laterMessage.message)
        }
        
        for message in self.messages {
            if message.incomplete {
                result.append(message.message)
            }
        }
        
        return result
    }
    
    public func completeMessages(messages: [MessageId : RenderedMessage]) {
        if let earlierMessage = self.earlierMessage {
            if let renderedMessage = messages[earlierMessage.message.id] {
                self.earlierMessage = renderedMessage
            }
        }
        
        if let laterMessage = self.laterMessage {
            if let renderedMessage = messages[laterMessage.message.id] {
                self.laterMessage = renderedMessage
            }
        }
        
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
        if let value = self.earlierMessage {
            string += "\(value.message.id.namespace): \(value.message.id.id)—\(value.message.timestamp)"
        }
        string += ") —— "
        
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
        
        string += " —— ("
        if let value = self.laterMessage {
            string += "\(value.message.id.namespace): \(value.message.id.id)—\(value.message.timestamp)"
        }
        string += ")..."
        
        return string
    }
}

public final class MessageHistoryView: CustomStringConvertible {
    public let hasEarlier: Bool
    private let earlierId: MessageIndex?
    public let hasLater: Bool
    private let laterId: MessageIndex?
    public let messages: [RenderedMessage]
    
    init(_ mutableView: MutableMessageHistoryView) {
        self.hasEarlier = mutableView.earlierMessage != nil
        self.hasLater = mutableView.laterMessage != nil
        self.messages = mutableView.messages
        
        if let earlierMessage = mutableView.earlierMessage {
            self.earlierId = MessageIndex(earlierMessage.message)
        } else {
            self.earlierId = nil
        }
        
        if let laterMessage = mutableView.laterMessage {
            self.laterId = MessageIndex(laterMessage.message)
        } else {
            self.laterId = nil
        }
    }
    
    public var description: String {
        var string = ""
        if self.hasEarlier {
            string += "more("
            if let earlierId = self.earlierId {
                string += "\(earlierId.id.namespace): \(earlierId.id.id)—\(earlierId.timestamp)"
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
            if let laterId = self.laterId {
                string += "\(laterId.id.namespace): \(laterId.id.id)—\(laterId.timestamp)"
            }
            string += ")"
        }
        return string
    }
}
