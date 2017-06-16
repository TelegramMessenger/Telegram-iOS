import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChannelAdminsControllerArguments {
    let account: Account
    
    let updateCurrentAdministrationType: () -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removeAdmin: (PeerId) -> Void
    let addAdmin: () -> Void
    let openAdmin: (ChannelParticipant) -> Void
    
    init(account: Account, updateCurrentAdministrationType: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removeAdmin: @escaping (PeerId) -> Void, addAdmin: @escaping () -> Void, openAdmin: @escaping (ChannelParticipant) -> Void) {
        self.account = account
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
    case administrationType(PresentationTheme, String, String)
    case administrationInfo(PresentationTheme, String)
    
    case adminsHeader(PresentationTheme, String)
    case adminPeerItem(PresentationTheme, PresentationStrings, Bool, Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool)
    case addAdmin(PresentationTheme, String, Bool)
    case adminsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .administrationType, .administrationInfo:
                return ChannelAdminsSection.administration.rawValue
            case .adminsHeader, .adminPeerItem, .addAdmin, .adminsInfo:
                return ChannelAdminsSection.admins.rawValue
        }
    }
    
    var stableId: ChannelAdminsEntryStableId {
        switch self {
            case .administrationType:
                return .index(0)
            case .administrationInfo:
                return .index(1)
            case .adminsHeader:
                return .index(2)
            case .addAdmin:
                return .index(3)
            case .adminsInfo:
                return .index(4)
            case let .adminPeerItem(_, _, _, _, participant, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelAdminsEntry, rhs: ChannelAdminsEntry) -> Bool {
        switch lhs {
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
            case let .adminPeerItem(lhsTheme, lhsStrings, lhsIsGroup, lhsIndex, lhsParticipant, lhsEditing, lhsEnabled):
                if case let .adminPeerItem(rhsTheme, rhsStrings, rhsIsGroup, rhsIndex, rhsParticipant, rhsEditing, rhsEnabled) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
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
            case .administrationType:
                return true
            case .administrationInfo:
                switch rhs {
                    case .administrationType:
                        return false
                    default:
                        return true
                }
            case .adminsHeader:
                switch rhs {
                    case .administrationType, .administrationInfo:
                        return false
                    default:
                        return true
                }
            case let .adminPeerItem(_, _, _, index, _, _, _):
                switch rhs {
                    case .administrationType, .administrationInfo, .adminsHeader:
                        return false
                    case let .adminPeerItem(_, _, _, rhsIndex, _, _, _):
                        return index < rhsIndex
                    default:
                        return true
                }
            case .addAdmin:
                switch rhs {
                    case .administrationType, .administrationInfo, .adminsHeader, .adminPeerItem:
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
            case let .administrationType(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.updateCurrentAdministrationType()
                })
            case let .administrationInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .adminsHeader(theme, title):
                return ItemListSectionHeaderItem(theme: theme, text: title, sectionId: self.section)
            case let .adminPeerItem(theme, strings, isGroup, _, participant, editing, enabled):
                let peerText: String
                let action: (() -> Void)?
                switch participant.participant {
                    case .creator:
                        peerText = strings.Channel_Management_LabelCreator
                        action = nil
                    case let .member(_, _, adminInfo, _):
                        if let adminInfo = adminInfo {
                            let baseFlags: TelegramChannelAdminRightsFlags
                            if isGroup {
                                baseFlags = .groupSpecific
                            } else {
                                baseFlags = .broadcastSpecific
                            }
                            let flags = adminInfo.rights.flags.intersection(baseFlags)
                            peerText = strings.Channel_Management_LabelRights(Int32(flags.count))
                        } else {
                            peerText = ""
                        }
                        action = {
                            arguments.openAdmin(participant.participant)
                        }
                }
                return ItemListPeerItem(theme: theme, account: arguments.account, peer: participant.peer, presence: nil, text: .text(peerText), label: .none, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: action, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removeAdmin(peerId)
                })
            case let .addAdmin(theme, text, editing):
                return ItemListPeerActionItem(theme: theme, icon: PresentationResourcesItemList.plusIconImage(theme), title: text, sectionId: self.section, editing: editing, action: {
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
    
    init() {
        self.selectedType = nil
        self.editing = false
        self.peerIdWithRevealedOptions = nil
        self.removingPeerId = nil
        self.removedPeerIds = Set()
        self.temporaryAdmins = []
    }
    
    init(selectedType: CurrentAdministrationType?, editing: Bool, peerIdWithRevealedOptions: PeerId?, removingPeerId: PeerId?, removedPeerIds: Set<PeerId>, temporaryAdmins: [RenderedChannelParticipant]) {
        self.selectedType = selectedType
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.removingPeerId = removingPeerId
        self.removedPeerIds = removedPeerIds
        self.temporaryAdmins = temporaryAdmins
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
        
        return true
    }
    
    func withUpdatedSelectedType(_ selectedType: CurrentAdministrationType?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: selectedType, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedRemovedPeerIds(_ removedPeerIds: Set<PeerId>) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedTemporaryAdmins(_ temporaryAdmins: [RenderedChannelParticipant]) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: temporaryAdmins)
    }
}

private func channelAdminsControllerEntries(presentationData: PresentationData, accountPeerId: PeerId, view: PeerView, state: ChannelAdminsControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelAdminsEntry] {
    var entries: [ChannelAdminsEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var isGroup = false
        if case let .group(info) = peer.info {
            isGroup = true
            
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
                        infoText = presentationData.strings.ChannelMembers_AllMembersMayInviteOnHelp
                    case .adminsCanAddMembers:
                        selectedTypeValue = presentationData.strings.ChannelMembers_WhoCanAddMembers_Admins
                        infoText = presentationData.strings.ChannelMembers_AllMembersMayInviteOffHelp
                }
                
                entries.append(.administrationType(presentationData.theme, presentationData.strings.ChannelMembers_WhoCanAddMembers, selectedTypeValue))
                
                entries.append(.administrationInfo(presentationData.theme, infoText))
            }
        }
        
        if let participants = participants {
            entries.append(.adminsHeader(presentationData.theme, isGroup ? presentationData.strings.ChannelMembers_GroupAdminsTitle : presentationData.strings.ChannelMembers_ChannelAdminsTitle))
            
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
                    entries.append(.adminPeerItem(presentationData.theme, presentationData.strings, isGroup, index, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), existingParticipantIds.contains(participant.peer.id)))
                    index += 1
                }
            }
            
            if peer.hasAdminRights(.canAddAdmins) {
                entries.append(.addAdmin(presentationData.theme, presentationData.strings.Channel_Management_AddModerator, state.editing))
                entries.append(.adminsInfo(presentationData.theme, presentationData.strings.Channel_Management_AddModeratorHelp))
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
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updateAdministrationDisposable = MetaDisposable()
    actionsDisposable.add(updateAdministrationDisposable)

    let removeAdminDisposable = MetaDisposable()
    actionsDisposable.add(removeAdminDisposable)
    
    let addAdminDisposable = MetaDisposable()
    actionsDisposable.add(addAdminDisposable)
    
    let adminsPromise = Promise<[RenderedChannelParticipant]?>(nil)
    
    let presentationDataSignal = (account.applicationContext as! TelegramApplicationContext).presentationData
    
    let arguments = ChannelAdminsControllerArguments(account: account, updateCurrentAdministrationType: {
        let _ = (presentationDataSignal |> take(1) |> deliverOnMainQueue).start(next: { presentationData in
            let actionSheet = ActionSheetController()
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
        let applyPeers: Signal<Void, NoError> = adminsPromise.get()
            |> filter { $0 != nil }
            |> take(1)
            |> deliverOnMainQueue
            |> mapToSignal { peers -> Signal<Void, NoError> in
                if let peers = peers {
                    var updatedPeers = peers
                    for i in 0 ..< updatedPeers.count {
                        if updatedPeers[i].peer.id == adminId {
                            updatedPeers.remove(at: i)
                            break
                        }
                    }
                    adminsPromise.set(.single(updatedPeers))
                }
                
                return .complete()
        }

        removeAdminDisposable.set((removePeerAdmin(account: account, peerId: peerId, adminId: adminId)
            |> then(applyPeers |> mapError { _ -> RemovePeerAdminError in return .generic }) |> deliverOnMainQueue).start(error: { _ in
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
        }, completed: {
            updateState { state in
                var updatedTemporaryAdmins = state.temporaryAdmins
                for i in 0 ..< updatedTemporaryAdmins.count {
                    if updatedTemporaryAdmins[i].peer.id == adminId {
                        updatedTemporaryAdmins.remove(at: i)
                        break
                    }
                }
                return state.withUpdatedRemovingPeerId(nil).withUpdatedTemporaryAdmins(updatedTemporaryAdmins)
            }
        }))
    }, addAdmin: {
        presentControllerImpl?(ChannelMembersSearchController(account: account, peerId: peerId, openPeer: { peer in
            presentControllerImpl?(channelAdminController(account: account, peerId: peerId, adminId: peer.id, initialParticipant: nil, updated: { updatedRights in
                let applyAdmin: Signal<Void, NoError> = adminsPromise.get()
                    |> filter { $0 != nil }
                    |> take(1)
                    |> deliverOnMainQueue
                    |> mapToSignal { admins -> Signal<Void, NoError> in
                        if let admins = admins {
                            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                            
                            var updatedAdmins = admins
                            if updatedRights.isEmpty {
                                for i in 0 ..< updatedAdmins.count {
                                    if updatedAdmins[i].peer.id == peer.id {
                                        updatedAdmins.remove(at: i)
                                        break
                                    }
                                }
                            } else {
                                var found = false
                                for i in 0 ..< updatedAdmins.count {
                                    if updatedAdmins[i].peer.id == peer.id {
                                        if case let .member(id, date, _, banInfo) = updatedAdmins[i].participant {
                                            updatedAdmins[i] = RenderedChannelParticipant(participant: .member(id: id, invitedAt: date, adminInfo: ChannelParticipantAdminInfo(rights: updatedRights, promotedBy: account.peerId, canBeEditedByAccountPeer: true), banInfo: banInfo), peer: updatedAdmins[i].peer, peers: [:])
                                        }
                                        found = true
                                        break
                                    }
                                }
                                if !found {
                                    updatedAdmins.append(RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: timestamp, adminInfo: ChannelParticipantAdminInfo(rights: updatedRights, promotedBy: account.peerId, canBeEditedByAccountPeer: true), banInfo: nil), peer: peer, peers: [:]))
                                }
                            }
                            adminsPromise.set(.single(updatedAdmins))
                        }
                        
                        return .complete()
                }
                addAdminDisposable.set(applyAdmin.start())
            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openAdmin: { participant in
        if case let .member(adminId, _, _, _) = participant {
            presentControllerImpl?(channelAdminController(account: account, peerId: peerId, adminId: participant.peerId, initialParticipant: participant, updated: { updatedRights in
                let applyAdmin: Signal<Void, NoError> = adminsPromise.get()
                    |> filter { $0 != nil }
                    |> take(1)
                    |> deliverOnMainQueue
                    |> mapToSignal { admins -> Signal<Void, NoError> in
                        if let admins = admins {
                            var updatedAdmins = admins
                            if updatedRights.isEmpty {
                                for i in 0 ..< updatedAdmins.count {
                                    if updatedAdmins[i].peer.id == adminId {
                                        updatedAdmins.remove(at: i)
                                        break
                                    }
                                }
                            } else {
                                var found = false
                                for i in 0 ..< updatedAdmins.count {
                                    if updatedAdmins[i].peer.id == adminId {
                                        if case let .member(id, date, _, banInfo) = updatedAdmins[i].participant {
                                            updatedAdmins[i] = RenderedChannelParticipant(participant: .member(id: id, invitedAt: date, adminInfo: ChannelParticipantAdminInfo(rights: updatedRights, promotedBy: account.peerId, canBeEditedByAccountPeer: true), banInfo: banInfo), peer: updatedAdmins[i].peer, peers: [:])
                                        }
                                        found = true
                                        break
                                    }
                                }
                                if !found {
                                    //updatedAdmins.append(RenderedChannelParticipant(participant: .member(id, date, adminInfo: ChannelParticipantAdminInfo(rights: updatedRights, promotedBy: account.peerId, canBeEditedByAccountPeer: true), banInfo: banInfo), peer: peer))
                                }
                            }
                            adminsPromise.set(.single(updatedAdmins))
                        }
                        
                        return .complete()
                    }
                addAdminDisposable.set(applyAdmin.start())
            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }
    })
    
    let peerView = account.viewTracker.peerView(peerId) |> deliverOnMainQueue
    
    let adminsSignal: Signal<[RenderedChannelParticipant]?, NoError> = .single(nil) |> then(channelAdmins(account: account, peerId: peerId) |> map { Optional($0) })
    
    adminsPromise.set(adminsSignal)
    
    var previousPeers: [RenderedChannelParticipant]?
    
    let signal = combineLatest(presentationDataSignal, statePromise.get(), peerView, adminsPromise.get() |> deliverOnMainQueue)
        |> deliverOnMainQueue
        |> map { presentationData, state, view, admins -> (ItemListControllerState, (ItemListNodeState<ChannelAdminsEntry>, ChannelAdminsEntry.ItemGenerationArguments)) in
            var rightNavigationButton: ItemListNavigationButton?
            if let admins = admins, admins.count > 1 {
                if state.editing {
                    rightNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Done, style: .bold, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedEditing(false)
                        }
                    })
                } else if let peer = view.peers[peerId] as? TelegramChannel, peer.flags.contains(.isCreator) {
                    rightNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Edit, style: .regular, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedEditing(true)
                        }
                    })
                }
            }
            
            let previous = previousPeers
            previousPeers = admins
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.ChatAdmins_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: nil, animateChanges: true)
            let listState = ItemListNodeState(entries: channelAdminsControllerEntries(presentationData: presentationData, accountPeerId: account.peerId, view: view, state: state, participants: admins), style: .blocks, animateChanges: previous != nil && admins != nil && previous!.count >= admins!.count)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(account: account, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window, with: p)
        }
    }
    return controller
}
