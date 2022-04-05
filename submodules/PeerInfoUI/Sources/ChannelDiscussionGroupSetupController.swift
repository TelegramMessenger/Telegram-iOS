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
import ItemListPeerActionItem
import ChatListFilterSettingsHeaderItem

private final class ChannelDiscussionGroupSetupControllerArguments {
    let context: AccountContext
    let createGroup: () -> Void
    let selectGroup: (PeerId) -> Void
    let unlinkGroup: () -> Void
    
    init(context: AccountContext, createGroup: @escaping () -> Void, selectGroup: @escaping (PeerId) -> Void, unlinkGroup: @escaping () -> Void) {
        self.context = context
        self.createGroup = createGroup
        self.selectGroup = selectGroup
        self.unlinkGroup = unlinkGroup
    }
}

private enum ChannelDiscussionGroupSetupControllerSection: Int32 {
    case header
    case groups
    case unlink
}

private enum ChannelDiscussionGroupSetupControllerEntryStableId: Hashable {
    case id(Int)
    case peer(PeerId)
}

private enum ChannelDiscussionGroupSetupControllerEntry: ItemListNodeEntry {
    case header(PresentationTheme, PresentationStrings, String?, Bool, String)
    case create(PresentationTheme, String)
    case group(Int, PresentationTheme, PresentationStrings, Peer, PresentationPersonNameOrder)
    case groupsInfo(PresentationTheme, String)
    case unlink(PresentationTheme, String)
    
    var section: Int32 {
        switch self {
            case .header:
                return ChannelDiscussionGroupSetupControllerSection.header.rawValue
            case .create, .group, .groupsInfo:
                return ChannelDiscussionGroupSetupControllerSection.groups.rawValue
            case .unlink:
                return ChannelDiscussionGroupSetupControllerSection.unlink.rawValue
        }
    }
    
    var stableId: ChannelDiscussionGroupSetupControllerEntryStableId {
        switch self {
            case .header:
                return .id(0)
            case .create:
                return .id(1)
            case let .group(_, _, _, peer, _):
                return .peer(peer.id)
            case .groupsInfo:
                return .id(2)
            case .unlink:
                return .id(3)
        }
    }
    
    static func ==(lhs: ChannelDiscussionGroupSetupControllerEntry, rhs: ChannelDiscussionGroupSetupControllerEntry) -> Bool {
        switch lhs {
            case let .header(lhsTheme, lhsStrings, lhsTitle, lhsIsGroup, lhsLabel):
                if case let .header(rhsTheme, rhsStrings, rhsTitle, rhsIsGroup, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsTitle == rhsTitle, lhsIsGroup == rhsIsGroup, lhsLabel == rhsLabel {
                    return true
                } else {
                    return false
                }
            case let .create(lhsTheme, lhsTitle):
                if case let .create(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .group(lhsIndex, lhsTheme, lhsStrings, lhsPeer, lhsNameOrder):
                if case let .group(rhsIndex, rhsTheme, rhsStrings, rhsPeer, rhsNameOrder) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings == rhsStrings, lhsPeer.isEqual(rhsPeer), lhsNameOrder == rhsNameOrder {
                    return true
                } else {
                    return false
                }
            case let .groupsInfo(lhsTheme, lhsTitle):
                if case let .groupsInfo(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .unlink(lhsTheme, lhsTitle):
                if case let .unlink(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
        }
    }
    
    private var sortIndex: Int {
        switch self {
            case .header:
                return 0
            case .create:
                return 1
            case let .group(index, _, _, _, _):
                return 10 + index
            case .groupsInfo:
                return 1000
            case .unlink:
                return 1001
        }
    }
    
    static func <(lhs: ChannelDiscussionGroupSetupControllerEntry, rhs: ChannelDiscussionGroupSetupControllerEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelDiscussionGroupSetupControllerArguments
        switch self {
            case let .header(_, _, title, isGroup, _):
                let text: String
                if let title = title {
                    if isGroup {
                        text = presentationData.strings.Channel_CommentsGroup_HeaderGroupSet(title).string
                    } else {
                        text = presentationData.strings.Channel_CommentsGroup_HeaderSet(title).string
                    }
                } else {
                    text = presentationData.strings.Channel_CommentsGroup_Header
                }
                return ChatListFilterSettingsHeaderItem(context: arguments.context, theme: presentationData.theme, text: text, animation: .discussionGroupSetup, sectionId: self.section)
            case let .create(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(theme), title: text, sectionId: self.section, editing: false, action: {
                    arguments.createGroup()
                })
            case let .group(_, _, strings, peer, nameOrder):
                let text: String
                if let peer = peer as? TelegramChannel, let addressName = peer.addressName, !addressName.isEmpty {
                    text = "@\(addressName)"
                } else if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                    text = strings.Channel_DiscussionGroup_PrivateChannel
                } else {
                    text = strings.Channel_DiscussionGroup_PrivateGroup
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: nameOrder, context: arguments.context, peer: EnginePeer(peer), aliasHandling: .standard, nameStyle: .plain, presence: nil, text: .text(text, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.selectGroup(peer.id)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
            case let .groupsInfo(_, title):
                return ItemListTextItem(presentationData: presentationData, text: .plain(title), sectionId: self.section)
            case let .unlink(_, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.unlinkGroup()
                })
        }
    }
}

private func channelDiscussionGroupSetupControllerEntries(presentationData: PresentationData, view: PeerView, groups: [Peer]?) -> [ChannelDiscussionGroupSetupControllerEntry] {
    guard let peer = view.peers[view.peerId] as? TelegramChannel, let cachedData = view.cachedData as? CachedChannelData else {
        return []
    }
    
    let canEditChannel = peer.hasPermission(.changeInfo)
    
    var entries: [ChannelDiscussionGroupSetupControllerEntry] = []
    
    if case let .known(maybeLinkedDiscussionPeerId) = cachedData.linkedDiscussionPeerId, let linkedDiscussionPeerId = maybeLinkedDiscussionPeerId {
        if let group = view.peers[linkedDiscussionPeerId] {
            if case .group = peer.info {
                entries.append(.header(presentationData.theme, presentationData.strings, EnginePeer(group).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), true, presentationData.strings.Channel_DiscussionGroup_HeaderLabel))
            } else {
                entries.append(.header(presentationData.theme, presentationData.strings, EnginePeer(group).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), false, presentationData.strings.Channel_DiscussionGroup_HeaderLabel))
            }
            
            entries.append(.group(0, presentationData.theme, presentationData.strings, group, presentationData.nameDisplayOrder))
            entries.append(.groupsInfo(presentationData.theme, presentationData.strings.Channel_DiscussionGroup_Info))
            if canEditChannel {
                let unlinkText: String
                if case .group = peer.info {
                    unlinkText = presentationData.strings.Channel_DiscussionGroup_UnlinkChannel
                } else {
                    unlinkText = presentationData.strings.Channel_DiscussionGroup_UnlinkGroup
                }
                entries.append(.unlink(presentationData.theme, unlinkText))
            }
        }
    } else if case .broadcast = peer.info, canEditChannel {
        if let groups = groups {
            entries.append(.header(presentationData.theme, presentationData.strings, nil, true, presentationData.strings.Channel_DiscussionGroup_HeaderLabel))
            
            entries.append(.create(presentationData.theme, presentationData.strings.Channel_DiscussionGroup_Create))
            var index = 0
            for group in groups {
                entries.append(.group(index, presentationData.theme, presentationData.strings, group, presentationData.nameDisplayOrder))
                index += 1
            }
            entries.append(.groupsInfo(presentationData.theme, presentationData.strings.Channel_DiscussionGroup_Info))
        }
    }
    
    return entries
}

private struct ChannelDiscussionGroupSetupControllerState: Equatable {
    var searching: Bool = false
}

public func channelDiscussionGroupSetupController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelDiscussionGroupSetupControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelDiscussionGroupSetupControllerState())
    let updateState: ((ChannelDiscussionGroupSetupControllerState) -> ChannelDiscussionGroupSetupControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let groupPeers = Promise<[Peer]?>()
    groupPeers.set(.single(nil)
    |> then(
        context.engine.peers.availableGroupsForChannelDiscussion()
        |> map(Optional.init)
        |> `catch` { _ -> Signal<[Peer]?, NoError> in
            return .single(nil)
        }
    ))
    
    let peerView = context.account.viewTracker.peerView(peerId)
    
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var navigateToGroupImpl: ((PeerId) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let applyGroupDisposable = MetaDisposable()
    actionsDisposable.add(applyGroupDisposable)
    
    let arguments = ChannelDiscussionGroupSetupControllerArguments(context: context, createGroup: {
        let _ = (context.account.postbox.transaction { transaction -> Peer? in
            transaction.getPeer(peerId)
        }
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            pushControllerImpl?(context.sharedContext.makeCreateGroupController(context: context, peerIds: [], initialTitle: EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) + " Chat", mode: .supergroup, completion: { groupId, dismiss in
                var applySignal = context.engine.peers.updateGroupDiscussionForChannel(channelId: peerId, groupId: groupId)
                var cancelImpl: (() -> Void)?
                let progressSignal = Signal<Never, NoError> { subscriber in
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    presentControllerImpl?(controller, nil)
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.15, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                
                applySignal = applySignal
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                cancelImpl = {
                    applyGroupDisposable.set(nil)
                }
                
                applyGroupDisposable.set((applySignal
                |> deliverOnMainQueue).start(error: { _ in
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                    dismiss()
                }, completed: {
                    dismiss()
                    /*let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                     let controller = OverlayStatusController(theme: presentationData.theme, type: .success)
                     presentControllerImpl?(controller, nil)*/
                }))
            }))
        })
    }, selectGroup: { groupId in
        dismissInputImpl?()
        
        let _ = (context.account.postbox.transaction { transaction -> (CachedChannelData?, Peer?, Peer?) in
            return (transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData, transaction.getPeer(peerId), transaction.getPeer(groupId))
        }
        |> deliverOnMainQueue).start(next: { cachedData, channelPeer, groupPeer in
            guard let cachedData = cachedData, let channelPeer = channelPeer, let groupPeer = groupPeer else {
                return
            }
            
            if case let .known(maybeLinkedDiscussionPeerId) = cachedData.linkedDiscussionPeerId, maybeLinkedDiscussionPeerId == groupId {
                navigateToGroupImpl?(groupId)
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ChannelDiscussionGroupActionSheetItem(context: context, channelPeer: channelPeer, groupPeer: groupPeer, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder),
                ActionSheetButtonItem(title: presentationData.strings.Channel_DiscussionGroup_LinkGroup, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    var applySignal: Signal<Bool, ChannelDiscussionGroupError>
                    var updatedPeerId: PeerId? = nil
                    if let legacyGroup = groupPeer as? TelegramGroup {
                        applySignal = context.engine.peers.convertGroupToSupergroup(peerId: legacyGroup.id)
                        |> mapError { error -> ChannelDiscussionGroupError in
                            switch error {
                            case .tooManyChannels:
                                return .tooManyChannels
                            default:
                                return .generic
                            }
                        }
                        |> deliverOnMainQueue
                        |> mapToSignal { resultPeerId -> Signal<Bool, ChannelDiscussionGroupError> in
                            updatedPeerId = resultPeerId
                            
                            return context.account.postbox.transaction { transaction -> Signal<Bool, ChannelDiscussionGroupError> in
                                if let groupPeer = transaction.getPeer(resultPeerId) {
                                    let _ = (groupPeers.get()
                                    |> take(1)
                                    |> deliverOnMainQueue).start(next: { groups in
                                        guard var groups = groups else {
                                            return
                                        }
                                        for i in 0 ..< groups.count {
                                            if groups[i].id == groupId {
                                                groups[i] = groupPeer
                                                break
                                            }
                                        }
                                        groupPeers.set(.single(groups))
                                    })
                                }
                                
                                return context.engine.peers.updateGroupDiscussionForChannel(channelId: peerId, groupId: resultPeerId)
                            }
                            |> castError(ChannelDiscussionGroupError.self)
                            |> switchToLatest
                        }
                    } else {
                        applySignal = context.engine.peers.updateGroupDiscussionForChannel(channelId: peerId, groupId: groupId)
                    }
                    var cancelImpl: (() -> Void)?
                    let progressSignal = Signal<Never, NoError> { subscriber in
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                            cancelImpl?()
                        }))
                        presentControllerImpl?(controller, nil)
                        return ActionDisposable { [weak controller] in
                            Queue.mainQueue().async() {
                                controller?.dismiss()
                            }
                        }
                    }
                    |> runOn(Queue.mainQueue())
                    |> delay(0.15, queue: Queue.mainQueue())
                    let progressDisposable = progressSignal.start()
                    
                    applySignal = applySignal
                    |> afterDisposed {
                        Queue.mainQueue().async {
                            progressDisposable.dispose()
                        }
                    }
                    cancelImpl = {
                        applyGroupDisposable.set(nil)
                    }
                    
                    applyGroupDisposable.set((applySignal
                    |> deliverOnMainQueue).start(error: { error in
                        switch error {
                            case .tooManyChannels:
                                pushControllerImpl?(oldChannelsController(context: context, intent: .upgrade))
                            case .generic, .hasNotPermissions:
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                
                                updateState { state in
                                    var state = state
                                    state.searching = false
                                    return state
                                }
                            case .groupHistoryIsCurrentlyPrivate:
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_DiscussionGroup_MakeHistoryPublic, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Channel_DiscussionGroup_MakeHistoryPublicProceed, action: {
                                    var applySignal: Signal<Bool, ChannelDiscussionGroupError> = context.engine.peers.updateChannelHistoryAvailabilitySettingsInteractively(peerId: updatedPeerId ?? groupId, historyAvailableForNewMembers: true)
                                    |> mapError { _ -> ChannelDiscussionGroupError in
                                        return .generic
                                    }
                                    |> mapToSignal { _ -> Signal<Bool, ChannelDiscussionGroupError> in
                                        return .complete()
                                    }
                                    |> then(
                                        context.engine.peers.updateGroupDiscussionForChannel(channelId: peerId, groupId: updatedPeerId ?? groupId)
                                    )
                                    var cancelImpl: (() -> Void)?
                                    let progressSignal = Signal<Never, NoError> { subscriber in
                                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                        let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                            cancelImpl?()
                                        }))
                                        presentControllerImpl?(controller, nil)
                                        return ActionDisposable { [weak controller] in
                                            Queue.mainQueue().async() {
                                                controller?.dismiss()
                                            }
                                        }
                                    }
                                    |> runOn(Queue.mainQueue())
                                    |> delay(0.15, queue: Queue.mainQueue())
                                    let progressDisposable = progressSignal.start()
                                    
                                    applySignal = applySignal
                                    |> afterDisposed {
                                        Queue.mainQueue().async {
                                            progressDisposable.dispose()
                                        }
                                    }
                                    cancelImpl = {
                                        applyGroupDisposable.set(nil)
                                    }
                                    
                                    applyGroupDisposable.set((applySignal
                                    |> deliverOnMainQueue).start(error: { _ in
                                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                        presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                        
                                        updateState { state in
                                            var state = state
                                            state.searching = false
                                            return state
                                        }
                                    }, completed: {
                                        updateState { state in
                                            var state = state
                                            state.searching = false
                                            return state
                                        }
                                    }))
                                })]), nil)
                        }
                    }, completed: {
                        updateState { state in
                            var state = state
                            state.searching = false
                            return state
                        }
                    }))
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            presentControllerImpl?(actionSheet, nil)
        })
    }, unlinkGroup: {
        let _ = (context.account.postbox.transaction { transaction -> (CachedChannelData?, Peer?) in
            return (transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData, transaction.getPeer(peerId))
        }
        |> deliverOnMainQueue).start(next: { cachedData, peer in
            guard let cachedData = cachedData, let peer = peer as? TelegramChannel else {
                return
            }
            
            let applyPeerId: PeerId
            if case .broadcast = peer.info {
                applyPeerId = peerId
            } else if case let .known(maybeLinkedDiscussionPeerId) = cachedData.linkedDiscussionPeerId, let linkedDiscussionPeerId = maybeLinkedDiscussionPeerId {
                applyPeerId = linkedDiscussionPeerId
            } else {
                return
            }
            
            var applySignal = context.engine.peers.updateGroupDiscussionForChannel(channelId: applyPeerId, groupId: nil)
            var cancelImpl: (() -> Void)?
            let progressSignal = Signal<Never, NoError> { subscriber in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                    cancelImpl?()
                }))
                presentControllerImpl?(controller, nil)
                return ActionDisposable { [weak controller] in
                    Queue.mainQueue().async() {
                        controller?.dismiss()
                    }
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.15, queue: Queue.mainQueue())
            let progressDisposable = progressSignal.start()
            
            applySignal = applySignal
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
            cancelImpl = {
                applyGroupDisposable.set(nil)
            }
            
            applyGroupDisposable.set((applySignal
            |> deliverOnMainQueue).start(error: { _ in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }, completed: {
                if case .group = peer.info {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controller = OverlayStatusController(theme: presentationData.theme, type: .success)
                    presentControllerImpl?(controller, nil)
                    
                    dismissImpl?()
                }
            }))
        })
    })
    
    var wasEmpty: Bool?
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(), presentationData, statePromise.get(), peerView, groupPeers.get())
    |> deliverOnMainQueue
    |> map { presentationData, state, view, groups -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let title: String
        if let peer = view.peers[view.peerId] as? TelegramChannel, case .broadcast = peer.info {
            title = presentationData.strings.Channel_DiscussionGroup
        } else {
            title = presentationData.strings.Group_LinkedChannel
        }
        
        var crossfade = false
        var isEmptyState = false
        var displayGroupList = false
        if let cachedData = view.cachedData as? CachedChannelData {
            var isEmpty = true
            switch cachedData.linkedDiscussionPeerId {
            case .unknown:
                isEmpty = true
            case let .known(value):
                isEmpty = value == nil
            }
            if let peer = view.peers[view.peerId] as? TelegramChannel, case .broadcast = peer.info {
                if isEmpty {
                    if groups == nil {
                        isEmptyState = true
                    } else {
                        displayGroupList = true
                    }
                }
            }
        } else {
            isEmptyState = true
        }
        if let wasEmpty = wasEmpty, wasEmpty != isEmptyState {
            crossfade = true
        }
        wasEmpty = isEmptyState
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if isEmptyState {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }
        
        var rightNavigationButton: ItemListNavigationButton?
        var searchItem: ItemListControllerSearch?
        if let groups = groups, groups.count >= 10, displayGroupList {
            if state.searching {
                searchItem = ChannelDiscussionGroupSetupSearchItem(context: context, peers: groups, cancel: {
                    updateState { state in
                        var state = state
                        state.searching = false
                        return state
                    }
                }, dismissInput: {
                    dismissInputImpl?()
                }, openPeer: { peer in
                    arguments.selectGroup(peer.id)
                })
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                    updateState { state in
                        var state = state
                        state.searching = true
                        return state
                    }
                })
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelDiscussionGroupSetupControllerEntries(presentationData: presentationData, view: view, groups: groups), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, crossfadeState: crossfade, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.filterController(controller, animated: true)
        }
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    navigateToGroupImpl = { [weak controller] groupId in
        guard let navigationController = controller?.navigationController as? NavigationController else {
            return
        }
        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: groupId), keepStack: .always))
    }
    return controller
}
