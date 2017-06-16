import Foundation
import Display
import TelegramLegacyComponents
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
    
    let controller = TGLocationViewController(locationAttachment: legacyLocation, peer: legacyPeer)!
    let navigationController = TGNavigationController(controllers: [controller])!
    let legacyController = LegacyController(legacyController: navigationController, presentation: .modal(animateIn: true))
    controller.customDismiss = { [weak legacyController] in
        legacyController?.dismiss()
    }
    controller.customActions = { [weak legacyController] in
        if let legacyController = legacyController {
            var shareAction: (([PeerId]) -> Void)?
            let shareController = ShareController(account: account, shareAction: { peerIds in
                shareAction?(peerIds)
            }, defaultAction: nil)
            legacyController.present(shareController, in: .window)
            shareAction = { [weak shareController] peerIds in
                shareController?.dismiss()
                
                for peerId in peerIds {
                    let _ = enqueueMessages(account: account, peerId: peerId, messages: [.forward(source: message.id)]).start()
                }
            }
        }
    }
    controller.calloutPressed = { [weak legacyController] in
        legacyController?.dismiss()
        
        if let author = message.author {
            openPeer(author)
        }
    }
    return legacyController
}
