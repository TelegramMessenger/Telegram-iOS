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

public struct ForumTopicListHolesEntry: Hashable {
    public let peerId: PeerId
    public let index: StoredPeerThreadCombinedState.Index?
    
    public init(peerId: PeerId, index: StoredPeerThreadCombinedState.Index?) {
        self.peerId = peerId
        self.index = index
    }
}

final class MutableForumTopicListHolesView {
    fileprivate var entries = Set<ForumTopicListHolesEntry>()
    
    func update(holes: Set<ForumTopicListHolesEntry>) -> Bool {
        if self.entries != holes {
            self.entries = holes
            return true
        } else {
            return false
        }
    }
}

public final class ForumTopicListHolesView {
    public let entries: Set<ForumTopicListHolesEntry>
    
    init(_ mutableView: MutableForumTopicListHolesView) {
        self.entries = mutableView.entries
    }
}

