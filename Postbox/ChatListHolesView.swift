import Foundation

final class MutableChatListHolesView {
    fileprivate var entries = Set<ChatListHole>()
    
    func update(holes: Set<ChatListHole>) -> Bool {
        if self.entries != holes {
            self.entries = holes
            return true
        } else {
            return false
        }
    }
}

public final class ChatListHolesView {
    public let entries: Set<ChatListHole>
    
    init(_ mutableView: MutableChatListHolesView) {
        self.entries = mutableView.entries
    }
}
