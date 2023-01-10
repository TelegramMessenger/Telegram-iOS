import Foundation
import UIKit
import Intents
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences
import TelegramPresentationData
import AvatarNode
import AccountContext

private let savedMessagesAvatar: UIImage = {
    return generateImage(CGSize(width: 60.0, height: 60.0), rotatedContext: { size, context in
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
    })!
}()

public enum SendMessageIntentContext {
    case chat
    case share
}

public enum SendMessageIntentSubject: CaseIterable {
    case contact
    case savedMessages
    case privateChat
    case group
    
    func toString() -> String {
        switch self {
            case .contact:
                return "contact"
            case .savedMessages:
                return "savedMessages"
            case .privateChat:
                return "privateChat"
            case .group:
                return "group"
        }
    }
}

public func donateSendMessageIntent(account: Account, sharedContext: SharedAccountContext, intentContext: SendMessageIntentContext, peerIds: [PeerId]) {
    if #available(iOSApplicationExtension 13.2, iOS 13.2, *) {
        let _ = (sharedContext.accountManager.transaction { transaction -> Bool in
            if case .none = transaction.getAccessChallengeData() {
                return true
            } else {
                return false
            }
        }
        |> mapToSignal { unlocked -> Signal<[(Peer, SendMessageIntentSubject, UIImage?)], NoError> in
            if unlocked {
                return sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.intentsSettings])
                |> take(1)
                |> mapToSignal { sharedData -> Signal<[(Peer, SendMessageIntentSubject)], NoError> in
                    let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.intentsSettings]?.get(IntentsSettings.self) ?? IntentsSettings.defaultSettings
                    if let accountId = settings.account, accountId != account.peerId {
                        return .single([])
                    }
                    if case .chat = intentContext, settings.onlyShared {
                        return .single([])
                    }
                    
                    return TelegramEngine(account: account).data.get(
                        EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)),
                        EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.IsContact.init)),
                        EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Messages.ChatListGroup.init))
                    )
                    |> map { peerMap, isContactMap, chatListGroupMap -> [(Peer, SendMessageIntentSubject)] in
                        var peers: [(Peer, SendMessageIntentSubject)] = []
                        for peerId in peerIds {
                            if peerId.namespace != Namespaces.Peer.SecretChat, let maybePeer = peerMap[peerId], let peer = maybePeer {
                                var subject: SendMessageIntentSubject?
                                let chatListGroup = chatListGroupMap[peerId]
                                if chatListGroup == .archive {
                                    continue
                                }
                                if peerId.namespace == Namespaces.Peer.CloudUser {
                                    if peerId == account.peerId {
                                        if !settings.savedMessages {
                                            continue
                                        }
                                        subject = .savedMessages
                                    } else if let isContact = isContactMap[peerId], isContact {
                                        if !settings.contacts {
                                            continue
                                        }
                                        subject = .contact
                                    } else {
                                        if !settings.privateChats {
                                            continue
                                        }
                                        subject = .privateChat
                                    }
                                } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                                    if !settings.groups {
                                         continue
                                    }
                                    subject = .group
                                } else if case let .channel(peer) = peer {
                                    if case .group = peer.info {
                                        if !settings.groups {
                                            continue
                                        }
                                        subject = .group
                                    } else {
                                        continue
                                    }
                                } else {
                                    continue
                                }
                                
                                if let subject = subject {
                                    peers.append((peer._asPeer(), subject))
                                }
                            }
                        }
                        return peers
                    }
                }
                |> mapToSignal { peers -> Signal<[(Peer, SendMessageIntentSubject, UIImage?)], NoError> in
                    var signals: [Signal<(Peer, SendMessageIntentSubject, UIImage?), NoError>] = []
                    for (peer, subject) in peers {
                        if peer.id == account.peerId {
                            signals.append(.single((peer, subject, savedMessagesAvatar)))
                        } else {
                            let peerAndAvatar = (peerAvatarImage(account: account, peerReference: PeerReference(peer), authorOfMessage: nil, representation: peer.smallProfileImage, clipStyle: .none) ?? .single(nil))
                            |> map { imageVersions -> (Peer, SendMessageIntentSubject, UIImage?) in
                                var avatarImage: UIImage?
                                if let image = imageVersions?.0 {
                                    avatarImage = image
                                } else {
                                    let avatarFont = avatarPlaceholderFont(size: 26.0)
                                    let size = CGSize(width: 60.0, height: 60.0)
                                    if let image = generateImage(size, rotatedContext: { size, context in
                                        context.clear(CGRect(origin: CGPoint(), size: size))
                                        
                                        drawPeerAvatarLetters(context: context, size: CGSize(width: size.width, height: size.height), font: avatarFont, letters: peer.displayLetters, peerId: peer.id)
                                    })?.withRenderingMode(.alwaysOriginal) {
                                        avatarImage = image
                                    }
                                }
                                return (peer, subject, avatarImage)
                            }
                            signals.append(peerAndAvatar)
                        }
                    }
                    return combineLatest(signals)
                }
            } else {
                return .single([])
            }
        }
        |> deliverOnMainQueue).start(next: { peers in
            let presentationData = sharedContext.currentPresentationData.with { $0 }
            
            for (peer, _, avatarImage) in peers {
                let recipientHandle = INPersonHandle(value: "tg\(peer.id.toInt64())", type: .unknown)
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
                        displayTitle = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        nameComponents.givenName = peer.firstName
                        nameComponents.familyName = peer.lastName
                    }
                } else {
                    displayTitle = EnginePeer(peer).compactDisplayTitle
                    nameComponents.givenName = displayTitle
                }
                
                var personImage: INImage?
                if let avatarImage = avatarImage, let avatarImageData = avatarImage.jpegData(compressionQuality: 0.8) {
                    personImage = INImage(imageData: avatarImageData)
                }
                
                let recipient = INPerson(personHandle: recipientHandle, nameComponents: nameComponents, displayName: displayTitle, image: personImage, contactIdentifier: nil, customIdentifier: "tg\(peer.id.toInt64())")
               
                let intent = INSendMessageIntent(recipients: [recipient], content: nil, speakableGroupName: INSpeakableString(spokenPhrase: displayTitle), conversationIdentifier: "tg\(peer.id.toInt64())", serviceName: nil, sender: nil)
                let interaction = INInteraction(intent: intent, response: nil)
                interaction.direction = .outgoing
                interaction.groupIdentifier = "sendMessage_\(peer.id.toInt64())"
                interaction.donate { error in
                    if let error = error {
                        print(error)
                    }
                }
            }
        })
    }
}

public func deleteSendMessageIntents(peerId: PeerId) {
    if #available(iOS 10.0, *) {
        INInteraction.delete(with: "sendMessage_\(peerId.toInt64())")
    }
}

public func deleteAllSendMessageIntents() {
    if #available(iOS 10.0, *) {
        INInteraction.deleteAll()
    }
}
