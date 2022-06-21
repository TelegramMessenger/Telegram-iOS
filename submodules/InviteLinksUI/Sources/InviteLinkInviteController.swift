import Foundation
import UIKit
import SwiftSignalKit
import TelegramPresentationData
import AppBundle
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import AccountContext
import SolidRoundedButtonNode
import ItemListUI
import ItemListPeerItem
import SectionHeaderItem
import TelegramStringFormatting
import MergeLists
import ContextUI
import ShareController
import OverlayStatusController
import PresentationDataUtils
import DirectionalPanGesture
import UndoUI
import QrCodeUI

class InviteLinkInviteInteraction {
    let context: AccountContext
    let mainLinkContextAction: (ExportedInvitation?, ASDisplayNode, ContextGesture?) -> Void
    let copyLink: (ExportedInvitation) -> Void
    let shareLink: (ExportedInvitation) -> Void
    let manageLinks: () -> Void
    
    init(context: AccountContext, mainLinkContextAction: @escaping (ExportedInvitation?, ASDisplayNode, ContextGesture?) -> Void, copyLink: @escaping (ExportedInvitation) -> Void, shareLink: @escaping (ExportedInvitation) -> Void, manageLinks: @escaping () -> Void) {
        self.context = context
        self.mainLinkContextAction = mainLinkContextAction
        self.copyLink = copyLink
        self.shareLink = shareLink
        self.manageLinks = manageLinks
    }
}

private struct InviteLinkInviteTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isLoading: Bool
}

private enum InviteLinkInviteEntryId: Hashable {
    case header
    case mainLink
    case manage
}

private enum InviteLinkInviteEntry: Comparable, Identifiable {
    case header(PresentationTheme, String, String)
    case mainLink(PresentationTheme, ExportedInvitation?)
    case manage(PresentationTheme, String, Bool)
    
    var stableId: InviteLinkInviteEntryId {
        switch self {
            case .header:
                return .header
            case .mainLink:
                return .mainLink
            case .manage:
                return .manage
        }
    }
    
    static func ==(lhs: InviteLinkInviteEntry, rhs: InviteLinkInviteEntry) -> Bool {
        switch lhs {
            case let .header(lhsTheme, lhsTitle, lhsText):
                if case let .header(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .mainLink(lhsTheme, lhsInvitation):
                if case let .mainLink(rhsTheme, rhsInvitation) = rhs, lhsTheme === rhsTheme, lhsInvitation == rhsInvitation {
                    return true
                } else {
                    return false
                }
            case let .manage(lhsTheme, lhsText, lhsStandalone):
                if case let .manage(rhsTheme, rhsText, rhsStandalone) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsStandalone == rhsStandalone {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: InviteLinkInviteEntry, rhs: InviteLinkInviteEntry) -> Bool {
        switch lhs {
            case .header:
                switch rhs {
                    case .header:
                        return false
                    case .mainLink, .manage:
                        return true
                }
            case .mainLink:
                switch rhs {
                    case .header, .mainLink:
                        return false
                    case .manage:
                        return true
                }
            case .manage:
                switch rhs {
                    case .header, .mainLink:
                        return false
                    case .manage:
                        return true
                }
        }
    }
    
    func item(account: Account, presentationData: PresentationData, interaction: InviteLinkInviteInteraction) -> ListViewItem {
        switch self {
            case let .header(theme, title, text):
                return InviteLinkInviteHeaderItem(theme: theme, title: title, text: text)
            case let .mainLink(_, invite):
                return ItemListPermanentInviteLinkItem(context: interaction.context, presentationData: ItemListPresentationData(presentationData), invite: invite, count: 0, peers: [], displayButton: true, displayImporters: false, buttonColor: nil, sectionId: 0, style: .plain, copyAction: {
                    if let invite = invite {
                        interaction.copyLink(invite)
                    }
                }, shareAction: {
                    if let invite = invite {
                        interaction.shareLink(invite)
                    }
                }, contextAction: { node, gesture in
                    interaction.mainLinkContextAction(invite, node, gesture)
                }, viewAction: {
                })
            case let .manage(theme, text, standalone):
                return InviteLinkInviteManageItem(theme: theme, text: text, standalone: standalone, action: {
                    interaction.manageLinks()
                })
        }
    }
}

private func preparedTransition(from fromEntries: [InviteLinkInviteEntry], to toEntries: [InviteLinkInviteEntry], isLoading: Bool, account: Account, presentationData: PresentationData, interaction: InviteLinkInviteInteraction) -> InviteLinkInviteTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return InviteLinkInviteTransaction(deletions: deletions, insertions: insertions, updates: updates, isLoading: isLoading)
}

public final class InviteLinkInviteController: ViewController {
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private weak var parentNavigationController: NavigationController?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
            
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, parentNavigationController: NavigationController?) {
        self.context = context
        self.peerId = peerId
        self.parentNavigationController = parentNavigationController
                        
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .flatModal
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, presentationData: self.presentationData, peerId: self.peerId, controller: self)
    }

    private var didAppearOnce: Bool = false
    private var isDismissed: Bool = false
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didAppearOnce {
            self.didAppearOnce = true
            
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            self.didAppearOnce = false
            
            self.dismissAllTooltips()
            
            self.controllerNode.animateOut(completion: { [weak self] in
                completion?()
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            })
        }
    }
    
    private func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }

    class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        private weak var controller: InviteLinkInviteController?
        
        private let context: AccountContext
        private let peerId: EnginePeer.Id
        private let invitesContext: PeerExportedInvitationsContext
        
        private var interaction: InviteLinkInviteInteraction?
        
        private var presentationData: PresentationData
        private let presentationDataPromise: Promise<PresentationData>
                
        private var disposable: Disposable?
        
        private let dimNode: ASDisplayNode
        private let contentNode: ASDisplayNode
        private let headerNode: ASDisplayNode
        private let headerBackgroundNode: ASDisplayNode
        private let titleNode: ImmediateTextNode
        private let doneButton: HighlightableButtonNode
        private let historyBackgroundNode: ASDisplayNode
        private let historyBackgroundContentNode: ASDisplayNode
        private var floatingHeaderOffset: CGFloat?
        private let listNode: ListView
        
        private var enqueuedTransitions: [InviteLinkInviteTransaction] = []
        
        private var validLayout: ContainerViewLayout?
        
        private var revokeDisposable = MetaDisposable()
        
        init(context: AccountContext, presentationData: PresentationData, peerId: EnginePeer.Id, controller: InviteLinkInviteController) {
            self.context = context
            self.peerId = peerId
            
            self.presentationData = presentationData
            self.presentationDataPromise = Promise(self.presentationData)
            self.controller = controller
            
            self.invitesContext = context.engine.peers.peerExportedInvitations(peerId: peerId, adminId: nil, revoked: false, forceUpdate: false)
                        
            self.dimNode = ASDisplayNode()
            self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            
            self.contentNode = ASDisplayNode()
            
            self.headerNode = ASDisplayNode()
            self.headerNode.clipsToBounds = true
            
            self.headerBackgroundNode = ASDisplayNode()
            self.headerBackgroundNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            self.headerBackgroundNode.cornerRadius = 16.0
            
            self.titleNode = ImmediateTextNode()
            self.titleNode.maximumNumberOfLines = 1
            self.titleNode.textAlignment = .center
            self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.InviteLink_InviteLink, font: Font.bold(17.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)

            self.doneButton = HighlightableButtonNode()
            self.doneButton.setTitle(self.presentationData.strings.Common_Done, with: Font.bold(17.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
            
            self.historyBackgroundNode = ASDisplayNode()
            self.historyBackgroundNode.isLayerBacked = true
            
            self.historyBackgroundContentNode = ASDisplayNode()
            self.historyBackgroundContentNode.isLayerBacked = true
            self.historyBackgroundContentNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            self.historyBackgroundNode.addSubnode(self.historyBackgroundContentNode)
            
            self.listNode = ListView()
            self.listNode.verticalScrollIndicatorColor = UIColor(white: 0.0, alpha: 0.3)
            self.listNode.verticalScrollIndicatorFollowsOverscroll = true
            self.listNode.accessibilityPageScrolledString = { row, count in
                return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
            }
            
            super.init()
            
            self.backgroundColor = nil
            self.isOpaque = false
        
            let mainInvitePromise = ValuePromise<ExportedInvitation?>(nil)
            
            self.interaction = InviteLinkInviteInteraction(context: context, mainLinkContextAction: { [weak self] invite, node, gesture in
                guard let node = node as? ContextReferenceContentNode else {
                    return
                }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                var items: [ContextMenuItem] = []

                items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    if let invite = invite {
                        UIPasteboard.general.string = invite.link
                        
                        self?.controller?.dismissAllTooltips()
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    }
                })))
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    if let invite = invite {
                        let _ = (context.account.postbox.loadedPeerWithId(peerId)
                        |> deliverOnMainQueue).start(next: { [weak self] peer in
                            guard let strongSelf = self else {
                                return
                            }
                            let isGroup: Bool
                            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                isGroup = false
                            } else {
                                isGroup = true
                            }
                            let updatedPresentationData = (strongSelf.presentationData, strongSelf.presentationDataPromise.get())
                            let controller = QrCodeScreen(context: context, updatedPresentationData: updatedPresentationData, subject: .invite(invite: invite, isGroup: isGroup))
                            strongSelf.controller?.present(controller, in: .window(.root))
                        })
                    }
                })))
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextRevoke, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                
                    let _ = (context.account.postbox.loadedPeerWithId(peerId)
                    |> deliverOnMainQueue).start(next: { peer in
                        let isGroup: Bool
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            isGroup = false
                        } else {
                            isGroup = true
                        }
                        let controller = ActionSheetController(presentationData: presentationData)
                        let dismissAction: () -> Void = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetTextItem(title: isGroup ? presentationData.strings.GroupInfo_InviteLink_RevokeAlert_Text : presentationData.strings.ChannelInfo_InviteLink_RevokeAlert_Text),
                                ActionSheetButtonItem(title: presentationData.strings.GroupInfo_InviteLink_RevokeLink, color: .destructive, action: {
                                    dismissAction()
                                    
                                    if let inviteLink = invite?.link {
                                        let _ = (context.engine.peers.revokePeerExportedInvitation(peerId: peerId, link: inviteLink) |> deliverOnMainQueue).start(next: { result in
                                            if let result = result, case let .replace(_, invite) = result {
                                                mainInvitePromise.set(invite)
                                            }
                                        })

                                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                        self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkRevoked(text: presentationData.strings.InviteLink_InviteLinkRevoked), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                                    }
                                })
                            ]),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                        ])
                        self?.controller?.present(controller, in: .window(.root))
                    })
                })))

                let contextController = ContextController(account: context.account, presentationData: presentationData, source: .reference(InviteLinkContextReferenceContentSource(controller: controller, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                self?.controller?.presentInGlobalOverlay(contextController)
            }, copyLink: { [weak self] invite in
                UIPasteboard.general.string = invite.link
                
                self?.controller?.dismissAllTooltips()
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
            }, shareLink: { [weak self] invite in
                guard let strongSelf = self, let inviteLink = invite.link else {
                    return
                }
                let updatedPresentationData = (strongSelf.presentationData, strongSelf.presentationDataPromise.get())
                let shareController = ShareController(context: context, subject: .url(inviteLink), updatedPresentationData: updatedPresentationData)
                shareController.completed = { [weak self] peerIds in
                    if let strongSelf = self {
                        let _ = (strongSelf.context.account.postbox.transaction { transaction -> [Peer] in
                            var peers: [Peer] = []
                            for peerId in peerIds {
                                if let peer = transaction.getPeer(peerId) {
                                    peers.append(peer)
                                }
                            }
                            return peers
                        } |> deliverOnMainQueue).start(next: { [weak self] peers in
                            if let strongSelf = self {
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                
                                let text: String
                                var savedMessages = false
                                if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                                    text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_SavedMessages_One
                                    savedMessages = true
                                } else {
                                    if peers.count == 1, let peer = peers.first {
                                        let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_Chat_One(peerName).string
                                    } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                        let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(firstPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(secondPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                                    } else if let peer = peers.first {
                                        let peerName = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                                    } else {
                                        text = ""
                                    }
                                }
                                
                                strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .window(.root))
                            }
                        })
                    }
                }
                shareController.actionCompleted = { [weak self] in
                    if let strongSelf = self {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    }
                }
                strongSelf.controller?.present(shareController, in: .window(.root))
            }, manageLinks: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let updatedPresentationData = (strongSelf.presentationData, strongSelf.presentationDataPromise.get())
                let controller = inviteLinkListController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, admin: nil)
                strongSelf.controller?.parentNavigationController?.pushViewController(controller)
                strongSelf.controller?.dismiss()
            })
            
            let previousEntries = Atomic<[InviteLinkInviteEntry]?>(value: nil)
            
            let peerView = context.account.postbox.peerView(id: peerId)
            let invites: Signal<PeerExportedInvitationsState, NoError> = .single(PeerExportedInvitationsState())
            self.disposable = (combineLatest(self.presentationDataPromise.get(), peerView, mainInvitePromise.get(), invites)
            |> deliverOnMainQueue).start(next: { [weak self] presentationData, view, interactiveMainInvite, invites in
                if let strongSelf = self {
                    var entries: [InviteLinkInviteEntry] = []
                    
                    let helpText: String
                    if let peer = peerViewMainPeer(view) as? TelegramChannel, case .broadcast = peer.info {
                        helpText = presentationData.strings.InviteLink_CreatePrivateLinkHelpChannel
                    } else {
                        helpText = presentationData.strings.InviteLink_CreatePrivateLinkHelp
                    }
                    entries.append(.header(presentationData.theme, presentationData.strings.InviteLink_InviteLink, helpText))
                    
                    let mainInvite: ExportedInvitation?
                    if let invite = interactiveMainInvite {
                        mainInvite = invite
                    } else if let cachedData = view.cachedData as? CachedGroupData, let invite = cachedData.exportedInvitation {
                        mainInvite = invite
                    } else if let cachedData = view.cachedData as? CachedChannelData, let invite = cachedData.exportedInvitation {
                        mainInvite = invite
                    } else {
                        mainInvite = nil
                    }
                    
                    entries.append(.mainLink(presentationData.theme, mainInvite))
                    entries.append(.manage(presentationData.theme, presentationData.strings.InviteLink_Manage, true))
                       
                    let previousEntries = previousEntries.swap(entries)
                    
                    let transition = preparedTransition(from: previousEntries ?? [], to: entries, isLoading: false, account: context.account, presentationData: presentationData, interaction: strongSelf.interaction!)
                    strongSelf.enqueueTransition(transition)
                }
            })
            
            self.listNode.preloadPages = true
            self.listNode.stackFromBottom = true
            self.listNode.updateFloatingHeaderOffset = { [weak self] offset, transition in
                if let strongSelf = self {
                    strongSelf.updateFloatingHeaderOffset(offset: offset, transition: transition)
                }
            }
            
            self.addSubnode(self.dimNode)
            self.addSubnode(self.contentNode)
            self.contentNode.addSubnode(self.historyBackgroundNode)
            self.contentNode.addSubnode(self.listNode)
            self.contentNode.addSubnode(self.headerNode)
            
            self.headerNode.addSubnode(self.headerBackgroundNode)
            self.headerNode.addSubnode(self.doneButton)
            
            self.doneButton.addTarget(self, action: #selector(self.doneButtonPressed), forControlEvents: .touchUpInside)
        }
        
        deinit {
            self.disposable?.dispose()
            self.revokeDisposable.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveTransitionGestureRecognizer = true
            self.view.disablesInteractiveModalDismiss = true
            
            self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            let panRecognizer = DirectionalPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.view.addGestureRecognizer(panRecognizer)
        }
        
        @objc private func doneButtonPressed() {
            self.controller?.dismiss()
        }
        
        func updatePresentationData(_ presentationData: PresentationData) {
            self.presentationData = presentationData
            self.presentationDataPromise.set(.single(presentationData))
            
            self.historyBackgroundContentNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            self.headerBackgroundNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.InviteLink_InviteLink, font: Font.bold(17.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
            self.doneButton.setTitle(self.presentationData.strings.Common_Done, with: Font.bold(17.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
        }
        
        private func enqueueTransition(_ transition: InviteLinkInviteTransaction) {
            self.enqueuedTransitions.append(transition)
            
            if let _ = self.validLayout {
                while !self.enqueuedTransitions.isEmpty {
                    self.dequeueTransition()
                }
            }
        }
        
        private func dequeueTransition() {
            guard let _ = self.validLayout, let transition = self.enqueuedTransitions.first else {
                return
            }
            self.enqueuedTransitions.remove(at: 0)
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: ListViewDeleteAndInsertOptions(), updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
        
        func animateIn() {
            guard let layout = self.validLayout else {
                return
            }
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            
            let initialBounds = self.contentNode.bounds
            self.contentNode.bounds = initialBounds.offsetBy(dx: 0.0, dy: -layout.size.height)
            transition.animateView({
                self.contentNode.view.bounds = initialBounds
            })
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        
        func animateOut(completion: (() -> Void)?) {
            guard let layout = self.validLayout else {
                return
            }
            var offsetCompleted = false
            let internalCompletion: () -> Void = {
                if offsetCompleted {
                    completion?()
                }
            }
            
            self.contentNode.layer.animateBoundsOriginYAdditive(from: self.contentNode.bounds.origin.y, to: -layout.size.height, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                offsetCompleted = true
                internalCompletion()
            })
            self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            
            transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            var insets = UIEdgeInsets()
            insets.left = layout.safeInsets.left
            insets.right = layout.safeInsets.right
            insets.bottom = layout.intrinsicInsets.bottom
                    
            let headerHeight: CGFloat = 54.0
            let visibleItemsHeight: CGFloat = 409.0
        
            let layoutTopInset: CGFloat = max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top)
            
            let listTopInset = layoutTopInset + headerHeight
            let listNodeSize = CGSize(width: layout.size.width, height: layout.size.height - listTopInset)
            
            insets.top = max(0.0, listNodeSize.height - visibleItemsHeight - insets.bottom)
                        
            let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listNodeSize, insets: insets, duration: duration, curve: curve)
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            
            transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(x: 0.0, y: listTopInset), size: listNodeSize))
            
            transition.updateFrame(node: self.headerBackgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: 68.0))
            
            let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width, height: headerHeight))
            let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: 18.0), size: titleSize)
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
            
            let doneSize = self.doneButton.measure(CGSize(width: layout.size.width, height: headerHeight))
            let doneFrame = CGRect(origin: CGPoint(x: layout.size.width - doneSize.width - 16.0, y: 18.0), size: doneSize)
            transition.updateFrame(node: self.doneButton, frame: doneFrame)
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)

            if result === self.headerNode.view {
                return self.view
            }
            if !self.bounds.contains(point) {
                return nil
            }
            if point.y < self.headerNode.frame.minY {
                return self.dimNode.view
            }
            return result
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss()
            }
        }
        
        private var panGestureArguments: CGFloat?

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return gestureRecognizer is DirectionalPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            let contentOffset = self.listNode.visibleContentOffset()
            switch recognizer.state {
                case .began:
                    self.panGestureArguments = 0.0
                case .changed:
                    var translation = recognizer.translation(in: self.contentNode.view).y
                    if let currentOffset = self.panGestureArguments {
                        if case let .known(value) = contentOffset, value <= 0.5 {
                            if currentOffset > 0.0 {
                                let translation = self.listNode.scroller.panGestureRecognizer.translation(in: self.listNode.scroller)
                                if translation.y > 10.0 {
                                    self.listNode.scroller.panGestureRecognizer.isEnabled = false
                                    self.listNode.scroller.panGestureRecognizer.isEnabled = true
                                } else {
                                    self.listNode.scroller.panGestureRecognizer.setTranslation(CGPoint(), in: self.listNode.scroller)
                                }
                            }
                        } else {
                            translation = 0.0
                            recognizer.setTranslation(CGPoint(), in: self.contentNode.view)
                        }

                        self.panGestureArguments = translation
                    }
                    
                    var bounds = self.contentNode.bounds
                    bounds.origin.y = -translation
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.contentNode.bounds = bounds
                case .ended:
                    let translation = recognizer.translation(in: self.contentNode.view)
                    var velocity = recognizer.velocity(in: self.contentNode.view)

                    if case let .known(value) = contentOffset, value > 0.0 {
                        velocity = CGPoint()
                    } else if case .unknown = contentOffset {
                        velocity = CGPoint()
                    }

                    var bounds = self.contentNode.bounds
                    bounds.origin.y = -translation.y
                    bounds.origin.y = min(0.0, bounds.origin.y)

                    self.panGestureArguments = nil
                    if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) {
                        self.controller?.dismiss()
                    } else {
                        var bounds = self.contentNode.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.contentNode.bounds = bounds
                        self.contentNode.layer.animateBounds(from: previousBounds, to: self.contentNode.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                case .cancelled:
                    self.panGestureArguments = nil

                    let previousBounds = self.contentNode.bounds
                    var bounds = self.contentNode.bounds
                    bounds.origin.y = 0.0
                    self.contentNode.bounds = bounds
                    self.contentNode.layer.animateBounds(from: previousBounds, to: self.contentNode.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                default:
                    break
            }
        }
        
        private func updateFloatingHeaderOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
            guard let validLayout = self.validLayout else {
                return
            }
            
            self.floatingHeaderOffset = offset
            
            let layoutTopInset: CGFloat = max(validLayout.statusBarHeight ?? 0.0, validLayout.safeInsets.top)
            
            let controlsHeight: CGFloat = 44.0
            
            let listTopInset = layoutTopInset + controlsHeight
            
            let rawControlsOffset = offset + listTopInset - controlsHeight
            let controlsOffset = max(layoutTopInset, rawControlsOffset)
            let controlsFrame = CGRect(origin: CGPoint(x: 0.0, y: controlsOffset), size: CGSize(width: validLayout.size.width, height: controlsHeight))
            
            let previousFrame = self.headerNode.frame
            
            if !controlsFrame.equalTo(previousFrame) {
                self.headerNode.frame = controlsFrame
                
                let positionDelta = CGPoint(x: controlsFrame.minX - previousFrame.minX, y: controlsFrame.minY - previousFrame.minY)
                
                transition.animateOffsetAdditive(node: self.headerNode, offset: positionDelta.y)
            }
            
//            transition.updateAlpha(node: self.headerNode.separatorNode, alpha: isOverscrolling ? 1.0 : 0.0)
            
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: controlsFrame.maxY), size: CGSize(width: validLayout.size.width, height: validLayout.size.height))
            
            let previousBackgroundFrame = self.historyBackgroundNode.frame
            
            if !backgroundFrame.equalTo(previousBackgroundFrame) {
                self.historyBackgroundNode.frame = backgroundFrame
                self.historyBackgroundContentNode.frame = CGRect(origin: CGPoint(), size: backgroundFrame.size)
                
                let positionDelta = CGPoint(x: backgroundFrame.minX - previousBackgroundFrame.minX, y: backgroundFrame.minY - previousBackgroundFrame.minY)
                
                transition.animateOffsetAdditive(node: self.historyBackgroundNode, offset: positionDelta.y)
            }
        }
    }
}
