import Foundation
import UIKit
import Intents
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import AvatarNode
import AccountContext

public func donateSendMessageIntent(account: Account, sharedContext: SharedAccountContext, peerIds: [PeerId]) {
    if #available(iOSApplicationExtension 13.2, iOS 13.2, *) {
        let _ = (account.postbox.transaction { transaction -> [Peer] in
            var peers: [Peer] = []
            for peerId in peerIds {
                if peerId.namespace == Namespaces.Peer.CloudUser && peerId != account.peerId, let peer = transaction.getPeer(peerId) {
                    peers.append(peer)
                }
            }
            return peers
        }
        |> mapToSignal { peers -> Signal<[(Peer, UIImage?)], NoError> in
            var signals: [Signal<(Peer, UIImage?), NoError>] = []
            for peer in peers {
                let peerAndAvatar = (peerAvatarImage(account: account, peer: peer, authorOfMessage: nil, representation: peer.smallProfileImage, round: false) ?? .single(nil))
                |> map { avatarImage in
                    return (peer, avatarImage)
                }
                signals.append(peerAndAvatar)
            }
            return combineLatest(signals)
        }
        |> deliverOnMainQueue).start(next: { peers in
            for (peer, avatarImage) in peers {
                guard let peer = peer as? TelegramUser, peer.botInfo == nil && !peer.flags.contains(.isSupport) else {
                    continue
                }
                let presentationData = sharedContext.currentPresentationData.with { $0 }
                
                let recipientHandle = INPersonHandle(value: "tg\(peer.id.id)", type: .unknown)
                var nameComponents = PersonNameComponents()
                nameComponents.givenName = peer.firstName
                nameComponents.familyName = peer.lastName
                
                let displayTitle = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                let recipient = INPerson(personHandle: recipientHandle, nameComponents: nameComponents, displayName: displayTitle, image: nil, contactIdentifier: nil, customIdentifier: "tg\(peer.id.id)")
               
                let intent = INSendMessageIntent(recipients: [recipient], content: nil, speakableGroupName: INSpeakableString(spokenPhrase: displayTitle), conversationIdentifier: "tg\(peer.id.id)", serviceName: nil, sender: nil)
                if let avatarImage = avatarImage, let avatarImageData = avatarImage.jpegData(compressionQuality: 0.8) {
                    intent.setImage(INImage(imageData: avatarImageData), forParameterNamed: \.groupName)
                }
                let interaction = INInteraction(intent: intent, response: nil)
                interaction.direction = .outgoing
                interaction.groupIdentifier = "sendMessage_\(account.peerId.toInt64())"
                interaction.donate()
            }
        })
    }
}

public func deleteAllSendMessageIntents(accountPeerId: PeerId) {
    if #available(iOS 10.0, *) {
        INInteraction.delete(with: "sendMessage_\(accountPeerId.toInt64())")
    }
}
