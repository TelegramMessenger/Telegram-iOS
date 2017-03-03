import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class GroupsInCommonControllerArguments {
    let account: Account
    
    let openPeer: (PeerId) -> Void
    
    init(account: Account, openPeer: @escaping (PeerId) -> Void) {
        self.account = account
        self.openPeer = openPeer
    }
}

private enum GroupsInCommonSection: Int32 {
    case peers
}

private enum GroupsInCommonEntryStableId: Hashable {
    case peer(PeerId)
    
    var hashValue: Int {
        switch self {
        case let .peer(peerId):
            return peerId.hashValue
        }
    }
    
    static func ==(lhs: GroupsInCommonEntryStableId, rhs: GroupsInCommonEntryStableId) -> Bool {
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

private enum GroupsInCommonEntry: ItemListNodeEntry {
    case peerItem(Int32, Peer)
    
    var section: ItemListSectionId {
        switch self {
            case .peerItem:
                return GroupsInCommonSection.peers.rawValue
        }
    }
    
    var stableId: GroupsInCommonEntryStableId {
        switch self {
            case let .peerItem(_, peer):
                return .peer(peer.id)
        }
    }
    
    static func ==(lhs: GroupsInCommonEntry, rhs: GroupsInCommonEntry) -> Bool {
        switch lhs {
            case let .peerItem(lhsIndex, lhsPeer):
                if case let .peerItem(rhsIndex, rhsPeer) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: GroupsInCommonEntry, rhs: GroupsInCommonEntry) -> Bool {
        switch lhs {
        case let .peerItem(index, _):
            switch rhs {
                case let .peerItem(rhsIndex, _):
                    return index < rhsIndex
            }
        }
    }
    
    func item(_ arguments: GroupsInCommonControllerArguments) -> ListViewItem {
        switch self {
        case let .peerItem(_, peer):
            return ItemListPeerItem(account: arguments.account, peer: peer, presence: nil, text: .none, label: nil, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, sectionId: self.section, action: {
                arguments.openPeer(peer.id)
            }, setPeerIdWithRevealedOptions: { _ in
            }, removePeer: { _ in
            })
        }
    }
}

private struct GroupsInCommonControllerState: Equatable {
    static func ==(lhs: GroupsInCommonControllerState, rhs: GroupsInCommonControllerState) -> Bool {
        return true
    }
}

private func groupsInCommonControllerEntries(state: GroupsInCommonControllerState, peers: [Peer]?) -> [GroupsInCommonEntry] {
    var entries: [GroupsInCommonEntry] = []
    
    if let peers = peers {
        var index: Int32 = 0
        for peer in peers {
            entries.append(.peerItem(index, peer))
            index += 1
        }
    }
    
    return entries
}

public func groupsInCommonController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(GroupsInCommonControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: GroupsInCommonControllerState())
    let updateState: ((GroupsInCommonControllerState) -> GroupsInCommonControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let peersPromise = Promise<[Peer]?>(nil)
    
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = GroupsInCommonControllerArguments(account: account, openPeer: { memberId in
        pushControllerImpl?(ChatController(account: account, peerId: memberId))
    })
    
    let peersSignal: Signal<[Peer]?, NoError> = .single(nil) |> then(groupsInCommon(account: account, peerId: peerId) |> mapToSignal { peerIds -> Signal<[Peer], NoError> in
            return account.postbox.modify { modifier -> [Peer] in
                var result: [Peer] = []
                for id in peerIds {
                    if let peer = modifier.getPeer(id) {
                        result.append(peer)
                    }
                }
                return result
            }
        }
        |> map { Optional($0) })
    
    peersPromise.set(peersSignal)
    
    var previousPeers: [Peer]?
    
    let signal = combineLatest(statePromise.get(), peersPromise.get())
        |> deliverOnMainQueue
        |> map { state, peers -> (ItemListControllerState, (ItemListNodeState<GroupsInCommonEntry>, GroupsInCommonEntry.ItemGenerationArguments)) in
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if peers == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem()
            }
            
            let previous = previousPeers
            previousPeers = peers
            
            let controllerState = ItemListControllerState(title: "Groups in Common", leftNavigationButton: nil, rightNavigationButton: nil, animateChanges: false)
            let listState = ItemListNodeState(entries: groupsInCommonControllerEntries(state: state, peers: peers), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && peers != nil && previous!.count >= peers!.count)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    return controller
}
