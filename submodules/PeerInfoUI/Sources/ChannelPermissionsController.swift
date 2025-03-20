import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import TemporaryCachedPeerDataManager
import AlertUI
import PresentationDataUtils
import ItemListPeerItem
import TelegramPermissionsUI
import ItemListPeerActionItem
import Markdown
import UndoUI
import Postbox
import OldChannelsController
import MessagePriceItem

private final class ChannelPermissionsControllerArguments {
    let context: AccountContext
    
    let updatePermission: (TelegramChatBannedRightsFlags, Bool) -> Void
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let addPeer: () -> Void
    let removePeer: (EnginePeer.Id) -> Void
    let openPeer: (ChannelParticipant) -> Void
    let openPeerInfo: (EnginePeer) -> Void
    let openKicked: () -> Void
    let presentRestrictedPermissionAlert: (TelegramChatBannedRightsFlags) -> Void
    let presentConversionToBroadcastGroup: () -> Void
    let openChannelExample: () -> Void
    let updateSlowmode: (Int32) -> Void
    let updateUnrestrictBoosters: (Int32) -> Void
    let updateStarsAmount: (StarsAmount?, Bool) -> Void
    let toggleIsOptionExpanded: (TelegramChatBannedRightsFlags) -> Void
    
    init(context: AccountContext, updatePermission: @escaping (TelegramChatBannedRightsFlags, Bool) -> Void, setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void, addPeer: @escaping  () -> Void, removePeer: @escaping (EnginePeer.Id) -> Void, openPeer: @escaping (ChannelParticipant) -> Void, openPeerInfo: @escaping (EnginePeer) -> Void, openKicked: @escaping () -> Void, presentRestrictedPermissionAlert: @escaping (TelegramChatBannedRightsFlags) -> Void, presentConversionToBroadcastGroup: @escaping () -> Void, openChannelExample: @escaping () -> Void, updateSlowmode: @escaping (Int32) -> Void, updateUnrestrictBoosters: @escaping (Int32) -> Void, updateStarsAmount: @escaping (StarsAmount?, Bool) -> Void, toggleIsOptionExpanded: @escaping (TelegramChatBannedRightsFlags) -> Void) {
        self.context = context
        self.updatePermission = updatePermission
        self.addPeer = addPeer
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.openPeer = openPeer
        self.openPeerInfo = openPeerInfo
        self.openKicked = openKicked
        self.presentRestrictedPermissionAlert = presentRestrictedPermissionAlert
        self.presentConversionToBroadcastGroup = presentConversionToBroadcastGroup
        self.openChannelExample = openChannelExample
        self.updateSlowmode = updateSlowmode
        self.updateUnrestrictBoosters = updateUnrestrictBoosters
        self.updateStarsAmount = updateStarsAmount
        self.toggleIsOptionExpanded = toggleIsOptionExpanded
    }
}

private enum ChannelPermissionsSection: Int32 {
    case permissions
    case slowmode
    case conversion
    case chargeForMessages
    case messagePrice
    case unrestrictBoosters
    case kicked
    case exceptions
}

private enum ChannelPermissionsEntryStableId: Hashable {
    case index(Int)
    case peer(EnginePeer.Id)
}

struct SubPermission: Equatable {
    var title: String
    var flags: TelegramChatBannedRightsFlags
    var isSelected: Bool
    var isEnabled: Bool
}

private enum ChannelPermissionsEntry: ItemListNodeEntry {
    case permissionsHeader(PresentationTheme, String)
    case permission(PresentationTheme, Int, String, Bool, TelegramChatBannedRightsFlags, Bool?, [SubPermission], Bool)
    case slowmodeHeader(PresentationTheme, String)
    case slowmode(PresentationTheme, PresentationStrings, Int32)
    case slowmodeInfo(PresentationTheme, String)
    
    case chargeForMessages(PresentationTheme, String, Bool)
    case chargeForMessagesInfo(PresentationTheme, String)
    
    case messagePriceHeader(PresentationTheme, String)
    case messagePrice(PresentationTheme, Int64, Int64, String)
    case messagePriceInfo(PresentationTheme, String)
    
    case unrestrictBoostersSwitch(PresentationTheme, String, Bool)
    case unrestrictBoosters(PresentationTheme, PresentationStrings, Int32)
    case unrestrictBoostersInfo(PresentationTheme, String)
    case conversionHeader(PresentationTheme, String)
    case conversion(PresentationTheme, String)
    case conversionInfo(PresentationTheme, String)
    case kicked(PresentationTheme, String, String)
    case exceptionsHeader(PresentationTheme, String)
    case add(PresentationTheme, String)
    case peerItem(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool, Bool, TelegramChatBannedRightsFlags)
    
    var section: ItemListSectionId {
        switch self {
            case .permissionsHeader, .permission:
                return ChannelPermissionsSection.permissions.rawValue
            case .slowmodeHeader, .slowmode, .slowmodeInfo:
                return ChannelPermissionsSection.slowmode.rawValue
            case .conversionHeader, .conversion, .conversionInfo:
                return ChannelPermissionsSection.conversion.rawValue
            case .chargeForMessages, .chargeForMessagesInfo:
                return ChannelPermissionsSection.chargeForMessages.rawValue
            case .messagePriceHeader, .messagePrice, .messagePriceInfo:
                return ChannelPermissionsSection.messagePrice.rawValue
            case .unrestrictBoostersSwitch, .unrestrictBoosters, .unrestrictBoostersInfo:
                return ChannelPermissionsSection.unrestrictBoosters.rawValue
            case .kicked:
                return ChannelPermissionsSection.kicked.rawValue
            case .exceptionsHeader, .add, .peerItem:
                return ChannelPermissionsSection.exceptions.rawValue
        }
    }
    
    var stableId: ChannelPermissionsEntryStableId {
        switch self {
            case .permissionsHeader:
                return .index(0)
            case let .permission(_, index, _, _, _, _, _, _):
                return .index(1 + index)
            case .conversionHeader:
                return .index(998)
            case .conversion:
                return .index(999)
            case .conversionInfo:
                return .index(1000)
            case .chargeForMessages:
                return .index(1001)
            case .chargeForMessagesInfo:
                return .index(1002)
            case .messagePriceHeader:
                return .index(1003)
            case .messagePrice:
                return .index(1004)
            case .messagePriceInfo:
                return .index(1005)
            case .unrestrictBoostersSwitch:
                return .index(1006)
            case .unrestrictBoosters:
                return .index(1007)
            case .unrestrictBoostersInfo:
                return .index(1008)
            case .slowmodeHeader:
                return .index(1009)
            case .slowmode:
                return .index(1010)
            case .slowmodeInfo:
                return .index(1011)
            case .kicked:
                return .index(1012)
            case .exceptionsHeader:
                return .index(1013)
            case .add:
                return .index(1014)
            case let .peerItem(_, _, _, _, _, participant, _, _, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelPermissionsEntry, rhs: ChannelPermissionsEntry) -> Bool {
        switch lhs {
            case let .permissionsHeader(lhsTheme, lhsText):
                if case let .permissionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .permission(theme, index, title, value, rights, enabled, subPermissions, isExpanded):
                if case .permission(theme, index, title, value, rights, enabled, subPermissions, isExpanded) = rhs {
                    return true
                } else {
                    return false
                }
            case let .slowmodeHeader(lhsTheme, lhsValue):
                if case let .slowmodeHeader(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .slowmode(lhsTheme, lhsStrings, lhsValue):
                if case let .slowmode(rhsTheme, rhsStrings, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .slowmodeInfo(lhsTheme, lhsValue):
                if case let .slowmodeInfo(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .conversionHeader(lhsTheme, lhsValue):
                if case let .conversionHeader(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .conversion(lhsTheme, lhsText):
                if case let .conversion(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .conversionInfo(lhsTheme, lhsValue):
                if case let .conversionInfo(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .chargeForMessages(lhsTheme, lhsTitle, lhsValue):
                if case let .chargeForMessages(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .chargeForMessagesInfo(lhsTheme, lhsText):
                if case let .chargeForMessagesInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .messagePriceHeader(lhsTheme, lhsText):
                if case let .messagePriceHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .messagePrice(lhsTheme, lhsValue, lhsMaxValue, lhsPrice):
                if case let .messagePrice(rhsTheme, rhsValue, rhsMaxValue, rhsPrice) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue, lhsMaxValue == rhsMaxValue, lhsPrice == rhsPrice {
                    return true
                } else {
                    return false
                }
            case let .messagePriceInfo(lhsTheme, lhsText):
                if case let .messagePriceInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .unrestrictBoostersSwitch(lhsTheme, lhsTitle, lhsValue):
                if case let .unrestrictBoostersSwitch(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .unrestrictBoosters(lhsTheme, lhsStrings, lhsValue):
                if case let .unrestrictBoosters(rhsTheme, rhsStrings, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .unrestrictBoostersInfo(lhsTheme, lhsValue):
                if case let .unrestrictBoostersInfo(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
                case let .kicked(lhsTheme, lhsText, lhsValue):
                if case let .kicked(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .exceptionsHeader(lhsTheme, lhsText):
                if case let .exceptionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .add(lhsTheme, lhsText):
                if case let .add(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .peerItem(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsIndex, lhsParticipant, lhsEditing, lhsEnabled, lhsCanOpen, lhsDefaultBannedRights):
                if case let .peerItem(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsIndex, rhsParticipant, rhsEditing, rhsEnabled, rhsCanOpen, rhsDefaultBannedRights) = rhs {
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
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsParticipant != rhsParticipant {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    if lhsCanOpen != rhsCanOpen {
                        return false
                    }
                    if lhsDefaultBannedRights != rhsDefaultBannedRights {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelPermissionsEntry, rhs: ChannelPermissionsEntry) -> Bool {
        switch lhs {
            case let .peerItem(_, _, _, _, index, _, _, _, _, _):
                switch rhs {
                    case let .peerItem(_, _, _, _, rhsIndex, _, _, _, _, _):
                        return index < rhsIndex
                    default:
                        return false
                }
            default:
                if case let .index(lhsIndex) = lhs.stableId {
                    if case let .index(rhsIndex) = rhs.stableId {
                        return lhsIndex < rhsIndex
                    } else {
                        return true
                    }
                } else {
                    assertionFailure()
                    return false
                }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelPermissionsControllerArguments
        switch self {
            case let .permissionsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .permission(_, _, title, value, rights, enabled, subPermissions, isExpanded):
                if !subPermissions.isEmpty {
                    return ItemListExpandableSwitchItem(presentationData: presentationData, title: title, value: value, isExpanded: isExpanded, subItems: subPermissions.map { item in
                        return ItemListExpandableSwitchItem.SubItem(
                            id: AnyHashable(item.flags.rawValue),
                            title: item.title,
                            isSelected: item.isSelected,
                            isEnabled: item.isEnabled
                        )
                    }, type: .icon, enableInteractiveChanges: enabled != nil, enabled: enabled ?? true, sectionId: self.section, style: .blocks, updated: { value in
                        if let _ = enabled {
                            arguments.updatePermission(rights, value)
                        } else {
                            arguments.presentRestrictedPermissionAlert(rights)
                        }
                    }, activatedWhileDisabled: {
                        arguments.presentRestrictedPermissionAlert(rights)
                    }, selectAction: {
                        arguments.toggleIsOptionExpanded(rights)
                    }, subAction: { item in
                        guard let value = item.id.base as? Int32 else {
                            return
                        }
                        let subRights = TelegramChatBannedRightsFlags(rawValue: value)
                        
                        if let _ = enabled {
                            arguments.updatePermission(subRights, !item.isSelected)
                        } else {
                            arguments.presentRestrictedPermissionAlert(subRights)
                        }
                    })
                } else {
                    return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, type: .icon, enableInteractiveChanges: enabled != nil, enabled: enabled ?? true, sectionId: self.section, style: .blocks, updated: { value in
                        if let _ = enabled {
                            arguments.updatePermission(rights, value)
                        } else {
                            arguments.presentRestrictedPermissionAlert(rights)
                        }
                    }, activatedWhileDisabled: {
                        arguments.presentRestrictedPermissionAlert(rights)
                    })
                }
            case let .slowmodeHeader(_, value):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: value, sectionId: self.section)
            case let .slowmode(theme, strings, value):
                return ChatSlowmodeItem(theme: theme, strings: strings, value: value, enabled: true, sectionId: self.section, updated: { value in
                    arguments.updateSlowmode(value)
                })
            case let .slowmodeInfo(_, value):
                return ItemListTextItem(presentationData: presentationData, text: .plain(value), sectionId: self.section)
            case let .conversionHeader(_, value):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: value, sectionId: self.section)
            case let .conversion(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks) {
                    arguments.presentConversionToBroadcastGroup()
                }
            case let .conversionInfo(_, value):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(value), sectionId: self.section) { _ in
                    arguments.openChannelExample()
                }
            case let .chargeForMessages(_, title, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateStarsAmount(value ? StarsAmount(value: 400, nanos: 0) : nil, true)
                })
            case let .chargeForMessagesInfo(_, value):
                return ItemListTextItem(presentationData: presentationData, text: .plain(value), sectionId: self.section)
            case let .messagePriceHeader(_, value):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: value, sectionId: self.section)
            case let .messagePrice(_, value, maxValue, price):
                return MessagePriceItem(theme: presentationData.theme, strings: presentationData.strings, isEnabled: true, minValue: 1, maxValue: maxValue, value: value, price: price, sectionId: self.section, updated: { value, apply in
                    arguments.updateStarsAmount(StarsAmount(value: value, nanos: 0), apply)
                })
            case let .messagePriceInfo(_, value):
                return ItemListTextItem(presentationData: presentationData, text: .plain(value), sectionId: self.section)
            case let .unrestrictBoostersSwitch(_, title, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateUnrestrictBoosters(value ? 1 : 0)
                })
            case let .unrestrictBoosters(theme, strings, value):
                return ChatUnrestrictBoostersItem(theme: theme, strings: strings, value: value, enabled: true, sectionId: self.section, updated: { value in
                    arguments.updateUnrestrictBoosters(value)
                })
            case let .unrestrictBoostersInfo(_, value):
                return ItemListTextItem(presentationData: presentationData, text: .plain(value), sectionId: self.section)
            case let .kicked(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openKicked()
                })
            case let .exceptionsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .add(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addPersonIcon(theme), title: text, sectionId: self.section, editing: false, action: {
                    arguments.addPeer()
                })
            case let .peerItem(_, strings, dateTimeFormat, nameDisplayOrder, _, participant, editing, enabled, canOpen, defaultBannedRights):
                var text: ItemListPeerItemText = .none
                switch participant.participant {
                    case let .member(_, _, _, banInfo, _, _):
                        var exceptionsString = ""
                        if let banInfo = banInfo {
                            let sendMediaRights = banSendMediaSubList().map { $0.0 }
                            for (rights, _) in internal_allPossibleGroupPermissionList {
                                if !defaultBannedRights.contains(rights) && banInfo.rights.flags.contains(rights) {
                                    if banInfo.rights.flags.contains(.banSendMedia) && sendMediaRights.contains(rights) {
                                        continue
                                    }
                                    if !exceptionsString.isEmpty {
                                        exceptionsString.append(", ")
                                    }
                                    exceptionsString.append(compactStringForGroupPermission(strings: strings, right: rights))
                                }
                            }
                            if !exceptionsString.isEmpty {
                                text = .text(exceptionsString, .secondary)
                            }
                        }
                    default:
                        break
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(participant.peer), presence: nil, text: text, label: .none, editing: editing, switchValue: nil, enabled: enabled, selectable: true, sectionId: self.section, action: canOpen ? {
                    arguments.openPeer(participant.participant)
                } : {
                    arguments.openPeerInfo(EnginePeer(participant.peer))
                }, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
        }
    }
}

private struct ChannelPermissionsControllerState: Equatable {
    var peerIdWithRevealedOptions: EnginePeer.Id?
    var removingPeerId: EnginePeer.Id?
    var searchingMembers: Bool = false
    var modifiedRightsFlags: TelegramChatBannedRightsFlags?
    var modifiedSlowmodeTimeout: Int32?
    var modifiedUnrestrictBoosters: Int32?
    var modifiedStarsAmount: StarsAmount?
    var expandedPermissions = Set<TelegramChatBannedRightsFlags>()
}

func stringForGroupPermission(strings: PresentationStrings, right: TelegramChatBannedRightsFlags, isForum: Bool) -> String {
    if right.contains(.banSendText) {
        return strings.Channel_BanUser_PermissionSendMessages
    } else if right.contains(.banSendMedia) {
        return strings.Channel_BanUser_PermissionSendMedia
    } else if right.contains(.banSendGifs) {
        return strings.Channel_BanUser_PermissionSendStickersAndGifs
    } else if right.contains(.banEmbedLinks) {
        return strings.Channel_BanUser_PermissionEmbedLinks
    } else if right.contains(.banSendPolls) {
        return strings.Channel_BanUser_PermissionSendPolls
    } else if right.contains(.banChangeInfo) {
        return strings.Channel_BanUser_PermissionChangeGroupInfo
    } else if right.contains(.banAddMembers) {
        return strings.Channel_BanUser_PermissionAddMembers
    } else if right.contains(.banPinMessages) {
        return strings.Channel_EditAdmin_PermissionPinMessages
    } else if right.contains(.banManageTopics) {
        return strings.Channel_EditAdmin_PermissionCreateTopics
    } else if right.contains(.banSendPhotos) {
        return strings.Channel_BanUser_PermissionSendPhoto
    } else if right.contains(.banSendVideos) {
        return strings.Channel_BanUser_PermissionSendVideo
    } else if right.contains(.banSendStickers) {
        return strings.Channel_BanUser_PermissionSendStickersAndGifs
    } else if right.contains(.banSendMusic) {
        return strings.Channel_BanUser_PermissionSendMusic
    } else if right.contains(.banSendFiles) {
        return strings.Channel_BanUser_PermissionSendFile
    } else if right.contains(.banSendVoice) {
        return strings.Channel_BanUser_PermissionSendVoiceMessage
    } else if right.contains(.banSendInstantVideos) {
        return strings.Channel_BanUser_PermissionSendVideoMessage
    } else {
        return ""
    }
}

func compactStringForGroupPermission(strings: PresentationStrings, right: TelegramChatBannedRightsFlags) -> String {
    if right.contains(.banSendText) {
        return strings.GroupPermission_NoSendMessages
    } else if right.contains(.banSendMedia) {
        return strings.GroupPermission_NoSendMedia
    } else if right.contains(.banSendPhotos) {
        return strings.GroupPermission_NoSendPhoto
    } else if right.contains(.banSendVideos) {
        return strings.GroupPermission_NoSendVideo
    } else if right.contains(.banSendMusic) {
        return strings.GroupPermission_NoSendMusic
    } else if right.contains(.banSendFiles) {
        return strings.GroupPermission_NoSendFile
    } else if right.contains(.banSendVoice) {
        return strings.GroupPermission_NoSendVoiceMessage
    } else if right.contains(.banSendInstantVideos) {
        return strings.GroupPermission_NoSendVideoMessage
    } else if right.contains(.banSendGifs) {
        return strings.GroupPermission_NoSendGifs
    } else if right.contains(.banEmbedLinks) {
        return strings.GroupPermission_NoSendLinks
    } else if right.contains(.banSendPolls) {
        return strings.GroupPermission_NoSendPolls
    } else if right.contains(.banChangeInfo) {
        return strings.GroupPermission_NoChangeInfo
    } else if right.contains(.banAddMembers) {
        return strings.GroupPermission_NoAddMembers
    } else if right.contains(.banPinMessages) {
        return strings.GroupPermission_NoPinMessages
    } else if right.contains(.banManageTopics) {
        return strings.GroupPermission_NoManageTopics
    } else {
        return ""
    }
}

private let internal_allPossibleGroupPermissionList: [(TelegramChatBannedRightsFlags, TelegramChannelPermission)] = [
    (.banSendText, .banMembers),
    (.banSendMedia, .banMembers),
    (.banSendPhotos, .banMembers),
    (.banSendVideos, .banMembers),
    (.banSendGifs, .banMembers),
    (.banSendMusic, .banMembers),
    (.banSendFiles, .banMembers),
    (.banSendVoice, .banMembers),
    (.banSendInstantVideos, .banMembers),
    (.banEmbedLinks, .banMembers),
    (.banSendPolls, .banMembers),
    (.banAddMembers, .banMembers),
    (.banPinMessages, .pinMessages),
    (.banManageTopics, .manageTopics),
    (.banChangeInfo, .changeInfo)
]

public func allGroupPermissionList(peer: EnginePeer, expandMedia: Bool) -> [(TelegramChatBannedRightsFlags, TelegramChannelPermission)] {
    var result: [(TelegramChatBannedRightsFlags, TelegramChannelPermission)]
    if case let .channel(channel) = peer, channel.flags.contains(.isForum) {
        result = [
            (.banSendText, .banMembers),
            (.banSendMedia, .banMembers),
            (.banAddMembers, .banMembers),
            (.banPinMessages, .pinMessages),
            (.banManageTopics, .manageTopics),
            (.banChangeInfo, .changeInfo)
        ]
    } else {
        result = [
            (.banSendText, .banMembers),
            (.banSendMedia, .banMembers),
            (.banAddMembers, .banMembers),
            (.banPinMessages, .pinMessages),
            (.banChangeInfo, .changeInfo)
        ]
    }
    
    if expandMedia, let index = result.firstIndex(where: { $0.0 == .banSendMedia }) {
        result.remove(at: index)
        
        for (subRight, permission) in banSendMediaSubList().reversed() {
            result.insert((subRight, permission), at: index)
        }
    }
    
    return result
}
    
public func banSendMediaSubList() -> [(TelegramChatBannedRightsFlags, TelegramChannelPermission)] {
    return [
        (.banSendPhotos, .banMembers),
        (.banSendVideos, .banMembers),
        (.banSendGifs, .banMembers),
        (.banSendMusic, .banMembers),
        (.banSendFiles, .banMembers),
        (.banSendVoice, .banMembers),
        (.banSendInstantVideos, .banMembers),
        (.banEmbedLinks, .banMembers),
        (.banSendPolls, .banMembers),
    ]
}

let publicGroupRestrictedPermissions: TelegramChatBannedRightsFlags = [
    .banPinMessages,
    .banChangeInfo
]

func groupPermissionDependencies(_ right: TelegramChatBannedRightsFlags) -> TelegramChatBannedRightsFlags {
    if right.contains(.banEmbedLinks) {
        return [.banSendText]
    } else if right.contains(.banSendMedia) || banSendMediaSubList().contains(where: { $0.0 == right }) {
        return []
    } else if right.contains(.banSendGifs) {
        return []
    } else if right.contains(.banSendPolls) {
        return []
    } else if right.contains(.banChangeInfo) {
        return []
    } else if right.contains(.banAddMembers) {
        return []
    } else if right.contains(.banPinMessages) {
        return []
    } else if right.contains(.banManageTopics) {
        return []
    } else {
        return []
    }
}

private func channelPermissionsControllerEntries(context: AccountContext, presentationData: PresentationData, view: PeerView, state: ChannelPermissionsControllerState, participants: [RenderedChannelParticipant]?, configuration: StarsSubscriptionConfiguration) -> [ChannelPermissionsEntry] {
    var entries: [ChannelPermissionsEntry] = []
    
    if let channel = view.peers[view.peerId] as? TelegramChannel, let participants = participants, let cachedData = view.cachedData as? CachedChannelData, let defaultBannedRights = channel.defaultBannedRights {
        var isDiscussion = false
        if case .group = channel.info, case let .known(peerId) = cachedData.linkedDiscussionPeerId, peerId != nil {
            isDiscussion = true
        }
        
        let effectiveRightsFlags: TelegramChatBannedRightsFlags
        if let modifiedRightsFlags = state.modifiedRightsFlags {
            effectiveRightsFlags = modifiedRightsFlags
        } else {
            effectiveRightsFlags = defaultBannedRights.flags
        }
        
        entries.append(.permissionsHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_SectionTitle))
        
        var rightIndex: Int = 0
        for (rights, correspondingAdminRight) in allGroupPermissionList(peer: .channel(channel), expandMedia: false) {
            var enabled = true
            if (channel.addressName != nil || channel.flags.contains(.hasGeo) || isDiscussion) && publicGroupRestrictedPermissions.contains(rights) {
                enabled = false
            }
            if !channel.hasPermission(.inviteMembers) {
                if rights.contains(.banAddMembers) {
                    enabled = false
                }
            }
            if !channel.hasPermission(correspondingAdminRight) {
                enabled = false
            }
            
            var isSelected = !effectiveRightsFlags.contains(rights)
            var subItems: [SubPermission] = []
            if rights == .banSendMedia {
                isSelected = banSendMediaSubList().allSatisfy({ !effectiveRightsFlags.contains($0.0) })
                
                for (subRight, _) in banSendMediaSubList() {
                    let subRightEnabled = true
                    
                    subItems.append(SubPermission(title: stringForGroupPermission(strings: presentationData.strings, right: subRight, isForum: channel.isForum), flags: subRight, isSelected: !effectiveRightsFlags.contains(subRight), isEnabled: enabled && subRightEnabled))
                }
            }
            
            entries.append(.permission(presentationData.theme, rightIndex, stringForGroupPermission(strings: presentationData.strings, right: rights, isForum: channel.flags.contains(.isForum)), isSelected, rights, enabled, subItems, state.expandedPermissions.contains(rights)))
            rightIndex += 1
        }
        
        let participantsLimit = context.currentLimitsConfiguration.with { $0 }.maxSupergroupMemberCount
        if channel.flags.contains(.isCreator) && !channel.flags.contains(.isGigagroup), let memberCount = cachedData.participantsSummary.memberCount, memberCount > participantsLimit - 1000 {
            entries.append(.conversionHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_BroadcastTitle.uppercased()))
            entries.append(.conversion(presentationData.theme, presentationData.strings.GroupInfo_Permissions_BroadcastConvert))
            entries.append(.conversionInfo(presentationData.theme, presentationData.strings.GroupInfo_Permissions_BroadcastConvertInfo(presentationStringsFormattedNumber(participantsLimit, presentationData.dateTimeFormat.groupingSeparator)).string))
        }
        
        if cachedData.flags.contains(.paidMessagesAvailable) && channel.hasPermission(.banMembers) {
            let sendPaidMessageStars = state.modifiedStarsAmount?.value ?? (cachedData.sendPaidMessageStars?.value ?? 0)
            let chargeEnabled = sendPaidMessageStars > 0
            entries.append(.chargeForMessages(presentationData.theme, presentationData.strings.GroupInfo_Permissions_ChargeForMessages, chargeEnabled))
            entries.append(.chargeForMessagesInfo(presentationData.theme, presentationData.strings.GroupInfo_Permissions_ChargeForMessagesInfo))
            
            if chargeEnabled {
                var price: String = ""
                let usdRate = Double(configuration.usdWithdrawRate) / 1000.0 / 100.0
                
                price = "≈\(formatTonUsdValue(sendPaidMessageStars, divide: false, rate: usdRate, dateTimeFormat: presentationData.dateTimeFormat))"
                
                entries.append(.messagePriceHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_MessagePrice))
                entries.append(.messagePrice(presentationData.theme, sendPaidMessageStars, configuration.paidMessageMaxAmount, price))
                entries.append(.messagePriceInfo(presentationData.theme, presentationData.strings.GroupInfo_Permissions_MessagePriceInfo("\(configuration.paidMessageCommissionPermille / 10)", price).string))
            }
        }
        
        let canSendText = !effectiveRightsFlags.contains(.banSendText)
        let canSendMedia = banSendMediaSubList().allSatisfy({ !effectiveRightsFlags.contains($0.0) })
        let slowModeTimeout = state.modifiedSlowmodeTimeout ?? (cachedData.slowModeTimeout ?? 0)
        if !canSendText || !canSendMedia || slowModeTimeout > 0 {
            let unrestrictBoosters = state.modifiedUnrestrictBoosters ?? (cachedData.boostsToUnrestrict ?? 0)
            let unrestrictEnabled = unrestrictBoosters > 0
            
            entries.append(.unrestrictBoostersSwitch(presentationData.theme, presentationData.strings.GroupInfo_Permissions_DontRestrictBoosters, unrestrictEnabled))
            if unrestrictEnabled {
                entries.append(.unrestrictBoosters(presentationData.theme, presentationData.strings, max(1, unrestrictBoosters)))
                entries.append(.unrestrictBoostersInfo(presentationData.theme, presentationData.strings.GroupInfo_Permissions_DontRestrictBoostersInfo))
            } else {
                entries.append(.unrestrictBoostersInfo(presentationData.theme, presentationData.strings.GroupInfo_Permissions_DontRestrictBoostersEnableInfo))
            }
        }
        
        entries.append(.slowmodeHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_SlowmodeHeader))
        entries.append(.slowmode(presentationData.theme, presentationData.strings, slowModeTimeout))
        entries.append(.slowmodeInfo(presentationData.theme, presentationData.strings.GroupInfo_Permissions_SlowmodeInfo))
        
        entries.append(.kicked(presentationData.theme, presentationData.strings.GroupInfo_Permissions_Removed, cachedData.participantsSummary.kickedCount.flatMap({ $0 == 0 ? "" : "\($0)" }) ?? ""))
        entries.append(.exceptionsHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_Exceptions))
        entries.append(.add(presentationData.theme, presentationData.strings.GroupInfo_Permissions_AddException))
        
        var index: Int32 = 0
        for participant in participants {
            entries.append(.peerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, index, participant, ItemListPeerItemEditing(editable: true, editing: false, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id, true, effectiveRightsFlags))
            index += 1
        }
    } else if let group = view.peers[view.peerId] as? TelegramGroup, let _ = view.cachedData as? CachedGroupData {
        let defaultBannedRights = group.defaultBannedRights ?? TelegramChatBannedRights(flags: [], untilDate: 0)
        
        let effectiveRightsFlags: TelegramChatBannedRightsFlags
        if let modifiedRightsFlags = state.modifiedRightsFlags {
            effectiveRightsFlags = modifiedRightsFlags
        } else {
            effectiveRightsFlags = defaultBannedRights.flags
        }
        
        entries.append(.permissionsHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_SectionTitle))
        var rightIndex: Int = 0
        for (rights, _) in allGroupPermissionList(peer: .legacyGroup(group), expandMedia: false) {
            var isSelected = !effectiveRightsFlags.contains(rights)
            
            var subItems: [SubPermission] = []
            if rights == .banSendMedia {
                isSelected = banSendMediaSubList().allSatisfy({ !effectiveRightsFlags.contains($0.0) })
                
                for (subRight, _) in banSendMediaSubList() {
                    let subRightEnabled = true
                    
                    subItems.append(SubPermission(title: stringForGroupPermission(strings: presentationData.strings, right: subRight, isForum: false), flags: subRight, isSelected: !effectiveRightsFlags.contains(subRight), isEnabled: subRightEnabled))
                }
            }
            
            entries.append(.permission(presentationData.theme, rightIndex, stringForGroupPermission(strings: presentationData.strings, right: rights, isForum: false), isSelected, rights, true, subItems, state.expandedPermissions.contains(rights)))
            rightIndex += 1
        }
        
        entries.append(.slowmodeHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_SlowmodeHeader))
        entries.append(.slowmode(presentationData.theme, presentationData.strings, 0))
        entries.append(.slowmodeInfo(presentationData.theme, presentationData.strings.GroupInfo_Permissions_SlowmodeInfo))
        
        entries.append(.exceptionsHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_Exceptions))
        entries.append(.add(presentationData.theme, presentationData.strings.GroupInfo_Permissions_AddException))
    }
    
    return entries
}

public func channelPermissionsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId originalPeerId: EnginePeer.Id, loadCompleted: @escaping () -> Void = {}) -> ViewController {
    let statePromise = ValuePromise(ChannelPermissionsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelPermissionsControllerState())
    let updateState: ((ChannelPermissionsControllerState) -> ChannelPermissionsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let configuration = StarsSubscriptionConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var navigateToChatControllerImpl: ((EnginePeer.Id) -> Void)?
    var dismissInputImpl: (() -> Void)?
    var dismissToChatController: (() -> Void)?
    var resetSlowmodeVisualValueImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let resolveDisposable = MetaDisposable()
    actionsDisposable.add(resolveDisposable)
    
    let updateBannedDisposable = MetaDisposable()
    actionsDisposable.add(updateBannedDisposable)
    
    let removePeerDisposable = MetaDisposable()
    actionsDisposable.add(removePeerDisposable)
    
    let sourcePeerId = Promise<(EnginePeer.Id, Bool)>((originalPeerId, false))
    
    let peersDisposable = MetaDisposable()
    let loadMoreControl = Atomic<PeerChannelMemberCategoryControl?>(value: nil)
    
    let peersPromise = Promise<(EnginePeer.Id, [RenderedChannelParticipant]?)>()
    
    actionsDisposable.add((sourcePeerId.get()
    |> deliverOnMainQueue).start(next: { peerId, updated in
        if peerId.namespace == Namespaces.Peer.CloudGroup {
            loadCompleted()
            peersDisposable.set(nil)
            let _ = loadMoreControl.swap(nil)
            peersPromise.set(.single((peerId, nil)))
        } else {
            var loadCompletedCalled = false
            let disposableAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.restricted(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, updated: { state in
                if case .loading(true) = state.loadingState, !updated {
                    peersPromise.set(.single((peerId, nil)))
                } else {
                    if !loadCompletedCalled {
                        loadCompletedCalled = true
                        loadCompleted()
                    }
                    peersPromise.set(.single((peerId, state.list)))
                }
            })
            peersDisposable.set(disposableAndLoadMoreControl.0)
            let _ = loadMoreControl.swap(disposableAndLoadMoreControl.1)
        }
    }))
    
    actionsDisposable.add(peersDisposable)
    
    let updateDefaultRightsDisposable = MetaDisposable()
    actionsDisposable.add(updateDefaultRightsDisposable)
    
    let updateUnrestrictBoostersDisposable = MetaDisposable()
    actionsDisposable.add(updateUnrestrictBoostersDisposable)
    
    let updateSendPaidMessageStarsDisposable = MetaDisposable()
    actionsDisposable.add(updateSendPaidMessageStarsDisposable)
    
    let peerView = Promise<PeerView>()
    peerView.set(sourcePeerId.get()
    |> mapToSignal(context.account.viewTracker.peerView))
    
    var upgradedToSupergroupImpl: ((EnginePeer.Id, @escaping () -> Void) -> Void)?
    
    let arguments = ChannelPermissionsControllerArguments(context: context, updatePermission: { rights, value in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            if let channel = view.peers[view.peerId] as? TelegramChannel, let _ = view.cachedData as? CachedChannelData {
                updateState { state in
                    var state = state
                    var effectiveRightsFlags: TelegramChatBannedRightsFlags
                    if let modifiedRightsFlags = state.modifiedRightsFlags {
                        effectiveRightsFlags = modifiedRightsFlags
                    } else if let defaultBannedRightsFlags = channel.defaultBannedRights?.flags {
                        effectiveRightsFlags = defaultBannedRightsFlags
                    } else {
                        effectiveRightsFlags = TelegramChatBannedRightsFlags()
                    }
                    
                    if rights == .banSendMedia {
                        if value {
                            effectiveRightsFlags.remove(rights)
                            for item in banSendMediaSubList() {
                                effectiveRightsFlags.remove(item.0)
                            }
                        } else {
                            effectiveRightsFlags.insert(rights)
                            for (right, _) in allGroupPermissionList(peer: .channel(channel), expandMedia: false) {
                                if groupPermissionDependencies(right).contains(rights) {
                                    effectiveRightsFlags.insert(right)
                                }
                            }
                            
                            for item in banSendMediaSubList() {
                                effectiveRightsFlags.insert(item.0)
                                for (right, _) in allGroupPermissionList(peer: .channel(channel), expandMedia: false) {
                                    if groupPermissionDependencies(right).contains(item.0) {
                                        effectiveRightsFlags.insert(right)
                                    }
                                }
                            }
                        }
                    } else {
                        if value {
                            effectiveRightsFlags.remove(rights)
                            effectiveRightsFlags = effectiveRightsFlags.subtracting(groupPermissionDependencies(rights))
                        } else {
                            effectiveRightsFlags.insert(rights)
                            for (right, _) in allGroupPermissionList(peer: .channel(channel), expandMedia: false) {
                                if groupPermissionDependencies(right).contains(rights) {
                                    effectiveRightsFlags.insert(right)
                                }
                            }
                            for (right, _) in banSendMediaSubList() {
                                if groupPermissionDependencies(right).contains(rights) {
                                    effectiveRightsFlags.insert(right)
                                }
                            }
                        }
                    }
                    if banSendMediaSubList().allSatisfy({ !effectiveRightsFlags.contains($0.0) }) {
                        effectiveRightsFlags.remove(.banSendMedia)
                    } else {
                        effectiveRightsFlags.insert(.banSendMedia)
                    }
                    state.modifiedRightsFlags = effectiveRightsFlags
                    return state
                }
                let state = stateValue.with { $0 }
                if let modifiedRightsFlags = state.modifiedRightsFlags {
                    updateDefaultRightsDisposable.set((context.engine.peers.updateDefaultChannelMemberBannedRights(peerId: view.peerId, rights: TelegramChatBannedRights(flags: completeRights(modifiedRightsFlags), untilDate: Int32.max))
                    |> deliverOnMainQueue).start())
                }
            } else if let group = view.peers[view.peerId] as? TelegramGroup, let _ = view.cachedData as? CachedGroupData {
                updateState { state in
                    var state = state
                    var effectiveRightsFlags: TelegramChatBannedRightsFlags
                    if let modifiedRightsFlags = state.modifiedRightsFlags {
                        effectiveRightsFlags = modifiedRightsFlags
                    } else if let defaultBannedRightsFlags = group.defaultBannedRights?.flags {
                        effectiveRightsFlags = defaultBannedRightsFlags
                    } else {
                        effectiveRightsFlags = TelegramChatBannedRightsFlags()
                    }
                    
                    if rights == .banSendMedia {
                        if value {
                            effectiveRightsFlags.remove(rights)
                            for item in banSendMediaSubList() {
                                effectiveRightsFlags.remove(item.0)
                            }
                        } else {
                            effectiveRightsFlags.insert(rights)
                            for (right, _) in allGroupPermissionList(peer: .legacyGroup(group), expandMedia: false) {
                                if groupPermissionDependencies(right).contains(rights) {
                                    effectiveRightsFlags.insert(right)
                                }
                            }
                            
                            for item in banSendMediaSubList() {
                                effectiveRightsFlags.insert(item.0)
                                for (right, _) in allGroupPermissionList(peer: .legacyGroup(group), expandMedia: false) {
                                    if groupPermissionDependencies(right).contains(item.0) {
                                        effectiveRightsFlags.insert(right)
                                    }
                                }
                            }
                        }
                    } else {
                        if value {
                            effectiveRightsFlags.remove(rights)
                            effectiveRightsFlags = effectiveRightsFlags.subtracting(groupPermissionDependencies(rights))
                        } else {
                            effectiveRightsFlags.insert(rights)
                            for (right, _) in allGroupPermissionList(peer: .legacyGroup(group), expandMedia: false) {
                                if groupPermissionDependencies(right).contains(rights) {
                                    effectiveRightsFlags.insert(right)
                                }
                            }
                        }
                    }
                    state.modifiedRightsFlags = effectiveRightsFlags
                    return state
                }
                let state = stateValue.with { $0 }
                if let modifiedRightsFlags = state.modifiedRightsFlags {
                    updateDefaultRightsDisposable.set((context.engine.peers.updateDefaultChannelMemberBannedRights(peerId: view.peerId, rights: TelegramChatBannedRights(flags: completeRights(modifiedRightsFlags), untilDate: Int32.max))
                        |> deliverOnMainQueue).start())
                }
            }
        })
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            var state = state
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                state.peerIdWithRevealedOptions = peerId
            }
            return state
        }
    }, addPeer: {
        let _ = (sourcePeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId, _ in
            var dismissController: (() -> Void)?
            let controller = ChannelMembersSearchController(context: context, peerId: peerId, mode: .ban, filters: [.disable([context.account.peerId])], openPeer: { peer, participant in
                if let participant = participant {
                    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                    switch participant.participant {
                        case .creator:
                            return
                        case let .member(_, _, adminInfo, _, _, _):
                            if let adminInfo = adminInfo, adminInfo.promotedBy != context.account.peerId {
                                presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_Members_AddBannedErrorAdmin, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                return
                            }
                    }
                }
                let _ = (context.account.postbox.loadedPeerWithId(peerId)
                |> deliverOnMainQueue).start(next: { channel in
                    dismissController?()
                        presentControllerImpl?(channelBannedMemberController(context: context, peerId: peerId, memberId: peer.id, initialParticipant: participant?.participant, updated: { _ in
                    }, upgradedToSupergroup: { upgradedPeerId, f in
                        upgradedToSupergroupImpl?(upgradedPeerId, f)
                    }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                })
            })
            dismissController = { [weak controller] in
                controller?.dismiss()
            }
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, removePeer: { memberId in
        let _ = (sourcePeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId, _ in
            updateState { state in
                var state = state
                state.removingPeerId = memberId
                return state
            }
            
            removePeerDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: memberId, bannedRights: nil)
            |> deliverOnMainQueue).start(error: { _ in
            }, completed: {
                updateState { state in
                    var state = state
                    state.removingPeerId = nil
                    return state
                }
            }))
        })
    }, openPeer: { participant in
        let _ = (sourcePeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId, _ in
            presentControllerImpl?(channelBannedMemberController(context: context, peerId: peerId, memberId: participant.peerId, initialParticipant: participant, updated: { _ in
            }, upgradedToSupergroup: { upgradedPeerId, f in
                upgradedToSupergroupImpl?(upgradedPeerId, f)
            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, openPeerInfo: { peer in
        if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
            pushControllerImpl?(controller)
        }
    }, openKicked: {
        let _ = (sourcePeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId, _ in
            pushControllerImpl?(channelBlacklistController(context: context, peerId: peerId))
        })
    }, presentRestrictedPermissionAlert: { right in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            guard let channel = view.peers[view.peerId] as? TelegramChannel else {
                return
            }
            for (listRight, permission) in allGroupPermissionList(peer: .channel(channel), expandMedia: false) {
                if listRight == right {
                    let text: String
                    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                    if !channel.hasPermission(permission) {
                        text = presentationData.strings.GroupInfo_Permissions_EditingDisabled
                    } else if right.contains(.banAddMembers) {
                        text = presentationData.strings.GroupPermission_AddMembersNotAvailable
                    } else {
                        var isDiscussion = false
                        if case .group = channel.info, let cachedData = view.cachedData as? CachedChannelData, case let .known(peerId) = cachedData.linkedDiscussionPeerId, peerId != nil {
                            isDiscussion = true
                        }
                        if channel.flags.contains(.hasGeo) {
                            text = presentationData.strings.GroupPermission_NotAvailableInGeoGroups
                        } else if isDiscussion {
                            text = presentationData.strings.GroupPermission_NotAvailableInDiscussionGroups
                        } else {
                            text = presentationData.strings.GroupPermission_NotAvailableInPublicGroups
                        }
                    }
                    presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                    break
                }
            }
        })
    }, presentConversionToBroadcastGroup: {
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        let controller = PermissionController(context: context, splashScreen: true)
        controller.navigationPresentation = .modal
        controller.setState(.custom(icon: .animation("BroadcastGroup"), title: presentationData.strings.BroadcastGroups_IntroTitle, subtitle: nil, text: presentationData.strings.BroadcastGroups_IntroText, buttonTitle: presentationData.strings.BroadcastGroups_Convert, secondaryButtonTitle: presentationData.strings.BroadcastGroups_Cancel, footerText: nil), animated: false)
        controller.proceed = { [weak controller] result in
            let attributedTitle = NSAttributedString(string: presentationData.strings.BroadcastGroups_ConfirmationAlert_Title, font: Font.semibold(presentationData.listsFontSize.baseDisplaySize), textColor: presentationData.theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
            let body = MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
            let bold = MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
            let attributedText = parseMarkdownIntoAttributedString(presentationData.strings.BroadcastGroups_ConfirmationAlert_Text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
            
            let alertController = richTextAlertController(context: context, title: attributedTitle, text: attributedText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.BroadcastGroups_ConfirmationAlert_Convert, action: { [weak controller] in
                controller?.dismiss()
                
                let _ = (convertGroupToGigagroup(account: context.account, peerId: originalPeerId)
                |> deliverOnMainQueue).start(completed: {
                    let participantsLimit = context.currentLimitsConfiguration.with { $0 }.maxSupergroupMemberCount
                    presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .gigagroupConversion(text: presentationData.strings.BroadcastGroups_Success(presentationStringsFormattedNumber(participantsLimit, presentationData.dateTimeFormat.decimalSeparator)).string), elevatedLayout: true, action: { _ in return false }), nil)
                    
                    dismissToChatController?()
                })
            })])
            controller?.present(alertController, in: .window(.root))
        }
        pushControllerImpl?(controller)
    }, openChannelExample: {
        resolveDisposable.set((context.engine.peers.resolvePeerByName(name: "durov", referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            guard case let .result(result) = result else {
                return .complete()
            }
            return .single(result)
        }
        |> deliverOnMainQueue).start(next: { peer in
            if let peer = peer {
                navigateToChatControllerImpl?(peer.id)
            }
        }))
    }, updateSlowmode: { value in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            if let _ = view.peers[view.peerId] as? TelegramChannel, let _ = view.cachedData as? CachedChannelData {
                updateState { state in
                    var state = state
                    state.modifiedSlowmodeTimeout = value
                    return state
                }
                let state = stateValue.with { $0 }
                if let modifiedSlowmodeTimeout = state.modifiedSlowmodeTimeout {
                    updateDefaultRightsDisposable.set(context.engine.peers.updateChannelSlowModeInteractively(peerId: view.peerId, timeout: modifiedSlowmodeTimeout == 0 ? nil : value).start())
                }
            } else if let _ = view.peers[view.peerId] as? TelegramGroup, let _ = view.cachedData as? CachedGroupData {
                updateState { state in
                    var state = state
                    state.modifiedSlowmodeTimeout = value
                    return state
                }
                
                let state = stateValue.with { $0 }
                guard let modifiedSlowmodeTimeout = state.modifiedSlowmodeTimeout else {
                    return
                }
                
                let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                let progress = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                presentControllerImpl?(progress, nil)
                
                let signal = context.engine.peers.convertGroupToSupergroup(peerId: view.peerId)
                |> mapError { error -> UpdateChannelSlowModeError in
                    switch error {
                    case .tooManyChannels:
                        Queue.mainQueue().async {
                            updateState { state in
                                var state = state
                                state.modifiedSlowmodeTimeout = nil
                                return state
                            }
                            resetSlowmodeVisualValueImpl?()
                        }
                        return .tooManyChannels
                    default:
                        return .generic
                    }
                }
                |> mapToSignal { upgradedPeerId -> Signal<EnginePeer.Id?, UpdateChannelSlowModeError> in
                    return context.engine.peers.updateChannelSlowModeInteractively(peerId: upgradedPeerId, timeout: modifiedSlowmodeTimeout == 0 ? nil : value)
                    |> mapToSignal { _ -> Signal<EnginePeer.Id?, UpdateChannelSlowModeError> in
                        return .complete()
                    }
                    |> then(.single(upgradedPeerId))
                }
                |> deliverOnMainQueue
                updateDefaultRightsDisposable.set((signal
                |> deliverOnMainQueue).start(next: { [weak progress] peerId in
                    if let peerId = peerId {
                        upgradedToSupergroupImpl?(peerId, {})
                    }
                    progress?.dismiss()
                }, error: { [weak progress] error in
                    progress?.dismiss()
                    
                    switch error {
                    case .tooManyChannels:
                        pushControllerImpl?(oldChannelsController(context: context, intent: .upgrade))
                    default:
                        break
                    }
                }))
            }
        })
    }, updateUnrestrictBoosters: { value in
        updateState { state in
            var state = state
            state.modifiedUnrestrictBoosters = value
            return state
        }
        
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            updateUnrestrictBoostersDisposable.set((context.engine.peers.updateChannelBoostsToUnlockRestrictions(peerId: view.peerId, boosts: value)
            |> deliverOnMainQueue).start())
        })
    }, updateStarsAmount: { value, apply in
        updateState { state in
            var state = state
            state.modifiedStarsAmount = value
            return state
        }
        
        if apply {
            let _ = (peerView.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { view in
                var effectiveValue = value
                if value?.value == 0 {
                    effectiveValue = nil
                }
                updateSendPaidMessageStarsDisposable.set((context.engine.peers.updateChannelPaidMessagesStars(peerId: view.peerId, stars: effectiveValue)
                |> deliverOnMainQueue).start())
            })
        }
    }, toggleIsOptionExpanded: { flags in
        updateState { state in
            var state = state
            if state.expandedPermissions.contains(flags) {
                state.expandedPermissions.remove(flags)
            } else {
                state.expandedPermissions.insert(flags)
            }
            return state
        }
    })
    
    let previousParticipants = Atomic<[RenderedChannelParticipant]?>(value: nil)
    
    let viewAndParticipants = combineLatest(queue: .mainQueue(), sourcePeerId.get(), peerView.get(), peersPromise.get())
    |> mapToSignal { peerIdAndChanged, view, peers -> Signal<(PeerView, [RenderedChannelParticipant]?), NoError> in
        let (peerId, changed) = peerIdAndChanged
        if view.peerId != peerId {
            return .complete()
        }
        if peers.0 != peerId {
            return .complete()
        }
        if changed {
            if view.cachedData == nil {
                return .complete()
            }
        }
        return .single((view, peers.1))
    }
    
    let previousExpandedPermissionsValue = Atomic<Set<TelegramChatBannedRightsFlags>?>(value: nil)
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(), presentationData, statePromise.get(), viewAndParticipants)
    |> deliverOnMainQueue
    |> map { presentationData, state, viewAndParticipants -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (view, participants) = viewAndParticipants
        
        var rightNavigationButton: ItemListNavigationButton?
        if let participants = participants, !participants.isEmpty {
            rightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .bold, enabled: true, action: {
                updateState { state in
                    var state = state
                    state.searchingMembers = true
                    return state
                }
            })
        }
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if view.peerId.namespace == Namespaces.Peer.CloudChannel && participants == nil {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }
        
        let previous = previousParticipants.swap(participants)
        let previousExpandedPermissions = previousExpandedPermissionsValue.swap(state.expandedPermissions)
        
        var searchItem: ItemListControllerSearch?
        if state.searchingMembers {
            searchItem = ChannelMembersSearchItem(context: context, peerId: view.peerId, searchContext: nil, searchMode: .searchBanned, cancel: {
                updateState { state in
                    var state = state
                    state.searchingMembers = false
                    return state
                }
            }, openPeer: { _, rendered in
                if let participant = rendered?.participant, case .member = participant, let _ = peerViewMainPeer(view) as? TelegramChannel {
                    updateState { state in
                        var state = state
                        state.searchingMembers = false
                        return state
                    }
                    presentControllerImpl?(channelBannedMemberController(context: context, peerId: view.peerId, memberId: participant.peerId, initialParticipant: participant, updated: { _ in
                    }, upgradedToSupergroup: { upgradedPeerId, f in
                        upgradedToSupergroupImpl?(upgradedPeerId, f)
                    }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
            }, pushController: { c in
                pushControllerImpl?(c)
            }, dismissInput: {
                dismissInputImpl?()
            })
        }
        
        var animateChanges = previous != nil && participants != nil && previous!.count >= participants!.count
        if let previousExpandedPermissions, previousExpandedPermissions != state.expandedPermissions {
            animateChanges = true
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.GroupInfo_Permissions_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelPermissionsControllerEntries(context: context, presentationData: presentationData, view: view, state: state, participants: participants, configuration: configuration), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
            controller.view.endEditing(true)
        }
    }
    
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }
    navigateToChatControllerImpl = { [weak controller] peerId in
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer else {
                return
            }
            if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), keepStack: .always))
            }
        })
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    dismissToChatController = { [weak controller] in
        if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
            var viewControllers = navigationController.viewControllers
            viewControllers = viewControllers.filter { controller in
                if controller is ItemListController {
                    return false
                }
                if controller is PeerInfoScreen {
                    return false
                }
                return true
            }
            navigationController.setViewControllers(viewControllers, animated: true)
        }
    }
    resetSlowmodeVisualValueImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        controller.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatSlowmodeItemNode {
                itemNode.forceSetValue(0)
            }
        }
    }
    upgradedToSupergroupImpl = { [weak controller] upgradedPeerId, f in
        guard let controller = controller, let navigationController = controller.navigationController as? NavigationController else {
            return
        }
        sourcePeerId.set(.single((upgradedPeerId, true)))
        rebuildControllerStackAfterSupergroupUpgrade(controller: controller, navigationController: navigationController)
    }
    
    controller.visibleBottomContentOffsetChanged = { offset in
        if case let .known(value) = offset, value < 40.0 {
            if let control = loadMoreControl.with({ $0 }) {
                let _ = (sourcePeerId.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { peerId, _ in
                    context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: control)
                })
            }
        }
    }
    return controller
}
