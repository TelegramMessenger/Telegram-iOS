import Foundation

final class MutableTimestampBasedMessageAttributesView {
    let tag: UInt16
    var head: TimestampBasedMessageAttributesEntry?
    
    init(tag: UInt16, getHead: (UInt16) -> TimestampBasedMessageAttributesEntry?) {
        self.tag = tag
        self.head = getHead(tag)
    }
    
    func replay(operations: [TimestampBasedMessageAttributesOperation], getHead: (UInt16) -> TimestampBasedMessageAttributesEntry?) -> Bool {
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
                        if let head = self.head, head.index == entry.index {
                            self.head = nil
                            updated = true
                            invalidatedHead = true
                        }
                    }
            }
        }
        if invalidatedHead {
            self.head = getHead(self.tag)
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
