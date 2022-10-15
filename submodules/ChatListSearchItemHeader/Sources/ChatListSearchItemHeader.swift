import Foundation
import UIKit
import Display
import TelegramPresentationData
import ListSectionHeaderNode

public enum ChatListSearchItemHeaderType {
    case localPeers
    case members
    case contacts
    case bots
    case admins
    case globalPeers
    case deviceContacts
    case recentPeers
    case phoneNumber
    case exceptions
    case addToExceptions
    case mapAddress
    case nearbyVenues
    case chats
    case chatTypes
    case faq
    case messages
    case groupMembers
    case activeVoiceChats
    case recentCalls
    case orImportIntoAnExistingGroup
    case subscribers
    case downloading
    case recentDownloads
    case topics
    
    fileprivate func title(strings: PresentationStrings) -> String {
        switch self {
            case .localPeers:
                return strings.DialogList_SearchSectionDialogs
            case .members:
                return strings.Channel_Info_Members
            case .contacts:
                return strings.Contacts_TopSection
            case .bots:
                return strings.MemberSearch_BotSection
            case .admins:
                return strings.Channel_Management_Title
            case .globalPeers:
                return strings.DialogList_SearchSectionGlobal
            case .deviceContacts:
                return strings.Contacts_NotRegisteredSection
            case .recentPeers:
                return strings.DialogList_SearchSectionRecent
            case .phoneNumber:
                return strings.Contacts_PhoneNumber
            case .exceptions:
                return strings.GroupInfo_Permissions_Exceptions
            case .addToExceptions:
                return strings.Exceptions_AddToExceptions
            case .mapAddress:
                return strings.Map_AddressOnMap
            case .nearbyVenues:
                return strings.Map_PlacesNearby
            case .chats:
                return strings.Cache_ByPeerHeader
            case .chatTypes:
                return strings.ChatList_ChatTypesSection
            case .faq:
                return strings.Settings_FrequentlyAskedQuestions
            case .messages:
                return strings.DialogList_SearchSectionMessages
            case .groupMembers:
                return strings.Group_GroupMembersHeader
            case .activeVoiceChats:
                return strings.CallList_ActiveVoiceChatsHeader
            case .recentCalls:
                return strings.CallList_RecentCallsHeader
            case .orImportIntoAnExistingGroup:
                return strings.ChatList_HeaderImportIntoAnExistingGroup
            case .subscribers:
                return strings.Channel_ChannelSubscribersHeader
            case .downloading:
                return strings.DownloadList_DownloadingHeader
            case .recentDownloads:
                return strings.DownloadList_DownloadedHeader
            case .topics:
                return strings.DialogList_SearchSectionTopics
        }
    }
    
    fileprivate var id: ChatListSearchItemHeaderId {
        switch self {
            case .localPeers:
                return .localPeers
            case .members:
                return .members
            case .contacts:
                return .contacts
            case .bots:
                return .bots
            case .admins:
                return .admins
            case .globalPeers:
                return .globalPeers
            case .deviceContacts:
                return .deviceContacts
            case .recentPeers:
                return .recentPeers
            case .phoneNumber:
                return .phoneNumber
            case .exceptions:
                return .exceptions
            case .addToExceptions:
                return .addToExceptions
            case .mapAddress:
                return .mapAddress
            case .nearbyVenues:
                return .nearbyVenues
            case .chats:
                return .chats
            case .chatTypes:
                return .chatTypes
            case .faq:
                return .faq
            case .messages:
                return .messages
            case .groupMembers:
                return .groupMembers
            case .activeVoiceChats:
                return .activeVoiceChats
            case .recentCalls:
                return .recentCalls
            case .orImportIntoAnExistingGroup:
                return .orImportIntoAnExistingGroup
            case .subscribers:
                return .subscribers
            case .downloading:
                return .downloading
            case .recentDownloads:
                return .recentDownloads
            case .topics:
                return .topics
        }
    }
}

private enum ChatListSearchItemHeaderId: Int32 {
    case localPeers
    case members
    case contacts
    case bots
    case admins
    case globalPeers
    case deviceContacts
    case recentPeers
    case phoneNumber
    case exceptions
    case addToExceptions
    case mapAddress
    case nearbyVenues
    case chats
    case chatTypes
    case faq
    case messages
    case photos
    case links
    case files
    case music
    case groupMembers
    case activeVoiceChats
    case recentCalls
    case orImportIntoAnExistingGroup
    case subscribers
    case downloading
    case recentDownloads
    case topics
}

public final class ChatListSearchItemHeader: ListViewItemHeader {
    public let id: ListViewItemNode.HeaderId
    public let type: ChatListSearchItemHeaderType
    public let stickDirection: ListViewItemHeaderStickDirection = .top
    public let stickOverInsets: Bool = true
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let actionTitle: String?
    public let action: (() -> Void)?
    
    public let height: CGFloat = 28.0
    
    public init(type: ChatListSearchItemHeaderType, theme: PresentationTheme, strings: PresentationStrings, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.type = type
        self.id = ListViewItemNode.HeaderId(space: 0, id: Int64(self.type.id.rawValue))
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.action = action
    }

    public func combinesWith(other: ListViewItemHeader) -> Bool {
        if let other = other as? ChatListSearchItemHeader, other.id == self.id {
            return true
        } else {
            return false
        }
    }
    
    public func node(synchronousLoad: Bool) -> ListViewItemHeaderNode {
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
        
        self.sectionHeaderNode.title = type.title(strings: strings).uppercased()
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
        
        self.sectionHeaderNode.title = type.title(strings: strings).uppercased()
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
    
    override public func animateAdded(duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: self.alpha, duration: 0.2)
    }
    
    override public func animateRemoved(duration: Double) {
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: true)
    }
}
