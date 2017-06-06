import Foundation
import Display

enum ChatListSearchItemHeaderType: Int32 {
    case localPeers
    case globalPeers
    case recentPeers
    case messages
}

final class ChatListSearchItemHeader: ListViewItemHeader {
    let id: Int64
    let type: ChatListSearchItemHeaderType
    let stickDirection: ListViewItemHeaderStickDirection = .top
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    let height: CGFloat = 29.0
    
    init(type: ChatListSearchItemHeaderType, theme: PresentationTheme, strings: PresentationStrings) {
        self.type = type
        self.id = Int64(self.type.rawValue)
        self.theme = theme
        self.strings = strings
    }
    
    func node() -> ListViewItemHeaderNode {
        return ChatListSearchItemHeaderNode(type: self.type, theme: self.theme, strings: self.strings)
    }
}

final class ChatListSearchItemHeaderNode: ListViewItemHeaderNode {
    private let type: ChatListSearchItemHeaderType
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let sectionHeaderNode: ListSectionHeaderNode
    
    init(type: ChatListSearchItemHeaderType, theme: PresentationTheme, strings: PresentationStrings) {
        self.type = type
        self.theme = theme
        self.strings = strings
        
        self.sectionHeaderNode = ListSectionHeaderNode(theme: theme)
        
        super.init()
        
        switch type {
            case .localPeers:
                self.sectionHeaderNode.title = strings.DialogList_SearchSectionDialogs.uppercased()
            case .globalPeers:
                self.sectionHeaderNode.title = strings.DialogList_SearchSectionGlobal.uppercased()
            case .messages:
                self.sectionHeaderNode.title = strings.DialogList_SearchSectionMessages.uppercased()
            case .recentPeers:
                self.sectionHeaderNode.title = strings.DialogList_SearchSectionRecent.uppercased()
        }
        
        self.addSubnode(self.sectionHeaderNode)
    }
    
    override func layout() {
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }
}
