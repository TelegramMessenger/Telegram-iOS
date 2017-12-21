import Foundation

public struct MessageHistoryHolesViewEntry: Hashable {
    public let hole: MessageHistoryViewHole
    public let direction: MessageHistoryViewRelativeHoleDirection
    public let tags: MessageTags?
    
    public var hashValue: Int {
        return self.hole.hashValue
    }

    public static func ==(lhs: MessageHistoryHolesViewEntry, rhs: MessageHistoryHolesViewEntry) -> Bool {
        return lhs.hole == rhs.hole && lhs.direction == rhs.direction && lhs.tags == rhs.tags
    }

    public static func <(lhs: MessageHistoryHolesViewEntry, rhs: MessageHistoryHolesViewEntry) -> Bool {
        return lhs.hole.holeMaxIndex < rhs.hole.holeMaxIndex
    }
}

final class MutableMessageHistoryHolesView {
    fileprivate var entries = Set<MessageHistoryHolesViewEntry>()
    
    init() {
    }
    
    func update(_ holes: Set<MessageHistoryHolesViewEntry>) -> Bool {
        if self.entries != holes {
            self.entries = holes
            return true
        } else {
            return false
        }
    }
}

public final class MessageHistoryHolesView {
    public let entries: Set<MessageHistoryHolesViewEntry>
    
    init(_ mutableView: MutableMessageHistoryHolesView) {
        self.entries = mutableView.entries
    }
}
