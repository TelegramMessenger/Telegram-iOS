import Foundation

final class MutableAllChatListHolesView: MutablePostboxView {
    fileprivate let groupId: PeerGroupId
    private var holes = Set<ChatListHole>()
    fileprivate var latestHole: ChatListHole?
    
    init(postbox: PostboxImpl, groupId: PeerGroupId) {
        self.groupId = groupId
        self.holes = Set(postbox.chatListTable.allHoles(groupId: groupId))
        self.latestHole = self.holes.max(by: { $0.index < $1.index })
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        if let operations = transaction.chatListOperations[self.groupId] {
            var updated = false
            for operation in operations {
                switch operation {
                case let .InsertHole(hole):
                    if !self.holes.contains(hole) {
                        self.holes.insert(hole)
                        updated = true
                    }
                case let .RemoveHoles(indices):
                    for index in indices {
                        if self.holes.contains(ChatListHole(index: index.messageIndex)) {
                            self.holes.remove(ChatListHole(index: index.messageIndex))
                            updated = true
                        }
                    }
                default:
                    break
                }
            }
            
            if updated {
                let updatedLatestHole = self.holes.max(by: { $0.index < $1.index })
                if updatedLatestHole != self.latestHole {
                    self.latestHole = updatedLatestHole
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        } else {
            return false
        }
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return AllChatListHolesView(self)
    }
}

public final class AllChatListHolesView: PostboxView {
    public let latestHole: ChatListHole?
    
    init(_ view: MutableAllChatListHolesView) {
        self.latestHole = view.latestHole
    }
}
