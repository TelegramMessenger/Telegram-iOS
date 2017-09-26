import Foundation
import Display

enum ChatListSearchItemHeaderType: Int32 {
    case localPeers
    case members
    case contacts
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
    let actionTitle: String?
    let action: (() -> Void)?
    
    let height: CGFloat = 29.0
    
    init(type: ChatListSearchItemHeaderType, theme: PresentationTheme, strings: PresentationStrings, actionTitle: String?, action: (() -> Void)?) {
        self.type = type
        self.id = Int64(self.type.rawValue)
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.action = action
    }
    
    func node() -> ListViewItemHeaderNode {
        return ChatListSearchItemHeaderNode(type: self.type, theme: self.theme, strings: self.strings, actionTitle: self.actionTitle, action: self.action)
    }
}

final class ChatListSearchItemHeaderNode: ListViewItemHeaderNode {
    private let type: ChatListSearchItemHeaderType
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let actionTitle: String?
    private let action: (() -> Void)?
    
    private let sectionHeaderNode: ListSectionHeaderNode
    
    init(type: ChatListSearchItemHeaderType, theme: PresentationTheme, strings: PresentationStrings, actionTitle: String?, action: (() -> Void)?) {
        self.type = type
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.action = action
        
        self.sectionHeaderNode = ListSectionHeaderNode(theme: theme)
        
        super.init()
        
        switch type {
            case .localPeers:
                self.sectionHeaderNode.title = strings.DialogList_SearchSectionDialogs.uppercased()
            case .members:
                self.sectionHeaderNode.title = strings.Compose_NewChannel_Members.uppercased()
            case .contacts:
                self.sectionHeaderNode.title = strings.Contacts_TopSection.uppercased()
            case .globalPeers:
                self.sectionHeaderNode.title = strings.DialogList_SearchSectionGlobal.uppercased()
            case .messages:
                self.sectionHeaderNode.title = strings.DialogList_SearchSectionMessages.uppercased()
            case .recentPeers:
                self.sectionHeaderNode.title = strings.DialogList_SearchSectionRecent.uppercased()
        }
        
        self.sectionHeaderNode.action = actionTitle
        self.sectionHeaderNode.activateAction = action
        
        self.addSubnode(self.sectionHeaderNode)
    }
    
    override func layout() {
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }
    
    override func animateRemoved(duration: Double) {
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
    }
}
