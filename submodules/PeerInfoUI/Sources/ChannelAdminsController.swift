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
import AccountContext
import TemporaryCachedPeerDataManager
import AlertUI
import PresentationDataUtils
import UndoUI
import ItemListPeerItem
import ItemListPeerActionItem

private final class ChannelAdminsControllerArguments {
    let context: AccountContext
    
    let openRecentActions: () -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removeAdmin: (PeerId) -> Void
    let addAdmin: () -> Void
    let openAdmin: (ChannelParticipant) -> Void
    
    init(context: AccountContext, openRecentActions: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removeAdmin: @escaping (PeerId) -> Void, addAdmin: @escaping () -> Void, openAdmin: @escaping (ChannelParticipant) -> Void) {
        self.context = context
        self.openRecentActions = openRecentActions
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removeAdmin = removeAdmin
        self.addAdmin = addAdmin
        self.openAdmin = openAdmin
    }
}

private enum ChannelAdminsSection: Int32 {
    case administration
    case admins
}

private enum ChannelAdminsEntryStableId: Hashable {
    case index(Int32)
    case peer(PeerId)
}

private enum ChannelAdminsEntry: ItemListNodeEntry {
    case recentActions(PresentationTheme, String)
    
    case adminsHeader(PresentationTheme, String)
    case adminPeerItem(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Bool, Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool, Bool)
    case addAdmin(PresentationTheme, String, Bool)
    case adminsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .recentActions:
                return ChannelAdminsSection.administration.rawValue
            case .adminsHeader, .adminPeerItem, .addAdmin, .adminsInfo:
                return ChannelAdminsSection.admins.rawValue
        }
    }
    
    var stableId: ChannelAdminsEntryStableId {
        switch self {
            case .recentActions:
                return .index(0)
            case .adminsHeader:
                return .index(3)
            case .addAdmin:
                return .index(4)
            case .adminsInfo:
                return .index(5)
            case let .adminPeerItem(_, _, _, _, _, _, participant, _, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelAdminsEntry, rhs: ChannelAdminsEntry) -> Bool {
        switch lhs {
            case let .recentActions(lhsTheme, lhsText):
                if case let .recentActions(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adminsHeader(lhsTheme, lhsText):
                if case let .adminsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adminPeerItem(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsIsGroup, lhsIndex, lhsParticipant, lhsEditing, lhsEnabled, lhsHasAction):
                if case let .adminPeerItem(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsIsGroup, rhsIndex, rhsParticipant, rhsEditing, rhsEnabled, rhsHasAction) = rhs {
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
                    if lhsIsGroup != rhsIsGroup {
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
                    if lhsHasAction != rhsHasAction {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .adminsInfo(lhsTheme, lhsText):
                if case let .adminsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addAdmin(lhsTheme, lhsText, lhsEditing):
                if case let .addAdmin(rhsTheme, rhsText, rhsEditing) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEditing == rhsEditing {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelAdminsEntry, rhs: ChannelAdminsEntry) -> Bool {
        switch lhs {
            case .recentActions:
                return true
            case .adminsHeader:
                switch rhs {
                    case .recentActions:
                        return false
                    default:
                        return true
                }
            case let .adminPeerItem(_, _, _, _, _, index, _, _, _, _):
                switch rhs {
                    case .recentActions, .adminsHeader, .addAdmin:
                        return false
                    case let .adminPeerItem(_, _, _, _, _, rhsIndex, _, _, _, _):
                        return index < rhsIndex
                    default:
                        return true
                }
            case .addAdmin:
                switch rhs {
                    case .recentActions, .adminsHeader, .addAdmin:
                        return false
                    default:
                        return true
                }
            case .adminsInfo:
                return false
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelAdminsControllerArguments
        switch self {
            case let .recentActions(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Chat/Info/RecentActionsIcon"), title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openRecentActions()
                })
            case let .adminsHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .adminPeerItem(_, strings, dateTimeFormat, nameDisplayOrder, _, _, participant, editing, enabled, hasAction):
                let peerText: String
                var action: (() -> Void)?
                switch participant.participant {
                    case .creator:
                        peerText = strings.Channel_Management_LabelOwner
                    case let .member(_, _, adminInfo, _, _):
                        if let adminInfo = adminInfo {
                            if let peer = participant.peers[adminInfo.promotedBy] {
                                if peer.id == participant.peer.id {
                                    peerText = strings.Channel_Management_LabelAdministrator
                                } else {
                                    peerText = strings.Channel_Management_PromotedBy(EnginePeer(peer).displayTitle(strings: strings, displayOrder: nameDisplayOrder)).string
                                }
                            } else {
                                peerText = ""
                            }
                        } else {
                            peerText = ""
                        }
                }
                if hasAction {
                    action = {
                        arguments.openAdmin(participant.participant)
                    }
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(participant.peer), presence: nil, text: .text(peerText, .secondary), label: .none, editing: editing, switchValue: nil, enabled: enabled, selectable: true, sectionId: self.section, action: action, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removeAdmin(peerId)
                })
            case let .addAdmin(theme, text, editing):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addPersonIcon(theme), title: text, sectionId: self.section, editing: editing, action: {
                    arguments.addAdmin()
                })
            case let .adminsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct ChannelAdminsControllerState: Equatable {
    let editing: Bool
    let peerIdWithRevealedOptions: PeerId?
    let removingPeerId: PeerId?
    let removedPeerIds: Set<PeerId>
    let temporaryAdmins: [RenderedChannelParticipant]
    let searchingMembers: Bool

    init() {
        self.editing = false
        self.peerIdWithRevealedOptions = nil
        self.removingPeerId = nil
        self.removedPeerIds = Set()
        self.temporaryAdmins = []
        self.searchingMembers = false
    }
    
    init(editing: Bool, peerIdWithRevealedOptions: PeerId?, removingPeerId: PeerId?, removedPeerIds: Set<PeerId>, temporaryAdmins: [RenderedChannelParticipant], searchingMembers: Bool) {
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.removingPeerId = removingPeerId
        self.removedPeerIds = removedPeerIds
        self.temporaryAdmins = temporaryAdmins
        self.searchingMembers = searchingMembers
    }
    
    static func ==(lhs: ChannelAdminsControllerState, rhs: ChannelAdminsControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.removingPeerId != rhs.removingPeerId {
            return false
        }
        if lhs.removedPeerIds != rhs.removedPeerIds {
            return false
        }
        if lhs.temporaryAdmins != rhs.temporaryAdmins {
            return false
        }
        if lhs.searchingMembers != rhs.searchingMembers {
            return false
        }
        
        return true
    }
    
    func withUpdatedSearchingMembers(_ searchingMembers: Bool) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: searchingMembers)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovedPeerIds(_ removedPeerIds: Set<PeerId>) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedTemporaryAdmins(_ temporaryAdmins: [RenderedChannelParticipant]) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: temporaryAdmins, searchingMembers: self.searchingMembers)
    }
}

private func channelAdminsControllerEntries(presentationData: PresentationData, accountPeerId: PeerId, view: PeerView, state: ChannelAdminsControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelAdminsEntry] {
    if participants == nil || participants?.count == nil {
        return []
    }
    
    var entries: [ChannelAdminsEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var isGroup = false
        if case .group = peer.info {
            isGroup = true
            entries.append(.recentActions(presentationData.theme, presentationData.strings.Group_Info_AdminLog))
        } else {
            entries.append(.recentActions(presentationData.theme, presentationData.strings.Group_Info_AdminLog))
        }
        
        if let participants = participants {
            entries.append(.adminsHeader(presentationData.theme, isGroup ? presentationData.strings.ChannelMembers_GroupAdminsTitle : presentationData.strings.ChannelMembers_ChannelAdminsTitle))
            
            if peer.hasPermission(.addAdmins) {
                entries.append(.addAdmin(presentationData.theme, presentationData.strings.Channel_Management_AddModerator, state.editing))
            }
            
            var combinedParticipants: [RenderedChannelParticipant] = participants
            var existingParticipantIds = Set<PeerId>()
            for participant in participants {
                existingParticipantIds.insert(participant.peer.id)
            }
            
            for participant in state.temporaryAdmins {
                if !existingParticipantIds.contains(participant.peer.id) {
                    combinedParticipants.append(participant)
                }
            }
            
            var index: Int32 = 0
            for participant in combinedParticipants.sorted(by: { lhs, rhs in
                let lhsInvitedAt: Int32
                switch lhs.participant {
                    case .creator:
                        lhsInvitedAt = Int32.min
                    case let .member(_, invitedAt, _, _, _):
                        lhsInvitedAt = invitedAt
                }
                let rhsInvitedAt: Int32
                switch rhs.participant {
                    case .creator:
                        rhsInvitedAt = Int32.min
                    case let .member(_, invitedAt, _, _, _):
                        rhsInvitedAt = invitedAt
                }
                return lhsInvitedAt < rhsInvitedAt
            }) {
                if !state.removedPeerIds.contains(participant.peer.id) {
                    var canEdit = true
                    var canOpen = true
                    switch participant.participant {
                        case .creator:
                            canEdit = false
                            canOpen = isGroup && peer.flags.contains(.isCreator)
                        case let .member(id, _, adminInfo, _, _):
                            if id == accountPeerId {
                                canEdit = false
                            } else if let adminInfo = adminInfo {
                                if peer.flags.contains(.isCreator) {
                                    canEdit = true
                                    canOpen = true
                                } else if adminInfo.promotedBy == accountPeerId {
                                    canEdit = true
                                    if let adminRights = peer.adminRights {
                                        if adminRights.rights.isEmpty {
                                            canOpen = false
                                        }
                                    }
                                } else {
                                    canEdit = false
                                }
                            } else {
                                canEdit = false
                            }
                    }
                    entries.append(.adminPeerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, isGroup, index, participant, ItemListPeerItemEditing(editable: canEdit, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id && existingParticipantIds.contains(participant.peer.id), canOpen))
                    index += 1
                }
            }
            
            if peer.hasPermission(.addAdmins) {
                let info = isGroup ? presentationData.strings.Group_Management_AddModeratorHelp : presentationData.strings.Channel_Management_AddModeratorHelp
                entries.append(.adminsInfo(presentationData.theme, info))
            }
        }
    } else if let peer = view.peers[view.peerId] as? TelegramGroup {
        let isGroup = true
        //entries.append(.recentActions(presentationData.theme, presentationData.strings.Group_Info_AdminLog))
        
        if let participants = participants {
            entries.append(.adminsHeader(presentationData.theme, presentationData.strings.ChannelMembers_GroupAdminsTitle))
            
            if case .creator = peer.role {
                entries.append(.addAdmin(presentationData.theme, presentationData.strings.Channel_Management_AddModerator, state.editing))
            }
            
            var combinedParticipants: [RenderedChannelParticipant] = participants
            var existingParticipantIds = Set<PeerId>()
            for participant in participants {
                existingParticipantIds.insert(participant.peer.id)
            }
            
            for participant in state.temporaryAdmins {
                if !existingParticipantIds.contains(participant.peer.id) {
                    combinedParticipants.append(participant)
                }
            }
            
            var index: Int32 = 0
            for participant in combinedParticipants.sorted(by: { lhs, rhs in
                let lhsInvitedAt: Int32
                switch lhs.participant {
                    case .creator:
                        lhsInvitedAt = Int32.min
                    case let .member(_, invitedAt, _, _, _):
                        lhsInvitedAt = invitedAt
                }
                let rhsInvitedAt: Int32
                switch rhs.participant {
                    case .creator:
                        rhsInvitedAt = Int32.min
                    case let .member(_, invitedAt, _, _, _):
                        rhsInvitedAt = invitedAt
                }
                return lhsInvitedAt < rhsInvitedAt
            }) {
                if !state.removedPeerIds.contains(participant.peer.id) {
                    var editable = true
                    var canEdit = true
                    switch participant.participant {
                        case .creator:
                            editable = false
                            if case .creator = peer.role {
                            } else {
                                canEdit = false
                            }
                        case let .member(id, _, adminInfo, _, _):
                            if id == accountPeerId {
                                editable = false
                            } else if let adminInfo = adminInfo {
                                if case .creator = peer.role {
                                    editable = true
                                } else if adminInfo.promotedBy == accountPeerId {
                                    editable = true
                                } else {
                                    editable = false
                                }
                            } else {
                                editable = false
                            }
                    }
                    entries.append(.adminPeerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, isGroup, index, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id && existingParticipantIds.contains(participant.peer.id), canEdit))
                    index += 1
                }
            }
            
            if case .creator = peer.role {
                let info = presentationData.strings.Group_Management_AddModeratorHelp
                entries.append(.adminsInfo(presentationData.theme, info))
            }
        }
    }
    
    return entries
}

public func channelAdminsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId initialPeerId: PeerId, loadCompleted: @escaping () -> Void = {}) -> ViewController {
    let statePromise = ValuePromise(ChannelAdminsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelAdminsControllerState())
    let updateState: ((ChannelAdminsControllerState) -> ChannelAdminsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissInputImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()

    let removeAdminDisposable = MetaDisposable()
    actionsDisposable.add(removeAdminDisposable)
    
    let addAdminDisposable = MetaDisposable()
    actionsDisposable.add(addAdminDisposable)
    
    let upgradeDisposable = MetaDisposable()
    actionsDisposable.add(upgradeDisposable)
    
    let adminsPromise = Promise<[RenderedChannelParticipant]?>(nil)
        
    var upgradedToSupergroupImpl: ((PeerId, @escaping () -> Void) -> Void)?
    
    let currentPeerId = ValuePromise<PeerId>(initialPeerId)
    
    let upgradedToSupergroup: (PeerId, @escaping () -> Void) -> Void = { upgradedPeerId, f in
        currentPeerId.set(upgradedPeerId)
        upgradedToSupergroupImpl?(upgradedPeerId, f)
    }
    
    let transferedOwnership: (PeerId) -> Void = { memberId in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = (currentPeerId.get()
        |> take(1)
        |> mapToSignal { peerId in
            return context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                TelegramEngine.EngineData.Item.Peer.Peer(id: memberId)
            )
        }
        |> deliverOnMainQueue).start(next: { peer, user in
            guard let peer = peer, let user = user else {
                return
            }
            presentControllerImpl?(UndoOverlayController(presentationData: context.sharedContext.currentPresentationData.with { $0 }, content: .succeed(text: presentationData.strings.Channel_OwnershipTransfer_TransferCompleted(user.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string), elevatedLayout: false, action: { _ in return false }), nil)
        })
    }
    
    let peerView = Promise<PeerView>()
    peerView.set(currentPeerId.get()
    |> mapToSignal { peerId in
        return context.account.viewTracker.peerView(peerId)
    })
    
    let arguments = ChannelAdminsControllerArguments(context: context, openRecentActions: {
        let _ = (currentPeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId in
            let _ = (context.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { peer in
                if peer is TelegramGroup {
                } else {
                    pushControllerImpl?(context.sharedContext.makeChatRecentActionsController(context: context, peer: peer, adminPeerId: nil))
                }
            })
        })
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, removeAdmin: { adminId in
        let _ = (currentPeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId in
            updateState {
                return $0.withUpdatedRemovingPeerId(adminId)
            }
            if peerId.namespace == Namespaces.Peer.CloudGroup {
                removeAdminDisposable.set((context.engine.peers.removeGroupAdmin(peerId: peerId, adminId: adminId)
                |> deliverOnMainQueue).start(completed: {
                    updateState {
                        return $0.withUpdatedRemovingPeerId(nil)
                    }
                }))
            } else {
                removeAdminDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(engine: context.engine, peerId: peerId, memberId: adminId, adminRights: nil, rank: nil)
                |> deliverOnMainQueue).start(completed: {
                    updateState {
                        return $0.withUpdatedRemovingPeerId(nil)
                    }
                }))
            }
        })
    }, addAdmin: {
        let _ = (currentPeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId in
            let _ = (peerView.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { peerView in
                updateState { current in
                    var dismissController: (() -> Void)?
                    let controller = ChannelMembersSearchController(context: context, peerId: peerId, mode: .promote, filters: [], openPeer: { peer, participant in
                        dismissController?()
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        if peer.id == context.account.peerId {
                            return
                        }
                        if let participant = participant {
                            switch participant.participant {
                            case .creator:
                                return
                            case let .member(_, _, _, banInfo, _):
                                if let banInfo = banInfo {
                                    var canUnban = false
                                    if banInfo.restrictedBy != context.account.peerId {
                                        canUnban = true
                                    }
                                    if let channel = peerView.peers[peerId] as? TelegramChannel {
                                        if channel.hasPermission(.banMembers) {
                                            canUnban = true
                                        }
                                    }
                                    if !canUnban {
                                        presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_Members_AddAdminErrorBlacklisted, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                        return
                                    }
                                }
                            }
                        }
                        pushControllerImpl?(channelAdminController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, adminId: peer.id, initialParticipant: participant?.participant, updated: { _ in
                        }, upgradedToSupergroup: upgradedToSupergroup, transferedOwnership: transferedOwnership))
                    })
                    dismissController = { [weak controller] in
                        controller?.dismiss()
                    }
                    pushControllerImpl?(controller)
                    
                    return current
                }
            })
        })
    }, openAdmin: { participant in
        let _ = (currentPeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId in
            pushControllerImpl?(channelAdminController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, adminId: participant.peerId, initialParticipant: participant, updated: { _ in
            }, upgradedToSupergroup: upgradedToSupergroup, transferedOwnership: transferedOwnership))
        })
    })
    
    let membersAndLoadMoreControlValue = Atomic<(Disposable, PeerChannelMemberCategoryControl?)?>(value: nil)
    
    let membersDisposableValue = MetaDisposable()
    actionsDisposable.add(membersDisposableValue)
    
    actionsDisposable.add((currentPeerId.get()
    |> deliverOnMainQueue).start(next: { peerId in
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            var didReportLoadCompleted = false
            let membersAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?) = context.peerChannelMemberCategoriesContextsManager.admins(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId) { membersState in
                if case .loading = membersState.loadingState, membersState.list.isEmpty {
                    adminsPromise.set(.single(nil))
                } else {
                    adminsPromise.set(.single(membersState.list))
                    if !didReportLoadCompleted {
                        didReportLoadCompleted = true
                        loadCompleted()
                    }
                }
            }
            let _ = membersAndLoadMoreControlValue.swap(membersAndLoadMoreControl)
            membersDisposableValue.set(membersAndLoadMoreControl.0)
        } else {
            loadCompleted()
            let membersDisposable = (peerView.get()
            |> map { peerView -> [RenderedChannelParticipant]? in
                guard let cachedData = peerView.cachedData as? CachedGroupData, let participants = cachedData.participants else {
                    return nil
                }
                var result: [RenderedChannelParticipant] = []
                var creatorPeer: Peer?
                for participant in participants.participants {
                    if let peer = peerView.peers[participant.peerId] {
                        switch participant {
                            case .creator:
                                creatorPeer = peer
                            default:
                                break
                        }
                    }
                }
                guard let creator = creatorPeer else {
                    return nil
                }
                for participant in participants.participants {
                    if let peer = peerView.peers[participant.peerId] {
                        switch participant {
                            case .creator:
                                result.append(RenderedChannelParticipant(participant: .creator(id: peer.id, adminInfo: nil, rank: nil), peer: peer))
                            case .admin:
                                var peers: [PeerId: Peer] = [:]
                                peers[creator.id] = creator
                                peers[peer.id] = peer
                                result.append(RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(rights: .groupSpecific), promotedBy: creator.id, canBeEditedByAccountPeer: creator.id == context.account.peerId), banInfo: nil, rank: nil), peer: peer, peers: peers))
                            case .member:
                                break
                        }
                    }
                }
                return result
            }).start(next: { members in
                adminsPromise.set(.single(members))
            })
            let membersAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?) = (membersDisposable, nil)
            let _ = membersAndLoadMoreControlValue.swap(membersAndLoadMoreControl)
            membersDisposableValue.set(membersAndLoadMoreControl.0)
        }
    }))
    
    var previousPeers: [RenderedChannelParticipant]?
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(), presentationData, statePromise.get(), peerView.get(), adminsPromise.get() |> deliverOnMainQueue)
    |> deliverOnMainQueue
    |> map { presentationData, state, view, admins -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let peerId = view.peerId
        
        var rightNavigationButton: ItemListNavigationButton?
        var secondaryRightNavigationButton: ItemListNavigationButton?
        if let admins = admins, admins.count > 1 {
            if state.editing {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedEditing(false)
                    }
                })
            } else if let peer = view.peers[peerId] as? TelegramChannel, peer.flags.contains(.isCreator) {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedEditing(true)
                    }
                })
            }
            
            if !state.editing && peerId.namespace == Namespaces.Peer.CloudChannel {
                if rightNavigationButton == nil {
                    rightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedSearchingMembers(true)
                        }
                    })
                } else {
                    secondaryRightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedSearchingMembers(true)
                        }
                    })
                }
            }
        }
        
        let previous = previousPeers
        previousPeers = admins
        
        var isGroup = true
        if let peer = view.peers[peerId] as? TelegramChannel, case .broadcast = peer.info {
            isGroup = false
        } else if let _ = view.peers[peerId] as? TelegramGroup {
            isGroup = true
        }
        
        var searchItem: ItemListControllerSearch?
        if state.searchingMembers {
            searchItem = ChannelMembersSearchItem(context: context, peerId: peerId, searchContext: nil, searchMode: .searchAdmins, cancel: {
                updateState { state in
                    return state.withUpdatedSearchingMembers(false)
                }
            }, openPeer: { _, participant in
                if let participant = participant?.participant, case .member = participant {
                    pushControllerImpl?(channelAdminController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, adminId: participant.peerId, initialParticipant: participant, updated: { _ in
                        updateState { state in
                            return state.withUpdatedSearchingMembers(false)
                        }
                    }, upgradedToSupergroup: upgradedToSupergroup, transferedOwnership: transferedOwnership))
                }
            }, pushController: { c in
                pushControllerImpl?(c)
            }, dismissInput: {
                dismissInputImpl?()
            })
        }
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if admins == nil || admins?.count == 0 {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(isGroup ? presentationData.strings.ChatAdmins_Title : presentationData.strings.Channel_Management_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, secondaryRightNavigationButton: secondaryRightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelAdminsControllerEntries(presentationData: presentationData, accountPeerId: context.account.peerId, view: view, state: state, participants: admins), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, animateChanges: previous != nil && admins != nil && previous!.count >= admins!.count)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
            controller.view.endEditing(true)
        }
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    upgradedToSupergroupImpl = { [weak controller] upgradedPeerId, f in
        guard let controller = controller, let navigationController = controller.navigationController as? NavigationController else {
            return
        }

        rebuildControllerStackAfterSupergroupUpgrade(controller: controller, navigationController: navigationController, replace: { c in
            if c === controller {
                return channelAdminsController(context: context, peerId: upgradedPeerId, loadCompleted: {
                })
            } else {
                return c
            }
        })
        f()
    }
    controller.visibleBottomContentOffsetChanged = { offset in
        if case let .known(value) = offset, value < 40.0 {
            let _ = (currentPeerId.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { peerId in
                if let loadMoreControl = membersAndLoadMoreControlValue.with({ $0?.1 }) {
                    context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
                }
            })
        }
    }
    return controller
}

public func rebuildControllerStackAfterSupergroupUpgrade(controller: ViewController, navigationController: NavigationController, replace: ((UIViewController) -> UIViewController)? = nil) {
    var controllers = navigationController.viewControllers
    for i in 0 ..< controllers.count {
        if controllers[i] === controller {
            for j in 0 ..< i {
                if controllers[j] is ChatController {
                    if j + 1 <= i - 1 {
                        controllers.removeSubrange(j + 1 ... i - 1)
                    }
                    break
                }
            }
            break
        }
    }
    for i in 0 ..< controllers.count {
        if let replace = replace {
            controllers[i] = replace(controllers[i])
        }
    }
    navigationController.setViewControllers(controllers, animated: false)
}
