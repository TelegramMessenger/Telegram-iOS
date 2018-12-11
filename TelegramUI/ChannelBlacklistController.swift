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
    let openPeerInfo:(Peer) -> Void
    init(account: Account, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addPeer: @escaping  () -> Void, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping (ChannelParticipant) -> Void, openPeerInfo: @escaping(Peer)->Void) {
        self.account = account
        self.addPeer = addPeer
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.openPeer = openPeer
        self.openPeerInfo = openPeerInfo
    }
}

private enum ChannelBlacklistSection: Int32 {
    case add
    case restricted
    case banned
}

private enum ChannelBlacklistEntryStableId: Hashable {
    case index(Int)
    case peer(PeerId)
}

private enum ChannelBlacklistPeerCategory {
    case restricted
    case banned
}

private enum ChannelBlacklistEntry: ItemListNodeEntry {
    case add(PresentationTheme, String)
    case restrictedHeader(PresentationTheme, String)
    case bannedHeader(PresentationTheme, String)
    case peerItem(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Int32, ChannelBlacklistPeerCategory, RenderedChannelParticipant, ItemListPeerItemEditing, Bool, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .add:
                return ChannelBlacklistSection.add.rawValue
            case .restrictedHeader:
                return ChannelBlacklistSection.restricted.rawValue
            case .bannedHeader:
                return ChannelBlacklistSection.banned.rawValue
            case let .peerItem(_, _, _, _, _, category, _, _, _, _):
                switch category {
                    case .restricted:
                        return ChannelBlacklistSection.restricted.rawValue
                    case .banned:
                        return ChannelBlacklistSection.banned.rawValue
                }
        }
    }
    
    var stableId: ChannelBlacklistEntryStableId {
        switch self {
            case .add:
                return .index(0)
            case .restrictedHeader:
                return .index(1)
            case .bannedHeader:
                return .index(2)
            case let .peerItem(_, _, _, _, _, _, participant, _, _, _):
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
            case let .restrictedHeader(lhsTheme, lhsText):
                if case let .restrictedHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .bannedHeader(lhsTheme, lhsText):
                if case let .bannedHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .peerItem(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsIndex, lhsCategory, lhsParticipant, lhsEditing, lhsEnabled, lhsCanOpen):
                if case let .peerItem(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsIndex, rhsCategory, rhsParticipant, rhsEditing, rhsEnabled, rhsCanOpen) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if lhsNameOrder != rhsNameOrder {
                        return false
                    }
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsCategory != rhsCategory {
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
                    if lhsCanOpen != rhsCanOpen {
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
            case .restrictedHeader:
                switch rhs {
                    case .add, .restrictedHeader:
                        return false
                    default:
                        return true
                }
            case .bannedHeader:
                switch rhs {
                    case .add, .restrictedHeader, .bannedHeader:
                        return false
                    case let .peerItem(_, _, _, _, _, category, _, _, _, _):
                        switch category {
                            case .restricted:
                                return false
                            case .banned:
                                return true
                        }
                }
            case let .peerItem(_, _, _, _, index, category, _, _, _, _):
                switch rhs {
                    case .add, .restrictedHeader:
                        return false
                    case .bannedHeader:
                        switch category {
                            case .restricted:
                                return true
                            case .banned:
                                return false
                        }
                    case let .peerItem(_, _, _, _, rhsIndex, _, _, _, _, _):
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
            case let .restrictedHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .bannedHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .peerItem(theme, strings, dateTimeFormat, nameDisplayOrder, _, _, participant, editing, enabled, canOpen):
                var text: ItemListPeerItemText = .none
                switch participant.participant {
                    case let .member(_, _, _, banInfo):
                        if let banInfo = banInfo, let peer = participant.peers[banInfo.restrictedBy] {
                            text = .text(strings.Channel_Management_RestrictedBy(peer.displayTitle).0)
                        }
                    default:
                        break
                }
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.account, peer: participant.peer, presence: nil, text: text, label: .none, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: canOpen ? {
                    arguments.openPeer(participant.participant)
                    } : {
                        arguments.openPeerInfo(participant.peer)
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
    let searchingMembers: Bool

    init() {
        self.editing = false
        self.peerIdWithRevealedOptions = nil
        self.removingPeerId = nil
        self.searchingMembers = false
    }
    
    init(editing: Bool, peerIdWithRevealedOptions: PeerId?, removingPeerId: PeerId?, searchingMembers: Bool) {
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.removingPeerId = removingPeerId
        self.searchingMembers = searchingMembers
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
        if lhs.searchingMembers != rhs.searchingMembers {
            return false
        }
        
        return true
    }
    
    func withUpdatedSearchingMembers(_ searchingMembers: Bool) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, searchingMembers: searchingMembers)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, searchingMembers: self.searchingMembers)
    }
    
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: removingPeerId, searchingMembers: self.searchingMembers)
    }
}

private func channelBlacklistControllerEntries(presentationData: PresentationData, view: PeerView, state: ChannelBlacklistControllerState, blacklist: ChannelBlacklist?) -> [ChannelBlacklistEntry] {
    var entries: [ChannelBlacklistEntry] = []
    
    if let channel = view.peers[view.peerId] as? TelegramChannel, let blacklist = blacklist {
        entries.append(.add(presentationData.theme, presentationData.strings.Channel_Members_AddMembers))
        
        var index: Int32 = 0
        if !blacklist.restricted.isEmpty {
            entries.append(.restrictedHeader(presentationData.theme, presentationData.strings.Channel_BanList_RestrictedTitle))
        }
        let canOpen: Bool
        if case .group = channel.info {
            canOpen = true
        } else {
            canOpen = false
        }
        for participant in blacklist.restricted {
            var editable = true
            if case .creator = participant.participant {
                editable = false
            }
            entries.append(.peerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, index, .restricted, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id, canOpen))
            index += 1
        }
        if !blacklist.banned.isEmpty {
            entries.append(.bannedHeader(presentationData.theme, presentationData.strings.Channel_BanList_BlockedTitle))
        }
        for participant in blacklist.banned {
            var editable = true
            if case .creator = participant.participant {
                editable = false
            }
            entries.append(.peerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, index, .banned, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id, canOpen))
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
    var pushControllerImpl: ((ViewController) -> Void)?

    let actionsDisposable = DisposableSet()
    
    let updateBannedDisposable = MetaDisposable()
    actionsDisposable.add(updateBannedDisposable)
    
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
        presentControllerImpl?(ChannelMembersSearchController(account: account, peerId: peerId, mode: .ban, openPeer: { peer, participant in
            if let participant = participant {
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                switch participant.participant {
                    case .creator:
                        return
                    case let .member(_, _, adminInfo, _):
                        if let adminInfo = adminInfo, adminInfo.promotedBy != account.peerId {
                            presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Channel_Members_AddBannedErrorAdmin, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                            return
                        }
                }
            }
            let _ = (account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { channel in
                guard let channel = channel as? TelegramChannel else {
                    return
                }
                if case .broadcast = channel.info {
                    removePeerDisposable.set((account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: account, peerId: peerId, memberId: peer.id, bannedRights: TelegramChannelBannedRights(flags: [.banReadMessages], untilDate: Int32.max))
                    |> deliverOnMainQueue).start())
                } else {
                    presentControllerImpl?(channelBannedMemberController(account: account, peerId: peerId, memberId: peer.id, initialParticipant: participant?.participant, updated: { _ in
                    }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
            })
        }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, removePeer: { memberId in
        updateState {
            return $0.withUpdatedRemovingPeerId(memberId)
        }
        
        removePeerDisposable.set((account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: account, peerId: peerId, memberId: memberId, bannedRights: TelegramChannelBannedRights(flags: [], untilDate: 0))  |> deliverOnMainQueue).start(error: { _ in
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
        }, completed: {
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
        }))
    }, openPeer: { participant in
        presentControllerImpl?(channelBannedMemberController(account: account, peerId: peerId, memberId: participant.peerId, initialParticipant: participant, updated: { _ in
        }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openPeerInfo: { peer in
        if let controller = peerInfoController(account: account, peer: peer) {
            pushControllerImpl?(controller)
        }
    })
    
    let peerView = account.viewTracker.peerView(peerId)
    
    let (listDisposable, loadMoreControl) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.restrictedAndBanned(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, updated: { listState in
        if case .loading = listState.loadingState, listState.list.isEmpty {
            blacklistPromise.set(.single(nil))
        } else {
            var restricted: [RenderedChannelParticipant] = []
            var banned: [RenderedChannelParticipant] = []
            for member in listState.list {
                switch member.participant {
                    case let .member(_, _, _, banInfo):
                        if let banInfo = banInfo {
                            if !banInfo.rights.flags.contains(.banReadMessages) {
                                restricted.append(member)
                            } else {
                                banned.append(member)
                            }
                        } else {
                            assertionFailure()
                        }
                    default:
                        assertionFailure()
                        break
                }
            }
            blacklistPromise.set(.single(ChannelBlacklist(banned: banned, restricted: restricted)))
        }
    })
    actionsDisposable.add(listDisposable)
    
    var previousBlacklist: ChannelBlacklist?
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), peerView, blacklistPromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state, view, blacklist -> (ItemListControllerState, (ItemListNodeState<ChannelBlacklistEntry>, ChannelBlacklistEntry.ItemGenerationArguments)) in
            var rightNavigationButton: ItemListNavigationButton?
            var secondaryRightNavigationButton: ItemListNavigationButton?
            if let blacklist = blacklist, !blacklist.isEmpty {
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
                
                if !state.editing {
                    if rightNavigationButton == nil {
                        rightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                            updateState { state in
                                return state.withUpdatedSearchingMembers(true)
                            }
                        })
                    } else {
                        secondaryRightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                            updateState { state in
                                return state.withUpdatedSearchingMembers(true)
                            }
                        })
                    }
                }
            }
            
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if blacklist == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
            
            let previous = previousBlacklist
            previousBlacklist = blacklist
            
            var searchItem: ItemListControllerSearch?
            if state.searchingMembers {
                searchItem = ChannelMembersSearchItem(account: account, peerId: peerId, searchMode: .searchBanned, cancel: {
                    updateState { state in
                        return state.withUpdatedSearchingMembers(false)
                    }
                }, openPeer: { _, rendered in
                    if let participant = rendered?.participant, case .member = participant, let channel = peerViewMainPeer(view) as? TelegramChannel {
                        if case .group = channel.info {
                            arguments.openPeer(participant)
                          //  presentControllerImpl?(channelBannedMemberController(account: account, peerId: peerId, memberId: participant.peerId, initialParticipant: participant, updated: { _ in
                          //  }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                        } else if let rendered = rendered {
                            arguments.openPeerInfo(rendered.peer)
                        }
                    }
                })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Channel_BlackList_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, secondaryRightNavigationButton: secondaryRightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
            let listState = ItemListNodeState(entries: channelBlacklistControllerEntries(presentationData: presentationData, view: view, state: state, blacklist: blacklist), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, animateChanges: previous != nil && blacklist != nil && (previous!.restricted.count + previous!.banned.count) >= (blacklist!.restricted.count + blacklist!.banned.count))
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
            controller.view.endEditing(true)
        }
    }
    
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }
    controller.visibleBottomContentOffsetChanged = { offset in
        if case let .known(value) = offset, value < 40.0 {
            account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
        }
    }
    return controller
}
