import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import ItemListPeerItem

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
}

private enum GroupsInCommonEntry: ItemListNodeEntry {
    case peerItem(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Peer)
    
    var section: ItemListSectionId {
        switch self {
            case .peerItem:
                return GroupsInCommonSection.peers.rawValue
        }
    }
    
    var stableId: GroupsInCommonEntryStableId {
        switch self {
            case let .peerItem(_, _, _, _, _, peer):
                return .peer(peer.id)
        }
    }
    
    static func ==(lhs: GroupsInCommonEntry, rhs: GroupsInCommonEntry) -> Bool {
        switch lhs {
            case let .peerItem(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsPeer):
                if case let .peerItem(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsPeer) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    if lhsNameOrder != rhsNameOrder {
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
        case let .peerItem(index, _, _, _, _, _):
            switch rhs {
                case let .peerItem(rhsIndex, _, _, _, _, _):
                    return index < rhsIndex
            }
        }
    }
    
    func item(_ arguments: GroupsInCommonControllerArguments) -> ListViewItem {
        switch self {
        case let .peerItem(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
            return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.account, peer: peer, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                arguments.openPeer(peer.id)
            }, setPeerIdWithRevealedOptions: { _, _ in
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

private func groupsInCommonControllerEntries(presentationData: PresentationData, state: GroupsInCommonControllerState, peers: [Peer]?) -> [GroupsInCommonEntry] {
    var entries: [GroupsInCommonEntry] = []
    
    if let peers = peers {
        var index: Int32 = 0
        for peer in peers {
            entries.append(.peerItem(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, peer))
            index += 1
        }
    }
    
    return entries
}

public func groupsInCommonController(context: AccountContext, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(GroupsInCommonControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: GroupsInCommonControllerState())
    let updateState: ((GroupsInCommonControllerState) -> GroupsInCommonControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let peersPromise = Promise<[Peer]?>(nil)
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    
    let arguments = GroupsInCommonControllerArguments(account: context.account, openPeer: { memberId in
        guard let navigationController = getNavigationControllerImpl?() else {
            return
        }
        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(memberId), animated: true))
    })
    
    let peersSignal: Signal<[Peer]?, NoError> = .single(nil) |> then(groupsInCommon(account: context.account, peerId: peerId) |> mapToSignal { peerIds -> Signal<[Peer], NoError> in
            return context.account.postbox.transaction { transaction -> [Peer] in
                var result: [Peer] = []
                for id in peerIds {
                    if let peer = transaction.getPeer(id) {
                        result.append(peer)
                    }
                }
                return result
            }
        }
        |> map(Optional.init))
    
    peersPromise.set(peersSignal)
    
    var previousPeers: [Peer]?
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), peersPromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state, peers -> (ItemListControllerState, (ItemListNodeState<GroupsInCommonEntry>, GroupsInCommonEntry.ItemGenerationArguments)) in
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if peers == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
            
            let previous = previousPeers
            previousPeers = peers
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.UserInfo_GroupsInCommon), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: groupsInCommonControllerEntries(presentationData: presentationData, state: state, peers: peers), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && peers != nil && previous!.count >= peers!.count)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}
