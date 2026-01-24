import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore

extension PeerInfoScreenNode {
    func openChatWithMessageSearch() {
        if let navigationController = (self.controller?.navigationController as? NavigationController) {
            if case let .replyThread(currentMessage) = self.chatLocation, let current = navigationController.viewControllers.first(where: { controller in
                if let controller = controller as? ChatController, case let .replyThread(message) = controller.chatLocation, message.peerId == currentMessage.peerId, message.threadId == currentMessage.threadId {
                    return true
                }
                return false
            }) as? ChatController {
                var viewControllers = navigationController.viewControllers
                if let index = viewControllers.firstIndex(of: current) {
                    viewControllers.removeSubrange(index + 1 ..< viewControllers.count)
                }
                navigationController.setViewControllers(viewControllers, animated: true)
                current.activateSearch(domain: .everything, query: "")
            } else if let peer = self.data?.chatPeer {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: self.nearbyPeerDistance != nil ? .always : .default, activateMessageSearch: (.everything, ""), peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), completion: { [weak self] _ in
                    if let strongSelf = self, strongSelf.nearbyPeerDistance != nil {
                        var viewControllers = navigationController.viewControllers
                        viewControllers = viewControllers.filter { controller in
                            if controller is PeerInfoScreen {
                                return false
                            }
                            return true
                        }
                        navigationController.setViewControllers(viewControllers, animated: false)
                    }
                }))
            }
        }
    }
    
    func openChatForReporting(title: String, option: Data, message: String?) {
        if let peer = self.data?.peer, let navigationController = (self.controller?.navigationController as? NavigationController) {
            if let channel = peer as? TelegramChannel, channel.isForumOrMonoForum {
                //let _ = self.context.engine.peers.reportPeer(peerId: peer.id, reason: reason, message: "").startStandalone()
                //self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .emoji(name: "PoliceCar", text: self.presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
            } else {
                self.context.sharedContext.navigateToChatController(
                    NavigateToChatControllerParams(
                        navigationController: navigationController,
                        context: self.context,
                        chatLocation: .peer(EnginePeer(peer)),
                        keepStack: .default,
                        reportReason: NavigateToChatControllerParams.ReportReason(title: title, option: option, message: message),
                        completion: { _ in
                        }
                    )
                )
            }
        }
    }
    
    func openChatForThemeChange() {
        if let peer = self.data?.peer, let navigationController = (self.controller?.navigationController as? NavigationController) {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: .default, changeColors: true, completion: { _ in
            }))
        }
    }
    
    func openChatForTranslation() {
        if let peer = self.data?.peer, let navigationController = (self.controller?.navigationController as? NavigationController) {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: .default, changeColors: false, completion: { _ in
            }))
        }
    }

    func openChat(peerId: EnginePeer.Id?) {
        if let peerId {
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                guard let navigationController = self.controller?.navigationController as? NavigationController else {
                    return
                }
                
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), keepStack: .always))
            })
            return
        }
        
        if let peer = self.data?.peer, let navigationController = self.controller?.navigationController as? NavigationController {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: self.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), completion: { [weak self] _ in
                if let strongSelf = self, strongSelf.nearbyPeerDistance != nil {
                    var viewControllers = navigationController.viewControllers
                    viewControllers = viewControllers.filter { controller in
                        if controller is PeerInfoScreen {
                            return false
                        }
                        return true
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }
            }))
        }
    }
    
    func openChatWithClearedHistory(type: InteractiveHistoryClearingType) {
        guard let peer = self.data?.chatPeer, let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: self.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), setupController: { controller in
            controller.beginClearHistory(type: type)
        }, completion: { [weak self] _ in
            if let strongSelf = self, strongSelf.nearbyPeerDistance != nil {
                var viewControllers = navigationController.viewControllers
                viewControllers = viewControllers.filter { controller in
                    if controller is PeerInfoScreen {
                        return false
                    }
                    return true
                }
                
                navigationController.setViewControllers(viewControllers, animated: false)
            }
        }))
    }

    func openChannelMessages() {
        guard let channel = self.data?.peer as? TelegramChannel, let linkedMonoforumId = channel.linkedMonoforumId else {
            return
        }
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: linkedMonoforumId)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let self, let peer else {
                return
            }
            if let controller = self.controller, let navigationController = controller.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
            }
        })
    }

    func openRecentActions() {
        guard let peer = self.data?.peer else {
            return
        }
        let controller = self.context.sharedContext.makeChatRecentActionsController(context: self.context, peer: peer, adminPeerId: nil, starsState: self.data?.starsRevenueStatsState)
        self.controller?.push(controller)
    }
}
