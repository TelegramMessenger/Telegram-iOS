import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import LegacyComponents
import TelegramPresentationData
import SafariServices
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import TextFormat
import AccountContext
import TelegramStringFormatting
import TemporaryCachedPeerDataManager
import ShareController
import AlertUI
import PresentationDataUtils
import MediaResources
import PhotoResources
import LocationResources
import GalleryUI
import LegacyUI
import LocationUI
import ItemListPeerItem
import ContactListUI
import ItemListAvatarAndNameInfoItem
import ItemListPeerActionItem
import WebSearchUI
import Geocoding
import PeerAvatarGalleryUI
import Emoji
import NotificationMuteSettingsUI
import MapResourceToAvatarSizes
import NotificationSoundSelectionUI
import ItemListAddressItem
import AppBundle
import Markdown
import LocalizedPeerData

private let maxParticipantsDisplayedLimit: Int32 = 50
private let maxParticipantsDisplayedCollapseLimit: Int32 = 60

private final class GroupInfoArguments {
    let context: AccountContext
    
    let avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext
    let tapAvatarAction: () -> Void
    let changeProfilePhoto: () -> Void
    let pushController: (ViewController) -> Void
    let presentController: (ViewController, ViewControllerPresentationArguments) -> Void
    let changeNotificationMuteSettings: () -> Void
    let openPreHistory: () -> Void
    let openSharedMedia: () -> Void
    let openAdministrators: () -> Void
    let openPermissions: () -> Void
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let updateEditingDescriptionText: (String) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let addMember: () -> Void
    let promotePeer: (RenderedChannelParticipant) -> Void
    let restrictPeer: (RenderedChannelParticipant) -> Void
    let removePeer: (PeerId) -> Void
    let leave: () -> Void
    let displayUsernameShareMenu: (String) -> Void
    let displayUsernameContextMenu: (String) -> Void
    let displayAboutContextMenu: (String) -> Void
    let aboutLinkAction: (TextLinkItemActionType, TextLinkItem) -> Void
    let openStickerPackSetup: () -> Void
    let openGroupTypeSetup: () -> Void
    let openLinkedChannelSetup: () -> Void
    let openLocation: (PeerGeoLocation) -> Void
    let changeLocation: () -> Void
    let displayLocationContextMenu: (String) -> Void
    let expandParticipants: () -> Void
    
    init(context: AccountContext, avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext, tapAvatarAction: @escaping () -> Void, changeProfilePhoto: @escaping () -> Void, pushController: @escaping (ViewController) -> Void, presentController: @escaping (ViewController, ViewControllerPresentationArguments) -> Void, changeNotificationMuteSettings: @escaping () -> Void, openPreHistory: @escaping () -> Void, openSharedMedia: @escaping () -> Void, openAdministrators: @escaping () -> Void, openPermissions: @escaping () -> Void, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, updateEditingDescriptionText: @escaping (String) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addMember: @escaping () -> Void, promotePeer: @escaping (RenderedChannelParticipant) -> Void, restrictPeer: @escaping (RenderedChannelParticipant) -> Void, removePeer: @escaping (PeerId) -> Void, leave: @escaping () -> Void, displayUsernameShareMenu: @escaping (String) -> Void, displayUsernameContextMenu: @escaping (String) -> Void, displayAboutContextMenu: @escaping (String) -> Void, aboutLinkAction: @escaping (TextLinkItemActionType, TextLinkItem) -> Void, openStickerPackSetup: @escaping () -> Void, openGroupTypeSetup: @escaping () -> Void, openLinkedChannelSetup: @escaping () -> Void, openLocation: @escaping (PeerGeoLocation) -> Void, changeLocation: @escaping () -> Void, displayLocationContextMenu: @escaping (String) -> Void, expandParticipants: @escaping () -> Void) {
        self.context = context
        self.avatarAndNameInfoContext = avatarAndNameInfoContext
        self.tapAvatarAction = tapAvatarAction
        self.changeProfilePhoto = changeProfilePhoto
        self.pushController = pushController
        self.presentController = presentController
        self.changeNotificationMuteSettings = changeNotificationMuteSettings
        self.openPreHistory = openPreHistory
        self.openSharedMedia = openSharedMedia
        self.openAdministrators = openAdministrators
        self.openPermissions = openPermissions
        self.updateEditingName = updateEditingName
        self.updateEditingDescriptionText = updateEditingDescriptionText
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.addMember = addMember
        self.promotePeer = promotePeer
        self.restrictPeer = restrictPeer
        self.removePeer = removePeer
        self.leave = leave
        self.displayUsernameShareMenu = displayUsernameShareMenu
        self.displayUsernameContextMenu = displayUsernameContextMenu
        self.displayAboutContextMenu = displayAboutContextMenu
        self.aboutLinkAction = aboutLinkAction
        self.openStickerPackSetup = openStickerPackSetup
        self.openGroupTypeSetup = openGroupTypeSetup
        self.openLinkedChannelSetup = openLinkedChannelSetup
        self.openLocation = openLocation
        self.changeLocation = changeLocation
        self.displayLocationContextMenu = displayLocationContextMenu
        self.expandParticipants = expandParticipants
    }
}

private enum GroupInfoSection: ItemListSectionId {
    case info
    case about
    case infoManagement
    case sharedMediaAndNotifications
    case memberManagement
    case members
    case leave
}

private enum GroupInfoEntryTag {
    case about
    case link
    case location
}

private enum GroupInfoMemberStatus: Equatable {
    case member
    case admin(rank: String?)
    case owner(rank: String?)
}

private enum GroupEntryStableId: Hashable, Equatable {
    case peer(PeerId)
    case index(Int)
    
    static func ==(lhs: GroupEntryStableId, rhs: GroupEntryStableId) -> Bool {
        switch lhs {
            case let .peer(peerId):
                if case .peer(peerId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .index(index):
                if case .index(index) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .peer(peerId):
                return peerId.hashValue
            case let .index(index):
                return index.hashValue
        }
    }
}

enum ParticipantRevealActionType {
    case promote
    case restrict
    case remove
}

struct ParticipantRevealAction: Equatable {
    let type: ItemListPeerItemRevealOptionType
    let title: String
    let action: ParticipantRevealActionType
}

private enum GroupInfoEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, peer: Peer?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState, updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?)
    case setGroupPhoto(PresentationTheme, String)
    case groupDescriptionSetup(PresentationTheme, String, String)
    case about(PresentationTheme, String)
    case locationHeader(PresentationTheme, String)
    case location(PresentationTheme, PeerGeoLocation)
    case changeLocation(PresentationTheme, String)
    case link(PresentationTheme, String)
    case sharedMedia(PresentationTheme, String)
    case notifications(PresentationTheme, String, String)
    case stickerPack(PresentationTheme, String, String)
    case groupTypeSetup(PresentationTheme, String, String)
    case linkedChannelSetup(PresentationTheme, String, String)
    case preHistory(PresentationTheme, String, String)
    case administrators(PresentationTheme, String, String)
    case permissions(PresentationTheme, String, String)
    case addMember(PresentationTheme, String, editing: Bool)
    case member(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, index: Int, peerId: PeerId, peer: Peer, participant: RenderedChannelParticipant?, presence: PeerPresence?, memberStatus: GroupInfoMemberStatus, editing: ItemListPeerItemEditing, revealActions: [ParticipantRevealAction], enabled: Bool, selectable: Bool)
    case expand(PresentationTheme, String)
    case leave(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .info, .setGroupPhoto, .groupDescriptionSetup, .about:
                return GroupInfoSection.info.rawValue
            case .locationHeader, .location, .changeLocation, .link:
                return GroupInfoSection.about.rawValue
            case .groupTypeSetup, .linkedChannelSetup, .preHistory, .stickerPack:
                return GroupInfoSection.infoManagement.rawValue
            case .sharedMedia, .notifications:
                return GroupInfoSection.sharedMediaAndNotifications.rawValue
            case .permissions, .administrators:
                return GroupInfoSection.memberManagement.rawValue
            case .addMember, .member, .expand:
                return GroupInfoSection.members.rawValue
            case .leave:
                return GroupInfoSection.leave.rawValue
        }
    }
    
    static func ==(lhs: GroupInfoEntry, rhs: GroupInfoEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsCachedData, lhsState, lhsUpdatingAvatar):
                if case let .info(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsCachedData, rhsState, rhsUpdatingAvatar) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else if (lhsPeer == nil) != (rhsPeer != nil) {
                        return false
                    }
                    if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                        if !lhsCachedData.isEqual(to: rhsCachedData) {
                            return false
                        }
                    } else if (lhsCachedData != nil) != (rhsCachedData != nil) {
                        return false
                    }
                    if lhsState != rhsState {
                        return false
                    }
                    if lhsUpdatingAvatar != rhsUpdatingAvatar {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .setGroupPhoto(lhsTheme, lhsText):
                if case let .setGroupPhoto(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .groupDescriptionSetup(lhsTheme, lhsPlaceholder, lhsText):
                if case let .groupDescriptionSetup(rhsTheme, rhsPlaceholder, rhsText) = rhs, lhsTheme === rhsTheme, lhsPlaceholder == rhsPlaceholder, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .sharedMedia(lhsTheme, lhsText):
                if case let .sharedMedia(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .leave(lhsTheme, lhsText):
                if case let .leave(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .about(lhsTheme, lhsText):
                if case let .about(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .locationHeader(lhsTheme, lhsText):
                if case let .locationHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .location(lhsTheme, lhsLocation):
                if case let .location(rhsTheme, rhsLocation) = rhs, lhsTheme === rhsTheme, lhsLocation == rhsLocation {
                    return true
                } else {
                    return false
                }
            case let .changeLocation(lhsTheme, lhsText):
                if case let .changeLocation(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .link(lhsTheme, lhsText):
                if case let .link(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .notifications(lhsTheme, lhsTitle, lhsText):
                if case let .notifications(rhsTheme, rhsTitle, rhsText) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsTitle != rhsTitle {
                        return false
                    }
                    if lhsText != rhsText {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .stickerPack(lhsTheme, lhsTitle, lhsValue):
                if case let .stickerPack(rhsTheme, rhsTitle, rhsValue) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsTitle != rhsTitle {
                        return false
                    }
                    if lhsValue != rhsValue {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .preHistory(lhsTheme, lhsTitle, lhsValue):
                if case let .preHistory(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .groupTypeSetup(lhsTheme, lhsTitle, lhsText):
                if case let .groupTypeSetup(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .linkedChannelSetup(lhsTheme, lhsTitle, lhsText):
                if case let .linkedChannelSetup(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .permissions(lhsTheme, lhsTitle, lhsText):
                if case let .permissions(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .administrators(lhsTheme, lhsTitle, lhsText):
                if case let .administrators(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addMember(lhsTheme, lhsTitle, lhsEditing):
                if case let .addMember(rhsTheme, rhsTitle, rhsEditing) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsEditing == rhsEditing {
                    return true
                } else {
                    return false
                }
            case let .member(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameDisplayOrder, lhsIndex, lhsPeerId, lhsPeer, lhsParticipant, lhsPresence, lhsMemberStatus, lhsEditing, lhsActions, lhsEnabled, lhsSelectable):
                if case let .member(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameDisplayOrder, rhsIndex, rhsPeerId, rhsPeer, rhsParticipant, rhsPresence, rhsMemberStatus, rhsEditing, rhsActions, rhsEnabled, rhsSelectable) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if lhsNameDisplayOrder != rhsNameDisplayOrder {
                        return false
                    }
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsMemberStatus != rhsMemberStatus {
                        return false
                    }
                    if lhsPeerId != rhsPeerId {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    if lhsParticipant != rhsParticipant {
                        return false
                    }
                    if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                        if !lhsPresence.isEqual(to: rhsPresence) {
                            return false
                        }
                    } else if (lhsPresence != nil) != (rhsPresence != nil) {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsActions != rhsActions {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    if lhsSelectable != rhsSelectable {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .expand(lhsTheme, lhsText):
                if case let .expand(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var stableId: GroupEntryStableId {
        switch self {
            case let .member(_, _, _, _, _, peerId, _, _, _, _, _, _, _, _):
                return .peer(peerId)
            default:
                return .index(self.sortIndex)
        }
    }
    
    private var sortIndex: Int {
        switch self {
            case .info:
                return 0
            case .setGroupPhoto:
                return 1
            case .groupDescriptionSetup:
                return 2
            case .about:
                return 3
            case .locationHeader:
                return 4
            case .location:
                return 5
            case .changeLocation:
                return 6
            case .link:
                return 7
            case .groupTypeSetup:
                return 8
            case .linkedChannelSetup:
                return 9
            case .preHistory:
                return 10
            case .stickerPack:
                return 11
            case .notifications:
                return 12
            case .sharedMedia:
                return 13
            case .permissions:
                return 14
            case .administrators:
                return 15
            case .addMember:
                return 16
            case let .member(_, _, _, _, index, _, _, _, _, _, _, _, _, _):
                return 20 + index
            case .expand:
                return 200000 + 1
            case .leave:
                return 200000 + 2
        }
    }
    
    static func <(lhs: GroupInfoEntry, rhs: GroupInfoEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GroupInfoArguments
        switch self {
            case let .info(theme, strings, dateTimeFormat, peer, cachedData, state, updatingAvatar):
                return ItemListAvatarAndNameInfoItem(accountContext: arguments.context, presentationData: presentationData, dateTimeFormat: dateTimeFormat, mode: .generic, peer: peer, presence: nil, cachedData: cachedData, state: state, sectionId: self.section, style: .blocks(withTopInset: false, withExtendedBottomInset: false), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                    arguments.tapAvatarAction()
                }, context: arguments.avatarAndNameInfoContext, updatingImage: updatingAvatar)
            case let .setGroupPhoto(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.changeProfilePhoto()
                })
            case let .about(theme, text):
                return ItemListMultilineTextItem(presentationData: presentationData, text: foldMultipleLineBreaks(text), enabledEntityTypes: [.url, .mention, .hashtag], sectionId: self.section, style: .blocks, longTapAction: {
                    arguments.displayAboutContextMenu(text)
                }, linkItemAction: { action, itemLink in
                    arguments.aboutLinkAction(action, itemLink)
                }, tag: GroupInfoEntryTag.about)
            case let .locationHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .location(theme, location):
                let imageSignal = chatMapSnapshotImage(account: arguments.context.account, resource: MapSnapshotMediaResource(latitude: location.latitude, longitude: location.longitude, width: 90, height: 90))
                return ItemListAddressItem(theme: theme, label: "", text: location.address.replacingOccurrences(of: ", ", with: "\n"), imageSignal: imageSignal, selected: nil, sectionId: self.section, style: .blocks, action: {
                    arguments.openLocation(location)
                }, longTapAction: {
                    arguments.displayLocationContextMenu(location.address.replacingOccurrences(of: "\n", with: ", "))
                }, tag: GroupInfoEntryTag.location)
            case let .changeLocation(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.changeLocation()
                }, clearHighlightAutomatically: false)
            case let .link(theme, url):
                return ItemListActionItem(presentationData: presentationData, title: url, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.displayUsernameShareMenu(url)
                }, longTapAction: {
                    arguments.displayUsernameContextMenu(url)
                }, tag: GroupInfoEntryTag.link)
            case let .notifications(theme, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.changeNotificationMuteSettings()
                })
            case let .stickerPack(theme, title, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openStickerPackSetup()
                })
            case let .preHistory(theme, title, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openPreHistory()
                })
            case let .sharedMedia(theme, title):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openSharedMedia()
                })
            case let .addMember(theme, title, editing):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addPersonIcon(theme), title: title, sectionId: self.section, editing: editing, action: {
                    arguments.addMember()
                })
            case let .groupTypeSetup(theme, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.openGroupTypeSetup()
                })
            case let .linkedChannelSetup(theme, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.openLinkedChannelSetup()
                })
            case let .groupDescriptionSetup(theme, placeholder, text):
                return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: placeholder, maxLength: ItemListMultilineInputItemTextLimit(value: 255, display: true), sectionId: self.section, style: .blocks, textUpdated: { updatedText in
                    arguments.updateEditingDescriptionText(updatedText)
                })
            case let .permissions(theme, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesChat.groupInfoPermissionsIcon(theme), title: title, label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.openPermissions()
                })
            case let .administrators(theme, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesChat.groupInfoAdminsIcon(theme), title: title, label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.openAdministrators()
                })
            case let .member(theme, strings, dateTimeFormat, nameDisplayOrder, _, _, peer, participant, presence, memberStatus, editing, actions, enabled, selectable):
                let label: String?
                switch memberStatus {
                    case let .owner(rank):
                        label = rank?.trimmingEmojis ?? strings.GroupInfo_LabelOwner
                    case let .admin(rank):
                        label = rank?.trimmingEmojis ?? strings.GroupInfo_LabelAdmin
                    case .member:
                        label = nil
                }
                var options: [ItemListPeerItemRevealOption] = []
                for action in actions {
                    options.append(ItemListPeerItemRevealOption(type: action.type, title: action.title, action: {
                        switch action.action {
                            case .promote:
                                if let participant = participant {
                                    arguments.promotePeer(participant)
                                }
                            case .restrict:
                                if let participant = participant {
                                    arguments.restrictPeer(participant)
                                }
                            case .remove:
                                arguments.removePeer(peer.id)
                        }
                    }))
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer, presence: presence, text: .presence, label: label == nil ? .none : .text(label!, .standard), editing: editing, revealOptions: ItemListPeerItemRevealOptions(options: options), switchValue: nil, enabled: enabled, selectable: selectable, sectionId: self.section, action: {
                    if let infoController = arguments.context.sharedContext.makePeerInfoController(context: arguments.context, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false), selectable {
                        arguments.pushController(infoController)
                    }
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
            case let .expand(theme, title):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(theme), title: title, sectionId: self.section, editing: false, action: {
                    arguments.expandParticipants()
                })
            case let .leave(theme, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.leave()
                })
            default:
                preconditionFailure()
        }
    }
}

private struct TemporaryParticipant: Equatable {
    let peer: Peer
    let presence: PeerPresence?
    let timestamp: Int32
    
    static func ==(lhs: TemporaryParticipant, rhs: TemporaryParticipant) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence {
            if !lhsPresence.isEqual(to: rhsPresence) {
                return false
            }
        } else if (lhs.presence != nil) != (rhs.presence != nil) {
            return false
        }
        return true
    }
}

private struct GroupInfoState: Equatable {
    let updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    let editingState: GroupInfoEditingState?
    let updatingName: ItemListAvatarAndNameInfoItemName?
    let peerIdWithRevealedOptions: PeerId?
    let expandedParticipants: Bool
    
    let temporaryParticipants: [TemporaryParticipant]
    let successfullyAddedParticipantIds: Set<PeerId>
    let removingParticipantIds: Set<PeerId>
    
    let savingData: Bool
    
    let searchingMembers: Bool
    
    static func ==(lhs: GroupInfoState, rhs: GroupInfoState) -> Bool {
        if lhs.updatingAvatar != rhs.updatingAvatar {
            return false
        }
        if lhs.editingState != rhs.editingState {
            return false
        }
        if lhs.updatingName != rhs.updatingName {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.expandedParticipants != rhs.expandedParticipants {
            return false
        }
        if lhs.temporaryParticipants != rhs.temporaryParticipants {
            return false
        }
        if lhs.successfullyAddedParticipantIds != rhs.successfullyAddedParticipantIds {
            return false
        }
        if lhs.removingParticipantIds != rhs.removingParticipantIds {
            return false
        }
        if lhs.savingData != rhs.savingData {
            return false
        }
        if lhs.searchingMembers != rhs.searchingMembers {
            return false
        }
        return true
    }
    
    func withUpdatedUpdatingAvatar(_ updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, expandedParticipants: self.expandedParticipants, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedEditingState(_ editingState: GroupInfoEditingState?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, expandedParticipants: self.expandedParticipants, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedUpdatingName(_ updatingName: ItemListAvatarAndNameInfoItemName?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, expandedParticipants: self.expandedParticipants, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: peerIdWithRevealedOptions, expandedParticipants: self.expandedParticipants, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }

    func withUpdatedExpandedParticipants(_ expandedParticipants: Bool) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, expandedParticipants: expandedParticipants, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedTemporaryParticipants(_ temporaryParticipants: [TemporaryParticipant]) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, expandedParticipants: self.expandedParticipants, temporaryParticipants: temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedSuccessfullyAddedParticipantIds(_ successfullyAddedParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, expandedParticipants: self.expandedParticipants, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovingParticipantIds(_ removingParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, expandedParticipants: self.expandedParticipants, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, expandedParticipants: self.expandedParticipants, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedSearchingMembers(_ searchingMembers: Bool) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, expandedParticipants: self.expandedParticipants, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: searchingMembers)
    }
}

private struct GroupInfoEditingState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName?
    let editingDescriptionText: String
    
    func withUpdatedEditingDescriptionText(_ editingDescriptionText: String) -> GroupInfoEditingState {
        return GroupInfoEditingState(editingName: self.editingName, editingDescriptionText: editingDescriptionText)
    }
    
    static func ==(lhs: GroupInfoEditingState, rhs: GroupInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.editingDescriptionText != rhs.editingDescriptionText {
            return false
        }
        return true
    }
}

private func canRemoveParticipant(account: Account, isAdmin: Bool, participantId: PeerId, invitedBy: PeerId?) -> Bool {
    if participantId == account.peerId {
        return false
    }
    
    if account.peerId == invitedBy {
        return true
    }
    
    return isAdmin
}

private func canRemoveParticipant(account: Account, channel: TelegramChannel, participant: ChannelParticipant) -> Bool {
    if participant.peerId == account.peerId {
        return false
    }
    
    if channel.flags.contains(.isCreator) {
        return true
    }
    
    switch participant {
        case .creator:
            return false
        case let .member(_, _, adminInfo, _, _):
            if channel.hasPermission(.banMembers) {
                if let adminInfo = adminInfo {
                    return adminInfo.promotedBy == account.peerId
                } else {
                    return false
                }
            } else {
                return false
            }
    }
}


private func groupInfoEntries(account: Account, presentationData: PresentationData, view: PeerView, channelMembers: [RenderedChannelParticipant], globalNotificationSettings: GlobalNotificationSettings, state: GroupInfoState) -> [GroupInfoEntry] {
    var entries: [GroupInfoEntry] = []
    
    var canEditGroupInfo = false
    var canEditMembers = false
    var canAddMembers = false
    var isPublic = false
    var isCreator = false
    if let group = view.peers[view.peerId] as? TelegramGroup {
        if case .creator = group.role {
            isCreator = true
        }
        switch group.role {
            case .admin, .creator:
                canEditGroupInfo = true
                canEditMembers = true
                canAddMembers = true
            case .member:
                break
        }
        if !group.hasBannedPermission(.banChangeInfo) {
            canEditGroupInfo = true
        }
        if !group.hasBannedPermission(.banAddMembers) {
            canAddMembers = true
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        isPublic = channel.username != nil
        if !isPublic, let cachedChannelData = view.cachedData as? CachedChannelData, cachedChannelData.peerGeoLocation != nil {
            isPublic = true
        }
        
        isCreator = channel.flags.contains(.isCreator)
        if channel.hasPermission(.changeInfo) {
            canEditGroupInfo = true
        }
        if channel.hasPermission(.banMembers) {
            canEditMembers = true
        }
        if channel.hasPermission(.inviteMembers) {
            canAddMembers = true
        }
    }
    
    if let peer = peerViewMainPeer(view) {
        let infoState = ItemListAvatarAndNameInfoItemState(editingName: canEditGroupInfo ? state.editingState?.editingName : nil, updatingName: state.updatingName)
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer: peer, cachedData: view.cachedData, state: infoState, updatingAvatar: state.updatingAvatar))
    }
    
    let peerNotificationSettings: TelegramPeerNotificationSettings = (view.notificationSettings as? TelegramPeerNotificationSettings) ?? TelegramPeerNotificationSettings.defaultSettings
    let notificationsText: String
    
    if case let .muted(until) = peerNotificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
        if until < Int32.max - 1 {
            notificationsText = stringForRemainingMuteInterval(strings: presentationData.strings, muteInterval: until)
        } else {
            notificationsText = presentationData.strings.UserInfo_NotificationsDisabled
        }
    } else if case .default = peerNotificationSettings.messageSound {
        notificationsText = presentationData.strings.UserInfo_NotificationsEnabled
    } else {
        notificationsText = localizedPeerNotificationSoundString(strings: presentationData.strings, sound: peerNotificationSettings.messageSound, default: globalNotificationSettings.effective.channels.sound)
    }
    
    if let editingState = state.editingState {
        if canEditGroupInfo {
            entries.append(GroupInfoEntry.setGroupPhoto(presentationData.theme, presentationData.strings.GroupInfo_SetGroupPhoto))
            
            entries.append(GroupInfoEntry.groupDescriptionSetup(presentationData.theme, presentationData.strings.Channel_About_Placeholder, editingState.editingDescriptionText))
        }
        
        if let group = view.peers[view.peerId] as? TelegramGroup, let cachedGroupData = view.cachedData as? CachedGroupData {
            if case .creator = group.role {
                if cachedGroupData.flags.contains(.canChangeUsername) {
                    entries.append(GroupInfoEntry.groupTypeSetup(presentationData.theme, presentationData.strings.GroupInfo_GroupType, presentationData.strings.Channel_Setup_TypePrivate))
                }
                entries.append(GroupInfoEntry.preHistory(presentationData.theme, presentationData.strings.GroupInfo_GroupHistory, presentationData.strings.GroupInfo_GroupHistoryHidden))
                
                var activePermissionCount: Int?
                if let defaultBannedRights = group.defaultBannedRights {
                    var count = 0
                    for (right, _) in allGroupPermissionList {
                        if !defaultBannedRights.flags.contains(right) {
                            count += 1
                        }
                    }
                    activePermissionCount = count
                }
                entries.append(GroupInfoEntry.permissions(presentationData.theme, presentationData.strings.GroupInfo_Permissions, activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList.count)" }) ?? ""))
                entries.append(.administrators(presentationData.theme, presentationData.strings.GroupInfo_Administrators, ""))
            }
        } else if let channel = view.peers[view.peerId] as? TelegramChannel, let cachedChannelData = view.cachedData as? CachedChannelData {
            if isCreator, let location = cachedChannelData.peerGeoLocation {
                entries.append(.locationHeader(presentationData.theme, presentationData.strings.GroupInfo_Location.uppercased()))
                entries.append(.location(presentationData.theme, location))
                if cachedChannelData.flags.contains(.canChangePeerGeoLocation) {
                    entries.append(.changeLocation(presentationData.theme, presentationData.strings.Group_Location_ChangeLocation))
                }
            }
            
            if isCreator || (channel.adminRights != nil && channel.hasPermission(.pinMessages)) {
                if cachedChannelData.peerGeoLocation != nil {
                    if isCreator {
                        entries.append(GroupInfoEntry.groupTypeSetup(presentationData.theme, presentationData.strings.GroupInfo_PublicLink, channel.addressName ?? presentationData.strings.GroupInfo_PublicLinkAdd))
                    }
                } else {
                    if cachedChannelData.flags.contains(.canChangeUsername) {
                        entries.append(GroupInfoEntry.groupTypeSetup(presentationData.theme, presentationData.strings.GroupInfo_GroupType, isPublic ? presentationData.strings.Channel_Setup_TypePublic : presentationData.strings.Channel_Setup_TypePrivate))
                        if let linkedDiscussionPeerId = cachedChannelData.linkedDiscussionPeerId, let peer = view.peers[linkedDiscussionPeerId] {
                            let peerTitle: String
                            if let addressName = peer.addressName, !addressName.isEmpty {
                                peerTitle = "@\(addressName)"
                            } else {
                                peerTitle = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            }
                            entries.append(GroupInfoEntry.linkedChannelSetup(presentationData.theme, presentationData.strings.Group_LinkedChannel, peerTitle))
                        }
                    }
                    if !isPublic && cachedChannelData.linkedDiscussionPeerId == nil {
                        entries.append(GroupInfoEntry.preHistory(presentationData.theme, presentationData.strings.GroupInfo_GroupHistory, cachedChannelData.flags.contains(.preHistoryEnabled) ? presentationData.strings.GroupInfo_GroupHistoryVisible : presentationData.strings.GroupInfo_GroupHistoryHidden))
                    }
                }
            }
            
            if cachedChannelData.flags.contains(.canSetStickerSet) && canEditGroupInfo {
                entries.append(GroupInfoEntry.stickerPack(presentationData.theme, presentationData.strings.Stickers_GroupStickers, cachedChannelData.stickerPack?.title ?? presentationData.strings.GroupInfo_SharedMediaNone))
            }
            
            var canViewAdminsAndBanned = false
            if let channel = view.peers[view.peerId] as? TelegramChannel {
                if let adminRights = channel.adminRights, !adminRights.isEmpty {
                    canViewAdminsAndBanned = true
                } else if channel.flags.contains(.isCreator) {
                    canViewAdminsAndBanned = true
                }
            }
            
            if canViewAdminsAndBanned {
                var activePermissionCount: Int?
                if let defaultBannedRights = channel.defaultBannedRights {
                    var count = 0
                    for (right, _) in allGroupPermissionList {
                        if !defaultBannedRights.flags.contains(right) {
                            count += 1
                        }
                    }
                    activePermissionCount = count
                }
                
                entries.append(GroupInfoEntry.permissions(presentationData.theme, presentationData.strings.GroupInfo_Permissions, activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList.count)" }) ?? ""))
                entries.append(GroupInfoEntry.administrators(presentationData.theme, presentationData.strings.GroupInfo_Administrators, cachedChannelData.participantsSummary.adminCount.flatMap { "\(presentationStringsFormattedNumber($0, presentationData.dateTimeFormat.groupingSeparator))" } ?? ""))
            }
        }
    } else {
        if let peer = peerViewMainPeer(view), peer.isScam {
            entries.append(.about(presentationData.theme, presentationData.strings.GroupInfo_ScamGroupWarning))
        }
        else if let cachedChannelData = view.cachedData as? CachedChannelData {
            if let about = cachedChannelData.about, !about.isEmpty {
                entries.append(.about(presentationData.theme, about))
            }
            if let peer = view.peers[view.peerId] as? TelegramChannel {
                if let location = cachedChannelData.peerGeoLocation {
                    entries.append(.locationHeader(presentationData.theme, presentationData.strings.GroupInfo_Location.uppercased()))
                    entries.append(.location(presentationData.theme, location))
                }
                if let username = peer.username, !username.isEmpty {
                    entries.append(.link(presentationData.theme, "t.me/" + username))
                }
            }
        } else if let cachedGroupData = view.cachedData as? CachedGroupData {
            if let about = cachedGroupData.about, !about.isEmpty {
                entries.append(.about(presentationData.theme, about))
            }
        }
        
        entries.append(GroupInfoEntry.notifications(presentationData.theme, presentationData.strings.GroupInfo_Notifications, notificationsText))
        entries.append(GroupInfoEntry.sharedMedia(presentationData.theme, presentationData.strings.GroupInfo_SharedMedia))
    }
    
    var canRemoveAnyMember = false
    if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
        for participant in participants.participants {
            if canRemoveParticipant(account: account, isAdmin: canEditMembers, participantId: participant.peerId, invitedBy: participant.invitedBy) {
                canRemoveAnyMember = true
                break
            }
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        for participant in channelMembers {
            if canRemoveParticipant(account: account, channel: channel, participant: participant.participant) {
                canRemoveAnyMember = true
                break
            }
        }
    }
    
    if canAddMembers {
        entries.append(GroupInfoEntry.addMember(presentationData.theme, presentationData.strings.GroupInfo_AddParticipant, editing: state.editingState != nil && canRemoveAnyMember))
    }
    
    if let group = view.peers[view.peerId] as? TelegramGroup, let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
        var updatedParticipants = participants.participants
        let existingParticipantIds = Set(updatedParticipants.map { $0.peerId })
        
        var peerPresences: [PeerId: PeerPresence] = view.peerPresences
        var peers: [PeerId: Peer] = view.peers
        var disabledPeerIds = state.removingParticipantIds
        
        if !state.temporaryParticipants.isEmpty {
            for participant in state.temporaryParticipants {
                if !existingParticipantIds.contains(participant.peer.id) {
                    updatedParticipants.append(.member(id: participant.peer.id, invitedBy: account.peerId, invitedAt: participant.timestamp))
                    if let presence = participant.presence, peerPresences[participant.peer.id] == nil {
                        peerPresences[participant.peer.id] = presence
                    }
                    if peers[participant.peer.id] == nil {
                        peers[participant.peer.id] = participant.peer
                    }
                    disabledPeerIds.insert(participant.peer.id)
                }
            }
        }
        
        let sortedParticipants = updatedParticipants.sorted(by: { lhs, rhs in
            let lhsPresence = peerPresences[lhs.peerId] as? TelegramUserPresence
            let rhsPresence = peerPresences[rhs.peerId] as? TelegramUserPresence
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                if lhsPresence.status < rhsPresence.status {
                    return false
                } else if lhsPresence.status > rhsPresence.status {
                    return true
                }
            } else if let _ = lhsPresence {
                return true
            } else if let _ = rhsPresence {
                return false
            }
            
            switch lhs {
                case .creator:
                    return false
                case let .admin(lhsId, _, lhsInvitedAt):
                    switch rhs {
                        case .creator:
                            return true
                        case let .admin(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .member(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                    }
                case let .member(lhsId, _, lhsInvitedAt):
                    switch rhs {
                        case .creator:
                            return true
                        case let .admin(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .member(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                    }
            }
        })
        
        for i in 0 ..< sortedParticipants.count {
            if let peer = peers[sortedParticipants[i].peerId] {
                let memberStatus: GroupInfoMemberStatus
                let participant: ChannelParticipant
                switch sortedParticipants[i] {
                    case .creator:
                        participant = .creator(id: sortedParticipants[i].peerId, rank: nil)
                        memberStatus = .owner(rank: nil)
                    case .admin:
                        participant = .member(id: sortedParticipants[i].peerId, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(flags: .groupSpecific), promotedBy: account.peerId, canBeEditedByAccountPeer: true), banInfo: nil, rank: nil)
                        memberStatus = .admin(rank: nil)
                    case .member:
                        participant = .member(id: sortedParticipants[i].peerId, invitedAt: 0, adminInfo: nil, banInfo: nil, rank: nil)
                        memberStatus = .member
                }
                
                var canPromote: Bool
                var canRestrict: Bool
                if sortedParticipants[i].peerId == account.peerId {
                    canPromote = false
                    canRestrict = false
                } else {
                    switch group.role {
                        case .creator:
                            canPromote = true
                            canRestrict = true
                        case .member:
                            canPromote = false
                            switch sortedParticipants[i] {
                                case .creator, .admin:
                                    canPromote = false
                                    canRestrict = false
                                case let .member(member):
                                    if member.invitedBy == account.peerId {
                                        canRestrict = true
                                    } else {
                                        canRestrict = false
                                    }
                                }
                        case .admin:
                            switch sortedParticipants[i] {
                                case .creator, .admin:
                                    canPromote = false
                                    canRestrict = false
                                case .member:
                                    canPromote = false
                                    canRestrict = true
                            }
                    }
                }
                
                var peerActions: [ParticipantRevealAction] = []
                if canPromote {
                    peerActions.append(ParticipantRevealAction(type: .neutral, title: presentationData.strings.GroupInfo_ActionPromote, action: .promote))
                }
                if canRestrict {
                    peerActions.append(ParticipantRevealAction(type: .warning, title: presentationData.strings.GroupInfo_ActionRestrict, action: .restrict))
                    peerActions.append(ParticipantRevealAction(type: .destructive, title: presentationData.strings.Common_Delete, action: .remove))
                }
                
                entries.append(GroupInfoEntry.member(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, index: i, peerId: peer.id, peer: peer, participant: RenderedChannelParticipant(participant: participant, peer: peer), presence: peerPresences[peer.id], memberStatus: memberStatus, editing: ItemListPeerItemEditing(editable: canRemoveParticipant(account: account, isAdmin: canEditMembers, participantId: peer.id, invitedBy: sortedParticipants[i].invitedBy), editing: state.editingState != nil && canRemoveAnyMember, revealed: state.peerIdWithRevealedOptions == peer.id), revealActions: peerActions, enabled: !disabledPeerIds.contains(peer.id), selectable: peer.id != account.peerId))
            }
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel, let cachedChannelData = view.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
        var updatedParticipants = channelMembers
        let existingParticipantIds = Set(updatedParticipants.map { $0.peer.id })

        var peerPresences: [PeerId: PeerPresence] = view.peerPresences
        var peers: [PeerId: Peer] = view.peers
        
        if !state.temporaryParticipants.isEmpty {
            for participant in state.temporaryParticipants {
                if !existingParticipantIds.contains(participant.peer.id) {
                    updatedParticipants.append(RenderedChannelParticipant(participant: ChannelParticipant.member(id: participant.peer.id, invitedAt: participant.timestamp, adminInfo: nil, banInfo: nil, rank: nil), peer: participant.peer))
                    if let presence = participant.presence, peerPresences[participant.peer.id] == nil {
                        peerPresences[participant.peer.id] = presence
                    }
                    if peers[participant.peer.id] == nil {
                        peers[participant.peer.id] = participant.peer
                    }
                    //disabledPeerIds.insert(participant.peer.id)
                }
            }
        }
        
        let sortedParticipants: [RenderedChannelParticipant]
        if memberCount < 200 {
            sortedParticipants = updatedParticipants.sorted(by: { lhs, rhs in
                let lhsPresence = lhs.presences[lhs.peer.id] as? TelegramUserPresence
                let rhsPresence = rhs.presences[rhs.peer.id] as? TelegramUserPresence
                if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                    if lhsPresence.status < rhsPresence.status {
                        return false
                    } else if lhsPresence.status > rhsPresence.status {
                        return true
                    }
                } else if let _ = lhsPresence {
                    return true
                } else if let _ = rhsPresence {
                    return false
                }
                
                switch lhs.participant {
                    case .creator:
                        return false
                    case let .member(lhsId, lhsInvitedAt, _, _, _):
                        switch rhs.participant {
                            case .creator:
                                return true
                            case let .member(rhsId, rhsInvitedAt, _, _, _):
                                if lhsInvitedAt == rhsInvitedAt {
                                    return lhsId.id < rhsId.id
                                }
                                return lhsInvitedAt > rhsInvitedAt
                        }
                }
            })
        } else {
            sortedParticipants = updatedParticipants
        }
        
        var expanded = state.expandedParticipants
        let participants: [RenderedChannelParticipant]
        if expanded {
            participants = sortedParticipants
        } else {
            if sortedParticipants.count > maxParticipantsDisplayedCollapseLimit {
                participants = Array(sortedParticipants.prefix(Int(maxParticipantsDisplayedLimit)))
            } else {
                participants = sortedParticipants
                expanded = true
            }
        }
        
        for i in 0 ..< participants.count {
            let participant = participants[i]
            let memberStatus: GroupInfoMemberStatus
            switch participant.participant {
                case let .creator(_, rank):
                    memberStatus = .owner(rank: rank)
                case let .member(_, _, adminInfo, _, rank):
                    if adminInfo != nil {
                        memberStatus = .admin(rank: rank)
                    } else {
                        memberStatus = .member
                    }
            }
            
            var canPromote: Bool
            var canRestrict: Bool
            if participant.peer.id == account.peerId {
                canPromote = false
                canRestrict = false
            } else {
                switch participant.participant {
                    case .creator:
                        canPromote = false
                        canRestrict = false
                    case let .member(_, _, adminRights, bannedRights, _):
                        if channel.hasPermission(.addAdmins) {
                            canPromote = true
                        } else {
                            canPromote = false
                        }
                        if channel.hasPermission(.banMembers) {
                            canRestrict = true
                        } else {
                            canRestrict = false
                        }
                        if canPromote {
                            if let bannedRights = bannedRights {
                                if bannedRights.restrictedBy != account.peerId && !channel.flags.contains(.isCreator) {
                                    canPromote = false
                                }
                            }
                        }
                        if canRestrict {
                            if let adminRights = adminRights {
                                if adminRights.promotedBy != account.peerId && !channel.flags.contains(.isCreator) {
                                    canRestrict = false
                                }
                            }
                        }
                }
            }
            
            var peerActions: [ParticipantRevealAction] = []
            if canPromote {
                peerActions.append(ParticipantRevealAction(type: .neutral, title: presentationData.strings.GroupInfo_ActionPromote, action: .promote))
            }
            if canRestrict {
                peerActions.append(ParticipantRevealAction(type: .warning, title: presentationData.strings.GroupInfo_ActionRestrict, action: .restrict))
                peerActions.append(ParticipantRevealAction(type: .destructive, title: presentationData.strings.Common_Delete, action: .remove))
            }
            
            entries.append(GroupInfoEntry.member(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, index: i, peerId: participant.peer.id, peer: participant.peer, participant: participant, presence: participant.presences[participant.peer.id], memberStatus: memberStatus, editing: ItemListPeerItemEditing(editable: !peerActions.isEmpty, editing: state.editingState != nil && canRemoveAnyMember, revealed: state.peerIdWithRevealedOptions == participant.peer.id), revealActions: peerActions, enabled: true, selectable: participant.peer.id != account.peerId))
        }
        
        if !expanded {
            entries.append(GroupInfoEntry.expand(presentationData.theme, presentationData.strings.GroupInfo_ShowMoreMembers(Int32(memberCount - maxParticipantsDisplayedLimit))))
        }
    }
    
    if let group = view.peers[view.peerId] as? TelegramGroup {
        if case .Member = group.membership {
            entries.append(.leave(presentationData.theme, presentationData.strings.Group_LeaveGroup))
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        if case .member = channel.participationStatus {
            if channel.flags.contains(.isCreator) {
                if let cachedChannelData = view.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount, memberCount <= 200 {
                    if state.editingState != nil {
                        entries.append(.leave(presentationData.theme, presentationData.strings.ChannelInfo_DeleteGroup))
                    } else {
                        entries.append(.leave(presentationData.theme, presentationData.strings.Group_LeaveGroup))
                    }
                }
            } else {
                entries.append(.leave(presentationData.theme, presentationData.strings.Group_LeaveGroup))
            }
        }
    }
    
    return entries
}

private func valuesRequiringUpdate(state: GroupInfoState, view: PeerView) -> (title: String?, description: String?) {
    if let peer = view.peers[view.peerId] as? TelegramGroup {
        var titleValue: String?
        var descriptionValue: String?
        if let editingState = state.editingState {
            if let title = editingState.editingName?.composedTitle, title != peer.title {
                titleValue = title
            }
            if let cachedData = view.cachedData as? CachedGroupData {
                if let about = cachedData.about {
                    if about != editingState.editingDescriptionText {
                        descriptionValue = editingState.editingDescriptionText
                    }
                } else if !editingState.editingDescriptionText.isEmpty {
                    descriptionValue = editingState.editingDescriptionText
                }
            }
        }
        return (titleValue, descriptionValue)
    } else if let peer = view.peers[view.peerId] as? TelegramChannel {
        var titleValue: String?
        var descriptionValue: String?
        if let editingState = state.editingState {
            if let title = editingState.editingName?.composedTitle, title != peer.title {
                titleValue = title
            }
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about {
                    if about != editingState.editingDescriptionText {
                        descriptionValue = editingState.editingDescriptionText
                    }
                } else if !editingState.editingDescriptionText.isEmpty {
                    descriptionValue = editingState.editingDescriptionText
                }
            }
        }
        return (titleValue, descriptionValue)
    } else {
        return (nil, nil)
    }
}

public func groupInfoController(context: AccountContext, peerId originalPeerId: PeerId, membersLoaded: @escaping () -> Void = {}) -> ViewController {
    let statePromise = ValuePromise(GroupInfoState(updatingAvatar: nil, editingState: nil, updatingName: nil, peerIdWithRevealedOptions: nil, expandedParticipants: false, temporaryParticipants: [], successfullyAddedParticipantIds: Set(), removingParticipantIds: Set(), savingData: false, searchingMembers: false), ignoreRepeated: true)
    let stateValue = Atomic(value: GroupInfoState(updatingAvatar: nil, editingState: nil, updatingName: nil, peerIdWithRevealedOptions: nil, expandedParticipants: false, temporaryParticipants: [], successfullyAddedParticipantIds: Set(), removingParticipantIds: Set(), savingData: false, searchingMembers: false))
    let updateState: ((GroupInfoState) -> GroupInfoState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var replaceControllerImpl: ((ViewController?, ViewController) -> Void)?
    var endEditingImpl: (() -> Void)?
    var removePeerChatImpl: ((Peer, Bool) -> Void)?
    var errorImpl: (() -> Void)?
    var clearHighlightImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updatePeerNameDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerNameDisposable)
    
    let updatePeerDescriptionDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerDescriptionDisposable)
    
    let addMemberDisposable = MetaDisposable()
    actionsDisposable.add(addMemberDisposable)
    let selectAddMemberDisposable = MetaDisposable()
    actionsDisposable.add(selectAddMemberDisposable)
    
    let removeMemberDisposable = MetaDisposable()
    actionsDisposable.add(removeMemberDisposable)
    
    let changeMuteSettingsDisposable = MetaDisposable()
    actionsDisposable.add(changeMuteSettingsDisposable)
    
    let hiddenAvatarRepresentationDisposable = MetaDisposable()
    actionsDisposable.add(hiddenAvatarRepresentationDisposable)
    
    let updateAvatarDisposable = MetaDisposable()
    actionsDisposable.add(updateAvatarDisposable)
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    let navigateDisposable = MetaDisposable()
    actionsDisposable.add(navigateDisposable)
    
    let upgradeDisposable = MetaDisposable()
    actionsDisposable.add(upgradeDisposable)
    
    var avatarGalleryTransitionArguments: ((AvatarGalleryEntry) -> GalleryTransitionArguments?)?
    let avatarAndNameInfoContext = ItemListAvatarAndNameInfoItemContext()
    var updateHiddenAvatarImpl: (() -> Void)?
    
    var displayCopyContextMenuImpl: ((String, GroupInfoEntryTag) -> Void)?
    var aboutLinkActionImpl: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    
    var upgradedToSupergroupImpl: ((PeerId, @escaping () -> Void) -> Void)?
    
    let actualPeerId = Promise<PeerId>()
    actualPeerId.set(context.account.viewTracker.peerView(originalPeerId)
    |> map { peerView -> PeerId in
        if let peer = peerView.peers[peerView.peerId] as? TelegramGroup, let migrationReference = peer.migrationReference {
            return migrationReference.peerId
        } else {
            return originalPeerId
        }
    }
    |> distinctUntilChanged)
    
    let peerView = Promise<PeerView>()
    let peerViewSignal = actualPeerId.get()
    |> distinctUntilChanged
    |> mapToSignal { peerId -> Signal<PeerView, NoError> in
        return context.account.viewTracker.peerView(peerId, updateData: true)
    }
    peerView.set(peerViewSignal)
    
    let arguments = GroupInfoArguments(context: context, avatarAndNameInfoContext: avatarAndNameInfoContext, tapAvatarAction: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            guard let peer = peerView.peers[peerView.peerId] else {
                return
            }
            if peer.profileImageRepresentations.isEmpty {
                return
            }
            
            let galleryController = AvatarGalleryController(context: context, peer: peer, replaceRootController: { controller, ready in
                
            })
            hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
                avatarAndNameInfoContext.hiddenAvatarRepresentation = entry?.representations.first?.representation
                updateHiddenAvatarImpl?()
            }))
            presentControllerImpl?(galleryController, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                return avatarGalleryTransitionArguments?(entry)
            }))
        })
    }, changeProfilePhoto: {
        endEditingImpl?()
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            let _ = (context.account.postbox.transaction { transaction -> (Peer?, SearchBotsConfiguration) in
                return (transaction.getPeer(peerView.peerId), currentSearchBotsConfiguration(transaction: transaction))
                } |> deliverOnMainQueue).start(next: { peer, searchBotsConfiguration in
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    
                    let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
                    legacyController.statusBar.statusBarStyle = .Ignore
                    
                    let emptyController = LegacyEmptyController(context: legacyController.context)!
                    let navigationController = makeLegacyNavigationController(rootController: emptyController)
                    navigationController.setNavigationBarHidden(true, animated: false)
                    navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
                    
                    legacyController.bind(controller: navigationController)
                    
                    presentControllerImpl?(legacyController, nil)
                    
                    var hasPhotos = false
                    if let peer = peer, !peer.profileImageRepresentations.isEmpty {
                        hasPhotos = true
                    }
                    
                    let completedImpl: (UIImage) -> Void = { image in
                        if let data = image.jpegData(compressionQuality: 0.6) {
                            let resource = LocalFileMediaResource(fileId: arc4random64())
                            context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                            let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource)
                            updateState {
                                $0.withUpdatedUpdatingAvatar(.image(representation, true))
                            }
                            updateAvatarDisposable.set((updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.account.peerId, peerId: peerView.peerId, photo: uploadedPeerPhoto(postbox: context.account.postbox, network: context.account.network, resource: resource), mapResourceToAvatarSizes: { resource, representations in
                                return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                            }) |> deliverOnMainQueue).start(next: { result in
                                switch result {
                                case .complete:
                                    updateState {
                                        $0.withUpdatedUpdatingAvatar(nil)
                                    }
                                case .progress:
                                    break
                                }
                            }))
                        }
                    }
                    
                    let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: hasPhotos, hasViewButton: false, personalPhoto: false, saveEditedPhotos: false, saveCapturedMedia: false, signup: false)!
                    let _ = currentAvatarMixin.swap(mixin)
                    mixin.requestSearchController = { assetsController in
                        let controller = WebSearchController(context: context, peer: peer, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), completion: { result in
                            assetsController?.dismiss()
                            completedImpl(result)
                        }))
                        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    }
                    mixin.didFinishWithImage = { image in
                        if let image = image {
                           completedImpl(image)
                        }
                    }
                    mixin.didFinishWithDelete = {
                        let _ = currentAvatarMixin.swap(nil)
                        updateState {
                            if let profileImage = peer?.smallProfileImage {
                                return $0.withUpdatedUpdatingAvatar(.image(profileImage, false))
                            } else {
                                return $0.withUpdatedUpdatingAvatar(.none)
                            }
                        }
                        updateAvatarDisposable.set((updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.account.peerId, peerId: peerView.peerId, photo: nil, mapResourceToAvatarSizes: { resource, representations in
                            return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                        }) |> deliverOnMainQueue).start(next: { result in
                            switch result {
                                case .complete:
                                    updateState {
                                        $0.withUpdatedUpdatingAvatar(nil)
                                    }
                                case .progress:
                                    break
                            }
                        }))
                    }
                    mixin.didDismiss = { [weak legacyController] in
                        let _ = currentAvatarMixin.swap(nil)
                        legacyController?.dismiss()
                    }
                    let menuController = mixin.present()
                    if let menuController = menuController {
                        menuController.customRemoveFromParentViewController = { [weak legacyController] in
                            legacyController?.dismiss()
                        }
                    }
            })
        })
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, presentController: { controller, presentationArguments in
        presentControllerImpl?(controller, presentationArguments)
    }, changeNotificationMuteSettings: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let _ = (context.account.postbox.transaction { transaction -> (TelegramPeerNotificationSettings, GlobalNotificationSettings) in
                let peerSettings: TelegramPeerNotificationSettings = (transaction.getPeerNotificationSettings(peerView.peerId) as? TelegramPeerNotificationSettings) ?? TelegramPeerNotificationSettings.defaultSettings
                let globalSettings: GlobalNotificationSettings = (transaction.getPreferencesEntry(key: PreferencesKeys.globalNotifications) as? GlobalNotificationSettings) ?? GlobalNotificationSettings.defaultSettings
                return (peerSettings, globalSettings)
            }
            |> deliverOnMainQueue).start(next: { peerSettings, globalSettings in
                let soundSettings: NotificationSoundSettings?
                if case .default = peerSettings.messageSound {
                    soundSettings = NotificationSoundSettings(value: nil)
                } else {
                    soundSettings = NotificationSoundSettings(value: peerSettings.messageSound)
                }
                let controller = notificationMuteSettingsController(presentationData: presentationData, notificationSettings: globalSettings.effective.groupChats, soundSettings: soundSettings, openSoundSettings: {
                    let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: peerSettings.messageSound, defaultSound: globalSettings.effective.groupChats.sound, completion: { sound in
                        let _ = updatePeerNotificationSoundInteractive(account: context.account, peerId: peerView.peerId, sound: sound).start()
                    })
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }, updateSettings: { value in
                    changeMuteSettingsDisposable.set(updatePeerMuteSetting(account: context.account, peerId: peerView.peerId, muteInterval: value).start())
                })
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })
        })
    }, openPreHistory: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            presentControllerImpl?(groupPreHistorySetupController(context: context, peerId: peerView.peerId, upgradedToSupergroup: { peerId, f in
                upgradedToSupergroupImpl?(peerId, f)
            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, openSharedMedia: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            if let controller = context.sharedContext.makePeerSharedMediaController(context: context, peerId: peerView.peerId) {
                pushControllerImpl?(controller)
            }
        })
    }, openAdministrators: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            pushControllerImpl?(channelAdminsController(context: context, peerId: peerView.peerId))
        })
    }, openPermissions: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            pushControllerImpl?(channelPermissionsController(context: context, peerId: peerView.peerId))
        })
    }, updateEditingName: { editingName in
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(GroupInfoEditingState(editingName: editingName, editingDescriptionText: editingState.editingDescriptionText))
            } else {
                return state
            }
        }
    }, updateEditingDescriptionText: { text in
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(editingState.withUpdatedEditingDescriptionText(text))
            }
            return state
        }
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, addMember: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            let members: Promise<[PeerId]> = Promise()
            if peerView.peerId.namespace == Namespaces.Peer.CloudChannel {
                var membersDisposable: Disposable?
                let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { listState in
                    members.set(.single(listState.list.map {$0.peer.id}))
                    membersDisposable?.dispose()
                })
                membersDisposable = disposable
            } else {
                members.set(.single([]))
            }
            
            let _ = (combineLatest(queue: .mainQueue(), context.account.postbox.loadedPeerWithId(peerView.peerId)
                |> deliverOnMainQueue, members.get() |> take(1) |> deliverOnMainQueue)).start(next: { groupPeer, recentIds in
                var confirmationImpl: ((PeerId) -> Signal<Bool, NoError>)?
                var options: [ContactListAdditionalOption] = []
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                var inviteByLinkImpl: (() -> Void)?
                
                var canCreateInviteLink = false
                if let group = groupPeer as? TelegramGroup {
                    switch group.role {
                        case .creator, .admin:
                            canCreateInviteLink = true
                        default:
                            break
                    }
                } else if let channel = groupPeer as? TelegramChannel {
                    if channel.hasPermission(.inviteMembers) {
                        if channel.flags.contains(.isCreator) || (channel.adminRights != nil && channel.username == nil) {
                            canCreateInviteLink = true
                        }
                    }
                }
                
                if canCreateInviteLink {
                    options.append(ContactListAdditionalOption(title: presentationData.strings.GroupInfo_InviteByLink, icon: .generic(UIImage(bundleImageName: "Contact List/LinkActionIcon")!), action: {
                        inviteByLinkImpl?()
                    }))
                }
                
                let contactsController: ViewController
                if peerView.peerId.namespace == Namespaces.Peer.CloudGroup {
                    contactsController = context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(context: context, autoDismiss: false, title: { $0.GroupInfo_AddParticipantTitle }, options: options, confirmation: { peer in
                        if let confirmationImpl = confirmationImpl, case let .peer(peer, _, _) = peer {
                            return confirmationImpl(peer.id)
                        } else {
                            return .single(false)
                        }
                    }))
                } else {
                    contactsController = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .peerSelection(searchChatList: false, searchGroups: false, searchChannels: false), options: options, filters: [.excludeSelf, .disable(recentIds)]))
                }
                
                confirmationImpl = { [weak contactsController] peerId in
                    return context.account.postbox.loadedPeerWithId(peerId)
                    |> deliverOnMainQueue
                    |> mapToSignal { peer in
                        let result = ValuePromise<Bool>()
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        if let contactsController = contactsController {
                            let alertController = textAlertController(context: context, title: nil, text: presentationData.strings.GroupInfo_AddParticipantConfirmation(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).0, actions: [
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_No, action: {
                                    result.set(false)
                                }),
                                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
                                    result.set(true)
                                })
                            ])
                            contactsController.present(alertController, in: .window(.root))
                        }
                        
                        return result.get()
                    }
                }
                
                let addMember: (ContactListPeer) -> Signal<Void, NoError> = { memberPeer -> Signal<Void, NoError> in
                    if case let .peer(selectedPeer, _, _) = memberPeer {
                        let memberId = selectedPeer.id
                        if peerView.peerId.namespace == Namespaces.Peer.CloudChannel {
                            return context.peerChannelMemberCategoriesContextsManager.addMember(account: context.account, peerId: peerView.peerId, memberId: memberId)
                            |> map { _ -> Void in
                                return Void()
                            }
                            |> `catch` { _ -> Signal<Void, NoError> in
                                return .complete()
                            }
                        }
                        
                        if let peer = peerView.peers[memberId] {
                            updateState { state in
                                var found = false
                                for participant in state.temporaryParticipants {
                                    if participant.peer.id == memberId {
                                        found = true
                                        break
                                    }
                                }
                                if !found {
                                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                    var temporaryParticipants = state.temporaryParticipants
                                    temporaryParticipants.append(TemporaryParticipant(peer: peer, presence: peerView.peerPresences[memberId], timestamp: timestamp))
                                    return state.withUpdatedTemporaryParticipants(temporaryParticipants)
                                } else {
                                    return state
                                }
                            }
                        }
                        
                        return addGroupMember(account: context.account, peerId: peerView.peerId, memberId: memberId)
                        |> deliverOnMainQueue
                        |> afterCompleted {
                            updateState { state in
                                var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                                successfullyAddedParticipantIds.insert(memberId)
                                
                                return state.withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds)
                            }
                        }
                        |> `catch` { error -> Signal<Void, NoError> in
                            switch error {
                                case .generic:
                                    updateState { state in
                                        var temporaryParticipants = state.temporaryParticipants
                                        for i in 0 ..< temporaryParticipants.count {
                                            if temporaryParticipants[i].peer.id == memberId {
                                                temporaryParticipants.remove(at: i)
                                                break
                                            }
                                        }
                                        var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                                        successfullyAddedParticipantIds.remove(memberId)
                                        
                                        return state.withUpdatedTemporaryParticipants(temporaryParticipants).withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds)
                                    }
                                    return .complete()
                                case .privacy, .notMutualContact:
                                    let _ = (context.account.postbox.loadedPeerWithId(memberId)
                                    |> deliverOnMainQueue).start(next: { peer in
                                        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(peer.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                    })
                                
                                    updateState { state in
                                        var temporaryParticipants = state.temporaryParticipants
                                        for i in 0 ..< temporaryParticipants.count {
                                            if temporaryParticipants[i].peer.id == memberId {
                                                temporaryParticipants.remove(at: i)
                                                break
                                            }
                                        }
                                        var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                                        successfullyAddedParticipantIds.remove(memberId)
                                        
                                        return state.withUpdatedTemporaryParticipants(temporaryParticipants).withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds)
                                    }
                                    return .complete()
                                case .tooManyChannels:
                                    let _ = (context.account.postbox.loadedPeerWithId(memberId)
                                    |> deliverOnMainQueue).start(next: { peer in
                                        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Invite_ChannelsTooMuch, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                    })
                                
                                    updateState { state in
                                        var temporaryParticipants = state.temporaryParticipants
                                        for i in 0 ..< temporaryParticipants.count {
                                            if temporaryParticipants[i].peer.id == memberId {
                                                temporaryParticipants.remove(at: i)
                                                break
                                            }
                                        }
                                        var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                                        successfullyAddedParticipantIds.remove(memberId)
                                        
                                        return state.withUpdatedTemporaryParticipants(temporaryParticipants).withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds)
                                    }
                                    return .complete()
                                case .groupFull:
                                    let signal = convertGroupToSupergroup(account: context.account, peerId: peerView.peerId)
                                    |> map(Optional.init)
                                    |> `catch` { error -> Signal<PeerId?, NoError> in
                                        switch error {
                                        case .tooManyChannels:
                                            Queue.mainQueue().async {
                                                pushControllerImpl?(oldChannelsController(context: context, intent: .upgrade))
                                            }
                                        default:
                                            break
                                        }
                                        return .single(nil)
                                    }
                                    |> mapToSignal { upgradedPeerId -> Signal<PeerId?, NoError> in
                                        guard let upgradedPeerId = upgradedPeerId else {
                                            return .single(nil)
                                        }
                                        return context.peerChannelMemberCategoriesContextsManager.addMember(account: context.account, peerId: upgradedPeerId, memberId: memberId)
                                        |> `catch` { _ -> Signal<Never, NoError> in
                                            return .complete()
                                        }
                                        |> mapToSignal { _ -> Signal<PeerId?, NoError> in
                                            return .complete()
                                        }
                                        |> then(.single(upgradedPeerId))
                                    }
                                    |> deliverOnMainQueue
                                    |> mapToSignal { upgradedPeerId -> Signal<Void, NoError> in
                                        if let upgradedPeerId = upgradedPeerId {
                                            upgradedToSupergroupImpl?(upgradedPeerId, {})
                                        }
                                        return .complete()
                                    }
                                    return signal
                            }
                        }
                    } else {
                        return .complete()
                    }
                }
                
                let addMembers: ([ContactListPeerId]) -> Signal<Void, AddChannelMemberError> = { members -> Signal<Void, AddChannelMemberError> in
                    let memberIds = members.compactMap { contact -> PeerId? in
                        switch contact {
                        case let .peer(peerId):
                            return peerId
                        default:
                            return nil
                        }
                    }
                    return context.account.postbox.multiplePeersView(memberIds)
                    |> take(1)
                    |> deliverOnMainQueue
                    |> mapError { _ in return .generic}
                    |> mapToSignal { view -> Signal<Void, AddChannelMemberError> in
                        if memberIds.count == 1 {
                            return context.peerChannelMemberCategoriesContextsManager.addMember(account: context.account, peerId: peerView.peerId, memberId: memberIds[0])
                            |> map { _ -> Void in
                                return Void()
                            }
                        } else {
                            return context.peerChannelMemberCategoriesContextsManager.addMembers(account: context.account, peerId: peerView.peerId, memberIds: memberIds) |> map { _ in
                                updateState { state in
                                    var state = state
                                    for (memberId, peer) in view.peers {
                                        var found = false
                                        for participant in state.temporaryParticipants {
                                            if participant.peer.id == memberId {
                                                found = true
                                                break
                                            }
                                        }
                                        if !found {
                                            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                            var temporaryParticipants = state.temporaryParticipants
                                            temporaryParticipants.append(TemporaryParticipant(peer: peer, presence: view.presences[memberId], timestamp: timestamp))
                                            state = state.withUpdatedTemporaryParticipants(temporaryParticipants)
                                        }
                                    }
                                    
                                    return state
                                }
                            }
                        }
                    }
                }
                
                inviteByLinkImpl = { [weak contactsController] in
                    let mode: ChannelVisibilityControllerMode
                    if groupPeer.addressName != nil {
                        mode = .generic
                    } else {
                        mode = .privateLink
                    }
                    let controller = channelVisibilityController(context: context, peerId: peerView.peerId, mode: mode, upgradedToSupergroup: { updatedPeerId, f in
                        upgradedToSupergroupImpl?(updatedPeerId, f)
                    })
                    controller.navigationPresentation = .modal
                    replaceControllerImpl?(contactsController, controller)
                }

                presentControllerImpl?(contactsController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                if let contactsController = contactsController as? ContactSelectionController {
                    selectAddMemberDisposable.set((contactsController.result
                    |> deliverOnMainQueue).start(next: { [weak contactsController] memberPeer in
                        guard let memberPeer = memberPeer else {
                            return
                        }
                        
                        contactsController?.displayProgress = true
                        addMemberDisposable.set((addMember(memberPeer)
                        |> deliverOnMainQueue).start(completed: {
                            contactsController?.dismiss()
                        }))
                    }))
                    contactsController.dismissed = {
                        selectAddMemberDisposable.set(nil)
                        addMemberDisposable.set(nil)
                    }
                }
                if let contactsController = contactsController as? ContactMultiselectionController {
                    selectAddMemberDisposable.set((contactsController.result
                    |> deliverOnMainQueue).start(next: { [weak contactsController] result in
                        var peers: [ContactListPeerId] = []
                        if case let .result(peerIdsValue, _) = result {
                            peers = peerIdsValue
                        }
                        
                        contactsController?.displayProgress = true
                        addMemberDisposable.set((addMembers(peers)
                        |> deliverOnMainQueue).start(error: { error in
                            if peers.count == 1, case .restricted = error {
                                switch peers[0] {
                                    case let .peer(peerId):
                                        let _ = (context.account.postbox.loadedPeerWithId(peerId)
                                        |> deliverOnMainQueue).start(next: { peer in
                                            presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(peer.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                        })
                                    default:
                                        break
                                }
                            } else if case .tooMuchJoined = error  {
                                presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Invite_ChannelsTooMuch, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                            }
                            
                            contactsController?.dismiss()
                        },completed: {
                            contactsController?.dismiss()
                        }))
                    }))
                    contactsController.dismissed = {
                        selectAddMemberDisposable.set(nil)
                        addMemberDisposable.set(nil)
                    }
                }
            })
        })
    }, promotePeer: { participant in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            pushControllerImpl?(channelAdminController(context: context, peerId: peerView.peerId, adminId: participant.peer.id, initialParticipant: participant.participant, updated: { _ in
            }, upgradedToSupergroup: { upgradedPeerId, f in
                upgradedToSupergroupImpl?(upgradedPeerId, f)
            }, transferedOwnership: { _ in }))
        })
    }, restrictPeer: { participant in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            presentControllerImpl?(channelBannedMemberController(context: context, peerId: peerView.peerId, memberId: participant.peer.id, initialParticipant: participant.participant, updated: { _ in
            }, upgradedToSupergroup: { upgradedPeerId, f in
                upgradedToSupergroupImpl?(upgradedPeerId, f)
            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, removePeer: { memberId in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            let signal = context.account.postbox.loadedPeerWithId(memberId)
            |> deliverOnMainQueue
            |> mapToSignal { peer -> Signal<Bool, NoError> in
                let result = ValuePromise<Bool>()
                result.set(true)
                return result.get()
            }
            |> mapToSignal { value -> Signal<Void, NoError> in
                if value {
                    updateState { state in
                        var temporaryParticipants = state.temporaryParticipants
                        for i in 0 ..< state.temporaryParticipants.count {
                            if state.temporaryParticipants[i].peer.id == memberId {
                                temporaryParticipants.remove(at: i)
                                break
                            }
                        }
                        var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                        successfullyAddedParticipantIds.remove(memberId)
                        
                        var removingParticipantIds = state.removingParticipantIds
                        removingParticipantIds.insert(memberId)
                        
                        return state.withUpdatedTemporaryParticipants(temporaryParticipants).withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds).withUpdatedRemovingParticipantIds(removingParticipantIds)
                    }
                    
                    if peerView.peerId.namespace == Namespaces.Peer.CloudChannel {
                        return context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: context.account, peerId: peerView.peerId, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max))
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                updateState { state in
                                    var removingParticipantIds = state.removingParticipantIds
                                    removingParticipantIds.remove(memberId)
                                    
                                    return state.withUpdatedRemovingParticipantIds(removingParticipantIds)
                                }
                            }
                        }
                    }
                    
                    return removePeerMember(account: context.account, peerId: peerView.peerId, memberId: memberId)
                    |> deliverOnMainQueue
                    |> afterDisposed {
                        updateState { state in
                            var removingParticipantIds = state.removingParticipantIds
                            removingParticipantIds.remove(memberId)
                            
                            return state.withUpdatedRemovingParticipantIds(removingParticipantIds)
                        }
                    }
                } else {
                    return .complete()
                }
            }
            removeMemberDisposable.set(signal.start())
        })
    }, leave: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            if let channel = peerView.peers[peerView.peerId] as? TelegramChannel, channel.flags.contains(.isCreator), stateValue.with({ $0 }).editingState != nil {
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                
                var items: [ActionSheetItem] = []
                items.append(ActionSheetTextItem(title: presentationData.strings.ChannelInfo_DeleteGroupConfirmation))
                items.append(ActionSheetButtonItem(title: presentationData.strings.ChannelInfo_DeleteGroup, color: .destructive, action: {
                    dismissAction()
                    removePeerChatImpl?(channel, true)
                }))
                controller.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            } else if let peer = peerView.peers[peerView.peerId] {
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                
                var items: [ActionSheetItem] = []
                if peerView.peerId.namespace == Namespaces.Peer.CloudGroup {
                    items.append(ActionSheetTextItem(title: presentationData.strings.GroupInfo_DeleteAndExitConfirmation))
                }
                items.append(ActionSheetButtonItem(title: presentationData.strings.Group_LeaveGroup, color: .destructive, action: {
                    dismissAction()
                    removePeerChatImpl?(peer, false)
                }))
                controller.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        })
    }, displayUsernameShareMenu: { text in
        let shareController = ShareController(context: context, subject: .url(text))
        presentControllerImpl?(shareController, nil)
    }, displayUsernameContextMenu: { text in
        displayCopyContextMenuImpl?(text, .link)
    }, displayAboutContextMenu: { text in
        displayCopyContextMenuImpl?(text, .about)
    }, aboutLinkAction: { action, itemLink in
        aboutLinkActionImpl?(action, itemLink)
    }, openStickerPackSetup: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            let _ = (context.account.postbox.transaction { transaction -> StickerPackCollectionInfo? in
                return (transaction.getPeerCachedData(peerId: peerView.peerId) as? CachedChannelData)?.stickerPack
            }
            |> deliverOnMainQueue).start(next: { stickerPack in
                presentControllerImpl?(groupStickerPackSetupController(context: context, peerId: peerView.peerId, currentPackInfo: stickerPack), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })
        })
    }, openGroupTypeSetup: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            presentControllerImpl?(channelVisibilityController(context: context, peerId: peerView.peerId, mode: .generic, upgradedToSupergroup: { updatedPeerId, f in
                upgradedToSupergroupImpl?(updatedPeerId, f)
            }), ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
        })
    }, openLinkedChannelSetup: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            pushControllerImpl?(channelDiscussionGroupSetupController(context: context, peerId: peerView.peerId))
        })
    }, openLocation: { location in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            guard let peer = peerView.peers[peerView.peerId] else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let mapMedia = TelegramMediaMap(latitude: location.latitude, longitude: location.longitude, geoPlace: nil, venue: MapVenue(title: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), address: location.address, provider: nil, id: nil, type: nil), liveBroadcastingTimeout: nil)
            let controller = legacyLocationController(message: nil, mapMedia: mapMedia, context: context, openPeer: { _ in }, sendLiveLocation: { _, _ in }, stopLiveLocation: {}, openUrl: { url in
                context.sharedContext.applicationBindings.openUrl(url)
            })
            pushControllerImpl?(controller)
        })
    }, changeLocation: {
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            guard let peer = peerView.peers[peerView.peerId] else {
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = legacyLocationPickerController(context: context, selfPeer: peer, peer: peer, sendLocation: { coordinate, _, address in
                let addressSignal: Signal<String, NoError>
                if let address = address {
                    addressSignal = .single(address)
                } else {
                    addressSignal = reverseGeocodeLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    |> map { placemark in
                        if let placemark = placemark {
                            return placemark.fullAddress
                        } else {
                            return "\(coordinate.latitude), \(coordinate.longitude)"
                        }
                    }
                }
                
                let _ = (addressSignal
                |> mapToSignal { address -> Signal<Bool, NoError> in
                    return updateChannelGeoLocation(postbox: context.account.postbox, network: context.account.network, channelId: peer.id, coordinate: (coordinate.latitude, coordinate.longitude), address: address)
                }
                |> deliverOnMainQueue).start(error: { errror in
                     presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                })
            }, sendLiveLocation: { _, _ in }, theme: presentationData.theme, customLocationPicker: true, presentationCompleted: {
                clearHighlightImpl?()
            })
            pushControllerImpl?(controller)
        })
    }, displayLocationContextMenu: { text in
        displayCopyContextMenuImpl?(text, .location)
    }, expandParticipants: {
        updateState {
            $0.withUpdatedExpandedParticipants(true)
        }
    })
    
    let loadMoreControl = Atomic<(PeerId, PeerChannelMemberCategoryControl)?>(value: nil)
    let channelMembersPromise = Promise<[RenderedChannelParticipant]>()
    
    let channelMembersDisposable = MetaDisposable()
    actionsDisposable.add(channelMembersDisposable)
    
    var membersLoadedCalled = false
    
    actionsDisposable.add((actualPeerId.get()
    |> distinctUntilChanged
    |> deliverOnMainQueue).start(next: { peerId in
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            let (disposable, control) = context.peerChannelMemberCategoriesContextsManager.recent(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, updated: { state in
                channelMembersPromise.set(.single(state.list))
                if case .loading(true) = state.loadingState {
                } else if !membersLoadedCalled {
                    membersLoadedCalled = true
                    membersLoaded()
                }
            })
            if let control = control {
                let _ = loadMoreControl.swap((peerId, control))
            } else {
                let _ = loadMoreControl.swap(nil)
            }
            channelMembersDisposable.set(disposable)
        } else {
            let _ = loadMoreControl.swap(nil)
            channelMembersPromise.set(.single([]))
            channelMembersDisposable.set(nil)
            if !membersLoadedCalled {
                membersLoadedCalled = true
                membersLoaded()
            }
        }
    }))
    
    let previousStateValue = Atomic<GroupInfoState?>(value: nil)
    let previousChannelMembers = Atomic<[PeerId]?>(value: nil)
    
    let searchContext = GroupMembersSearchContext(context: context, peerId: originalPeerId)
    
    let globalNotificationsKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([PreferencesKeys.globalNotifications]))
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get(), peerView.get(), context.account.postbox.combinedView(keys: [globalNotificationsKey]), channelMembersPromise.get())
    |> map { presentationData, state, view, combinedView, channelMembers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let peer = peerViewMainPeer(view)
        
        var globalNotificationSettings: GlobalNotificationSettings = GlobalNotificationSettings.defaultSettings
        if let preferencesView = combinedView.views[globalNotificationsKey] as? PreferencesView {
            if let settings = preferencesView.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                globalNotificationSettings = settings
            }
        }
        
        var canEditGroupInfo = false
        if let group = view.peers[view.peerId] as? TelegramGroup {
            switch group.role {
                case .admin, .creator:
                    canEditGroupInfo = true
                case .member:
                    break
            }
            if !group.hasBannedPermission(.banChangeInfo) {
                canEditGroupInfo = true
            }
        } else if let channel = view.peers[view.peerId] as? TelegramChannel {
            if channel.hasPermission(.changeInfo) || !(channel.adminRights?.flags ?? []).isEmpty {
                canEditGroupInfo = true
            }
        }
        
        var rightNavigationButton: ItemListNavigationButton?
        var secondaryRightNavigationButton: ItemListNavigationButton?
        if let editingState = state.editingState {
            var doneEnabled = true
            if let editingName = editingState.editingName, editingName.isEmpty {
                doneEnabled = false
            }
            if peer is TelegramChannel {
                if (view.cachedData as? CachedChannelData) == nil {
                    doneEnabled = false
                }
            }
            
            if state.savingData {
                rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: doneEnabled, action: {})
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: doneEnabled, action: {
                    var updateValues: (title: String?, description: String?) = (nil, nil)
                    var failed = false
                    updateState { state in
                        updateValues = valuesRequiringUpdate(state: state, view: view)
                        if updateValues.0 != nil || updateValues.1 != nil {
                            if (updateValues.description?.count ?? 0) > 255 {
                                failed = true
                                return state
                            }
                            return state.withUpdatedSavingData(true)
                        } else {
                            return state.withUpdatedEditingState(nil)
                        }
                    }
                    
                    guard !failed else {
                        errorImpl?()
                        return
                    }
                    
                    let updateTitle: Signal<Void, Void>
                    if let titleValue = updateValues.title {
                        updateTitle = updatePeerTitle(account: context.account, peerId: view.peerId, title: titleValue)
                            |> mapError { _ in return Void() }
                    } else {
                        updateTitle = .complete()
                    }
                    
                    let updateDescription: Signal<Void, Void>
                    if let descriptionValue = updateValues.description {
                        updateDescription = updatePeerDescription(account: context.account, peerId: view.peerId, description: descriptionValue.isEmpty ? nil : descriptionValue)
                            |> mapError { _ in return Void() }
                    } else {
                        updateDescription = .complete()
                    }
                    
                    let signal = combineLatest(queue: .mainQueue(),
                        updateTitle,
                        updateDescription
                    )
                    
                    updatePeerNameDisposable.set((signal
                    |> deliverOnMainQueue).start(error: { _ in
                        updateState { state in
                            return state.withUpdatedSavingData(false)
                        }
                    }, completed: {
                        updateState { state in
                            return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                        }
                    }))
                })
            }
        } else if canEditGroupInfo {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                if let peer = peer as? TelegramGroup {
                    var text = ""
                    if let cachedData = view.cachedData as? CachedGroupData, let about = cachedData.about {
                        text = about
                    }
                    updateState { state in
                        return state.withUpdatedEditingState(GroupInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(peer), editingDescriptionText: text))
                    }
                } else if let channel = peer as? TelegramChannel, case .group = channel.info {
                    var text = ""
                    if let cachedData = view.cachedData as? CachedChannelData, let about = cachedData.about {
                        text = about
                    }
                    updateState { state in
                        return state.withUpdatedEditingState(GroupInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(channel), editingDescriptionText: text))
                    }
                }
            })
            if peer is TelegramChannel {
                secondaryRightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedSearchingMembers(true)
                    }
                })
            }
        } else {
            if peer is TelegramChannel {
                rightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedSearchingMembers(true)
                    }
                })
            }
        }
        
        var searchItem: ItemListControllerSearch?
        if state.searchingMembers {
            searchItem = ChannelMembersSearchItem(context: context, peerId: view.peerId, searchContext: searchContext, cancel: {
                updateState { state in
                    return state.withUpdatedSearchingMembers(false)
                }
            }, openPeer: { peer, _ in
                if let infoController = context.sharedContext.makePeerInfoController(context: context, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false) {
                    arguments.pushController(infoController)
                }
            }, pushController: { c in
                pushControllerImpl?(c)
            }, dismissInput: {
                dismissInputImpl?()
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.GroupInfo_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, secondaryRightNavigationButton: secondaryRightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        
        let entries = groupInfoEntries(account: context.account, presentationData: presentationData, view: view, channelMembers: channelMembers, globalNotificationSettings: globalNotificationSettings, state: state)
        var memberIds: [PeerId] = []
        for entry in entries {
            switch entry {
                case let .member(member):
                    memberIds.append(member.peerId)
                default:
                    break
            }
        }
        let previousState = previousStateValue.swap(state)
        let previousMembers = previousChannelMembers.swap(memberIds) ?? []
        
        var animateChanges = previousMembers.count > memberIds.count || (previousState != nil && (previousState!.editingState != nil) != (state.editingState != nil))
        if presentationData.disableAnimations {
            if Set(memberIds) == Set(previousMembers) && memberIds != previousMembers {
                animateChanges = false
            }
        }
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, searchItem: searchItem, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.view.endEditing(true)
        controller?.present(value, in: .window(.root), with: presentationArguments, blockInteraction: true)
    }
    replaceControllerImpl = { [weak controller] previous, updated in
        if let navigationController = controller?.navigationController as? NavigationController {
            var controllers = navigationController.viewControllers
            if let previous = previous {
                controllers.removeAll(where: { $0 === previous })
            }
            controllers.append(updated)
            navigationController.setViewControllers(controllers, animated: true)
        }
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    upgradedToSupergroupImpl = { [weak controller] upgradedPeerId, f in
        let _ = (context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(upgradedPeerId)
        }
        |> deliverOnMainQueue).start(next: { peer in
            guard let controller = controller, let navigationController = controller.navigationController as? NavigationController, let _ = peer else {
                return
            }
            let infoController = groupInfoController(context: context, peerId: upgradedPeerId, membersLoaded: {
                f()
            })
            let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(upgradedPeerId), subject: nil, botStart: nil, mode: .standard(previewing: false))
            var viewControllers: [UIViewController] = []
            if let first = navigationController.viewControllers.first {
                viewControllers.append(first)
            }
            viewControllers.append(chatController)
            viewControllers.append(infoController)
            navigationController.setViewControllers(viewControllers, animated: false)
        })
    }
    removePeerChatImpl = { [weak controller] peer, deleteGloballyIfPossible in
        guard let controller = controller, let navigationController = controller.navigationController as? NavigationController else {
            return
        }
        guard let tabController = navigationController.viewControllers.first as? TabBarController else {
            return
        }
        for childController in tabController.controllers {
            if let chatListController = childController as? ChatListController {
                chatListController.maybeAskForPeerChatRemoval(peer: RenderedPeer(peer: peer), deleteGloballyIfPossible: deleteGloballyIfPossible, completion: { [weak navigationController] removed in
                    if removed {
                        navigationController?.popToRoot(animated: true)
                    }
                }, removed: {
                })
                break
            }
        }
    }
    displayCopyContextMenuImpl = { [weak controller] text, tag in
        if let strongController = controller {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                var itemTag: GroupInfoEntryTag? = nil
                if let itemNode = itemNode as? ItemListMultilineTextItemNode {
                    if let tag = itemNode.tag as? GroupInfoEntryTag {
                        itemTag = tag
                    }
                }
                else if let itemNode = itemNode as? ItemListActionItemNode {
                    if let tag = itemNode.tag as? GroupInfoEntryTag {
                        itemTag = tag
                    }
                }
                else if let itemNode = itemNode as? ItemListAddressItemNode {
                    if let tag = itemNode.tag as? GroupInfoEntryTag {
                        itemTag = tag
                    }
                }
                if itemTag == tag {
                    resultItemNode = itemNode
                    return true
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: {
                    UIPasteboard.general.string = text
                })])
                strongController.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
                    if let strongController = controller, let resultItemNode = resultItemNode {
                        return (resultItemNode, resultItemNode.contentBounds.insetBy(dx: 0.0, dy: -2.0), strongController.displayNode, strongController.view.bounds)
                    } else {
                        return nil
                    }
                }))
                
            }
        }
    }
    
    aboutLinkActionImpl = { [weak context, weak controller] action, itemLink in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            if let controller = controller, let context = context {
                context.sharedContext.handleTextLinkAction(context: context, peerId: peerView.peerId, navigateDisposable: navigateDisposable, controller: controller, action: action, itemLink: itemLink)
            }
        })
    }
    
    avatarGalleryTransitionArguments = { [weak controller] entry in
        if let controller = controller {
            var result: ((ASDisplayNode, CGRect, () -> (UIView?, UIView?)), CGRect)?
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    result = itemNode.avatarTransitionNode()
                }
            }
            if let (node, _) = result {
                return GalleryTransitionArguments(transitionNode: node, addToTransitionSurface: { _ in
                })
            }
        }
        return nil
    }
    updateHiddenAvatarImpl = { [weak controller] in
        if let controller = controller {
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    itemNode.updateAvatarHidden()
                }
            }
        }
    }
    endEditingImpl = {
        [weak controller] in
        controller?.view.endEditing(true)
    }
    clearHighlightImpl = { [weak controller] in
        controller?.clearItemNodesHighlight(animated: true)
    }
    
    let hapticFeedback = HapticFeedback()
    errorImpl = { [weak controller] in
        hapticFeedback.error()
        controller?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListMultilineInputItemNode {
                itemNode.animateError()
            }
        }
    }
    
    controller.visibleBottomContentOffsetChanged = { offset in
        if let (peerId, loadMoreControl) = loadMoreControl.with({ $0 }), case let .known(value) = offset, value < 40.0 {
            if stateValue.with({ $0 }).expandedParticipants {
                context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
            }
        }
    }
    return controller
}
