import Foundation

final class MutableTimestampBasedMessageAttributesView {
    let tag: UInt16
    var head: TimestampBasedMessageAttributesEntry?
    
    init(postbox: PostboxImpl, tag: UInt16) {
        self.tag = tag
        self.head = postbox.timestampBasedMessageAttributesTable.head(tag: tag)

        postboxLog("MutableTimestampBasedMessageAttributesView: tag: \(tag) head: \(String(describing: self.head))")
    }
    
    func replay(postbox: PostboxImpl, operations: [TimestampBasedMessageAttributesOperation]) -> Bool {
        var updated = false
        var invalidatedHead = false
        for operation in operations {
            switch operation {
                case let .add(entry):
                    if entry.tag == self.tag {
                        if let head = self.head {
                            if entry.index < head.index {
                                self.head = entry
                                updated = true
                            }
                        } else {
                            self.head = entry
                            updated = true
                        }
                    }
                case let .remove(entry):
                    if entry.tag == self.tag {
                        if let head = self.head, head.messageId == entry.messageId {
                            self.head = nil
                            updated = true
                            invalidatedHead = true
                        }
                    }
            }
        }
        if invalidatedHead {
            self.head = postbox.timestampBasedMessageAttributesTable.head(tag: self.tag)
        }
        return updated
    }
}

public final class TimestampBasedMessageAttributesView {
    public let head: TimestampBasedMessageAttributesEntry?
    
    init(_ view: MutableTimestampBasedMessageAttributesView) {
        self.head = view.head
    }
}
