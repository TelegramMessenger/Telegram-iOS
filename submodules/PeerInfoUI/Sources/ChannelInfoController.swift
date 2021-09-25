import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TextFormat
import OverlayStatusController
import TelegramStringFormatting
import ShareController
import AlertUI
import PresentationDataUtils
import GalleryUI
import LegacyUI
import LegacyMediaPickerUI
import ItemListAvatarAndNameInfoItem
import WebSearchUI
import PeerAvatarGalleryUI
import NotificationMuteSettingsUI
import MapResourceToAvatarSizes
import NotificationSoundSelectionUI
import Markdown

private final class ChannelInfoControllerArguments {
    let context: AccountContext
    let avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext
    let tapAvatarAction: () -> Void
    let changeProfilePhoto: () -> Void
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let updateEditingDescriptionText: (String) -> Void
    let openChannelTypeSetup: () -> Void
    let openDiscussionGroupSetup: () -> Void
    let changeNotificationMuteSettings: () -> Void
    let openSharedMedia: () -> Void
    let openStats: () -> Void
    let openAdmins: () -> Void
    let openMembers: () -> Void
    let openBanned: () -> Void
    let reportChannel: () -> Void
    let leaveChannel: () -> Void
    let deleteChannel: () -> Void
    let displayAddressNameContextMenu: (String) -> Void
    let displayContextMenu: (ChannelInfoEntryTag, String) -> Void
    let aboutLinkAction: (TextLinkItemActionType, TextLinkItem) -> Void
    let toggleSignatures: (Bool) -> Void
    
    init(context: AccountContext, avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext, tapAvatarAction: @escaping () -> Void, changeProfilePhoto: @escaping () -> Void, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, updateEditingDescriptionText: @escaping (String) -> Void, openChannelTypeSetup: @escaping () -> Void, openDiscussionGroupSetup: @escaping () -> Void, changeNotificationMuteSettings: @escaping () -> Void, openSharedMedia: @escaping () -> Void, openStats: @escaping () -> Void, openAdmins: @escaping () -> Void, openMembers: @escaping () -> Void, openBanned: @escaping () -> Void, reportChannel: @escaping () -> Void, leaveChannel: @escaping () -> Void, deleteChannel: @escaping () -> Void, displayAddressNameContextMenu: @escaping (String) -> Void, displayContextMenu: @escaping (ChannelInfoEntryTag, String) -> Void, aboutLinkAction: @escaping (TextLinkItemActionType, TextLinkItem) -> Void, toggleSignatures: @escaping(Bool)->Void) {
        self.context = context
        self.avatarAndNameInfoContext = avatarAndNameInfoContext
        self.tapAvatarAction = tapAvatarAction
        self.changeProfilePhoto = changeProfilePhoto
        self.updateEditingName = updateEditingName
        self.updateEditingDescriptionText = updateEditingDescriptionText
        self.openChannelTypeSetup = openChannelTypeSetup
        self.openDiscussionGroupSetup = openDiscussionGroupSetup
        self.changeNotificationMuteSettings = changeNotificationMuteSettings
        self.openSharedMedia = openSharedMedia
        self.openStats = openStats
        self.openAdmins = openAdmins
        self.openMembers = openMembers
        self.openBanned = openBanned
        self.reportChannel = reportChannel
        self.leaveChannel = leaveChannel
        self.deleteChannel = deleteChannel
        self.displayAddressNameContextMenu = displayAddressNameContextMenu
        self.displayContextMenu = displayContextMenu
        self.aboutLinkAction = aboutLinkAction
        self.toggleSignatures = toggleSignatures
    }
}

private enum ChannelInfoSection: ItemListSectionId {
    case info
    case discriptionAndType
    case sharedMediaAndNotifications
    case sign
    case members
    case reportOrLeave
}

private enum ChannelInfoEntryTag {
    case about
    case link
}

private enum ChannelInfoEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, peer: Peer?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState, updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?)
    case about(theme: PresentationTheme, text: String, value: String)
    case addressName(theme: PresentationTheme, text: String, value: String)
    case channelPhotoSetup(theme: PresentationTheme, text: String)
    case channelTypeSetup(theme: PresentationTheme, text: String, value: String)
    case discussionGroupSetup(theme: PresentationTheme, text: String, value: String)
    case discussionGroupSetupInfo(theme: PresentationTheme, text: String)
    case channelDescriptionSetup(theme: PresentationTheme, placeholder: String, value: String)
    case admins(theme: PresentationTheme, text: String, value: String)
    case members(theme: PresentationTheme, text: String, value: String)
    case banned(theme: PresentationTheme, text: String, value: String)
    case notifications(theme: PresentationTheme, text: String, value: String)
    case sharedMedia(theme: PresentationTheme, text: String)
    case stats(theme: PresentationTheme, text: String)
    case signMessages(theme: PresentationTheme, text: String, value: Bool)
    case signInfo(theme: PresentationTheme, text: String)
    case report(theme: PresentationTheme, text: String)
    case leave(theme: PresentationTheme, text: String)
    case deleteChannel(theme: PresentationTheme, text: String)
    
    var section: ItemListSectionId {
        switch self {
            case .info, .about, .addressName, .channelPhotoSetup, .channelDescriptionSetup:
                return ChannelInfoSection.info.rawValue
            case .channelTypeSetup, .discussionGroupSetup, .discussionGroupSetupInfo:
                return ChannelInfoSection.discriptionAndType.rawValue
            case .signMessages, .signInfo:
                return ChannelInfoSection.sign.rawValue
            case .admins, .members, .banned:
                return ChannelInfoSection.members.rawValue
            case .sharedMedia, .notifications, .stats:
                return ChannelInfoSection.sharedMediaAndNotifications.rawValue
            case .report, .leave, .deleteChannel:
                return ChannelInfoSection.reportOrLeave.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .info:
                return 0
            case .channelPhotoSetup:
                return 1
            case .addressName:
                return 2
            case .about:
                return 3
            case .channelDescriptionSetup:
                return 4
            case .channelTypeSetup:
                return 5
            case .discussionGroupSetup:
                return 6
            case .discussionGroupSetupInfo:
                return 7
            case .signMessages:
                return 8
            case .signInfo:
                return 9
            case .admins:
                return 10
            case .members:
                return 11
            case .banned:
                return 12
            case .notifications:
                return 13
            case .sharedMedia:
                return 14
            case .stats:
                return 15
            case .report:
                return 16
            case .leave:
                return 17
            case .deleteChannel:
                return 18
        }
    }
    
    static func ==(lhs: ChannelInfoEntry, rhs: ChannelInfoEntry) -> Bool {
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
            case let .about(lhsTheme, lhsText, lhsValue):
                if case let .about(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }

            case let .addressName(lhsTheme, lhsText, lhsValue):
                if case let .addressName(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .channelPhotoSetup(lhsTheme, lhsText):
                if case let .channelPhotoSetup(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .channelTypeSetup(lhsTheme, lhsText, lhsValue):
                if case let .channelTypeSetup(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .discussionGroupSetup(lhsTheme, lhsText, lhsValue):
                if case let .discussionGroupSetup(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .discussionGroupSetupInfo(lhsTheme, lhsText):
                if case let .discussionGroupSetupInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .channelDescriptionSetup(lhsTheme, lhsPlaceholder, lhsValue):
                if case let .channelDescriptionSetup(rhsTheme, rhsPlaceholder, rhsValue) = rhs, lhsTheme === rhsTheme, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .admins(lhsTheme, lhsText, lhsValue):
                if case let .admins(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .members(lhsTheme, lhsText, lhsValue):
                if case let .members(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .banned(lhsTheme, lhsText, lhsValue):
                if case let .banned(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .signMessages(lhsTheme, lhsText, lhsValue):
                if case let .signMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .signInfo(lhsTheme, lhsText):
                if case let .signInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .stats(lhsTheme, lhsText):
                if case let .stats(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .report(lhsTheme, lhsText):
                if case let .report(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .deleteChannel(lhsTheme, lhsText):
                if case let .deleteChannel(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .notifications(lhsTheme, lhsText, lhsValue):
                if case let .notifications(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelInfoEntry, rhs: ChannelInfoEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelInfoControllerArguments
        switch self {
            case let .info(_, _, dateTimeFormat, peer, cachedData, state, updatingAvatar):
                return ItemListAvatarAndNameInfoItem(accountContext: arguments.context, presentationData: presentationData, dateTimeFormat: dateTimeFormat, mode: .generic, peer: peer.flatMap(EnginePeer.init), presence: nil, memberCount: (cachedData as? CachedChannelData)?.participantsSummary.memberCount.flatMap(Int.init), state: state, sectionId: self.section, style: .plain, editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                    arguments.tapAvatarAction()
                }, context: arguments.avatarAndNameInfoContext, updatingImage: updatingAvatar)
            case let .about(_, text, value):
                return ItemListTextWithLabelItem(presentationData: presentationData, label: text, text: foldMultipleLineBreaks(value), enabledEntityTypes: [.allUrl, .mention, .hashtag], multiline: true, sectionId: self.section, action: nil, longTapAction: {
                    arguments.displayContextMenu(ChannelInfoEntryTag.about, value)
                }, linkItemAction: { action, itemLink in
                    arguments.aboutLinkAction(action, itemLink)
                }, tag: ChannelInfoEntryTag.about)
            case let .addressName(_, text, value):
                return ItemListTextWithLabelItem(presentationData: presentationData, label: text, text: "https://t.me/\(value)", textColor: .accent, enabledEntityTypes: [], multiline: false, sectionId: self.section, action: {
                    arguments.displayAddressNameContextMenu("https://t.me/\(value)")
                }, longTapAction: {
                    arguments.displayContextMenu(ChannelInfoEntryTag.link, "https://t.me/\(value)")
                }, tag: ChannelInfoEntryTag.link)
            case let .channelPhotoSetup(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.changeProfilePhoto()
                })
            case let .channelTypeSetup(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .plain, action: {
                    arguments.openChannelTypeSetup()
                })
            case let .discussionGroupSetup(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .plain, action: {
                    arguments.openDiscussionGroupSetup()
                })
            case let .discussionGroupSetupInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .channelDescriptionSetup(_, placeholder, value):
                return ItemListMultilineInputItem(presentationData: presentationData, text: value, placeholder: placeholder, maxLength: ItemListMultilineInputItemTextLimit(value: 255, display: true), sectionId: self.section, style: .plain, textUpdated: { updatedText in
                    arguments.updateEditingDescriptionText(updatedText)
                })
            case let .admins(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .plain, action: {
                    arguments.openAdmins()
                })
            case let .members(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .plain, action: {
                    arguments.openMembers()
                })
            case let .banned(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .plain, action: {
                    arguments.openBanned()
                })
            case let .signMessages(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .plain, updated: { updated in
                    arguments.toggleSignatures(updated)
                })
            case let .signInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section, style: .plain)
            case let .sharedMedia(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .plain, action: {
                    arguments.openSharedMedia()
                })
            case let .stats(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .plain, action: {
                    arguments.openStats()
                })
            case let .notifications(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .plain, action: {
                    arguments.changeNotificationMuteSettings()
                })
            case let .report(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.reportChannel()
                })
            case let .leave(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.leaveChannel()
                })
            case let .deleteChannel(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.deleteChannel()
                })
        }
    }
}

private struct ChannelInfoState: Equatable {
    let updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    let editingState: ChannelInfoEditingState?
    let savingData: Bool
    
    init(updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?, editingState: ChannelInfoEditingState?, savingData: Bool) {
        self.updatingAvatar = updatingAvatar
        self.editingState = editingState
        self.savingData = savingData
    }
    
    init() {
        self.updatingAvatar = nil
        self.editingState = nil
        self.savingData = false
    }
    
    static func ==(lhs: ChannelInfoState, rhs: ChannelInfoState) -> Bool {
        if lhs.updatingAvatar != rhs.updatingAvatar {
            return false
        }
        if lhs.editingState != rhs.editingState {
            return false
        }
        if lhs.savingData != rhs.savingData {
            return false
        }
        return true
    }
    
    func withUpdatedUpdatingAvatar(_ updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?) -> ChannelInfoState {
        return ChannelInfoState(updatingAvatar: updatingAvatar, editingState: self.editingState, savingData: self.savingData)
    }
    
    func withUpdatedEditingState(_ editingState: ChannelInfoEditingState?) -> ChannelInfoState {
        return ChannelInfoState(updatingAvatar: self.updatingAvatar, editingState: editingState, savingData: self.savingData)
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> ChannelInfoState {
        return ChannelInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, savingData: savingData)
    }
}

private struct ChannelInfoEditingState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName?
    let editingDescriptionText: String
    
    func withUpdatedEditingDescriptionText(_ editingDescriptionText: String) -> ChannelInfoEditingState {
        return ChannelInfoEditingState(editingName: self.editingName, editingDescriptionText: editingDescriptionText)
    }
    
    static func ==(lhs: ChannelInfoEditingState, rhs: ChannelInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.editingDescriptionText != rhs.editingDescriptionText {
            return false
        }
        return true
    }
}

private func channelInfoEntries(account: Account, presentationData: PresentationData, view: PeerView, globalNotificationSettings: GlobalNotificationSettings, state: ChannelInfoState) -> [ChannelInfoEntry] {
    var entries: [ChannelInfoEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        let canEditChannel = peer.hasPermission(.changeInfo)
        let canEditMembers = peer.hasPermission(.banMembers)
        
        let infoState = ItemListAvatarAndNameInfoItemState(editingName: canEditChannel ? state.editingState?.editingName : nil, updatingName: nil)
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer: peer, cachedData: view.cachedData, state: infoState, updatingAvatar: state.updatingAvatar))
        
        if let editingState = state.editingState, canEditChannel {
            entries.append(.channelPhotoSetup(theme: presentationData.theme, text: presentationData.strings.Channel_UpdatePhotoItem))
            entries.append(.channelDescriptionSetup(theme: presentationData.theme, placeholder: presentationData.strings.Channel_About_Placeholder, value: editingState.editingDescriptionText))
        }
        
        if let _ = state.editingState, peer.flags.contains(.isCreator) {
            let linkText: String
            if let username = peer.username {
                linkText = "@\(username)"
            } else {
                linkText = presentationData.strings.Channel_Setup_TypePrivate
            }
            entries.append(.channelTypeSetup(theme: presentationData.theme, text: presentationData.strings.Channel_TypeSetup_Title, value: linkText))
            
            let discussionGroupTitle: String
            if let cachedData = view.cachedData as? CachedChannelData {
                if case let .known(maybeLinkedDiscussionPeerId) = cachedData.linkedDiscussionPeerId, let linkedDiscussionPeerId = maybeLinkedDiscussionPeerId, let peer = view.peers[linkedDiscussionPeerId] {
                    if let addressName = peer.addressName, !addressName.isEmpty {
                        discussionGroupTitle = "@\(addressName)"
                    } else {
                        discussionGroupTitle = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                    }
                } else {
                    discussionGroupTitle = presentationData.strings.Channel_DiscussionGroupAdd
                }
            } else {
                discussionGroupTitle = "..."
            }
            entries.append(.discussionGroupSetup(theme: presentationData.theme, text: presentationData.strings.Channel_DiscussionGroup, value: discussionGroupTitle))
            entries.append(.discussionGroupSetupInfo(theme: presentationData.theme, text: presentationData.strings.Channel_DiscussionGroupInfo))
            
            let messagesShouldHaveSignatures:Bool
            switch peer.info {
                case let .broadcast(info):
                    messagesShouldHaveSignatures = info.flags.contains(.messagesShouldHaveSignatures)
                default:
                    messagesShouldHaveSignatures = false
            }
            
            entries.append(.signMessages(theme: presentationData.theme, text: presentationData.strings.Channel_SignMessages, value: messagesShouldHaveSignatures))
            entries.append(.signInfo(theme: presentationData.theme, text: presentationData.strings.Channel_SignMessages_Help))
        } else {
            if state.editingState == nil || !peer.flags.contains(.isCreator) {
                if let username = peer.username, !username.isEmpty, state.editingState == nil {
                    entries.append(.addressName(theme: presentationData.theme, text: presentationData.strings.Channel_LinkItem, value: username))
                }
            }
            
            if let _ = state.editingState, let _ = peer.adminRights {
                let discussionGroupTitle: String?
                if let cachedData = view.cachedData as? CachedChannelData {
                    if case let .known(maybeLinkedDiscussionPeerId) = cachedData.linkedDiscussionPeerId, let linkedDiscussionPeerId = maybeLinkedDiscussionPeerId, let peer = view.peers[linkedDiscussionPeerId] {
                        if let addressName = peer.addressName, !addressName.isEmpty {
                            discussionGroupTitle = "@\(addressName)"
                        } else {
                            discussionGroupTitle = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        }
                    } else if canEditChannel {
                        discussionGroupTitle = presentationData.strings.Channel_DiscussionGroupAdd
                    } else {
                        discussionGroupTitle = nil
                    }
                } else if canEditChannel {
                    discussionGroupTitle = "..."
                } else {
                    discussionGroupTitle = nil
                }
                
                if let discussionGroupTitle = discussionGroupTitle {
                    entries.append(.discussionGroupSetup(theme: presentationData.theme, text: presentationData.strings.Channel_DiscussionGroup, value: discussionGroupTitle))
                    if canEditChannel {
                        entries.append(.discussionGroupSetupInfo(theme: presentationData.theme, text: presentationData.strings.Channel_DiscussionGroupInfo))
                    }
                }
            }
        }
        
        if let _ = state.editingState {
        } else {
            if peer.isScam {
                entries.append(.about(theme: presentationData.theme, text: presentationData.strings.Channel_AboutItem, value: presentationData.strings.ChannelInfo_ScamChannelWarning))
            } else if let cachedChannelData = view.cachedData as? CachedChannelData, let about = cachedChannelData.about, !about.isEmpty {
                entries.append(.about(theme: presentationData.theme, text: presentationData.strings.Channel_AboutItem, value: about))
            }
        }
        
        if let cachedChannelData = view.cachedData as? CachedChannelData {
            if canEditMembers {
                if peer.adminRights != nil || peer.flags.contains(.isCreator) {
                    let adminCount = cachedChannelData.participantsSummary.adminCount ?? 0
                    entries.append(.admins(theme: presentationData.theme, text: presentationData.strings.GroupInfo_Administrators, value: "\(adminCount == 0 ? "" : "\(presentationStringsFormattedNumber(adminCount, presentationData.dateTimeFormat.groupingSeparator))")"))
                    
                    let memberCount = cachedChannelData.participantsSummary.memberCount ?? 0
                    entries.append(.members(theme: presentationData.theme, text: presentationData.strings.Channel_Info_Subscribers, value: "\(memberCount == 0 ? "" : "\(presentationStringsFormattedNumber(memberCount, presentationData.dateTimeFormat.groupingSeparator))")"))
                    
                    let bannedCount = cachedChannelData.participantsSummary.kickedCount ?? 0
                    entries.append(.banned(theme: presentationData.theme, text: presentationData.strings.GroupRemoved_Title, value: "\(bannedCount == 0 ? "" : "\(presentationStringsFormattedNumber(bannedCount, presentationData.dateTimeFormat.groupingSeparator))")"))
                }
            }
        }
        
        if state.editingState == nil, let notificationSettings = view.notificationSettings as? TelegramPeerNotificationSettings {
            let notificationsText: String
            if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                if until < Int32.max - 1 {
                    notificationsText = stringForRemainingMuteInterval(strings: presentationData.strings, muteInterval: until)
                } else {
                    notificationsText = presentationData.strings.UserInfo_NotificationsDisabled
                }
            } else if case .default = notificationSettings.messageSound {
                notificationsText = presentationData.strings.UserInfo_NotificationsEnabled
            } else {
                notificationsText = localizedPeerNotificationSoundString(strings: presentationData.strings, sound: notificationSettings.messageSound, default: globalNotificationSettings.effective.channels.sound)
            }
            entries.append(ChannelInfoEntry.notifications(theme: presentationData.theme, text: presentationData.strings.GroupInfo_Notifications, value: notificationsText))
        }
        if state.editingState == nil {
            entries.append(ChannelInfoEntry.sharedMedia(theme: presentationData.theme, text: presentationData.strings.GroupInfo_SharedMedia))
            if let cachedChannelData = view.cachedData as? CachedChannelData, cachedChannelData.flags.contains(.canViewStats) {
                entries.append(ChannelInfoEntry.stats(theme: presentationData.theme, text: presentationData.strings.ChannelInfo_Stats))
            }
        }
        
        if peer.flags.contains(.isCreator) {
            //if state.editingState != nil {
            entries.append(ChannelInfoEntry.deleteChannel(theme: presentationData.theme, text: presentationData.strings.ChannelInfo_DeleteChannel))
            //}
        } else if state.editingState == nil {
            entries.append(ChannelInfoEntry.report(theme: presentationData.theme, text: presentationData.strings.ReportPeer_Report))
            if peer.participationStatus == .member {
                entries.append(ChannelInfoEntry.leave(theme: presentationData.theme, text: presentationData.strings.Channel_LeaveChannel))
            }
        }
    }
    
    return entries
}

private func valuesRequiringUpdate(state: ChannelInfoState, view: PeerView) -> (title: String?, description: String?) {
    if let peer = view.peers[view.peerId] as? TelegramChannel {
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

public func channelInfoController(context: AccountContext, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelInfoState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelInfoState())
    let updateState: ((ChannelInfoState) -> ChannelInfoState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var removePeerChatImpl: ((Peer, Bool) -> Void)?
    var endEditingImpl: (() -> Void)?
    var errorImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updatePeerNameDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerNameDisposable)
    
    let updatePeerDescriptionDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerDescriptionDisposable)
    
    let changeMuteSettingsDisposable = MetaDisposable()
    actionsDisposable.add(changeMuteSettingsDisposable)
    
    let hiddenAvatarRepresentationDisposable = MetaDisposable()
    actionsDisposable.add(hiddenAvatarRepresentationDisposable)
    
    let updateAvatarDisposable = MetaDisposable()
    actionsDisposable.add(updateAvatarDisposable)
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    let navigateDisposable = MetaDisposable()
    actionsDisposable.add(navigateDisposable)
    
    let statsUrlDisposable = MetaDisposable()
    actionsDisposable.add(statsUrlDisposable)
    
    var avatarGalleryTransitionArguments: ((AvatarGalleryEntry) -> GalleryTransitionArguments?)?
    let avatarAndNameInfoContext = ItemListAvatarAndNameInfoItemContext()
    var updateHiddenAvatarImpl: (() -> Void)?
    
    var displayContextMenuImpl: ((ChannelInfoEntryTag, String) -> Void)?
    var aboutLinkActionImpl: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    
    let arguments = ChannelInfoControllerArguments(context: context, avatarAndNameInfoContext: avatarAndNameInfoContext, tapAvatarAction: {
        let _ = (context.account.postbox.loadedPeerWithId(peerId) |> take(1) |> deliverOnMainQueue).start(next: { peer in
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
        
        let _ = (context.account.postbox.transaction { transaction -> (Peer?, SearchBotsConfiguration) in
            return (transaction.getPeer(peerId), currentSearchBotsConfiguration(transaction: transaction))
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
                        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                        context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)
                        updateState {
                            $0.withUpdatedUpdatingAvatar(.image(representation, true))
                        }
                        updateAvatarDisposable.set((context.engine.peers.updatePeerPhoto(peerId: peerId, photo: context.engine.peers.uploadedPeerPhoto(resource: resource), mapResourceToAvatarSizes: { resource, representations in
                            return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                        })
                        |> deliverOnMainQueue).start(next: { result in
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
                                
                let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: hasPhotos, hasViewButton: false, personalPhoto: false, isVideo: false, saveEditedPhotos: false, saveCapturedMedia: false, signup: true)!
                let _ = currentAvatarMixin.swap(mixin)
                mixin.requestSearchController = { assetsController in
                    let controller = WebSearchController(context: context, peer: peer.flatMap(EnginePeer.init), chatLocation: nil, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: peer.flatMap(EnginePeer.init)?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), completion: { result in
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
                            return $0.withUpdatedUpdatingAvatar(ItemListAvatarAndNameInfoItemUpdatingAvatar.none)
                        }
                    }
                    updateAvatarDisposable.set((context.engine.peers.updatePeerPhoto(peerId: peerId, photo: nil, mapResourceToAvatarSizes: { resource, representations in
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
    }, updateEditingName: { editingName in
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(ChannelInfoEditingState(editingName: editingName, editingDescriptionText: editingState.editingDescriptionText))
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
    }, openChannelTypeSetup: {
        presentControllerImpl?(channelVisibilityController(context: context, peerId: peerId, mode: .generic, upgradedToSupergroup: { _, f in f() }), ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
    }, openDiscussionGroupSetup: {
        pushControllerImpl?(channelDiscussionGroupSetupController(context: context, peerId: peerId))
    }, changeNotificationMuteSettings: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = (context.account.postbox.transaction { transaction -> (TelegramPeerNotificationSettings, GlobalNotificationSettings) in
            let peerSettings: TelegramPeerNotificationSettings = (transaction.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings) ?? TelegramPeerNotificationSettings.defaultSettings
            let globalSettings: GlobalNotificationSettings = transaction.getPreferencesEntry(key: PreferencesKeys.globalNotifications)?.get(GlobalNotificationSettings.self) ?? GlobalNotificationSettings.defaultSettings
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
                    let _ = context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, sound: sound).start()
                })
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }, updateSettings: { value in
                changeMuteSettingsDisposable.set(context.engine.peers.updatePeerMuteSetting(peerId: peerId, muteInterval: value).start())
            })
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, openSharedMedia: {
        if let controller = context.sharedContext.makePeerSharedMediaController(context: context, peerId: peerId) {
            pushControllerImpl?(controller)
        }
    }, openStats: {
    }, openAdmins: {
        pushControllerImpl?(channelAdminsController(context: context, peerId: peerId))
    }, openMembers: {
        pushControllerImpl?(channelMembersController(context: context, peerId: peerId))
    }, openBanned: {
        pushControllerImpl?(channelBlacklistController(context: context, peerId: peerId))
    }, reportChannel: {
        presentControllerImpl?(peerReportOptionsController(context: context, subject: .peer(peerId), passthrough: false, present: { c, a in
            presentControllerImpl?(c, a)
        }, push: { c in
            pushControllerImpl?(c)
        }, completion: { _, _ in }), nil)
    }, leaveChannel: {
        let _ = (context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        }
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = ActionSheetController(presentationData: presentationData)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Channel_LeaveChannel, color: .destructive, action: {
                        dismissAction()
                        removePeerChatImpl?(peer, false)
                    }),
                ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, deleteChannel: {
        let _ = (context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        }
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = ActionSheetController(presentationData: presentationData)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: presentationData.strings.ChannelInfo_DeleteChannelConfirmation),
                    ActionSheetButtonItem(title: presentationData.strings.ChannelInfo_DeleteChannel, color: .destructive, action: {
                        dismissAction()
                        removePeerChatImpl?(peer, true)
                    }),
                ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, displayAddressNameContextMenu: { text in
        let shareController = ShareController(context: context, subject: .url(text))
        presentControllerImpl?(shareController, nil)
    }, displayContextMenu: { tag, text in
        displayContextMenuImpl?(tag, text)
    }, aboutLinkAction: { action, itemLink in
        aboutLinkActionImpl?(action, itemLink)
    }, toggleSignatures: { enabled in
        actionsDisposable.add(context.engine.peers.toggleShouldChannelMessagesSignatures(peerId: peerId, enabled: enabled).start())
    })

    var wasEditing: Bool?
    
    let globalNotificationsKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([PreferencesKeys.globalNotifications]))
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get(), context.account.viewTracker.peerView(peerId, updateData: true), context.account.postbox.combinedView(keys: [globalNotificationsKey]))
        |> map { presentationData, state, view, combinedView -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let peer = peerViewMainPeer(view)
            
            var globalNotificationSettings: GlobalNotificationSettings = GlobalNotificationSettings.defaultSettings
            if let preferencesView = combinedView.views[globalNotificationsKey] as? PreferencesView {
                if let settings = preferencesView.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
                    globalNotificationSettings = settings
                }
            }
                        
            var canEditChannel = false
            var hasSomethingToEdit = false
            if let peer = view.peers[view.peerId] as? TelegramChannel {
                canEditChannel = peer.hasPermission(.changeInfo)
                if canEditChannel {
                    hasSomethingToEdit = true
                } else if let _ = peer.adminRights {
                    if let cachedData = view.cachedData as? CachedChannelData, case let .known(maybeLinkedDiscussionPeerId) = cachedData.linkedDiscussionPeerId, let _ = maybeLinkedDiscussionPeerId {
                        hasSomethingToEdit = true
                    }
                }
            }
            
            var leftNavigationButton: ItemListNavigationButton?
            var rightNavigationButton: ItemListNavigationButton?
            if let editingState = state.editingState {
                leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                    updateState {
                        $0.withUpdatedEditingState(nil)
                    }
                })
            
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
                            updateTitle = context.engine.peers.updatePeerTitle(peerId: peerId, title: titleValue)
                                |> mapError { _ in return Void() }
                        } else {
                            updateTitle = .complete()
                        }
                        
                        let updateDescription: Signal<Void, Void>
                        if let descriptionValue = updateValues.description {
                            updateDescription = context.engine.peers.updatePeerDescription(peerId: peerId, description: descriptionValue.isEmpty ? nil : descriptionValue)
                                |> mapError { _ in return Void() }
                        } else {
                            updateDescription = .complete()
                        }
                        
                        let signal = combineLatest(updateTitle, updateDescription)
                        
                        updatePeerNameDisposable.set((signal |> deliverOnMainQueue).start(error: { _ in
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
            } else if hasSomethingToEdit {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                        var text = ""
                        if let cachedData = view.cachedData as? CachedChannelData, let about = cachedData.about {
                            text = about
                        }
                        updateState { state in
                            return state.withUpdatedEditingState(ChannelInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(EnginePeer(channel)), editingDescriptionText: text))
                        }
                    }
                })
            }
            
            let wasEditingValue = wasEditing
            wasEditing = state.editingState != nil
            
            var crossfadeState = false
            if let wasEditingValue = wasEditingValue, wasEditingValue != (state.editingState != nil) {
                crossfadeState = true
            }
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.UserInfo_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelInfoEntries(account: context.account, presentationData: presentationData, view: view, globalNotificationSettings: globalNotificationSettings, state: state), style: .plain, crossfadeState: crossfadeState, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window(.root), with: presentationArguments, blockInteraction: true)
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
                chatListController.maybeAskForPeerChatRemoval(peer: RenderedPeer(peer: peer), joined: false, deleteGloballyIfPossible: deleteGloballyIfPossible, completion: { [weak navigationController] removed in
                    if removed {
                        navigationController?.popToRoot(animated: true)
                    }
                }, removed: {
                })
                break
            }
        }
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
    displayContextMenuImpl = { [weak controller] tag, text in
        if let strongController = controller {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListTextWithLabelItemNode {
                    if let itemTag = itemNode.tag as? ChannelInfoEntryTag {
                        if itemTag == tag {
                            resultItemNode = itemNode
                            return true
                        }
                    }
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
        if let controller = controller, let context = context {
            context.sharedContext.handleTextLinkAction(context: context, peerId: peerId, navigateDisposable: navigateDisposable, controller: controller, action: action, itemLink: itemLink)
        }
    }
    endEditingImpl = {
        [weak controller] in
        controller?.view.endEditing(true)
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
    return controller
}
