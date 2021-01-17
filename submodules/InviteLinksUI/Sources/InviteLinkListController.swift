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
import ShareController

private final class InviteLinkListControllerArguments {
    let context: AccountContext
    let shareMainLink: (ExportedInvitation?) -> Void
    let openMainLink: (ExportedInvitation?) -> Void
    let mainLinkContextAction: (ExportedInvitation?, ASDisplayNode, ContextGesture?) -> Void
    let createLink: () -> Void
    let openLink: (ExportedInvitation) -> Void
    let linkContextAction: (ExportedInvitation?, ASDisplayNode, ContextGesture?) -> Void
    let deleteAllRevokedLinks: () -> Void
    
    init(context: AccountContext, shareMainLink: @escaping (ExportedInvitation?) -> Void, openMainLink: @escaping (ExportedInvitation?) -> Void, mainLinkContextAction: @escaping (ExportedInvitation?, ASDisplayNode, ContextGesture?) -> Void, createLink: @escaping () -> Void, openLink: @escaping (ExportedInvitation?) -> Void, linkContextAction: @escaping (ExportedInvitation?, ASDisplayNode, ContextGesture?) -> Void, deleteAllRevokedLinks: @escaping () -> Void) {
        self.context = context
        self.shareMainLink = shareMainLink
        self.openMainLink = openMainLink
        self.mainLinkContextAction = mainLinkContextAction
        self.createLink = createLink
        self.openLink = openLink
        self.linkContextAction = linkContextAction
        self.deleteAllRevokedLinks = deleteAllRevokedLinks
    }
}

private enum InviteLinksListSection: Int32 {
    case header
    case mainLink
    case links
    case revokedLinks
}

private enum InviteLinksListEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)
   
    case mainLinkHeader(PresentationTheme, String)
    case mainLink(PresentationTheme, ExportedInvitation?, [Peer])
    
    case linksHeader(PresentationTheme, String)
    case linksCreate(PresentationTheme, String)
    case links(Int32, PresentationTheme, [ExportedInvitation]?)
    case linksInfo(PresentationTheme, String)
    case revokedLinksHeader(PresentationTheme, String)
    case revokedLinksDeleteAll(PresentationTheme, String)
    case revokedLinks(Int32, PresentationTheme, [ExportedInvitation]?)
    
    var section: ItemListSectionId {
        switch self {
            case .header:
                return InviteLinksListSection.header.rawValue
            case .mainLinkHeader, .mainLink:
                return InviteLinksListSection.mainLink.rawValue
            case .linksHeader, .linksCreate, .links, .linksInfo:
                return InviteLinksListSection.links.rawValue
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
            case .linksHeader:
                return 3
            case .linksCreate:
                return 4
            case let .links(index, _, _):
                return 5 + index
            case .linksInfo:
                return 10000
            case .revokedLinksHeader:
                return 10001
            case .revokedLinksDeleteAll:
                return 10002
            case let .revokedLinks(index, _, _):
                return 10003 + index
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
            case let .mainLink(lhsTheme, lhsInvite, lhsPeers):
                if case let .mainLink(rhsTheme, rhsInvite, rhsPeers) = rhs, lhsTheme === rhsTheme, lhsInvite == rhsInvite, arePeerArraysEqual(lhsPeers, rhsPeers) {
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
            case let .links(lhsIndex, lhsTheme, lhsLinks):
                if case let .links(rhsIndex, rhsTheme, rhsLinks) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsLinks == rhsLinks {
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
            case let .mainLink(_, invite, peers):
                return ItemListPermanentInviteLinkItem(context: arguments.context, presentationData: presentationData, invite: invite, peers: peers, buttonColor: nil, sectionId: self.section, style: .blocks, shareAction: {
                    arguments.shareMainLink(invite)
                }, contextAction: { node in
                    arguments.mainLinkContextAction(invite, node, nil)
                }, viewAction: {
                    if let invite = invite {
                        arguments.openLink(invite)
                    }
                })
            case let .linksHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .linksCreate(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(theme), title: text, hasSeparator: false, sectionId: self.section, editing: false, action: {
                    arguments.createLink()
                })
            case let .links(_, _, invites):
                return ItemListInviteLinkGridItem(presentationData: presentationData, invites: invites, sectionId: self.section, style: .blocks, tapAction: { invite in
                    arguments.openLink(invite)
                }, contextAction: { invite, node in
                    arguments.linkContextAction(invite, node, nil)
                })
            case let .linksInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .revokedLinksHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .revokedLinksDeleteAll(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.deleteIconImage(theme), title: text, hasSeparator: false, sectionId: self.section, color: .destructive, editing: false, action: {
                    arguments.deleteAllRevokedLinks()
                })
            case let .revokedLinks(_, _, invites):
                return ItemListInviteLinkGridItem(presentationData: presentationData, invites: invites, sectionId: self.section, style: .blocks, tapAction: { invite in
                    arguments.openLink(invite)
                }, contextAction: { invite, node in
                    arguments.linkContextAction(invite, node, nil)
                })
        }
    }
}

private func inviteLinkListControllerEntries(presentationData: PresentationData, view: PeerView, invites: [ExportedInvitation]?, revokedInvites: [ExportedInvitation]?, mainPeers: [Peer]) -> [InviteLinksListEntry] {
    var entries: [InviteLinksListEntry] = []
    
    entries.append(.header(presentationData.theme, presentationData.strings.InviteLink_CreatePrivateLinkHelp))
    entries.append(.mainLinkHeader(presentationData.theme, presentationData.strings.InviteLink_PermanentLink.uppercased()))
        
    let mainInvite: ExportedInvitation?
    if let invites = invites, let invite = invites.first(where: { $0.isPermanent && !$0.isRevoked }) {
        mainInvite = invite
    } else if let invite = (view.cachedData as? CachedChannelData)?.exportedInvitation {
        mainInvite = invite
    } else if let invite = (view.cachedData as? CachedGroupData)?.exportedInvitation {
        mainInvite = invite
    } else {
        mainInvite = nil
    }
    entries.append(.mainLink(presentationData.theme, mainInvite, mainPeers))
    
    entries.append(.linksHeader(presentationData.theme, presentationData.strings.InviteLink_AdditionalLinks.uppercased()))
    entries.append(.linksCreate(presentationData.theme, presentationData.strings.InviteLink_Create))
    
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
            entries.append(.links(index, presentationData.theme, invitesPair))
            index += 1
        }
    }
    entries.append(.linksInfo(presentationData.theme, presentationData.strings.InviteLink_CreateInfo))
    
    if let revokedInvites = revokedInvites, !revokedInvites.isEmpty {
        entries.append(.revokedLinksHeader(presentationData.theme, presentationData.strings.InviteLink_RevokedLinks.uppercased()))
        entries.append(.revokedLinksDeleteAll(presentationData.theme, presentationData.strings.InviteLink_DeleteAllRevokedLinks))
        
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


public func inviteLinkListController(context: AccountContext, peerId: PeerId) -> ViewController {
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
    
    actionsDisposable.add((context.account.viewTracker.peerView(peerId) |> filter { $0.cachedData != nil } |> take(1) |> mapToSignal { view -> Signal<String?, NoError> in
        return ensuredExistingPeerExportedInvitation(account: context.account, peerId: peerId)
        |> mapToSignal { _ -> Signal<String?, NoError> in
            return .complete()
        }
    }).start())
    
    var getControllerImpl: (() -> ViewController?)?
    
    let invitesPromise = Promise<ExportedInvitations?>()
    invitesPromise.set(.single(nil)
    |> then(peerExportedInvitations(account: context.account, peerId: peerId, revoked: false)))
    
    let revokedInvitesPromise = Promise<ExportedInvitations?>()
    revokedInvitesPromise.set(.single(nil)
    |> then(peerExportedInvitations(account: context.account, peerId: peerId, revoked: true)))
    
    let arguments = InviteLinkListControllerArguments(context: context, shareMainLink: { invite in
        if let invite = invite {
            let shareController = ShareController(context: context, subject: .url(invite.link))
            presentControllerImpl?(shareController, nil)
        }
    }, openMainLink: { invite in
        if let invite = invite {
            let controller = InviteLinkViewController(context: context, peerId: peerId, invite: invite, importersContext: nil)
            pushControllerImpl?(controller)
        }
    }, mainLinkContextAction: { invite, node, gesture in
        guard let node = node as? ContextExtractedContentContainingNode, let controller = getControllerImpl?() else {
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
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.Username_LinkCopied, false)), nil)
            }
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Wallet/QrIcon"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.dismissWithoutContent)
            
            if let invite = invite {
                let controller = InviteLinkQRCodeController(context: context, invite: invite)
                presentControllerImpl?(controller, nil)
            }
        })))
        
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
                            revokeLinkDisposable.set((ensuredExistingPeerExportedInvitation(account: context.account, peerId: peerId, revokeExisted: true) |> deliverOnMainQueue).start(completed: {
                                updateState { state in
                                    var updatedState = state
                                    updatedState.revokingPrivateLink = false
                                    return updatedState
                                }
                                invitesPromise.set(peerExportedInvitations(account: context.account, peerId: peerId, revoked: false))
                            }))
                        }
                    })
                ]),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })))

        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .extracted(InviteLinkContextExtractedContentSource(controller: controller, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
        presentInGlobalOverlayImpl?(contextController)
    }, createLink: {
        let controller = inviteLinkEditController(context: context, peerId: peerId, invite: nil, completion: {
            invitesPromise.set(peerExportedInvitations(account: context.account, peerId: peerId, revoked: false))
        })
        controller.navigationPresentation = .modal
        pushControllerImpl?(controller)
    }, openLink: { invite in
        if let invite = invite {
            let controller = InviteLinkViewController(context: context, peerId: peerId, invite: invite, importersContext: nil)
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
            presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.Username_LinkCopied, false)), nil)
        })))
        
        if !invite.isRevoked {
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
            
                let controller = inviteLinkEditController(context: context, peerId: peerId, invite: invite, completion: {
                    invitesPromise.set(peerExportedInvitations(account: context.account, peerId: peerId, revoked: false))
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
                        ActionSheetTextItem(title: presentationData.strings.GroupInfo_InviteLink_RevokeAlert_Text),
                        ActionSheetButtonItem(title: presentationData.strings.GroupInfo_InviteLink_RevokeLink, color: .destructive, action: {
                            dismissAction()
                            
                            revokeLinkDisposable.set((revokePeerExportedInvitation(account: context.account, peerId: peerId, link: invite.link) |> deliverOnMainQueue).start(completed: {

                            }))
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
                        })
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })))
        }

        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .extracted(InviteLinkContextExtractedContentSource(controller: controller, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
        presentInGlobalOverlayImpl?(contextController)
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
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    })
        
    let peerView = context.account.viewTracker.peerView(peerId)
    |> deliverOnMainQueue
    
    let importersState = Promise<PeerInvitationImportersState?>(nil)
    let importersContext: Signal<PeerInvitationImportersContext, NoError> = peerView
    |> mapToSignal { view -> Signal<ExportedInvitation, NoError> in
        if let cachedData = view.cachedData as? CachedGroupData, let exportedInvitation = cachedData.exportedInvitation {
            return .single(exportedInvitation)
        } else if let cachedData = view.cachedData as? CachedChannelData, let exportedInvitation = cachedData.exportedInvitation {
            return .single(exportedInvitation)
        } else {
            return .complete()
        }
    }
    |> distinctUntilChanged
    |> deliverOnMainQueue
    |> map { invite -> PeerInvitationImportersContext in
        return PeerInvitationImportersContext(account: context.account, peerId: peerId, invite: invite)
    } |> afterNext { context in
        importersState.set(context.state |> map(Optional.init))
    }
    
    let signal = combineLatest(context.sharedContext.presentationData, peerView, importersContext, importersState.get(), invitesPromise.get(), revokedInvitesPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, view, importersContext, importers, invites, revokedInvites -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.InviteLink_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: inviteLinkListControllerEntries(presentationData: presentationData, view: view, invites: invites?.list, revokedInvites: revokedInvites?.list, mainPeers: importers?.importers.compactMap { $0.peer.peer } ?? []), style: .blocks, emptyStateItem: nil, crossfadeState: false, animateChanges: false)
        
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
