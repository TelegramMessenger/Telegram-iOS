import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ItemListPeerItem
import ContextUI

private final class GroupsInCommonControllerArguments {
    let context: AccountContext
    
    let openPeer: (PeerId) -> Void
    let contextAction: (Peer, ASDisplayNode, ContextGesture?) -> Void
    
    init(context: AccountContext, openPeer: @escaping (PeerId) -> Void, contextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void) {
        self.context = context
        self.openPeer = openPeer
        self.contextAction = contextAction
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
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GroupsInCommonControllerArguments
        switch self {
        case let .peerItem(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                arguments.openPeer(peer.id)
            }, setPeerIdWithRevealedOptions: { _, _ in
            }, removePeer: { _ in
            }, contextAction: { node, gesture in
                arguments.contextAction(peer, node, gesture)
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
    
    var contextActionImpl: ((Peer, ASDisplayNode, ContextGesture?) -> Void)?
    
    let arguments = GroupsInCommonControllerArguments(context: context, openPeer: { memberId in
        guard let navigationController = getNavigationControllerImpl?() else {
            return
        }
        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(memberId), animated: true))
    }, contextAction: { peer, node, gesture in
        contextActionImpl?(peer, node, gesture)
    })
    
    let peersSignal: Signal<[Peer]?, NoError> = .single(nil) |> then(groupsInCommon(account: context.account, peerId: peerId) |> mapToSignal { peerIds -> Signal<[Peer], NoError> in
            return context.account.postbox.transaction { transaction -> [Peer] in
                var result: [Peer] = []
                for id in peerIds {
                    if let peer = transaction.getPeer(id.id) {
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
        |> map { presentationData, state, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if peers == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
            
            let previous = previousPeers
            previousPeers = peers
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.UserInfo_GroupsInCommon), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: groupsInCommonControllerEntries(presentationData: presentationData, state: state, peers: peers), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && peers != nil && previous!.count >= peers!.count)
            
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
    contextActionImpl = { [weak controller] peer, node, gesture in
        guard let controller = controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(peer.id), subject: nil, botStart: nil, mode: .standard(previewing: true))
        chatController.canReadHistory.set(false)
        let items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: presentationData.strings.Conversation_LinkDialogOpen, icon: { _ in nil }, action: { _, f in
                f(.dismissWithoutContent)
                arguments.openPeer(peer.id)
            }))
        ]
        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
        controller.presentInGlobalOverlay(contextController)
    }
    return controller
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = true
    
    init(controller: ViewController, sourceNode: ASDisplayNode?) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}
