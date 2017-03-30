import Foundation

final class MutableMessageView {
    let messageId: MessageId
    var message: Message?
    
    init(messageId: MessageId, message: Message?) {
        self.messageId = messageId
        self.message = message
    }
    
    func replay(_ operations: [MessageHistoryOperation], updatedMedia: [MediaId: Media?], renderIntermediateMessage: (IntermediateMessage) -> Message) -> Bool {
        var updated = false
        for operation in operations {
            switch operation {
                case let .Remove(indices):
                    if let message = self.message {
                        let messageIndex = MessageIndex(message)
                        for (index, _, _) in indices {
                            if index == messageIndex {
                                self.message = nil
                                updated = true
                                break
                            }
                        }
                    }
                case let .InsertMessage(message):
                    if message.id == self.messageId {
                        self.message = renderIntermediateMessage(message)
                        updated = true
                    }
                case let .UpdateEmbeddedMedia(index, embeddedMedia):
                    break
                case let .UpdateTimestamp(index, timestamp):
                    break
                default:
                    break
            }
        }
        return updated
    }
}

public final class MessageView {
    public let messageId: MessageId
    public let message: Message?
    
    init(_ view: MutableMessageView) {
        self.messageId = view.messageId
        self.message = view.message
    }
}
