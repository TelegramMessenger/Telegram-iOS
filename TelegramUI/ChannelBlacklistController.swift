import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChannelBlacklistControllerArguments {
    let account: Account
    
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let addPeer: () -> Void
    let removePeer: (PeerId) -> Void
    let openPeer: (ChannelParticipant) -> Void
    
    init(account: Account, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addPeer: @escaping  () -> Void, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping (ChannelParticipant) -> Void) {
        self.account = account
        self.addPeer = addPeer
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.openPeer = openPeer
    }
}

private enum ChannelBlacklistSection: Int32 {
    case add
    case peers
}

private enum ChannelBlacklistEntryStableId: Hashable {
    case add
    case peer(PeerId)
    
    var hashValue: Int {
        switch self {
            case .add:
                return 0
            case let .peer(peerId):
                return peerId.hashValue
        }
    }
    
    static func ==(lhs: ChannelBlacklistEntryStableId, rhs: ChannelBlacklistEntryStableId) -> Bool {
        switch lhs {
            case .add:
                if case .add = rhs {
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

private enum ChannelBlacklistEntry: ItemListNodeEntry {
    case add(PresentationTheme, String)
    case peerItem(PresentationTheme, PresentationStrings, Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .add:
                return ChannelBlacklistSection.add.rawValue
            case .peerItem:
                return ChannelBlacklistSection.peers.rawValue
        }
    }
    
    var stableId: ChannelBlacklistEntryStableId {
        switch self {
            case .add:
                return .add
            case let .peerItem(_, _, _, participant, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelBlacklistEntry, rhs: ChannelBlacklistEntry) -> Bool {
        switch lhs {
            case let .add(lhsTheme, lhsText):
                if case let .add(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .peerItem(lhsTheme, lhsStrings, lhsIndex, lhsParticipant, lhsEditing, lhsEnabled):
                if case let .peerItem(rhsTheme, rhsStrings, rhsIndex, rhsParticipant, rhsEditing, rhsEnabled) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
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
            case .add:
                switch rhs {
                    case .add:
                        return false
                    default:
                        return true
                }
            case let .peerItem(_, _, index, _, _, _):
                switch rhs {
                    case .add:
                        return false
                    case let .peerItem(_, _, rhsIndex, _, _, _):
                        return index < rhsIndex
                }
        }
    }
    
    func item(_ arguments: ChannelBlacklistControllerArguments) -> ListViewItem {
        switch self {
            case let .add(theme, text):
                return ItemListPeerActionItem(theme: theme, icon: PresentationResourcesItemList.addPersonIcon(theme), title: text, sectionId: self.section, editing: false, action: {
                    arguments.addPeer()
                })
            case let .peerItem(theme, strings, _, participant, editing, enabled):
                return ItemListPeerItem(theme: theme, strings: strings, account: arguments.account, peer: participant.peer, presence: nil, text: .none, label: .none, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: {
                    arguments.openPeer(participant.participant)
                }, setPeerIdWithRevealedOptions: { previousId, id in
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

private func channelBlacklistControllerEntries(presentationData: PresentationData, view: PeerView, state: ChannelBlacklistControllerState, blacklist: ChannelBlacklist?) -> [ChannelBlacklistEntry] {
    var entries: [ChannelBlacklistEntry] = []
    
    if let blacklist = blacklist {
        entries.append(.add(presentationData.theme, presentationData.strings.Channel_Members_AddMembers))
        
        var index: Int32 = 0
        for participant in blacklist.banned.sorted(by: { lhs, rhs in
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
            entries.append(.peerItem(presentationData.theme, presentationData.strings, index, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id))
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
    
    let blacklistPromise = Promise<ChannelBlacklist?>(nil)
    
    let arguments = ChannelBlacklistControllerArguments(account: account, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, addPeer: {
        presentControllerImpl?(ChannelMembersSearchController(account: account, peerId: peerId, openPeer: { peer in
            /*presentControllerImpl?(channelAdminController(account: account, peerId: peerId, adminId: peer.id, initialParticipant: nil, updated: { updatedRights in
                let applyAdmin: Signal<Void, NoError> = adminsPromise.get()
                    |> filter { $0 != nil }
                    |> take(1)
                    |> deliverOnMainQueue
                    |> mapToSignal { admins -> Signal<Void, NoError> in
                        if let admins = admins {
                            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                            
                            var updatedAdmins = admins
                            if updatedRights.isEmpty {
                                for i in 0 ..< updatedAdmins.count {
                                    if updatedAdmins[i].peer.id == peer.id {
                                        updatedAdmins.remove(at: i)
                                        break
                                    }
                                }
                            } else {
                                var found = false
                                for i in 0 ..< updatedAdmins.count {
                                    if updatedAdmins[i].peer.id == peer.id {
                                        if case let .member(id, date, _, banInfo) = updatedAdmins[i].participant {
                                            updatedAdmins[i] = RenderedChannelParticipant(participant: .member(id: id, invitedAt: date, adminInfo: ChannelParticipantAdminInfo(rights: updatedRights, promotedBy: account.peerId, canBeEditedByAccountPeer: true), banInfo: banInfo), peer: updatedAdmins[i].peer)
                                        }
                                        found = true
                                        break
                                    }
                                }
                                if !found {
                                    updatedAdmins.append(RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: timestamp, adminInfo: ChannelParticipantAdminInfo(rights: updatedRights, promotedBy: account.peerId, canBeEditedByAccountPeer: true), banInfo: nil), peer: peer))
                                }
                            }
                            adminsPromise.set(.single(updatedAdmins))
                        }
                        
                        return .complete()
                }
                addAdminDisposable.set(applyAdmin.start())
            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))*/
        }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, removePeer: { memberId in
        updateState {
            return $0.withUpdatedRemovingPeerId(memberId)
        }
        
        let applyPeers: Signal<Void, NoError> = blacklistPromise.get()
            |> filter { $0 != nil }
            |> take(1)
            |> deliverOnMainQueue
            |> mapToSignal { blacklist -> Signal<Void, NoError> in
                if let blacklist = blacklist {
                    let updatedBlacklist = blacklist.withRemovedPeerId(memberId)
                    blacklistPromise.set(.single(updatedBlacklist))
                }
                
                return .complete()
            }
        
        /*removePeerDisposable.set((removeChannelBlacklistedPeer(account: account, peerId: peerId, memberId: memberId) |> then(applyPeers) |> deliverOnMainQueue).start(error: { _ in
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
        }, completed: {
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
            
        }))*/
    }, openPeer: { participant in
        /*presentControllerImpl?(channelBannedMemberController(account: account, peerId: peerId, memberId: participant.peerId, initialParticipant: participant, updated: { rights in
            
        }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))*/
    })
    
    let peerView = account.viewTracker.peerView(peerId)
    
    let blacklistSignal: Signal<ChannelBlacklist?, NoError> = .single(nil) |> then(channelBlacklistParticipants(account: account, peerId: peerId) |> map { Optional($0) })
    
    blacklistPromise.set(blacklistSignal)
    
    var previousBlacklist: ChannelBlacklist?
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), peerView, blacklistPromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state, view, blacklist -> (ItemListControllerState, (ItemListNodeState<ChannelBlacklistEntry>, ChannelBlacklistEntry.ItemGenerationArguments)) in
            var rightNavigationButton: ItemListNavigationButton?
            if let blacklist = blacklist, !blacklist.isEmpty {
                if state.editing {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedEditing(false)
                        }
                    })
                } else {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedEditing(true)
                        }
                    })
                }
            }
            
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if blacklist == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
            
            let previous = previousBlacklist
            previousBlacklist = blacklist
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Channel_BlackList_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
            let listState = ItemListNodeState(entries: channelBlacklistControllerEntries(presentationData: presentationData, view: view, state: state, blacklist: blacklist), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && blacklist != nil && (previous!.restricted.count + previous!.banned.count) >= (blacklist!.restricted.count + blacklist!.banned.count))
            
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
