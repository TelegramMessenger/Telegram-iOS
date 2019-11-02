import Foundation

public final class UnsentMessageIdsView {
    public let ids: Set<MessageId>
    
    init(_ ids: Set<MessageId>) {
        self.ids = ids
    }
}
