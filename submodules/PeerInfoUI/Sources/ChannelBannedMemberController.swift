import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import TelegramStringFormatting
import OverlayStatusController
import AccountContext
import AlertUI
import PresentationDataUtils
import ItemListAvatarAndNameInfoItem
import OldChannelsController

private let rankMaxLength: Int32 = 16

private final class ChannelBannedMemberControllerArguments {
    let context: AccountContext
    let toggleRight: (TelegramChatBannedRightsFlags, Bool) -> Void
    let toggleRightWhileDisabled: (TelegramChatBannedRightsFlags) -> Void
    let toggleIsOptionExpanded: (TelegramChatBannedRightsFlags) -> Void
    let openTimeout: () -> Void
    let delete: () -> Void
    let openPeer: () -> Void
    let updateRank: (String, String) -> Void
    let updateFocusedOnRank: (Bool) -> Void
    let dismissInput: () -> Void
    let animateError: () -> Void
    
    init(context: AccountContext, toggleRight: @escaping (TelegramChatBannedRightsFlags, Bool) -> Void, toggleRightWhileDisabled: @escaping (TelegramChatBannedRightsFlags) -> Void, toggleIsOptionExpanded: @escaping (TelegramChatBannedRightsFlags) -> Void, openTimeout: @escaping () -> Void, delete: @escaping () -> Void, openPeer: @escaping () -> Void, updateRank: @escaping (String, String) -> Void, updateFocusedOnRank: @escaping (Bool) -> Void, dismissInput: @escaping () -> Void, animateError: @escaping () -> Void) {
        self.context = context
        self.toggleRight = toggleRight
        self.toggleRightWhileDisabled = toggleRightWhileDisabled
        self.toggleIsOptionExpanded = toggleIsOptionExpanded
        self.openTimeout = openTimeout
        self.delete = delete
        self.openPeer = openPeer
        self.updateRank = updateRank
        self.updateFocusedOnRank = updateFocusedOnRank
        self.dismissInput = dismissInput
        self.animateError = animateError
    }
}

private enum ChannelBannedMemberSection: Int32 {
    case info
    case rights
    case timeout
    case delete
    case rank
}

private enum ChannelBannedMemberEntryTag: ItemListItemTag {
    case rank

    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? ChannelBannedMemberEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum ChannelBannedMemberEntryStableId: Hashable {
    case info
    case rightsHeader
    case right(TelegramChatBannedRightsFlags)
    case timeout
    case exceptionInfo
    case delete
    case rankTitle
    case rankPreview
    case rank
    case rankInfo
}

private enum ChannelBannedMemberEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, EnginePeer, EnginePeer.Presence?)
    case rightsHeader(PresentationTheme, String)
    case rightItem(PresentationTheme, Int, String, TelegramChatBannedRightsFlags, Bool, Bool, [SubPermission], Bool)
    case timeout(PresentationTheme, String, String)
    case exceptionInfo(PresentationTheme, String)
    case delete(PresentationTheme, String)
    case rankTitle(PresentationTheme, String, Int32?, Int32)
    case rankPreview(PresentationTheme, PresentationStrings, EnginePeer, String, Bool)
    case rank(PresentationTheme, PresentationStrings, String, String, Bool)
    case rankInfo(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return ChannelBannedMemberSection.info.rawValue
            case .rightsHeader, .rightItem:
                return ChannelBannedMemberSection.rights.rawValue
            case .timeout, .exceptionInfo:
                return ChannelBannedMemberSection.timeout.rawValue
            case .delete:
                return ChannelBannedMemberSection.delete.rawValue
            case .rankTitle, .rankPreview, .rank, .rankInfo:
                return ChannelBannedMemberSection.rank.rawValue
        }
    }
    
    var stableId: ChannelBannedMemberEntryStableId {
        switch self {
            case .info:
                return .info
            case .rightsHeader:
                return .rightsHeader
            case let .rightItem(_, _, _, right, _, _, _, _):
                return .right(right)
            case .timeout:
                return .timeout
            case .exceptionInfo:
                return .exceptionInfo
            case .delete:
                return .delete
            case .rankTitle:
                return .rankTitle
            case .rankPreview:
                return .rankPreview
            case .rank:
                return .rank
            case .rankInfo:
                return .rankInfo
        }
    }
    
    static func ==(lhs: ChannelBannedMemberEntry, rhs: ChannelBannedMemberEntry) -> Bool {
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
                    if lhsPeer != rhsPeer {
                        return false
                    }
                    if lhsPresence != rhsPresence {
                        return false
                    }
                    
                    return true
                } else {
                    return false
                }
            case let .rightsHeader(theme, title):
                if case .rightsHeader(theme, title) = rhs {
                    return true
                } else {
                    return false
                }
            case let .rightItem(lhsTheme, lhsIndex, lhsText, lhsRight, lhsValue, lhsEnabled, lhsSubItems, lhsIsExpanded):
                if case let .rightItem(rhsTheme, rhsIndex, rhsText, rhsRight, rhsValue, rhsEnabled, rhsSubItems, rhsIsExpanded) = rhs {
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
                    if lhsValue != rhsValue {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    if lhsSubItems != rhsSubItems {
                        return false
                    }
                    if lhsIsExpanded != rhsIsExpanded {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .timeout(lhsTheme, lhsText, lhsValue):
                if case let .timeout(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .exceptionInfo(theme, title):
                if case .exceptionInfo(theme, title) = rhs {
                    return true
                } else {
                    return false
                }
            case let .delete(theme, title):
                if case .delete(theme, title) = rhs {
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
            case let .rankPreview(lhsTheme, lhsStrings, lhsPeer, lhsRank, lhsIsOwner):
                if case let .rankPreview(rhsTheme, rhsStrings, rhsPeer, rhsRank, rhsIsOwner) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsPeer == rhsPeer, lhsRank == rhsRank, lhsIsOwner == rhsIsOwner {
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
            case let .rankInfo(lhsTheme, lhsText, lhsTrimBottomInset):
                if case let .rankInfo(rhsTheme, rhsText, rhsTrimBottomInset) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsTrimBottomInset == rhsTrimBottomInset {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelBannedMemberEntry, rhs: ChannelBannedMemberEntry) -> Bool {
        switch lhs {
        case .info:
            switch rhs {
            case .info:
                return false
            default:
                return true
            }
        case .rightsHeader:
            switch rhs {
            case .info, .rightsHeader:
                return false
            default:
                return true
            }
        case let .rightItem(_, lhsIndex, _, _, _, _, _, _):
            switch rhs {
            case .info, .rightsHeader:
                return false
            case let .rightItem(_, rhsIndex, _, _, _, _, _, _):
                return lhsIndex < rhsIndex
            default:
                return true
            }
        case .timeout:
            switch rhs {
            case .info, .rightsHeader, .rightItem, .timeout:
                return false
            default:
                return true
            }
        case .exceptionInfo:
            switch rhs {
            case .info, .rightsHeader, .rightItem, .timeout, .exceptionInfo:
                return false
            default:
                return true
            }
        case .delete:
            switch rhs {
            case .info, .rightsHeader, .rightItem, .timeout, .exceptionInfo, .delete:
                return false
            default:
                return true
            }
        case .rankTitle:
            switch rhs {
            case .info, .rightsHeader, .rightItem, .timeout, .delete, .rankTitle:
                return false
            default:
                return true
            }
        case .rankPreview:
            switch rhs {
            case .info, .rightsHeader, .rightItem, .timeout, .delete, .rankTitle, .rankPreview:
                return false
            default:
                return true
            }
            
        case .rank:
            switch rhs {
            case .info, .rightsHeader, .rightItem, .timeout, .delete, .rankTitle, .rankPreview, .rank:
                return false
            default:
                return true
            }
            
        case .rankInfo:
            switch rhs {
            case .info, .rightsHeader, .rightItem, .timeout, .delete, .rankTitle, .rankPreview, .rank, .rankInfo:
                return false
            default:
                return true
            }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelBannedMemberControllerArguments
        switch self {
            case let .info(_, _, dateTimeFormat, peer, presence):
                return ItemListAvatarAndNameInfoItem(itemContext: .accountContext(arguments.context), presentationData: presentationData, systemStyle: .glass, dateTimeFormat: dateTimeFormat, mode: .generic, peer: peer, presence: presence, memberCount: nil, state: ItemListAvatarAndNameInfoItemState(), sectionId: self.section, style: .blocks(withTopInset: true, withExtendedBottomInset: false), editingNameUpdated: { _ in
                }, avatarTapped: {
                }, action: {
                    arguments.openPeer()
                })
            case let .rightsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .rightItem(_, _, text, right, value, enabled, subPermissions, isExpanded):
                if !subPermissions.isEmpty {
                    return ItemListExpandableSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, isExpanded: isExpanded, subItems: subPermissions.map { item in
                        return ItemListExpandableSwitchItem.SubItem(
                            id: AnyHashable(item.flags.rawValue),
                            title: item.title,
                            isSelected: item.isSelected,
                            isEnabled: item.isEnabled
                        )
                    }, type: .icon, enableInteractiveChanges: enabled, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                        arguments.toggleRight(right, value)
                    }, activatedWhileDisabled: {
                        arguments.toggleRightWhileDisabled(right)
                    }, selectAction: {
                        arguments.toggleIsOptionExpanded(right)
                    }, subAction: { item in
                        guard let value = item.id.base as? Int32 else {
                            return
                        }
                        let subRights = TelegramChatBannedRightsFlags(rawValue: value)
                        
                        if item.isEnabled {
                            arguments.toggleRight(subRights, !item.isSelected)
                        } else {
                            arguments.toggleIsOptionExpanded(subRights)
                        }
                    })
                } else {
                    return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, type: .icon, enableInteractiveChanges: enabled, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                        arguments.toggleRight(right, value)
                    }, activatedWhileDisabled: {
                        arguments.toggleRightWhileDisabled(right)
                    })
                }
            case let .timeout(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openTimeout()
                })
            case let .exceptionInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .delete(_, text):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.delete()
                })
            case let .rankTitle(_, text, count, limit):
                var accessoryText: ItemListSectionHeaderAccessoryText?
                if let count = count {
                    accessoryText = ItemListSectionHeaderAccessoryText(value: "\(limit - count)", color: count > limit ? .destructive : .generic)
                }
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: accessoryText, sectionId: self.section)
            case let .rankPreview(_, _, peer, rank, _):
                let globalPresentationData = arguments.context.sharedContext.currentPresentationData.with { $0 }
                return arguments.context.sharedContext.makeChatRankPreviewItem(context: arguments.context, peer: peer, rank: rank, rankRole: .member, theme: presentationData.theme, strings: presentationData.strings, wallpaper: globalPresentationData.chatWallpaper, fontSize: globalPresentationData.chatFontSize, chatBubbleCorners: globalPresentationData.chatBubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder, sectionId: self.section)
            case let .rank(_, _, placeholder, text, enabled):
                return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "", textColor: .black), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: true), spacing: 0.0, clearType: enabled ? .always : .none, enabled: enabled, tag: ChannelBannedMemberEntryTag.rank, sectionId: self.section, textUpdated: { updatedText in
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
            case let .rankInfo(_, text, trimBottomInset):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section, additionalOuterInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: trimBottomInset ? -44.0 : 0.0, right: 0.0))
        }
    }
}

private struct ChannelBannedMemberControllerState: Equatable {
    var referenceTimestamp: Int32
    var updatedFlags: TelegramChatBannedRightsFlags?
    var updatedTimeout: Int32?
    var updating: Bool = false
    var expandedPermissions = Set<TelegramChatBannedRightsFlags>()
    var updatedRank: String?
    var focusedOnRank: Bool
}

func completeRights(_ flags: TelegramChatBannedRightsFlags) -> TelegramChatBannedRightsFlags {
    var result = flags
    result.remove(.banReadMessages)
    if result.contains(.banSendGifs) {
        result.insert(.banSendStickers)
        result.insert(.banSendGifs)
        result.insert(.banSendGames)
        result.insert(.banSendInline)
    } else {
        result.remove(.banSendStickers)
        result.remove(.banSendGifs)
        result.remove(.banSendGames)
        result.remove(.banSendInline)
    }
    return result
}

private func channelBannedMemberControllerEntries(presentationData: PresentationData, state: ChannelBannedMemberControllerState, accountPeerId: PeerId, channelPeer: EnginePeer?, memberPeer: EnginePeer?, memberPresence: EnginePeer.Presence?, initialParticipant: ChannelParticipant?, initialBannedBy: EnginePeer?, editMember: Bool) -> [ChannelBannedMemberEntry] {
    var entries: [ChannelBannedMemberEntry] = []
    
    if case let .channel(channel) = channelPeer, let defaultBannedRights = channel.defaultBannedRights, let member = memberPeer {
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, member, memberPresence))
            
        let currentRightsFlags: TelegramChatBannedRightsFlags
        if let updatedFlags = state.updatedFlags {
            currentRightsFlags = updatedFlags
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentRightsFlags = banInfo.rights.flags
        } else {
            currentRightsFlags = defaultBannedRights.flags
        }
        
        let currentTimeout: Int32
        if let updatedTimeout = state.updatedTimeout {
            currentTimeout = updatedTimeout
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentTimeout = banInfo.rights.untilDate
        } else {
            currentTimeout = Int32.max
        }
        
        let currentTimeoutString: String
        if currentTimeout == 0 || currentTimeout == Int32.max {
            currentTimeoutString = presentationData.strings.MessageTimer_Forever
        } else {
            let remainingTimeout = currentTimeout - state.referenceTimestamp
            currentTimeoutString = timeIntervalString(strings: presentationData.strings, value: remainingTimeout)
        }
        
        entries.append(.rightsHeader(presentationData.theme, presentationData.strings.GroupPermission_SectionTitle))
        
        var index = 0
        for (right, _) in allGroupPermissionList(peer: .channel(channel), expandMedia: false) {
            let defaultEnabled = !defaultBannedRights.flags.contains(right) && channel.hasPermission(.banMembers)
            
            var isSelected = defaultEnabled && !currentRightsFlags.contains(right)
            
            var subItems: [SubPermission] = []
            if right == .banSendMedia {
                isSelected = banSendMediaSubList().allSatisfy({ defaultEnabled && !currentRightsFlags.contains($0.0) })
                
                for (subRight, _) in banSendMediaSubList() {
                    let subItemEnabled = defaultEnabled && !state.updating && !defaultBannedRights.flags.contains(subRight) && channel.hasPermission(.banMembers)
                    
                    subItems.append(SubPermission(title: stringForGroupPermission(strings: presentationData.strings, right: subRight, isForum: channel.isForum), flags: subRight, isSelected: defaultEnabled && !currentRightsFlags.contains(subRight), isEnabled: subItemEnabled))
                }
            }
            
            entries.append(.rightItem(presentationData.theme, index, stringForGroupPermission(strings: presentationData.strings, right: right, isForum: channel.isForum), right, isSelected, defaultEnabled && !state.updating, subItems, state.expandedPermissions.contains(right)))
            index += 1
        }
        
        if editMember {
            let currentRank: String?
            if let updatedRank = state.updatedRank {
                currentRank = updatedRank
            } else if let initialParticipant = initialParticipant {
                currentRank = initialParticipant.rank
            } else {
                currentRank = nil
            }
            
            let rankEnabled = !state.updating
            entries.append(.rankTitle(presentationData.theme, presentationData.strings.Group_EditAdmin_MemberTagTitle.uppercased(), rankEnabled && state.focusedOnRank ? Int32(currentRank?.count ?? 0) : nil, rankMaxLength))
            entries.append(.rankPreview(presentationData.theme, presentationData.strings, member, currentRank ?? "0️⃣", false))
            entries.append(.rank(presentationData.theme, presentationData.strings, presentationData.strings.EditRank_Placeholder, currentRank ?? "", rankEnabled))
            entries.append(.rankInfo(presentationData.theme, presentationData.strings.Group_EditAdmin_MemberTagInfo(member.compactDisplayTitle).string, false))
        } else {
            entries.append(.timeout(presentationData.theme, presentationData.strings.GroupPermission_Duration, currentTimeoutString))
            
            if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo?, _, _) = initialParticipant, let initialBannedBy = initialBannedBy {
                entries.append(.exceptionInfo(presentationData.theme, presentationData.strings.GroupPermission_AddedInfo(initialBannedBy.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), stringForRelativeSymbolicTimestamp(strings: presentationData.strings, relativeTimestamp: banInfo.timestamp, relativeTo: state.referenceTimestamp, dateTimeFormat: presentationData.dateTimeFormat)).string))
                entries.append(.delete(presentationData.theme, presentationData.strings.GroupPermission_Delete))
            }
        }
    } else if case let .legacyGroup(group) = channelPeer, let member = memberPeer {
        let defaultBannedRightsFlags = group.defaultBannedRights?.flags ?? []
        
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, member, memberPresence))
        
        let currentRightsFlags: TelegramChatBannedRightsFlags
        if let updatedFlags = state.updatedFlags {
            currentRightsFlags = updatedFlags
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentRightsFlags = banInfo.rights.flags
        } else {
            currentRightsFlags = defaultBannedRightsFlags
        }
        
        let currentTimeout: Int32
        if let updatedTimeout = state.updatedTimeout {
            currentTimeout = updatedTimeout
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentTimeout = banInfo.rights.untilDate
        } else {
            currentTimeout = Int32.max
        }
        
        let currentTimeoutString: String
        if currentTimeout == 0 || currentTimeout == Int32.max {
            currentTimeoutString = presentationData.strings.MessageTimer_Forever
        } else {
            let remainingTimeout = currentTimeout - state.referenceTimestamp
            currentTimeoutString = timeIntervalString(strings: presentationData.strings, value: remainingTimeout)
        }
        
        entries.append(.rightsHeader(presentationData.theme, presentationData.strings.GroupPermission_SectionTitle))
        
        var index = 0
        for (right, _) in allGroupPermissionList(peer: .legacyGroup(group), expandMedia: false) {
            let defaultEnabled = !defaultBannedRightsFlags.contains(right)
            
            var isSelected = defaultEnabled && !currentRightsFlags.contains(right)
            
            var subItems: [SubPermission] = []
            if right == .banSendMedia {
                isSelected = banSendMediaSubList().allSatisfy({ defaultEnabled && !currentRightsFlags.contains($0.0) })
                
                for (subRight, _) in banSendMediaSubList() {
                    let subItemEnabled = defaultEnabled && !state.updating && !defaultBannedRightsFlags.contains(subRight)
                    
                    subItems.append(SubPermission(title: stringForGroupPermission(strings: presentationData.strings, right: subRight, isForum: false), flags: subRight, isSelected: defaultEnabled && !currentRightsFlags.contains(subRight), isEnabled: subItemEnabled))
                }
            }
            
            entries.append(.rightItem(presentationData.theme, index, stringForGroupPermission(strings: presentationData.strings, right: right, isForum: false), right, isSelected, defaultEnabled && !state.updating, subItems, state.expandedPermissions.contains(right)))
            index += 1
        }
        
        if editMember {
            let currentRank: String?
            if let updatedRank = state.updatedRank {
                currentRank = updatedRank
            } else if let initialParticipant = initialParticipant {
                currentRank = initialParticipant.rank
            } else {
                currentRank = nil
            }
            
            let rankEnabled = !state.updating
            entries.append(.rankTitle(presentationData.theme, presentationData.strings.Group_EditAdmin_MemberTagTitle.uppercased(), rankEnabled && state.focusedOnRank ? Int32(currentRank?.count ?? 0) : nil, rankMaxLength))
            entries.append(.rankPreview(presentationData.theme, presentationData.strings, member, currentRank ?? "0️⃣", false))
            entries.append(.rank(presentationData.theme, presentationData.strings, presentationData.strings.EditRank_Placeholder, currentRank ?? "", rankEnabled))
            entries.append(.rankInfo(presentationData.theme, presentationData.strings.Group_EditAdmin_MemberTagInfo(member.compactDisplayTitle).string, false))
            
        } else {
            entries.append(.timeout(presentationData.theme, presentationData.strings.GroupPermission_Duration, currentTimeoutString))
            
            if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo?, _, _) = initialParticipant, let initialBannedBy = initialBannedBy {
                entries.append(.exceptionInfo(presentationData.theme, presentationData.strings.GroupPermission_AddedInfo(initialBannedBy.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), stringForRelativeSymbolicTimestamp(strings: presentationData.strings, relativeTimestamp: banInfo.timestamp, relativeTo: state.referenceTimestamp, dateTimeFormat: presentationData.dateTimeFormat)).string))
                entries.append(.delete(presentationData.theme, presentationData.strings.GroupPermission_Delete))
            }
        }
    }
    
    return entries
}

public func channelBannedMemberController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, memberId: PeerId, editMember: Bool = false, initialParticipant: ChannelParticipant?, updated: @escaping (TelegramChatBannedRights?) -> Void, upgradedToSupergroup: @escaping (PeerId, @escaping () -> Void) -> Void) -> ViewController {
    let initialState = ChannelBannedMemberControllerState(referenceTimestamp: Int32(Date().timeIntervalSince1970), updatedFlags: nil, updatedTimeout: nil, updating: false, updatedRank: nil, focusedOnRank: false)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChannelBannedMemberControllerState) -> ChannelBannedMemberControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let updateRightsDisposable = MetaDisposable()
    actionsDisposable.add(updateRightsDisposable)
    
    let updateRankDisposable = MetaDisposable()
    actionsDisposable.add(updateRankDisposable)
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissInputImpl: (() -> Void)?
    var errorImpl: (() -> Void)?
    var scrollToRankImpl: (() -> Void)?
    
    let peerView = Promise<PeerView>()
    peerView.set(context.account.viewTracker.peerView(peerId))
    
    let arguments = ChannelBannedMemberControllerArguments(context: context, toggleRight: { rights, value in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            var defaultBannedRightsFlagsValue: TelegramChatBannedRightsFlags?
            guard let peer = view.peers[peerId] else {
                return
            }
            if let channel = peer as? TelegramChannel, let initialRightFlags = channel.defaultBannedRights?.flags {
                defaultBannedRightsFlagsValue = initialRightFlags
            } else if let group = peer as? TelegramGroup, let initialRightFlags = group.defaultBannedRights?.flags {
                defaultBannedRightsFlagsValue = initialRightFlags
            }
            guard let defaultBannedRightsFlags = defaultBannedRightsFlagsValue else {
                return
            }
            
            updateState { state in
                var state = state
                var effectiveRightsFlags: TelegramChatBannedRightsFlags
                if let updatedFlags = state.updatedFlags {
                    effectiveRightsFlags = updatedFlags
                } else if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo?, _, _) = initialParticipant {
                    effectiveRightsFlags = banInfo.rights.flags
                } else {
                    effectiveRightsFlags = defaultBannedRightsFlags
                }
                                
                if rights == .banSendMedia {
                    if value {
                        effectiveRightsFlags.remove(rights)
                        for item in banSendMediaSubList() {
                            effectiveRightsFlags.remove(item.0)
                        }
                    } else {
                        effectiveRightsFlags.insert(rights)
                        for (right, _) in allGroupPermissionList(peer: EnginePeer(peer), expandMedia: false) {
                            if groupPermissionDependencies(right).contains(rights) {
                                effectiveRightsFlags.insert(right)
                            }
                        }
                        
                        for item in banSendMediaSubList() {
                            effectiveRightsFlags.insert(item.0)
                            for (right, _) in allGroupPermissionList(peer: EnginePeer(peer), expandMedia: false) {
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
                        for (right, _) in allGroupPermissionList(peer: EnginePeer(peer), expandMedia: false) {
                            if groupPermissionDependencies(right).contains(rights) {
                                effectiveRightsFlags.insert(right)
                            }
                        }
                    }
                }
                state.updatedFlags = effectiveRightsFlags
                return state
            }
        })
    }, toggleRightWhileDisabled: { right in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            guard let channel = view.peers[view.peerId] as? TelegramChannel else {
                return
            }
            guard let defaultBannedRights = channel.defaultBannedRights else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let text: String
            if channel.hasPermission(.banMembers) {
                if defaultBannedRights.flags.contains(right) {
                    text = presentationData.strings.GroupPermission_PermissionDisabledByDefault
                } else {
                    text = presentationData.strings.GroupPermission_PermissionGloballyDisabled
                }
            } else {
                text = presentationData.strings.GroupPermission_EditingDisabled
            }
            presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
        })
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
    }, openTimeout: {
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        let intervals: [Int32] = [
            1 * 60 * 60 * 24,
            7 * 60 * 60 * 24,
            30 * 60 * 60 * 24
        ]
        let applyValue: (Int32?) -> Void = { value in
            updateState { state in
                var state = state
                state.updatedTimeout = value
                return state
            }
        }
        var items: [ActionSheetItem] = []
        for interval in intervals {
            items.append(ActionSheetButtonItem(title: timeIntervalString(strings: presentationData.strings, value: interval), color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                applyValue(initialState.referenceTimestamp + interval)
            }))
        }
        items.append(ActionSheetButtonItem(title: presentationData.strings.MessageTimer_Forever, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            applyValue(Int32.max)
        }))
        items.append(ActionSheetButtonItem(title: presentationData.strings.MessageTimer_Custom, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            presentControllerImpl?(PeerBanTimeoutController(context: context, updatedPresentationData: updatedPresentationData, currentValue: Int32(Date().timeIntervalSince1970), applyValue: { value in
                applyValue(value)
            }), nil)
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }, delete: {
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        items.append(ActionSheetButtonItem(title: presentationData.strings.GroupPermission_Delete, color: .destructive, font: .default, enabled: true, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            updateState { state in
                var state = state
                state.updating = true
                return state
            }
            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: memberId, bannedRights: nil)
                |> deliverOnMainQueue).start(error: { _ in
                    
                }, completed: {
                    updated(nil)
                    dismissImpl?()
                }))
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }, openPeer: {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: memberId))
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer else {
                return
            }
            if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: updatedPresentationData, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                pushControllerImpl?(controller)
            }
        })
    }, updateRank: { previousRank, updatedRank in
        if updatedRank != previousRank {
            updateState { state in
                var state = state
                state.updatedRank = updatedRank
                return state
            }
        }
    }, updateFocusedOnRank: { focusedOnRank in
        updateState { state in
            var state = state
            state.focusedOnRank = focusedOnRank
            return state
        }
        
        if focusedOnRank {
            scrollToRankImpl?()
        }
    }, dismissInput: {
        dismissInputImpl?()
    }, animateError: {
        errorImpl?()
    })
    
    var peerDataItems: [TelegramEngine.EngineData.Item.Peer.Peer] = []
    peerDataItems.append(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    peerDataItems.append(TelegramEngine.EngineData.Item.Peer.Peer(id: memberId))
    if let banInfo = initialParticipant?.banInfo {
        peerDataItems.append(TelegramEngine.EngineData.Item.Peer.Peer(id: banInfo.restrictedBy))
    }
    
    let peersMap = context.engine.data.subscribe(
        EngineDataMap(peerDataItems),
        TelegramEngine.EngineData.Item.Peer.Presence(id: memberId)
    )
    
    let canEdit = true
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(presentationData, statePromise.get(), peersMap)
    |> deliverOnMainQueue
    |> map { presentationData, state, peersMap -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let channelPeer = peersMap.0[peerId].flatMap { $0 }
        let memberPeer = peersMap.0[memberId].flatMap { $0 }
        var initialBannedByPeer: EnginePeer?
        if let banInfo = initialParticipant?.banInfo {
            initialBannedByPeer = peersMap.0[banInfo.restrictedBy].flatMap { $0 }
        }
        let memberPresence = peersMap.1
        
        var footerButtonTitle: String = presentationData.strings.GroupPermission_SaveChanges

        let rightButtonActionImpl = {
            let _ = (peerView.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { view in
                var defaultBannedRightsFlagsValue: TelegramChatBannedRightsFlags?
                guard let peer = view.peers[peerId] else {
                    return
                }
                if let channel = peer as? TelegramChannel, let initialRightFlags = channel.defaultBannedRights?.flags {
                    defaultBannedRightsFlagsValue = initialRightFlags
                } else if let group = peer as? TelegramGroup, let initialRightFlags = group.defaultBannedRights?.flags {
                    defaultBannedRightsFlagsValue = initialRightFlags
                }
                guard let defaultBannedRightsFlags = defaultBannedRightsFlagsValue else {
                    return
                }
                
                var updateRank: String?
                updateState { current in
                    updateRank = current.updatedRank?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return current
                }
                if let updateRank = updateRank, updateRank.count > rankMaxLength || updateRank.containsEmoji {
                    errorImpl?()
                    return
                }
                
                var resolvedRights: TelegramChatBannedRights?
                if let initialParticipant = initialParticipant {
                    var updateFlags: TelegramChatBannedRightsFlags?
                    var updateTimeout: Int32?
                    updateState { current in
                        updateFlags = current.updatedFlags
                        updateTimeout = current.updatedTimeout
                        return current
                    }
                    
                    if updateFlags == nil && updateTimeout == nil && !editMember {
                        if case let .member(_, _, _, maybeBanInfo, _, _) = initialParticipant {
                            if maybeBanInfo == nil {
                                updateFlags = defaultBannedRightsFlags
                                updateTimeout = Int32.max
                            }
                        }
                    }
                    
                    if updateFlags != nil || updateTimeout != nil {
                        let currentRightsFlags: TelegramChatBannedRightsFlags
                        if let updatedFlags = updateFlags {
                            currentRightsFlags = updatedFlags
                        } else if case let .member(_, _, _, maybeBanInfo, _, _) = initialParticipant, let banInfo = maybeBanInfo {
                            currentRightsFlags = banInfo.rights.flags
                        } else {
                            currentRightsFlags = defaultBannedRightsFlags
                        }
                        
                        let currentTimeout: Int32
                        if let updateTimeout = updateTimeout {
                            currentTimeout = updateTimeout
                        } else if case let .member(_, _, _, maybeBanInfo, _, _) = initialParticipant, let banInfo = maybeBanInfo {
                            currentTimeout = banInfo.rights.untilDate
                        } else {
                            currentTimeout = Int32.max
                        }
                        
                        resolvedRights = TelegramChatBannedRights(flags: completeRights(currentRightsFlags), untilDate: currentTimeout)
                    }
                } else if canEdit, case .channel = channelPeer {
                    var updateFlags: TelegramChatBannedRightsFlags?
                    var updateTimeout: Int32?
                    updateState { state in
                        var state = state
                        updateFlags = state.updatedFlags
                        updateTimeout = state.updatedTimeout
                        state.updating = false
                        return state
                    }
                    
                    if updateFlags == nil {
                        updateFlags = defaultBannedRightsFlags
                    }
                    if updateTimeout == nil {
                        updateTimeout = Int32.max
                    }
                    
                    if let updateFlags = updateFlags, let updateTimeout = updateTimeout {
                       resolvedRights = TelegramChatBannedRights(flags: completeRights(updateFlags), untilDate: updateTimeout)
                    }
                }
                
                var previousRights: TelegramChatBannedRights?
                if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo, _, _) = initialParticipant, banInfo != nil {
                    previousRights = banInfo?.rights
                }
                
                let updateRankSignal: (PeerId) -> Signal<Void, NoError>
                if let updateRank {
                    updateRankSignal = { peerId in
                        return context.peerChannelMemberCategoriesContextsManager.updateMemberRank(engine: context.engine, peerId: peerId, memberId: memberId, rank: updateRank)
                        |> `catch` { _ -> Signal<Void, NoError> in
                            return .single(Void())
                        }
                    }
                } else {
                    updateRankSignal = { _ in return .complete() }
                }
                
                if let resolvedRights = resolvedRights, previousRights != resolvedRights {
                    let cleanResolvedRightsFlags = resolvedRights.flags.union(defaultBannedRightsFlags)
                    let cleanResolvedRights = TelegramChatBannedRights(flags: cleanResolvedRightsFlags, untilDate: resolvedRights.untilDate)
                     
                    if cleanResolvedRights.flags.isEmpty && previousRights == nil {
                        updateRankDisposable.set((updateRankSignal(peerId)
                        |> deliverOnMainQueue).start(completed: {
                            dismissImpl?()
                        }))
                    } else {
                        let applyRights: () -> Void = {
                            updateState { state in
                                var state = state
                                state.updating = true
                                return state
                            }
                            
                            if peerId.namespace == Namespaces.Peer.CloudGroup {
                                let signal = context.engine.peers.convertGroupToSupergroup(peerId: peerId)
                                |> map(Optional.init)
                                |> `catch` { error -> Signal<PeerId?, NoError> in
                                    switch error {
                                    case .tooManyChannels:
                                        Queue.mainQueue().async {
                                            pushControllerImpl?(oldChannelsController(context: context, updatedPresentationData: updatedPresentationData, intent: .upgrade))
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
                                    
                                    let rankSignal = updateRankSignal(upgradedPeerId)
                                    
                                    return context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: upgradedPeerId, memberId: memberId, bannedRights: cleanResolvedRights)
                                    |> mapToSignal { _ -> Signal<PeerId?, NoError> in
                                        return rankSignal
                                        |> mapToSignal { _ -> Signal<PeerId?, NoError> in
                                            return .complete()
                                        }
                                    }
                                    |> then(.single(upgradedPeerId))
                                }
                                |> deliverOnMainQueue
                                
                                updateState { current in
                                    var current = current
                                    current.updating = true
                                    return current
                                }
                                updateRightsDisposable.set(signal.start(next: { upgradedPeerId in
                                    if let upgradedPeerId = upgradedPeerId {
                                        upgradedToSupergroup(upgradedPeerId, {
                                            dismissImpl?()
                                        })
                                    } else {
                                        updateState { current in
                                            var current = current
                                            current.updating = false
                                            return current
                                        }
                                    }
                                }, error: { _ in
                                }))
                            } else {
                                updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: memberId, bannedRights: cleanResolvedRights)
                                |> deliverOnMainQueue).start(error: { _ in
                                    
                                }, completed: {
                                    if previousRights == nil, !editMember {
                                        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                                        presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.GroupPermission_AddSuccess, false)), nil)
                                    }
                                    updated(cleanResolvedRights.flags.isEmpty ? nil : cleanResolvedRights)
                                    dismissImpl?()
                                }))
                                
                                updateRankDisposable.set(updateRankSignal(peerId).start())
                            }
                        }
                        
                        applyRights()
                    }
                } else {
                    updateRankDisposable.set((updateRankSignal(peerId)
                    |> deliverOnMainQueue).start(completed: {
                        dismissImpl?()
                    }))
                }
            })
        }

        let title: String
        if editMember {
            title = presentationData.strings.GroupPermission_Member
        } else {
            if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo, _, _) = initialParticipant, banInfo != nil {
                title = presentationData.strings.GroupPermission_Title
            } else {
                title = presentationData.strings.GroupPermission_NewTitle
                footerButtonTitle = presentationData.strings.GroupPermission_AddException
            }
        }
        
        let rightNavigationButton: ItemListNavigationButton?
        let footerItem: ItemListControllerFooterItem?
        if state.focusedOnRank {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                rightButtonActionImpl()
            })
            footerItem = nil
        } else {
            rightNavigationButton = nil
            footerItem = ChannelParticipantFooterItem(theme: presentationData.theme, title: footerButtonTitle, displayProgress: state.updating, action: {
                rightButtonActionImpl()
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelBannedMemberControllerEntries(presentationData: presentationData, state: state, accountPeerId: context.account.peerId, channelPeer: channelPeer, memberPeer: memberPeer, memberPresence: memberPresence, initialParticipant: initialParticipant, initialBannedBy: initialBannedByPeer, editMember: editMember), style: .blocks, emptyStateItem: nil, footerItem: footerItem, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    dismissImpl = { [weak controller] in
        controller?.dismiss()
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
                    if let tag = itemNode.tag as? ChannelBannedMemberEntryTag, tag == .rank {
                        resultItemNode = itemNode
                        return true
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                Queue.mainQueue().after(0.1) {
                    controller.ensureItemNodeVisible(resultItemNode, atTop: true)
                }
            }
        })
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    return controller
}
