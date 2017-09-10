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
    case groupInfo(PresentationTheme, PresentationStrings, Peer?, ItemListAvatarAndNameInfoItemState)
    case setProfilePhoto(PresentationTheme, String)
    
    case member(Int32, PresentationTheme, PresentationStrings, Peer, PeerPresence?)
    
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
            case let .member(index, _, _, _, _):
                return 2 + index
        }
    }
    
    static func ==(lhs: CreateGroupEntry, rhs: CreateGroupEntry) -> Bool {
        switch lhs {
            case let .groupInfo(lhsTheme, lhsStrings, lhsPeer, lhsEditingState):
                if case let .groupInfo(rhsTheme, rhsStrings, rhsPeer, rhsEditingState) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
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
            case let .setProfilePhoto(lhsTheme, lhsText):
                if case let .setProfilePhoto(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .member(lhsIndex, lhsTheme, lhsStrings, lhsPeer, lhsPresence):
                if case let .member(rhsIndex, rhsTheme, rhsStrings, rhsPeer, rhsPresence) = rhs {
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
            case let .groupInfo(theme, strings, peer, state):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, peer: peer, presence: nil, cachedData: nil, state: state, sectionId: ItemListSectionId(self.section), style: .blocks(withTopInset: false), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                })
            case let .setProfilePhoto(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    
                })
            case let .member(_, theme, strings, peer, presence):
                return ItemListPeerItem(theme: theme, strings: strings, account: arguments.account, peer: peer, presence: presence, text: .presence, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
        }
    }
}

private struct CreateGroupState: Equatable {
    let creating: Bool
    let editingName: ItemListAvatarAndNameInfoItemName
    
    static func ==(lhs: CreateGroupState, rhs: CreateGroupState) -> Bool {
        if lhs.creating != rhs.creating {
            return false
        }
        if lhs.editingName != rhs.editingName {
            return false
        }
        
        return true
    }
}

private func createGroupEntries(presentationData: PresentationData, state: CreateGroupState, peerIds: [PeerId], view: MultiplePeersView) -> [CreateGroupEntry] {
    var entries: [CreateGroupEntry] = []
    
    let groupInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingName, updatingName: nil)
    
    let peer = TelegramGroup(id: PeerId(namespace: 100, id: 0), title: state.editingName.composedTitle, photo: [], participantCount: 0, role: .creator, membership: .Member, flags: [], migrationReference: nil, creationDate: 0, version: 0)
    
    entries.append(.groupInfo(presentationData.theme, presentationData.strings, peer, groupInfoState))
    entries.append(.setProfilePhoto(presentationData.theme, presentationData.strings.Settings_SetProfilePhoto))
    
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
        entries.append(.member(Int32(i), presentationData.theme, presentationData.strings, peers[i], view.presences[peers[i].id]))
    }
    
    return entries
}

public func createGroupController(account: Account, peerIds: [PeerId]) -> ViewController {
    let initialState = CreateGroupState(creating: false, editingName: .title(title: ""))
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateGroupState) -> CreateGroupState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var replaceControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let arguments = CreateGroupArguments(account: account, updateEditingName: { editingName in
        updateState { current in
            return CreateGroupState(creating: current.creating, editingName: editingName)
        }
    }, done: {
        let (creating, title) = stateValue.with { state -> (Bool, String) in
            return (state.creating, state.editingName.composedTitle)
        }
        
        if !creating && !title.isEmpty {
            updateState { current in
                return CreateGroupState(creating: true, editingName: current.editingName)
            }
            actionsDisposable.add((createGroup(account: account, title: title, peerIds: peerIds) |> deliverOnMainQueue |> afterDisposed {
                Queue.mainQueue().async {
                    updateState { current in
                        return CreateGroupState(creating: false, editingName: current.editingName)
                    }
                }
            }).start(next: { peerId in
                if let peerId = peerId {
                    let controller = ChatController(account: account, peerId: peerId)
                    replaceControllerImpl?(controller)
                }
            }))
        }
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), account.postbox.multiplePeersView(peerIds))
        |> map { presentationData, state, view -> (ItemListControllerState, (ItemListNodeState<CreateGroupEntry>, CreateGroupEntry.ItemGenerationArguments)) in
            
            let rightNavigationButton: ItemListNavigationButton
            if state.creating {
                rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
            } else {
                rightNavigationButton = ItemListNavigationButton(title: "Create", style: .bold, enabled: !state.editingName.composedTitle.isEmpty, action: {
                    arguments.done()
                })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Create Group"), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: "Back"))
            let listState = ItemListNodeState(entries: createGroupEntries(presentationData: presentationData, state: state, peerIds: peerIds, view: view), style: .blocks)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(account: account, state: signal)
    replaceControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.replaceAllButRootController(value, animated: true)
    }
    return controller
}
