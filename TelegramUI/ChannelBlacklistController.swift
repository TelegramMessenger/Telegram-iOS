import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChannelBlacklistControllerArguments {
    let account: Account
    
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removePeer: (PeerId) -> Void
    
    init(account: Account, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removePeer: @escaping (PeerId) -> Void) {
        self.account = account
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
    }
}

private enum ChannelBlacklistSection: Int32 {
    case peers
}

private enum ChannelBlacklistEntryStableId: Hashable {
    case peer(PeerId)
    
    var hashValue: Int {
        switch self {
            case let .peer(peerId):
                return peerId.hashValue
        }
    }
    
    static func ==(lhs: ChannelBlacklistEntryStableId, rhs: ChannelBlacklistEntryStableId) -> Bool {
        switch lhs {
            case let .peer(peerId):
                if case .peer(peerId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum ChannelBlacklistEntry: ItemListNodeEntry {
    case peerItem(Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .peerItem:
                return ChannelBlacklistSection.peers.rawValue
        }
    }
    
    var stableId: ChannelBlacklistEntryStableId {
        switch self {
            case let .peerItem(_, participant, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelBlacklistEntry, rhs: ChannelBlacklistEntry) -> Bool {
        switch lhs {
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
    
    static func <(lhs: ChannelBlacklistEntry, rhs: ChannelBlacklistEntry) -> Bool {
        switch lhs {
            case let .peerItem(index, _, _, _):
                switch rhs {
                    case let .peerItem(rhsIndex, _, _, _):
                        return index < rhsIndex
                }
        }
    }
    
    func item(_ arguments: ChannelBlacklistControllerArguments) -> ListViewItem {
        switch self {
            case let .peerItem(_, participant, editing, enabled):
                return ItemListPeerItem(account: arguments.account, peer: participant.peer, presence: nil, text: .none, label: .none, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
        }
    }
}

private struct ChannelBlacklistControllerState: Equatable {
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
    
    static func ==(lhs: ChannelBlacklistControllerState, rhs: ChannelBlacklistControllerState) -> Bool {
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
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: removingPeerId)
    }
}

private func channelBlacklistControllerEntries(view: PeerView, state: ChannelBlacklistControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelBlacklistEntry] {
    var entries: [ChannelBlacklistEntry] = []
    
    if let participants = participants {
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
            if case .creator = participant.participant {
                editable = false
            }
            entries.append(.peerItem(index, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id))
            index += 1
        }
    }
    
    return entries
}

public func channelBlacklistController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelBlacklistControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelBlacklistControllerState())
    let updateState: ((ChannelBlacklistControllerState) -> ChannelBlacklistControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updateAdministrationDisposable = MetaDisposable()
    actionsDisposable.add(updateAdministrationDisposable)
    
    let removePeerDisposable = MetaDisposable()
    actionsDisposable.add(removePeerDisposable)
    
    let peersPromise = Promise<[RenderedChannelParticipant]?>(nil)
    
    let arguments = ChannelBlacklistControllerArguments(account: account, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
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
        
        removePeerDisposable.set((removeChannelBlacklistedPeer(account: account, peerId: peerId, memberId: memberId) |> then(applyPeers) |> deliverOnMainQueue).start(error: { _ in
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
    
    let peersSignal: Signal<[RenderedChannelParticipant]?, NoError> = .single(nil) |> then(channelBlacklist(account: account, peerId: peerId) |> map { Optional($0) })
    
    peersPromise.set(peersSignal)
    
    var previousPeers: [RenderedChannelParticipant]?
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), peerView, peersPromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state, view, peers -> (ItemListControllerState, (ItemListNodeState<ChannelBlacklistEntry>, ChannelBlacklistEntry.ItemGenerationArguments)) in
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
            if let peers = peers {
                if peers.isEmpty {
                    if let peer = view.peers[view.peerId] as? TelegramChannel {
                        if case .group = peer.info {
                            emptyStateItem = ItemListTextEmptyStateItem(text: "Blacklisted users are removed from the group and can only come back if invited by an admin. Invite links don't work for them.")
                        } else {
                            emptyStateItem = ItemListTextEmptyStateItem(text: "Blacklisted users are removed from the channel and can only come back if invited by an admin. Invite links don't work for them.")
                        }
                    }
                }
            } else if peers == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem()
            }
            
            let previous = previousPeers
            previousPeers = peers
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Blacklist"), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: "Back"), animateChanges: true)
            let listState = ItemListNodeState(entries: channelBlacklistControllerEntries(view: view, state: state, participants: peers), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && peers != nil && previous!.count >= peers!.count)
            
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
