import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChannelPermissionsControllerArguments {
    let account: Account
    
    let updatePermission: (TelegramChatBannedRightsFlags, Bool) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let addPeer: () -> Void
    let removePeer: (PeerId) -> Void
    let openPeer: (ChannelParticipant) -> Void
    let openPeerInfo: (Peer) -> Void
    let openKicked: () -> Void
    
    init(account: Account, updatePermission: @escaping (TelegramChatBannedRightsFlags, Bool) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addPeer: @escaping  () -> Void, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping (ChannelParticipant) -> Void, openPeerInfo: @escaping (Peer) -> Void, openKicked: @escaping () -> Void) {
        self.account = account
        self.updatePermission = updatePermission
        self.addPeer = addPeer
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.openPeer = openPeer
        self.openPeerInfo = openPeerInfo
        self.openKicked = openKicked
    }
}

private enum ChannelPermissionsSection: Int32 {
    case permissions
    case kicked
    case exceptions
}

private enum ChannelPermissionsEntryStableId: Hashable {
    case index(Int)
    case peer(PeerId)
}

private enum ChannelPermissionsEntry: ItemListNodeEntry {
    case permissionsHeader(PresentationTheme, String)
    case permission(PresentationTheme, Int, String, Bool, TelegramChatBannedRightsFlags)
    case kicked(PresentationTheme, String, String)
    case exceptionsHeader(PresentationTheme, String)
    case add(PresentationTheme, String)
    case peerItem(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .permissionsHeader, .permission:
                return ChannelPermissionsSection.permissions.rawValue
            case .kicked:
                return ChannelPermissionsSection.kicked.rawValue
            case .exceptionsHeader, .add, .peerItem:
                return ChannelPermissionsSection.exceptions.rawValue
        }
    }
    
    var stableId: ChannelPermissionsEntryStableId {
        switch self {
            case .permissionsHeader:
                return .index(0)
            case let .permission(_, index, _, _, _):
                return .index(1 + index)
            case .kicked:
                return .index(1000)
            case .exceptionsHeader:
                return .index(1001)
            case .add:
                return .index(1002)
            case let .peerItem(_, _, _, _, _, participant, _, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelPermissionsEntry, rhs: ChannelPermissionsEntry) -> Bool {
        switch lhs {
            case let .permissionsHeader(lhsTheme, lhsText):
                if case let .permissionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .permission(theme, index, title, value, rights):
                if case .permission(theme, index, title, value, rights) = rhs {
                    return true
                } else {
                    return false
                }
            case let .kicked(lhsTheme, lhsText, lhsValue):
                if case let .kicked(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .exceptionsHeader(lhsTheme, lhsText):
                if case let .exceptionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .add(lhsTheme, lhsText):
                if case let .add(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .peerItem(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsIndex, lhsParticipant, lhsEditing, lhsEnabled, lhsCanOpen):
                if case let .peerItem(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsIndex, rhsParticipant, rhsEditing, rhsEnabled, rhsCanOpen) = rhs {
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
    
    static func <(lhs: ChannelPermissionsEntry, rhs: ChannelPermissionsEntry) -> Bool {
        switch lhs {
            case let .peerItem(_, _, _, _, index, _, _, _, _):
                switch rhs {
                    case let .peerItem(_, _, _, _, rhsIndex, _, _, _, _):
                        return index < rhsIndex
                    default:
                        return false
                }
            default:
                if case let .index(lhsIndex) = lhs.stableId {
                    if case let .index(rhsIndex) = rhs.stableId {
                        return lhsIndex < rhsIndex
                    } else {
                        return true
                    }
                } else {
                    assertionFailure()
                    return false
                }
        }
    }
    
    func item(_ arguments: ChannelPermissionsControllerArguments) -> ListViewItem {
        switch self {
            case let .permissionsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .permission(theme, _, title, value, rights):
                return ItemListSwitchItem(theme: theme, title: title, value: value, type: .icon, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updatePermission(rights, value)
                })
            case let .kicked(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openKicked()
                })
            case let .exceptionsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .add(theme, text):
                return ItemListPeerActionItem(theme: theme, icon: PresentationResourcesItemList.addPersonIcon(theme), title: text, sectionId: self.section, editing: false, action: {
                    arguments.addPeer()
                })
            case let .peerItem(theme, strings, dateTimeFormat, nameDisplayOrder, _, participant, editing, enabled, canOpen):
                var text: ItemListPeerItemText = .none
                switch participant.participant {
                    case let .member(_, _, _, banInfo):
                        var exceptionsString = ""
                        if let banInfo = banInfo {
                            for rights in allGroupPermissionList {
                                if banInfo.rights.flags.contains(rights) {
                                    if !exceptionsString.isEmpty {
                                        exceptionsString.append(", ")
                                    }
                                    exceptionsString.append(compactStringForGroupPermission(strings: strings, right: rights))
                                }
                            }
                            text = .text(exceptionsString)
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

private struct ChannelPermissionsControllerState: Equatable {
    var peerIdWithRevealedOptions: PeerId?
    var removingPeerId: PeerId?
    var searchingMembers: Bool = false
    var modifiedRightsFlags: TelegramChatBannedRightsFlags?
}

func stringForGroupPermission(strings: PresentationStrings, right: TelegramChatBannedRightsFlags) -> String {
    if right.contains(.banSendMessages) {
        return strings.Channel_BanUser_PermissionSendMessages
    } else if right.contains(.banSendMedia) {
        return strings.Channel_BanUser_PermissionSendMedia
    } else if right.contains(.banSendGifs) {
        return strings.Channel_BanUser_PermissionSendStickersAndGifs
    } else if right.contains(.banEmbedLinks) {
        return strings.Channel_BanUser_PermissionEmbedLinks
    } else if right.contains(.banSendPolls) {
        return strings.Channel_BanUser_PermissionSendPolls
    } else if right.contains(.banChangeInfo) {
        return strings.Channel_BanUser_PermissionChangeGroupInfo
    } else if right.contains(.banAddMembers) {
        return strings.Channel_BanUser_PermissionAddMembers
    } else if right.contains(.banPinMessages) {
        return strings.Channel_EditAdmin_PermissionPinMessages
    } else {
        return ""
    }
}

func compactStringForGroupPermission(strings: PresentationStrings, right: TelegramChatBannedRightsFlags) -> String {
    if right.contains(.banSendMessages) {
        return strings.GroupPermission_NoSendMessages
    } else if right.contains(.banSendMedia) {
        return strings.GroupPermission_NoSendMedia
    } else if right.contains(.banSendGifs) {
        return strings.GroupPermission_NoSendGifs
    } else if right.contains(.banEmbedLinks) {
        return strings.GroupPermission_NoSendLinks
    } else if right.contains(.banSendPolls) {
        return strings.GroupPermission_NoSendPolls
    } else if right.contains(.banChangeInfo) {
        return strings.GroupPermission_NoChangeInfo
    } else if right.contains(.banAddMembers) {
        return strings.GroupPermission_NoAddMembers
    } else if right.contains(.banPinMessages) {
        return strings.GroupPermission_NoPinMessages
    } else {
        return ""
    }
}

let allGroupPermissionList: [TelegramChatBannedRightsFlags] = [
    .banSendMessages,
    .banSendMedia,
    .banSendGifs,
    .banEmbedLinks,
    .banSendPolls,
    .banAddMembers,
    .banPinMessages,
    .banChangeInfo
]

func groupPermissionDependencies(_ right: TelegramChatBannedRightsFlags) -> TelegramChatBannedRightsFlags {
    if right.contains(.banSendMedia) {
        return [.banSendMessages]
    } else if right.contains(.banSendGifs) {
        return [.banSendMessages]
    } else if right.contains(.banEmbedLinks) {
        return [.banSendMessages]
    } else if right.contains(.banSendPolls) {
        return [.banSendMessages]
    } else if right.contains(.banChangeInfo) {
        return []
    } else if right.contains(.banAddMembers) {
        return []
    } else if right.contains(.banPinMessages) {
        return []
    } else {
        return []
    }
}

private func completeRights(_ flags: TelegramChatBannedRightsFlags) -> TelegramChatBannedRightsFlags {
    var result = flags
    result.remove(.banReadMessages)
    if result.contains(.banSendGifs) {
        result.insert(.banSendStickers)
        result.insert(.banSendGifs)
        result.insert(.banSendGames)
    } else {
        result.remove(.banSendStickers)
        result.remove(.banSendGifs)
        result.remove(.banSendGames)
    }
    if result.contains(.banEmbedLinks) {
        result.insert(.banSendInline)
    } else {
        result.remove(.banSendInline)
    }
    return result
}

private func channelPermissionsControllerEntries(presentationData: PresentationData, view: PeerView, state: ChannelPermissionsControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelPermissionsEntry] {
    var entries: [ChannelPermissionsEntry] = []
    
    if let _ = view.peers[view.peerId] as? TelegramChannel, let participants = participants {
        let cachedData = view.cachedData as? CachedChannelData
        
        let effectiveRightsFlags: TelegramChatBannedRightsFlags
        if let modifiedRightsFlags = state.modifiedRightsFlags {
            effectiveRightsFlags = modifiedRightsFlags
        } else if let defaultBannedRightsFlags = cachedData?.defaultBannedRights?.flags {
            effectiveRightsFlags = defaultBannedRightsFlags
        } else {
            effectiveRightsFlags = TelegramChatBannedRightsFlags()
        }
        
        entries.append(.permissionsHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_SectionTitle))
        var rightIndex: Int = 0
        for rights in allGroupPermissionList {
            entries.append(.permission(presentationData.theme, rightIndex, stringForGroupPermission(strings: presentationData.strings, right: rights), !effectiveRightsFlags.contains(rights), rights))
            rightIndex += 1
        }
        
        entries.append(.kicked(presentationData.theme, presentationData.strings.GroupInfo_Permissions_Removed, cachedData?.participantsSummary.kickedCount.flatMap({ "\($0)" }) ?? ""))
        entries.append(.exceptionsHeader(presentationData.theme, presentationData.strings.GroupInfo_Permissions_Exceptions))
        entries.append(.add(presentationData.theme, presentationData.strings.GroupInfo_Permissions_AddException))
        
        var index: Int32 = 0
        for participant in participants {
            entries.append(.peerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, index, participant, ItemListPeerItemEditing(editable: true, editing: false, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id, true))
            index += 1
        }
    }
    
    return entries
}

public func channelPermissionsController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelPermissionsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelPermissionsControllerState())
    let updateState: ((ChannelPermissionsControllerState) -> ChannelPermissionsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updateBannedDisposable = MetaDisposable()
    actionsDisposable.add(updateBannedDisposable)
    
    let removePeerDisposable = MetaDisposable()
    actionsDisposable.add(removePeerDisposable)
    
    let peersPromise = Promise<[RenderedChannelParticipant]?>(nil)
    let (disposable, loadMoreControl) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.restricted(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, updated: { state in
        peersPromise.set(.single(state.list))
    })
    actionsDisposable.add(disposable)
    
    let updateDefaultRightsDisposable = MetaDisposable()
    actionsDisposable.add(updateDefaultRightsDisposable)
    
    let peerView = Promise<PeerView>()
    peerView.set(account.viewTracker.peerView(peerId))
    
    let arguments = ChannelPermissionsControllerArguments(account: account, updatePermission: { rights, value in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            if let cachedData = view.cachedData as? CachedChannelData {
                updateState { state in
                    var state = state
                    var effectiveRightsFlags: TelegramChatBannedRightsFlags
                    if let modifiedRightsFlags = state.modifiedRightsFlags {
                        effectiveRightsFlags = modifiedRightsFlags
                    } else if let defaultBannedRightsFlags = cachedData.defaultBannedRights?.flags {
                        effectiveRightsFlags = defaultBannedRightsFlags
                    } else {
                        effectiveRightsFlags = TelegramChatBannedRightsFlags()
                    }
                    if value {
                        effectiveRightsFlags.remove(rights)
                        effectiveRightsFlags = effectiveRightsFlags.subtracting(groupPermissionDependencies(rights))
                    } else {
                        effectiveRightsFlags.insert(rights)
                        for right in allGroupPermissionList {
                            if groupPermissionDependencies(right).contains(rights) {
                                effectiveRightsFlags.insert(right)
                            }
                        }
                    }
                    state.modifiedRightsFlags = effectiveRightsFlags
                    return state
                }
                let state = stateValue.with { $0 }
                if let modifiedRightsFlags = state.modifiedRightsFlags {
                    updateDefaultRightsDisposable.set((updateDefaultChannelMemberBannedRights(account: account, peerId: peerId, rights: TelegramChatBannedRights(flags: completeRights(modifiedRightsFlags), untilDate: Int32.max))
                    |> deliverOnMainQueue).start())
                }
            }
        })
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            var state = state
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                state.peerIdWithRevealedOptions = peerId
            }
            return state
        }
    }, addPeer: {
        var dismissController: (() -> Void)?
        let controller = ChannelMembersSearchController(account: account, peerId: peerId, mode: .ban, openPeer: { peer, participant in
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
                    dismissController?()
                    guard let _ = channel as? TelegramChannel else {
                        return
                    }
                        presentControllerImpl?(channelBannedMemberController(account: account, peerId: peerId, memberId: peer.id, initialParticipant: participant?.participant, updated: { _ in
                    }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                })
        })
        dismissController = { [weak controller] in
            controller?.dismiss()
        }
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, removePeer: { memberId in
        updateState { state in
            var state = state
            state.removingPeerId = memberId
            return state
        }
        
        removePeerDisposable.set((account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: account, peerId: peerId, memberId: memberId, bannedRights: nil)
        |> deliverOnMainQueue).start(error: { _ in
            updateState { state in
                var state = state
                state.removingPeerId = nil
                return state
            }
        }, completed: {
            updateState { state in
                var state = state
                state.removingPeerId = nil
                return state
            }
        }))
    }, openPeer: { participant in
        presentControllerImpl?(channelBannedMemberController(account: account, peerId: peerId, memberId: participant.peerId, initialParticipant: participant, updated: { _ in
        }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openPeerInfo: { peer in
        if let controller = peerInfoController(account: account, peer: peer) {
            pushControllerImpl?(controller)
        }
    }, openKicked: {
        pushControllerImpl?(channelBlacklistController(account: account, peerId: peerId))
    })
    
    let previousParticipants = Atomic<[RenderedChannelParticipant]?>(value: nil)
    
    let signal = combineLatest(queue: .mainQueue(), (account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), peerView.get(), peersPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state, view, participants -> (ItemListControllerState, (ItemListNodeState<ChannelPermissionsEntry>, ChannelPermissionsEntry.ItemGenerationArguments)) in
        var rightNavigationButton: ItemListNavigationButton?
        if let participants = participants, !participants.isEmpty {
            rightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .bold, enabled: true, action: {
                updateState { state in
                    var state = state
                    state.searchingMembers = true
                    return state
                }
            })
        }
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if participants == nil {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }
        
        let previous = previousParticipants.swap(participants)
        
        var searchItem: ItemListControllerSearch?
        if state.searchingMembers {
            searchItem = ChannelMembersSearchItem(account: account, peerId: peerId, searchMode: .searchBanned, cancel: {
                updateState { state in
                    var state = state
                    state.searchingMembers = false
                    return state
                }
            }, openPeer: { _, rendered in
                if let participant = rendered?.participant, case .member = participant, let _ = peerViewMainPeer(view) as? TelegramChannel {
                    updateState { state in
                        var state = state
                        state.searchingMembers = false
                        return state
                    }
                    presentControllerImpl?(channelBannedMemberController(account: account, peerId: peerId, memberId: participant.peerId, initialParticipant: participant, updated: { _ in
                    }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
            }, present: { c, a in
                presentControllerImpl?(c, a)
            })
        }
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.GroupInfo_Permissions_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(entries: channelPermissionsControllerEntries(presentationData: presentationData, view: view, state: state, participants: participants), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, animateChanges: previous != nil && participants != nil && previous!.count >= participants!.count)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
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
