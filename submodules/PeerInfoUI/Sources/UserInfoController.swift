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

private func getUserPeer(engine: TelegramEngine, peerId: EnginePeer.Id) -> Signal<(EnginePeer?, EnginePeer.StatusSettings?), NoError> {
    return engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    |> mapToSignal { peer -> Signal<EnginePeer?, NoError> in
        if case let .secretChat(secretChat) = peer {
            return engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: secretChat.regularPeerId))
        } else {
            return .single(peer)
        }
    }
    |> mapToSignal { peer -> Signal<(EnginePeer?, EnginePeer.StatusSettings?), NoError> in
        guard let peer = peer else {
            return .single((nil, nil))
        }
        return engine.data.get(TelegramEngine.EngineData.Item.Peer.StatusSettings(id: peer.id))
        |> map { statusSettings -> (EnginePeer?, EnginePeer.StatusSettings?) in
            return (peer, statusSettings)
        }
    }
}

public func openAddPersonContactImpl(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, pushController: @escaping (ViewController) -> Void, present: @escaping (ViewController, Any?) -> Void) {
    let _ = (getUserPeer(engine: context.engine, peerId: peerId)
    |> deliverOnMainQueue).start(next: { peer, statusSettings in
        guard case let .user(user) = peer, let contactData = DeviceContactExtendedData(peer: user) else {
            return
        }
        
        var shareViaException = false
        if let statusSettings = statusSettings {
            shareViaException = statusSettings.contains(.addExceptionWhenAddingContact)
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
