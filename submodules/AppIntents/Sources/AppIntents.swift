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

private let savedMessagesAvatar: UIImage = {
    return generateImage(CGSize(width: 60.0, height: 60.0)) { size, context in
        var locations: [CGFloat] = [1.0, 0.0]
               
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: [UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor] as CFArray, locations: &locations)!
               
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
        let factor = size.width / 60.0
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: factor, y: -factor)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        
        if let savedMessagesIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/SavedMessagesIcon"), color: .white) {
            context.draw(savedMessagesIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((size.width - savedMessagesIcon.size.width) / 2.0), y: floor((size.height - savedMessagesIcon.size.height) / 2.0)), size: savedMessagesIcon.size))
        }
    }!
}()

public func donateSendMessageIntent(account: Account, sharedContext: SharedAccountContext, peerIds: [PeerId]) {
    if #available(iOSApplicationExtension 13.2, iOS 13.2, *) {
        let _ = (account.postbox.transaction { transaction -> [Peer] in
            var peers: [Peer] = []
            for peerId in peerIds {
                if peerId.namespace != Namespaces.Peer.SecretChat, let peer = transaction.getPeer(peerId) {
                    peers.append(peer)
                }
            }
            return peers
        }
        |> mapToSignal { peers -> Signal<[(Peer, UIImage?)], NoError> in
            var signals: [Signal<(Peer, UIImage?), NoError>] = []
            for peer in peers {
                if peer.id == account.peerId {
                    signals.append(.single((peer, savedMessagesAvatar)))
                } else {
                    let peerAndAvatar = (peerAvatarImage(account: account, peer: peer, authorOfMessage: nil, representation: peer.smallProfileImage, round: false) ?? .single(nil))
                    |> map { avatarImage in
                        return (peer, avatarImage)
                    }
                    signals.append(peerAndAvatar)
                }
            }
            return combineLatest(signals)
        }
        |> deliverOnMainQueue).start(next: { peers in
            let presentationData = sharedContext.currentPresentationData.with { $0 }
            
            for (peer, avatarImage) in peers {
                let recipientHandle = INPersonHandle(value: "tg\(peer.id.id)", type: .unknown)
                let displayTitle: String
                var nameComponents = PersonNameComponents()
                
                if let peer = peer as? TelegramUser {
                    if peer.botInfo != nil || peer.flags.contains(.isSupport) {
                        continue
                    }
                    
                    if peer.id == account.peerId {
                        displayTitle = presentationData.strings.DialogList_SavedMessages
                        nameComponents.givenName = displayTitle
                    } else {
                        displayTitle = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        nameComponents.givenName = peer.firstName
                        nameComponents.familyName = peer.lastName
                    }
                } else {
                    displayTitle = peer.compactDisplayTitle
                    nameComponents.givenName = displayTitle
                }
                
                let recipient = INPerson(personHandle: recipientHandle, nameComponents: nameComponents, displayName: displayTitle, image: nil, contactIdentifier: nil, customIdentifier: "tg\(peer.id.id)")
               
                let intent = INSendMessageIntent(recipients: [recipient], content: nil, speakableGroupName: INSpeakableString(spokenPhrase: displayTitle), conversationIdentifier: "tg\(peer.id.id)", serviceName: nil, sender: nil)
                if let avatarImage = avatarImage, let avatarImageData = avatarImage.jpegData(compressionQuality: 0.8) {
                    intent.setImage(INImage(imageData: avatarImageData), forParameterNamed: \.groupName)
                }
                let interaction = INInteraction(intent: intent, response: nil)
                interaction.direction = .outgoing
                interaction.identifier = "sendMessage_\(account.peerId.toInt64())_\(peer.id.toInt64)"
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
