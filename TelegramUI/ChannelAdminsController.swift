import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let addMemberPlusIcon = UIImage(bundleImageName: "Peer Info/PeerItemPlusIcon")?.precomposed()

private struct ChannelAdminsControllerArguments {
    let account: Account
    
    let updateCurrentAdministrationType: () -> Void
    let addAdmin: () -> Void
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
    case adminPeerItem(Int32, RenderedChannelParticipant, ItemListPeerItemEditing)
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
            case let .adminPeerItem(_, participant, _):
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
            case let .adminPeerItem(lhsIndex, lhsParticipant, lhsEditing):
                if case let .adminPeerItem(rhsIndex, rhsParticipant, rhsEditing) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsParticipant != rhsParticipant {
                        return false
                    }
                    if lhsEditing != rhsEditing {
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
            case let .adminPeerItem(index, _, _):
                switch rhs {
                    case .administrationType, .administrationInfo, .adminsHeader:
                        return false
                    case let .adminPeerItem(rhsIndex, _, _):
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
                    
                })
            case let .administrationInfo(text):
                return ItemListTextItem(text: text, sectionId: self.section)
            case let .adminsHeader(title):
                return ItemListSectionHeaderItem(text: title, sectionId: self.section)
            case let .adminPeerItem(_, participant, editing):
                let peerText: String
                switch participant.participant {
                    case .creator:
                        peerText = "Creator"
                    default:
                        peerText = "Moderator"
                }
                return ItemListPeerItem(account: arguments.account, peer: participant.peer, presence: nil, text: .text(peerText), label: nil, editing: editing, enabled: true, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { previousId, id in
                    
                }, removePeer: { _ in
                    
                })
            case let .addAdmin(editing):
                return ItemListPeerActionItem(icon: addMemberPlusIcon, title: "Add Admin", sectionId: self.section, editing: editing, action: {
                    arguments.addAdmin()
                })
            case let .adminsInfo(text):
                return ItemListTextItem(text: text, sectionId: self.section)
        }
    }
}

private enum CurrentAdministrationType {
    case everyoneCanAddMembers
    case adminsCanAddMembers
}

private struct ChannelAdminsControllerState: Equatable {
    let selectedType: CurrentAdministrationType?
    
    init() {
        self.selectedType = nil
    }
    
    init(selectedType: CurrentAdministrationType?) {
        self.selectedType = selectedType
    }
    
    static func ==(lhs: ChannelAdminsControllerState, rhs: ChannelAdminsControllerState) -> Bool {
        if lhs.selectedType != rhs.selectedType {
            return false
        }
        
        return true
    }
    
    func withUpdatedSelectedType(_ selectedType: CurrentAdministrationType?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: selectedType)
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
            
            var index: Int32 = 0
            for participant in participants.sorted(by: { lhs, rhs in
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
                var editable = true
                if case .creator = participant.participant {
                    editable = false
                }
                entries.append(.adminPeerItem(index, participant, ItemListPeerItemEditing(editable: editable, editing: false, revealed: false)))
                index += 1
            }
            
            entries.append(.addAdmin(false))
            entries.append(.adminsInfo(isGroup ? "You can add admins to help you manage your group" : "You can add admins to help you manage your channel"))
        }
    }
    
    return entries
}

/*private func effectiveAdministrationType(state: ChannelAdminsControllerState, peer: TelegramChannel) -> CurrentAdministrationType {
    let selectedType: CurrentAdministrationType
    if let current = state.selectedType {
        selectedType = current
    } else {
        if let addressName = peer.addressName, !addressName.isEmpty {
            selectedType = .publicChannel
        } else {
            selectedType = .privateChannel
        }
    }
    return selectedType
}*/

public func ChannelAdminsController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelAdminsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelAdminsControllerState())
    let updateState: ((ChannelAdminsControllerState) -> ChannelAdminsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let updateAdministrationDisposable = MetaDisposable()
    actionsDisposable.add(updateAdministrationDisposable)
    
    let addAdminDisposable = MetaDisposable()
    actionsDisposable.add(addAdminDisposable)
    
    let arguments = ChannelAdminsControllerArguments(account: account, updateCurrentAdministrationType: {
    }, addAdmin: {
    })
    
    let peerView = account.viewTracker.peerView(peerId)
    
    let adminsPromise = Promise<[RenderedChannelParticipant]?>(nil)
    
    let adminsSignal: Signal<[RenderedChannelParticipant]?, NoError> = .single(nil) |> then(channelAdmins(account: account, peerId: peerId) |> map { Optional($0) })
    
    adminsPromise.set(adminsSignal)
    
    let signal = combineLatest(statePromise.get(), peerView, adminsPromise.get())
        |> map { state, view, admins -> (ItemListControllerState, (ItemListNodeState<ChannelAdminsEntry>, ChannelAdminsEntry.ItemGenerationArguments)) in
            let peer = peerViewMainPeer(view)
            
            var rightNavigationButton: ItemListNavigationButton?
            if let admins = admins, admins.count > 1 {
                rightNavigationButton = ItemListNavigationButton(title: "Edit", style: .regular, enabled: true, action: {
                    updateState { state in
                        return state
                    }
                })
            }
            
            let controllerState = ItemListControllerState(title: "Admins", leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, animateChanges: true)
            let listState = ItemListNodeState(entries: ChannelAdminsControllerEntries(view: view, state: state, participants: admins), style: .blocks, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    return controller
}
