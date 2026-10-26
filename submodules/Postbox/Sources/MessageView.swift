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
        var reloadForMedia = false
        for operation in operations {
            switch operation {
                case let .Remove(indices):
                    if let message = self.message {
                        let messageIndex = message.index
                        for (index, _, _) in indices {
                            if index == messageIndex {
                                self.message = nil
                                updated = true
                                reloadForMedia = false
                                break
                            }
                        }
                    }
                case let .InsertMessage(message):
                    if message.id == self.messageId || message.stableId == self.stableId {
                        self.message = postbox.renderIntermediateMessage(message)
                        self.stableId = message.stableId
                        updated = true
                        reloadForMedia = false
                    }
                case let .UpdateEmbeddedMedia(index, _):
                    // By id only: the timestamp can have moved without this view following it.
                    if let message = self.message, message.id == index.id {
                        reloadForMedia = true
                    }
                case .UpdateTimestamp:
                    break
                default:
                    break
            }
        }
        // Media shared by several messages lives in a record of its own; updating it
        // rewrites that record and reports the id here, with no history operation.
        if !reloadForMedia, let message = self.message, message.referencesAnyMedia(in: updatedMedia) {
            reloadForMedia = true
        }
        // Re-read the message this view currently holds (it may have followed an id
        // change through its stable id); the table already has the new media.
        if reloadForMedia, let current = self.message, let reloaded = postbox.getMessage(current.id) {
            self.message = reloaded
            updated = true
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
