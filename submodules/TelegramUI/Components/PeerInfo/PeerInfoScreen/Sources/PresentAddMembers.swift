import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import SwiftSignalKit
import Postbox
import TelegramCore
import InviteLinksUI
import SendInviteLinkScreen
import UndoUI
import PresentationDataUtils

public func presentAddMembersImpl(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, parentController: ViewController, groupPeer: Peer, selectAddMemberDisposable: MetaDisposable, addMemberDisposable: MetaDisposable) {
    let members: Promise<[PeerId]> = Promise()
    if groupPeer.id.namespace == Namespaces.Peer.CloudChannel {
        /*var membersDisposable: Disposable?
        let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { listState in
            members.set(.single(listState.list.map {$0.peer.id}))
            membersDisposable?.dispose()
        })
        membersDisposable = disposable*/
        members.set(.single([]))
    } else {
        members.set(.single([]))
    }
    
    let _ = (members.get()
    |> take(1)
    |> deliverOnMainQueue).startStandalone(next: { [weak parentController] recentIds in
        var createInviteLinkImpl: (() -> Void)?
        var confirmationImpl: ((PeerId) -> Signal<Bool, NoError>)?
        let _ = confirmationImpl
        var options: [ContactListAdditionalOption] = []
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        var canCreateInviteLink = false
        if let group = groupPeer as? TelegramGroup {
            switch group.role {
            case .creator:
                canCreateInviteLink = true
            case let .admin(rights, _):
                canCreateInviteLink = rights.rights.contains(.canInviteUsers)
            default:
                break
            }
        } else if let channel = groupPeer as? TelegramChannel, (channel.addressName?.isEmpty ?? true) {
            if channel.flags.contains(.isCreator) || (channel.adminRights?.rights.contains(.canInviteUsers) == true) {
                canCreateInviteLink = true
            }
        }
        
        if canCreateInviteLink {
            options.append(ContactListAdditionalOption(title: presentationData.strings.GroupInfo_InviteByLink, icon: .generic(UIImage(bundleImageName: "Contact List/LinkActionIcon")!), action: {
                createInviteLinkImpl?()
            }, clearHighlightAutomatically: true))
        }
        
        let contactsController = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, updatedPresentationData: updatedPresentationData, mode: .peerSelection(searchChatList: false, searchGroups: false, searchChannels: false), options: .single(options), filters: [.excludeSelf, .disable(recentIds)], onlyWriteable: true, isGroupInvitation: true))
            contactsController.navigationPresentation = .modal
        
        confirmationImpl = { [weak contactsController] peerId in
            return context.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue
            |> mapToSignal { peer in
                let result = ValuePromise<Bool>()
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                if let contactsController = contactsController {
                    let alertController = textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.GroupInfo_AddParticipantConfirmation(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string, actions: [
                        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_No, action: {
                            result.set(false)
                        }),
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
                            result.set(true)
                        })
                    ])
                    contactsController.present(alertController, in: .window(.root))
                }
                
                return result.get()
            }
        }
        
        let addMembers: ([ContactListPeerId]) -> Signal<[(PeerId, AddChannelMemberError)], NoError> = { members -> Signal<[(PeerId, AddChannelMemberError)], NoError> in
            let memberIds = members.compactMap { contact -> PeerId? in
                switch contact {
                case let .peer(peerId):
                    return peerId
                default:
                    return nil
                }
            }
            return context.account.postbox.multiplePeersView(memberIds)
            |> take(1)
            |> deliverOnMainQueue
            |> mapToSignal { view -> Signal<[(PeerId, AddChannelMemberError)], NoError> in
                if groupPeer.id.namespace == Namespaces.Peer.CloudChannel {
                    if memberIds.count == 1 {
                        return context.peerChannelMemberCategoriesContextsManager.addMember(engine: context.engine, peerId: groupPeer.id, memberId: memberIds[0])
                        |> map { _ -> [(PeerId, AddChannelMemberError)] in
                        }
                        |> then(Signal<[(PeerId, AddChannelMemberError)], AddChannelMemberError>.single([]))
                        |> `catch` { error -> Signal<[(PeerId, AddChannelMemberError)], NoError> in
                            return .single([(memberIds[0], error)])
                        }
                    } else {
                        return context.peerChannelMemberCategoriesContextsManager.addMembersAllowPartial(engine: context.engine, peerId: groupPeer.id, memberIds: memberIds)
                    }
                } else {
                    var signals: [Signal<(PeerId, AddChannelMemberError)?, NoError>] = []
                    for memberId in memberIds {
                        let signal: Signal<(PeerId, AddChannelMemberError)?, NoError> = context.engine.peers.addGroupMember(peerId: groupPeer.id, memberId: memberId)
                        |> mapError { error -> AddChannelMemberError in
                            switch error {
                            case .generic:
                                return .generic
                            case .groupFull:
                                return .limitExceeded
                            case let .privacy(privacy):
                                return .restricted(privacy?.forbiddenPeers.first)
                            case .notMutualContact:
                                return .notMutualContact
                            case .tooManyChannels:
                                return .generic
                            }
                        }
                        |> ignoreValues
                        |> map { _ -> (PeerId, AddChannelMemberError)? in
                        }
                        |> then(Signal<(PeerId, AddChannelMemberError)?, AddChannelMemberError>.single(nil))
                        |> `catch` { error -> Signal<(PeerId, AddChannelMemberError)?, NoError> in
                            return .single((memberId, error))
                        }
                        signals.append(signal)
                    }
                    return combineLatest(signals)
                    |> map { values -> [(PeerId, AddChannelMemberError)] in
                        return values.compactMap { $0 }
                    }
                }
            }
        }
        
        createInviteLinkImpl = { [weak contactsController] in
            contactsController?.view.window?.endEditing(true)
            contactsController?.present(InviteLinkInviteController(context: context, updatedPresentationData: updatedPresentationData, mode: .groupOrChannel(peerId: groupPeer.id), initialInvite: nil, parentNavigationController: contactsController?.navigationController as? NavigationController), in: .window(.root))
        }

        parentController?.push(contactsController)
        do {
            selectAddMemberDisposable.set((
                combineLatest(queue: .mainQueue(),
                    context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ExportedInvitation(id: groupPeer.id)),
                    contactsController.result
                )
            |> deliverOnMainQueue).start(next: { [weak contactsController] exportedInvitation, result in
                var peers: [ContactListPeerId] = []
                if case let .result(peerIdsValue, _) = result {
                    peers = peerIdsValue
                }
                
                contactsController?.displayProgress = true
                addMemberDisposable.set((addMembers(peers)
                |> deliverOnMainQueue).start(next: { failedPeerIds in
                    if failedPeerIds.isEmpty {
                        contactsController?.dismiss()
                        
                        let mappedPeerIds: [EnginePeer.Id] = peers.compactMap { peer -> EnginePeer.Id? in
                            switch peer {
                            case let .peer(id):
                                return id
                            default:
                                return nil
                            }
                        }
                        if !mappedPeerIds.isEmpty {
                            let _ = (context.engine.data.get(EngineDataMap(mappedPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
                            |> deliverOnMainQueue).startStandalone(next: { maybePeers in
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                let peers = maybePeers.compactMap { $0.value }
                                
                                let text: String
                                if peers.count == 1 {
                                    text = presentationData.strings.PeerInfo_NotificationMemberAdded(peers[0].displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                } else {
                                    text = presentationData.strings.PeerInfo_NotificationMultipleMembersAdded(Int32(peers.count))
                                }
                                parentController?.present(UndoOverlayController(presentationData: presentationData, content: .peers(context: context, peers: peers, title: nil, text: text, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                            })
                        }
                    } else {
                        let failedPeers = failedPeerIds.compactMap { _, error -> TelegramForbiddenInvitePeer? in
                            if case let .restricted(peer) = error {
                                return peer
                            } else {
                                return nil
                            }
                        }
                        
                        if !failedPeers.isEmpty, let contactsController, let navigationController = contactsController.navigationController as? NavigationController {
                            var viewControllers = navigationController.viewControllers
                            if let index = viewControllers.firstIndex(where: { $0 === contactsController }) {
                                let inviteScreen = SendInviteLinkScreen(context: context, subject: .chat(peer: EnginePeer(groupPeer), link: exportedInvitation?.link), peers: failedPeers)
                                viewControllers.remove(at: index)
                                viewControllers.append(inviteScreen)
                                navigationController.setViewControllers(viewControllers, animated: true)
                            }
                        } else {
                            contactsController?.dismiss()
                        }
                    }
                }))
            }))
            contactsController.dismissed = {
                selectAddMemberDisposable.set(nil)
                addMemberDisposable.set(nil)
            }
        }
    })
}
