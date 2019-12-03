import Foundation
import UIKit
import Display
import TelegramPresentationData
import ListSectionHeaderNode

public enum ChatListSearchItemHeaderType: Int32 {
    case localPeers
    case members
    case contacts
    case bots
    case admins
    case globalPeers
    case deviceContacts
    case recentPeers
    case messages
    case phoneNumber
    case exceptions
    case addToExceptions
    case mapAddress
    case nearbyVenues
}

public final class ChatListSearchItemHeader: ListViewItemHeader {
    public let id: Int64
    public let type: ChatListSearchItemHeaderType
    public let stickDirection: ListViewItemHeaderStickDirection = .top
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let actionTitle: String?
    public let action: (() -> Void)?
    
    public let height: CGFloat = 28.0
    
    public init(type: ChatListSearchItemHeaderType, theme: PresentationTheme, strings: PresentationStrings, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.type = type
        self.id = Int64(self.type.rawValue)
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public func node() -> ListViewItemHeaderNode {
        return ChatListSearchItemHeaderNode(type: self.type, theme: self.theme, strings: self.strings, actionTitle: self.actionTitle, action: self.action)
    }
    
    public func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {
        (node as? ChatListSearchItemHeaderNode)?.update(type: self.type, actionTitle: self.actionTitle, action: self.action)
    }
}

public final class ChatListSearchItemHeaderNode: ListViewItemHeaderNode {
    private var type: ChatListSearchItemHeaderType
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var actionTitle: String?
    private var action: (() -> Void)?
    
    private var validLayout: (size: CGSize, leftInset: CGFloat, rightInset: CGFloat)?
    
    private let sectionHeaderNode: ListSectionHeaderNode
    
    public init(type: ChatListSearchItemHeaderType, theme: PresentationTheme, strings: PresentationStrings, actionTitle: String?, action: (() -> Void)?) {
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
            self.sectionHeaderNode.title = strings.Channel_Info_Members.uppercased()
        case .contacts:
            self.sectionHeaderNode.title = strings.Contacts_TopSection.uppercased()
        case .bots:
            self.sectionHeaderNode.title = strings.MemberSearch_BotSection.uppercased()
        case .admins:
            self.sectionHeaderNode.title = strings.Channel_Management_Title.uppercased()
        case .globalPeers:
            self.sectionHeaderNode.title = strings.DialogList_SearchSectionGlobal.uppercased()
        case .deviceContacts:
            self.sectionHeaderNode.title = strings.Contacts_NotRegisteredSection.uppercased()
        case .messages:
            self.sectionHeaderNode.title = strings.DialogList_SearchSectionMessages.uppercased()
        case .recentPeers:
            self.sectionHeaderNode.title = strings.DialogList_SearchSectionRecent.uppercased()
        case .phoneNumber:
            self.sectionHeaderNode.title = strings.Contacts_PhoneNumber.uppercased()
        case .exceptions:
            self.sectionHeaderNode.title = strings.GroupInfo_Permissions_Exceptions.uppercased()
        case .addToExceptions:
            self.sectionHeaderNode.title = strings.Exceptions_AddToExceptions.uppercased()
        case .mapAddress:
            self.sectionHeaderNode.title = strings.Map_AddressOnMap.uppercased()
        case .nearbyVenues:
            self.sectionHeaderNode.title = strings.Map_PlacesNearby.uppercased()
        }
        
        self.sectionHeaderNode.action = actionTitle
        self.sectionHeaderNode.activateAction = action
        
        self.addSubnode(self.sectionHeaderNode)
    }
    
    public func updateTheme(theme: PresentationTheme) {
        self.theme = theme
        self.sectionHeaderNode.updateTheme(theme: theme)
    }
    
    public func update(type: ChatListSearchItemHeaderType, actionTitle: String?, action: (() -> Void)?) {
        self.actionTitle = actionTitle
        self.action = action
        
        switch type {
        case .localPeers:
            self.sectionHeaderNode.title = strings.DialogList_SearchSectionDialogs.uppercased()
        case .members:
            self.sectionHeaderNode.title = strings.Channel_Info_Members.uppercased()
        case .contacts:
            self.sectionHeaderNode.title = strings.Contacts_TopSection.uppercased()
        case .bots:
            self.sectionHeaderNode.title = strings.MemberSearch_BotSection.uppercased()
        case .admins:
            self.sectionHeaderNode.title = strings.Channel_Management_Title.uppercased()
        case .globalPeers:
            self.sectionHeaderNode.title = strings.DialogList_SearchSectionGlobal.uppercased()
        case .deviceContacts:
            self.sectionHeaderNode.title = strings.Contacts_NotRegisteredSection.uppercased()
        case .messages:
            self.sectionHeaderNode.title = strings.DialogList_SearchSectionMessages.uppercased()
        case .recentPeers:
            self.sectionHeaderNode.title = strings.DialogList_SearchSectionRecent.uppercased()
        case .phoneNumber:
            self.sectionHeaderNode.title = strings.Contacts_PhoneNumber.uppercased()
        case .exceptions:
            self.sectionHeaderNode.title = strings.GroupInfo_Permissions_Exceptions.uppercased()
        case .addToExceptions:
            self.sectionHeaderNode.title = strings.Exceptions_AddToExceptions.uppercased()
        case .mapAddress:
            self.sectionHeaderNode.title = strings.Map_AddressOnMap.uppercased()
        case .nearbyVenues:
            self.sectionHeaderNode.title = strings.Map_PlacesNearby.uppercased()
        }
        
        self.sectionHeaderNode.action = actionTitle
        self.sectionHeaderNode.activateAction = action
        
        if let (size, leftInset, rightInset) = self.validLayout {
            self.sectionHeaderNode.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
        }
    }
    
    override public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        self.validLayout = (size, leftInset, rightInset)
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: size)
        self.sectionHeaderNode.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
    }
    
    override public func animateRemoved(duration: Double) {
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: true)
    }
}
