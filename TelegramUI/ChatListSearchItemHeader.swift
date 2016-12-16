import Foundation
import Display

enum ChatListSearchItemHeaderType: Int32 {
    case localPeers
    case globalPeers
    case messages
}

final class ChatListSearchItemHeader: ListViewItemHeader {
    let id: Int64
    let type: ChatListSearchItemHeaderType
    let stickDirection: ListViewItemHeaderStickDirection = .top
    
    let height: CGFloat = 29.0
    
    init(type: ChatListSearchItemHeaderType) {
        self.type = type
        self.id = Int64(self.type.rawValue)
    }
    
    func node() -> ListViewItemHeaderNode {
        return ChatListSearchItemHeaderNode(type: self.type)
    }
}

final class ChatListSearchItemHeaderNode: ListViewItemHeaderNode {
    private let type: ChatListSearchItemHeaderType
    
    private let sectionHeaderNode: ListSectionHeaderNode
    
    init(type: ChatListSearchItemHeaderType) {
        self.type = type
        
        self.sectionHeaderNode = ListSectionHeaderNode()
        
        super.init()
        
        switch type {
            case .localPeers:
                self.sectionHeaderNode.title = "CHATS AND CONTACTS"
            case .globalPeers:
                self.sectionHeaderNode.title = "GLOBAL SEARCH"
            case .messages:
                self.sectionHeaderNode.title = "MESSAGES"
        }
        
        self.addSubnode(self.sectionHeaderNode)
    }
    
    override func layout() {
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }
}
