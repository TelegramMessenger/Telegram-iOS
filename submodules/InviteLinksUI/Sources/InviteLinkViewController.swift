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

class InviteLinkViewInteraction {
    let context: AccountContext
    let openPeer: (EnginePeer.Id) -> Void
    let copyLink: (ExportedInvitation) -> Void
    let shareLink: (ExportedInvitation) -> Void
    let editLink: (ExportedInvitation) -> Void
    let contextAction: (ExportedInvitation, ASDisplayNode, ContextGesture?) -> Void
    
    init(context: AccountContext, openPeer: @escaping (EnginePeer.Id) -> Void, copyLink: @escaping (ExportedInvitation) -> Void, shareLink: @escaping (ExportedInvitation) -> Void, editLink: @escaping (ExportedInvitation) -> Void, contextAction: @escaping (ExportedInvitation, ASDisplayNode, ContextGesture?) -> Void) {
        self.context = context
        self.openPeer = openPeer
        self.copyLink = copyLink
        self.shareLink = shareLink
        self.editLink = editLink
        self.contextAction = contextAction
    }
}

private struct InviteLinkViewTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isLoading: Bool
    let animated: Bool
    let crossfade: Bool
}

private enum InviteLinkViewEntryId: Hashable {
    case link
    case creatorHeader
    case creator
    case requestHeader
    case request(EnginePeer.Id)
    case importerHeader
    case importer(EnginePeer.Id)
}

private enum InviteLinkViewEntry: Comparable, Identifiable {
    case link(PresentationTheme, ExportedInvitation)
    case creatorHeader(PresentationTheme, String)
    case creator(PresentationTheme, PresentationDateTimeFormat, EnginePeer, Int32)
    case requestHeader(PresentationTheme, String, String, Bool)
    case request(Int32, PresentationTheme, PresentationDateTimeFormat, EnginePeer, Int32, Bool)
    case importerHeader(PresentationTheme, String, String, Bool)
    case importer(Int32, PresentationTheme, PresentationDateTimeFormat, EnginePeer, Int32, Bool)
    
    var stableId: InviteLinkViewEntryId {
        switch self {
            case .link:
                return .link
            case .creatorHeader:
                return .creatorHeader
            case .creator:
                return .creator
            case .requestHeader:
                return .requestHeader
            case let .request(_, _, _, peer, _, _):
                return .request(peer.id)
            case .importerHeader:
                return .importerHeader
            case let .importer(_, _, _, peer, _, _):
                return .importer(peer.id)
        }
    }
    
    static func ==(lhs: InviteLinkViewEntry, rhs: InviteLinkViewEntry) -> Bool {
        switch lhs {
            case let .link(lhsTheme, lhsInvitation):
                if case let .link(rhsTheme, rhsInvitation) = rhs, lhsTheme === rhsTheme, lhsInvitation == rhsInvitation {
                    return true
                } else {
                    return false
                }
            case let .creatorHeader(lhsTheme, lhsTitle):
                if case let .creatorHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .creator(lhsTheme, lhsDateTimeFormat, lhsPeer, lhsDate):
                if case let .creator(rhsTheme, rhsDateTimeFormat, rhsPeer, rhsDate) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsPeer == rhsPeer, lhsDate == rhsDate {
                    return true
                } else {
                    return false
                }
            case let .requestHeader(lhsTheme, lhsTitle, lhsSubtitle, lhsExpired):
                if case let .requestHeader(rhsTheme, rhsTitle, rhsSubtitle, rhsExpired) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsExpired == rhsExpired {
                    return true
                } else {
                    return false
                }
            case let .request(lhsIndex, lhsTheme, lhsDateTimeFormat, lhsPeer, lhsDate, lhsLoading):
                if case let .request(rhsIndex, rhsTheme, rhsDateTimeFormat, rhsPeer, rhsDate, rhsLoading) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsPeer == rhsPeer, lhsDate == rhsDate, lhsLoading == rhsLoading {
                    return true
                } else {
                    return false
                }
            case let .importerHeader(lhsTheme, lhsTitle, lhsSubtitle, lhsExpired):
                if case let .importerHeader(rhsTheme, rhsTitle, rhsSubtitle, rhsExpired) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsExpired == rhsExpired {
                    return true
                } else {
                    return false
                }
            case let .importer(lhsIndex, lhsTheme, lhsDateTimeFormat, lhsPeer, lhsDate, lhsLoading):
                if case let .importer(rhsIndex, rhsTheme, rhsDateTimeFormat, rhsPeer, rhsDate, rhsLoading) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsPeer == rhsPeer, lhsDate == rhsDate, lhsLoading == rhsLoading {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: InviteLinkViewEntry, rhs: InviteLinkViewEntry) -> Bool {
        switch lhs {
            case .link:
                switch rhs {
                    case .link:
                        return false
                    case .creatorHeader, .creator, .requestHeader, .request, .importerHeader, .importer:
                        return true
                }
            case .creatorHeader:
                switch rhs {
                    case .link, .creatorHeader:
                        return false
                    case .creator, .requestHeader, .request, .importerHeader, .importer:
                        return true
                }
            case .creator:
                switch rhs {
                    case .link, .creatorHeader, .creator:
                        return false
                    case .requestHeader, .request, .importerHeader, .importer:
                        return true
            }
            case .requestHeader:
                switch rhs {
                    case .link, .creatorHeader, .creator, .requestHeader:
                        return false
                    case .request, .importerHeader, .importer:
                        return true
                }
            case let .request(lhsIndex, _, _, _, _, _):
                switch rhs {
                    case .link, .creatorHeader, .creator, .requestHeader:
                        return false
                    case let .request(rhsIndex, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    case .importerHeader, .importer:
                        return true
                }
            case .importerHeader:
                switch rhs {
                    case .link, .creatorHeader, .creator, .requestHeader, .request, .importerHeader:
                        return false
                    case .importer:
                        return true
                }
            case let .importer(lhsIndex, _, _, _, _, _):
                switch rhs {
                    case .link, .creatorHeader, .creator, .importerHeader, .request, .requestHeader:
                        return false
                    case let .importer(rhsIndex, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                }
        }
    }
    
    func item(account: Account, presentationData: PresentationData, interaction: InviteLinkViewInteraction) -> ListViewItem {
        switch self {
            case let .link(_, invite):
                return ItemListPermanentInviteLinkItem(context: interaction.context, presentationData: ItemListPresentationData(presentationData), invite: invite, count: 0, peers: [], displayButton: !invite.isRevoked, displayImporters: false, buttonColor: nil, sectionId: 0, style: .plain, copyAction: {
                    interaction.copyLink(invite)
                }, shareAction: {
                    if invitationAvailability(invite).isZero {
                        interaction.editLink(invite)
                    } else {
                        interaction.shareLink(invite)
                    }
                }, contextAction: { node, gesture in
                    interaction.contextAction(invite, node, gesture)
                }, viewAction: {
                })
            case let .creatorHeader(_, title):
                return SectionHeaderItem(presentationData: ItemListPresentationData(presentationData), title: title)
            case let .creator(_, dateTimeFormat, peer, date):
                let dateString = stringForFullDate(timestamp: date, strings: presentationData.strings, dateTimeFormat: dateTimeFormat)
                return ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: interaction.context, peer: peer, height: .generic, nameStyle: .distinctBold, presence: nil, text: .text(dateString, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: peer.id != account.peerId, sectionId: 0, action: {
                    interaction.openPeer(peer.id)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, hasTopStripe: false, noInsets: true, tag: nil)
            case let .importerHeader(_, title, subtitle, expired), let .requestHeader(_, title, subtitle, expired):
                let additionalText: SectionHeaderAdditionalText
                if !subtitle.isEmpty {
                    if expired {
                        additionalText = .destructive(subtitle)
                    } else {
                        additionalText = .generic(subtitle)
                    }
                } else {
                    additionalText = .none
                }
                return SectionHeaderItem(presentationData: ItemListPresentationData(presentationData), title: title, additionalText: additionalText)
            case let .importer(_, _, dateTimeFormat, peer, date, loading), let .request(_, _, dateTimeFormat, peer, date, loading):
                let dateString = stringForFullDate(timestamp: date, strings: presentationData.strings, dateTimeFormat: dateTimeFormat)
                return ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: interaction.context, peer: peer, height: .generic, nameStyle: .distinctBold, presence: nil, text: .text(dateString, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: peer.id != account.peerId, sectionId: 0, action: {
                    interaction.openPeer(peer.id)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, hasTopStripe: false, noInsets: true, tag: nil, shimmering: loading ? ItemListPeerItemShimmering(alternationIndex: 0) : nil)
        }
    }
}

private func preparedTransition(from fromEntries: [InviteLinkViewEntry], to toEntries: [InviteLinkViewEntry], isLoading: Bool, animated: Bool, crossfade: Bool, account: Account, presentationData: PresentationData, interaction: InviteLinkViewInteraction) -> InviteLinkViewTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return InviteLinkViewTransaction(deletions: deletions, insertions: insertions, updates: updates, isLoading: isLoading, animated: animated, crossfade: crossfade)
}

private let titleFont = Font.bold(17.0)
private let subtitleFont = Font.with(size: 13, design: .regular, weight: .regular, traits: .monospacedNumbers)

func textForTimeout(value: Int32) -> String {
    if value < 3600 {
        let minutes = value / 60
        let seconds = value % 60
        let secondsPadding = seconds < 10 ? "0" : ""
        return "\(minutes):\(secondsPadding)\(seconds)"
    } else {
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let minutesPadding = minutes < 10 ? "0" : ""
        let seconds = value % 60
        let secondsPadding = seconds < 10 ? "0" : ""
        return "\(hours):\(minutesPadding)\(minutes):\(secondsPadding)\(seconds)"
    }
}

public final class InviteLinkViewController: ViewController {
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let invite: ExportedInvitation
    private let invitationsContext: PeerExportedInvitationsContext?
    private let revokedInvitationsContext: PeerExportedInvitationsContext?
    private let importersContext: PeerInvitationImportersContext?

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    fileprivate var presentationDataPromise = Promise<PresentationData>()
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, invite: ExportedInvitation, invitationsContext: PeerExportedInvitationsContext?, revokedInvitationsContext: PeerExportedInvitationsContext?, importersContext: PeerInvitationImportersContext?) {
        self.context = context
        self.peerId = peerId
        self.invite = invite
        self.invitationsContext = invitationsContext
        self.revokedInvitationsContext = revokedInvitationsContext
        self.importersContext = importersContext
        
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .flatModal
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(presentationData))
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
        self.displayNode = Node(context: self.context, presentationData: self.presentationData, peerId: self.peerId, invite: self.invite, importersContext: self.importersContext, controller: self)
    }
    
    override public func loadView() {
        super.loadView()
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
                self?.dismiss(animated: false)
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
        private weak var controller: InviteLinkViewController?
        
        private let context: AccountContext
        private let peerId: EnginePeer.Id
        private var invite: ExportedInvitation
        
        private let importersContext: PeerInvitationImportersContext
        private let requestsContext: PeerInvitationImportersContext?
        
        private var interaction: InviteLinkViewInteraction?
        
        private var presentationData: PresentationData
        private let presentationDataPromise: Promise<PresentationData>
        
        private var disposable: Disposable?
        
        private let dimNode: ASDisplayNode
        private let contentNode: ASDisplayNode
        private let headerNode: ASDisplayNode
        private let headerBackgroundNode: ASDisplayNode
        private let titleNode: ImmediateTextNode
        private let subtitleNode: ImmediateTextNode
        private let editButton: HighlightableButtonNode
        private let doneButton: HighlightableButtonNode
        private let historyBackgroundNode: ASDisplayNode
        private let historyBackgroundContentNode: ASDisplayNode
        private var floatingHeaderOffset: CGFloat?
        private let listNode: ListView
        
        private var enqueuedTransitions: [InviteLinkViewTransaction] = []
        
        private var countdownTimer: SwiftSignalKit.Timer?
        
        private var validLayout: ContainerViewLayout?
        
        init(context: AccountContext, presentationData: PresentationData, peerId: EnginePeer.Id, invite: ExportedInvitation, importersContext: PeerInvitationImportersContext?, controller: InviteLinkViewController) {
            self.context = context
            self.peerId = peerId
            self.invite = invite
            self.presentationData = presentationData
            self.presentationDataPromise = Promise(self.presentationData)
            self.controller = controller
            
            self.importersContext = importersContext ?? context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .invite(invite: invite, requested: false))
            if case let .link(_, _, _, requestApproval, _, _, _, _, _, _, _, _) = invite, requestApproval {
                self.requestsContext = context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .invite(invite: invite, requested: true))
            } else {
                self.requestsContext = nil
            }
            
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
            
            self.subtitleNode = ImmediateTextNode()
            self.subtitleNode.maximumNumberOfLines = 1
            self.subtitleNode.textAlignment = .center
            
            let accentColor = presentationData.theme.actionSheet.controlAccentColor
            
            self.editButton = HighlightableButtonNode()
            self.editButton.setTitle(self.presentationData.strings.Common_Edit, with: Font.regular(17.0), with: accentColor, for: .normal)
            
            self.doneButton = HighlightableButtonNode()
            self.doneButton.setTitle(self.presentationData.strings.Common_Done, with: Font.bold(17.0), with: accentColor, for: .normal)
            
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
        
            self.interaction = InviteLinkViewInteraction(context: context, openPeer: { [weak self] peerId in
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    guard let peer = peer else {
                        return
                    }
                    
                    if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), keepStack: .always))
                    }
                })
            }, copyLink: { [weak self] invite in
                UIPasteboard.general.string = invite.link
                
                self?.controller?.dismissAllTooltips()
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
            }, shareLink: { [weak self] invite in
                guard let inviteLink = invite.link else {
                    return
                }
                let shareController = ShareController(context: context, subject: .url(inviteLink))
                shareController.completed = { [weak self] peerIds in
                    if let strongSelf = self {
                        let _ = (strongSelf.context.engine.data.get(
                            EngineDataList(
                                peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                            )
                        )
                        |> deliverOnMainQueue).start(next: { [weak self] peerList in
                            if let strongSelf = self {
                                let peers = peerList.compactMap { $0 }
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                
                                let text: String
                                var savedMessages = false
                                if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                                    text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_SavedMessages_One
                                    savedMessages = true
                                } else {
                                    if peers.count == 1, let peer = peers.first {
                                        let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_Chat_One(peerName).string
                                    } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                        let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        text = presentationData.strings.InviteLink_InviteLinkForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                                    } else if let peer = peers.first {
                                        let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
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
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                }
                self?.controller?.present(shareController, in: .window(.root))
            }, editLink: { [weak self] invite in
                self?.editButtonPressed()
            }, contextAction: { [weak self] invite, node, gesture in
                guard let node = node as? ContextReferenceContentNode else {
                    return
                }
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                var items: [ContextMenuItem] = []

                items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                    
                    UIPasteboard.general.string = invite.link
  
                    self?.controller?.dismissAllTooltips()
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                })))
                
                if invite.isRevoked {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextDelete, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                    }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        
                        let controller = ActionSheetController(presentationData: presentationData)
                        let dismissAction: () -> Void = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetTextItem(title: presentationData.strings.InviteLink_DeleteLinkAlert_Text),
                                ActionSheetButtonItem(title: presentationData.strings.InviteLink_DeleteLinkAlert_Action, color: .destructive, action: {
                                    dismissAction()
                                    self?.controller?.dismiss()
                                    
                                    if let inviteLink = invite.link {
                                        let _ = (context.engine.peers.deletePeerExportedInvitation(peerId: peerId, link: inviteLink) |> deliverOnMainQueue).start()
                                    }
                                    
                                    self?.controller?.revokedInvitationsContext?.remove(invite)
                                })
                            ]),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                        ])
                        self?.controller?.present(controller, in: .window(.root))
                    })))
                } else {
                    if !invitationAvailability(invite).isZero {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            let _ = (context.account.postbox.loadedPeerWithId(peerId)
                            |> deliverOnMainQueue).start(next: { [weak self] peer in
                                guard let strongSelf = self, let parentController = strongSelf.controller else {
                                    return
                                }
                                let isGroup: Bool
                                if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                    isGroup = false
                                } else {
                                    isGroup = true
                                }
                                let updatedPresentationData = (strongSelf.presentationData, parentController.presentationDataPromise.get())
                                strongSelf.controller?.present(QrCodeScreen(context: context, updatedPresentationData: updatedPresentationData, subject: .invite(invite: invite, isGroup: isGroup)), in: .window(.root))
                            })
                        })))
                    }
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextRevoke, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                    }, action: { [weak self] _, f in
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
                                        self?.controller?.dismiss()

                                        if let inviteLink = invite.link {
                                            let _ = (context.engine.peers.revokePeerExportedInvitation(peerId: peerId, link: inviteLink) |> deliverOnMainQueue).start(next: { result in
                                                if case let .replace(_, newInvite) = result {
                                                    self?.controller?.invitationsContext?.add(newInvite)
                                                }
                                            })
                                        }
                                        
                                        self?.controller?.invitationsContext?.remove(invite)
                                        let revokedInvite = invite.withUpdated(isRevoked: true)
                                        self?.controller?.revokedInvitationsContext?.add(revokedInvite)
                                        
                                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                        self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkRevoked(text: presentationData.strings.InviteLink_InviteLinkRevoked), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                                    })
                                ]),
                                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                            ])
                            self?.controller?.present(controller, in: .window(.root))
                        })
                    })))
                }
                           
                let contextController = ContextController(account: context.account, presentationData: presentationData, source: .reference(InviteLinkContextReferenceContentSource(controller: controller, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                self?.controller?.presentInGlobalOverlay(contextController)
            })
            
            let previousEntries = Atomic<[InviteLinkViewEntry]?>(value: nil)
            let previousCount = Atomic<Int32?>(value: nil)
            let previousLoading = Atomic<Bool?>(value: nil)
            
            let requestsState: Signal<PeerInvitationImportersState, NoError>
            if let requestsContext = self.requestsContext {
                requestsState = requestsContext.state
            } else {
                requestsState = .single(PeerInvitationImportersState.Empty)
            }
            
            if case let .link(_, _, _, _, _, adminId, date, _, _, usageLimit, _, _) = invite {
                self.disposable = (combineLatest(
                    self.presentationDataPromise.get(),
                    self.importersContext.state,
                    requestsState,
                    context.account.postbox.loadedPeerWithId(adminId)
                ) |> deliverOnMainQueue).start(next: { [weak self] presentationData, state, requestsState, creatorPeer in
                    if let strongSelf = self {
                        var entries: [InviteLinkViewEntry] = []
                        
                        entries.append(.link(presentationData.theme, invite))
                        entries.append(.creatorHeader(presentationData.theme, presentationData.strings.InviteLink_CreatedBy.uppercased()))
                        entries.append(.creator(presentationData.theme, presentationData.dateTimeFormat, EnginePeer(creatorPeer), date))
                                            
                        if !requestsState.importers.isEmpty || (state.isLoadingMore && requestsState.count > 0) {
                            entries.append(.requestHeader(presentationData.theme, presentationData.strings.MemberRequests_PeopleRequested(Int32(requestsState.count)).uppercased(), "", false))
                        }
                        
                        var count: Int32
                        var loading: Bool
                        var index: Int32 = 0
                        if requestsState.importers.isEmpty && requestsState.isLoadingMore {
                            count = min(4, state.count)
                            loading = true
                            let fakeUser = TelegramUser(id: EnginePeer.Id(namespace: .max, id: EnginePeer.Id.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "", lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [])
                            for i in 0 ..< count {
                                entries.append(.request(Int32(i), presentationData.theme, presentationData.dateTimeFormat, EnginePeer.user(fakeUser), 0, true))
                            }
                        } else {
                            count = min(4, Int32(requestsState.importers.count))
                            loading = false
                            for importer in requestsState.importers {
                                if let peer = importer.peer.peer {
                                    entries.append(.request(index, presentationData.theme, presentationData.dateTimeFormat, EnginePeer(peer), importer.date, false))
                                }
                                index += 1
                            }
                        }
                        
                        if !state.importers.isEmpty || (state.isLoadingMore && state.count > 0) {
                            let subtitle: String
                            let subtitleExpired: Bool
                            if let usageLimit = usageLimit {
                                let remaining = max(0, usageLimit - state.count)
                                subtitle = presentationData.strings.InviteLink_PeopleRemaining(remaining).uppercased()
                                subtitleExpired = remaining <= 0
                            } else {
                                subtitle = ""
                                subtitleExpired = false
                            }

                            entries.append(.importerHeader(presentationData.theme, presentationData.strings.InviteLink_PeopleJoined(Int32(state.count)).uppercased(), subtitle, subtitleExpired))
                        }
                        
                        index = 0
                        if state.importers.isEmpty && state.isLoadingMore {
                            count = min(4, state.count)
                            loading = true
                            let fakeUser = TelegramUser(id: EnginePeer.Id(namespace: .max, id: EnginePeer.Id.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "", lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [])
                            for i in 0 ..< count {
                                entries.append(.importer(Int32(i), presentationData.theme, presentationData.dateTimeFormat, EnginePeer.user(fakeUser), 0, true))
                            }
                        } else {
                            count = min(4, Int32(state.importers.count))
                            loading = false
                            for importer in state.importers {
                                if let peer = importer.peer.peer {
                                    entries.append(.importer(index, presentationData.theme, presentationData.dateTimeFormat, EnginePeer(peer), importer.date, false))
                                }
                                index += 1
                            }
                        }
                        
                        let previousCount = previousCount.swap(count)
                        let previousLoading = previousLoading.swap(loading)
                        
                        var animated = false
                        var crossfade = false
                        if let previousCount = previousCount, let previousLoading = previousLoading {
                            if (previousCount == count || previousCount >= 4) && previousLoading && !loading {
                                crossfade = true
                            } else if previousCount < 4 && previousCount != count && !loading {
                                animated = true
                            }
                        }
                        let previousEntries = previousEntries.swap(entries)
                        
                        let transition = preparedTransition(from: previousEntries ?? [], to: entries, isLoading: false, animated: animated, crossfade: crossfade, account: context.account, presentationData: presentationData, interaction: strongSelf.interaction!)
                        strongSelf.enqueueTransition(transition)
                    }
                })
            }
            
            self.listNode.preloadPages = true
            self.listNode.stackFromBottom = true
            self.listNode.updateFloatingHeaderOffset = { [weak self] offset, transition in
                if let strongSelf = self {
                    strongSelf.updateFloatingHeaderOffset(offset: offset, transition: transition)
                }
            }
            self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
                if case let .known(value) = offset, value < 40.0 {
                    self?.importersContext.loadMore()
                }
            }
            
            self.addSubnode(self.dimNode)
            self.addSubnode(self.contentNode)
            self.contentNode.addSubnode(self.historyBackgroundNode)
            self.contentNode.addSubnode(self.listNode)
            self.contentNode.addSubnode(self.headerNode)
            
            self.headerNode.addSubnode(self.headerBackgroundNode)
            self.headerNode.addSubnode(self.titleNode)
            self.headerNode.addSubnode(self.subtitleNode)
            self.headerNode.addSubnode(self.editButton)
            self.headerNode.addSubnode(self.doneButton)
            
            self.editButton.addTarget(self, action: #selector(self.editButtonPressed), forControlEvents: .touchUpInside)
            self.doneButton.addTarget(self, action: #selector(self.doneButtonPressed), forControlEvents: .touchUpInside)
                        
            if invite.isPermanent || invite.isRevoked {
                self.editButton.isHidden = true
            }
        }
        
        deinit {
            self.disposable?.dispose()
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
        
        @objc private func editButtonPressed() {
            guard let parentController = self.controller else {
                return
            }
            
            let navigationController = parentController.navigationController as? NavigationController
          
  
            let invitationsContext = parentController.invitationsContext
            let revokedInvitationsContext = parentController.revokedInvitationsContext
            if let navigationController = navigationController {
                let updatedPresentationData = (self.presentationData, parentController.presentationDataPromise.get())
                let controller = inviteLinkEditController(context: self.context, updatedPresentationData: updatedPresentationData, peerId: self.peerId, invite: self.invite, completion: { [weak self] invite in
                    if let invite = invite {
                        if invite.isRevoked {
                            invitationsContext?.remove(invite)
                            revokedInvitationsContext?.add(invite.withUpdated(isRevoked: true))
                            
                            self?.controller?.dismiss()
                        } else {
                            invitationsContext?.update(invite)
                            
                            if let strongSelf = self, let layout = strongSelf.validLayout {
                                strongSelf.invite = invite
                                strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                            }
                        }
                    }
                })
                controller.navigationPresentation = .modal
                navigationController.pushViewController(controller)
            }
        }
        
        @objc private func doneButtonPressed() {
            self.controller?.dismiss()
        }
        
        func updatePresentationData(_ presentationData: PresentationData) {
            self.presentationData = presentationData
            self.presentationDataPromise.set(.single(presentationData))
            
            self.historyBackgroundContentNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            self.headerBackgroundNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            self.titleNode.attributedText = NSAttributedString(string: self.titleNode.attributedText?.string ?? "", font: titleFont, textColor: self.presentationData.theme.actionSheet.primaryTextColor)
            self.subtitleNode.attributedText = NSAttributedString(string: self.subtitleNode.attributedText?.string ?? "", font: subtitleFont, textColor: self.presentationData.theme.list.itemSecondaryTextColor)
            
            let accentColor = self.presentationData.theme.actionSheet.controlAccentColor
            self.editButton.setTitle(self.presentationData.strings.Common_Edit, with: Font.regular(17.0), with: accentColor, for: .normal)
            self.doneButton.setTitle(self.presentationData.strings.Common_Done, with: Font.bold(17.0), with: accentColor, for: .normal)
        }
        
        private func enqueueTransition(_ transition: InviteLinkViewTransaction) {
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
            
            var options = ListViewDeleteAndInsertOptions()
            if transition.animated {
                options.insert(.AnimateInsertion)
            }
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
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
            let visibleItemsHeight: CGFloat = 147.0 + floor(52.0 * 3.5)
        
            let layoutTopInset: CGFloat = max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top)
            
            let listTopInset = layoutTopInset + headerHeight
            let listNodeSize = CGSize(width: layout.size.width, height: layout.size.height - listTopInset)
            
            insets.top = max(0.0, listNodeSize.height - visibleItemsHeight)
                        
            let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listNodeSize, insets: insets, duration: duration, curve: curve)
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            
            transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(x: 0.0, y: listTopInset), size: listNodeSize))
            
            transition.updateFrame(node: self.headerBackgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: 68.0))
            
            var titleText = self.presentationData.strings.InviteLink_InviteLink
            var subtitleText = ""
            var subtitleColor = self.presentationData.theme.list.itemSecondaryTextColor
            
            if case let .link(_, title, _, _, isRevoked, _, _, _, expireDate, usageLimit, count, _) = self.invite {
                if isRevoked {
                    subtitleText = self.presentationData.strings.InviteLink_Revoked
                } else if let usageLimit = usageLimit, let count = count, count >= usageLimit {
                    subtitleText = self.presentationData.strings.InviteLink_UsageLimitReached
                    subtitleColor = self.presentationData.theme.list.itemDestructiveColor
                } else if let expireDate = expireDate {
                    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                    if currentTime >= expireDate {
                        titleText = self.presentationData.strings.InviteLink_ExpiredLink
                        subtitleText = self.presentationData.strings.InviteLink_ExpiredLinkStatus
                        subtitleColor = self.presentationData.theme.list.itemDestructiveColor
                        self.countdownTimer?.invalidate()
                        self.countdownTimer = nil
                    } else {
                        let elapsedTime = expireDate - currentTime
                        if elapsedTime >= 86400 {
                            subtitleText = self.presentationData.strings.InviteLink_ExpiresIn(scheduledTimeIntervalString(strings: self.presentationData.strings, value: elapsedTime)).string
                        } else {
                            subtitleText = self.presentationData.strings.InviteLink_ExpiresIn(textForTimeout(value: elapsedTime)).string
                            if self.countdownTimer == nil {
                                let countdownTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                                    if let strongSelf = self, let layout = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                                    }
                                }, queue: Queue.mainQueue())
                                self.countdownTimer = countdownTimer
                                countdownTimer.start()
                            }
                        }
                    }
                }
            
                if let title = title, !title.isEmpty {
                    titleText = title
                }
            }
            
            self.titleNode.attributedText = NSAttributedString(string: titleText, font: Font.bold(17.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
            self.subtitleNode.attributedText = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: subtitleColor)
                                                
            let editSize = self.editButton.measure(CGSize(width: layout.size.width, height: headerHeight))
            let editFrame = CGRect(origin: CGPoint(x: 16.0 + layout.safeInsets.left, y: 18.0), size: editSize)
            transition.updateFrame(node: self.editButton, frame: editFrame)
            
            let doneSize = self.doneButton.measure(CGSize(width: layout.size.width, height: headerHeight))
            let doneFrame = CGRect(origin: CGPoint(x: layout.size.width - doneSize.width - 16.0 - layout.safeInsets.right, y: 18.0), size: doneSize)
            transition.updateFrame(node: self.doneButton, frame: doneFrame)
            
            let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: layout.size.width - editSize.width - doneSize.width - 20.0, height: headerHeight))
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - subtitleSize.width) / 2.0), y: 30.0 - UIScreenPixel), size: subtitleSize)
            transition.updateFrame(node: self.subtitleNode, frame: subtitleFrame)
            
            let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - editSize.width - doneSize.width - 20.0, height: headerHeight))
            let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: subtitleSize.height.isZero ? 18.0 : 10.0 + UIScreenPixel), size: titleSize)
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
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
