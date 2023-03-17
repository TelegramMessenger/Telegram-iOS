import Foundation
import UIKit
import AsyncDisplayKit
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
import AppBundle
import ContextUI
import TelegramStringFormatting
import ItemListPeerActionItem
import ItemListPeerItem
import ShareController
import UndoUI
import QrCodeUI

private final class FolderInviteLinkListControllerArguments {
    let context: AccountContext
    let shareMainLink: (String) -> Void
    let openMainLink: (String) -> Void
    let copyLink: (String) -> Void
    let mainLinkContextAction: (String?, ASDisplayNode, ContextGesture?) -> Void
    let peerAction: (EnginePeer) -> Void
    let generateLink: () -> Void
    
    init(
        context: AccountContext,
        shareMainLink: @escaping (String) -> Void,
        openMainLink: @escaping (String) -> Void,
        copyLink: @escaping (String) -> Void,
        mainLinkContextAction: @escaping (String?, ASDisplayNode, ContextGesture?) -> Void,
        peerAction: @escaping (EnginePeer) -> Void,
        generateLink: @escaping () -> Void
    ) {
        self.context = context
        self.shareMainLink = shareMainLink
        self.openMainLink = openMainLink
        self.copyLink = copyLink
        self.mainLinkContextAction = mainLinkContextAction
        self.peerAction = peerAction
        self.generateLink = generateLink
    }
}

private enum InviteLinksListSection: Int32 {
    case header
    case mainLink
    case peers
}

private enum InviteLinksListEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case index(Int)
        case peer(EnginePeer.Id)
    }
    
    case header(String)
   
    case mainLinkHeader(String)
    case mainLink(link: ExportedChatFolderLink?, isGenerating: Bool)
    
    case peersHeader(String)
    case peer(index: Int, peer: EnginePeer, isSelected: Bool)
    case peersInfo(String)
    
    var section: ItemListSectionId {
        switch self {
        case .header:
            return InviteLinksListSection.header.rawValue
        case .mainLinkHeader, .mainLink:
            return InviteLinksListSection.mainLink.rawValue
        case .peersHeader, .peer, .peersInfo:
            return InviteLinksListSection.peers.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .header:
            return .index(0)
        case .mainLinkHeader:
            return .index(1)
        case .mainLink:
            return .index(2)
        case .peersHeader:
            return .index(4)
        case .peersInfo:
            return .index(5)
        case let .peer(_, peer, _):
            return .peer(peer.id)
        }
    }
    
    var sortIndex: Int {
        switch self {
        case .header:
            return 0
        case .mainLinkHeader:
            return 1
        case .mainLink:
            return 2
        case .peersHeader:
            return 4
        case let .peer(index, _, _):
            return 10 + index
        case .peersInfo:
            return 1000
        }
    }
    
    static func ==(lhs: InviteLinksListEntry, rhs: InviteLinksListEntry) -> Bool {
        switch lhs {
        case let .header(text):
            if case .header(text) = rhs {
                return true
            } else {
                return false
            }
        case let .mainLinkHeader(text):
            if case .mainLinkHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .mainLink(lhsLink, lhsIsGenerating):
            if case let .mainLink(rhsLink, rhsIsGenerating) = rhs, lhsLink == rhsLink, lhsIsGenerating == rhsIsGenerating {
                return true
            } else {
                return false
            }
        case let .peersHeader(text):
            if case .peersHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .peersInfo(text):
            if case .peersInfo(text) = rhs {
                return true
            } else {
                return false
            }
        case let .peer(index, peer, isSelected):
            if case .peer(index, peer, isSelected) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: InviteLinksListEntry, rhs: InviteLinksListEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! FolderInviteLinkListControllerArguments
        switch self {
        case let .header(text):
            return InviteLinkHeaderItem(context: arguments.context, theme: presentationData.theme, text: text, animationName: "ChatListNewFolder", sectionId: self.section)
        case let .mainLinkHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .mainLink(link, isGenerating):
            return ItemListFolderInviteLinkItem(context: arguments.context, presentationData: presentationData, invite: link, count: 0, peers: [], displayButton: true, enableButton: !isGenerating, buttonTitle: link != nil ? "Share Invite Link" : "Generate Invite Link", displayImporters: false, buttonColor: nil, sectionId: self.section, style: .blocks, copyAction: {
                if let link {
                    arguments.copyLink(link.link)
                }
            }, shareAction: {
                if let link {
                    arguments.shareMainLink(link.link)
                } else {
                    arguments.generateLink()
                }
            }, contextAction: { node, gesture in
                arguments.mainLinkContextAction(link?.link, node, gesture)
            }, viewAction: {
                if let link {
                    arguments.openMainLink(link.link)
                }
            })
        case let .peersHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .peersInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .peer(_, peer, isSelected):
            return ItemListPeerItem(
                presentationData: presentationData,
                dateTimeFormat: PresentationDateTimeFormat(),
                nameDisplayOrder: presentationData.nameDisplayOrder,
                context: arguments.context,
                peer: peer,
                presence: nil,
                text: .none,
                label: .none,
                editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false),
                switchValue: ItemListPeerItemSwitch(value: isSelected, style: .leftCheck),
                enabled: true,
                selectable: true,
                sectionId: self.section,
                action: {
                    arguments.peerAction(peer)
                },
                setPeerIdWithRevealedOptions: { _, _ in
                },
                removePeer: { _ in
                }
            )
        }
    }
}

private func folderInviteLinkListControllerEntries(
    presentationData: PresentationData,
    state: FolderInviteLinkListControllerState,
    allPeers: [EnginePeer]
) -> [InviteLinksListEntry] {
    var entries: [InviteLinksListEntry] = []
    
    entries.append(.header("Anyone with this link can add Gaming Club folder and the 2 chats selected below."))
    
    //TODO:localize
    
    entries.append(.mainLinkHeader("INVITE LINK"))
    entries.append(.mainLink(link: state.currentLink, isGenerating: state.generatingLink))
    
    entries.append(.peersHeader("\(allPeers.count) CHATS SELECTED"))
    for peer in allPeers {
        entries.append(.peer(index: entries.count, peer: peer, isSelected: state.selectedPeerIds.contains(peer.id)))
    }
    
    return entries
}

private struct FolderInviteLinkListControllerState: Equatable {
    var currentLink: ExportedChatFolderLink?
    var selectedPeerIds = Set<EnginePeer.Id>()
    var generatingLink: Bool = false
}

public func folderInviteLinkListController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, filterId: Int32, allPeerIds: [PeerId], currentInvitation: ExportedChatFolderLink?) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    let _ = pushControllerImpl
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    
    var dismissTooltipsImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    var initialState = FolderInviteLinkListControllerState()
    initialState.currentLink = currentInvitation
    for peerId in allPeerIds {
        initialState.selectedPeerIds.insert(peerId)
    }
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((FolderInviteLinkListControllerState) -> FolderInviteLinkListControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    let _ = updateState
    
    let revokeLinkDisposable = MetaDisposable()
    actionsDisposable.add(revokeLinkDisposable)
    
    let deleteAllRevokedLinksDisposable = MetaDisposable()
    actionsDisposable.add(deleteAllRevokedLinksDisposable)
        
    var getControllerImpl: (() -> ViewController?)?
    
    let arguments = FolderInviteLinkListControllerArguments(context: context, shareMainLink: { inviteLink in
        let shareController = ShareController(context: context, subject: .url(inviteLink), updatedPresentationData: updatedPresentationData)
        shareController.completed = { peerIds in
            let _ = (context.engine.data.get(
                EngineDataList(
                    peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                )
            )
            |> deliverOnMainQueue).start(next: { peerList in
                let peers = peerList.compactMap { $0 }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                let text: String
                var savedMessages = false
                if peerIds.count == 1, let peerId = peerIds.first, peerId == context.account.peerId {
                    text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_SavedMessages_One
                    savedMessages = true
                } else {
                    if peers.count == 1, let peer = peers.first {
                        let peerName = peer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_Chat_One(peerName).string
                    } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                        let firstPeerName = firstPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        let secondPeerName = secondPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                    } else if let peer = peers.first {
                        let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                    } else {
                        text = ""
                    }
                }
                
                presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), nil)
            })
        }
        shareController.actionCompleted = {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
        }
        presentControllerImpl?(shareController, nil)
    }, openMainLink: { _ in
    }, copyLink: { link in
        UIPasteboard.general.string = link
        
        dismissTooltipsImpl?()
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
    }, mainLinkContextAction: { invite, node, gesture in
        guard let node = node as? ContextReferenceContentNode, let controller = getControllerImpl?(), let invite = invite else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var items: [ContextMenuItem] = []

        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            dismissTooltipsImpl?()
            
            UIPasteboard.general.string = invite
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            //presentControllerImpl?(QrCodeScreen(context: context, updatedPresentationData: updatedPresentationData, subject: .invite(invite: invite, isGroup: isGroup)), nil)
        })))

        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .reference(InviteLinkContextReferenceContentSource(controller: controller, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        presentInGlobalOverlayImpl?(contextController)
    }, peerAction: { peer in
        updateState { state in
            var state = state
            
            if state.selectedPeerIds.contains(peer.id) {
                state.selectedPeerIds.remove(peer.id)
            } else {
                state.selectedPeerIds.insert(peer.id)
            }
            
            return state
        }
    }, generateLink: {
        let currentState = stateValue.with({ $0 })
        if !currentState.generatingLink {
            updateState { state in
                var state = state
                
                state.generatingLink = true
                
                return state
            }
            
            actionsDisposable.add((context.engine.peers.exportChatFolder(filterId: filterId, title: "Link", peerIds: Array(currentState.selectedPeerIds))
            |> deliverOnMainQueue).start(next: { result in
                updateState { state in
                    var state = state
                    
                    state.generatingLink = false
                    state.currentLink = result
                    
                    return state
                }
            }, error: { _ in
            }))
        }
    })
    
    let allPeers = context.engine.data.subscribe(
        EngineDataList(allPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
    )
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        statePromise.get(),
        allPeers
    )
    |> map { presentationData, state, allPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let crossfade = false
        let animateChanges = false
        
        //TODO:localize
        let title: ItemListControllerTitle
        title = .text("Share Folder")
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: folderInviteLinkListControllerEntries(
            presentationData: presentationData,
            state: state,
            allPeers: allPeers.compactMap { $0 }
        ), style: .blocks, emptyStateItem: nil, crossfadeState: crossfade, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
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
