import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class GroupAdminsControllerArguments {
    let account: Account
    
    let updateAllAreAdmins: (Bool) -> Void
    let updatePeerIsAdmin: (PeerId, Bool) -> Void
    
    init(account: Account, updateAllAreAdmins: @escaping (Bool) -> Void, updatePeerIsAdmin: @escaping (PeerId, Bool) -> Void) {
        self.account = account
        self.updateAllAreAdmins = updateAllAreAdmins
        self.updatePeerIsAdmin = updatePeerIsAdmin
    }
}

private enum GroupAdminsSection: Int32 {
    case allAdmins
    case peers
}

private enum GroupAdminsEntryStableId: Hashable {
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
    
    static func ==(lhs: GroupAdminsEntryStableId, rhs: GroupAdminsEntryStableId) -> Bool {
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

private enum GroupAdminsEntry: ItemListNodeEntry {
    case allAdmins(Bool)
    case allAdminsInfo(String)
    case peerItem(Int32, Peer, PeerPresence?, Bool, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .allAdmins, .allAdminsInfo:
                return GroupAdminsSection.allAdmins.rawValue
            case .peerItem:
                return GroupAdminsSection.peers.rawValue
        }
    }
    
    var stableId: GroupAdminsEntryStableId {
        switch self {
            case .allAdmins:
                return .index(0)
            case .allAdminsInfo:
                return .index(1)
            case let .peerItem(_, peer, _, _, _):
                return .peer(peer.id)
        }
    }
    
    static func ==(lhs: GroupAdminsEntry, rhs: GroupAdminsEntry) -> Bool {
        switch lhs {
            case let .allAdmins(value):
                if case .allAdmins(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .allAdminsInfo(text):
                if case .allAdminsInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .peerItem(lhsIndex, lhsPeer, lhsPresence, lhsToggled, lhsEnabled):
                if case let .peerItem(rhsIndex, rhsPeer, rhsPresence, rhsToggled, rhsEnabled) = rhs {
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
                    if lhsToggled != rhsToggled {
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
    
    static func <(lhs: GroupAdminsEntry, rhs: GroupAdminsEntry) -> Bool {
        switch lhs {
            case .allAdmins:
                return true
            case .allAdminsInfo:
                switch rhs {
                    case .allAdmins:
                        return false
                    default:
                        return true
                }
            case let .peerItem(index, _, _, _, _):
                switch rhs {
                    case let .peerItem(rhsIndex, _, _, _, _):
                        return index < rhsIndex
                    case .allAdmins, .allAdminsInfo:
                        return false
                }
        }
    }
    
    func item(_ arguments: GroupAdminsControllerArguments) -> ListViewItem {
        switch self {
        case let .allAdmins(value):
            return ItemListSwitchItem(title: "All Members Are Admins", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.updateAllAreAdmins(updatedValue)
            })
        case let .allAdminsInfo(text):
            return ItemListTextItem(text: .plain(text), sectionId: self.section)
        case let .peerItem(_, peer, presence, toggled, enabled):
            return ItemListPeerItem(account: arguments.account, peer: peer, presence: presence, text: .presence, label: nil, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: toggled, enabled: enabled, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { _ in }, removePeer: { _ in }, toggleUpdated: { value in
                arguments.updatePeerIsAdmin(peer.id, value)
            })
        }
    }
}

private struct GroupAdminsControllerState: Equatable {
    let updatingAllAdminsValue: Bool?
    let updatedAllAdminsValue: Bool?
    
    let updatingAdminValue: [PeerId: Bool]
    
    init() {
        self.updatingAllAdminsValue = nil
        self.updatedAllAdminsValue = nil
        self.updatingAdminValue = [:]
    }
    
    init(updatingAllAdminsValue: Bool?, updatedAllAdminsValue: Bool?, updatingAdminValue: [PeerId: Bool]) {
        self.updatingAllAdminsValue = updatingAllAdminsValue
        self.updatedAllAdminsValue = updatedAllAdminsValue
        self.updatingAdminValue = updatingAdminValue
    }
    
    static func ==(lhs: GroupAdminsControllerState, rhs: GroupAdminsControllerState) -> Bool {
        if lhs.updatingAllAdminsValue != rhs.updatingAllAdminsValue {
            return false
        }
        if lhs.updatedAllAdminsValue != rhs.updatedAllAdminsValue {
            return false
        }
        if lhs.updatingAdminValue != rhs.updatingAdminValue {
            return false
        }
        
        return true
    }
    
    func withUpdatedUpdatingAllAdminsValue(_ updatingAllAdminsValue: Bool?) -> GroupAdminsControllerState {
        return GroupAdminsControllerState(updatingAllAdminsValue: updatingAllAdminsValue, updatedAllAdminsValue: self.updatedAllAdminsValue, updatingAdminValue: self.updatingAdminValue)
    }
    
    func withUpdatedUpdatedAllAdminsValue(_ updatedAllAdminsValue: Bool?) -> GroupAdminsControllerState {
        return GroupAdminsControllerState(updatingAllAdminsValue: self.updatingAllAdminsValue, updatedAllAdminsValue: updatedAllAdminsValue, updatingAdminValue: self.updatingAdminValue)
    }
    
    func withUpdatedUpdatingAdminValue(_ updatingAdminValue: [PeerId: Bool]) -> GroupAdminsControllerState {
        return GroupAdminsControllerState(updatingAllAdminsValue: self.updatingAllAdminsValue, updatedAllAdminsValue: self.updatedAllAdminsValue, updatingAdminValue: updatingAdminValue)
    }
}

private func groupAdminsControllerEntries(account: Account, view: PeerView, state: GroupAdminsControllerState) -> [GroupAdminsEntry] {
    var entries: [GroupAdminsEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramGroup, let cachedData = view.cachedData as? CachedGroupData, let participants = cachedData.participants {
        let effectiveAdminsEnabled: Bool
        if let updatingAllAdminsValue = state.updatingAllAdminsValue {
            effectiveAdminsEnabled = updatingAllAdminsValue
        } else {
            effectiveAdminsEnabled = peer.flags.contains(.adminsEnabled)
        }
        
        entries.append(.allAdmins(!effectiveAdminsEnabled))
        if effectiveAdminsEnabled {
            entries.append(.allAdminsInfo("Only admins can add and remove members, edit name and photo of this group."))
        } else {
            entries.append(.allAdminsInfo("Group members can add new members, edit name and photo of this group."))
        }
        
        let sortedParticipants = participants.participants.sorted(by: { lhs, rhs in
            let lhsInvitedAt: Int32
            switch lhs {
                case let .admin(_, _, invitedAt):
                    lhsInvitedAt = invitedAt
                case .creator(_):
                    lhsInvitedAt = Int32.max
                case let .member(_, _, invitedAt):
                    lhsInvitedAt = invitedAt
            }
            
            let rhsInvitedAt: Int32
            switch rhs {
                case let .admin(_, _, invitedAt):
                    rhsInvitedAt = invitedAt
                case .creator(_):
                    rhsInvitedAt = Int32.max
                case let .member(_, _, invitedAt):
                    rhsInvitedAt = invitedAt
            }
            return lhsInvitedAt > rhsInvitedAt
        })
        
        var index: Int32 = 0
        for participant in sortedParticipants {
            if let peer = view.peers[participant.peerId] {
                var isAdmin = false
                var isEnabled = true
                if !effectiveAdminsEnabled {
                    isAdmin = true
                    isEnabled = false
                } else {
                    switch participant {
                        case .creator:
                            isAdmin = true
                            isEnabled = false
                        case .admin:
                            if let value = state.updatingAdminValue[peer.id] {
                                isAdmin = value
                            } else {
                                isAdmin = true
                            }
                        case .member:
                            if let value = state.updatingAdminValue[peer.id] {
                                isAdmin = value
                            } else {
                                isAdmin = false
                            }
                    }
                }
                entries.append(.peerItem(index, peer, view.peerPresences[participant.peerId], isAdmin, isEnabled))
                index += 1
            }
        }
    }
    
    return entries
}

public func groupAdminsController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(GroupAdminsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: GroupAdminsControllerState())
    let updateState: ((GroupAdminsControllerState) -> GroupAdminsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let toggleAllAdminsDisposable = MetaDisposable()
    actionsDisposable.add(toggleAllAdminsDisposable)
    
    let toggleAdminsDisposables = DisposableDict<PeerId>()
    actionsDisposable.add(toggleAdminsDisposables)
    
    let arguments = GroupAdminsControllerArguments(account: account, updateAllAreAdmins: { value in
        updateState { state in
            return state.withUpdatedUpdatingAllAdminsValue(value)
        }
        toggleAllAdminsDisposable.set((updateGroupManagementType(account: account, peerId: peerId, type: value ? .unrestricted : .restrictedToAdmins) |> deliverOnMainQueue).start(error: {
            updateState { state in
                return state.withUpdatedUpdatingAllAdminsValue(nil)
            }
        }, completed: {
            updateState { state in
                return state.withUpdatedUpdatingAllAdminsValue(nil).withUpdatedUpdatedAllAdminsValue(value)
            }
        }))
    }, updatePeerIsAdmin: { memberId, value in
        updateState { state in
            var updatingAdminValue = state.updatingAdminValue
            updatingAdminValue[memberId] = value
            return state.withUpdatedUpdatingAdminValue(updatingAdminValue)
        }
        
        if value {
            toggleAdminsDisposables.set((addPeerAdmin(account: account, peerId: peerId, adminId: memberId) |> deliverOnMainQueue).start(error: { _ in
                updateState { state in
                    var updatingAdminValue = state.updatingAdminValue
                    updatingAdminValue.removeValue(forKey: memberId)
                    return state.withUpdatedUpdatingAdminValue(updatingAdminValue)
                }
            }, completed: {
                updateState { state in
                    var updatingAdminValue = state.updatingAdminValue
                    updatingAdminValue.removeValue(forKey: memberId)
                    return state.withUpdatedUpdatingAdminValue(updatingAdminValue)
                }
            }), forKey: memberId)
        } else {
            toggleAdminsDisposables.set((removePeerAdmin(account: account, peerId: peerId, adminId: memberId) |> deliverOnMainQueue).start(error: { _ in
                updateState { state in
                    var updatingAdminValue = state.updatingAdminValue
                    updatingAdminValue.removeValue(forKey: memberId)
                    return state.withUpdatedUpdatingAdminValue(updatingAdminValue)
                }
            }, completed: {
                updateState { state in
                    var updatingAdminValue = state.updatingAdminValue
                    updatingAdminValue.removeValue(forKey: memberId)
                    return state.withUpdatedUpdatingAdminValue(updatingAdminValue)
                }
            }), forKey: memberId)
        }
    })
    
    let peerView = account.viewTracker.peerView(peerId)
    
    let signal = combineLatest(statePromise.get() |> deliverOnMainQueue, peerView |> deliverOnMainQueue)
        |> deliverOnMainQueue
        |> map { state, view -> (ItemListControllerState, (ItemListNodeState<GroupAdminsEntry>, GroupAdminsEntry.ItemGenerationArguments)) in
            
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if view.cachedData == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem()
            }
            
            var rightNavigationButton: ItemListNavigationButton?
            if !state.updatingAdminValue.isEmpty || state.updatingAllAdminsValue != nil {
                rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
            }
            
            let controllerState = ItemListControllerState(title: "Admins", leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, animateChanges: true)
            let listState = ItemListNodeState(entries: groupAdminsControllerEntries(account: account, view: view, state: state), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: true)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(signal)
    return controller
}
