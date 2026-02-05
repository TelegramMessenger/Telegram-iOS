import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import AlertComponent
import AlertTransferHeaderComponent
import AvatarComponent
import PeerInfoUI
import OwnershipTransferController

extension ChatListControllerImpl {
    func presentLeaveChannelConfirmation(peer: EnginePeer, nextCreator: EnginePeer, completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let accountPeer = await (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))).get()
            
            guard let accountPeer else {
                completion(false)
                return
            }
            
            var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
            content.append(AnyComponentWithIdentity(
                id: "header",
                component: AnyComponent(
                    AlertTransferHeaderComponent(
                        fromComponent: AnyComponentWithIdentity(id: "account", component: AnyComponent(
                            AvatarComponent(
                                context: self.context,
                                theme: self.presentationData.theme,
                                peer: accountPeer
                            )
                        )),
                        toComponent: AnyComponentWithIdentity(id: "user", component: AnyComponent(
                            AvatarComponent(
                                context: self.context,
                                theme: self.presentationData.theme,
                                peer: nextCreator,
                                icon: AnyComponent(
                                    AvatarComponent(
                                        context: self.context,
                                        theme: self.presentationData.theme,
                                        peer: peer
                                    )
                                )
                            )
                        )),
                        type: .transfer
                    )
                )
            ))
            content.append(AnyComponentWithIdentity(
                id: "title",
                component: AnyComponent(
                    AlertTitleComponent(title: self.presentationData.strings.LeaveGroup_Title(peer.compactDisplayTitle).string)
                )
            ))
            content.append(AnyComponentWithIdentity(
                id: "text",
                component: AnyComponent(
                    AlertTextComponent(content: .plain(self.presentationData.strings.LeaveGroup_Text(nextCreator.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), peer.compactDisplayTitle).string))
                )
            ))
            
            let alertController = AlertScreen(
                context: self.context,
                configuration: .init(actionAlignment: .vertical),
                content: content,
                actions: [
                    .init(title: self.presentationData.strings.LeaveGroup_AppointAnotherOwner, action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.presentOwnershipTransfer(chatPeer: peer, leaveGroup: {
                            completion(true)
                        })
                    }),
                    .init(title: self.presentationData.strings.Common_Cancel, action: {
                        completion(false)
                    }),
                    .init(title: self.presentationData.strings.LeaveGroup_Proceed, type: .destructive, action: {
                        completion(true)
                    })
                ]
            )
            if let topController = self.navigationController?.topViewController as? ViewController {
                topController.present(alertController, in: .window(.root))
            }
        }
    }
    
    func presentOwnershipTransfer(chatPeer: EnginePeer, leaveGroup: @escaping () -> Void) {
        let presentController: (ViewController) -> Void = { [weak self] c in
            if let topController = self?.navigationController?.topViewController as? ViewController {
                topController.present(c, in: .window(.root))
            }
        }
        let pushController: (ViewController) -> Void = { [weak self] c in
            if let topController = self?.navigationController?.topViewController as? ViewController {
                topController.push(c)
            }
        }
        
        var dismissController: (() -> Void)?
        let controller = ChannelMembersSearchControllerImpl(
            params: ChannelMembersSearchControllerParams(
                context: self.context,
                peerId: chatPeer.id,
                mode: .ownershipTransfer,
                filters: [.exclude([self.context.account.peerId])],
                openPeer: { [weak self] peer, participant in
                    guard let self else {
                        return
                    }
                    if peer.id == self.context.account.peerId {
                        return
                    }
                    if let participant {
                        switch participant.participant {
                        case .creator:
                            return
                        case let .member(_, _, adminInfo, _, _, _):
                            if adminInfo == nil {
                                let _ = self.context.engine.peers.updateChannelAdminRights(peerId: chatPeer.id, adminId: peer.id, rights: TelegramChatAdminRights(rights: .all), rank: nil).start()
                            }
                            
                            let _ = (self.context.engine.peers.checkOwnershipTranfserAvailability(memberId: peer.id) |> deliverOnMainQueue).start(error: { [weak self] error in
                                guard let self, case let .user(user) = peer else {
                                    return
                                }
                                let controller = channelOwnershipTransferController(
                                    context: self.context,
                                    updatedPresentationData: nil,
                                    peer: chatPeer,
                                    member: user,
                                    onLeave: true,
                                    initialError: error,
                                    present: { c, a in
                                        presentController(c)
                                    },
                                    push: { c in
                                        pushController(c)
                                    },
                                    completion: { _ in
                                        dismissController?()
                                        
                                        leaveGroup()
                                    }
                                )
                                presentController(controller)
                            })
                        }
                    }
                })
        )
        dismissController = { [weak controller] in
            controller?.dismiss()
        }
        pushController(controller)
    }
}
