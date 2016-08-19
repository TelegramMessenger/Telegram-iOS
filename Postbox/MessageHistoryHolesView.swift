import Foundation

public struct MessageHistoryHolesViewEntry: Hashable {
    public let hole: MessageHistoryHole
    public let direction: HoleFillDirection
    public let tags: MessageTags?
    
    public var hashValue: Int {
        return self.hole.maxIndex.hashValue
    }
}

public func ==(lhs: MessageHistoryHolesViewEntry, rhs: MessageHistoryHolesViewEntry) -> Bool {
    return lhs.hole == rhs.hole && lhs.direction == rhs.direction && lhs.tags == rhs.tags
}

public func <(lhs: MessageHistoryHolesViewEntry, rhs: MessageHistoryHolesViewEntry) -> Bool {
    return lhs.hole.maxIndex < rhs.hole.maxIndex
}

final class MutableMessageHistoryHolesView {
    private var entries: [PeerId: Set<MessageHistoryHolesViewEntry>] = [:]
    
    init() {
    }
    
    func update(peerId: PeerId, holes: Set<MessageHistoryHolesViewEntry>) -> Bool {
        if let currentHoles = self.entries[peerId] {
            if currentHoles != holes {
                if holes.isEmpty {
                    self.entries.removeValue(forKey: peerId)
                } else {
                    self.entries[peerId] = holes
                }
                return true
            } else {
                return false
            }
        } else if !holes.isEmpty {
            self.entries[peerId] = holes
            return true
        } else {
            return false
        }
    }
}

public final class MessageHistoryHolesView {
    public let entries: [PeerId: Set<MessageHistoryHolesViewEntry>]
    
    init(_ mutableView: MutableMessageHistoryHolesView) {
        self.entries = mutableView.entries
    }
}
