import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import ItemListAvatarAndNameInfoItem
import Emoji
import LocalizedPeerData

private let rankMaxLength: Int32 = 16

private final class ChannelAdminControllerArguments {
    let context: AccountContext
    let toggleRight: (TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags) -> Void
    let toggleRightWhileDisabled: (TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags) -> Void
    let transferOwnership: () -> Void
    let updateRank: (String, String) -> Void
    let updateFocusedOnRank: (Bool) -> Void
    let dismissAdmin: () -> Void
    let dismissInput: () -> Void
    let animateError: () -> Void
    
    init(context: AccountContext, toggleRight: @escaping (TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags) -> Void, toggleRightWhileDisabled: @escaping (TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags) -> Void, transferOwnership: @escaping () -> Void, updateRank: @escaping (String, String) -> Void, updateFocusedOnRank: @escaping (Bool) -> Void, dismissAdmin: @escaping () -> Void, dismissInput: @escaping () -> Void, animateError: @escaping () -> Void) {
        self.context = context
        self.toggleRight = toggleRight
        self.toggleRightWhileDisabled = toggleRightWhileDisabled
        self.transferOwnership = transferOwnership
        self.updateRank = updateRank
        self.updateFocusedOnRank = updateFocusedOnRank
        self.dismissAdmin = dismissAdmin
        self.dismissInput = dismissInput
        self.animateError = animateError
    }
}

private enum ChannelAdminSection: Int32 {
    case info
    case rank
    case rights
    case transfer
    case dismiss
}

private enum ChannelAdminEntryTag: ItemListItemTag {
    case rank

    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? ChannelAdminEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum ChannelAdminEntryStableId: Hashable {
    case info
    case rankTitle
    case rank
    case rankInfo
    case rightsTitle
    case right(TelegramChatAdminRightsFlags)
    case addAdminsInfo
    case transfer
    case dismiss
    
    var hashValue: Int {
        switch self {
            case .info:
                return 0
            case .rankTitle:
                return 1
            case .rank:
                return 2
            case .rankInfo:
                return 3
            case .rightsTitle:
                return 4
            case .addAdminsInfo:
                return 5
            case .dismiss:
                return 6
            case .transfer:
                return 7
            case let .right(flags):
                return flags.rawValue.hashValue
        }
    }
    
    static func ==(lhs: ChannelAdminEntryStableId, rhs: ChannelAdminEntryStableId) -> Bool {
        switch lhs {
            case .info:
                if case .info = rhs {
                    return true
                } else {
                    return false
                }
            case .rankTitle:
                if case .rankTitle = rhs {
                    return true
                } else {
                    return false
                }
            case .rank:
                if case .rank = rhs {
                    return true
                } else {
                    return false
                }
            case .rankInfo:
                if case .rankInfo = rhs {
                    return true
                } else {
                    return false
                }
            case .rightsTitle:
                if case .rightsTitle = rhs {
                    return true
                } else {
                    return false
                }
            case let right(flags):
                if case .right(flags) = rhs {
                    return true
                } else {
                    return false
                }
            case .addAdminsInfo:
                if case .addAdminsInfo = rhs {
                    return true
                } else {
                    return false
                }
            case .transfer:
                if case .transfer = rhs {
                    return true
                } else {
                    return false
                }
            case .dismiss:
                if case .dismiss = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum ChannelAdminEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, TelegramUserPresence?)
    case rankTitle(PresentationTheme, String, Int32?, Int32)
    case rank(PresentationTheme, PresentationStrings, String, String, Bool)
    case rankInfo(PresentationTheme, String)
    case rightsTitle(PresentationTheme, String)
    case rightItem(PresentationTheme, Int, String, TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags, Bool, Bool)
    case addAdminsInfo(PresentationTheme, String)
    case transfer(PresentationTheme, String)
    case dismiss(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return ChannelAdminSection.info.rawValue
            case .rankTitle, .rank, .rankInfo:
                return ChannelAdminSection.rank.rawValue
            case .rightsTitle, .rightItem, .addAdminsInfo:
                return ChannelAdminSection.rights.rawValue
            case .transfer:
                return ChannelAdminSection.transfer.rawValue
            case .dismiss:
                return ChannelAdminSection.dismiss.rawValue
        }
    }
    
    var stableId: ChannelAdminEntryStableId {
        switch self {
            case .info:
                return .info
            case .rankTitle:
                return .rankTitle
            case .rank:
                return .rank
            case .rankInfo:
                return .rankInfo
            case .rightsTitle:
                return .rightsTitle
            case let .rightItem(_, _, _, right, _, _, _):
                return .right(right)
            case .addAdminsInfo:
                return .addAdminsInfo
            case .transfer:
                return .transfer
            case .dismiss:
                return .dismiss
        }
    }
    
    static func ==(lhs: ChannelAdminEntry, rhs: ChannelAdminEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsPresence):
                if case let .info(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsPresence) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if !arePeersEqual(lhsPeer, rhsPeer) {
                        return false
                    }
                    if lhsPresence != rhsPresence {
                        return false
                    }
                    
                    return true
                } else {
                    return false
                }
            case let .rankTitle(lhsTheme, lhsText, lhsCount, lhsLimit):
                if case let .rankTitle(rhsTheme, rhsText, rhsCount, rhsLimit) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsCount == rhsCount, lhsLimit == rhsLimit {
                    return true
                } else {
                    return false
                }
            case let .rank(lhsTheme, lhsStrings, lhsPlaceholder, lhsValue, lhsEnabled):
                if case let .rank(rhsTheme, rhsStrings, rhsPlaceholder, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .rankInfo(lhsTheme, lhsText):
                if case let .rankInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .rightsTitle(lhsTheme, lhsText):
                if case let .rightsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .rightItem(lhsTheme, lhsIndex, lhsText, lhsRight, lhsFlags, lhsValue, lhsEnabled):
                if case let .rightItem(rhsTheme, rhsIndex, rhsText, rhsRight, rhsFlags, rhsValue, rhsEnabled) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsText != rhsText {
                        return false
                    }
                    if lhsRight != rhsRight {
                        return false
                    }
                    if lhsFlags != rhsFlags {
                        return false
                    }
                    if lhsValue != rhsValue {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .addAdminsInfo(lhsTheme, lhsText):
                if case let .addAdminsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .transfer(lhsTheme, lhsText):
                if case let .transfer(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .dismiss(lhsTheme, lhsText):
                if case let .dismiss(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelAdminEntry, rhs: ChannelAdminEntry) -> Bool {
        switch lhs {
            case .info:
                switch rhs {
                    case .info:
                        return false
                    default:
                        return true
                }
            case .rightsTitle:
                switch rhs {
                    case .info, .rightsTitle:
                        return false
                    default:
                        return true
                }
            case let .rightItem(_, lhsIndex, _, _, _, _, _):
                switch rhs {
                    case .info, .rightsTitle:
                        return false
                    case let .rightItem(_, rhsIndex, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return true
                }
            case .addAdminsInfo:
                switch rhs {
                    case .info, .rightsTitle, .rightItem, .addAdminsInfo:
                        return false
                    default:
                        return true
                }
            case .transfer:
                switch rhs {
                    case .info, .rightsTitle, .rightItem, .addAdminsInfo, .transfer:
                        return false
                    default:
                        return true
                }
            case .rankTitle:
                switch rhs {
                    case .info, .rightsTitle, .rightItem, .addAdminsInfo, .transfer, .rankTitle:
                        return false
                    default:
                        return true
                }
            case .rank:
                switch rhs {
                    case .info, .rightsTitle, .rightItem, .addAdminsInfo, .transfer, .rankTitle, .rank:
                        return false
                    default:
                        return true
                }
            case .rankInfo:
                switch rhs {
                    case .info, .rightsTitle, .rightItem, .addAdminsInfo, .transfer, .rankTitle, .rank, .rankInfo:
                        return false
                    default:
                        return true
                }
            case .dismiss:
                return false
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelAdminControllerArguments
        switch self {
            case let .info(theme, strings, dateTimeFormat, peer, presence):
                return ItemListAvatarAndNameInfoItem(accountContext: arguments.context, presentationData: presentationData, dateTimeFormat: dateTimeFormat, mode: .generic, peer: peer, presence: presence, cachedData: nil, state: ItemListAvatarAndNameInfoItemState(), sectionId: self.section, style: .blocks(withTopInset: true, withExtendedBottomInset: false), editingNameUpdated: { _ in
                }, avatarTapped: {
                })
            case let .rankTitle(theme, text, count, limit):
                var accessoryText: ItemListSectionHeaderAccessoryText?
                if let count = count {
                    accessoryText = ItemListSectionHeaderAccessoryText(value: "\(limit - count)", color: count > limit ? .destructive : .generic)
                }
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: accessoryText, sectionId: self.section)
            case let .rank(theme, strings, placeholder, text, enabled):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "", textColor: .black), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: true), spacing: 0.0, clearType: enabled ? .always : .none, enabled: enabled, tag: ChannelAdminEntryTag.rank, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateRank(text, updatedText)
                }, shouldUpdateText: { text in
                    if text.containsEmoji {
                        arguments.animateError()
                        return false
                    }
                    return true
                }, updatedFocus: { focus in
                    arguments.updateFocusedOnRank(focus)
                }, action: {
                    arguments.dismissInput()
                })
            case let .rankInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .rightsTitle(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .rightItem(theme, _, text, right, flags, value, enabled):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, type: .icon, enabled: enabled, sectionId: self.section, style: .blocks, updated: { _ in
                    arguments.toggleRight(right, flags)
                }, activatedWhileDisabled: {
                    arguments.toggleRightWhileDisabled(right, flags)
                })
            case let .addAdminsInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .transfer(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.transferOwnership()
                }, tag: nil)
            case let .dismiss(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.dismissAdmin()
                }, tag: nil)
        }
    }
}

private struct ChannelAdminControllerState: Equatable {
    let updatedFlags: TelegramChatAdminRightsFlags?
    let updatedRank: String?
    let updating: Bool
    let focusedOnRank: Bool
    
    init(updatedFlags: TelegramChatAdminRightsFlags? = nil, updatedRank: String? = nil, updating: Bool = false, focusedOnRank: Bool = false) {
        self.updatedFlags = updatedFlags
        self.updatedRank = updatedRank
        self.updating = updating
        self.focusedOnRank = focusedOnRank
    }
    
    static func ==(lhs: ChannelAdminControllerState, rhs: ChannelAdminControllerState) -> Bool {
        if lhs.updatedFlags != rhs.updatedFlags {
            return false
        }
        if lhs.updatedRank != rhs.updatedRank {
            return false
        }
        if lhs.updating != rhs.updating {
            return false
        }
        if lhs.focusedOnRank != rhs.focusedOnRank {
            return false
        }
        return true
    }
    
    func withUpdatedUpdatedFlags(_ updatedFlags: TelegramChatAdminRightsFlags?) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: updatedFlags, updatedRank: self.updatedRank, updating: self.updating, focusedOnRank: self.focusedOnRank)
    }
    
    func withUpdatedUpdatedRank(_ updatedRank: String?) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: self.updatedFlags, updatedRank: updatedRank, updating: self.updating, focusedOnRank: self.focusedOnRank)
    }
    
    func withUpdatedUpdating(_ updating: Bool) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: self.updatedFlags, updatedRank: self.updatedRank, updating: updating, focusedOnRank: self.focusedOnRank)
    }
    
    func withUpdatedFocusedOnRank(_ focusedOnRank: Bool) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: self.updatedFlags, updatedRank: self.updatedRank, updating: self.updating, focusedOnRank: focusedOnRank)
    }
}

private func stringForRight(strings: PresentationStrings, right: TelegramChatAdminRightsFlags, isGroup: Bool, defaultBannedRights: TelegramChatBannedRights?) -> String {
    if right.contains(.canChangeInfo) {
        return isGroup ? strings.Group_EditAdmin_PermissionChangeInfo : strings.Channel_EditAdmin_PermissionChangeInfo
    } else if right.contains(.canPostMessages) {
        return strings.Channel_EditAdmin_PermissionPostMessages
    } else if right.contains(.canEditMessages) {
        return strings.Channel_EditAdmin_PermissionEditMessages
    } else if right.contains(.canDeleteMessages) {
        return isGroup ? strings.Channel_EditAdmin_PermissionDeleteMessages : strings.Channel_EditAdmin_PermissionDeleteMessagesOfOthers
    } else if right.contains(.canBanUsers) {
        return strings.Channel_EditAdmin_PermissionBanUsers
    } else if right.contains(.canInviteUsers) {
        if isGroup {
            if let defaultBannedRights = defaultBannedRights, defaultBannedRights.flags.contains(.banAddMembers) {
                return strings.Channel_EditAdmin_PermissionInviteMembers
            } else {
                return strings.Channel_EditAdmin_PermissionInviteViaLink
            }
        } else {
            return strings.Channel_EditAdmin_PermissionInviteSubscribers
        }
    } else if right.contains(.canPinMessages) {
        return strings.Channel_EditAdmin_PermissionPinMessages
    } else if right.contains(.canAddAdmins) {
        return strings.Channel_EditAdmin_PermissionAddAdmins
    } else {
        return ""
    }
}

private func rightDependencies(_ right: TelegramChatAdminRightsFlags) -> [TelegramChatAdminRightsFlags] {
    if right.contains(.canChangeInfo) {
        return []
    } else if right.contains(.canPostMessages) {
        return []
    } else if right.contains(.canEditMessages) {
        return []
    } else if right.contains(.canDeleteMessages) {
        return []
    } else if right.contains(.canBanUsers) {
        return []
    } else if right.contains(.canInviteUsers) {
        return []
    } else if right.contains(.canPinMessages) {
        return []
    } else if right.contains(.canAddAdmins) {
        return []
    } else {
        return []
    }
}

private func canEditAdminRights(accountPeerId: PeerId, channelPeer: Peer, initialParticipant: ChannelParticipant?) -> Bool {
    if let channel = channelPeer as? TelegramChannel {
        if channel.flags.contains(.isCreator) {
            return true
        } else if let initialParticipant = initialParticipant {
            switch initialParticipant {
                case .creator:
                    return false
                case let .member(_, _, adminInfo, _, _):
                    if let adminInfo = adminInfo {
                        return adminInfo.canBeEditedByAccountPeer || adminInfo.promotedBy == accountPeerId
                    } else {
                        return channel.hasPermission(.addAdmins)
                    }
            }
        } else {
            return channel.hasPermission(.addAdmins)
        }
    } else if let group = channelPeer as? TelegramGroup {
        if case .creator = group.role {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}

private func rightEnabledByDefault(channelPeer: Peer, right: TelegramChatAdminRightsFlags) -> Bool {
    if let channel = channelPeer as? TelegramChannel {
        guard let defaultBannedRights = channel.defaultBannedRights else {
            return false
        }
        switch right {
        case .canPinMessages:
            return !defaultBannedRights.flags.contains(.banPinMessages)
        case .canChangeInfo:
            return !defaultBannedRights.flags.contains(.banChangeInfo)
        default:
            break
        }
    }
    return false
}

private func areAllAdminRightsEnabled(_ flags: TelegramChatAdminRightsFlags, group: Bool) -> Bool {
    if group {
        return TelegramChatAdminRightsFlags.groupSpecific.intersection(flags) == TelegramChatAdminRightsFlags.groupSpecific
    } else {
        return TelegramChatAdminRightsFlags.broadcastSpecific.intersection(flags) == TelegramChatAdminRightsFlags.broadcastSpecific
    }
}

private func channelAdminControllerEntries(presentationData: PresentationData, state: ChannelAdminControllerState, accountPeerId: PeerId, channelView: PeerView, adminView: PeerView, initialParticipant: ChannelParticipant?, canEdit: Bool) -> [ChannelAdminEntry] {
    var entries: [ChannelAdminEntry] = []
    
    if let channel = channelView.peers[channelView.peerId] as? TelegramChannel, let admin = adminView.peers[adminView.peerId] {
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, admin, adminView.peerPresences[admin.id] as? TelegramUserPresence))
        
        var isCreator = false
        if let initialParticipant = initialParticipant, case .creator = initialParticipant {
            isCreator = true
        }
        
        var canTransfer = false
        var canDismiss = false
        
        let isGroup: Bool
        let maskRightsFlags: TelegramChatAdminRightsFlags
        let rightsOrder: [TelegramChatAdminRightsFlags]
        
        switch channel.info {
            case .broadcast:
                isGroup = false
                maskRightsFlags = .broadcastSpecific
                rightsOrder = [
                    .canChangeInfo,
                    .canPostMessages,
                    .canEditMessages,
                    .canDeleteMessages,
                    .canInviteUsers,
                    .canAddAdmins
                ]
            case .group:
                isGroup = true
                maskRightsFlags = .groupSpecific
                rightsOrder = [
                    .canChangeInfo,
                    .canDeleteMessages,
                    .canBanUsers,
                    .canInviteUsers,
                    .canPinMessages,
                    .canAddAdmins
                ]
        }
        
        if isCreator {
        } else {
            entries.append(.rightsTitle(presentationData.theme, presentationData.strings.Channel_EditAdmin_PermissionsHeader))
        
            if let channelPeer = channelView.peers[channelView.peerId], canEditAdminRights(accountPeerId: accountPeerId, channelPeer: channelPeer, initialParticipant: initialParticipant) {
                let accountUserRightsFlags: TelegramChatAdminRightsFlags
                if channel.flags.contains(.isCreator) {
                    accountUserRightsFlags = maskRightsFlags
                } else if let adminRights = channel.adminRights {
                    accountUserRightsFlags = maskRightsFlags.intersection(adminRights.flags)
                } else {
                    accountUserRightsFlags = []
                }
                
                let currentRightsFlags: TelegramChatAdminRightsFlags
                if let updatedFlags = state.updatedFlags {
                    currentRightsFlags = updatedFlags
                } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminRights, _, _) = initialParticipant, let adminRights = maybeAdminRights {
                    currentRightsFlags = adminRights.rights.flags
                } else {
                    currentRightsFlags = accountUserRightsFlags.subtracting(.canAddAdmins)
                }
                
                var index = 0
                for right in rightsOrder {
                    if accountUserRightsFlags.contains(right) {
                        entries.append(.rightItem(presentationData.theme, index, stringForRight(strings: presentationData.strings, right: right, isGroup: isGroup, defaultBannedRights: channel.defaultBannedRights), right, currentRightsFlags, currentRightsFlags.contains(right), !state.updating && admin.id != accountPeerId && !rightEnabledByDefault(channelPeer: channel, right: right)))
                        index += 1
                    }
                }
                
                if accountUserRightsFlags.contains(.canAddAdmins) {
                    entries.append(.addAdminsInfo(presentationData.theme, currentRightsFlags.contains(.canAddAdmins) ? presentationData.strings.Channel_EditAdmin_PermissinAddAdminOn : presentationData.strings.Channel_EditAdmin_PermissinAddAdminOff))
                }
                
                if let admin = admin as? TelegramUser, admin.botInfo == nil && !admin.isDeleted && channel.flags.contains(.isCreator) && areAllAdminRightsEnabled(currentRightsFlags, group: isGroup) {
                    canTransfer = true
                }
            
                if let initialParticipant = initialParticipant, case let .member(participant) = initialParticipant, let adminInfo = participant.adminInfo, !adminInfo.rights.flags.isEmpty && admin.id != accountPeerId {
                    if channel.flags.contains(.isCreator) {
                        canDismiss = true
                    } else {
                        switch initialParticipant {
                            case .creator:
                                break
                            case let .member(_, _, adminInfo, _, _):
                                if let adminInfo = adminInfo {
                                    if adminInfo.promotedBy == accountPeerId || adminInfo.canBeEditedByAccountPeer {
                                        canDismiss = true
                                    }
                                }
                        }
                    }
                }
            } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminInfo, _, _) = initialParticipant, let adminInfo = maybeAdminInfo {
                var index = 0
                for right in rightsOrder {
                    entries.append(.rightItem(presentationData.theme, index, stringForRight(strings: presentationData.strings, right: right, isGroup: isGroup, defaultBannedRights: channel.defaultBannedRights), right, adminInfo.rights.flags, adminInfo.rights.flags.contains(right), false))
                    index += 1
                }
            }
        }
        
        if canTransfer {
            entries.append(.transfer(presentationData.theme, isGroup ? presentationData.strings.Group_EditAdmin_TransferOwnership : presentationData.strings.Channel_EditAdmin_TransferOwnership))
        }
        
        if case .group = channel.info {
            let placeholder = isCreator ? presentationData.strings.Group_EditAdmin_RankOwnerPlaceholder : presentationData.strings.Group_EditAdmin_RankAdminPlaceholder
            
            let currentRank: String?
            if let updatedRank = state.updatedRank {
                currentRank = updatedRank
            } else if let initialParticipant = initialParticipant {
                currentRank = initialParticipant.rank
            } else {
                currentRank = nil
            }
            
            let rankEnabled = !state.updating && canEdit
            entries.append(.rankTitle(presentationData.theme, presentationData.strings.Group_EditAdmin_RankTitle.uppercased(), rankEnabled && state.focusedOnRank ? Int32(currentRank?.count ?? 0) : nil, rankMaxLength))
            entries.append(.rank(presentationData.theme, presentationData.strings, isCreator ? presentationData.strings.Group_EditAdmin_RankOwnerPlaceholder : presentationData.strings.Group_EditAdmin_RankAdminPlaceholder, currentRank ?? "", rankEnabled))
            entries.append(.rankInfo(presentationData.theme, presentationData.strings.Group_EditAdmin_RankInfo(placeholder).0))
        }
        
        if canDismiss {
            entries.append(.dismiss(presentationData.theme, presentationData.strings.Channel_Moderator_AccessLevelRevoke))
        }
    } else if let group = channelView.peers[channelView.peerId] as? TelegramGroup, let admin = adminView.peers[adminView.peerId] {
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, admin, adminView.peerPresences[admin.id] as? TelegramUserPresence))
        
        var isCreator = false
        if let initialParticipant = initialParticipant, case .creator = initialParticipant {
            isCreator = true
        }
        
        let currentRank: String?
        if let updatedRank = state.updatedRank {
            currentRank = updatedRank
        } else {
            currentRank = nil
        }
        
        let rankEnabled = !state.updating && canEdit
        
        if isCreator {
            entries.append(.rankTitle(presentationData.theme, presentationData.strings.Group_EditAdmin_RankTitle.uppercased(), rankEnabled && state.focusedOnRank ? Int32(currentRank?.count ?? 0) : nil, rankMaxLength))
            entries.append(.rank(presentationData.theme, presentationData.strings, isCreator ? presentationData.strings.Group_EditAdmin_RankOwnerPlaceholder : presentationData.strings.Group_EditAdmin_RankAdminPlaceholder, currentRank ?? "", rankEnabled))
        } else {
            entries.append(.rightsTitle(presentationData.theme, presentationData.strings.Channel_EditAdmin_PermissionsHeader))
            
            let isGroup = true
            let maskRightsFlags: TelegramChatAdminRightsFlags = .groupSpecific
            let rightsOrder: [TelegramChatAdminRightsFlags] = [
                    .canChangeInfo,
                    .canDeleteMessages,
                    .canBanUsers,
                    .canInviteUsers,
                    .canPinMessages,
                    .canAddAdmins
                ]
        
            let accountUserRightsFlags: TelegramChatAdminRightsFlags = maskRightsFlags
        
            let currentRightsFlags: TelegramChatAdminRightsFlags
            if let updatedFlags = state.updatedFlags {
                currentRightsFlags = updatedFlags
            } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminRights, _, _) = initialParticipant, let adminRights = maybeAdminRights {
                currentRightsFlags = adminRights.rights.flags.subtracting(.canAddAdmins)
            } else {
                currentRightsFlags = accountUserRightsFlags.subtracting(.canAddAdmins)
            }
        
            var index = 0
            for right in rightsOrder {
                if accountUserRightsFlags.contains(right) {
                    entries.append(.rightItem(presentationData.theme, index, stringForRight(strings: presentationData.strings, right: right, isGroup: isGroup, defaultBannedRights: group.defaultBannedRights), right, currentRightsFlags, currentRightsFlags.contains(right), !state.updating))
                    index += 1
                }
            }
        
            if accountUserRightsFlags.contains(.canAddAdmins) {
                entries.append(.addAdminsInfo(presentationData.theme, currentRightsFlags.contains(.canAddAdmins) ? presentationData.strings.Channel_EditAdmin_PermissinAddAdminOn : presentationData.strings.Channel_EditAdmin_PermissinAddAdminOff))
            }
        
            if let admin = admin as? TelegramUser, case .creator = group.role, admin.botInfo == nil && !admin.isDeleted && areAllAdminRightsEnabled(currentRightsFlags, group: true) {
                entries.append(.transfer(presentationData.theme, presentationData.strings.Group_EditAdmin_TransferOwnership))
            }
            
            entries.append(.rankTitle(presentationData.theme, presentationData.strings.Group_EditAdmin_RankTitle.uppercased(), rankEnabled && state.focusedOnRank ? Int32(currentRank?.count ?? 0) : nil, rankMaxLength))
            entries.append(.rank(presentationData.theme, presentationData.strings, isCreator ? presentationData.strings.Group_EditAdmin_RankOwnerPlaceholder : presentationData.strings.Group_EditAdmin_RankAdminPlaceholder, currentRank ?? "", rankEnabled))
            
            if let initialParticipant = initialParticipant, case let .member(participant) = initialParticipant, let adminInfo = participant.adminInfo, !adminInfo.rights.flags.isEmpty && admin.id != accountPeerId {
                entries.append(.dismiss(presentationData.theme, presentationData.strings.Channel_Moderator_AccessLevelRevoke))
            }
        }
    }
    
    return entries
}

public func channelAdminController(context: AccountContext, peerId: PeerId, adminId: PeerId, initialParticipant: ChannelParticipant?, updated: @escaping (TelegramChatAdminRights) -> Void, upgradedToSupergroup: @escaping (PeerId, @escaping () -> Void) -> Void, transferedOwnership: @escaping (PeerId) -> Void) -> ViewController {
    let statePromise = ValuePromise(ChannelAdminControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelAdminControllerState())
    let updateState: ((ChannelAdminControllerState) -> ChannelAdminControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let updateRightsDisposable = MetaDisposable()
    actionsDisposable.add(updateRightsDisposable)
    
    let transferOwnershipDisposable = MetaDisposable()
    actionsDisposable.add(transferOwnershipDisposable)
    
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var errorImpl: (() -> Void)?
    var scrollToRankImpl: (() -> Void)?
    
    let actualPeerId = Atomic<PeerId>(value: peerId)
    let upgradedToSupergroupImpl: (PeerId, @escaping () -> Void) -> Void = { peerId, completion in
        let _ = actualPeerId.swap(peerId)
        upgradedToSupergroup(peerId, completion)
    }
    
    let arguments = ChannelAdminControllerArguments(context: context, toggleRight: { right, flags in
        updateState { current in
            var updated = flags
            if flags.contains(right) {
                updated.remove(right)
            } else {
                updated.insert(right)
            }
            return current.withUpdatedUpdatedFlags(updated)
        }
    }, toggleRightWhileDisabled: { right, _ in
        let _ = (context.account.postbox.transaction { transaction -> (peer: Peer?, member: Peer?) in
            return (peer: transaction.getPeer(peerId), member: transaction.getPeer(adminId))
        }
        |> deliverOnMainQueue).start(next: { peer, member in
            guard let peer = peer, let _ = member as? TelegramUser else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            let text: String
            if !canEditAdminRights(accountPeerId: context.account.peerId, channelPeer: peer, initialParticipant: initialParticipant) {
                text = presentationData.strings.Channel_EditAdmin_CannotEdit
            } else if rightEnabledByDefault(channelPeer: peer, right: right) {
                text = presentationData.strings.Channel_EditAdmin_PermissionEnabledByDefault
            } else {
                text = presentationData.strings.Channel_EditAdmin_CannotEdit
            }
            
            presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
        })
    }, transferOwnership: {
        let _ = (context.account.postbox.transaction { transaction -> (peer: Peer?, member: Peer?) in
            return (peer: transaction.getPeer(peerId), member: transaction.getPeer(adminId))
        } |> deliverOnMainQueue).start(next: { peer, member in
            guard let peer = peer, let member = member as? TelegramUser else {
                return
            }
            
            transferOwnershipDisposable.set((checkOwnershipTranfserAvailability(postbox: context.account.postbox, network: context.account.network, accountStateManager: context.account.stateManager, memberId: adminId) |> deliverOnMainQueue).start(error: { error in
                let controller = channelOwnershipTransferController(context: context, peer: peer, member: member, initialError: error, present: { c, a in
                    presentControllerImpl?(c, a)
                }, completion: { upgradedPeerId in
                    if let upgradedPeerId = upgradedPeerId {
                        upgradedToSupergroupImpl(upgradedPeerId, {
                            dismissImpl?()
                            transferedOwnership(member.id)
                        })
                    } else {
                        dismissImpl?()
                        transferedOwnership(member.id)
                    }
                })
                presentControllerImpl?(controller, nil)
            }))
        })
    }, updateRank: { previousRank, updatedRank in
        if updatedRank != previousRank {
            updateState { $0.withUpdatedUpdatedRank(updatedRank) }
        }
    }, updateFocusedOnRank: { focusedOnRank in
        updateState { $0.withUpdatedFocusedOnRank(focusedOnRank) }
        
        if focusedOnRank {
            scrollToRankImpl?()
        }
    }, dismissAdmin: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        items.append(ActionSheetButtonItem(title: presentationData.strings.Channel_Moderator_AccessLevelRevoke, color: .destructive, font: .default, enabled: true, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            
            updateState { current in
                return current.withUpdatedUpdating(true)
            }
            if peerId.namespace == Namespaces.Peer.CloudGroup {
                updateRightsDisposable.set((removeGroupAdmin(account: context.account, peerId: peerId, adminId: adminId)
                |> deliverOnMainQueue).start(error: { _ in
                }, completed: {
                    updated(TelegramChatAdminRights(flags: []))
                    dismissImpl?()
                }))
            } else {
                updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: []), rank: nil) |> deliverOnMainQueue).start(error: { _ in
                    
                }, completed: {
                    updated(TelegramChatAdminRights(flags: []))
                    dismissImpl?()
                }))
            }
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }, dismissInput: {
        dismissInputImpl?()
    }, animateError: {
        errorImpl?()
    })
    
    let combinedView = context.account.postbox.combinedView(keys: [.peer(peerId: peerId, components: .all), .peer(peerId: adminId, components: .all)])
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), combinedView)
    |> deliverOnMainQueue
    |> map { presentationData, state, combinedView -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let channelView = combinedView.views[.peer(peerId: peerId, components: .all)] as! PeerView
        let adminView = combinedView.views[.peer(peerId: adminId, components: .all)] as! PeerView
        let canEdit = canEditAdminRights(accountPeerId: context.account.peerId, channelPeer: channelView.peers[channelView.peerId]!, initialParticipant: initialParticipant)
        
        let leftNavigationButton: ItemListNavigationButton
        if canEdit {
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
        } else {
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                dismissImpl?()
            })
        }
        
        var focusItemTag: ItemListItemTag?
        if let initialParticipant = initialParticipant, case .creator = initialParticipant {
            focusItemTag = ChannelAdminEntryTag.rank
        }
        
        var rightNavigationButton: ItemListNavigationButton?
        if state.updating {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else if canEdit {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                if let channel = channelView.peers[channelView.peerId] as? TelegramChannel {
                    if let initialParticipant = initialParticipant {
                        var updateFlags: TelegramChatAdminRightsFlags?
                        var updateRank: String?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            updateRank = current.updatedRank?.trimmingCharacters(in: .whitespacesAndNewlines)
                            return current
                        }
                        
                        if let updateRank = updateRank, updateRank.count > rankMaxLength || updateRank.containsEmoji {
                            errorImpl?()
                            return
                        }
                        
                        let maskRightsFlags: TelegramChatAdminRightsFlags
                        switch channel.info {
                            case .broadcast:
                                maskRightsFlags = .broadcastSpecific
                            case .group:
                                maskRightsFlags = .groupSpecific
                        }
                        
                        var currentRank: String?
                        var currentFlags: TelegramChatAdminRightsFlags?
                        switch initialParticipant {
                            case let .creator(creator):
                                currentRank = creator.rank
                                currentFlags = maskRightsFlags
                            case let .member(member):
                                if updateFlags == nil {
                                    if member.adminInfo?.rights == nil {
                                        if channel.flags.contains(.isCreator) {
                                            updateFlags = maskRightsFlags.subtracting(.canAddAdmins)
                                        } else if let adminRights = channel.adminRights {
                                            updateFlags = maskRightsFlags.intersection(adminRights.flags).subtracting(.canAddAdmins)
                                        } else {
                                            updateFlags = []
                                        }
                                    }
                                }
                                currentRank = member.rank
                                currentFlags = member.adminInfo?.rights.flags
                        }
                        
                        let effectiveRank = updateRank ?? currentRank
                        if effectiveRank?.containsEmoji ?? false {
                            errorImpl?()
                            return
                        }
                        
                        if let updateFlags = updateFlags {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: updateFlags), rank: effectiveRank) |> deliverOnMainQueue).start(error: { error in
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                var text = presentationData.strings.Login_UnknownError
                                switch error {
                                case .generic:
                                    break
                                case let .addMemberError(addMemberError):
                                    switch addMemberError {
                                    case .tooMuchJoined:
                                        text = presentationData.strings.Group_ErrorSupergroupConversionNotPossible
                                    case .restricted:
                                        if let peer = adminView.peers[adminView.peerId] {
                                            text = presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(peer.compactDisplayTitle, peer.compactDisplayTitle).0
                                        }
                                    case .notMutualContact:
                                        text = presentationData.strings.GroupInfo_AddUserLeftError
                                    default:
                                        break
                                    }
                                }
                                presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                            }, completed: {
                                updated(TelegramChatAdminRights(flags: updateFlags))
                                dismissImpl?()
                            }))
                        } else if let updateRank = updateRank, let currentFlags = currentFlags {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: currentFlags), rank: updateRank) |> deliverOnMainQueue).start(error: { _ in
                                
                            }, completed: {
                                updated(TelegramChatAdminRights(flags: currentFlags))
                                dismissImpl?()
                            }))
                        } else {
                            dismissImpl?()
                        }
                    } else if canEdit {
                        var updateFlags: TelegramChatAdminRightsFlags?
                        var updateRank: String?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            updateRank = current.updatedRank?.trimmingCharacters(in: .whitespacesAndNewlines)
                            return current
                        }
                        
                        if let updateRank = updateRank, updateRank.count > rankMaxLength || updateRank.containsEmoji {
                            errorImpl?()
                            return
                        }
                        
                        if updateFlags == nil {
                            let maskRightsFlags: TelegramChatAdminRightsFlags
                            switch channel.info {
                                case .broadcast:
                                    maskRightsFlags = .broadcastSpecific
                                case .group:
                                    maskRightsFlags = .groupSpecific
                            }
                            
                            if channel.flags.contains(.isCreator) {
                                updateFlags = maskRightsFlags.subtracting(.canAddAdmins)
                            } else if let adminRights = channel.adminRights {
                                updateFlags = maskRightsFlags.intersection(adminRights.flags).subtracting(.canAddAdmins)
                            } else {
                                updateFlags = []
                            }
                        }
                        
                        if let updateFlags = updateFlags {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: updateFlags), rank: updateRank) |> deliverOnMainQueue).start(error: { error in
                                if case let .addMemberError(error) = error, let admin = adminView.peers[adminView.peerId] {
                                    if case .restricted = error {
                                        var text = presentationData.strings.Privacy_GroupsAndChannels_InviteToChannelError(admin.compactDisplayTitle, admin.compactDisplayTitle).0
                                        if case .group = channel.info {
                                            text = presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(admin.compactDisplayTitle, admin.compactDisplayTitle).0
                                        }
                                        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                    } else if case .tooMuchJoined = error {
                                        let text = presentationData.strings.Invite_ChannelsTooMuch
                                        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                    }
                                }
                                dismissImpl?()
                            }, completed: {
                                updated(TelegramChatAdminRights(flags: updateFlags))
                                dismissImpl?()
                            }))
                        }
                    }
                } else if let _ = channelView.peers[channelView.peerId] as? TelegramGroup {
                    var updateFlags: TelegramChatAdminRightsFlags?
                    var updateRank: String?
                    updateState { current in
                        updateFlags = current.updatedFlags
                        if let updatedRank = current.updatedRank, !updatedRank.isEmpty {
                            updateRank = updatedRank.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        return current
                    }
                    
                    if let updateRank = updateRank, updateRank.count > rankMaxLength || updateRank.containsEmoji {
                        errorImpl?()
                        return
                    }
                    
                    let maskRightsFlags: TelegramChatAdminRightsFlags = .groupSpecific
                    let defaultFlags = maskRightsFlags.subtracting(.canAddAdmins)
                    
                    if updateFlags == nil {
                        updateFlags = defaultFlags
                    }
                    
                    if let updateFlags = updateFlags {
                        if initialParticipant?.adminInfo == nil && updateFlags == defaultFlags && updateRank == nil {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((addGroupAdmin(account: context.account, peerId: peerId, adminId: adminId)
                            |> deliverOnMainQueue).start(error: { error in
                                if case let .addMemberError(error) = error, case .privacy = error, let admin = adminView.peers[adminView.peerId] {
                                    presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(admin.compactDisplayTitle, admin.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                }
                                
                                dismissImpl?()
                            }, completed: {
                                dismissImpl?()
                            }))
                        } else if updateFlags != defaultFlags || updateRank != nil {
                            enum WrappedUpdateChannelAdminRightsError {
                                case direct(UpdateChannelAdminRightsError)
                                case conversionTooManyChannels
                                case conversionFailed
                            }
                            
                            let signal = convertGroupToSupergroup(account: context.account, peerId: peerId)
                            |> map(Optional.init)
                            |> `catch` { error -> Signal<PeerId?, WrappedUpdateChannelAdminRightsError> in
                                switch error {
                                case .tooManyChannels:
                                    return .fail(.conversionTooManyChannels)
                                default:
                                    return .fail(.conversionFailed)
                                }
                            }
                            |> mapToSignal { upgradedPeerId -> Signal<PeerId?, WrappedUpdateChannelAdminRightsError> in
                                guard let upgradedPeerId = upgradedPeerId else {
                                    return .fail(.conversionFailed)
                                }
                                return context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: upgradedPeerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: updateFlags), rank: updateRank)
                                |> mapError { error -> WrappedUpdateChannelAdminRightsError in
                                    return .direct(error)
                                }
                                |> mapToSignal { _ -> Signal<PeerId?, WrappedUpdateChannelAdminRightsError> in
                                    return .complete()
                                }
                                |> then(.single(upgradedPeerId))
                            }
                            |> deliverOnMainQueue
                            
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set(signal.start(next: { upgradedPeerId in
                                if let upgradedPeerId = upgradedPeerId {
                                    upgradedToSupergroup(upgradedPeerId, {
                                        dismissImpl?()
                                    })
                                }
                            }, error: { error in
                                updateState { current in
                                    return current.withUpdatedUpdating(false)
                                }
                                
                                switch error {
                                case let .direct(error):
                                    if case let .addMemberError(error) = error {
                                        var text = presentationData.strings.Login_UnknownError
                                        if case .restricted = error, let admin = adminView.peers[adminView.peerId] {
                                            text = presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(admin.compactDisplayTitle, admin.compactDisplayTitle).0
                                        } else if case .tooMuchJoined = error {
                                            text = presentationData.strings.Invite_ChannelsTooMuch
                                        }
                                        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                    }
                                case .conversionFailed, .conversionTooManyChannels:
                                    pushControllerImpl?(oldChannelsController(context: context, intent: .upgrade))
                                }
                                
                                dismissImpl?()
                            }))
                        } else {
                            dismissImpl?()
                        }
                    } else {
                        dismissImpl?()
                    }
                }
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(initialParticipant?.adminInfo == nil ? presentationData.strings.Channel_Management_AddModerator : presentationData.strings.Channel_Moderator_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelAdminControllerEntries(presentationData: presentationData, state: state, accountPeerId: context.account.peerId, channelView: channelView, adminView: adminView, initialParticipant: initialParticipant, canEdit: canEdit), style: .blocks, focusItemTag: focusItemTag, ensureVisibleItemTag: nil, emptyStateItem: nil, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.experimentalSnapScrollToItem = true
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window(.root), with: presentationArguments)
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    
    let hapticFeedback = HapticFeedback()
    errorImpl = { [weak controller] in
        hapticFeedback.error()
        controller?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListSingleLineInputItemNode {
                itemNode.animateError()
            }
        }
    }
    scrollToRankImpl = { [weak controller] in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            
            var resultItemNode: ListViewItemNode?
            let _ = controller.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListSingleLineInputItemNode {
                    if let tag = itemNode.tag as? ChannelAdminEntryTag, tag == .rank {
                        resultItemNode = itemNode
                        return true
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode)
            }
        })
    }
    
    return controller
}
