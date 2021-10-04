import Foundation

final class MutableMessageView {
    let messageId: MessageId
    var stableId: UInt32?
    var message: Message?
    
    init(messageId: MessageId, message: Message?) {
        self.messageId = messageId
        self.message = message
        self.stableId = message?.stableId
    }
    
    func replay(postbox: PostboxImpl, operations: [MessageHistoryOperation], updatedMedia: [MediaId: Media?]) -> Bool {
        var updated = false
        for operation in operations {
            switch operation {
                case let .Remove(indices):
                    if let message = self.message {
                        let messageIndex = message.index
                        for (index, _) in indices {
                            if index == messageIndex {
                                self.message = nil
                                updated = true
                                break
                            }
                        }
                    }
                case let .InsertMessage(message):
                    if message.id == self.messageId || message.stableId == self.stableId {
                        self.message = postbox.renderIntermediateMessage(message)
                        self.stableId = message.stableId
                        updated = true
                    }
                case .UpdateEmbeddedMedia:
                    break
                case .UpdateTimestamp:
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
