import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TextFormat
import OverlayStatusController
import TelegramStringFormatting
import AccountContext
import ShareController
import AlertUI
import PresentationDataUtils
import TelegramNotices
import GalleryUI
import ItemListAvatarAndNameInfoItem
import PeerAvatarGalleryUI
import NotificationMuteSettingsUI
import NotificationSoundSelectionUI
import Markdown
import LocalizedPeerData
import PhoneNumberFormat
import TelegramIntents

private func getUserPeer(postbox: Postbox, peerId: PeerId) -> Signal<(Peer?, CachedPeerData?), NoError> {
    return postbox.transaction { transaction -> (Peer?, CachedPeerData?) in
        guard let peer = transaction.getPeer(peerId) else {
            return (nil, nil)
        }
        var resultPeer: Peer?
        if let peer = peer as? TelegramSecretChat {
            resultPeer = transaction.getPeer(peer.regularPeerId)
        } else {
            resultPeer = peer
        }
        return (resultPeer, resultPeer.flatMap({ transaction.getPeerCachedData(peerId: $0.id) }))
    }
}

public func openAddPersonContactImpl(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, pushController: @escaping (ViewController) -> Void, present: @escaping (ViewController, Any?) -> Void) {
    let _ = (getUserPeer(postbox: context.account.postbox, peerId: peerId)
    |> deliverOnMainQueue).start(next: { peer, cachedData in
        guard let user = peer as? TelegramUser, let contactData = DeviceContactExtendedData(peer: user) else {
            return
        }
        
        var shareViaException = false
        if let cachedData = cachedData as? CachedUserData, let peerStatusSettings = cachedData.peerStatusSettings {
            shareViaException = peerStatusSettings.contains(.addExceptionWhenAddingContact)
        }
        
        pushController(deviceContactInfoController(context: context, updatedPresentationData: updatedPresentationData, subject: .create(peer: user, contactData: contactData, isSharing: true, shareViaException: shareViaException, completion: { peer, stableId, contactData in
            if let peer = peer as? TelegramUser {
                if let phone = peer.phone, !phone.isEmpty {
                }
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                present(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.AddContact_StatusSuccess(EnginePeer(peer).compactDisplayTitle).string, true)), nil)
            }
        }), completed: nil, cancelled: nil))
    })
}
