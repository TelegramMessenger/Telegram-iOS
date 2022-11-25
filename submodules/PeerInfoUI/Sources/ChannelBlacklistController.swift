import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import AlertUI
import PresentationDataUtils
import ItemListPeerItem

private final class ChannelBlacklistControllerArguments {
    let context: AccountContext
    
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let addPeer: () -> Void
    let removePeer: (PeerId) -> Void
    let openPeer: (RenderedChannelParticipant) -> Void
    
    init(context: AccountContext, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addPeer: @escaping  () -> Void, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping (RenderedChannelParticipant) -> Void) {
        self.context = context
        self.addPeer = addPeer
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.openPeer = openPeer
    }
}

private enum ChannelBlacklistSection: Int32 {
    case add
    case banned
}

private enum ChannelBlacklistEntryStableId: Hashable {
    case index(Int)
    case peer(PeerId)
}

private enum ChannelBlacklistEntry: ItemListNodeEntry {
    case add(PresentationTheme, String)
    case addInfo(PresentationTheme, String)
    case bannedHeader(PresentationTheme, String)
    case peerItem(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .add, .addInfo:
                return ChannelBlacklistSection.add.rawValue
            case .bannedHeader:
                return ChannelBlacklistSection.banned.rawValue
            case .peerItem:
                return ChannelBlacklistSection.banned.rawValue
        }
    }
    
    var stableId: ChannelBlacklistEntryStableId {
        switch self {
            case .add:
                return .index(0)
            case .addInfo:
                return .index(1)
            case .bannedHeader:
                return .index(2)
            case let .peerItem(_, _, _, _, _, participant, _, _):
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
            case let .addInfo(lhsTheme, lhsText):
                if case let .addInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .peerItem(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsIndex, lhsParticipant, lhsEditing, lhsEnabled):
                if case let .peerItem(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsIndex, rhsParticipant, rhsEditing, rhsEnabled) = rhs {
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
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelBlacklistEntry, rhs: ChannelBlacklistEntry) -> Bool {
        switch lhs {
            case let .peerItem(_, _, _, _, index, _, _, _):
                switch rhs {
                    case let .peerItem(_, _, _, _, rhsIndex, _, _, _):
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
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelBlacklistControllerArguments
        switch self {
            case let .add(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.addPeer()
                })
            case let .addInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .bannedHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .peerItem(_, strings, dateTimeFormat, nameDisplayOrder, _, participant, editing, enabled):
                var text: ItemListPeerItemText = .none
                switch participant.participant {
                    case let .member(_, _, _, banInfo, _):
                        if let banInfo = banInfo, let peer = participant.peers[banInfo.restrictedBy] {
                            text = .text(strings.Channel_Management_RemovedBy(EnginePeer(peer).displayTitle(strings: strings, displayOrder: nameDisplayOrder)).string, .secondary)
                        }
                    default:
                        break
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(participant.peer), presence: nil, text: text, label: .none, editing: editing, switchValue: nil, enabled: enabled, selectable: true, sectionId: self.section, action: {
                    arguments.openPeer(participant)
                }, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
        }
    }
}

private struct ChannelBlacklistControllerState: Equatable {
    let referenceTimestamp: Int32
    let editing: Bool
    let peerIdWithRevealedOptions: PeerId?
    let removingPeerId: PeerId?
    let searchingMembers: Bool

    init(referenceTimestamp: Int32) {
        self.referenceTimestamp = referenceTimestamp
        self.editing = false
        self.peerIdWithRevealedOptions = nil
        self.removingPeerId = nil
        self.searchingMembers = false
    }
    
    init(referenceTimestamp: Int32, editing: Bool, peerIdWithRevealedOptions: PeerId?, removingPeerId: PeerId?, searchingMembers: Bool) {
        self.referenceTimestamp = referenceTimestamp
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.removingPeerId = removingPeerId
        self.searchingMembers = searchingMembers
    }
    
    static func ==(lhs: ChannelBlacklistControllerState, rhs: ChannelBlacklistControllerState) -> Bool {
        if lhs.referenceTimestamp != rhs.referenceTimestamp {
            return false
        }
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
        return ChannelBlacklistControllerState(referenceTimestamp: self.referenceTimestamp, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, searchingMembers: searchingMembers)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(referenceTimestamp: self.referenceTimestamp, editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, searchingMembers: self.searchingMembers)
    }
    
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(referenceTimestamp: self.referenceTimestamp, editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(referenceTimestamp: self.referenceTimestamp, editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: removingPeerId, searchingMembers: self.searchingMembers)
    }
}

private func channelBlacklistControllerEntries(presentationData: PresentationData, view: PeerView, state: ChannelBlacklistControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelBlacklistEntry] {
    var entries: [ChannelBlacklistEntry] = []
    
    if let channel = view.peers[view.peerId] as? TelegramChannel, let participants = participants {
        entries.append(.add(presentationData.theme, presentationData.strings.GroupRemoved_Remove))
        
        let isGroup: Bool
        if case .group = channel.info {
            isGroup = true
        } else {
            isGroup = false
        }
        entries.append(.addInfo(presentationData.theme, isGroup ? presentationData.strings.GroupRemoved_RemoveInfo : presentationData.strings.ChannelRemoved_RemoveInfo))
        
        var index: Int32 = 0
        if !participants.isEmpty {
            entries.append(.bannedHeader(presentationData.theme, presentationData.strings.GroupRemoved_UsersSectionTitle))
        }
        for participant in participants {
            entries.append(.peerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, index, participant, ItemListPeerItemEditing(editable: true, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id))
            index += 1
        }
    }
    
    return entries
}

public func channelBlacklistController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelBlacklistControllerState(referenceTimestamp: Int32(Date().timeIntervalSince1970)), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelBlacklistControllerState(referenceTimestamp: Int32(Date().timeIntervalSince1970)))
    let updateState: ((ChannelBlacklistControllerState) -> ChannelBlacklistControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var getNavigationControllerImpl: (() -> NavigationController?)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissInputImpl: (() -> Void)?

    let actionsDisposable = DisposableSet()
    
    let updateBannedDisposable = MetaDisposable()
    actionsDisposable.add(updateBannedDisposable)
    
    let removePeerDisposable = MetaDisposable()
    actionsDisposable.add(removePeerDisposable)
    
    let peerView = Promise<PeerView>()
    peerView.set(context.account.viewTracker.peerView(peerId))
    let blacklistPromise = Promise<[RenderedChannelParticipant]?>(nil)
    
    let arguments = ChannelBlacklistControllerArguments(context: context, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, addPeer: {
        var dismissController: (() -> Void)?
        let controller = ChannelMembersSearchController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, mode: .ban, openPeer: { peer, participant in
            if let participant = participant {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                switch participant.participant {
                    case .creator:
                        return
                    case let .member(_, _, adminInfo, _, _):
                        if let adminInfo = adminInfo, adminInfo.promotedBy != context.account.peerId {
                            presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_Members_AddBannedErrorAdmin, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                            return
                        }
                }
            }
            let _ = (context.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { channel in
                guard let _ = channel as? TelegramChannel else {
                    return
                }
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let progress = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                presentControllerImpl?(progress, nil)
                removePeerDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: peer.id, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max))
                    |> deliverOnMainQueue).start(error: { _ in
                    }, completed: { [weak progress] in 
                        progress?.dismiss()
                        dismissController?()
                    }))
            })
        })
        dismissController = { [weak controller] in
            controller?.dismiss()
        }
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, removePeer: { memberId in
        updateState {
            return $0.withUpdatedRemovingPeerId(memberId)
        }
        
        removePeerDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: memberId, bannedRights: nil)  |> deliverOnMainQueue).start(error: { _ in
        }, completed: {
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
        }))
    }, openPeer: { participant in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerView in
            guard let channel = peerView.peers[peerId] as? TelegramChannel else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = []
            if !EnginePeer(participant.peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).isEmpty {
                items.append(ActionSheetTextItem(title: EnginePeer(participant.peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)))
            }
            let viewInfoTitle: String
            if participant.peer is TelegramChannel {
                viewInfoTitle = presentationData.strings.GroupRemoved_ViewChannelInfo
            } else {
                viewInfoTitle = presentationData.strings.GroupRemoved_ViewUserInfo
            }
            items.append(ActionSheetButtonItem(title: viewInfoTitle, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                if participant.peer is TelegramChannel {
                    if let navigationController = getNavigationControllerImpl?() {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(EnginePeer(participant.peer))))
                    }
                } else if let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: participant.peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                    pushControllerImpl?(infoController)
                }
            }))
            if case .group = channel.info, channel.hasPermission(.inviteMembers) {
                items.append(ActionSheetButtonItem(title: presentationData.strings.GroupRemoved_AddToGroup, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    let memberId = participant.peer.id
                    updateState {
                        return $0.withUpdatedRemovingPeerId(memberId)
                    }
                    let signal = context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: memberId, bannedRights: nil)
                    |> ignoreValues
                    |> then(
                        context.peerChannelMemberCategoriesContextsManager.addMember(engine: context.engine, peerId: peerId, memberId: memberId)
                        |> map { _ -> Void in
                        }
                        |> `catch` { _ -> Signal<Void, NoError> in
                            return .complete()
                        }
                        |> ignoreValues
                    )
                    removePeerDisposable.set((signal |> deliverOnMainQueue).start(error: { _ in
                    }, completed: {
                        updateState {
                            return $0.withUpdatedRemovingPeerId(nil)
                        }
                    }))
                }))
            }
            items.append(ActionSheetButtonItem(title: presentationData.strings.GroupRemoved_DeleteUser, color: .destructive, font: .default, enabled: true, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let memberId = participant.peer.id
                updateState {
                    return $0.withUpdatedRemovingPeerId(memberId)
                }
                
                removePeerDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: memberId, bannedRights: nil)  |> deliverOnMainQueue).start(error: { _ in
                }, completed: {
                    updateState {
                        return $0.withUpdatedRemovingPeerId(nil)
                    }
                }))
            }))
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            presentControllerImpl?(actionSheet, nil)
        })
    })
    
    let (listDisposable, loadMoreControl) = context.peerChannelMemberCategoriesContextsManager.banned(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, updated: { listState in
        if case .loading(true) = listState.loadingState, listState.list.isEmpty {
            blacklistPromise.set(.single(nil))
        } else {
            blacklistPromise.set(.single(listState.list))
        }
    })
    actionsDisposable.add(listDisposable)
    
    let previousParticipantsValue = Atomic<[RenderedChannelParticipant]?>(value: nil)
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(), presentationData, statePromise.get(), peerView.get(), blacklistPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state, view, participants -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var rightNavigationButton: ItemListNavigationButton?
        var secondaryRightNavigationButton: ItemListNavigationButton?
        if let participants = participants, !participants.isEmpty {
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
        if participants == nil {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }
        
        let previous = previousParticipantsValue.swap(participants)
        
        var searchItem: ItemListControllerSearch?
        if state.searchingMembers {
            searchItem = ChannelMembersSearchItem(context: context, peerId: peerId, searchContext: nil, searchMode: .searchKicked, cancel: {
                updateState { state in
                    return state.withUpdatedSearchingMembers(false)
                }
            }, openPeer: { _, rendered in
                if let rendered = rendered, case .member = rendered.participant {
                    arguments.openPeer(rendered)
                }
            }, pushController: { c in
                pushControllerImpl?(c)
            }, dismissInput: {
                dismissInputImpl?()
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.GroupRemoved_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, secondaryRightNavigationButton: secondaryRightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelBlacklistControllerEntries(presentationData: presentationData, view: view, state: state, participants: participants), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, animateChanges: previous != nil && participants != nil && previous!.count >= participants!.count)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
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
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    controller.visibleBottomContentOffsetChanged = { offset in
        if case let .known(value) = offset, value < 40.0 {
            context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
        }
    }
    return controller
}
