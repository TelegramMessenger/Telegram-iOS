import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChannelAdminsControllerArguments {
    let account: Account
    
    let openRecentActions: () -> Void
    let updateCurrentAdministrationType: () -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removeAdmin: (PeerId) -> Void
    let addAdmin: () -> Void
    let openAdmin: (ChannelParticipant) -> Void
    
    init(account: Account, openRecentActions: @escaping () -> Void, updateCurrentAdministrationType: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removeAdmin: @escaping (PeerId) -> Void, addAdmin: @escaping () -> Void, openAdmin: @escaping (ChannelParticipant) -> Void) {
        self.account = account
        self.openRecentActions = openRecentActions
        self.updateCurrentAdministrationType = updateCurrentAdministrationType
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
    
    var hashValue: Int {
        switch self {
            case let .index(index):
                return index.hashValue
            case let .peer(peerId):
                return peerId.hashValue
        }
    }
    
    static func ==(lhs: ChannelAdminsEntryStableId, rhs: ChannelAdminsEntryStableId) -> Bool {
        switch lhs {
            case let .index(index):
                if case .index(index) = rhs {
                    return true
                } else {
                    return false
                }
            case let .peer(peerId):
                if case .peer(peerId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum ChannelAdminsEntry: ItemListNodeEntry {
    case recentActions(PresentationTheme, String)
    case administrationType(PresentationTheme, String, String)
    case administrationInfo(PresentationTheme, String)
    
    case adminsHeader(PresentationTheme, String)
    case adminPeerItem(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Bool, Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool)
    case addAdmin(PresentationTheme, String, Bool)
    case adminsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .recentActions, .administrationType, .administrationInfo:
                return ChannelAdminsSection.administration.rawValue
            case .adminsHeader, .adminPeerItem, .addAdmin, .adminsInfo:
                return ChannelAdminsSection.admins.rawValue
        }
    }
    
    var stableId: ChannelAdminsEntryStableId {
        switch self {
            case .recentActions:
                return .index(0)
            case .administrationType:
                return .index(1)
            case .administrationInfo:
                return .index(2)
            case .adminsHeader:
                return .index(3)
            case .addAdmin:
                return .index(4)
            case .adminsInfo:
                return .index(5)
            case let .adminPeerItem(_, _, _, _, _, _, participant, _, _):
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
            case let .administrationType(lhsTheme, lhsText, lhsValue):
                if case let .administrationType(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .administrationInfo(lhsTheme, lhsText):
                if case let .administrationInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .adminPeerItem(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsIsGroup, lhsIndex, lhsParticipant, lhsEditing, lhsEnabled):
                if case let .adminPeerItem(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsIsGroup, rhsIndex, rhsParticipant, rhsEditing, rhsEnabled) = rhs {
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
            case .administrationType:
                switch rhs {
                    case .recentActions:
                        return false
                    default:
                        return true
                }
            case .administrationInfo:
                switch rhs {
                    case .recentActions, .administrationType:
                        return false
                    default:
                        return true
                }
            case .adminsHeader:
                switch rhs {
                    case .recentActions, .administrationType, .administrationInfo:
                        return false
                    default:
                        return true
                }
            case let .adminPeerItem(_, _, _, _, _, index, _, _, _):
                switch rhs {
                    case .recentActions, .administrationType, .administrationInfo, .adminsHeader, .addAdmin:
                        return false
                    case let .adminPeerItem(_, _, _, _, _, rhsIndex, _, _, _):
                        return index < rhsIndex
                    default:
                        return true
                }
            case .addAdmin:
                switch rhs {
                    case .recentActions, .administrationType, .administrationInfo, .adminsHeader, .addAdmin:
                        return false
                    default:
                        return true
                }
            case .adminsInfo:
                return false
        }
    }
    
    func item(_ arguments: ChannelAdminsControllerArguments) -> ListViewItem {
        switch self {
            case let .recentActions(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openRecentActions()
                })
            case let .administrationType(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.updateCurrentAdministrationType()
                })
            case let .administrationInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .adminsHeader(theme, title):
                return ItemListSectionHeaderItem(theme: theme, text: title, sectionId: self.section)
            case let .adminPeerItem(theme, strings, dateTimeFormat, nameDisplayOrder, _, _, participant, editing, enabled):
                let peerText: String
                let action: (() -> Void)?
                switch participant.participant {
                    case .creator:
                        peerText = strings.Channel_Management_LabelCreator
                        action = nil
                    case let .member(_, _, adminInfo, _):
                        if let adminInfo = adminInfo {
                            if let peer = participant.peers[adminInfo.promotedBy] {
                                peerText = strings.Channel_Management_PromotedBy(peer.displayTitle).0
                            } else {
                                peerText = ""
                            }
                        } else {
                            peerText = ""
                        }
                        action = {
                            arguments.openAdmin(participant.participant)
                        }
                }
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.account, peer: participant.peer, presence: nil, text: .text(peerText), label: .none, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: action, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removeAdmin(peerId)
                })
            case let .addAdmin(theme, text, editing):
                return ItemListPeerActionItem(theme: theme, icon: PresentationResourcesItemList.addPersonIcon(theme), title: text, sectionId: self.section, editing: editing, action: {
                    arguments.addAdmin()
                })
            case let .adminsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private enum CurrentAdministrationType {
    case everyoneCanAddMembers
    case adminsCanAddMembers
}

private struct ChannelAdminsControllerState: Equatable {
    let selectedType: CurrentAdministrationType?
    let editing: Bool
    let peerIdWithRevealedOptions: PeerId?
    let removingPeerId: PeerId?
    let removedPeerIds: Set<PeerId>
    let temporaryAdmins: [RenderedChannelParticipant]
    let searchingMembers: Bool

    init() {
        self.selectedType = nil
        self.editing = false
        self.peerIdWithRevealedOptions = nil
        self.removingPeerId = nil
        self.removedPeerIds = Set()
        self.temporaryAdmins = []
        self.searchingMembers = false
    }
    
    init(selectedType: CurrentAdministrationType?, editing: Bool, peerIdWithRevealedOptions: PeerId?, removingPeerId: PeerId?, removedPeerIds: Set<PeerId>, temporaryAdmins: [RenderedChannelParticipant], searchingMembers: Bool) {
        self.selectedType = selectedType
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.removingPeerId = removingPeerId
        self.removedPeerIds = removedPeerIds
        self.temporaryAdmins = temporaryAdmins
        self.searchingMembers = searchingMembers
    }
    
    static func ==(lhs: ChannelAdminsControllerState, rhs: ChannelAdminsControllerState) -> Bool {
        if lhs.selectedType != rhs.selectedType {
            return false
        }
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
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: searchingMembers)
    }
    
    func withUpdatedSelectedType(_ selectedType: CurrentAdministrationType?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: selectedType, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovedPeerIds(_ removedPeerIds: Set<PeerId>) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedTemporaryAdmins(_ temporaryAdmins: [RenderedChannelParticipant]) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: temporaryAdmins, searchingMembers: self.searchingMembers)
    }
}

private func channelAdminsControllerEntries(presentationData: PresentationData, accountPeerId: PeerId, view: PeerView, state: ChannelAdminsControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelAdminsEntry] {
    if participants == nil || participants?.count == nil {
        return []
    }
    
    var entries: [ChannelAdminsEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var isGroup = false
        if case let .group(info) = peer.info {
            isGroup = true
            
            entries.append(.recentActions(presentationData.theme, presentationData.strings.Group_Info_AdminLog))
            
            if peer.flags.contains(.isCreator) {
                let selectedType: CurrentAdministrationType
                if let current = state.selectedType {
                    selectedType = current
                } else {
                    if info.flags.contains(.everyMemberCanInviteMembers) {
                        selectedType = .everyoneCanAddMembers
                    } else {
                        selectedType = .adminsCanAddMembers
                    }
                }
                let selectedTypeValue: String
                let infoText: String
                switch selectedType {
                    case .everyoneCanAddMembers:
                        selectedTypeValue = presentationData.strings.ChannelMembers_WhoCanAddMembers_AllMembers
                        infoText = presentationData.strings.ChannelMembers_WhoCanAddMembersAllHelp
                    case .adminsCanAddMembers:
                        selectedTypeValue = presentationData.strings.ChannelMembers_WhoCanAddMembers_Admins
                        infoText = presentationData.strings.ChannelMembers_WhoCanAddMembersAdminsHelp
                }
                
                entries.append(.administrationType(presentationData.theme, presentationData.strings.ChannelMembers_WhoCanAddMembers, selectedTypeValue))
                
                entries.append(.administrationInfo(presentationData.theme, infoText))
            }
        } else {
            entries.append(.recentActions(presentationData.theme, presentationData.strings.Group_Info_AdminLog))
        }
        
        if let participants = participants {
            entries.append(.adminsHeader(presentationData.theme, isGroup ? presentationData.strings.ChannelMembers_GroupAdminsTitle : presentationData.strings.ChannelMembers_ChannelAdminsTitle))
            
            if peer.hasAdminRights(.canAddAdmins) {
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
                    case let .member(_, invitedAt, _, _):
                        lhsInvitedAt = invitedAt
                }
                let rhsInvitedAt: Int32
                switch rhs.participant {
                    case .creator:
                        rhsInvitedAt = Int32.min
                    case let .member(_, invitedAt, _, _):
                        rhsInvitedAt = invitedAt
                }
                return lhsInvitedAt < rhsInvitedAt
            }) {
                if !state.removedPeerIds.contains(participant.peer.id) {
                    var editable = true
                    switch participant.participant {
                        case .creator:
                            editable = false
                        case let .member(id, _, adminInfo, _):
                            if id == accountPeerId {
                                editable = false
                            } else if let adminInfo = adminInfo {
                                if peer.flags.contains(.isCreator) || adminInfo.promotedBy == accountPeerId {
                                    editable = true
                                } else {
                                    editable = false
                                }
                            } else {
                                editable = false
                            }
                    }
                    entries.append(.adminPeerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, isGroup, index, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), existingParticipantIds.contains(participant.peer.id)))
                    index += 1
                }
            }
            
            if peer.hasAdminRights(.canAddAdmins) {
                let info = isGroup ? presentationData.strings.Group_Management_AddModeratorHelp : presentationData.strings.Channel_Management_AddModeratorHelp
                entries.append(.adminsInfo(presentationData.theme, info))
            }
        }
    }
    
    return entries
}

public func channelAdminsController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelAdminsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelAdminsControllerState())
    let updateState: ((ChannelAdminsControllerState) -> ChannelAdminsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updateAdministrationDisposable = MetaDisposable()
    actionsDisposable.add(updateAdministrationDisposable)

    let removeAdminDisposable = MetaDisposable()
    actionsDisposable.add(removeAdminDisposable)
    
    let addAdminDisposable = MetaDisposable()
    actionsDisposable.add(addAdminDisposable)
    
    let adminsPromise = Promise<[RenderedChannelParticipant]?>(nil)
    
    let presentationDataSignal = (account.applicationContext as! TelegramApplicationContext).presentationData
    
    let arguments = ChannelAdminsControllerArguments(account: account, openRecentActions: {
        let _ = (account.postbox.loadedPeerWithId(peerId)
        |> deliverOnMainQueue).start(next: { peer in
            pushControllerImpl?(ChatRecentActionsController(account: account, peer: peer))
        })
    }, updateCurrentAdministrationType: {
        let _ = (presentationDataSignal |> take(1) |> deliverOnMainQueue).start(next: { presentationData in
            let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
            let result = ValuePromise<Bool>()
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.ChannelMembers_WhoCanAddMembers_AllMembers, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    result.set(true)
                }),
                ActionSheetButtonItem(title: presentationData.strings.ChannelMembers_WhoCanAddMembers_Admins, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    result.set(false)
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            let updateSignal = result.get()
                |> take(1)
                |> mapToSignal { value -> Signal<Void, NoError> in
                    updateState { state in
                        return state.withUpdatedSelectedType(value ? .everyoneCanAddMembers : .adminsCanAddMembers)
                    }
                    
                    return account.postbox.loadedPeerWithId(peerId)
                    |> mapToSignal { peer -> Signal<Void, NoError> in
                        if let peer = peer as? TelegramChannel, case let .group(info) = peer.info {
                            var updatedValue: Bool?
                            if value && !info.flags.contains(.everyMemberCanInviteMembers) {
                                updatedValue = true
                            } else if !value && info.flags.contains(.everyMemberCanInviteMembers) {
                                updatedValue = false
                            }
                            if let updatedValue = updatedValue {
                                return updateGroupManagementType(account: account, peerId: peerId, type: updatedValue ? .unrestricted : .restrictedToAdmins)
                                |> `catch` { _ -> Signal<Void, NoError> in
                                    return .complete()
                                }
                            } else {
                                return .complete()
                            }
                        } else {
                            return .complete()
                        }
                    }
                }
            updateAdministrationDisposable.set(updateSignal.start())
            presentControllerImpl?(actionSheet, nil)
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
        updateState {
            return $0.withUpdatedRemovingPeerId(adminId)
        }
        removeAdminDisposable.set((account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: account, peerId: peerId, memberId: adminId, adminRights: TelegramChannelAdminRights(flags: []))
        |> deliverOnMainQueue).start(completed: {
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
        }))
    }, addAdmin: {
        updateState { current in
            
            presentControllerImpl?(ChannelMembersSearchController(account: account, peerId: peerId, mode: .promote, filters: [], openPeer: { peer, participant in
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                if peer.id == account.peerId {
                    return
                }
                if let participant = participant {
                    switch participant.participant {
                    case .creator:
                        return
                    case let .member(_, _, _, banInfo):
                        if let banInfo = banInfo, banInfo.restrictedBy != account.peerId {
                            presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Channel_Members_AddAdminErrorBlacklisted, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                            return
                        }
                    }
                }
                presentControllerImpl?(channelAdminController(account: account, peerId: peerId, adminId: peer.id, initialParticipant: participant?.participant, updated: { _ in
                }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            
            return current
        }
        
    }, openAdmin: { participant in
        if case let .member(adminId, _, _, _) = participant {
            presentControllerImpl?(channelAdminController(account: account, peerId: peerId, adminId: participant.peerId, initialParticipant: participant, updated: { _ in
            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }
    })
    
    let peerView = account.viewTracker.peerView(peerId) |> deliverOnMainQueue
    
    let (membersDisposable, loadMoreControl) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.admins(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId) { membersState in
        if case .loading = membersState.loadingState, membersState.list.isEmpty {
            adminsPromise.set(.single(nil))
        } else {
            adminsPromise.set(.single(membersState.list))
        }
    }
    actionsDisposable.add(membersDisposable)
    
    var previousPeers: [RenderedChannelParticipant]?
    
    let signal = combineLatest(presentationDataSignal, statePromise.get(), peerView, adminsPromise.get() |> deliverOnMainQueue)
        |> deliverOnMainQueue
        |> map { presentationData, state, view, admins -> (ItemListControllerState, (ItemListNodeState<ChannelAdminsEntry>, ChannelAdminsEntry.ItemGenerationArguments)) in
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
                
                
                if !state.editing {
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
                
                _ = stateValue.swap(state.withUpdatedTemporaryAdmins(admins))
            }
            
            let previous = previousPeers
            previousPeers = admins
            
            var isGroup = true
            if let peer = view.peers[peerId] as? TelegramChannel, case .broadcast = peer.info {
                isGroup = false
            }
            
            var searchItem: ItemListControllerSearch?
            if state.searchingMembers {
                searchItem = ChannelMembersSearchItem(account: account, peerId: peerId, searchMode: .searchAdmins, cancel: {
                    updateState { state in
                        return state.withUpdatedSearchingMembers(false)
                    }
                }, openPeer: { _, participant in
                    if let participant = participant?.participant, case .member = participant {
                        presentControllerImpl?(channelAdminController(account: account, peerId: peerId, adminId: participant.peerId, initialParticipant: participant, updated: { _ in
                        }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    }
                }, present: { c, a in
                    presentControllerImpl?(c, a)
                })
            }
            
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if admins == nil || admins?.count == 0 {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(isGroup ? presentationData.strings.ChatAdmins_Title : presentationData.strings.Channel_Management_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, secondaryRightNavigationButton: secondaryRightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
            let listState = ItemListNodeState(entries: channelAdminsControllerEntries(presentationData: presentationData, accountPeerId: account.peerId, view: view, state: state, participants: admins), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, animateChanges: previous != nil && admins != nil && previous!.count >= admins!.count)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(account: account, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
            controller.view.endEditing(true)
        }
    }
    controller.visibleBottomContentOffsetChanged = { offset in
        if case let .known(value) = offset, value < 40.0 {
            account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
        }
    }
    return controller
}
