import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private struct CreateGroupArguments {
    let account: Account
    
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let done: () -> Void
}

private enum CreateGroupSection: Int32 {
    case info
    case members
}

private enum CreateGroupEntry: ItemListNodeEntry {
    case groupInfo(Peer?, ItemListAvatarAndNameInfoItemState)
    case setProfilePhoto
    
    case member(Int32, Peer, PeerPresence?)
    
    var section: ItemListSectionId {
        switch self {
            case .groupInfo, .setProfilePhoto:
                return CreateGroupSection.info.rawValue
            case .member:
                return CreateGroupSection.members.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .groupInfo:
                return 0
            case .setProfilePhoto:
                return 1
            case let .member(index, _, _):
                return 2 + index
        }
    }
    
    static func ==(lhs: CreateGroupEntry, rhs: CreateGroupEntry) -> Bool {
        switch lhs {
            case let .groupInfo(lhsPeer, lhsEditingState):
                if case let .groupInfo(rhsPeer, rhsEditingState) = rhs {
                    if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else if (lhsPeer != nil) != (rhsPeer != nil) {
                        return false
                    }
                    if lhsEditingState != rhsEditingState {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case .setProfilePhoto:
                if case .setProfilePhoto = rhs {
                    return true
                } else {
                    return false
                }
            case let .member(lhsIndex, lhsPeer, lhsPresence):
                if case let .member(rhsIndex, rhsPeer, rhsPresence) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    
                    if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                        if !lhsPresence.isEqual(to: rhsPresence) {
                            return false
                        }
                    } else if (lhsPresence != nil) != (rhsPresence != nil) {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: CreateGroupEntry, rhs: CreateGroupEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: CreateGroupArguments) -> ListViewItem {
        switch self {
            case let .groupInfo(peer, state):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, peer: peer, cachedData: nil, state: state, sectionId: ItemListSectionId(self.section), style: .blocks, editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                })
            case .setProfilePhoto:
                return ItemListActionItem(title: "Set Profile Photo", kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    
                })
            case let .member(_, peer, presence):
                return ItemListPeerItem(account: arguments.account, peer: peer, presence: presence, label: nil, sectionId: self.section, action: nil)
        }
    }
}

private struct CreateGroupState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName
    
    static func ==(lhs: CreateGroupState, rhs: CreateGroupState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        
        return true
    }
}

private func createGroupEntries(state: CreateGroupState, peerIds: [PeerId], view: MultiplePeersView) -> [CreateGroupEntry] {
    var entries: [CreateGroupEntry] = []
    
    let groupInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingName, updatingName: nil)
    
    let peer = TelegramGroup(id: PeerId(namespace: 100, id: 0), title: "", photo: [], participantCount: 0, role: .creator, membership: .Member, flags: [], migrationReference: nil, creationDate: 0, version: 0)
    
    entries.append(.groupInfo(peer, groupInfoState))
    entries.append(.setProfilePhoto)
    
    var peers: [Peer] = []
    for peerId in peerIds {
        if let peer = view.peers[peerId] {
            peers.append(peer)
        }
    }
    
    peers.sort(by: { lhs, rhs in
        let lhsPresence = view.presences[lhs.id] as? TelegramUserPresence
        let rhsPresence = view.presences[rhs.id] as? TelegramUserPresence
        if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
            if lhsPresence.status < rhsPresence.status {
                return false
            } else if lhsPresence.status > rhsPresence.status {
                return true
            } else {
                return lhs.id < rhs.id
            }
        } else if let _ = lhsPresence {
            return true
        } else if let _ = rhsPresence {
            return false
        } else {
            return lhs.id < rhs.id
        }
    })
    
    for i in 0 ..< peers.count {
        entries.append(.member(Int32(i), peers[i], view.presences[peers[i].id]))
    }
    
    return entries
}

public func createGroupController(account: Account, peerIds: [PeerId]) -> ViewController {
    let initialState = CreateGroupState(editingName: .title(title: ""))
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateGroupState) -> CreateGroupState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var replaceControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let arguments = CreateGroupArguments(account: account, updateEditingName: { editingName in
        updateState { _ in
            return CreateGroupState(editingName: editingName)
        }
    }, done: {
        let title = stateValue.with { state -> String in
            return state.editingName.composedTitle
        }
        
        if !title.isEmpty {
            actionsDisposable.add((createGroup(account: account, title: title, peerIds: peerIds) |> deliverOnMainQueue).start(next: { peerId in
                if let peerId = peerId {
                    let controller = ChatController(account: account, peerId: peerId)
                    replaceControllerImpl?(controller)
                }
            }))
        }
    })
    
    let signal = combineLatest(statePromise.get(), account.postbox.multiplePeersView(peerIds))
        |> map { state, view -> (ItemListControllerState, (ItemListNodeState<CreateGroupEntry>, CreateGroupEntry.ItemGenerationArguments)) in
            
            let rightNavigationButton = ItemListNavigationButton(title: "Create", style: .bold, enabled: !state.editingName.composedTitle.isEmpty, action: {
                arguments.done()
            })
            
            let controllerState = ItemListControllerState(title: "Create Group", leftNavigationButton: nil, rightNavigationButton: rightNavigationButton)
            let listState = ItemListNodeState(entries: createGroupEntries(state: state, peerIds: peerIds, view: view), style: .blocks)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(signal)
    replaceControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.replaceAllButRootController(value, animated: true)
    }
    return controller
}
