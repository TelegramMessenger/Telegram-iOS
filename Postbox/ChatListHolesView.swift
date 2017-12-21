import Foundation

public struct ChatListHolesEntry: Hashable {
    public let groupId: PeerGroupId?
    public let hole: ChatListHole
    
    public var hashValue: Int {
        return self.hole.hashValue
    }
    
    public static func ==(lhs: ChatListHolesEntry, rhs: ChatListHolesEntry) -> Bool {
        return lhs.groupId == rhs.groupId && lhs.hole == rhs.hole
    }
}

final class MutableChatListHolesView {
    fileprivate var entries = Set<ChatListHolesEntry>()
    
    func update(holes: Set<ChatListHolesEntry>) -> Bool {
        if self.entries != holes {
            self.entries = holes
            return true
        } else {
            return false
        }
    }
}

public final class ChatListHolesView {
    public let entries: Set<ChatListHolesEntry>
    
    init(_ mutableView: MutableChatListHolesView) {
        self.entries = mutableView.entries
    }
}
