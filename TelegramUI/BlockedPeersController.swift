import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class BlockedPeersControllerArguments {
    let account: Account
    
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removePeer: (PeerId) -> Void
    
    init(account: Account, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removePeer: @escaping (PeerId) -> Void) {
        self.account = account
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
    }
}

private enum BlockedPeersSection: Int32 {
    case peers
}

private enum BlockedPeersEntryStableId: Hashable {
    case peer(PeerId)
    
    var hashValue: Int {
        switch self {
            case let .peer(peerId):
                return peerId.hashValue
        }
    }
    
    static func ==(lhs: BlockedPeersEntryStableId, rhs: BlockedPeersEntryStableId) -> Bool {
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

private enum BlockedPeersEntry: ItemListNodeEntry {
    case peerItem(Int32, PresentationTheme, PresentationStrings, Peer, ItemListPeerItemEditing, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .peerItem:
                return BlockedPeersSection.peers.rawValue
        }
    }
    
    var stableId: BlockedPeersEntryStableId {
        switch self {
            case let .peerItem(_, _, _, peer, _, _):
                return .peer(peer.id)
        }
    }
    
    static func ==(lhs: BlockedPeersEntry, rhs: BlockedPeersEntry) -> Bool {
        switch lhs {
        case let .peerItem(lhsIndex, lhsTheme, lhsStrings, lhsPeer, lhsEditing, lhsEnabled):
            if case let .peerItem(rhsIndex, rhsTheme, rhsStrings, rhsPeer, rhsEditing, rhsEnabled) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsTheme !== rhsTheme {
                    return false
                }
                if lhsStrings !== rhsStrings {
                    return false
                }
                if !lhsPeer.isEqual(rhsPeer) {
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
    
    static func <(lhs: BlockedPeersEntry, rhs: BlockedPeersEntry) -> Bool {
        switch lhs {
            case let .peerItem(index, _, _, _, _, _):
                switch rhs {
                    case let .peerItem(rhsIndex, _, _, _, _, _):
                        return index < rhsIndex
                }
        }
    }
    
    func item(_ arguments: BlockedPeersControllerArguments) -> ListViewItem {
        switch self {
            case let .peerItem(_, theme, strings, peer, editing, enabled):
                return ItemListPeerItem(theme: theme, strings: strings, account: arguments.account, peer: peer, presence: nil, text: .none, label: .none, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
        }
    }
}

private struct BlockedPeersControllerState: Equatable {
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
    
    static func ==(lhs: BlockedPeersControllerState, rhs: BlockedPeersControllerState) -> Bool {
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
    
    func withUpdatedEditing(_ editing: Bool) -> BlockedPeersControllerState {
        return BlockedPeersControllerState(editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> BlockedPeersControllerState {
        return BlockedPeersControllerState(editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> BlockedPeersControllerState {
        return BlockedPeersControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: removingPeerId)
    }
}

private func blockedPeersControllerEntries(presentationData: PresentationData, state: BlockedPeersControllerState, peers: [Peer]?) -> [BlockedPeersEntry] {
    var entries: [BlockedPeersEntry] = []
    
    if let peers = peers {
        var index: Int32 = 0
        for peer in peers {
            entries.append(.peerItem(index, presentationData.theme, presentationData.strings, peer, ItemListPeerItemEditing(editable: true, editing: state.editing, revealed: peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != peer.id))
            index += 1
        }
    }
    
    return entries
}

public func blockedPeersController(account: Account) -> ViewController {
    let statePromise = ValuePromise(BlockedPeersControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: BlockedPeersControllerState())
    let updateState: ((BlockedPeersControllerState) -> BlockedPeersControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let removePeerDisposable = MetaDisposable()
    actionsDisposable.add(removePeerDisposable)
    
    let peersPromise = Promise<[Peer]?>(nil)
    
    let arguments = BlockedPeersControllerArguments(account: account, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
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
                        if updatedPeers[i].id == memberId {
                            updatedPeers.remove(at: i)
                            break
                        }
                    }
                    peersPromise.set(.single(updatedPeers))
                }
                
                return .complete()
        }
        
        removePeerDisposable.set((requestUpdatePeerIsBlocked(account: account, peerId: memberId, isBlocked: false) |> then(applyPeers) |> deliverOnMainQueue).start(error: { _ in
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
        }, completed: {
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
            
        }))
    })
    
    let peersSignal: Signal<[Peer]?, NoError> = .single(nil) |> then(requestBlockedPeers(account: account) |> map { Optional($0) })
    
    peersPromise.set(peersSignal)
    
    var previousPeers: [Peer]?
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), peersPromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state, peers -> (ItemListControllerState, (ItemListNodeState<BlockedPeersEntry>, BlockedPeersEntry.ItemGenerationArguments)) in
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
                    emptyStateItem = ItemListTextEmptyStateItem(text: "Blocked users can't send you messages of add you to groups. They will not see your profile pictures, online and last seen status.")
                }
            } else if peers == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem()
            }
            
            let previous = previousPeers
            previousPeers = peers
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Blocked Users"), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: "Back"), animateChanges: true)
            let listState = ItemListNodeState(entries: blockedPeersControllerEntries(presentationData: presentationData, state: state, peers: peers), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && peers != nil && previous!.count >= peers!.count)
            
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
