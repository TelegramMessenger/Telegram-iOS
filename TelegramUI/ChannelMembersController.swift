import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChannelMembersControllerArguments {
    let account: Account
    
    let addMember: () -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removePeer: (PeerId) -> Void
    
    init(account: Account, addMember: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removePeer: @escaping (PeerId) -> Void) {
        self.account = account
        self.addMember = addMember
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
    }
}

private enum ChannelMembersSection: Int32 {
    case addMembers
    case peers
}

private enum ChannelMembersEntryStableId: Hashable {
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
    
    static func ==(lhs: ChannelMembersEntryStableId, rhs: ChannelMembersEntryStableId) -> Bool {
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

private enum ChannelMembersEntry: ItemListNodeEntry {
    case addMember
    case addMemberInfo
    case peerItem(Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .addMember, .addMemberInfo:
                return ChannelMembersSection.addMembers.rawValue
            case .peerItem:
                return ChannelMembersSection.peers.rawValue
        }
    }
    
    var stableId: ChannelMembersEntryStableId {
        switch self {
            case .addMember:
                return .index(0)
            case .addMemberInfo:
                return .index(1)
            case let .peerItem(_, participant, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelMembersEntry, rhs: ChannelMembersEntry) -> Bool {
        switch lhs {
            case .addMember, .addMemberInfo:
                return lhs.stableId == rhs.stableId
            case let .peerItem(lhsIndex, lhsParticipant, lhsEditing, lhsEnabled):
                if case let .peerItem(rhsIndex, rhsParticipant, rhsEditing, rhsEnabled) = rhs {
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
        }
    }
    
    static func <(lhs: ChannelMembersEntry, rhs: ChannelMembersEntry) -> Bool {
        switch lhs {
            case .addMember:
                return true
            case .addMemberInfo:
                switch rhs {
                    case .addMember:
                        return false
                    default:
                        return true
                }
            case let .peerItem(index, _, _, _):
                switch rhs {
                    case let .peerItem(rhsIndex, _, _, _):
                        return index < rhsIndex
                    case .addMember, .addMemberInfo:
                        return false
                }
        }
    }
    
    func item(_ arguments: ChannelMembersControllerArguments) -> ListViewItem {
        switch self {
            case .addMember:
                return ItemListActionItem(title: "Add Members", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.addMember()
                })
            case .addMemberInfo:
                return ItemListTextItem(text: .plain("Only channel admins can see this list."), sectionId: self.section)
            case let .peerItem(_, participant, editing, enabled):
                return ItemListPeerItem(account: arguments.account, peer: participant.peer, presence: nil, text: .none, label: .none, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
        }
    }
}

private struct ChannelMembersControllerState: Equatable {
    let editing: Bool
    let peerIdWithRevealedOptions: PeerId?
    let removingPeerId: PeerId?
    
    init() {
        self.editing = false
        self.peerIdWithRevealedOptions = nil
        self.removingPeerId = nil
    }
    
    init(editing: Bool, peerIdWithRevealedOptions: PeerId?, removingPeerId: PeerId?) {
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.removingPeerId = removingPeerId
    }
    
    static func ==(lhs: ChannelMembersControllerState, rhs: ChannelMembersControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.removingPeerId != rhs.removingPeerId {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelMembersControllerState {
        return ChannelMembersControllerState(editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelMembersControllerState {
        return ChannelMembersControllerState(editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelMembersControllerState {
        return ChannelMembersControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: removingPeerId)
    }
}

private func ChannelMembersControllerEntries(account: Account, view: PeerView, state: ChannelMembersControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelMembersEntry] {
    var entries: [ChannelMembersEntry] = []
    
    if let participants = participants {
        entries.append(.addMember)
        entries.append(.addMemberInfo)
        
        var index: Int32 = 0
        for participant in participants.sorted(by: { lhs, rhs in
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
            var editable = true
            var canEditMembers = false
            if let peer = view.peers[view.peerId] as? TelegramChannel {
                canEditMembers = peer.hasAdminRights(.canBanUsers)
            }
            
            if participant.peer.id == account.peerId {
                editable = false
            } else {
                switch participant.participant {
                    case .creator:
                        editable = false
                    case .member:
                        editable = canEditMembers
                }
            }
            entries.append(.peerItem(index, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id))
            index += 1
        }
    }
    
    return entries
}

public func channelMembersController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelMembersControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelMembersControllerState())
    let updateState: ((ChannelMembersControllerState) -> ChannelMembersControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let addMembersDisposable = MetaDisposable()
    actionsDisposable.add(addMembersDisposable)
    
    let removePeerDisposable = MetaDisposable()
    actionsDisposable.add(removePeerDisposable)
    
    let peersPromise = Promise<[RenderedChannelParticipant]?>(nil)
    
    let arguments = ChannelMembersControllerArguments(account: account, addMember: {
        var confirmationImpl: ((PeerId) -> Signal<Bool, NoError>)?
        let contactsController = ContactSelectionController(account: account, title: { $0.GroupInfo_AddParticipantTitle }, confirmation: { peerId in
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
                        let alertController = standardTextAlertController(title: nil, text: "Add \(peer.displayTitle)?", actions: [
                            TextAlertAction(type: .genericAction, title: "Cancel", action: {
                                result.set(false)
                            }),
                            TextAlertAction(type: .defaultAction, title: "OK", action: {
                                result.set(true)
                            })
                        ])
                        contactsController.present(alertController, in: .window(.root))
                    }
                    
                    return result.get()
            }
        }
        
        let addMember = contactsController.result
            |> mapError { _ -> AddPeerMemberError in return .generic }
            |> deliverOnMainQueue
            |> mapToSignal { memberId -> Signal<Void, AddPeerMemberError> in
                if let memberId = memberId {
                    let applyMembers: Signal<Void, AddPeerMemberError> = peersPromise.get()
                        |> filter { $0 != nil }
                        |> take(1)
                        |> mapToSignal { peers -> Signal<Void, NoError> in
                            return account.postbox.modify { modifier -> Peer? in
                                return modifier.getPeer(memberId)
                            }
                            |> deliverOnMainQueue
                            |> mapToSignal { peer -> Signal<Void, NoError> in
                                if let peer = peer, let peers = peers {
                                    var updatedPeers = peers
                                    var found = false
                                    for i in 0 ..< updatedPeers.count {
                                        if updatedPeers[i].peer.id == memberId {
                                            found = true
                                            break
                                        }
                                    }
                                    if !found {
                                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                        updatedPeers.append(RenderedChannelParticipant(participant: ChannelParticipant.member(id: peer.id, invitedAt: timestamp, adminInfo: nil, banInfo: nil), peer: peer, peers: [:]))
                                        peersPromise.set(.single(updatedPeers))
                                    }
                                }
                                return .complete()
                            }
                        }
                        |> mapError { _ -> AddPeerMemberError in return .generic }
                
                    return addPeerMember(account: account, peerId: peerId, memberId: memberId)
                        |> then(applyMembers)
                } else {
                    return .complete()
                }
        }
        presentControllerImpl?(contactsController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        addMembersDisposable.set(addMember.start())
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, removePeer: { memberId in
        updateState {
            return $0.withUpdatedRemovingPeerId(memberId)
        }
        
        let applyPeers: Signal<Void, NoError> = peersPromise.get()
            |> filter { $0 != nil }
            |> take(1)
            |> deliverOnMainQueue
            |> mapToSignal { peers -> Signal<Void, NoError> in
                if let peers = peers {
                    var updatedPeers = peers
                    for i in 0 ..< updatedPeers.count {
                        if updatedPeers[i].peer.id == memberId {
                            updatedPeers.remove(at: i)
                            break
                        }
                    }
                    peersPromise.set(.single(updatedPeers))
                }
                
                return .complete()
        }
        
        removePeerDisposable.set((removePeerMember(account: account, peerId: peerId, memberId: memberId) |> then(applyPeers) |> deliverOnMainQueue).start(error: { _ in
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
        }, completed: {
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
            
        }))
    })
    
    let peerView = account.viewTracker.peerView(peerId)
    
    let peersSignal: Signal<[RenderedChannelParticipant]?, NoError> = .single(nil) |> then(channelMembers(account: account, peerId: peerId) |> map { Optional($0) })
    
    peersPromise.set(peersSignal)
    
    var previousPeers: [RenderedChannelParticipant]?
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), peerView, peersPromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state, view, peers -> (ItemListControllerState, (ItemListNodeState<ChannelMembersEntry>, ChannelMembersEntry.ItemGenerationArguments)) in
            var rightNavigationButton: ItemListNavigationButton?
            if let peers = peers, !peers.isEmpty {
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
            
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if peers == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem()
            }
            
            let previous = previousPeers
            previousPeers = peers
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Members"), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: "Back"), animateChanges: true)
            let listState = ItemListNodeState(entries: ChannelMembersControllerEntries(account: account, view: view, state: state, participants: peers), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && peers != nil && previous!.count >= peers!.count)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    return controller
}
