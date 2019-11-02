import Foundation

public struct MessageHistoryHolesViewEntry: Equatable, Hashable {
    public let hole: MessageHistoryViewHole
    public let direction: MessageHistoryViewRelativeHoleDirection
    public let space: MessageHistoryHoleSpace
    
    public init(hole: MessageHistoryViewHole, direction: MessageHistoryViewRelativeHoleDirection, space: MessageHistoryHoleSpace) {
        self.hole = hole
        self.direction = direction
        self.space = space
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
