import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import AlertUI
import PresentationDataUtils
import AppBundle
import ContextUI
import TelegramStringFormatting
import ItemListPeerActionItem
import ItemListPeerItem
import ShareController
import UndoUI

private final class InviteRequestsControllerArguments {
    let context: AccountContext
    let openLinks: () -> Void
    let openPeer: (EnginePeer) -> Void
    let approveRequest: (EnginePeer) -> Void
    let denyRequest: (EnginePeer) -> Void
    let peerContextAction: (EnginePeer, ASDisplayNode, ContextGesture?) -> Void
    
    init(context: AccountContext, openLinks: @escaping () -> Void, openPeer: @escaping (EnginePeer) -> Void, approveRequest: @escaping (EnginePeer) -> Void, denyRequest: @escaping (EnginePeer) -> Void, peerContextAction: @escaping (EnginePeer, ASDisplayNode, ContextGesture?) -> Void) {
        self.context = context
        self.openLinks = openLinks
        self.openPeer = openPeer
        self.approveRequest = approveRequest
        self.denyRequest = denyRequest
        self.peerContextAction = peerContextAction
    }
}

private enum InviteRequestsSection: Int32 {
    case header
    case requests
}

private enum InviteRequestsEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)
   
    case requestsHeader(PresentationTheme, String)
    case request(Int32, PresentationTheme, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerInvitationImportersState.Importer, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .header:
                return InviteRequestsSection.header.rawValue
            case .requestsHeader, .request:
                return InviteRequestsSection.requests.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .header:
                return 0
            case .requestsHeader:
                return 1
            case let .request(index, _, _, _, _, _):
                return 2 + index
        }
    }
    
    static func ==(lhs: InviteRequestsEntry, rhs: InviteRequestsEntry) -> Bool {
        switch lhs {
            case let .header(lhsTheme, lhsText):
                if case let .header(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .requestsHeader(lhsTheme, lhsText):
                if case let .requestsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .request(lhsIndex, lhsTheme, lhsDateTimeFormat, lhsNameDisplayOrder, lhsImporter, lhsIsGroup):
                if case let .request(rhsIndex, rhsTheme, rhsDateTimeFormat, rhsNameDisplayOrder, rhsImporter, rhsIsGroup) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsNameDisplayOrder == rhsNameDisplayOrder, lhsImporter == rhsImporter, lhsIsGroup == rhsIsGroup {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: InviteRequestsEntry, rhs: InviteRequestsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! InviteRequestsControllerArguments
        switch self {
            case let .header(theme, text):
                return InviteLinkHeaderItem(context: arguments.context, theme: theme, text: text, animationName: "Requests", sectionId: self.section, linkAction: { _ in
                    arguments.openLinks()
                })
            case let .requestsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .request(_, _, dateTimeFormat, nameDisplayOrder, importer, isGroup):
                return ItemListInviteRequestItem(context: arguments.context, presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, importer: importer, isGroup: isGroup, sectionId: self.section, style: .blocks, tapAction: {
                    if let peer = importer.peer.peer.flatMap({ EnginePeer($0) }) {
                        arguments.openPeer(peer)
                    }
                }, addAction: {
                    if let peer = importer.peer.peer.flatMap({ EnginePeer($0) }) {
                        arguments.approveRequest(peer)
                    }
                }, dismissAction: {
                    if let peer = importer.peer.peer.flatMap({ EnginePeer($0) }) {
                        arguments.denyRequest(peer)
                    }
                }, contextAction: { node, gesture in
                    if let peer = importer.peer.peer.flatMap({ EnginePeer($0) }) {
                        arguments.peerContextAction(peer, node, gesture)
                    }
                })
        }
    }
}

private func inviteRequestsControllerEntries(presentationData: PresentationData, peer: EnginePeer?, importers: [PeerInvitationImportersState.Importer]?, isGroup: Bool) -> [InviteRequestsEntry] {
    var entries: [InviteRequestsEntry] = []
    
    if let importers = importers, !importers.isEmpty {
        let helpText: String
        if case let .channel(peer) = peer, case .broadcast = peer.info {
            helpText = presentationData.strings.MemberRequests_DescriptionChannel
        } else {
            helpText = presentationData.strings.MemberRequests_DescriptionGroup
        }
        entries.append(.header(presentationData.theme, helpText))
    
        entries.append(.requestsHeader(presentationData.theme, presentationData.strings.MemberRequests_PeopleRequested(Int32(importers.count)).uppercased()))
        
        var index: Int32 = 0
        for importer in importers {
            entries.append(.request(index, presentationData.theme, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, importer, isGroup))
            index += 1
        }
    }

    return entries
}

public func inviteRequestsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, existingContext: PeerInvitationImportersContext? = nil) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    var navigateToProfileImpl: ((EnginePeer) -> Void)?
    
    var dismissTooltipsImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updateDisposable = MetaDisposable()
    actionsDisposable.add(updateDisposable)
    
    var getControllerImpl: (() -> ViewController?)?
    
    let importersContext = existingContext ?? context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .requests(query: nil))
    
    let arguments = InviteRequestsControllerArguments(context: context, openLinks: {
        let controller = inviteLinkListController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, admin: nil)
        pushControllerImpl?(controller)
    }, openPeer: { peer in
        navigateToProfileImpl?(peer)
    }, approveRequest: { peer in
        importersContext.update(peer.id, action: .approve)
                
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .invitedToVoiceChat(context: context, peer: peer, text: presentationData.strings.MemberRequests_UserAddedToChannel(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
    }, denyRequest: { peer in
        importersContext.update(peer.id, action: .deny)
    }, peerContextAction: { peer, node, gesture in
        guard let node = node as? ContextReferenceContentNode, let controller = getControllerImpl?() else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var items: [ContextMenuItem] = []

        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            dismissTooltipsImpl?()
                        
        })))
        
        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .reference(InviteLinkContextReferenceContentSource(controller: controller, sourceNode: node)), items: .single(ContextController.Items(items: items)), gesture: gesture)
        presentInGlobalOverlayImpl?(contextController)
    })
    
    let previousEntries = Atomic<[InviteRequestsEntry]>(value: [])
        
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
        ),
        importersContext.state
    )
    |> map { presentationData, peer, importersState -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var isGroup = true
        if case let .channel(channel) = peer, case .broadcast = channel.info {
            isGroup = false
        }
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if importersState.hasLoadedOnce && importersState.importers.isEmpty {
            emptyStateItem = InviteRequestsEmptyStateItem(context: context, theme: presentationData.theme, strings: presentationData.strings, isGroup: isGroup)
        }
        
        let entries = inviteRequestsControllerEntries(presentationData: presentationData, peer: peer, importers: importersState.hasLoadedOnce ? importersState.importers : nil, isGroup: isGroup)
        let previousEntries = previousEntries.swap(entries)
        
        let crossfade = !previousEntries.isEmpty && entries.isEmpty
        let animateChanges = (!previousEntries.isEmpty && !entries.isEmpty) && previousEntries.count != entries.count
        
        let title: ItemListControllerTitle = .text(presentationData.strings.MemberRequests_Title)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: crossfade, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.willDisappear = { _ in
        dismissTooltipsImpl?()
    }
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
    }
    controller.visibleBottomContentOffsetChanged = { offset in
        if case let .known(value) = offset, value < 40.0 {
            
        }
    }
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c, animated: true)
        }
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    presentInGlobalOverlayImpl = { [weak controller] c in
        if let controller = controller {
            controller.presentInGlobalOverlay(c)
        }
    }
    navigateToProfileImpl = { [weak controller] peer in
        if let navigationController = controller?.navigationController as? NavigationController, let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: peer.largeProfileImage != nil, fromChat: false) {
            navigationController.pushViewController(controller)
        }
    }
    getControllerImpl = { [weak controller] in
        return controller
    }
    dismissTooltipsImpl = { [weak controller] in
        controller?.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        controller?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    return controller
}
