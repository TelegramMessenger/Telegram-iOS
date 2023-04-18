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
import QrCodeUI
import PromptUI

private final class FolderInviteLinkListControllerArguments {
    let context: AccountContext
    let shareMainLink: (String) -> Void
    let openMainLink: (String) -> Void
    let copyLink: (String) -> Void
    let mainLinkContextAction: (ExportedChatFolderLink?, ASDisplayNode, ContextGesture?) -> Void
    let peerAction: (EnginePeer, Bool) -> Void
    let toggleAllSelected: () -> Void
    
    init(
        context: AccountContext,
        shareMainLink: @escaping (String) -> Void,
        openMainLink: @escaping (String) -> Void,
        copyLink: @escaping (String) -> Void,
        mainLinkContextAction: @escaping (ExportedChatFolderLink?, ASDisplayNode, ContextGesture?) -> Void,
        peerAction: @escaping (EnginePeer, Bool) -> Void,
        toggleAllSelected: @escaping () -> Void
    ) {
        self.context = context
        self.shareMainLink = shareMainLink
        self.openMainLink = openMainLink
        self.copyLink = copyLink
        self.mainLinkContextAction = mainLinkContextAction
        self.peerAction = peerAction
        self.toggleAllSelected = toggleAllSelected
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
    
    case peersHeader(String, String?)
    case peer(index: Int, peer: EnginePeer, isSelected: Bool, disabledReasonText: String?)
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
        case let .peer(_, peer, _, _):
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
        case let .peer(index, _, _, _):
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
        case let .peersHeader(text, action):
            if case .peersHeader(text, action) = rhs {
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
        case let .peer(index, peer, isSelected, disabledReasonText):
            if case .peer(index, peer, isSelected, disabledReasonText) = rhs {
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
            return InviteLinkHeaderItem(context: arguments.context, theme: presentationData.theme, text: text, animationName: "ChatListCloudFolderLink", sectionId: self.section)
        case let .mainLinkHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .mainLink(link, isGenerating):
            return ItemListFolderInviteLinkItem(context: arguments.context, presentationData: presentationData, invite: link, count: 0, peers: [], displayButton: true, enableButton: !isGenerating, buttonTitle: presentationData.strings.FolderLinkScreen_LinkActionCopy, secondaryButtonTitle: link != nil ? presentationData.strings.FolderLinkScreen_LinkActionShare : nil, displayImporters: false, buttonColor: nil, sectionId: self.section, style: .blocks, copyAction: {
                if let link {
                    arguments.copyLink(link.link)
                }
            }, shareAction: {
                if let link {
                    arguments.copyLink(link.link)
                }
            }, secondaryAction: {
                if let link {
                    arguments.shareMainLink(link.link)
                }
            }, contextAction: { node, gesture in
                arguments.mainLinkContextAction(link, node, gesture)
            }, viewAction: {
                if let link {
                    arguments.openMainLink(link.link)
                }
            })
        case let .peersHeader(text, action):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, actionText: action, action: action == nil ? nil : {
                arguments.toggleAllSelected()
            }, sectionId: self.section)
        case let .peersInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .peer(_, peer, isSelected, disabledReasonText):
            return ItemListPeerItem(
                presentationData: presentationData,
                dateTimeFormat: PresentationDateTimeFormat(),
                nameDisplayOrder: presentationData.nameDisplayOrder,
                context: arguments.context,
                peer: peer,
                presence: nil,
                text: .text(disabledReasonText ?? presentationData.strings.FolderLinkScreen_LabelCanInvite, .secondary),
                label: .none,
                editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false),
                switchValue: ItemListPeerItemSwitch(value: isSelected, style: .leftCheck, isEnabled: disabledReasonText == nil),
                enabled: true,
                selectable: true,
                highlightable: false,
                sectionId: self.section,
                action: {
                    arguments.peerAction(peer, disabledReasonText == nil)
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
    title: String,
    allPeers: [EnginePeer]
) -> [InviteLinksListEntry] {
    var entries: [InviteLinksListEntry] = []
    
    var infoString: String?
    let chatCountString: String
    let peersHeaderString: String
    
    let canShareChats = !allPeers.allSatisfy({ !canShareLinkToPeer(peer: $0) })
    let allSelected = allPeers.filter({ canShareLinkToPeer(peer: $0) }).allSatisfy({ state.selectedPeerIds.contains($0.id) })
    
    var selectAllString: String?
    
    if !canShareChats {
        infoString = presentationData.strings.FolderLinkScreen_TitleDescriptionUnavailable
        chatCountString = presentationData.strings.FolderLinkScreen_ChatCountHeaderUnavailable
        peersHeaderString = presentationData.strings.FolderLinkScreen_ChatsSectionHeaderUnavailable
    } else if state.selectedPeerIds.isEmpty {
        chatCountString = presentationData.strings.FolderLinkScreen_TitleDescriptionDeselected(title).string
        peersHeaderString = presentationData.strings.FolderLinkScreen_ChatsSectionHeader
        if allPeers.count > 1 {
            selectAllString = allSelected ? presentationData.strings.FolderLinkScreen_ChatsSectionHeaderActionDeselectAll : presentationData.strings.FolderLinkScreen_ChatsSectionHeaderActionSelectAll
        }
    } else {
        chatCountString = presentationData.strings.FolderLinkScreen_TitleDescriptionSelected(title, presentationData.strings.FolderLinkScreen_TitleDescriptionSelectedCount(Int32(state.selectedPeerIds.count))).string
        peersHeaderString = presentationData.strings.FolderLinkScreen_ChatsSectionHeaderSelected(Int32(state.selectedPeerIds.count))
        if allPeers.count > 1 {
            selectAllString = allSelected ? presentationData.strings.FolderLinkScreen_ChatsSectionHeaderActionDeselectAll : presentationData.strings.FolderLinkScreen_ChatsSectionHeaderActionSelectAll
        }
    }
    entries.append(.header(chatCountString))
    
    if canShareChats {
        entries.append(.mainLinkHeader(presentationData.strings.FolderLinkScreen_LinkSectionHeader))
        entries.append(.mainLink(link: state.currentLink, isGenerating: state.generatingLink))
    }
    
    entries.append(.peersHeader(peersHeaderString, selectAllString))
    
    var sortedPeers: [EnginePeer] = []
    for peer in allPeers.filter({ canShareLinkToPeer(peer: $0) }) {
        sortedPeers.append(peer)
    }
    for peer in allPeers.filter({ !canShareLinkToPeer(peer: $0) }) {
        sortedPeers.append(peer)
    }
    
    for peer in sortedPeers {
        var disabledReasonText: String?
        if !canShareLinkToPeer(peer: peer) {
            if case let .user(user) = peer {
                if user.botInfo != nil {
                    disabledReasonText = presentationData.strings.FolderLinkScreen_LabelUnavailableBot
                } else {
                    disabledReasonText = presentationData.strings.FolderLinkScreen_LabelUnavailableUser
                }
            } else {
                disabledReasonText = presentationData.strings.FolderLinkScreen_LabelUnavailableGeneric
            }
        }
        entries.append(.peer(index: entries.count, peer: peer, isSelected: state.selectedPeerIds.contains(peer.id), disabledReasonText: disabledReasonText))
    }
    
    if let infoString {
        entries.append(.peersInfo(infoString))
    }
    
    return entries
}

private struct FolderInviteLinkListControllerState: Equatable {
    var title: String?
    var currentLink: ExportedChatFolderLink?
    var selectedPeerIds = Set<EnginePeer.Id>()
    var generatingLink: Bool = false
    var isSaving: Bool = false
}

public func folderInviteLinkListController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, filterId: Int32, title filterTitle: String, allPeerIds: [EnginePeer.Id], currentInvitation: ExportedChatFolderLink?, linkUpdated: @escaping (ExportedChatFolderLink?) -> Void, presentController parentPresentController: ((ViewController) -> Void)?) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    let _ = pushControllerImpl
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var attemptNavigationImpl: ((@escaping () -> Void) -> Bool)?
    
    var dismissTooltipsImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    var initialState = FolderInviteLinkListControllerState()
    initialState.title = currentInvitation?.title
    initialState.currentLink = currentInvitation
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
    
    var displayTooltipImpl: ((UndoOverlayContent, Bool) -> Void)?
    
    var didDisplayAddPeerNotice: Bool = false
    
    var combinedPeerIds: [EnginePeer.Id] = []
    if let currentInvitation {
        for peerId in currentInvitation.peerIds {
            if !combinedPeerIds.contains(peerId) {
                combinedPeerIds.append(peerId)
            }
        }
    }
    for peerId in allPeerIds {
        if !combinedPeerIds.contains(peerId) {
            combinedPeerIds.append(peerId)
        }
    }
    
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
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.FolderLinkScreen_ContextActionNameLink, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Pencil"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            let state = stateValue.with({ $0 })
            
            let promptController = promptController(sharedContext: context.sharedContext, updatedPresentationData: updatedPresentationData, text: presentationData.strings.FolderLinkScreen_NameLink_Title, titleFont: .bold, value: state.title ?? "", characterLimit: 32, apply: { value in
                if let value {
                    updateState { state in
                        var state = state
                        
                        state.title = value
                        
                        return state
                    }
                }
            })
            presentControllerImpl?(promptController, nil)
        })))

        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            dismissTooltipsImpl?()
            
            UIPasteboard.general.string = invite.link
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            presentControllerImpl?(QrCodeScreen(context: context, updatedPresentationData: updatedPresentationData, subject: .chatFolder(slug: invite.slug)), nil)
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextRevoke, textColor: .destructive, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            let _ = (context.engine.peers.editChatFolderLink(filterId: filterId, link: invite, title: nil, peerIds: nil, revoke: true)
            |> deliverOnMainQueue).start(completed: {
                let _ = (context.engine.peers.deleteChatFolderLink(filterId: filterId, link: invite)
                |> deliverOnMainQueue).start(completed: {
                    linkUpdated(nil)
                    dismissImpl?()
                })
            })
        })))

        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .reference(InviteLinkContextReferenceContentSource(controller: controller, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        presentInGlobalOverlayImpl?(contextController)
    }, peerAction: { peer, isEnabled in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        if isEnabled {
            var added = false
            updateState { state in
                var state = state
                
                if state.selectedPeerIds.contains(peer.id) {
                    state.selectedPeerIds.remove(peer.id)
                } else {
                    state.selectedPeerIds.insert(peer.id)
                    
                    if let currentInvitation, !currentInvitation.peerIds.contains(peer.id) {
                        added = true
                    }
                }
                
                return state
            }
            
            if added && !didDisplayAddPeerNotice {
                didDisplayAddPeerNotice = true
                
                dismissTooltipsImpl?()
                displayTooltipImpl?(.info(title: nil, text: presentationData.strings.FolderLinkScreen_ToastNewChatAdded, timeout: 8), true)
            }
        } else {
            let text: String
            if case let .user(user) = peer {
                if user.botInfo != nil {
                    text = presentationData.strings.FolderLinkScreen_AlertTextUnavailableBot
                } else {
                    text = presentationData.strings.FolderLinkScreen_AlertTextUnavailableUser
                }
            } else {
                var isGroup = true
                let isPrivate = peer.addressName == nil
                if case let .channel(channel) = peer, case .broadcast = channel.info {
                    isGroup = false
                }
                if isGroup {
                    if isPrivate {
                        text = presentationData.strings.FolderLinkScreen_AlertTextUnavailablePrivateGroup
                    } else {
                        text = presentationData.strings.FolderLinkScreen_AlertTextUnavailablePublicGroup
                    }
                } else {
                    if isPrivate {
                        text = presentationData.strings.FolderLinkScreen_AlertTextUnavailablePrivateChannel
                    } else {
                        text = presentationData.strings.FolderLinkScreen_AlertTextUnavailablePublicChannel
                    }
                }
            }
            dismissTooltipsImpl?()
            displayTooltipImpl?(.peers(context: context, peers: [peer], title: nil, text: text, customUndoText: nil), true)
        }
    }, toggleAllSelected: {
        let _ = (context.engine.data.get(
            EngineDataList(combinedPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
        )
        |> deliverOnMainQueue).start(next: { allPeers in
            let allPeers = allPeers.compactMap({ $0 })
            
            let selectablePeers = allPeers.filter({ canShareLinkToPeer(peer: $0) })
            let state = stateValue.with({ $0 })
            let allSelected = selectablePeers.allSatisfy({ state.selectedPeerIds.contains($0.id) })
            
            updateState { state in
                var state = state
                
                if allSelected {
                    state.selectedPeerIds.removeAll()
                } else {
                    state.selectedPeerIds.removeAll()
                    for peer in selectablePeers {
                        state.selectedPeerIds.insert(peer.id)
                    }
                }
                
                return state
            }
        })
    })
    
    let allPeers = context.engine.data.subscribe(
        EngineDataList(combinedPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
    )
    |> map { peers -> [EnginePeer] in
        return peers.compactMap({ peer -> EnginePeer? in
            guard let peer else {
                return nil
            }
            if case let .legacyGroup(group) = peer, group.migrationReference != nil {
                return nil
            }
            return peer
        })
    }
    
    let applyChangesImpl: (() -> Void)? = {
        let state = stateValue.with({ $0 })
        
        if state.selectedPeerIds.isEmpty {
            return
        }
        
        if let currentLink = state.currentLink {
            if currentLink.title != state.title || Set(currentLink.peerIds) != state.selectedPeerIds {
                updateState { state in
                    var state = state
                    state.isSaving = true
                    return state
                }
                actionsDisposable.add((context.engine.peers.editChatFolderLink(filterId: filterId, link: currentLink, title: state.title, peerIds: Array(state.selectedPeerIds), revoke: false)
                |> deliverOnMainQueue).start(error: { _ in
                    updateState { state in
                        var state = state
                        state.isSaving = false
                        return state
                    }
                    
                    dismissTooltipsImpl?()
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.FolderLinkScreen_SaveUnknownError, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                }, completed: {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    linkUpdated(ExportedChatFolderLink(title: state.title ?? "", link: currentLink.link, peerIds: Array(state.selectedPeerIds), isRevoked: false))
                    displayTooltipImpl?(.info(title: nil, text: presentationData.strings.FolderLinkScreen_ToastLinkUpdated, timeout: 3), false)
                    
                    dismissImpl?()
                }))
            } else {
                dismissImpl?()
            }
        } else {
            dismissImpl?()
        }
    }
    
    let _ = (allPeers
    |> take(1)
    |> deliverOnMainQueue).start(next: { peers in
        updateState { state in
            var state = state
            
            if let currentInvitation {
                for peerId in currentInvitation.peerIds {
                    state.selectedPeerIds.insert(peerId)
                }
            } else {
                for peerId in peers.map(\.id) {
                    if let peer = peers.first(where: { $0.id == peerId }) {
                        if canShareLinkToPeer(peer: peer) {
                            state.selectedPeerIds.insert(peerId)
                        }
                    }
                }
            }
            
            return state
        }
    })
    
    let previousState = Atomic<FolderInviteLinkListControllerState?>(value: nil)
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        statePromise.get(),
        allPeers
    )
    |> map { presentationData, state, allPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let allPeers = allPeers.compactMap { $0 }
        
        let crossfade = false
        
        var animateChanges = false
        
        let previousStateValue = previousState.swap(state)
        if let previousStateValue, previousStateValue.selectedPeerIds != state.selectedPeerIds {
            animateChanges = true
        }
        
        let title: ItemListControllerTitle
        
        var folderTitle = presentationData.strings.FolderLinkScreen_Title
        if let title = state.title, !title.isEmpty {
            folderTitle = title
        }
        title = .text(folderTitle)
        
        var doneButton: ItemListNavigationButton?
        
        let canShareChats = !allPeers.allSatisfy({ !canShareLinkToPeer(peer: $0) })
        
        if !canShareChats {
            doneButton = nil
        } else if state.isSaving {
            doneButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            var saveEnabled = false
            if let currentLink = state.currentLink {
                if currentLink.title != state.title || Set(currentLink.peerIds) != state.selectedPeerIds {
                    saveEnabled = true
                }
            } else {
                saveEnabled = true
            }
            
            doneButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Save), style: .bold, enabled: !state.selectedPeerIds.isEmpty && saveEnabled, action: {
                applyChangesImpl?()
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: nil, rightNavigationButton: doneButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: folderInviteLinkListControllerEntries(
            presentationData: presentationData,
            state: state,
            title: filterTitle,
            allPeers: allPeers
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
    controller.attemptNavigation = { f in
        return attemptNavigationImpl?(f) ?? true
    }
    attemptNavigationImpl = { f in
        if let currentInvitation {
            let state = stateValue.with({ $0 })
            
            var hasChanges = false
            if state.title != currentInvitation.title {
                hasChanges = true
            }
            if state.selectedPeerIds != Set(currentInvitation.peerIds) {
                hasChanges = true
            }
            
            if hasChanges {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.FolderLinkScreen_SaveAlertTitle, text: presentationData.strings.FolderLinkScreen_SaveAlertText, actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.FolderLinkScreen_SaveAlertActionDiscard, action: {
                        f()
                        dismissImpl?()
                    }),
                    TextAlertAction(type: .defaultAction, title: state.selectedPeerIds.isEmpty ? presentationData.strings.FolderLinkScreen_SaveAlertActionApply : presentationData.strings.FolderLinkScreen_SaveAlertActionContinue, action: {
                        applyChangesImpl?()
                    })
                ]), nil)
                return false
            } else {
                f()
                return true
            }
        } else {
            f()
            return true
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
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    getControllerImpl = { [weak controller] in
        return controller
    }
    displayTooltipImpl = { [weak controller] c, inCurrentContext in
        let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
        if let controller = controller, inCurrentContext {
            controller.present(UndoOverlayController(presentationData: presentationData, content: c, elevatedLayout: false, action: { _ in return false }), in: .current)
        } else if !inCurrentContext {
            parentPresentController?(UndoOverlayController(presentationData: presentationData, content: c, elevatedLayout: false, action: { _ in return false }))
        }
    }
    dismissTooltipsImpl = { [weak controller] in
        controller?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    return controller
}
