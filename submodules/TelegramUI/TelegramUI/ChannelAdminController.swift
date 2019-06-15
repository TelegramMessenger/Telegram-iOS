import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChannelAdminControllerArguments {
    let account: Account
    let toggleRight: (TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags) -> Void
    let transferOwnership: () -> Void
    let dismissAdmin: () -> Void
    
    init(account: Account, toggleRight: @escaping (TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags) -> Void, transferOwnership: @escaping () -> Void, dismissAdmin: @escaping () -> Void) {
        self.account = account
        self.toggleRight = toggleRight
        self.transferOwnership = transferOwnership
        self.dismissAdmin = dismissAdmin
    }
}

private enum ChannelAdminSection: Int32 {
    case info
    case rights
    case transfer
    case dismiss
}

private enum ChannelAdminEntryStableId: Hashable {
    case info
    case rightsTitle
    case right(TelegramChatAdminRightsFlags)
    case addAdminsInfo
    case transfer
    case dismiss
    
    var hashValue: Int {
        switch self {
            case .info:
                return 0
            case .rightsTitle:
                return 1
            case .addAdminsInfo:
                return 2
            case .dismiss:
                return 3
            case .transfer:
                return 4
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
    case rightsTitle(PresentationTheme, String)
    case rightItem(PresentationTheme, Int, String, TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags, Bool, Bool)
    case addAdminsInfo(PresentationTheme, String)
    case transfer(PresentationTheme, String)
    case dismiss(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return ChannelAdminSection.info.rawValue
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
            case .dismiss:
                return false
        }
    }
    
    func item(_ arguments: ChannelAdminControllerArguments) -> ListViewItem {
        switch self {
            case let .info(theme, strings, dateTimeFormat, peer, presence):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, mode: .generic, peer: peer, presence: presence, cachedData: nil, state: ItemListAvatarAndNameInfoItemState(), sectionId: self.section, style: .blocks(withTopInset: true), editingNameUpdated: { _ in
                }, avatarTapped: {
                })
            case let .rightsTitle(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .rightItem(theme, _, text, right, flags, value, enabled):
                return ItemListSwitchItem(theme: theme, title: text, value: value, type: .icon, enabled: enabled, sectionId: self.section, style: .blocks, updated: { _ in
                    arguments.toggleRight(right, flags)
                })
            case let .addAdminsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .transfer(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.transferOwnership()
                }, tag: nil)
            case let .dismiss(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.dismissAdmin()
                }, tag: nil)
        }
    }
}

private struct ChannelAdminControllerState: Equatable {
    let updatedFlags: TelegramChatAdminRightsFlags?
    let updating: Bool
    
    init(updatedFlags: TelegramChatAdminRightsFlags? = nil, updating: Bool = false) {
        self.updatedFlags = updatedFlags
        self.updating = updating
    }
    
    static func ==(lhs: ChannelAdminControllerState, rhs: ChannelAdminControllerState) -> Bool {
        if lhs.updatedFlags != rhs.updatedFlags {
            return false
        }
        if lhs.updating != rhs.updating {
            return false
        }
        return true
    }
    
    func withUpdatedUpdatedFlags(_ updatedFlags: TelegramChatAdminRightsFlags?) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: updatedFlags, updating: self.updating)
    }
    
    func withUpdatedUpdating(_ updating: Bool) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: self.updatedFlags, updating: updating)
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
        return strings.Channel_EditAdmin_PermissionDeleteMessages
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

private func canEditAdminRights(accountPeerId: PeerId, channelView: PeerView, initialParticipant: ChannelParticipant?) -> Bool {
    if let channel = channelView.peers[channelView.peerId] as? TelegramChannel {
        if channel.flags.contains(.isCreator) {
            return true
        } else if let initialParticipant = initialParticipant {
            switch initialParticipant {
                case .creator:
                    return false
                case let .member(_, _, adminInfo, _):
                    if let adminInfo = adminInfo {
                        return adminInfo.canBeEditedByAccountPeer || adminInfo.promotedBy == accountPeerId
                    } else {
                        return channel.hasPermission(.addAdmins)
                    }
            }
        } else {
            return channel.hasPermission(.addAdmins)
        }
    } else if let group = channelView.peers[channelView.peerId] as? TelegramGroup {
        if case .creator = group.role {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}

private func areAllAdminRightsEnabled(_ flags: TelegramChatAdminRightsFlags, group: Bool) -> Bool {
    if group {
        return TelegramChatAdminRightsFlags.groupSpecific.intersection(flags) == TelegramChatAdminRightsFlags.groupSpecific
    } else {
        return TelegramChatAdminRightsFlags.broadcastSpecific.intersection(flags) == TelegramChatAdminRightsFlags.broadcastSpecific
    }
}

private func channelAdminControllerEntries(presentationData: PresentationData, state: ChannelAdminControllerState, accountPeerId: PeerId, channelView: PeerView, adminView: PeerView, initialParticipant: ChannelParticipant?) -> [ChannelAdminEntry] {
    var entries: [ChannelAdminEntry] = []
    
    if let channel = channelView.peers[channelView.peerId] as? TelegramChannel, let admin = adminView.peers[adminView.peerId] {
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, admin, adminView.peerPresences[admin.id] as? TelegramUserPresence))
        
        entries.append(.rightsTitle(presentationData.theme, presentationData.strings.Channel_EditAdmin_PermissionsHeader))
        
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
        
        if canEditAdminRights(accountPeerId: accountPeerId, channelView: channelView, initialParticipant: initialParticipant) {
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
            } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminRights, _) = initialParticipant, let adminRights = maybeAdminRights {
                currentRightsFlags = adminRights.rights.flags
            } else {
                currentRightsFlags = accountUserRightsFlags.subtracting(.canAddAdmins)
            }
            
            var index = 0
            for right in rightsOrder {
                if accountUserRightsFlags.contains(right) {
                    entries.append(.rightItem(presentationData.theme, index, stringForRight(strings: presentationData.strings, right: right, isGroup: isGroup, defaultBannedRights: channel.defaultBannedRights), right, currentRightsFlags, currentRightsFlags.contains(right), !state.updating))
                    index += 1
                }
            }
            
            if accountUserRightsFlags.contains(.canAddAdmins) {
                entries.append(.addAdminsInfo(presentationData.theme, currentRightsFlags.contains(.canAddAdmins) ? presentationData.strings.Channel_EditAdmin_PermissinAddAdminOn : presentationData.strings.Channel_EditAdmin_PermissinAddAdminOff))
            }
            
            if let admin = admin as? TelegramUser, admin.botInfo == nil && !admin.isDeleted && channel.flags.contains(.isCreator) && areAllAdminRightsEnabled(currentRightsFlags, group: isGroup) {
                entries.append(.transfer(presentationData.theme, isGroup ? presentationData.strings.Group_EditAdmin_TransferOwnership : presentationData.strings.Channel_EditAdmin_TransferOwnership))
            }
        
            if let initialParticipant = initialParticipant, case let .member(participant) = initialParticipant, let adminInfo = participant.adminInfo, !adminInfo.rights.flags.isEmpty && admin.id != accountPeerId {
                var canDismiss = false
                if channel.flags.contains(.isCreator) {
                    canDismiss = true
                } else {
                    switch initialParticipant {
                        case .creator:
                            break
                        case let .member(_, _, adminInfo, _):
                            if let adminInfo = adminInfo {
                                if adminInfo.promotedBy == accountPeerId || adminInfo.canBeEditedByAccountPeer {
                                    canDismiss = true
                                }
                            }
                    }
                }
                if canDismiss {
                    entries.append(.dismiss(presentationData.theme, presentationData.strings.Channel_Moderator_AccessLevelRevoke))
                }
            }
        } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminInfo, _) = initialParticipant, let adminInfo = maybeAdminInfo {
            var index = 0
            for right in rightsOrder {
                entries.append(.rightItem(presentationData.theme, index, stringForRight(strings: presentationData.strings, right: right, isGroup: isGroup, defaultBannedRights: channel.defaultBannedRights), right, adminInfo.rights.flags, adminInfo.rights.flags.contains(right), false))
                index += 1
            }
        }
    } else if let group = channelView.peers[channelView.peerId] as? TelegramGroup, let admin = adminView.peers[adminView.peerId] {
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, admin, adminView.peerPresences[admin.id] as? TelegramUserPresence))
        
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
        } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminRights, _) = initialParticipant, let adminRights = maybeAdminRights {
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
    
        if let admin = admin as? TelegramUser, admin.botInfo == nil && !admin.isDeleted && group.role == .creator && areAllAdminRightsEnabled(currentRightsFlags, group: true) {
            entries.append(.transfer(presentationData.theme, presentationData.strings.Group_EditAdmin_TransferOwnership))
        }
        
        if let initialParticipant = initialParticipant, case let .member(participant) = initialParticipant, let adminInfo = participant.adminInfo, !adminInfo.rights.flags.isEmpty && admin.id != accountPeerId {
            entries.append(.dismiss(presentationData.theme, presentationData.strings.Channel_Moderator_AccessLevelRevoke))
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
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    let actualPeerId = Atomic<PeerId>(value: peerId)
    let upgradedToSupergroupImpl: (PeerId, @escaping () -> Void) -> Void = { peerId, completion in
        let _ = actualPeerId.swap(peerId)
        upgradedToSupergroup(peerId, completion)
    }
    
    let arguments = ChannelAdminControllerArguments(account: context.account, toggleRight: { right, flags in
        updateState { current in
            var updated = flags
            if flags.contains(right) {
                updated.remove(right)
            } else {
                updated.insert(right)
            }
            return current.withUpdatedUpdatedFlags(updated)
        }
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
    }, dismissAdmin: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
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
                updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: [])) |> deliverOnMainQueue).start(error: { _ in
                    
                }, completed: {
                    updated(TelegramChatAdminRights(flags: []))
                    dismissImpl?()
                }))
            }
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    })
    
    let combinedView = context.account.postbox.combinedView(keys: [.peer(peerId: peerId, components: .all), .peer(peerId: adminId, components: .all)])
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), combinedView)
    |> deliverOnMainQueue
    |> map { presentationData, state, combinedView -> (ItemListControllerState, (ItemListNodeState<ChannelAdminEntry>, ChannelAdminEntry.ItemGenerationArguments)) in
        let channelView = combinedView.views[.peer(peerId: peerId, components: .all)] as! PeerView
        let adminView = combinedView.views[.peer(peerId: adminId, components: .all)] as! PeerView
        let canEdit = canEditAdminRights(accountPeerId: context.account.peerId, channelView: channelView, initialParticipant: initialParticipant)
        
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
        
        var rightNavigationButton: ItemListNavigationButton?
        if state.updating {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else if canEdit {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                if let channel = channelView.peers[channelView.peerId] as? TelegramChannel {
                    if let initialParticipant = initialParticipant {
                        var updateFlags: TelegramChatAdminRightsFlags?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            if let _ = updateFlags {
                                return current.withUpdatedUpdating(true)
                            } else {
                                return current
                            }
                        }
                        
                        if updateFlags == nil {
                            switch initialParticipant {
                                case .creator:
                                    break
                                case let .member(member):
                                    if member.adminInfo?.rights == nil {
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
                            }
                        }
                        
                        if let updateFlags = updateFlags {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: updateFlags)) |> deliverOnMainQueue).start(error: { _ in
                                
                            }, completed: {
                                updated(TelegramChatAdminRights(flags: updateFlags))
                                dismissImpl?()
                            }))
                        } else {
                            dismissImpl?()
                        }
                    } else if canEdit {
                        var updateFlags: TelegramChatAdminRightsFlags?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            return current.withUpdatedUpdating(true)
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
                            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: updateFlags)) |> deliverOnMainQueue).start(error: { error in
                                if case let .addMemberError(error) = error, case .restricted = error, let admin = adminView.peers[adminView.peerId] {
                                    var text = presentationData.strings.Privacy_GroupsAndChannels_InviteToChannelError(admin.compactDisplayTitle, admin.compactDisplayTitle).0
                                    if case .group = channel.info {
                                        text = presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(admin.compactDisplayTitle, admin.compactDisplayTitle).0
                                    }
                                    presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                }
                            }, completed: {
                                updated(TelegramChatAdminRights(flags: updateFlags))
                                dismissImpl?()
                            }))
                        }
                    }
                } else if let _ = channelView.peers[channelView.peerId] as? TelegramGroup {
                    var updateFlags: TelegramChatAdminRightsFlags?
                    updateState { current in
                        updateFlags = current.updatedFlags
                        return current
                    }
                    
                    let maskRightsFlags: TelegramChatAdminRightsFlags = .groupSpecific
                    let defaultFlags = maskRightsFlags.subtracting(.canAddAdmins)
                    
                    if updateFlags == nil {
                        updateFlags = defaultFlags
                    }
                    
                    if let updateFlags = updateFlags {
                        if initialParticipant?.adminInfo == nil && updateFlags == defaultFlags {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((addGroupAdmin(account: context.account, peerId: peerId, adminId: adminId)
                            |> deliverOnMainQueue).start(completed: {
                                dismissImpl?()
                            }))
                        } else if updateFlags != defaultFlags {
                            let signal = convertGroupToSupergroup(account: context.account, peerId: peerId)
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<PeerId?, UpdateChannelAdminRightsError> in
                                return .fail(.generic)
                            }
                            |> mapToSignal { upgradedPeerId -> Signal<PeerId?, UpdateChannelAdminRightsError> in
                                guard let upgradedPeerId = upgradedPeerId else {
                                    return .fail(.generic)
                                }
                                return context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: upgradedPeerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: updateFlags))
                                |> mapToSignal { _ -> Signal<PeerId?, UpdateChannelAdminRightsError> in
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
                                if case let .addMemberError(error) = error, case .restricted = error, let admin = adminView.peers[adminView.peerId] {
                                    presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(admin.compactDisplayTitle, admin.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                }
                                
                                updateState { current in
                                    return current.withUpdatedUpdating(false)
                                }
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
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Channel_Management_LabelEditor), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        
        let listState = ItemListNodeState(entries: channelAdminControllerEntries(presentationData: presentationData, state: state, accountPeerId: context.account.peerId, channelView: channelView, adminView: adminView, initialParticipant: initialParticipant), style: .blocks, emptyStateItem: nil, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window(.root), with: presentationArguments)
    }
    return controller
}
