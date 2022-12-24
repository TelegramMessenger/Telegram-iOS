import Foundation

public struct MessageHistoryHolesViewEntry: Equatable, Hashable, CustomStringConvertible {
    public let hole: MessageHistoryViewHole
    public let direction: MessageHistoryViewRelativeHoleDirection
    public let space: MessageHistoryHoleSpace
    public let count: Int
    public let userId: Int64?
    
    public init(hole: MessageHistoryViewHole, direction: MessageHistoryViewRelativeHoleDirection, space: MessageHistoryHoleSpace, count: Int, userId: Int64?) {
        self.hole = hole
        self.direction = direction
        self.space = space
        self.count = count
        self.userId = userId
    }
    
    public var description: String {
        return "hole: \(self.hole), direction: \(self.direction), space: \(self.space), count: \(self.count), userId: \(String(describing: self.userId))"
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

public struct MessageHistoryExternalHolesViewEntry: Equatable, Hashable {
    public let hole: MessageHistoryViewHole
    public let direction: MessageHistoryViewRelativeHoleDirection
    public let count: Int
    
    public init(hole: MessageHistoryViewHole, direction: MessageHistoryViewRelativeHoleDirection, count: Int) {
        self.hole = hole
        self.direction = direction
        self.count = count
    }
}

final class MutableMessageHistoryExternalHolesView {
    fileprivate var entries = Set<MessageHistoryExternalHolesViewEntry>()
    
    init() {
    }
    
    func update(_ holes: Set<MessageHistoryExternalHolesViewEntry>) -> Bool {
        if self.entries != holes {
            self.entries = holes
            return true
        } else {
            return false
        }
    }
}

public final class MessageHistoryExternalHolesView {
    public let entries: Set<MessageHistoryExternalHolesViewEntry>
    
    init(_ mutableView: MutableMessageHistoryExternalHolesView) {
        self.entries = mutableView.entries
    }
}

