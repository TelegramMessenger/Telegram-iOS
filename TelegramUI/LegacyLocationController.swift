import Foundation
import Display
import LegacyComponents
import TelegramCore
import Postbox

func legacyLocationController(message: Message, mapMedia: TelegramMediaMap, account: Account, openPeer: @escaping (Peer) -> Void) -> ViewController {
    var legacyPeer: AnyObject?
    if let user = message.author as? TelegramUser {
        let legacyUser = TGUser()
        legacyUser.uid = user.id.id
        legacyUser.firstName = user.firstName
        legacyUser.lastName = user.lastName
        legacyPeer = legacyUser
    } else if let channel = message.author as? TelegramChannel {
        let legacyConversation = TGConversation()
        legacyConversation.conversationId = Int64(channel.id.id)
        legacyConversation.chatTitle = channel.title
        legacyPeer = legacyConversation
    }
    let legacyLocation = TGLocationMediaAttachment()
    legacyLocation.latitude = mapMedia.latitude
    legacyLocation.longitude = mapMedia.longitude
    if let venue = mapMedia.venue {
        legacyLocation.venue = TGVenueAttachment(title: venue.title, address: venue.address, provider: venue.provider, venueId: venue.id)
    }
    
    let legacyController = LegacyController(presentation: .modal(animateIn: true))
    let controller = TGLocationViewController(context: legacyController.context, locationAttachment: legacyLocation, peer: legacyPeer)!
    controller.modalMode = true
    let navigationController = TGNavigationController(controllers: [controller])!
    legacyController.bind(controller: navigationController)
    controller.navigation_setDismiss({ [weak legacyController] in
        legacyController?.dismiss()
    }, rootController: nil)
    /*controller.shareAction = { [weak legacyController]  in
        if let legacyController = legacyController {
            var shareAction: (([PeerId]) -> Void)?
            let shareController = ShareController(account: account, shareAction: { peerIds in
                shareAction?(peerIds)
            }, defaultAction: nil)
            legacyController.present(shareController, in: .window(.root))
            shareAction = { [weak shareController] peerIds in
                shareController?.dismiss()
                
                for peerId in peerIds {
                    let _ = enqueueMessages(account: account, peerId: peerId, messages: [.forward(source: message.id)]).start()
                }
            }
        }
    }*/
    controller.calloutPressed = { [weak legacyController] in
        legacyController?.dismiss()
        
        if let author = message.author {
            openPeer(author)
        }
    }
    return legacyController
}
