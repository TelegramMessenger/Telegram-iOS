import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
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

private final class InviteLinkListControllerArguments {
    let context: AccountContext
    let shareMainLink: (ExportedInvitation) -> Void
    let openMainLink: (ExportedInvitation) -> Void
    let copyLink: (ExportedInvitation) -> Void
    let mainLinkContextAction: (ExportedInvitation?, ASDisplayNode, ContextGesture?) -> Void
    let createLink: () -> Void
    let openLink: (ExportedInvitation) -> Void
    let linkContextAction: (ExportedInvitation?, ASDisplayNode, ContextGesture?) -> Void
    let openAdmin: (ExportedInvitationCreator) -> Void
    let deleteAllRevokedLinks: () -> Void
    
    init(context: AccountContext, shareMainLink: @escaping (ExportedInvitation) -> Void, openMainLink: @escaping (ExportedInvitation) -> Void, copyLink: @escaping (ExportedInvitation) -> Void, mainLinkContextAction: @escaping (ExportedInvitation?, ASDisplayNode, ContextGesture?) -> Void, createLink: @escaping () -> Void, openLink: @escaping (ExportedInvitation?) -> Void, linkContextAction: @escaping (ExportedInvitation?, ASDisplayNode, ContextGesture?) -> Void, openAdmin: @escaping (ExportedInvitationCreator) -> Void, deleteAllRevokedLinks: @escaping () -> Void) {
        self.context = context
        self.shareMainLink = shareMainLink
        self.openMainLink = openMainLink
        self.copyLink = copyLink
        self.mainLinkContextAction = mainLinkContextAction
        self.createLink = createLink
        self.openLink = openLink
        self.linkContextAction = linkContextAction
        self.openAdmin = openAdmin
        self.deleteAllRevokedLinks = deleteAllRevokedLinks
    }
}

private enum InviteLinksListSection: Int32 {
    case header
    case mainLink
    case links
    case admins
    case revokedLinks
}

private enum InviteLinksListEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)
   
    case mainLinkHeader(PresentationTheme, String)
    case mainLink(PresentationTheme, ExportedInvitation?, [Peer], Int32, Bool)
    case mainLinkOtherInfo(PresentationTheme, String)
    
    case linksHeader(PresentationTheme, String)
    case linksCreate(PresentationTheme, String)
    case links(Int32, PresentationTheme, [ExportedInvitation]?, Int)
    case linksInfo(PresentationTheme, String)
    
    case adminsHeader(PresentationTheme, String)
    case admin(Int32, PresentationTheme, ExportedInvitationCreator)
    
    case revokedLinksHeader(PresentationTheme, String)
    case revokedLinksDeleteAll(PresentationTheme, String)
    case revokedLinks(Int32, PresentationTheme, [ExportedInvitation]?)
    
    var section: ItemListSectionId {
        switch self {
            case .header:
                return InviteLinksListSection.header.rawValue
            case .mainLinkHeader, .mainLink, .mainLinkOtherInfo:
                return InviteLinksListSection.mainLink.rawValue
            case .linksHeader, .linksCreate, .links, .linksInfo:
                return InviteLinksListSection.links.rawValue
            case .adminsHeader, .admin:
                return InviteLinksListSection.admins.rawValue
            case .revokedLinksHeader, .revokedLinksDeleteAll, .revokedLinks:
                return InviteLinksListSection.revokedLinks.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .header:
                return 0
            case .mainLinkHeader:
                return 1
            case .mainLink:
                return 2
            case .mainLinkOtherInfo:
                return 3
            case .linksHeader:
                return 4
            case .linksCreate:
                return 5
            case let .links(index, _, _, _):
                return 6 + index
            case .linksInfo:
                return 10000
            case .adminsHeader:
                return 10001
            case let .admin(index, _, _):
                return 10002 + index
            case .revokedLinksHeader:
                return 20001
            case .revokedLinksDeleteAll:
                return 20002
            case let .revokedLinks(index, _, _):
                return 20003 + index
        }
    }
    
    static func ==(lhs: InviteLinksListEntry, rhs: InviteLinksListEntry) -> Bool {
        switch lhs {
            case let .header(lhsTheme, lhsText):
                if case let .header(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .mainLinkHeader(lhsTheme, lhsText):
                if case let .mainLinkHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .mainLink(lhsTheme, lhsInvite, lhsPeers, lhsImportersCount, lhsIsPublic):
                if case let .mainLink(rhsTheme, rhsInvite, rhsPeers, rhsImportersCount, rhsIsPublic) = rhs, lhsTheme === rhsTheme, lhsInvite == rhsInvite, arePeerArraysEqual(lhsPeers, rhsPeers), lhsImportersCount == rhsImportersCount, lhsIsPublic == rhsIsPublic {
                    return true
                } else {
                    return false
                }
            case let .mainLinkOtherInfo(lhsTheme, lhsText):
                if case let .mainLinkOtherInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .linksHeader(lhsTheme, lhsText):
                if case let .linksHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .linksCreate(lhsTheme, lhsText):
                if case let .linksCreate(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .links(lhsIndex, lhsTheme, lhsLinks, lhsCount):
                if case let .links(rhsIndex, rhsTheme, rhsLinks, rhsCount) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsLinks == rhsLinks, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
            case let .linksInfo(lhsTheme, lhsText):
                if case let .linksInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adminsHeader(lhsTheme, lhsText):
                if case let .adminsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .admin(lhsIndex, lhsTheme, lhsCreator):
                if case let .admin(rhsIndex, rhsTheme, rhsCreator) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsCreator == rhsCreator {
                    return true
                } else {
                    return false
                }
            case let .revokedLinksHeader(lhsTheme, lhsText):
                if case let .revokedLinksHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .revokedLinksDeleteAll(lhsTheme, lhsText):
                if case let .revokedLinksDeleteAll(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .revokedLinks(lhsIndex, lhsTheme, lhsLinks):
                if case let .revokedLinks(rhsIndex, rhsTheme, rhsLinks) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsLinks == rhsLinks {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: InviteLinksListEntry, rhs: InviteLinksListEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! InviteLinkListControllerArguments
        switch self {
            case let .header(theme, text):
                return InviteLinkHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .mainLinkHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .mainLink(_, invite, peers, importersCount, isPublic):
                return ItemListPermanentInviteLinkItem(context: arguments.context, presentationData: presentationData, invite: invite, count: importersCount, peers: peers, displayButton: true, displayImporters: !isPublic, buttonColor: nil, sectionId: self.section, style: .blocks, copyAction: {
                    if let invite = invite {
                        arguments.copyLink(invite)
                    }
                }, shareAction: {
                    if let invite = invite {
                        arguments.shareMainLink(invite)
                    }
                }, contextAction: { node in
                    arguments.mainLinkContextAction(invite, node, nil)
                }, viewAction: {
                    if let invite = invite {
                        arguments.openLink(invite)
                    }
                })
            case let .mainLinkOtherInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: nil, style: .blocks, tag: nil)
            case let .linksHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .linksCreate(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(theme), title: text, hasSeparator: false, sectionId: self.section, editing: false, action: {
                    arguments.createLink()
                })
            case let .links(_, _, invites, count):
                return ItemListInviteLinkGridItem(presentationData: presentationData, invites: invites, count: count, share: false, sectionId: self.section, style: .blocks, tapAction: { invite in
                    arguments.openLink(invite)
                }, contextAction: { invite, node in
                    arguments.linkContextAction(invite, node, nil)
                })
            case let .linksInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .adminsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .admin(_, _, creator):
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(timeFormat: .regular, dateFormat: .monthFirst, dateSeparator: ".", decimalSeparator: ".", groupingSeparator: "."), nameDisplayOrder: .firstLast, context: arguments.context, peer: creator.peer.peer!, height: .peerList, aliasHandling: .standard, nameColor: .primary, nameStyle: .plain, presence: nil, text: .none, label: .disclosure("\(creator.count)"), editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: nil), revealOptions: nil, switchValue: nil, enabled: true, highlighted: false, selectable: true, sectionId: self.section, action: {
                    arguments.openAdmin(creator)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, contextAction: nil)
            case let .revokedLinksHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .revokedLinksDeleteAll(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.deleteIconImage(theme), title: text, hasSeparator: false, sectionId: self.section, color: .destructive, editing: false, action: {
                    arguments.deleteAllRevokedLinks()
                })
            case let .revokedLinks(_, _, invites):
                return ItemListInviteLinkGridItem(presentationData: presentationData, invites: invites, count: 0, share: false, sectionId: self.section, style: .blocks, tapAction: { invite in
                    arguments.openLink(invite)
                }, contextAction: { invite, node in
                    arguments.linkContextAction(invite, node, nil)
                })
        }
    }
}

private func inviteLinkListControllerEntries(presentationData: PresentationData, view: PeerView, invites: [ExportedInvitation]?, revokedInvites: [ExportedInvitation]?, importers: PeerInvitationImportersState?, creators: [ExportedInvitationCreator], admin: ExportedInvitationCreator?) -> [InviteLinksListEntry] {
    var entries: [InviteLinksListEntry] = []
    
    if admin == nil {
        entries.append(.header(presentationData.theme, presentationData.strings.InviteLink_CreatePrivateLinkHelp))
    }
    
    let mainInvite: ExportedInvitation?
    var isPublic = false
    if let peer = peerViewMainPeer(view), let address = peer.addressName, !address.isEmpty && admin == nil {
        mainInvite = ExportedInvitation(link: "t.me/\(address)", isPermanent: true, isRevoked: false, adminId: PeerId(0), date: 0, startDate: nil, expireDate: nil, usageLimit: nil, count: nil)
        isPublic = true
    } else if let invites = invites, let invite = invites.first(where: { $0.isPermanent && !$0.isRevoked }) {
        mainInvite = invite
    } else if let invite = (view.cachedData as? CachedChannelData)?.exportedInvitation, admin == nil {
        mainInvite = invite
    } else if let invite = (view.cachedData as? CachedGroupData)?.exportedInvitation, admin == nil {
        mainInvite = invite
    } else {
        mainInvite = nil
    }
    
    entries.append(.mainLinkHeader(presentationData.theme, isPublic ? presentationData.strings.InviteLink_PublicLink.uppercased() : presentationData.strings.InviteLink_PermanentLink.uppercased()))
    
    let importersCount: Int32
    if let count = importers?.count {
        importersCount = count
    } else if let count = mainInvite?.count {
        importersCount = count
    } else {
        importersCount = 0
    }
    
    entries.append(.mainLink(presentationData.theme, mainInvite, importers?.importers.prefix(3).compactMap { $0.peer.peer } ?? [], importersCount, isPublic))
    if let adminPeer = admin?.peer.peer, let peer = peerViewMainPeer(view) {
        let string = presentationData.strings.InviteLink_OtherPermanentLinkInfo(adminPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))
        entries.append(.mainLinkOtherInfo(presentationData.theme, string.0))
    }
    
    entries.append(.linksHeader(presentationData.theme, presentationData.strings.InviteLink_AdditionalLinks.uppercased()))
    if admin == nil {
        entries.append(.linksCreate(presentationData.theme, presentationData.strings.InviteLink_Create))
    }
    var additionalInvites: [ExportedInvitation]?
    if let invites = invites {
        additionalInvites = invites.filter { $0.link != mainInvite?.link }
    }
    if let additionalInvites = additionalInvites {
        var index: Int32 = 0
        for i in stride(from: 0, to: additionalInvites.endIndex, by: 2) {
            var invitesPair: [ExportedInvitation] = []
            invitesPair.append(additionalInvites[i])
            if i + 1 < additionalInvites.count {
                invitesPair.append(additionalInvites[i + 1])
            }
            entries.append(.links(index, presentationData.theme, invitesPair, invitesPair.count))
            index += 1
        }
    } else if let admin = admin {
        var index: Int32 = 0
        for _ in stride(from: 0, to: admin.count, by: 2) {
            entries.append(.links(index, presentationData.theme, nil, 1))
            index += 1
        }
    }
    entries.append(.linksInfo(presentationData.theme, presentationData.strings.InviteLink_CreateInfo))
    
    if !creators.isEmpty {
        entries.append(.adminsHeader(presentationData.theme, presentationData.strings.InviteLink_OtherAdminsLinks.uppercased()))
        var index: Int32 = 0
        for creator in creators {
            if let _ = creator.peer.peer {
                entries.append(.admin(index, presentationData.theme, creator))
                index += 1
            }
        }
    }
    
    if let revokedInvites = revokedInvites, !revokedInvites.isEmpty {
        entries.append(.revokedLinksHeader(presentationData.theme, presentationData.strings.InviteLink_RevokedLinks.uppercased()))
        if admin == nil {
            entries.append(.revokedLinksDeleteAll(presentationData.theme, presentationData.strings.InviteLink_DeleteAllRevokedLinks))
        }
        var index: Int32 = 0
        for i in stride(from: 0, to: revokedInvites.endIndex, by: 2) {
            var invitesPair: [ExportedInvitation] = []
            invitesPair.append(revokedInvites[i])
            if i + 1 < revokedInvites.count {
                invitesPair.append(revokedInvites[i + 1])
            }
            entries.append(.revokedLinks(index, presentationData.theme, invitesPair))
            index += 1
        }
    }
   
    return entries
}

private struct InviteLinkListControllerState: Equatable {
    var revokingPrivateLink: Bool
}


public func inviteLinkListController(context: AccountContext, peerId: PeerId, admin: ExportedInvitationCreator?) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let statePromise = ValuePromise(InviteLinkListControllerState(revokingPrivateLink: false), ignoreRepeated: true)
    let stateValue = Atomic(value: InviteLinkListControllerState(revokingPrivateLink: false))
    let updateState: ((InviteLinkListControllerState) -> InviteLinkListControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let revokeLinkDisposable = MetaDisposable()
    actionsDisposable.add(revokeLinkDisposable)
    
    let deleteAllRevokedLinksDisposable = MetaDisposable()
    actionsDisposable.add(deleteAllRevokedLinksDisposable)
        
    var getControllerImpl: (() -> ViewController?)?
    
    let adminId = admin?.peer.peer?.id
    let invitesContext = PeerExportedInvitationsContext(account: context.account, peerId: peerId, adminId: adminId, revoked: false, forceUpdate: false)
    let revokedInvitesContext = PeerExportedInvitationsContext(account: context.account, peerId: peerId, adminId: adminId, revoked: true, forceUpdate: true)
    
    let creators: Signal<[ExportedInvitationCreator], NoError>
    if adminId == nil {
        creators = .single([]) |> then(peerExportedInvitationsCreators(account: context.account, peerId: peerId))
    } else {
        creators = .single([])
    }
    
    let arguments = InviteLinkListControllerArguments(context: context, shareMainLink: { invite in
        let shareController = ShareController(context: context, subject: .url(invite.link))
        presentControllerImpl?(shareController, nil)
    }, openMainLink: { invite in
        let controller = InviteLinkViewController(context: context, peerId: peerId, invite: invite, invitationsContext: nil, revokedInvitationsContext: revokedInvitesContext, importersContext: nil)
        pushControllerImpl?(controller)
    }, copyLink: { invite in
        UIPasteboard.general.string = invite.link
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
    }, mainLinkContextAction: { invite, node, gesture in
        guard let node = node as? ContextExtractedContentContainingNode, let controller = getControllerImpl?(), let invite = invite else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var items: [ContextMenuItem] = []

        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            UIPasteboard.general.string = invite.link
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Wallet/QrIcon"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            let controller = InviteLinkQRCodeController(context: context, invite: invite)
            presentControllerImpl?(controller, nil)
        })))
        
        if invite.adminId.toInt64() != 0 {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextRevoke, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { _, f in
                f(.dismissWithoutContent)
            
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: presentationData.strings.GroupInfo_InviteLink_RevokeAlert_Text),
                        ActionSheetButtonItem(title: presentationData.strings.GroupInfo_InviteLink_RevokeLink, color: .destructive, action: {
                            dismissAction()
                            
                            var revoke = false
                            updateState { state in
                                if !state.revokingPrivateLink {
                                    revoke = true
                                    var updatedState = state
                                    updatedState.revokingPrivateLink = true
                                    return updatedState
                                } else {
                                    return state
                                }
                            }
                            if revoke {
                                revokeLinkDisposable.set((revokePersistentPeerExportedInvitation(account: context.account, peerId: peerId) |> deliverOnMainQueue).start(completed: {
                                    updateState { state in
                                        var updatedState = state
                                        updatedState.revokingPrivateLink = false
                                        return updatedState
                                    }
                                    
                                    invitesContext.reload()
                                    revokedInvitesContext.reload()
                                }))
                            }
                        })
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })))
        }

        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .extracted(InviteLinkContextExtractedContentSource(controller: controller, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
        presentInGlobalOverlayImpl?(contextController)
    }, createLink: {
        let controller = inviteLinkEditController(context: context, peerId: peerId, invite: nil, completion: { invite in
            if let invite = invite {
                invitesContext.add(invite)
            }
        })
        controller.navigationPresentation = .modal
        pushControllerImpl?(controller)
    }, openLink: { invite in
        if let invite = invite {
            let controller = InviteLinkViewController(context: context, peerId: peerId, invite: invite, invitationsContext: invitesContext, revokedInvitationsContext: revokedInvitesContext, importersContext: nil)
            pushControllerImpl?(controller)
        }
    }, linkContextAction: { invite, node, gesture in
        guard let node = node as? ContextExtractedContentContainingNode, let controller = getControllerImpl?(), let invite = invite else {
            return
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var items: [ContextMenuItem] = []

        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            UIPasteboard.general.string = invite.link

            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
        })))
        
        if !invite.isRevoked {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextShare, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.dismissWithoutContent)
            
                let shareController = ShareController(context: context, subject: .url(invite.link))
                presentControllerImpl?(shareController, nil)
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Wallet/QrIcon"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.dismissWithoutContent)
                
                let controller = InviteLinkQRCodeController(context: context, invite: invite)
                presentControllerImpl?(controller, nil)
            })))
        
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextEdit, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.dismissWithoutContent)
            
                let controller = inviteLinkEditController(context: context, peerId: peerId, invite: invite, completion: { invite in
                    if let invite = invite {
                        if invite.isRevoked {
                            invitesContext.remove(invite)
                            revokedInvitesContext.add(invite.withUpdated(isRevoked: true))
                        } else {
                            invitesContext.update(invite)
                        }
                    }
                })
                controller.navigationPresentation = .modal
                pushControllerImpl?(controller)
            })))
        }
        
        if invite.isRevoked {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextDelete, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { _, f in
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

                            revokeLinkDisposable.set((deletePeerExportedInvitation(account: context.account, peerId: peerId, link: invite.link) |> deliverOnMainQueue).start(completed: {

                            }))
                            
                            revokedInvitesContext.remove(invite)
                        })
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })))
        } else {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextRevoke, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { _, f in
                f(.dismissWithoutContent)
            
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: presentationData.strings.GroupInfo_InviteLink_RevokeAlert_Text),
                        ActionSheetButtonItem(title: presentationData.strings.GroupInfo_InviteLink_RevokeLink, color: .destructive, action: {
                            dismissAction()
                            
                            revokeLinkDisposable.set((revokePeerExportedInvitation(account: context.account, peerId: peerId, link: invite.link) |> deliverOnMainQueue).start(completed: {

                            }))
                            
                            invitesContext.remove(invite)
                            revokedInvitesContext.add(invite.withUpdated(isRevoked: true))
                        })
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })))
        }

        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .extracted(InviteLinkContextExtractedContentSource(controller: controller, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
        presentInGlobalOverlayImpl?(contextController)
    }, openAdmin: { admin in
        let controller = inviteLinkListController(context: context, peerId: peerId, admin: admin)
        pushControllerImpl?(controller)
    }, deleteAllRevokedLinks: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationData: presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: presentationData.strings.InviteLink_DeleteAllRevokedLinksAlert_Text),
                ActionSheetButtonItem(title: presentationData.strings.InviteLink_DeleteAllRevokedLinksAlert_Action, color: .destructive, action: {
                    dismissAction()
                    
                    deleteAllRevokedLinksDisposable.set((deleteAllRevokedPeerExportedInvitations(account: context.account, peerId: peerId) |> deliverOnMainQueue).start(completed: {
                    }))
                    
                    revokedInvitesContext.clear()
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    })
        
    let peerView = context.account.viewTracker.peerView(peerId)
    |> deliverOnMainQueue
    
    let importersState = Promise<PeerInvitationImportersState?>(nil)
    let importersContext: Signal<PeerInvitationImportersContext?, NoError> = peerView
    |> mapToSignal { view -> Signal<ExportedInvitation?, NoError> in
        if let cachedData = view.cachedData as? CachedGroupData, let exportedInvitation = cachedData.exportedInvitation {
            return .single(exportedInvitation)
        } else if let cachedData = view.cachedData as? CachedChannelData, let exportedInvitation = cachedData.exportedInvitation {
            return .single(exportedInvitation)
        } else {
            return .single(nil)
        }
    }
    |> distinctUntilChanged
    |> deliverOnMainQueue
    |> map { invite -> PeerInvitationImportersContext? in
        return invite.flatMap { PeerInvitationImportersContext(account: context.account, peerId: peerId, invite: $0) }
    } |> afterNext { context in
        if let context = context {
            importersState.set(context.state |> map(Optional.init))
        } else {
            importersState.set(.single(nil))
        }
    }
    
    let previousRevokedInvites = Atomic<PeerExportedInvitationsState?>(value: nil)
    let signal = combineLatest(context.sharedContext.presentationData, peerView, importersContext, importersState.get(), invitesContext.state, revokedInvitesContext.state, creators)
    |> deliverOnMainQueue
    |> map { presentationData, view, importersContext, importers, invites, revokedInvites, creators -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let previousRevokedInvites = previousRevokedInvites.swap(invites)
        
        var crossfade = false
        if (previousRevokedInvites?.hasLoadedOnce ?? false) != (revokedInvites.hasLoadedOnce) {
            crossfade = true
        }
        
        let title: ItemListControllerTitle
        if let admin = admin, let peer = admin.peer.peer {
            title = .textWithSubtitle(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), "\(admin.count) invite links")
        } else {
            title = .text(presentationData.strings.InviteLink_Title)
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: inviteLinkListControllerEntries(presentationData: presentationData, view: view, invites: invites.hasLoadedOnce ? invites.invitations : nil, revokedInvites: revokedInvites.invitations, importers: importers, creators: creators, admin: admin), style: .blocks, emptyStateItem: nil, crossfadeState: crossfade, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
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
    return controller
}


final class InviteLinkContextExtractedContentSource: ContextExtractedContentSource {
    var keepInPlace: Bool
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.keepInPlace = true
        self.blurBackground = false
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
