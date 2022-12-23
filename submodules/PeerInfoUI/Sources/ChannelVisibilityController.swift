import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import ShareController
import AlertUI
import PresentationDataUtils
import TelegramNotices
import ItemListPeerItem
import ItemListPeerActionItem
import AccountContext
import InviteLinksUI
import ContextUI
import UndoUI
import QrCodeUI
import PremiumUI

private final class ChannelVisibilityControllerArguments {
    let context: AccountContext
    let updateCurrentType: (CurrentChannelType) -> Void
    let updatePublicLinkText: (String?, String) -> Void
    let scrollToPublicLinkText: () -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let revokePeerId: (PeerId) -> Void
    let copyLink: (ExportedInvitation) -> Void
    let shareLink: (ExportedInvitation) -> Void
    let linkContextAction: (ASDisplayNode, ContextGesture?) -> Void
    let manageInviteLinks: () -> Void
    let openLink: (ExportedInvitation) -> Void
    let toggleForwarding: (Bool) -> Void
    let updateJoinToSend: (CurrentChannelJoinToSend) -> Void
    let toggleApproveMembers: (Bool) -> Void
    let activateLink: (String) -> Void
    let deactivateLink: (String) -> Void
    
    init(context: AccountContext, updateCurrentType: @escaping (CurrentChannelType) -> Void, updatePublicLinkText: @escaping (String?, String) -> Void, scrollToPublicLinkText: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, revokePeerId: @escaping (PeerId) -> Void, copyLink: @escaping (ExportedInvitation) -> Void, shareLink: @escaping (ExportedInvitation) -> Void, linkContextAction: @escaping (ASDisplayNode, ContextGesture?) -> Void, manageInviteLinks: @escaping () -> Void, openLink: @escaping (ExportedInvitation) -> Void, toggleForwarding: @escaping (Bool) -> Void, updateJoinToSend: @escaping (CurrentChannelJoinToSend) -> Void, toggleApproveMembers: @escaping (Bool) -> Void, activateLink: @escaping (String) -> Void, deactivateLink: @escaping (String) -> Void) {
        self.context = context
        self.updateCurrentType = updateCurrentType
        self.updatePublicLinkText = updatePublicLinkText
        self.scrollToPublicLinkText = scrollToPublicLinkText
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.revokePeerId = revokePeerId
        self.copyLink = copyLink
        self.shareLink = shareLink
        self.linkContextAction = linkContextAction
        self.manageInviteLinks = manageInviteLinks
        self.openLink = openLink
        self.toggleForwarding = toggleForwarding
        self.updateJoinToSend = updateJoinToSend
        self.toggleApproveMembers = toggleApproveMembers
        self.activateLink = activateLink
        self.deactivateLink = deactivateLink
    }
}

private enum ChannelVisibilitySection: Int32 {
    case type
    case limitInfo
    case link
    case linkActions
    case additional
    case joinToSend
    case approveMembers
    case forwarding
}

private enum ChannelVisibilityEntryTag: ItemListItemTag {
    case publicLink
    case privateLink
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? ChannelVisibilityEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum ChannelVisibilityEntryId: Hashable {
    case index(Int32)
    case username(String)
}

private enum ChannelVisibilityEntry: ItemListNodeEntry {
    case typeHeader(PresentationTheme, String)
    case typePublic(PresentationTheme, String, Bool)
    case typePrivate(PresentationTheme, String, Bool)
    case typeInfo(PresentationTheme, String)
    
    case publicLinkHeader(PresentationTheme, String)
    case publicLinkAvailability(PresentationTheme, String, Bool)
    case linksLimitInfo(PresentationTheme, String, Int32, Int32, Int32, Bool)
    case editablePublicLink(PresentationTheme, PresentationStrings, String, String)
    case privateLinkHeader(PresentationTheme, String)
    case privateLink(PresentationTheme, ExportedInvitation?, [EnginePeer], Int32, Bool)
    case privateLinkInfo(PresentationTheme, String)
    case privateLinkManage(PresentationTheme, String)
    case privateLinkManageInfo(PresentationTheme, String)
    
    case publicLinkInfo(PresentationTheme, String)
    case publicLinkStatus(PresentationTheme, String, AddressNameValidationStatus)
    
    case existingLinksInfo(PresentationTheme, String)
    case existingLinkPeerItem(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Peer, ItemListPeerItemEditing, Bool)
    
    case additionalLinkHeader(PresentationTheme, String)
    case additionalLink(PresentationTheme, TelegramPeerUsername, Int32)
    case additionalLinkInfo(PresentationTheme, String)
    
    case joinToSendHeader(PresentationTheme, String)
    case joinToSendEveryone(PresentationTheme, String, Bool)
    case joinToSendMembers(PresentationTheme, String, Bool)
    
    case approveMembers(PresentationTheme, String, Bool)
    case approveMembersInfo(PresentationTheme, String)
    
    case forwardingHeader(PresentationTheme, String)
    case forwardingDisabled(PresentationTheme, String, Bool)
    case forwardingInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo:
                return ChannelVisibilitySection.type.rawValue
            case .linksLimitInfo:
                return ChannelVisibilitySection.limitInfo.rawValue
            case .publicLinkHeader, .publicLinkAvailability, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkInfo, .publicLinkStatus:
                return ChannelVisibilitySection.link.rawValue
            case .additionalLinkHeader, .additionalLink, .additionalLinkInfo:
                return ChannelVisibilitySection.additional.rawValue
            case .privateLinkManage, .privateLinkManageInfo:
                return ChannelVisibilitySection.linkActions.rawValue
            case .existingLinksInfo, .existingLinkPeerItem:
                return ChannelVisibilitySection.link.rawValue
            case .joinToSendHeader, .joinToSendEveryone, .joinToSendMembers:
                return ChannelVisibilitySection.joinToSend.rawValue
            case .approveMembers, .approveMembersInfo:
                return ChannelVisibilitySection.approveMembers.rawValue
            case .forwardingHeader, .forwardingDisabled, .forwardingInfo:
                return ChannelVisibilitySection.forwarding.rawValue
        }
    }
    
    var stableId: ChannelVisibilityEntryId {
        switch self {
            case .typeHeader:
            return .index(0)
            case .typePublic:
                return .index(1)
            case .typePrivate:
                return .index(2)
            case .typeInfo:
                return .index(3)
            case .publicLinkHeader:
                return .index(4)
            case .publicLinkAvailability:
                return .index(5)
            case .linksLimitInfo:
                return .index(6)
            case .privateLinkHeader:
                return .index(7)
            case .privateLink:
                return .index(8)
            case .editablePublicLink:
                return .index(9)
            case .privateLinkInfo:
                return .index(10)
            case .publicLinkStatus:
                return .index(11)
            case .publicLinkInfo:
                return .index(12)
            case .existingLinksInfo:
                return .index(13)
            case let .existingLinkPeerItem(index, _, _, _, _, _, _, _):
                return .index(14 + index)
            case .additionalLinkHeader:
                return .index(1000)
            case let .additionalLink(_, username, _):
                return .username(username.username)
            case .additionalLinkInfo:
                return .index(2000)
            case .privateLinkManage:
                return .index(2001)
            case .privateLinkManageInfo:
                return .index(2002)
            case .joinToSendHeader:
                return .index(2003)
            case .joinToSendEveryone:
                return .index(2004)
            case .joinToSendMembers:
                return .index(2005)
            case .approveMembers:
                return .index(2006)
            case .approveMembersInfo:
                return .index(2007)
            case .forwardingHeader:
                return .index(2008)
            case .forwardingDisabled:
                return .index(2009)
            case .forwardingInfo:
                return .index(2010)
        }
    }
    
    static func ==(lhs: ChannelVisibilityEntry, rhs: ChannelVisibilityEntry) -> Bool {
        switch lhs {
            case let .typeHeader(lhsTheme, lhsTitle):
                if case let .typeHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .typePublic(lhsTheme, lhsTitle, lhsSelected):
                if case let .typePublic(rhsTheme, rhsTitle, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .typePrivate(lhsTheme, lhsTitle, lhsSelected):
                if case let .typePrivate(rhsTheme, rhsTitle, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .typeInfo(lhsTheme, lhsText):
                if case let .typeInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .publicLinkHeader(lhsTheme, lhsTitle):
                if case let .publicLinkHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .publicLinkAvailability(lhsTheme, lhsText, lhsValue):
                if case let .publicLinkAvailability(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .linksLimitInfo(lhsTheme, lhsText, lhsCount, lhsLimit, lhsPremiumLimit, lhsIsPremiumDisabled):
                if case let .linksLimitInfo(rhsTheme, rhsText, rhsCount, rhsLimit, rhsPremiumLimit, rhsIsPremiumDisabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsCount == rhsCount, lhsLimit == rhsLimit, lhsPremiumLimit == rhsPremiumLimit, lhsIsPremiumDisabled == rhsIsPremiumDisabled {
                    return true
                } else {
                    return false
                }
            case let .additionalLinkHeader(lhsTheme, lhsText):
                if case let .additionalLinkHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .additionalLink(lhsTheme, lhsAddressName, lhsIndex):
                if case let .additionalLink(rhsTheme, rhsAddressName, rhsIndex) = rhs, lhsTheme === rhsTheme, lhsAddressName == rhsAddressName, lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
            case let .additionalLinkInfo(lhsTheme, lhsText):
                if case let .additionalLinkInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .privateLinkHeader(lhsTheme, lhsTitle):
                if case let .privateLinkHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .privateLink(lhsTheme, lhsInvite, lhsPeers, lhsImportersCount, lhsDisplayImporters):
                if case let .privateLink(rhsTheme, rhsInvite, rhsPeers, rhsImportersCount, rhsDisplayImporters) = rhs, lhsTheme === rhsTheme, lhsInvite == rhsInvite, lhsPeers == rhsPeers, lhsImportersCount == rhsImportersCount, lhsDisplayImporters == rhsDisplayImporters {
                    return true
                } else {
                    return false
                }
            case let .editablePublicLink(lhsTheme, lhsStrings, lhsPlaceholder, lhsCurrentText):
                if case let .editablePublicLink(rhsTheme, rhsStrings, rhsPlaceholder, rhsCurrentText) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsPlaceholder == rhsPlaceholder, lhsCurrentText == rhsCurrentText {
                    return true
                } else {
                    return false
                }
            case let .privateLinkInfo(lhsTheme, lhsText):
                if case let .privateLinkInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .privateLinkManage(lhsTheme, lhsText):
                if case let .privateLinkManage(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .privateLinkManageInfo(lhsTheme, lhsText):
                if case let .privateLinkManageInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .publicLinkInfo(lhsTheme, lhsText):
                if case let .publicLinkInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .publicLinkStatus(lhsTheme, lhsText, lhsStatus):
                if case let .publicLinkStatus(rhsTheme, rhsText, rhsStatus) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsStatus == rhsStatus {
                    return true
                } else {
                    return false
                }
            case let .existingLinksInfo(lhsTheme, lhsText):
                if case let .existingLinksInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .existingLinkPeerItem(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsPeer, lhsEditing, lhsEnabled):
                if case let .existingLinkPeerItem(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsPeer, rhsEditing, rhsEnabled) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if lhsNameOrder != rhsNameOrder {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .joinToSendHeader(lhsTheme, lhsText):
                if case let .joinToSendHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .joinToSendEveryone(lhsTheme, lhsText, lhsValue):
                if case let .joinToSendEveryone(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .joinToSendMembers(lhsTheme, lhsText, lhsValue):
                if case let .joinToSendMembers(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .approveMembers(lhsTheme, lhsText, lhsValue):
                if case let .approveMembers(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .approveMembersInfo(lhsTheme, lhsText):
                if case let .approveMembersInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .forwardingHeader(lhsTheme, lhsText):
                if case let .forwardingHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .forwardingDisabled(lhsTheme, lhsText, lhsValue):
                if case let .forwardingDisabled(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .forwardingInfo(lhsTheme, lhsText):
                if case let .forwardingInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
        
    static func <(lhs: ChannelVisibilityEntry, rhs: ChannelVisibilityEntry) -> Bool {
        switch lhs {
        case .typeHeader:
            switch rhs {
            case  .typeHeader:
                return false
            default:
                return true
            }
        case .typePublic:
            switch rhs {
            case .typeHeader, .typePublic:
                return false
            default:
                return true
            }
        case .typePrivate:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate:
                return false
            default:
                return true
            }
        case .typeInfo:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo:
                return false
            default:
                return true
            }
        case .publicLinkHeader:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader:
                return false
            default:
                return true
            }
        case .publicLinkAvailability:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability:
                return false
            default:
                return true
            }
        case .linksLimitInfo:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo:
                return false
            default:
                return true
            }
        case .privateLinkHeader:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader:
                return false
            default:
                return true
            }
        case .privateLink:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink:
                return false
            default:
                return true
            }
        case .editablePublicLink:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink:
                return false
            default:
                return true
            }
        case .privateLinkInfo:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo:
                return false
            default:
                return true
            }
        case .publicLinkStatus:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus:
                return false
            default:
                return true
            }
        case .publicLinkInfo:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo:
                return false
            default:
                return true
            }
        case .existingLinksInfo:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo:
                return false
            default:
                return true
            }
        case let .existingLinkPeerItem(lhsIndex, _, _, _, _, _, _, _):
            switch rhs {
            case let .existingLinkPeerItem(rhsIndex, _, _, _, _, _, _, _):
                return lhsIndex < rhsIndex
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo:
                return false
            default:
                return true
            }
        case .additionalLinkHeader:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader:
                return false
            default:
                return true
            }
        case let .additionalLink(_, _, lhsIndex):
            switch rhs {
            case let .additionalLink(_, _, rhsIndex):
                return lhsIndex < rhsIndex
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader:
                return false
            default:
                return true
            }
        case .additionalLinkInfo:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo:
                return false
            default:
                return true
            }
        case .privateLinkManage:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo, .privateLinkManage:
                return false
            default:
                return true
            }
        case .privateLinkManageInfo:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo, .privateLinkManage, .privateLinkManageInfo:
                return false
            default:
                return true
            }
        case .joinToSendHeader:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo, .privateLinkManage, .privateLinkManageInfo, .joinToSendHeader:
                return false
            default:
                return true
            }
        case .joinToSendEveryone:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo, .privateLinkManage, .privateLinkManageInfo, .joinToSendHeader, .joinToSendEveryone:
                return false
            default:
                return true
            }
        case .joinToSendMembers:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo, .privateLinkManage, .privateLinkManageInfo, .joinToSendHeader, .joinToSendEveryone, .joinToSendMembers:
                return false
            default:
                return true
            }
        case .approveMembers:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo, .privateLinkManage, .privateLinkManageInfo, .joinToSendHeader, .joinToSendEveryone, .joinToSendMembers, .approveMembers:
                return false
            default:
                return true
            }
        case .approveMembersInfo:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo, .privateLinkManage, .privateLinkManageInfo, .joinToSendHeader, .joinToSendEveryone, .joinToSendMembers, .approveMembers, .approveMembersInfo:
                return false
            default:
                return true
            }
        case .forwardingHeader:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo, .privateLinkManage, .privateLinkManageInfo, .joinToSendHeader, .joinToSendEveryone, .joinToSendMembers, .approveMembers, .approveMembersInfo, .forwardingHeader:
                return false
            default:
                return true
            }
        case .forwardingDisabled:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo, .privateLinkManage, .privateLinkManageInfo, .joinToSendHeader, .joinToSendEveryone, .joinToSendMembers, .approveMembers, .approveMembersInfo, .forwardingHeader, .forwardingDisabled:
                return false
            default:
                return true
            }
        case .forwardingInfo:
            switch rhs {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo, .publicLinkHeader, .publicLinkAvailability, .linksLimitInfo, .privateLinkHeader, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkStatus, .publicLinkInfo, .existingLinksInfo, .existingLinkPeerItem, .additionalLinkHeader, .additionalLink, .additionalLinkInfo, .privateLinkManage, .privateLinkManageInfo, .joinToSendHeader, .joinToSendEveryone, .joinToSendMembers, .approveMembers, .approveMembersInfo, .forwardingHeader, .forwardingDisabled, .forwardingInfo:
                return false
            }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelVisibilityControllerArguments
        switch self {
            case let .typeHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .typePublic(_, text, selected):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCurrentType(.publicChannel)
                })
            case let .typePrivate(_, text, selected):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCurrentType(.privateChannel)
                })
            case let .typeInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .publicLinkHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .publicLinkAvailability(theme, text, value):
                let attr = NSMutableAttributedString(string: text, textColor: value ? theme.list.freeTextColor : theme.list.freeTextErrorColor)
                attr.addAttribute(.font, value: Font.regular(13), range: NSMakeRange(0, attr.length))
                return ItemListActivityTextItem(displayActivity: value, presentationData: presentationData, text: attr, sectionId: self.section)
            case let .linksLimitInfo(theme, text, count, limit, premiumLimit, isPremiumDisabled):
                return IncreaseLimitHeaderItem(theme: theme, strings: presentationData.strings, icon: .link, count: count, limit: limit, premiumCount: premiumLimit, text: text, isPremiumDisabled: isPremiumDisabled, sectionId: self.section)
            case let .privateLinkHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .privateLink(_, invite, peers, importersCount, displayImporters):
                return ItemListPermanentInviteLinkItem(context: arguments.context, presentationData: presentationData, invite: invite, count: importersCount, peers: peers, displayButton: true, displayImporters: displayImporters, buttonColor: nil, sectionId: self.section, style: .blocks, copyAction: {
                    if let invite = invite {
                        arguments.copyLink(invite)
                    }
                }, shareAction: {
                    if let invite = invite {
                        arguments.shareLink(invite)
                    }
                }, contextAction: { node, gesture in
                    arguments.linkContextAction(node, gesture)
                }, viewAction: {
                    if let invite = invite {
                        arguments.openLink(invite)
                    }
                })
            case let .editablePublicLink(theme, _, placeholder, currentText):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "t.me/", textColor: theme.list.itemPrimaryTextColor), text: currentText, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), clearType: .always, tag: ChannelVisibilityEntryTag.publicLink, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePublicLinkText(currentText, updatedText)
                }, updatedFocus: { focus in
                    if focus {
                        arguments.scrollToPublicLinkText()
                    }
                }, action: {
                })
            case let .privateLinkInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .privateLinkManage(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.linkIcon(theme), title: text, sectionId: self.section, editing: false, action: {
                    arguments.manageInviteLinks()
                })
            case let .privateLinkManageInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .publicLinkInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .publicLinkStatus(theme, text, status):
                var displayActivity = false
                let color: UIColor
                switch status {
                    case .invalidFormat:
                        color = theme.list.freeTextErrorColor
                    case let .availability(availability):
                        switch availability {
                            case .available:
                                color = theme.list.freeTextSuccessColor
                            case .invalid:
                                color = theme.list.freeTextErrorColor
                            case .taken:
                                color = theme.list.freeTextErrorColor
                        }
                    case .checking:
                        color = theme.list.freeTextColor
                        displayActivity = true
                }
                return ItemListActivityTextItem(displayActivity: displayActivity, presentationData: presentationData, text: NSAttributedString(string: text, textColor: color), sectionId: self.section)
            case let .existingLinksInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .existingLinkPeerItem(_, _, _, dateTimeFormat, nameDisplayOrder, peer, editing, enabled):
                var label = ""
                if let addressName = peer.addressName {
                    label = "t.me/" + addressName
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(peer), presence: nil, text: .text(label, .secondary), label: .none, editing: editing, switchValue: nil, enabled: enabled, selectable: true, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.revokePeerId(peerId)
                })
            case let .additionalLinkHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .additionalLink(_, link, _):
                return AdditionalLinkItem(presentationData: presentationData, username: link, sectionId: self.section, style: .blocks, tapAction: {
                    if !link.flags.contains(.isEditable) {
                        if link.flags.contains(.isActive) {
                            arguments.deactivateLink(link.username)
                        } else {
                            arguments.activateLink(link.username)
                        }
                    }
                })
            case let .additionalLinkInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .joinToSendHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .joinToSendEveryone(_, text, selected):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateJoinToSend(.everyone)
                    arguments.toggleApproveMembers(false)
                })
            case let .joinToSendMembers(_, text, selected):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateJoinToSend(.members)
                })
            case let .approveMembers(_, text, selected):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: selected, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleApproveMembers(value)
                })
            case let .approveMembersInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .forwardingHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .forwardingDisabled(_, text, selected):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: selected, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleForwarding(!value)
                })
            case let .forwardingInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private enum CurrentChannelType {
    case publicChannel
    case privateChannel
}

private enum CurrentChannelLocation: Equatable {
    case removed
    case location(PeerGeoLocation)
}

private enum CurrentChannelJoinToSend {
    case everyone
    case members
}

private struct ChannelVisibilityControllerState: Equatable {
    let selectedType: CurrentChannelType?
    let editingPublicLinkText: String?
    let addressNameValidationStatus: AddressNameValidationStatus?
    let updatingAddressName: Bool
    let revealedRevokePeerId: PeerId?
    let revokingPeerId: PeerId?
    let revokingPrivateLink: Bool
    let forwardingEnabled: Bool?
    let joinToSend: CurrentChannelJoinToSend?
    let approveMembers: Bool?
    
    init() {
        self.selectedType = nil
        self.editingPublicLinkText = nil
        self.addressNameValidationStatus = nil
        self.updatingAddressName = false
        self.revealedRevokePeerId = nil
        self.revokingPeerId = nil
        self.revokingPrivateLink = false
        self.forwardingEnabled = nil
        self.joinToSend = nil
        self.approveMembers = nil
    }
    
    init(selectedType: CurrentChannelType?, editingPublicLinkText: String?, addressNameValidationStatus: AddressNameValidationStatus?, updatingAddressName: Bool, revealedRevokePeerId: PeerId?, revokingPeerId: PeerId?, revokingPrivateLink: Bool, forwardingEnabled: Bool?, joinToSend: CurrentChannelJoinToSend?, approveMembers: Bool?) {
        self.selectedType = selectedType
        self.editingPublicLinkText = editingPublicLinkText
        self.addressNameValidationStatus = addressNameValidationStatus
        self.updatingAddressName = updatingAddressName
        self.revealedRevokePeerId = revealedRevokePeerId
        self.revokingPeerId = revokingPeerId
        self.revokingPrivateLink = revokingPrivateLink
        self.forwardingEnabled = forwardingEnabled
        self.joinToSend = joinToSend
        self.approveMembers = approveMembers
    }
    
    static func ==(lhs: ChannelVisibilityControllerState, rhs: ChannelVisibilityControllerState) -> Bool {
        if lhs.selectedType != rhs.selectedType {
            return false
        }
        if lhs.editingPublicLinkText != rhs.editingPublicLinkText {
            return false
        }
        if lhs.addressNameValidationStatus != rhs.addressNameValidationStatus {
            return false
        }
        if lhs.updatingAddressName != rhs.updatingAddressName {
            return false
        }
        if lhs.revealedRevokePeerId != rhs.revealedRevokePeerId {
            return false
        }
        if lhs.revokingPeerId != rhs.revokingPeerId {
            return false
        }
        if lhs.revokingPrivateLink != rhs.revokingPrivateLink {
            return false
        }
        if lhs.forwardingEnabled != rhs.forwardingEnabled {
            return false
        }
        if lhs.joinToSend != rhs.joinToSend {
            return false
        }
        if lhs.approveMembers != rhs.approveMembers {
            return false
        }
        return true
    }
    
    func withUpdatedSelectedType(_ selectedType: CurrentChannelType?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId, revokingPrivateLink: self.revokingPrivateLink, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedEditingPublicLinkText(_ editingPublicLinkText: String?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId, revokingPrivateLink: self.revokingPrivateLink, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedAddressNameValidationStatus(_ addressNameValidationStatus: AddressNameValidationStatus?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId, revokingPrivateLink: self.revokingPrivateLink, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedUpdatingAddressName(_ updatingAddressName: Bool) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId, revokingPrivateLink: self.revokingPrivateLink, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedRevealedRevokePeerId(_ revealedRevokePeerId: PeerId?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revealedRevokePeerId: revealedRevokePeerId, revokingPeerId: self.revokingPeerId, revokingPrivateLink: self.revokingPrivateLink, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedRevokingPeerId(_ revokingPeerId: PeerId?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: revokingPeerId, revokingPrivateLink: self.revokingPrivateLink, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedRevokingPrivateLink(_ revokingPrivateLink: Bool) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId, revokingPrivateLink: revokingPrivateLink, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedForwardingEnabled(_ forwardingEnabled: Bool) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId, revokingPrivateLink: self.revokingPrivateLink, forwardingEnabled: forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedJoinToSend(_ joinToSend: CurrentChannelJoinToSend?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId, revokingPrivateLink: self.revokingPrivateLink, forwardingEnabled: self.forwardingEnabled, joinToSend: joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedApproveMembers(_ approveMembers: Bool) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId, revokingPrivateLink: self.revokingPrivateLink, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: approveMembers)
    }
}

private func channelVisibilityControllerEntries(presentationData: PresentationData, mode: ChannelVisibilityControllerMode, view: PeerView, publicChannelsToRevoke: [Peer]?, importers: PeerInvitationImportersState?, state: ChannelVisibilityControllerState, limits: EngineConfiguration.UserLimits, premiumLimits: EngineConfiguration.UserLimits, isPremium: Bool, isPremiumDisabled: Bool, temporaryOrder: [String]?) -> [ChannelVisibilityEntry] {
    var entries: [ChannelVisibilityEntry] = []
    
    let isInitialSetup: Bool
    if case .initialSetup = mode {
        isInitialSetup = true
    } else {
        isInitialSetup = false
    }
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var isGroup = false
        if case .group = peer.info {
            isGroup = true
        }
        
        let selectedType: CurrentChannelType
        if case .privateLink = mode {
            selectedType = .privateChannel
        } else {
            if let current = state.selectedType {
                selectedType = current
            } else {
                if let addressName = peer.addressName, !addressName.isEmpty {
                    selectedType = .publicChannel
                } else if let cachedChannelData = view.cachedData as? CachedChannelData, cachedChannelData.peerGeoLocation != nil  {
                    selectedType = .publicChannel
                } else if case .initialSetup = mode {
                    selectedType = .publicChannel
                } else {
                    selectedType = .privateChannel
                }
            }
        }
        
        let joinToSend: CurrentChannelJoinToSend
        if let current = state.joinToSend {
            joinToSend = current
        } else {
            if peer.flags.contains(.joinToSend) {
                joinToSend = .members
            } else {
                joinToSend = .everyone
            }
        }
        
        let approveMembers: Bool
        if let enabled = state.approveMembers {
            approveMembers = enabled
        } else {
            if peer.flags.contains(.requestToJoin) {
                approveMembers = true
            } else {
                approveMembers = false
            }
        }
        
        let forwardingEnabled: Bool
        if let enabled = state.forwardingEnabled {
            forwardingEnabled = enabled
        } else {
            if peer.flags.contains(.copyProtectionEnabled) {
                forwardingEnabled = false
            } else {
                forwardingEnabled = true
            }
        }
        
        let currentUsername: String
        if let current = state.editingPublicLinkText {
            currentUsername = current
        } else {
            if let username = peer.editableUsername {
                currentUsername = username
            } else {
                currentUsername = ""
            }
        }
        
        if let _ = (view.cachedData as? CachedChannelData)?.peerGeoLocation {
        } else {
            switch mode {
                case .privateLink, .revokeNames:
                    break
                case .initialSetup, .generic:
                    entries.append(.typeHeader(presentationData.theme, isGroup ? presentationData.strings.Group_Setup_TypeHeader.uppercased() : presentationData.strings.Channel_Edit_LinkItem.uppercased()))
                    entries.append(.typePublic(presentationData.theme, isGroup ? presentationData.strings.Group_Setup_TypePublic : presentationData.strings.Channel_Setup_LinkTypePublic, selectedType == .publicChannel))
                    entries.append(.typePrivate(presentationData.theme, isGroup ? presentationData.strings.Group_Setup_TypePrivate : presentationData.strings.Channel_Setup_LinkTypePrivate, selectedType == .privateChannel))
            
                    switch selectedType {
                        case .publicChannel:
                            if isGroup {
                                entries.append(.typeInfo(presentationData.theme, presentationData.strings.Group_Setup_TypePublicHelp))
                            } else {
                                entries.append(.typeInfo(presentationData.theme, presentationData.strings.Channel_Setup_TypePublicHelp))
                            }
                        case .privateChannel:
                            if isGroup {
                                entries.append(.typeInfo(presentationData.theme, presentationData.strings.Group_Setup_TypePrivateHelp))
                            } else {
                                entries.append(.typeInfo(presentationData.theme, presentationData.strings.Channel_Setup_TypePrivateHelp))
                            }
                    }
            }
        }
        
        let otherUsernames = peer.usernames.filter { !$0.flags.contains(.isEditable) }
        
        if case .revokeNames = mode {
            let count = Int32(publicChannelsToRevoke?.count ?? 0)
            
            let text: String
            if count >= premiumLimits.maxPublicLinksCount {
                text = presentationData.strings.Group_Username_RemoveExistingUsernamesFinalInfo
            } else {
                if isPremiumDisabled {
                    text = presentationData.strings.Group_Username_RemoveExistingUsernamesNoPremiumInfo
                } else {
                    text = presentationData.strings.Group_Username_RemoveExistingUsernamesOrExtendInfo("\(premiumLimits.maxPublicLinksCount)").string
                }
            }
            
            entries.append(.linksLimitInfo(presentationData.theme, text, count, limits.maxPublicLinksCount, premiumLimits.maxPublicLinksCount, isPremiumDisabled))
            
            if let publicChannelsToRevoke = publicChannelsToRevoke {
                var index: Int32 = 0
                for peer in publicChannelsToRevoke.sorted(by: { lhs, rhs in
                    var lhsDate: Int32 = 0
                    var rhsDate: Int32 = 0
                    if let lhs = lhs as? TelegramChannel {
                        lhsDate = lhs.creationDate
                    }
                    if let rhs = rhs as? TelegramChannel {
                        rhsDate = rhs.creationDate
                    }
                    return lhsDate > rhsDate
                }) {
                    entries.append(.existingLinkPeerItem(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, peer, ItemListPeerItemEditing(editable: true, editing: true, revealed: state.revealedRevokePeerId == peer.id), state.revokingPeerId == nil))
                    index += 1
                }
            }
        } else {
            switch selectedType {
                case .publicChannel:
                    entries.append(.editablePublicLink(presentationData.theme, presentationData.strings, presentationData.strings.Group_PublicLink_Placeholder, currentUsername))
                    if let status = state.addressNameValidationStatus {
                        let text: String
                        switch status {
                            case let .invalidFormat(error):
                                switch error {
                                    case .startsWithDigit:
                                        if isGroup {
                                            text = presentationData.strings.Group_Username_InvalidStartsWithNumber
                                        } else {
                                            text = presentationData.strings.Channel_Username_InvalidStartsWithNumber
                                        }
                                    case .startsWithUnderscore:
                                        if isGroup {
                                            text = presentationData.strings.Group_Username_InvalidStartsWithUnderscore
                                        } else {
                                            text = presentationData.strings.Channel_Username_InvalidStartsWithUnderscore
                                        }
                                    case .endsWithUnderscore:
                                        if isGroup {
                                            text = presentationData.strings.Group_Username_InvalidEndsWithUnderscore
                                        } else {
                                            text = presentationData.strings.Channel_Username_InvalidEndsWithUnderscore
                                        }
                                    case .tooShort:
                                        if isGroup {
                                            text = presentationData.strings.Group_Username_InvalidTooShort
                                        } else {
                                            text = presentationData.strings.Channel_Username_InvalidTooShort
                                        }
                                    case .invalidCharacters:
                                        text = presentationData.strings.Channel_Username_InvalidCharacters
                                }
                            case let .availability(availability):
                                switch availability {
                                    case .available:
                                        text = presentationData.strings.Channel_Username_UsernameIsAvailable(currentUsername).string
                                    case .invalid:
                                        text = presentationData.strings.Channel_Username_InvalidCharacters
                                    case .taken:
                                        text = presentationData.strings.Channel_Username_InvalidTaken
                                }
                            case .checking:
                                text = presentationData.strings.Channel_Username_CheckingUsername
                        }
                        
                        entries.append(.publicLinkStatus(presentationData.theme, text, status))
                    }
                    if isGroup {
                        if let cachedChannelData = view.cachedData as? CachedChannelData, cachedChannelData.peerGeoLocation != nil {
                            entries.append(.publicLinkInfo(presentationData.theme, presentationData.strings.Group_PublicLink_Info))
                        } else {
                            entries.append(.publicLinkInfo(presentationData.theme, presentationData.strings.Group_Username_CreatePublicLinkHelp))
                        }
                    } else {
                        entries.append(.publicLinkInfo(presentationData.theme, presentationData.strings.Channel_Username_CreatePublicLinkHelp))
                    }
                
                    if !otherUsernames.isEmpty {
                        entries.append(.additionalLinkHeader(presentationData.theme, isGroup ? presentationData.strings.Group_Setup_LinksOrder : presentationData.strings.Channel_Setup_LinksOrder))
                        
                        var usernames = peer.usernames
                        if let temporaryOrder = temporaryOrder {
                            var usernamesMap: [String: TelegramPeerUsername] = [:]
                            for username in usernames {
                                usernamesMap[username.username] = username
                            }
                            var sortedUsernames: [TelegramPeerUsername] = []
                            for username in temporaryOrder {
                                if let username = usernamesMap[username] {
                                    sortedUsernames.append(username)
                                }
                            }
                            usernames = sortedUsernames
                        }
                        var i: Int32 = 0
                        for username in usernames {
                            entries.append(.additionalLink(presentationData.theme, username, i))
                            i += 1
                        }
                        
                        entries.append(.additionalLinkInfo(presentationData.theme, isGroup ? presentationData.strings.Group_Setup_LinksOrderInfo : presentationData.strings.Channel_Setup_LinksOrderInfo))
                    }
                
                    switch mode {
                        case .initialSetup, .revokeNames:
                            break
                        case .generic, .privateLink:
                            entries.append(.privateLinkManage(presentationData.theme, presentationData.strings.InviteLink_Manage))
                            entries.append(.privateLinkManageInfo(presentationData.theme, presentationData.strings.InviteLink_CreateInfo))
                    }
                case .privateChannel:
                    let invite = (view.cachedData as? CachedChannelData)?.exportedInvitation
                    entries.append(.privateLinkHeader(presentationData.theme, presentationData.strings.InviteLink_InviteLink.uppercased()))
                    entries.append(.privateLink(presentationData.theme, invite, importers?.importers.prefix(3).compactMap { $0.peer.peer.flatMap(EnginePeer.init) } ?? [], importers?.count ?? 0, !isInitialSetup))
                    if isGroup {
                        entries.append(.privateLinkInfo(presentationData.theme, presentationData.strings.Group_Username_CreatePrivateLinkHelp))
                    } else {
                        entries.append(.privateLinkInfo(presentationData.theme, presentationData.strings.Channel_Username_CreatePrivateLinkHelp))
                    }
                    switch mode {
                        case .initialSetup, .revokeNames:
                            break
                        case .generic, .privateLink:
                            entries.append(.privateLinkManage(presentationData.theme, presentationData.strings.InviteLink_Manage))
                            entries.append(.privateLinkManageInfo(presentationData.theme, presentationData.strings.InviteLink_CreateInfo))
                    }
            }
                        
            var isDiscussion = false
            if let cachedData = view.cachedData as? CachedChannelData, case let .known(peerId) = cachedData.linkedDiscussionPeerId, peerId != nil {
                isDiscussion = true
            }
            
            if isGroup && (selectedType == .publicChannel || isDiscussion) {
                if isDiscussion {
                    entries.append(.joinToSendHeader(presentationData.theme, presentationData.strings.Group_Setup_WhoCanSendMessages_Title.uppercased()))
                    entries.append(.joinToSendEveryone(presentationData.theme, presentationData.strings.Group_Setup_WhoCanSendMessages_Everyone, joinToSend == .everyone))
                    entries.append(.joinToSendMembers(presentationData.theme, presentationData.strings.Group_Setup_WhoCanSendMessages_OnlyMembers, joinToSend == .members))
                }
                    
                if !isDiscussion || joinToSend == .members {
                    entries.append(.approveMembers(presentationData.theme, presentationData.strings.Group_Setup_ApproveNewMembers, approveMembers))
                    entries.append(.approveMembersInfo(presentationData.theme, presentationData.strings.Group_Setup_ApproveNewMembersInfo))
                }
            }
            
            entries.append(.forwardingHeader(presentationData.theme, isGroup ? presentationData.strings.Group_Setup_ForwardingGroupTitle.uppercased() : presentationData.strings.Group_Setup_ForwardingChannelTitle.uppercased()))
            entries.append(.forwardingDisabled(presentationData.theme, presentationData.strings.Group_Setup_ForwardingDisabled, !forwardingEnabled))
            entries.append(.forwardingInfo(presentationData.theme, forwardingEnabled ? (isGroup ? presentationData.strings.Group_Setup_ForwardingGroupInfo : presentationData.strings.Group_Setup_ForwardingChannelInfo) : (isGroup ? presentationData.strings.Group_Setup_ForwardingGroupInfoDisabled : presentationData.strings.Group_Setup_ForwardingChannelInfoDisabled)))
        }
    } else if let peer = view.peers[view.peerId] as? TelegramGroup {
        if case .revokeNames = mode {
            let count = Int32(publicChannelsToRevoke?.count ?? 0)
            
            let text: String
            if count >= premiumLimits.maxPublicLinksCount {
                text = presentationData.strings.Group_Username_RemoveExistingUsernamesFinalInfo
            } else {
                if isPremiumDisabled {
                    text = presentationData.strings.Group_Username_RemoveExistingUsernamesNoPremiumInfo
                } else {
                    text = presentationData.strings.Group_Username_RemoveExistingUsernamesOrExtendInfo("\(premiumLimits.maxPublicLinksCount)").string
                }
            }
            
            entries.append(.linksLimitInfo(presentationData.theme, text, count, limits.maxPublicLinksCount, premiumLimits.maxPublicLinksCount, isPremiumDisabled))
            
            if let publicChannelsToRevoke = publicChannelsToRevoke {
                var index: Int32 = 0
                for peer in publicChannelsToRevoke.sorted(by: { lhs, rhs in
                    var lhsDate: Int32 = 0
                    var rhsDate: Int32 = 0
                    if let lhs = lhs as? TelegramChannel {
                        lhsDate = lhs.creationDate
                    }
                    if let rhs = rhs as? TelegramChannel {
                        rhsDate = rhs.creationDate
                    }
                    return lhsDate > rhsDate
                }) {
                    entries.append(.existingLinkPeerItem(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, peer, ItemListPeerItemEditing(editable: true, editing: true, revealed: state.revealedRevokePeerId == peer.id), state.revokingPeerId == nil))
                    index += 1
                }
            }
        } else {
            switch mode {
                case .revokeNames:
                    break
                case .privateLink:
                    let invite = (view.cachedData as? CachedGroupData)?.exportedInvitation
                    entries.append(.privateLinkHeader(presentationData.theme, presentationData.strings.InviteLink_InviteLink.uppercased()))
                    entries.append(.privateLink(presentationData.theme, invite, importers?.importers.prefix(3).compactMap { $0.peer.peer.flatMap(EnginePeer.init) } ?? [], importers?.count ?? 0, !isInitialSetup))
                    entries.append(.privateLinkInfo(presentationData.theme, presentationData.strings.GroupInfo_InviteLink_Help))
                    switch mode {
                        case .initialSetup, .revokeNames:
                            break
                        case .generic, .privateLink:
                            entries.append(.privateLinkManage(presentationData.theme, presentationData.strings.InviteLink_Manage))
                            entries.append(.privateLinkManageInfo(presentationData.theme, presentationData.strings.InviteLink_CreateInfo))
                    }
                case .generic, .initialSetup:
                    let selectedType: CurrentChannelType
                    if let current = state.selectedType {
                        selectedType = current
                    } else {
                        selectedType = .privateChannel
                    }
                    
                    let currentUsername: String
                    if let current = state.editingPublicLinkText {
                        currentUsername = current
                    } else {
                        currentUsername = ""
                    }
                    
                    entries.append(.typeHeader(presentationData.theme, presentationData.strings.Group_Setup_TypeHeader.uppercased()))
                    entries.append(.typePublic(presentationData.theme, presentationData.strings.Channel_Setup_TypePublic, selectedType == .publicChannel))
                    entries.append(.typePrivate(presentationData.theme, presentationData.strings.Channel_Setup_TypePrivate, selectedType == .privateChannel))
                    
                    switch selectedType {
                    case .publicChannel:
                        entries.append(.typeInfo(presentationData.theme, presentationData.strings.Group_Setup_TypePublicHelp))
                    case .privateChannel:
                        entries.append(.typeInfo(presentationData.theme, presentationData.strings.Group_Setup_TypePrivateHelp))
                    }
                    
                    switch selectedType {
                        case .publicChannel:
                            entries.append(.editablePublicLink(presentationData.theme, presentationData.strings, "", currentUsername))
                            if let status = state.addressNameValidationStatus {
                                let text: String
                                switch status {
                                case let .invalidFormat(error):
                                    switch error {
                                        case .startsWithDigit:
                                            text = presentationData.strings.Group_Username_InvalidStartsWithNumber
                                        case .startsWithUnderscore:
                                            text = presentationData.strings.Channel_Username_InvalidStartsWithUnderscore
                                        case .endsWithUnderscore:
                                            text = presentationData.strings.Channel_Username_InvalidEndsWithUnderscore
                                        case .tooShort:
                                            text = presentationData.strings.Group_Username_InvalidTooShort
                                        case .invalidCharacters:
                                            text = presentationData.strings.Channel_Username_InvalidCharacters
                                        }
                                case let .availability(availability):
                                    switch availability {
                                    case .available:
                                        text = presentationData.strings.Channel_Username_UsernameIsAvailable(currentUsername).string
                                    case .invalid:
                                        text = presentationData.strings.Channel_Username_InvalidCharacters
                                    case .taken:
                                        text = presentationData.strings.Channel_Username_InvalidTaken
                                    }
                                case .checking:
                                    text = presentationData.strings.Channel_Username_CheckingUsername
                                }
                                
                                entries.append(.publicLinkStatus(presentationData.theme, text, status))
                            }
                            
                            entries.append(.publicLinkInfo(presentationData.theme, presentationData.strings.Group_Username_CreatePublicLinkHelp))
                        case .privateChannel:
                            let invite = (view.cachedData as? CachedGroupData)?.exportedInvitation
                            entries.append(.privateLinkHeader(presentationData.theme, presentationData.strings.InviteLink_InviteLink.uppercased()))
                            entries.append(.privateLink(presentationData.theme, invite, importers?.importers.prefix(3).compactMap { $0.peer.peer.flatMap(EnginePeer.init) } ?? [], importers?.count ?? 0, !isInitialSetup))
                            entries.append(.privateLinkInfo(presentationData.theme, presentationData.strings.Group_Username_CreatePrivateLinkHelp))
                            switch mode {
                                case .initialSetup, .revokeNames:
                                    break
                                case .generic, .privateLink:
                                    entries.append(.privateLinkManage(presentationData.theme, presentationData.strings.InviteLink_Manage))
                                    entries.append(.privateLinkManageInfo(presentationData.theme, presentationData.strings.InviteLink_CreateInfo))
                            }
                }
            }
            
            let forwardingEnabled: Bool
            if let enabled = state.forwardingEnabled {
                forwardingEnabled = enabled
            } else {
                if peer.flags.contains(.copyProtectionEnabled) {
                    forwardingEnabled = false
                } else {
                    forwardingEnabled = true
                }
            }
            
            entries.append(.forwardingHeader(presentationData.theme, presentationData.strings.Group_Setup_ForwardingGroupTitle.uppercased()))
            entries.append(.forwardingDisabled(presentationData.theme, presentationData.strings.Group_Setup_ForwardingDisabled, !forwardingEnabled))
            entries.append(.forwardingInfo(presentationData.theme, forwardingEnabled ? presentationData.strings.Group_Setup_ForwardingGroupInfo : presentationData.strings.Group_Setup_ForwardingGroupInfoDisabled))
        }
    }
    
    return entries
}

private func effectiveChannelType(mode: ChannelVisibilityControllerMode, state: ChannelVisibilityControllerState, peer: TelegramChannel, cachedData: CachedPeerData?) -> CurrentChannelType {
    let selectedType: CurrentChannelType
    if let current = state.selectedType {
        selectedType = current
    } else {
        if let addressName = peer.addressName, !addressName.isEmpty {
            selectedType = .publicChannel
        } else if let cachedChannelData = cachedData as? CachedChannelData, cachedChannelData.peerGeoLocation != nil {
            selectedType = .publicChannel
        } else if case .initialSetup = mode {
            selectedType = .publicChannel
        } else {
            selectedType = .privateChannel
        }
    }
    return selectedType
}

private func updatedAddressName(mode: ChannelVisibilityControllerMode, state: ChannelVisibilityControllerState, peer: Peer, cachedData: CachedPeerData?) -> String? {
    if let peer = peer as? TelegramChannel {
        let selectedType = effectiveChannelType(mode: mode, state: state, peer: peer, cachedData: cachedData)
        
        let currentUsername: String
        
        switch selectedType {
            case .privateChannel:
                currentUsername = ""
            case .publicChannel:
                if let current = state.editingPublicLinkText {
                    currentUsername = current
                } else {
                    if let username = peer.editableUsername {
                        currentUsername = username
                    } else {
                        currentUsername = ""
                    }
                }
        }
        
        if !currentUsername.isEmpty {
            if currentUsername != peer.editableUsername {
                return currentUsername
            } else {
                return nil
            }
        } else if peer.editableUsername != nil {
            return ""
        } else {
            return nil
        }
    } else if let _ = peer as? TelegramGroup {
        let currentUsername = state.editingPublicLinkText ?? ""
        if !currentUsername.isEmpty {
            return currentUsername
        } else {
            return nil
        }
    } else {
        return nil
    }
}

public enum ChannelVisibilityControllerMode {
    case initialSetup
    case generic
    case privateLink
    case revokeNames([Peer])
}

public func channelVisibilityController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, mode: ChannelVisibilityControllerMode, upgradedToSupergroup: @escaping (PeerId, @escaping () -> Void) -> Void, onDismissRemoveController: ViewController? = nil, revokedPeerAddressName: ((PeerId) -> Void)? = nil) -> ViewController {
    let statePromise = ValuePromise(ChannelVisibilityControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelVisibilityControllerState())
    let updateState: ((ChannelVisibilityControllerState) -> ChannelVisibilityControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let adminedPublicChannels = Promise<[Peer]?>()
    if case let .revokeNames(peers) = mode {
        adminedPublicChannels.set(.single(peers))
    } else {
        adminedPublicChannels.set(context.engine.peers.adminedPublicChannels(scope: .all)
        |> map(Optional.init))
    }
    
    let peersDisablingAddressNameAssignment = Promise<[Peer]?>()
    peersDisablingAddressNameAssignment.set(.single(nil) |> then(context.engine.peers.channelAddressNameAssignmentAvailability(peerId: peerId.namespace == Namespaces.Peer.CloudChannel ? peerId : nil) |> mapToSignal { result -> Signal<[Peer]?, NoError> in
        if case .addressNameLimitReached = result {
            return context.engine.peers.adminedPublicChannels(scope: .all)
            |> map(Optional.init)
        } else {
            return .single([])
        }
    }))
    
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var nextImpl: (() -> Void)?
    var scrollToPublicLinkTextImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    var getControllerImpl: (() -> ViewController?)?
    
    var dismissTooltipsImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let updateAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(updateAddressNameDisposable)
    
    let revokeAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(revokeAddressNameDisposable)
    
    let deactivateAllAddressNamesDisposable = MetaDisposable()
    actionsDisposable.add(deactivateAllAddressNamesDisposable)
    
    let revokeLinkDisposable = MetaDisposable()
    actionsDisposable.add(revokeLinkDisposable)
    
    let toggleCopyProtectionDisposable = MetaDisposable()
    actionsDisposable.add(toggleCopyProtectionDisposable)
    
    let toggleJoinToSendDisposable = MetaDisposable()
    actionsDisposable.add(toggleJoinToSendDisposable)
    
    let toggleRequestToJoinDisposable = MetaDisposable()
    actionsDisposable.add(toggleRequestToJoinDisposable)
    
    let temporaryOrder = Promise<[String]?>(nil)
    
    let arguments = ChannelVisibilityControllerArguments(context: context, updateCurrentType: { type in
        if type == .publicChannel {
            let _ = combineLatest(
                queue: Queue.mainQueue(),
                adminedPublicChannels.get() |> filter { $0 != nil } |> take(1),
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
                context.engine.data.get(
                    TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                    TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
                )
            ).start(next: { peers, accountPeer, peer, data in
                let (limits, premiumLimits) = data
                let isPremium = accountPeer?.isPremium ?? false
                
                let hasAdditionalUsernames = (peer?._asPeer().usernames.firstIndex(where: { !$0.flags.contains(.isEditable) }) ?? nil) != nil
                
                if let peers = peers {
                    let count = Int32(peers.count)
                    if count < limits.maxPublicLinksCount || (count < premiumLimits.maxPublicLinksCount && isPremium) || hasAdditionalUsernames {
                        updateState { state in
                            return state.withUpdatedSelectedType(type)
                        }
                    } else {
                        let controller = channelVisibilityController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, mode: .revokeNames(peers), upgradedToSupergroup: { _, _ in }, revokedPeerAddressName: { revokedPeerId in
                            let updatedPublicChannels = peers.filter { $0.id != revokedPeerId }
                            adminedPublicChannels.set(.single(updatedPublicChannels) |> then(
                                context.engine.peers.adminedPublicChannels(scope: .all) |> map(Optional.init))
                            )
                        })
                        controller.navigationPresentation = .modal
                        pushControllerImpl?(controller)
                    }
                } else {
                }
            })
        } else {
            updateState { state in
                return state.withUpdatedSelectedType(type)
            }
        }
    }, updatePublicLinkText: { currentText, text in
        if text.isEmpty {
            checkAddressNameDisposable.set(nil)
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text).withUpdatedAddressNameValidationStatus(nil)
            }
        } else if currentText == text {
            checkAddressNameDisposable.set(nil)
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text).withUpdatedAddressNameValidationStatus(nil).withUpdatedAddressNameValidationStatus(nil)
            }
        } else {
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text)
            }
            
            checkAddressNameDisposable.set((context.engine.peers.validateAddressNameInteractive(domain: .peer(peerId), name: text)
            |> deliverOnMainQueue).start(next: { result in
                updateState { state in
                    return state.withUpdatedAddressNameValidationStatus(result)
                }
            }))
        }
    }, scrollToPublicLinkText: {
        scrollToPublicLinkTextImpl?()
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.revealedRevokePeerId) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedRevealedRevokePeerId(peerId)
            } else {
                return state
            }
        }
    }, revokePeerId: { peerId in
        updateState { state in
            return state.withUpdatedRevokingPeerId(peerId)
        }
        
        revokeAddressNameDisposable.set((context.engine.peers.updateAddressName(domain: .peer(peerId), name: nil) |> deliverOnMainQueue).start(error: { _ in
            updateState { state in
                return state.withUpdatedRevokingPeerId(nil)
            }
        }, completed: {
            revokedPeerAddressName?(peerId)
            dismissImpl?()
        }))
    }, copyLink: { invite in
        UIPasteboard.general.string = invite.link
       
        dismissTooltipsImpl?()
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
    }, shareLink: { invite in
        guard let inviteLink = invite.link else {
            return
        }
        let shareController = ShareController(context: context, subject: .url(inviteLink), updatedPresentationData: updatedPresentationData)
        shareController.actionCompleted = {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
        }
        presentControllerImpl?(shareController, nil)
    }, linkContextAction: { node, gesture in
        guard let node = node as? ContextReferenceContentNode, let controller = getControllerImpl?() else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var items: [ContextMenuItem] = []

        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ExportedInvitation(id: peerId))
            |> deliverOnMainQueue).start(next: { exportedInvitation in
                if let link = exportedInvitation?.link {
                    UIPasteboard.general.string = link
                    
                    dismissTooltipsImpl?()
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                }
            })
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ExportedInvitation(id: peerId))
            |> deliverOnMainQueue).start(next: { invite in
                if let invite = invite {
                    let _ = (context.account.postbox.loadedPeerWithId(peerId)
                    |> deliverOnMainQueue).start(next: { peer in
                        let isGroup: Bool
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            isGroup = false
                        } else {
                            isGroup = true
                        }
                        presentControllerImpl?(QrCodeScreen(context: context, updatedPresentationData: updatedPresentationData, subject: .invite(invite: invite, isGroup: isGroup)), nil)
                    })
                }
            })
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextRevoke, textColor: .destructive, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
        
            let _ = (context.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { peer in
                let isGroup: Bool
                if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                    isGroup = false
                } else {
                    isGroup = true
                }
                
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: isGroup ? presentationData.strings.GroupInfo_InviteLink_RevokeAlert_Text : presentationData.strings.ChannelInfo_InviteLink_RevokeAlert_Text),
                        ActionSheetButtonItem(title: presentationData.strings.GroupInfo_InviteLink_RevokeLink, color: .destructive, action: {
                            dismissAction()
                            
                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ExportedInvitation(id: peerId))
                            |> deliverOnMainQueue).start(next: { exportedInvitation in
                                if let link = exportedInvitation?.link {
                                    var revoke = false
                                    updateState { state in
                                        if !state.revokingPrivateLink {
                                            revoke = true
                                            return state.withUpdatedRevokingPrivateLink(true)
                                        } else {
                                            return state
                                        }
                                    }
                                    if revoke {
                                        revokeLinkDisposable.set((context.engine.peers.revokePeerExportedInvitation(peerId: peerId, link: link) |> deliverOnMainQueue).start(completed: {
                                            updateState {
                                                $0.withUpdatedRevokingPrivateLink(false)
                                            }
                                        }))
                                    }
                                }
                            })
                        })
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })
        })))

        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .reference(InviteLinkContextReferenceContentSource(controller: controller, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        presentInGlobalOverlayImpl?(contextController)
    }, manageInviteLinks: {
        let controller = inviteLinkListController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, admin: nil)
        pushControllerImpl?(controller)
    }, openLink: { invite in
        let controller = InviteLinkViewController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, invite: invite, invitationsContext: nil, revokedInvitationsContext: nil, importersContext: nil)
        pushControllerImpl?(controller)
    }, toggleForwarding: { value in
        updateState { state in
            return state.withUpdatedForwardingEnabled(value)
        }
    }, updateJoinToSend: { value in
        updateState { state in
            return state.withUpdatedJoinToSend(value)
        }
    }, toggleApproveMembers: { value in
        updateState { state in
            return state.withUpdatedApproveMembers(value)
        }
    }, activateLink: { name in
        dismissInputImpl?()
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { peer in
            let isGroup: Bool
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                isGroup = false
            } else {
                isGroup = true
            }

            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let title: String
            let text: String
            let action: String
            if isGroup {
                title = presentationData.strings.Group_Setup_ActivateAlertTitle
                text = presentationData.strings.Group_Setup_ActivateAlertText
                action = presentationData.strings.Group_Setup_ActivateAlertShow
            } else {
                title = presentationData.strings.Channel_Setup_ActivateAlertTitle
                text = presentationData.strings.Channel_Setup_ActivateAlertText
                action = presentationData.strings.Channel_Setup_ActivateAlertShow
            }
            presentControllerImpl?(textAlertController(context: context, title: title, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: action, action: {
                let _ = (context.engine.peers.toggleAddressNameActive(domain: .peer(peerId), name: name, active: true)
                |> deliverOnMainQueue).start(error: { error in
                    let errorText: String
                    switch error {
                    case .activeLimitReached:
                        if isGroup {
                            errorText = presentationData.strings.Group_Setup_ActiveLimitReachedError
                        } else {
                            errorText = presentationData.strings.Channel_Setup_ActiveLimitReachedError
                        }
                    default:
                        errorText = presentationData.strings.Login_UnknownError
                    }
                    presentControllerImpl?(textAlertController(context: context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                })
            })]), nil)
        })
    }, deactivateLink: { name in
        dismissInputImpl?()
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { peer in
            let isGroup: Bool
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                isGroup = false
            } else {
                isGroup = true
            }

            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let title: String
            let text: String
            let action: String

            if isGroup {
                title = presentationData.strings.Group_Setup_DeactivateAlertTitle
                text = presentationData.strings.Group_Setup_DeactivateAlertText
                action = presentationData.strings.Group_Setup_DeactivateAlertHide
            } else {
                title = presentationData.strings.Channel_Setup_DeactivateAlertTitle
                text = presentationData.strings.Channel_Setup_DeactivateAlertText
                action = presentationData.strings.Channel_Setup_DeactivateAlertHide
            }
            presentControllerImpl?(textAlertController(context: context, title: title, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: action, action: {
                let _ = context.engine.peers.toggleAddressNameActive(domain: .peer(peerId), name: name, active: false).start()
            })]), nil)
        })
    })
    
    let peerView = context.account.viewTracker.peerView(peerId)
    |> deliverOnMainQueue
    
    let previousHadNamesToRevoke = Atomic<Bool?>(value: nil)
    let previousInvitation = Atomic<ExportedInvitation?>(value: nil)
    let previousUsernames = Atomic<[String]?>(value: nil)
    
    let mainLink = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Peer.ExportedInvitation(id: peerId)
    )
    
    let importersState = Promise<PeerInvitationImportersState?>(nil)
    let importersContext: Signal<PeerInvitationImportersContext?, NoError> = mainLink
    |> distinctUntilChanged
    |> deliverOnMainQueue
    |> map { invite -> PeerInvitationImportersContext? in
        return invite.flatMap { context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .invite(invite: $0, requested: false)) }
    } |> afterNext { context in
        if let context = context {
            importersState.set(context.state |> map(Optional.init))
        } else {
            importersState.set(.single(nil))
        }
    }
    
    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(
        presentationData,
        statePromise.get() |> deliverOnMainQueue,
        peerView,
        adminedPublicChannels.get(),
        importersContext,
        importersState.get(),
        context.engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true),
            TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
        ),
        temporaryOrder.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, view, publicChannelsToRevoke, importersContext, importers, data, temporaryOrder -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let peer = peerViewMainPeer(view)
        
        let (limits, premiumLimits, accountPeer) = data
        let isPremium = accountPeer?.isPremium ?? false
        
        var footerItem: ItemListControllerFooterItem?
        
        var rightNavigationButton: ItemListNavigationButton?
        if case .revokeNames = mode {
            let count = Int32(publicChannelsToRevoke?.count ?? 0)
            if !premiumConfiguration.isPremiumDisabled && count < premiumLimits.maxPublicLinksCount {
                footerItem = IncreaseLimitFooterItem(theme: presentationData.theme, title: presentationData.strings.Premium_IncreaseLimit, colorful: true, action: {
                    let controller = PremiumIntroScreen(context: context, source: .publicLinks)
                    pushControllerImpl?(controller)
                })
            }
        } else {
            if let peer = peer as? TelegramChannel {
                var doneEnabled = true
                if let selectedType = state.selectedType {
                    switch selectedType {
                        case .privateChannel:
                            break
                        case .publicChannel:
                            var hasLocation = false
                            if let cachedChannelData = view.cachedData as? CachedChannelData, cachedChannelData.peerGeoLocation != nil {
                                hasLocation = true
                            }
                            
                            if let addressNameValidationStatus = state.addressNameValidationStatus {
                                switch addressNameValidationStatus {
                                    case .availability(.available):
                                        break
                                    default:
                                        doneEnabled = false
                                }
                            } else {
                                doneEnabled = !(peer.addressName?.isEmpty ?? true) || hasLocation
                            }
                    }
                }
                
                let isInitialSetup: Bool
                if case .initialSetup = mode {
                    isInitialSetup = true
                } else {
                    isInitialSetup = false
                }
                
                rightNavigationButton = ItemListNavigationButton(content: .text(isInitialSetup ? presentationData.strings.Common_Next : presentationData.strings.Common_Done), style: state.updatingAddressName ? .activity : .bold, enabled: doneEnabled, action: {
                    var updatedAddressNameValue: String?
                    updateState { state in
                        updatedAddressNameValue = updatedAddressName(mode: mode, state: state, peer: peer, cachedData: view.cachedData)
                        return state
                    }
                    
                    if let selectedType = state.selectedType, case .privateChannel = selectedType, peer.usernames.firstIndex(where: { $0.isActive && !$0.flags.contains(.isEditable) }) != nil {
                        deactivateAllAddressNamesDisposable.set(context.engine.peers.deactivateAllAddressNames(peerId: peerId).start())
                    }
                    
                    if let updatedCopyProtection = state.forwardingEnabled {
                        toggleCopyProtectionDisposable.set(context.engine.peers.toggleMessageCopyProtection(peerId: peerId, enabled: !updatedCopyProtection).start())
                    }
                    
                    if let updatedJoinToSend = state.joinToSend {
                        toggleJoinToSendDisposable.set(context.engine.peers.toggleChannelJoinToSend(peerId: peerId, enabled: updatedJoinToSend == .members).start())
                    }
                    
                    if let updatedApproveMembers = state.approveMembers {
                        toggleRequestToJoinDisposable.set(context.engine.peers.toggleChannelJoinRequest(peerId: peerId, enabled: updatedApproveMembers).start())
                    }
                    
                    if let updatedAddressNameValue = updatedAddressNameValue {
                        let invokeAction: () -> Void = {
                            updateState { state in
                                return state.withUpdatedUpdatingAddressName(true)
                            }
                            _ = ApplicationSpecificNotice.markAsSeenSetPublicChannelLink(accountManager: context.sharedContext.accountManager).start()
                            
                            updateAddressNameDisposable.set((context.engine.peers.updateAddressName(domain: .peer(peerId), name: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue) |> timeout(10, queue: Queue.mainQueue(), alternate: .fail(.generic))
                                |> deliverOnMainQueue).start(error: { _ in
                                    updateState { state in
                                        return state.withUpdatedUpdatingAddressName(false)
                                    }
                                    presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                }, completed: {
                                    updateState { state in
                                        return state.withUpdatedUpdatingAddressName(false)
                                    }
                                    switch mode {
                                        case .initialSetup:
                                            nextImpl?()
                                        case .generic, .privateLink, .revokeNames:
                                            dismissImpl?()
                                    }
                                }))
                            
                        }
                        
                        _ = (ApplicationSpecificNotice.getSetPublicChannelLink(accountManager: context.sharedContext.accountManager) |> deliverOnMainQueue).start(next: { showAlert in
                            if showAlert {
                                let text: String
                                if case .broadcast = peer.info {
                                    text = presentationData.strings.Channel_Edit_PrivatePublicLinkAlert
                                } else {
                                    text = presentationData.strings.Group_Edit_PrivatePublicLinkAlert
                                }
                                presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: invokeAction)]), nil)
                            } else {
                                invokeAction()
                            }
                        })
                    } else {
                        switch mode {
                            case .initialSetup:
                                nextImpl?()
                            case .generic, .privateLink, .revokeNames:
                                dismissImpl?()
                        }
                    }
                })
            } else if let peer = peer as? TelegramGroup {
                var doneEnabled = true
                if let selectedType = state.selectedType {
                    switch selectedType {
                        case .privateChannel:
                            break
                        case .publicChannel:
                            if let addressNameValidationStatus = state.addressNameValidationStatus {
                                switch addressNameValidationStatus {
                                    case .availability(.available):
                                        break
                                    default:
                                        doneEnabled = false
                                }
                            } else {
                                doneEnabled = !(peer.addressName?.isEmpty ?? true)
                            }
                    }
                }
                
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: state.updatingAddressName ? .activity : .bold, enabled: doneEnabled, action: {
                    var updatedAddressNameValue: String?
                    updateState { state in
                        updatedAddressNameValue = updatedAddressName(mode: mode, state: state, peer: peer, cachedData: nil)
                        return state
                    }
                    
                    if let updatedCopyProtection = state.forwardingEnabled {
                        toggleCopyProtectionDisposable.set(context.engine.peers.toggleMessageCopyProtection(peerId: peerId, enabled: !updatedCopyProtection).start())
                    }
                    
                    if let updatedAddressNameValue = updatedAddressNameValue {
                        let invokeAction: () -> Void = {
                            updateState { state in
                                return state.withUpdatedUpdatingAddressName(true)
                            }
                            _ = ApplicationSpecificNotice.markAsSeenSetPublicChannelLink(accountManager: context.sharedContext.accountManager).start()
                            
                            let signal = context.engine.peers.convertGroupToSupergroup(peerId: peerId)
                            |> mapToSignal { upgradedPeerId -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                                return context.engine.peers.updateAddressName(domain: .peer(upgradedPeerId), name: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue)
                                |> `catch` { _ -> Signal<Void, NoError> in
                                    return .complete()
                                }
                                |> mapToSignal { _ -> Signal<PeerId?, NoError> in
                                    return .complete()
                                }
                                |> then(.single(upgradedPeerId))
                                |> castError(ConvertGroupToSupergroupError.self)
                            }
                            |> deliverOnMainQueue
                            
                            updateAddressNameDisposable.set((signal
                            |> deliverOnMainQueue).start(next: { updatedPeerId in
                                if let updatedPeerId = updatedPeerId {
                                    upgradedToSupergroup(updatedPeerId, {
                                        dismissImpl?()
                                    })
                                } else {
                                    dismissImpl?()
                                }
                            }, error: { error in
                                updateState { state in
                                    return state.withUpdatedUpdatingAddressName(false)
                                }
                                switch error {
                                case .tooManyChannels:
                                    pushControllerImpl?(oldChannelsController(context: context, updatedPresentationData: updatedPresentationData, intent: .upgrade))
                                default:
                                    presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                }
                            }))
                        }
                        
                        _ = (ApplicationSpecificNotice.getSetPublicChannelLink(accountManager: context.sharedContext.accountManager) |> deliverOnMainQueue).start(next: { showAlert in
                            if showAlert {
                                presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Group_Edit_PrivatePublicLinkAlert, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: invokeAction)]), nil)
                            } else {
                                invokeAction()
                            }
                        })
                    } else {
                        switch mode {
                            case .initialSetup:
                                nextImpl?()
                            case .generic, .privateLink, .revokeNames:
                                dismissImpl?()
                        }
                    }
                })
            }
        }
        
        if state.revokingPeerId != nil {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        }
        
        var isGroup = false
        if let peer = peer as? TelegramChannel {
            if case .group = peer.info {
                isGroup = true
            }
        } else if let _ = peer as? TelegramGroup {
            isGroup = true
        }
        
        let leftNavigationButton: ItemListNavigationButton?
        switch mode {
            case .initialSetup:
                leftNavigationButton = nil
            case .generic, .privateLink, .revokeNames:
                leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                    dismissImpl?()
                })
        }
        
        var crossfade: Bool = false
        var animateChanges: Bool = false
        if let cachedData = view.cachedData as? CachedChannelData {
            let invitation = cachedData.exportedInvitation
            let previousInvitation = previousInvitation.swap(invitation)
            
            if invitation != previousInvitation {
                crossfade = true
            }
        }
        
        let hasNamesToRevoke = publicChannelsToRevoke != nil && !publicChannelsToRevoke!.isEmpty
        let hadNamesToRevoke = previousHadNamesToRevoke.swap(hasNamesToRevoke)
        
        if let peer = view.peers[view.peerId] as? TelegramChannel {
            let currentUsernames = peer.usernames.map { $0.username }
            let previousUsernames = previousUsernames.swap(currentUsernames)
            
            let selectedType: CurrentChannelType
            if case .privateLink = mode {
                selectedType = .privateChannel
            } else {
                if let current = state.selectedType {
                    selectedType = current
                } else {
                    if let addressName = peer.addressName, !addressName.isEmpty {
                        selectedType = .publicChannel
                    } else if let cachedChannelData = view.cachedData as? CachedChannelData, cachedChannelData.peerGeoLocation != nil {
                        selectedType = .publicChannel
                    } else {
                        selectedType = .privateChannel
                    }
                }
            }
            
            if selectedType == .publicChannel, let hadNamesToRevoke = hadNamesToRevoke, !crossfade {
                crossfade = hadNamesToRevoke != hasNamesToRevoke
            }
                        
            if let hadNamesToRevoke = hadNamesToRevoke {
                animateChanges = hadNamesToRevoke != hasNamesToRevoke
            }
            
            if temporaryOrder != nil || previousUsernames != currentUsernames {
                animateChanges = true
            }
        }
        
        let title: String
        switch mode {
            case .generic, .initialSetup:
                if let cachedChannelData = view.cachedData as? CachedChannelData, cachedChannelData.peerGeoLocation != nil {
                    title = presentationData.strings.Group_PublicLink_Title
                } else {
                    title = isGroup ? presentationData.strings.GroupInfo_GroupType : presentationData.strings.Channel_TypeSetup_Title
                }
            case .privateLink:
                title = presentationData.strings.GroupInfo_InviteLink_Title
            case .revokeNames:
                title = presentationData.strings.Premium_LimitReached
        }

        let entries = channelVisibilityControllerEntries(presentationData: presentationData, mode: mode, view: view, publicChannelsToRevoke: publicChannelsToRevoke, importers: importers, state: state, limits: limits, premiumLimits: premiumLimits, isPremium: isPremium, isPremiumDisabled: premiumConfiguration.isPremiumDisabled, temporaryOrder: temporaryOrder)
        
        var focusItemTag: ItemListItemTag?
        if entries.count > 1, let cachedChannelData = view.cachedData as? CachedChannelData, cachedChannelData.peerGeoLocation != nil {
            focusItemTag = ChannelVisibilityEntryTag.publicLink
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, focusItemTag: focusItemTag, footerItem: footerItem, crossfadeState: crossfade, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.willDisappear = { _ in
        dismissTooltipsImpl?()
    }
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [ChannelVisibilityEntry]) -> Signal<Bool, NoError> in
        let fromEntry = entries[fromIndex]
        guard case let .additionalLink(_, fromUsername, _) = fromEntry else {
            return .single(false)
        }
        var referenceId: String?
        var beforeAll = false
        var afterAll = false
        
        var maxIndex: Int?
        
        var currentUsernames: [String] = []
        var i = 0
        for entry in entries {
            switch entry {
            case let .additionalLink(_, link, _):
                currentUsernames.append(link.username)
                if !link.isActive && maxIndex == nil {
                    maxIndex = max(0, i - 1)
                }
                i += 1
            default:
                break
            }
        }
        
        if toIndex < entries.count {
            switch entries[toIndex] {
                case let .additionalLink(_, toUsername, _):
                    if toUsername.isActive {
                        referenceId = toUsername.username
                    } else {
                        afterAll = true
                    }
                default:
                    if entries[toIndex] < fromEntry {
                        beforeAll = true
                    } else {
                        afterAll = true
                    }
            }
        } else {
            afterAll = true
        }

        var previousIndex: Int?
        for i in 0 ..< currentUsernames.count {
            if currentUsernames[i] == fromUsername.username {
                previousIndex = i
                currentUsernames.remove(at: i)
                break
            }
        }

        var didReorder = false
        if let referenceId = referenceId {
            var inserted = false
            for i in 0 ..< currentUsernames.count {
                if currentUsernames[i] == referenceId {
                    if fromIndex < toIndex {
                        didReorder = previousIndex != i + 1
                        currentUsernames.insert(fromUsername.username, at: i + 1)
                    } else {
                        didReorder = previousIndex != i
                        currentUsernames.insert(fromUsername.username, at: i)
                    }
                    inserted = true
                    break
                }
            }
            if !inserted {
                didReorder = previousIndex != currentUsernames.count
                if let maxIndex = maxIndex {
                    currentUsernames.insert(fromUsername.username, at: maxIndex)
                } else {
                    currentUsernames.append(fromUsername.username)
                }
            }
        } else if beforeAll {
            didReorder = previousIndex != 0
            currentUsernames.insert(fromUsername.username, at: 0)
        } else if afterAll {
            didReorder = previousIndex != currentUsernames.count
            if let maxIndex = maxIndex {
                currentUsernames.insert(fromUsername.username, at: maxIndex)
            } else {
                currentUsernames.append(fromUsername.username)
            }
        }

        temporaryOrder.set(.single(currentUsernames))
        
        if didReorder {
            DispatchQueue.main.async {
                dismissInputImpl?()
            }
        }
        
        return .single(didReorder)
    })
    
    controller.setReorderCompleted({ (entries: [ChannelVisibilityEntry]) -> Void in
        var currentUsernames: [TelegramPeerUsername] = []
        for entry in entries {
            switch entry {
            case let .additionalLink(_, username, _):
                currentUsernames.append(username)
            default:
                break
            }
        }
        let _ = (context.engine.peers.reorderAddressNames(domain: .peer(peerId), names: currentUsernames)
        |> deliverOnMainQueue).start(completed: {
            temporaryOrder.set(.single(nil))
        })
    })
    controller.beganInteractiveDragging = {
        dismissInputImpl?()
    }
    dismissImpl = { [weak controller, weak onDismissRemoveController] in
        guard let controller = controller else {
            return
        }
        controller.view.endEditing(true)
        if let onDismissRemoveController = onDismissRemoveController, let navigationController = controller.navigationController {
            navigationController.setViewControllers(navigationController.viewControllers.filter { c in
                if c === controller || c === onDismissRemoveController {
                    return false
                } else {
                    return true
                }
            }, animated: true)
        } else {
            controller.dismiss()
        }
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    nextImpl = { [weak controller] in
        if let controller = controller {
            if case .initialSetup = mode {
                let selectionController = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, updatedPresentationData: updatedPresentationData, mode: .channelCreation, options: []))
                (controller.navigationController as? NavigationController)?.replaceAllButRootController(selectionController, animated: true)
                let _ = (selectionController.result
                |> deliverOnMainQueue).start(next: { [weak selectionController] result in
                    guard let selectionController = selectionController, let navigationController = selectionController.navigationController as? NavigationController else {
                        return
                    }
                    
                    var peerIds: [ContactListPeerId] = []
                    if case let .result(peerIdsValue, _) = result {
                        peerIds = peerIdsValue
                    }
                    
                    let filteredPeerIds = peerIds.compactMap({ peerId -> PeerId? in
                        if case let .peer(id) = peerId {
                            return id
                        } else {
                            return nil
                        }
                    })
                    if filteredPeerIds.isEmpty {
                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                        |> deliverOnMainQueue).start(next: { peer in
                            guard let peer = peer else {
                                return
                            }
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(peer), keepStack: .never, animated: true))
                        })
                    } else {
                        selectionController.displayProgress = true
                        let _ = (context.engine.peers.addChannelMembers(peerId: peerId, memberIds: filteredPeerIds)
                        |> deliverOnMainQueue).start(error: { [weak selectionController] _ in
                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                            |> deliverOnMainQueue).start(next: { peer in
                                guard let peer = peer else {
                                    return
                                }
                                guard let selectionController = selectionController, let navigationController = selectionController.navigationController as? NavigationController else {
                                    return
                                }
                                
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(peer), keepStack: .never, animated: true))
                            })
                        }, completed: { [weak selectionController] in
                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                            |> deliverOnMainQueue).start(next: { peer in
                                guard let peer = peer else {
                                    return
                                }
                                
                                guard let selectionController = selectionController, let navigationController = selectionController.navigationController as? NavigationController else {
                                    return
                                }
                                
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(peer), keepStack: .never, animated: true))
                            })
                        })
                    }
                })
            } else {
                if let navigationController = controller.navigationController as? NavigationController {
                    navigationController.replaceAllButRootController(context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(previewing: false)), animated: true)
                }
            }
        }
    }
    scrollToPublicLinkTextImpl = { [weak controller] in
        DispatchQueue.main.async {
            if let strongController = controller {
                var resultItemNode: ListViewItemNode?
                let _ = strongController.frameForItemNode({ itemNode in
                    if let itemNode = itemNode as? ItemListSingleLineInputItemNode {
                        if let tag = itemNode.tag as? ChannelVisibilityEntryTag {
                            if tag == .publicLink {
                                resultItemNode = itemNode
                                return true
                            }
                        }
                    }
                    return false
                })
                if let resultItemNode = resultItemNode {
                    strongController.ensureItemNodeVisible(resultItemNode)
                }
            }
        }
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentInGlobalOverlayImpl = { [weak controller] c in
        if let controller = controller {
            controller.presentInGlobalOverlay(c)
        }
    }
    getControllerImpl = { [weak controller] in
        return controller
    }
    dismissTooltipsImpl = { [weak controller] in
        controller?.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        controller?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    return controller
}

final class InviteLinkContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
