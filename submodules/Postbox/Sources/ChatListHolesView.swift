import Foundation

public struct ChatListHolesEntry: Hashable {
    public let groupId: PeerGroupId
    public let hole: ChatListHole
    
    public init(groupId: PeerGroupId, hole: ChatListHole) {
        self.groupId = groupId
        self.hole = hole
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
