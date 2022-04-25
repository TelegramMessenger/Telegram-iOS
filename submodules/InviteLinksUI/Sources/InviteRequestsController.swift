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

private func inviteRequestsControllerEntries(presentationData: PresentationData, peer: EnginePeer?, importers: [PeerInvitationImportersState.Importer]?, count: Int32, isGroup: Bool) -> [InviteRequestsEntry] {
    var entries: [InviteRequestsEntry] = []
    
    if let importers = importers, !importers.isEmpty {
        let helpText: String
        if case let .channel(peer) = peer, case .broadcast = peer.info {
            helpText = presentationData.strings.MemberRequests_DescriptionChannel
        } else {
            helpText = presentationData.strings.MemberRequests_DescriptionGroup
        }
        entries.append(.header(presentationData.theme, helpText))
    
        entries.append(.requestsHeader(presentationData.theme, presentationData.strings.MemberRequests_PeopleRequested(count).uppercased()))
        
        var index: Int32 = 0
        for importer in importers {
            entries.append(.request(index, presentationData.theme, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, importer, isGroup))
            index += 1
        }
    }

    return entries
}

private struct InviteRequestsControllerState: Equatable {
    var searchingMembers: Bool
}

public func inviteRequestsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, existingContext: PeerInvitationImportersContext? = nil) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    var navigateToProfileImpl: ((EnginePeer) -> Void)?
    var navigateToChatImpl: ((EnginePeer) -> Void)?
    var dismissInputImpl: (() -> Void)?
    var dismissTooltipsImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    if let existingContext = existingContext {
        existingContext.reload()
    }
    
    let statePromise = ValuePromise(InviteRequestsControllerState(searchingMembers: false), ignoreRepeated: true)
    let stateValue = Atomic(value: InviteRequestsControllerState(searchingMembers: false))
    let updateState: ((InviteRequestsControllerState) -> InviteRequestsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let updateDisposable = MetaDisposable()
    actionsDisposable.add(updateDisposable)
        
    let importersContext = existingContext ?? context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .requests(query: nil))
    
    let approveRequestImpl: (EnginePeer) -> Void = { peer in
        importersContext.update(peer.id, action: .approve)
                
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
        )
        |> deliverOnMainQueue).start(next: { chatPeer in
            guard let chatPeer = chatPeer else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let string: String
            if case let .channel(channel) = chatPeer, case .broadcast = channel.info {
                string = presentationData.strings.MemberRequests_UserAddedToChannel(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
            } else {
                string = presentationData.strings.MemberRequests_UserAddedToGroup(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
            }
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .invitedToVoiceChat(context: context, peer: peer, text: string), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
        })
    }
    
    let denyRequestImpl: (EnginePeer) -> Void = { peer in
        importersContext.update(peer.id, action: .deny)
    }
    
    let arguments = InviteRequestsControllerArguments(context: context, openLinks: {
        let controller = inviteLinkListController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, admin: nil)
        pushControllerImpl?(controller)
    }, openPeer: { peer in
        navigateToProfileImpl?(peer)
    }, approveRequest: { peer in
        approveRequestImpl(peer)
    }, denyRequest: { peer in
        denyRequestImpl(peer)
    }, peerContextAction: { peer, node, gesture in
        guard let node = node as? ContextExtractedContentContainingNode else {
            return
        }
        
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
        )
        |> deliverOnMainQueue).start(next: { chatPeer in
            guard let chatPeer = chatPeer else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let addString: String
            if case let .channel(channel) = chatPeer, case .broadcast = channel.info {
                addString = presentationData.strings.MemberRequests_AddToChannel
            } else {
                addString = presentationData.strings.MemberRequests_AddToGroup
            }
            var items: [ContextMenuItem] = []

            items.append(.action(ContextMenuActionItem(text: addString, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.dismissWithoutContent)
                
                approveRequestImpl(peer)
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.ContactList_Context_SendMessage, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Message"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.dismissWithoutContent)
                
                navigateToChatImpl?(peer)
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.MemberRequests_Dismiss, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor)
            }, action: { _, f in
                f(.dismissWithoutContent)
                
                Queue.mainQueue().after(0.3, {
                    denyRequestImpl(peer)
                })
            })))
            
            let dismissPromise = ValuePromise<Bool>(false)
            let source = InviteRequestsContextExtractedContentSource(sourceNode: node, keepInPlace: false, blurBackground: true, centerVertically: true, shouldBeDismissed: dismissPromise.get())
    //        sourceNode.requestDismiss = {
    //            dismissPromise.set(true)
    //        }
            
            let contextController = ContextController(account: context.account, presentationData: presentationData, source: .extracted(source), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            presentInGlobalOverlayImpl?(contextController)
        })
    })
    
    let previousEntries = Atomic<[InviteRequestsEntry]>(value: [])
        
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
        ),
        importersContext.state,
        statePromise.get()
    )
    |> map { presentationData, peer, importersState, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var isGroup = true
        if case let .channel(channel) = peer, case .broadcast = channel.info {
            isGroup = false
        }
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if importersState.hasLoadedOnce && importersState.importers.isEmpty {
            emptyStateItem = InviteRequestsEmptyStateItem(context: context, theme: presentationData.theme, strings: presentationData.strings, isGroup: isGroup)
        }
        
        let entries = inviteRequestsControllerEntries(presentationData: presentationData, peer: peer, importers: importersState.hasLoadedOnce ? importersState.importers : nil, count: importersState.count, isGroup: isGroup)
        let previousEntries = previousEntries.swap(entries)
        
        let crossfade = !previousEntries.isEmpty && entries.isEmpty
        let animateChanges = (!previousEntries.isEmpty && !entries.isEmpty) && previousEntries.count != entries.count
        
        let rightNavigationButton: ItemListNavigationButton?
        if !importersState.importers.isEmpty {
            rightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                updateState { state in
                    var updatedState = state
                    updatedState.searchingMembers = true
                    return updatedState
                }
            })
        } else {
            rightNavigationButton = nil
        }
        
        var searchItem: ItemListControllerSearch?
        if state.searchingMembers && !importersState.importers.isEmpty {
            searchItem = InviteRequestsSearchItem(context: context, peerId: peerId, cancel: {
                updateState { state in
                    var updatedState = state
                    updatedState.searchingMembers = false
                    return updatedState
                }
            }, openPeer: { peer in
                arguments.openPeer(peer)
            }, approveRequest: { peer in
                arguments.approveRequest(peer)
            }, denyRequest: { peer in
                arguments.denyRequest(peer)
            }, navigateToChat: { peer in
                navigateToChatImpl?(peer)
            }, pushController: { c in
                pushControllerImpl?(c)
            }, dismissInput: {
                dismissInputImpl?()
            }, presentInGlobalOverlay: { c in
                presentInGlobalOverlayImpl?(c)
            })
        }
        
        let title: ItemListControllerTitle = .text(presentationData.strings.MemberRequests_Title)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, crossfadeState: crossfade, animateChanges: animateChanges, scrollEnabled: emptyStateItem == nil)
        
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
            importersContext.loadMore()
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
        if let navigationController = controller?.navigationController as? NavigationController, let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: peer.largeProfileImage != nil, fromChat: false, requestsContext: nil) {
            navigationController.pushViewController(controller)
        }
    }
    navigateToChatImpl = { [weak controller] peer in
        if let navigationController = controller?.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peer.id), keepStack: .always))
        }
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
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


final class InviteRequestsContextExtractedContentSource: ContextExtractedContentSource {
    var keepInPlace: Bool
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool

    private let sourceNode: ContextExtractedContentContainingNode
    
    var centerVertically: Bool
    var shouldBeDismissed: Signal<Bool, NoError>
    
    init(sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool, blurBackground: Bool, centerVertically: Bool, shouldBeDismissed: Signal<Bool, NoError>) {
        self.sourceNode = sourceNode
        self.keepInPlace = keepInPlace
        self.blurBackground = blurBackground
        self.centerVertically = centerVertically
        self.shouldBeDismissed = shouldBeDismissed
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
