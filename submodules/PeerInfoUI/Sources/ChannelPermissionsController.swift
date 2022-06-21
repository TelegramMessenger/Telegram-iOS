import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
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

private final class ChannelPermissionsControllerArguments {
    let context: AccountContext
    
    let updatePermission: (TelegramChatBannedRightsFlags, Bool) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let addPeer: () -> Void
    let removePeer: (PeerId) -> Void
    let openPeer: (ChannelParticipant) -> Void
    let openPeerInfo: (Peer) -> Void
    let openKicked: () -> Void
    let presentRestrictedPermissionAlert: (TelegramChatBannedRightsFlags) -> Void
    let presentConversionToBroadcastGroup: () -> Void
    let openChannelExample: () -> Void
    let updateSlowmode: (Int32) -> Void
    
    init(context: AccountContext, updatePermission: @escaping (TelegramChatBannedRightsFlags, Bool) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addPeer: @escaping  () -> Void, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping (ChannelParticipant) -> Void, openPeerInfo: @escaping (Peer) -> Void, openKicked: @escaping () -> Void, presentRestrictedPermissionAlert: @escaping (TelegramChatBannedRightsFlags) -> Void, presentConversionToBroadcastGroup: @escaping () -> Void, openChannelExample: @escaping () -> Void, updateSlowmode: @escaping (Int32) -> Void) {
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
    }
}

private enum ChannelPermissionsSection: Int32 {
    case permissions
    case slowmode
    case conversion
    case kicked
    case exceptions
}

private enum ChannelPermissionsEntryStableId: Hashable {
    case index(Int)
    case peer(PeerId)
}

private enum ChannelPermissionsEntry: ItemListNodeEntry {
    case permissionsHeader(PresentationTheme, String)
    case permission(PresentationTheme, Int, String, Bool, TelegramChatBannedRightsFlags, Bool?)
    case slowmodeHeader(PresentationTheme, String)
    case slowmode(PresentationTheme, PresentationStrings, Int32)
    case slowmodeInfo(PresentationTheme, String)
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
            case let .permission(_, index, _, _, _, _):
                return .index(1 + index)
            case .conversionHeader:
                return .index(998)
            case .conversion:
                return .index(999)
            case .conversionInfo:
                return .index(1000)
            case .slowmodeHeader:
                return .index(1001)
            case .slowmode:
                return .index(1002)
            case .slowmodeInfo:
                return .index(1003)
            case .kicked:
                return .index(1004)
            case .exceptionsHeader:
                return .index(1005)
            case .add:
                return .index(1006)
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
            case let .permission(theme, index, title, value, rights, enabled):
                if case .permission(theme, index, title, value, rights, enabled) = rhs {
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
            case let .permission(_, _, title, value, rights, enabled):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, type: .icon, enableInteractiveChanges: enabled != nil, enabled: enabled ?? true, sectionId: self.section, style: .blocks, updated: { value in
                    if let _ = enabled {
                        arguments.updatePermission(rights, value)
                    } else {
                        arguments.presentRestrictedPermissionAlert(rights)
                    }
                }, activatedWhileDisabled: {
                    arguments.presentRestrictedPermissionAlert(rights)
                })
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
                    case let .member(_, _, _, banInfo, _):
                        var exceptionsString = ""
                        if let banInfo = banInfo {
                            for (rights, _) in allGroupPermissionList {
                                if !defaultBannedRights.contains(rights) && banInfo.rights.flags.contains(rights) {
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
                    arguments.openPeerInfo(participant.peer)
                }, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
        }
    }
}

private struct ChannelPermissionsControllerState: Equatable {
    var peerIdWithRevealedOptions: PeerId?
    var removingPeerId: PeerId?
    var searchingMembers: Bool = false
    var modifiedRightsFlags: TelegramChatBannedRightsFlags?
    var modifiedSlowmodeTimeout: Int32?
}

func stringForGroupPermission(strings: PresentationStrings, right: TelegramChatBannedRightsFlags) -> String {
    if right.contains(.banSendMessages) {
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
    } else {
        return ""
    }
}

func compactStringForGroupPermission(strings: PresentationStrings, right: TelegramChatBannedRightsFlags) -> String {
    if right.contains(.banSendMessages) {
        return strings.GroupPermission_NoSendMessages
    } else if right.contains(.banSendMedia) {
        return strings.GroupPermission_NoSendMedia
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
    } else {
        return ""
    }
}

public let allGroupPermissionList: [(TelegramChatBannedRightsFlags, TelegramChannelPermission)] = [
    (.banSendMessages, .banMembers),
    (.banSendMedia, .banMembers),
    (.banSendGifs, .banMembers),
    (.banEmbedLinks, .banMembers),
    (.banSendPolls, .banMembers),
    (.banAddMembers, .banMembers),
    (.banPinMessages, .pinMessages),
    (.banChangeInfo, .changeInfo)
]

let publicGroupRestrictedPermissions: TelegramChatBannedRightsFlags = [
    .banPinMessages,
    .banChangeInfo
]

func groupPermissionDependencies(_ right: TelegramChatBannedRightsFlags) -> TelegramChatBannedRightsFlags {
    if right.contains(.banSendMedia) {
        return [.banSendMessages]
    } else if right.contains(.banSendGifs) {
        return [.banSendMessages]
    } else if right.contains(.banEmbedLinks) {
        return [.banSendMessages]
    } else if right.contains(.banSendPolls) {
        return [.banSendMessages]
    } else if right.contains(.banChangeInfo) {
        return []
    } else if right.contains(.banAddMembers) {
        return []
    } else if right.contains(.banPinMessages) {
        return []
    } else {
        return []
    }
}

private func channelPermissionsControllerEntries(context: AccountContext, presentationData: PresentationData, view: PeerView, state: ChannelPermissionsControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelPermissionsEntry] {
    var entries: [ChannelPermissionsEntry] = []
    
    if let channel = view.peers[view.peerId] as? TelegramChannel, let participants = participants, let cachedData = view.cachedData as? CachedChannelData, let defaultBannedRights = channel.defaultBannedRights {
        let effectiveRightsFlags: TelegramChatBannedRightsFlags
        if let modifiedRightsFlags = state.modifiedRightsFlags {
            effectiveRightsFlags = modifiedRightsFlags
        } else {
            effectiveRightsFlags = defaultBannedRights.flags
        }
        
        entries.append(.permissionsHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_SectionTitle))
        var rightIndex: Int = 0
        for (rights, correspondingAdminRight) in allGroupPermissionList {
            var enabled: Bool? = true
            if channel.addressName != nil && publicGroupRestrictedPermissions.contains(rights) {
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
            entries.append(.permission(presentationData.theme, rightIndex, stringForGroupPermission(strings: presentationData.strings, right: rights), !effectiveRightsFlags.contains(rights), rights, enabled))
            rightIndex += 1
        }
        
        let participantsLimit = context.currentLimitsConfiguration.with { $0 }.maxSupergroupMemberCount
        if channel.flags.contains(.isCreator) && !channel.flags.contains(.isGigagroup), let memberCount = cachedData.participantsSummary.memberCount, memberCount > participantsLimit - 1000 {
            entries.append(.conversionHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_BroadcastTitle.uppercased()))
            entries.append(.conversion(presentationData.theme, presentationData.strings.GroupInfo_Permissions_BroadcastConvert))
            entries.append(.conversionInfo(presentationData.theme, presentationData.strings.GroupInfo_Permissions_BroadcastConvertInfo(presentationStringsFormattedNumber(participantsLimit, presentationData.dateTimeFormat.groupingSeparator)).string))
        }
        
        entries.append(.slowmodeHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_SlowmodeHeader))
        entries.append(.slowmode(presentationData.theme, presentationData.strings, state.modifiedSlowmodeTimeout ?? (cachedData.slowModeTimeout ?? 0)))
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
        for (rights, _) in allGroupPermissionList {
            entries.append(.permission(presentationData.theme, rightIndex, stringForGroupPermission(strings: presentationData.strings, right: rights), !effectiveRightsFlags.contains(rights), rights, true))
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

public func channelPermissionsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId originalPeerId: PeerId, loadCompleted: @escaping () -> Void = {}) -> ViewController {
    let statePromise = ValuePromise(ChannelPermissionsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelPermissionsControllerState())
    let updateState: ((ChannelPermissionsControllerState) -> ChannelPermissionsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var navigateToChatControllerImpl: ((PeerId) -> Void)?
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
    
    let sourcePeerId = Promise<(PeerId, Bool)>((originalPeerId, false))
    
    let peersDisposable = MetaDisposable()
    let loadMoreControl = Atomic<PeerChannelMemberCategoryControl?>(value: nil)
    
    let peersPromise = Promise<(PeerId, [RenderedChannelParticipant]?)>()
    
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
    
    let peerView = Promise<PeerView>()
    peerView.set(sourcePeerId.get()
    |> mapToSignal(context.account.viewTracker.peerView))
    
    var upgradedToSupergroupImpl: ((PeerId, @escaping () -> Void) -> Void)?
    
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
                    if value {
                        effectiveRightsFlags.remove(rights)
                        effectiveRightsFlags = effectiveRightsFlags.subtracting(groupPermissionDependencies(rights))
                    } else {
                        effectiveRightsFlags.insert(rights)
                        for (right, _) in allGroupPermissionList {
                            if groupPermissionDependencies(right).contains(rights) {
                                effectiveRightsFlags.insert(right)
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
                    if value {
                        effectiveRightsFlags.remove(rights)
                        effectiveRightsFlags = effectiveRightsFlags.subtracting(groupPermissionDependencies(rights))
                    } else {
                        effectiveRightsFlags.insert(rights)
                        for (right, _) in allGroupPermissionList {
                            if groupPermissionDependencies(right).contains(rights) {
                                effectiveRightsFlags.insert(right)
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
            let controller = ChannelMembersSearchController(context: context, peerId: peerId, mode: .ban, openPeer: { peer, participant in
                if let participant = participant {
                    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                    switch participant.participant {
                        case .creator:
                            return
                        case let .member(_, _, adminInfo, _, _):
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
        if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
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
            for (listRight, permission) in allGroupPermissionList {
                if listRight == right {
                    let text: String
                    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                    if !channel.hasPermission(permission) {
                        text = presentationData.strings.GroupInfo_Permissions_EditingDisabled
                    } else if right.contains(.banAddMembers) {
                        text = presentationData.strings.GroupPermission_AddMembersNotAvailable
                    } else {
                        text = presentationData.strings.GroupPermission_NotAvailableInPublicGroups
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
            let attributedTitle = NSAttributedString(string: presentationData.strings.BroadcastGroups_ConfirmationAlert_Title, font: Font.medium(17.0), textColor: presentationData.theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
            let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
            let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
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
        resolveDisposable.set((context.engine.peers.resolvePeerByName(name: "durov") |> deliverOnMainQueue).start(next: { peer in
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
                |> mapToSignal { upgradedPeerId -> Signal<PeerId?, UpdateChannelSlowModeError> in
                    return context.engine.peers.updateChannelSlowModeInteractively(peerId: upgradedPeerId, timeout: modifiedSlowmodeTimeout == 0 ? nil : value)
                    |> mapToSignal { _ -> Signal<PeerId?, UpdateChannelSlowModeError> in
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
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.GroupInfo_Permissions_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelPermissionsControllerEntries(context: context, presentationData: presentationData, view: view, state: state, participants: participants), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, animateChanges: previous != nil && participants != nil && previous!.count >= participants!.count)
        
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
        if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId), keepStack: .always))
        }
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
