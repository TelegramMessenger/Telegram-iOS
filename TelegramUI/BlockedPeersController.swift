import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class BlockedPeersControllerArguments {
    let account: Account
    
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let addPeer: () -> Void
    let removePeer: (PeerId) -> Void
    let openPeer: (Peer) -> Void
    
    init(account: Account, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addPeer: @escaping () -> Void, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping (Peer) -> Void) {
        self.account = account
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.addPeer = addPeer
        self.removePeer = removePeer
        self.openPeer = openPeer
    }
}

private enum BlockedPeersSection: Int32 {
    case actions
    case peers
}

private enum BlockedPeersEntryStableId: Hashable {
    case add
    case peer(PeerId)
}

private enum BlockedPeersEntry: ItemListNodeEntry {
    case add(PresentationTheme, String)
    case peerItem(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, ItemListPeerItemEditing, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .add:
                return BlockedPeersSection.actions.rawValue
            case .peerItem:
                return BlockedPeersSection.peers.rawValue
        }
    }
    
    var stableId: BlockedPeersEntryStableId {
        switch self {
            case .add:
                return .add
            case let .peerItem(_, _, _, _, peer, _, _):
                return .peer(peer.id)
        }
    }
    
    static func ==(lhs: BlockedPeersEntry, rhs: BlockedPeersEntry) -> Bool {
        switch lhs {
            case let .add(lhsTheme, lhsText):
                if case let .add(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .peerItem(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsEditing, lhsEnabled):
                if case let .peerItem(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsEditing, rhsEnabled) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
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
            case .add:
                if case .add = rhs {
                    return true
                } else {
                    return false
                }
            case let .peerItem(index, _, _, _, _, _, _):
                switch rhs {
                    case .add:
                        return false
                    case let .peerItem(rhsIndex, _, _, _, _, _, _):
                        return index < rhsIndex
                }
        }
    }
    
    func item(_ arguments: BlockedPeersControllerArguments) -> ListViewItem {
        switch self {
            case let .add(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.addPeer()
                })
            case let .peerItem(_, theme, strings, dateTimeFormat, peer, editing, enabled):
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, account: arguments.account, peer: peer, presence: nil, text: .none, label: .none, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: {
                    arguments.openPeer(peer)
                }, setPeerIdWithRevealedOptions: { previousId, id in
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
        entries.append(.add(presentationData.theme, presentationData.strings.Conversation_BlockUser))
        
        var index: Int32 = 0
        for peer in peers {
            entries.append(.peerItem(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, ItemListPeerItemEditing(editable: true, editing: state.editing, revealed: peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != peer.id))
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
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
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
    }, addPeer: {
        let controller = PeerSelectionController(account: account, filter: [.onlyUsers])
        controller.peerSelected = { [weak controller] peerId in
            if let strongController = controller {
                strongController.inProgress = true
                
                let _ = (account.viewTracker.peerView(peerId)
                |> take(1)
                |> map { view -> Peer? in
                    return peerViewMainPeer(view)
                }
                |> deliverOnMainQueue).start(next: { peer in
                    let applyPeers: Signal<Void, NoError> = peersPromise.get()
                    |> filter { $0 != nil }
                    |> take(1)
                    |> map { peers -> ([Peer]?, Peer?) in
                        return (peers, peer)
                    }
                    |> deliverOnMainQueue
                    |> mapToSignal { peers, peer -> Signal<Void, NoError> in
                        if let peers = peers, let peer = peer {
                            var updatedPeers = peers
                            for i in 0 ..< updatedPeers.count {
                                if updatedPeers[i].id == peer.id {
                                    updatedPeers.remove(at: i)
                                    break
                                }
                            }
                            updatedPeers.insert(peer, at: 0)
                            peersPromise.set(.single(updatedPeers))
                        }
                        
                        return .complete()
                    }
                    if let peer = peer {
                        removePeerDisposable.set((requestUpdatePeerIsBlocked(account: account, peerId: peer.id, isBlocked: true) |> then(applyPeers) |> deliverOnMainQueue).start(completed: {
                            if let strongController = controller {
                                strongController.inProgress = false
                                strongController.dismiss()
                            }
                        }))
                    }
                })
            }
        }
        presentControllerImpl?(controller, nil)
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
    }, openPeer: { peer in
        if let controller = peerInfoController(account: account, peer: peer) {
            pushControllerImpl?(controller)
        }
    })
    
    let peersSignal: Signal<[Peer]?, NoError> = .single(nil) |> then(requestBlockedPeers(account: account) |> map(Optional.init))
    
    peersPromise.set(peersSignal)
    
    var previousPeers: [Peer]?
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), peersPromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state, peers -> (ItemListControllerState, (ItemListNodeState<BlockedPeersEntry>, BlockedPeersEntry.ItemGenerationArguments)) in
            var rightNavigationButton: ItemListNavigationButton?
            if let peers = peers, !peers.isEmpty {
                if state.editing {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedEditing(false)
                        }
                    })
                } else {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedEditing(true)
                        }
                    })
                }
            }
            
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if let peers = peers {
                if peers.isEmpty {
                    emptyStateItem = ItemListTextEmptyStateItem(text: presentationData.strings.BlockedUsers_Info)
                }
            } else if peers == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
            
            let previous = previousPeers
            previousPeers = peers
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.BlockedUsers_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
            let listState = ItemListNodeState(entries: blockedPeersControllerEntries(presentationData: presentationData, state: state, peers: peers), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && peers != nil && previous!.count >= peers!.count)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }
    presentControllerImpl = { [weak controller] c, a in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: a)
        }
    }
    return controller
}
