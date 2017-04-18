import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let addMemberPlusIcon = UIImage(bundleImageName: "Peer Info/PeerItemPlusIcon")?.precomposed()

private final class ChannelAdminsControllerArguments {
    let account: Account
    
    let updateCurrentAdministrationType: () -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removeAdmin: (PeerId) -> Void
    let addAdmin: () -> Void
    
    init(account: Account, updateCurrentAdministrationType: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removeAdmin: @escaping (PeerId) -> Void, addAdmin: @escaping () -> Void) {
        self.account = account
        self.updateCurrentAdministrationType = updateCurrentAdministrationType
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removeAdmin = removeAdmin
        self.addAdmin = addAdmin
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
    case administrationType(CurrentAdministrationType)
    case administrationInfo(String)
    
    case adminsHeader(String)
    case adminPeerItem(Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool)
    case addAdmin(Bool)
    case adminsInfo(String)
    
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
            case let .adminPeerItem(_, participant, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelAdminsEntry, rhs: ChannelAdminsEntry) -> Bool {
        switch lhs {
            case let .administrationType(type):
                if case .administrationType(type) = rhs {
                    return true
                } else {
                    return false
                }
            case let .administrationInfo(text):
                if case .administrationInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .adminsHeader(title):
                if case .adminsHeader(title) = rhs {
                    return true
                } else {
                    return false
                }
            case let .adminPeerItem(lhsIndex, lhsParticipant, lhsEditing, lhsEnabled):
                if case let .adminPeerItem(rhsIndex, rhsParticipant, rhsEditing, rhsEnabled) = rhs {
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
            case let .adminsInfo(text):
                if case .adminsInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .addAdmin(editing):
                if case .addAdmin(editing) = rhs {
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
            case let .adminPeerItem(index, _, _, _):
                switch rhs {
                    case .administrationType, .administrationInfo, .adminsHeader:
                        return false
                    case let .adminPeerItem(rhsIndex, _, _, _):
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
            case let .administrationType(type):
                let label: String
                switch type {
                    case .adminsCanAddMembers:
                        label = "Only Admins"
                    case .everyoneCanAddMembers:
                        label = "All Members"
                }
                return ItemListDisclosureItem(title: "Who can add members", label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.updateCurrentAdministrationType()
                })
            case let .administrationInfo(text):
                return ItemListTextItem(text: .plain(text), sectionId: self.section)
            case let .adminsHeader(title):
                return ItemListSectionHeaderItem(text: title, sectionId: self.section)
            case let .adminPeerItem(_, participant, editing, enabled):
                let peerText: String
                switch participant.participant {
                    case .creator:
                        peerText = "Creator"
                    default:
                        peerText = "Moderator"
                }
                return ItemListPeerItem(account: arguments.account, peer: participant.peer, presence: nil, text: .text(peerText), label: .none, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removeAdmin(peerId)
                })
            case let .addAdmin(editing):
                return ItemListPeerActionItem(icon: addMemberPlusIcon, title: "Add Admin", sectionId: self.section, editing: editing, action: {
                    arguments.addAdmin()
                })
            case let .adminsInfo(text):
                return ItemListTextItem(text: .plain(text), sectionId: self.section)
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

private func ChannelAdminsControllerEntries(view: PeerView, state: ChannelAdminsControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelAdminsEntry] {
    var entries: [ChannelAdminsEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var isGroup = false
        if case let .group(info) = peer.info {
            isGroup = true
            
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
            
            entries.append(.administrationType(selectedType))
            let infoText: String
            switch selectedType {
                case .everyoneCanAddMembers:
                    infoText = "Everybody can add new members"
                case .adminsCanAddMembers:
                    infoText = "Only Admins can add new mebers"
            }
            entries.append(.administrationInfo(infoText))
        }
        
        if let participants = participants {
            entries.append(.adminsHeader(isGroup ? "GROUP ADMINS" : "CHANNEL ADMINS"))
            
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
                    case let .editor(_, _, invitedAt):
                        lhsInvitedAt = invitedAt
                    case let .moderator(_, _, invitedAt):
                        lhsInvitedAt = invitedAt
                    case let .member(_, invitedAt):
                        lhsInvitedAt = invitedAt
                }
                let rhsInvitedAt: Int32
                switch rhs.participant {
                    case .creator:
                        rhsInvitedAt = Int32.min
                    case let .editor(_, _, invitedAt):
                        rhsInvitedAt = invitedAt
                    case let .moderator(_, _, invitedAt):
                        rhsInvitedAt = invitedAt
                    case let .member(_, invitedAt):
                        rhsInvitedAt = invitedAt
                }
                return lhsInvitedAt < rhsInvitedAt
            }) {
                if !state.removedPeerIds.contains(participant.peer.id) {
                    var editable = true
                    if case .creator = participant.participant {
                        editable = false
                    }
                    entries.append(.adminPeerItem(index, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), existingParticipantIds.contains(participant.peer.id)))
                    index += 1
                }
            }
            
            entries.append(.addAdmin(state.editing))
            entries.append(.adminsInfo(isGroup ? "You can add admins to help you manage your group" : "You can add admins to help you manage your channel"))
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
    
    let arguments = ChannelAdminsControllerArguments(account: account, updateCurrentAdministrationType: {
        let actionSheet = ActionSheetController()
        let result = ValuePromise<Bool>()
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: "All Members", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                result.set(true)
            }),
            ActionSheetButtonItem(title: "Only Admins", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                result.set(false)
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
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
        var confirmationImpl: ((PeerId) -> Signal<Bool, NoError>)?
        let contactsController = ContactSelectionController(account: account, title: "Add admin", confirmation: { peerId in
            if let confirmationImpl = confirmationImpl {
                return confirmationImpl(peerId)
            } else {
                return .single(false)
            }
        })
        confirmationImpl = { [weak contactsController] peerId in
            return account.postbox.loadedPeerWithId(peerId)
                |> deliverOnMainQueue
                |> mapToSignal { peer in
                    let result = ValuePromise<Bool>()
                    if let contactsController = contactsController {
                        let alertController = standardTextAlertController(title: nil, text: "Add \(peer.displayTitle) as admin?", actions: [
                            TextAlertAction(type: .genericAction, title: "Cancel", action: {
                                result.set(false)
                            }),
                            TextAlertAction(type: .defaultAction, title: "OK", action: {
                                result.set(true)
                            })
                        ])
                        contactsController.present(alertController, in: .window)
                    }
                    
                    return result.get()
            }
        }
        let addAdmin = contactsController.result
            |> deliverOnMainQueue
            |> mapToSignal { memberId -> Signal<Void, NoError> in
                if let memberId = memberId {
                    return account.postbox.peerView(id: memberId)
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { view -> Signal<Void, NoError> in
                            if let peer = view.peers[memberId] {
                                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                
                                updateState { state in
                                    var found = false
                                    for participant in state.temporaryAdmins {
                                        if participant.peer.id == memberId {
                                            found = true
                                            break
                                        }
                                    }
                                    var removedPeerIds = state.removedPeerIds
                                    removedPeerIds.remove(memberId)
                                    if !found {
                                        var temporaryAdmins = state.temporaryAdmins
                                        temporaryAdmins.append(RenderedChannelParticipant(participant: ChannelParticipant.moderator(id: peer.id, invitedBy: account.peerId, invitedAt: timestamp), peer: peer))
                                        return state.withUpdatedTemporaryAdmins(temporaryAdmins).withUpdatedRemovedPeerIds(removedPeerIds)
                                    } else {
                                        return state.withUpdatedRemovedPeerIds(removedPeerIds)
                                    }
                                }
                                
                                let applyAdmin: Signal<Void, AddPeerAdminError> = adminsPromise.get()
                                    |> filter { $0 != nil }
                                    |> take(1)
                                    |> deliverOnMainQueue
                                    |> mapError { _ -> AddPeerAdminError in return .generic }
                                    |> mapToSignal { admins -> Signal<Void, AddPeerAdminError> in
                                        if let admins = admins {
                                            var updatedAdmins = admins
                                            var found = false
                                            for i in 0 ..< updatedAdmins.count {
                                                if updatedAdmins[i].peer.id == memberId {
                                                    found = true
                                                    break
                                                }
                                            }
                                            if !found {
                                                updatedAdmins.append(RenderedChannelParticipant(participant: ChannelParticipant.moderator(id: peer.id, invitedBy: account.peerId, invitedAt: timestamp), peer: peer))
                                                adminsPromise.set(.single(updatedAdmins))
                                            }
                                        }
                                        
                                        return .complete()
                                    }
                            
                                return addPeerAdmin(account: account, peerId: peerId, adminId: memberId)
                                    |> deliverOnMainQueue
                                    |> then(applyAdmin)
                                    |> `catch` { _ -> Signal<Void, NoError> in
                                        updateState { state in
                                            var temporaryAdmins = state.temporaryAdmins
                                            for i in 0 ..< temporaryAdmins.count {
                                                if temporaryAdmins[i].peer.id == memberId {
                                                    temporaryAdmins.remove(at: i)
                                                    break
                                                }
                                            }
                                            
                                            return state.withUpdatedTemporaryAdmins(temporaryAdmins)
                                        }
                                        return .complete()
                                    }
                            } else {
                                return .complete()
                            }
                    }
                } else {
                    return .complete()
                }
        }
        presentControllerImpl?(contactsController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        addAdminDisposable.set(addAdmin.start())
    })
    
    let peerView = account.viewTracker.peerView(peerId) |> deliverOnMainQueue
    
    let adminsSignal: Signal<[RenderedChannelParticipant]?, NoError> = .single(nil) |> then(channelAdmins(account: account, peerId: peerId) |> map { Optional($0) })
    
    adminsPromise.set(adminsSignal)
    
    var previousPeers: [RenderedChannelParticipant]?
    
    let signal = combineLatest(statePromise.get(), peerView, adminsPromise.get() |> deliverOnMainQueue)
        |> deliverOnMainQueue
        |> map { state, view, admins -> (ItemListControllerState, (ItemListNodeState<ChannelAdminsEntry>, ChannelAdminsEntry.ItemGenerationArguments)) in
            var rightNavigationButton: ItemListNavigationButton?
            if let admins = admins, admins.count > 1 {
                if state.editing {
                    rightNavigationButton = ItemListNavigationButton(title: "Done", style: .bold, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedEditing(false)
                        }
                    })
                } else {
                    rightNavigationButton = ItemListNavigationButton(title: "Edit", style: .regular, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedEditing(true)
                        }
                    })
                }
            }
            
            let previous = previousPeers
            previousPeers = admins
            
            let controllerState = ItemListControllerState(title: .text("Admins"), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, animateChanges: true)
            let listState = ItemListNodeState(entries: ChannelAdminsControllerEntries(view: view, state: state, participants: admins), style: .blocks, animateChanges: previous != nil && admins != nil && previous!.count >= admins!.count)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window, with: p)
        }
    }
    return controller
}
