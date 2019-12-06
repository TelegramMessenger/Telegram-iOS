import Foundation

public struct MessageHistoryHolesViewEntry: Equatable, Hashable {
    public let hole: MessageHistoryViewHole
    public let direction: MessageHistoryViewRelativeHoleDirection
    public let space: MessageHistoryHoleSpace
    public let count: Int
    
    public init(hole: MessageHistoryViewHole, direction: MessageHistoryViewRelativeHoleDirection, space: MessageHistoryHoleSpace, count: Int) {
        self.hole = hole
        self.direction = direction
        self.space = space
        self.count = count
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
